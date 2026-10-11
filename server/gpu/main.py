"""SpineCare GPU coaching server.

WebSocket protocol (JSON messages):
  client -> {"type":"frame","t":ms,"img":"<b64 jpeg>","w":..,"h":..,"imu":{...}?}
  client -> {"type":"session","exercise_id":..,"mode":"live"}
  client -> {"type":"calibrate","action":"neutral"}
  server -> {"type":"pose","t":..,"metrics":{..},"framing":{..},"reps":..,"cues":[..],"latency_ms":..}

Design: on-device checks stay on the phone; the server adds GPU pose + temporal
analysis + form scoring. Frames are processed in-memory; only derived metrics and
session summaries are persisted (data minimization).
"""
from __future__ import annotations
import asyncio, base64, json, time, uuid, io, os, sqlite3
from pathlib import Path
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import numpy as np

from pose import PersonPose, compute_metrics, framing_check, RepEngine

ROOT = Path(__file__).resolve().parent
DB = ROOT / "sessions.db"

app = FastAPI(title="SpineCare GPU server")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

EXERCISES = json.loads((ROOT / "exercises.json").read_text())
EX_BY_ID = {e["id"]: e for e in EXERCISES["exercises"]}

# ---- GPU model (lazy) ----
_MODEL = None
def get_model():
    global _MODEL
    if _MODEL is None:
        from ultralytics import YOLO
        _MODEL = YOLO("yolov8n-pose.pt")
        _MODEL.to("cuda" if _gpu_ok() else "cpu")
    return _MODEL

def _gpu_ok():
    try:
        import torch
        return torch.cuda.is_available()
    except Exception:
        return False

def _init_db():
    con = sqlite3.connect(DB)
    con.execute("""CREATE TABLE IF NOT EXISTS sessions(
        id TEXT PRIMARY KEY, exercise_id TEXT, started_at REAL, ended_at REAL,
        reps INTEGER, avg_metrics TEXT, cues TEXT, frames INTEGER)""")
    con.commit(); con.close()
_init_db()

def _save_session(sid, ex_id, started, ended, reps, metrics, cues, frames):
    con = sqlite3.connect(DB)
    con.execute("INSERT OR REPLACE INTO sessions VALUES(?,?,?,?,?,?,?,?)",
                (sid, ex_id, started, ended, reps, json.dumps(metrics), json.dumps(cues), frames))
    con.commit(); con.close()

class Session:
    def __init__(self, ex_id: str):
        self.id = str(uuid.uuid4())[:8]
        self.ex = EX_BY_ID[ex_id]
        self.started = time.time()
        self.reps = RepEngine(self.ex["rep_band"]["low"], self.ex["rep_band"]["high"])
        self.metric_hist: dict[str, list[float]] = {}
        self.cue_counts: dict[str, int] = {}
        self.frames = 0
        self.last_signal = None

def _score_form(ex: dict, metrics: dict) -> list[dict]:
    cues = []
    for rule in ex.get("form_rules", []):
        v = metrics.get(rule["metric"])
        if v is None:
            continue
        if abs(v) > rule["max_abs"]:
            cues.append({"metric": rule["metric"], "value": round(v, 1), "cue": rule["cue"]})
    return cues

def _signal_value(ex: dict, metrics: dict) -> float | None:
    sig = ex["signal"]
    if sig == "trunk_tilt_sagittal_proxy":
        # side view: trunk vs vertical in image plane approximates sagittal inclination
        return metrics.get("trunk_tilt_frontal")
    if sig.startswith("abs:"):
        v = metrics.get(sig[4:])
        return abs(v) if v is not None else None
    return metrics.get(sig)

@app.get("/health")
def health():
    return {"ok": True, "gpu": _gpu_ok(), "exercises": list(EX_BY_ID)}

@app.get("/exercises")
def exercises():
    return EXERCISES

@app.get("/sessions")
def sessions():
    con = sqlite3.connect(DB)
    rows = con.execute("SELECT id,exercise_id,started_at,ended_at,reps,frames FROM sessions ORDER BY started_at DESC LIMIT 50").fetchall()
    con.close()
    return [dict(zip(["id","exercise_id","started_at","ended_at","reps","frames"], r)) for r in rows]

