# SpineCare

Combined cervical-movement companion. It merges the Hermes coaching engines (pose metrics, framing gate, rep counter, BLE packet, sleep experiment, sensor limits) with the Expo app (English/Romanian, clinician-written exercises, symptom check-ins, landmark-only remote analysis, CSV export).

This is a prototype. It does not diagnose, does not image the spine, and does not decide whether a disc, nerve, or bone lesion is safe to load. Use only a plan your treating clinician has approved. Stop and seek urgent care for new or worsening weakness, clumsy hands, trouble walking, or bowel/bladder change.

## What was wrong, and what this version does

- Neck rotation used ear separation. A turned head hid one ear and the angle collapsed to 0, so the NHS demo counted 0 reps. The signal is now a signed nose offset from the shoulder midline, which stays visible during a turn.
- Chin tucks required the left ear only. Facing the other way failed the framing gate even when the visible ear was clear. Either confident ear now satisfies a side-view ear requirement.
- Invisible ears were averaged in as the origin and invented a head-forward offset. Missing ears are ignored.
- Thoracic extension pointed at `trunk_tilt_sagittal_proxy`, which no engine computed, while the Android plan used raw trunk tilt. Reps are now the change from your own seated start.
- Scapular setting counted shoulder-line tilt, so a shrug looked like a successful rep. It now needs a sustained depth change and a release, and a level shoulder is a form cue, not a rep.
- The Expo app had no camera path on the web and did not count reps. This version runs MediaPipe Pose on the device, draws the skeleton, gates scoring until framing is ready, and still lets you count by hand if the camera is off.
- Remote mode in Hermes uploaded camera frames. This version sends landmarks only, and only after you turn sharing on. The password stays in memory and is not written to device storage.
- Sleep guidance was a static page. You can now log a 7-night pillow experiment. Phone tilt and the ESP32 posture-node packet (service 0xFFF0) are available where the browser allows them.

## Screens

Today, Plan, Coach, Progress, Sleep, Sensors, Settings. English and Romanian. Plans, doses, sessions, check-ins, and sleep notes stay on this device.

Nothing here is a prescription. The four reference movements start unapproved until you confirm your clinician allowed that dose.
