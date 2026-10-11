"""Pose analysis: YOLOv8-pose (GPU) -> body-segment angles + framing checks.

Keypoints are COCO-17 (ultralytics). Note COCO includes ears/eyes, which lets us
estimate cervical (neck) angles from visible segments. These are ESTIMATES of
body-segment orientation, never vertebral measurements.
"""
from __future__ import annotations
import math
from dataclasses import dataclass, field

KP = {
    "nose": 0, "leye": 1, "reye": 2, "lear": 3, "rear": 4,
    "lsho": 5, "rsho": 6, "lel": 7, "rel": 8, "lwri": 9, "rwri": 10,
    "lhip": 11, "rhip": 12, "lkne": 13, "rkne": 14, "lank": 15, "rank": 16,
}

@dataclass
class PersonPose:
    kpts: list           # list of (x, y, conf) length 17
    bbox: tuple
    def p(self, name):
        return self.kpts[KP[name]]
    def vis(self, name, min_conf=0.5):
        return self.kpts[KP[name]][2] >= min_conf

def _mid(a, b):
    return ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0, min(a[2], b[2]))

def _ang_between(v1, v2):
    d = v1[0]*v2[0] + v1[1]*v2[1]
    n1 = math.hypot(*v1); n2 = math.hypot(*v2)
    if n1 < 1e-6 or n2 < 1e-6:
        return None
    return math.degrees(math.acos(max(-1.0, min(1.0, d/(n1*n2)))))

def _ang_from_vertical(a, b):
    """Angle of segment a->b vs downward vertical (0 = straight down)."""
    v = (b[0]-a[0], b[1]-a[1])
    return _ang_between(v, (0.0, 1.0))

def compute_metrics(pose: PersonPose) -> dict:
    """Visible-segment metrics. All angles in degrees, offsets normalized by torso length."""
    m: dict[str, float | None] = {}
    lsho, rsho = pose.p("lsho"), pose.p("rsho")
    lhip, rhip = pose.p("lhip"), pose.p("rhip")
    lear, rear = pose.p("lear"), pose.p("rear")
    nose = pose.p("nose")

    sho_mid = _mid(lsho, rsho)
    hip_mid = _mid(lhip, rhip)
    ear_mid = _mid(lear, rear)
    torso_len = math.hypot(sho_mid[0]-hip_mid[0], sho_mid[1]-hip_mid[1]) or 1.0
    sho_w = math.hypot(lsho[0]-rsho[0], lsho[1]-rsho[1]) or 1.0

    # Trunk inclination (frontal): shoulder-mid -> hip-mid vs vertical
    if pose.vis("lsho") and pose.vis("rsho") and pose.vis("lhip") and pose.vis("rhip"):
        m["trunk_tilt_frontal"] = _ang_from_vertical(sho_mid, hip_mid)
        # Sagittal head-forward posture proxy: ear vs shoulder horizontal offset
        # (meaningful in side view; in front view it collapses to ~0)
        m["head_forward_proxy"] = (ear_mid[0]-sho_mid[0]) / torso_len
    # Cervical tilt (frontal): ear-mid vs shoulder-mid vs vertical
    if pose.vis("lear") and pose.vis("rear") and pose.vis("lsho") and pose.vis("rsho"):
        m["cervical_tilt"] = _ang_from_vertical(ear_mid, sho_mid)
    # Neck rotation estimate (front view, chest facing camera): signed lateral
    # nose offset vs shoulder midline. Ear-separation proxies collapse when an
    # ear occludes during rotation; the nose stays visible and gives sign too.
    if pose.vis("nose") and pose.vis("lsho") and pose.vis("rsho"):
        nose_dx = nose[0] - sho_mid[0]
        ratio = max(-1.0, min(1.0, nose_dx / (0.28 * sho_w)))
        m["neck_yaw_est"] = math.degrees(math.asin(ratio))
    # Shoulder line tilt (wrapped to (-90, 90] so facing direction doesn't flip it)
    if pose.vis("lsho") and pose.vis("rsho"):
        deg = math.degrees(math.atan2(rsho[1]-lsho[1], rsho[0]-lsho[0]))
        m["shoulder_line_tilt"] = (deg + 90.0) % 180.0 - 90.0
    # Cervical extension/flexion proxy (side view): nose vs ear vs shoulder
    if pose.vis("nose") and pose.vis("lear") and pose.vis("lsho"):
        m["cervical_sag_proxy"] = _ang_between((nose[0]-ear_mid[0], nose[1]-ear_mid[1]),
                                               (sho_mid[0]-ear_mid[0], sho_mid[1]-ear_mid[1]))
    return m

def framing_check(pose: PersonPose | None, required: list[str], min_conf: float,
                  frame_w: int, frame_h: int, margin: float = 0.03) -> dict:
    """Verify required landmarks are visible and inside frame margins."""
    issues = []
    if pose is None:
        return {"ready": False, "issues": ["no_person"], "missing": required}
    missing = []
    for name in required:
        x, y, c = pose.p(name)
        if c < min_conf:
            missing.append(name); issues.append(f"{name}:low_conf")
        elif not (margin*frame_w <= x <= (1-margin)*frame_w and margin*frame_h <= y <= (1-margin)*frame_h):
            missing.append(name); issues.append(f"{name}:out_of_frame")
    return {"ready": len(missing) == 0, "issues": issues, "missing": missing}

class RepEngine:
    """Hysteresis phase machine counting reps on a scalar signal (e.g. neck yaw)."""
    def __init__(self, low: float, high: float, min_hold_s: float = 0.4):
        self.low, self.high, self.min_hold = low, high, min_hold_s
        self.phase = "rest"   # rest -> in -> out -> in ...
        self.reps = 0
        self.t_enter = None
        self.last_reps_t = 0.0

    def update(self, value: float, t: float) -> dict:
        if value is None:
            return {"reps": self.reps, "phase": self.phase, "rep_just_done": False}
        rep_done = False
        if self.phase == "rest" and value >= self.high:
            self.phase = "out"; self.t_enter = t
        elif self.phase == "out" and value <= self.low:
            if t - (self.t_enter or t) >= self.min_hold:
                self.reps += 1; rep_done = True; self.last_reps_t = t
            self.phase = "in"; self.t_enter = t
        elif self.phase == "in" and value >= self.high:
            self.phase = "out"; self.t_enter = t
        return {"reps": self.reps, "phase": self.phase, "rep_just_done": rep_done}
