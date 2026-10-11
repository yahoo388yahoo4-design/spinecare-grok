"""Unit tests for pose.py — run with pytest inside the VM venv."""
import math
import pytest
from pose import PersonPose, compute_metrics, framing_check, RepEngine

def mk(kpts=None, **overrides):
    """Default: a plausible standing person, 640x480 frame."""
    base = [(0, 0, 0.0)] * 17
    default = {
        "nose": (320, 100, 0.9), "lear": (300, 110, 0.9), "rear": (340, 110, 0.9),
        "lsho": (270, 160, 0.9), "rsho": (370, 160, 0.9),
        "lel": (255, 230, 0.8), "rel": (385, 230, 0.8),
        "lwri": (250, 300, 0.8), "rwri": (390, 300, 0.8),
        "lhip": (285, 300, 0.9), "rhip": (355, 300, 0.9),
        "lkne": (283, 380, 0.9), "rkne": (357, 380, 0.9),
        "lank": (282, 450, 0.9), "rank": (358, 450, 0.9),
    }
    default.update(overrides)
    for name, v in default.items():
        from pose import KP
        base[KP[name]] = v
    return PersonPose(base, (200, 60, 440, 470))

def test_upright_trunk_zero_tilt():
    m = compute_metrics(mk())
    assert abs(m["trunk_tilt_frontal"]) < 3
    assert abs(m["shoulder_line_tilt"]) < 1

def test_leaning_trunk_detected():
    # shift hips 60px right -> trunk tilts
    m = compute_metrics(mk(lhip=(345, 300, 0.9), rhip=(415, 300, 0.9)))
    assert m["trunk_tilt_frontal"] > 10

def test_head_forward_proxy_sign():
    m1 = compute_metrics(mk(lear=(300, 110, 0.9), rear=(340, 110, 0.9)))
    m2 = compute_metrics(mk(lear=(330, 110, 0.9), rear=(370, 110, 0.9)))  # ears forward
    assert m2["head_forward_proxy"] > m1["head_forward_proxy"]

def test_neck_yaw_front_vs_turned():
    """Signed nose-offset estimator: nose lateral offset vs shoulder midline."""
    front = compute_metrics(mk())
    assert abs(front["neck_yaw_est"]) < 15
    # head turned toward right shoulder: nose shifts right of shoulder midline
    right = compute_metrics(mk(nose=(336, 100, 0.9)))
    assert right["neck_yaw_est"] > 25
    # head turned toward left shoulder: nose shifts left
    left = compute_metrics(mk(nose=(304, 100, 0.9)))
    assert left["neck_yaw_est"] < -25

def test_neck_yaw_survives_ear_occlusion():
    """The old ear-separation proxy collapsed to 0 when an ear was occluded;
    the nose-offset estimator must still report rotation."""
    m = compute_metrics(mk(nose=(336, 100, 0.9), lear=(300, 110, 0.1), rear=(322, 110, 0.1)))
    assert m["neck_yaw_est"] > 25

def test_framing_all_visible():
    f = framing_check(mk(), ["lear", "lsho", "lhip"], 0.5, 640, 480)
    assert f["ready"] and not f["missing"]

def test_framing_low_conf():
    p = mk(lear=(300, 110, 0.2))
    f = framing_check(p, ["lear", "lsho"], 0.5, 640, 480)
    assert not f["ready"] and "lear" in f["missing"]

def test_framing_out_of_frame():
    p = mk(lhip=(5, 300, 0.9))
    f = framing_check(p, ["lhip"], 0.5, 640, 480)
    assert not f["ready"] and any(i.endswith("out_of_frame") for i in f["issues"])

def test_framing_no_person():
    f = framing_check(None, ["lsho"], 0.5, 640, 480)
    assert not f["ready"] and f["issues"] == ["no_person"]

def test_rep_engine_counts_cycles():
    r = RepEngine(8, 35, min_hold_s=0.0)
    done = []
    t = 0.0
    for cycle in range(3):
        for v in (5, 20, 40, 45, 40, 20, 5):
            done.append(r.update(v, t)["rep_just_done"]); t += 0.1
    assert r.reps == 3
    assert sum(done) == 3

def test_rep_engine_hysteresis_no_double_count():
    r = RepEngine(8, 35, min_hold_s=0.0)
    t = 0.0
    for v in (5, 40, 36, 34, 36, 40, 5):  # wobble at top should count once
        r.update(v, t); t += 0.1
    assert r.reps == 1

def test_rep_engine_ignores_none():
    r = RepEngine(0, 10)
    out = r.update(None, 1.0)
    assert out["rep_just_done"] is False