@app.websocket("/ws/session")
async def ws_session(ws: WebSocket):
    await ws.accept()
    session: Session | None = None
    loop = asyncio.get_event_loop()
    try:
        while True:
            raw = await ws.receive_text()
            msg = json.loads(raw)
            t0 = time.time()
            if msg["type"] == "session":
                ex_id = msg["exercise_id"]
                if ex_id not in EX_BY_ID:
                    await ws.send_json({"type":"error","error":"unknown exercise"}); continue
                session = Session(ex_id)
                await ws.send_json({"type":"session_started","session_id":session.id,
                                    "exercise":session.ex})
                continue
            if msg["type"] == "frame":
                if session is None:
                    await ws.send_json({"type":"error","error":"no active session"}); continue
                img_b = base64.b64decode(msg["img"])
                img = Image.open(io.BytesIO(img_b)).convert("RGB")
                arr = np.asarray(img)
                model = get_model()
                res = await loop.run_in_executor(None, lambda: model.predict(arr, verbose=False, device=0 if _gpu_ok() else "cpu"))
                r = res[0]
                pose = None
                if r.keypoints is not None and len(r.keypoints) > 0:
                    kdata = r.keypoints.data[0].cpu().numpy()  # (17,3)
                    kpts = [(float(x), float(y), float(c)) for x, y, c in kdata]
                    pose = PersonPose(kpts, tuple(map(float, r.boxes.xyxy[0].cpu().numpy())))
                ex = session.ex
                framing = framing_check(pose, ex["required_landmarks"], ex["min_conf"],
                                        arr.shape[1], arr.shape[0])
                metrics = compute_metrics(pose) if pose else {}
                sig = _signal_value(ex, metrics)
                # Rep timing uses the client frame timestamp when provided (video replay
                # or buffered streams); falls back to server wall-clock for live streams.
                rep_t = (msg["t"] / 1000.0) if msg.get("t") else time.time()
                rep_state = session.reps.update(sig, rep_t) if sig is not None else {"reps": session.reps.reps, "phase": "rest", "rep_just_done": False}
                cues = _score_form(ex, metrics)
                for c in cues:
                    session.cue_counts[c["metric"]] = session.cue_counts.get(c["metric"], 0) + 1
                for k, v in metrics.items():
                    if v is not None:
                        session.metric_hist.setdefault(k, []).append(v)
                session.frames += 1
                session.last_signal = sig
                latency = int((time.time() - t0) * 1000)
                await ws.send_json({
                    "type": "pose", "t": msg.get("t"), "session_id": session.id,
                    "landmarks": [{"x": x, "y": y, "visibility": c} for x, y, c in kpts] if pose else [],
                    "metrics": {k: (round(v, 2) if v is not None else None) for k, v in metrics.items()},
                    "signal": sig, "framing": framing,
                    "reps": rep_state["reps"], "phase": rep_state["phase"],
                    "rep_just_done": rep_state["rep_just_done"],
                    "target_reps": ex["target_reps"],
                    "cues": cues, "latency_ms": latency,
                    "stop_conditions": ex["stop_conditions"],
                })
                continue
            if msg["type"] == "end_session":
                if session:
                    avg = {k: round(sum(v)/len(v), 2) for k, v in session.metric_hist.items() if v}
                    _save_session(session.id, session.ex["id"], session.started, time.time(),
                                  session.reps.reps, avg, session.cue_counts, session.frames)
                    await ws.send_json({"type": "session_saved", "session_id": session.id,
                                        "reps": session.reps.reps, "avg_metrics": avg,
                                        "cue_counts": session.cue_counts, "frames": session.frames})
                    session = None
                continue
    except WebSocketDisconnect:
        if session:
            avg = {k: round(sum(v)/len(v), 2) for k, v in session.metric_hist.items() if v}
            _save_session(session.id, session.ex["id"], session.started, time.time(),
                          session.reps.reps, avg, session.cue_counts, session.frames)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8300)
