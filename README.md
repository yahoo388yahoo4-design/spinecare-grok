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

## Native clients, server, and firmware

These trees are the phone, server, and wearable code from the Hermes and SpineCare repositories. The web app in this workspace is separate; it does not replace these projects.

| Path | What it is |
| --- | --- |
| `android/` | Kotlin app. CameraX, on-device MediaPipe, rep engine, BLE posture client, Health Connect, CSV export. |
| `ios/` | Swift app. Vision pose, the same coaching engines, session store, unsigned IPA via XcodeGen. |
| `firmware/esp32_posture_node/` | ESP32-S3 BLE posture node (BMI270). |
| `server/gpu/` | Optional FastAPI + WebSocket coaching server (YOLOv8-pose). Processes frames in memory. |
| `server/landmarks/` | Optional landmark-only API. Authenticated `/health` and `/analyze/pose`. No camera frames. Not a clinical assessment. |

### Android

Needs JDK 17, Android SDK 34, Gradle 8.7.

```bash
cd android
gradle assembleDebug
gradle testDebugUnitTest
```

The pose model is already in `android/app/src/main/assets/pose_landmarker_full.task`.

### iOS

```bash
cd ios
brew install xcodegen   # once
xcodegen generate
xcodebuild -project SpineCare.xcodeproj -scheme SpineCare -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO build
```

A device IPA still needs your own Apple signing. Do not commit certificates or profiles.

### GPU server

```bash
cd server/gpu
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8300
```

### Landmark server

```bash
cd server/landmarks
pip install -r requirements.txt
export SPINECARE_SERVER_USER='choose-a-user'
export SPINECARE_SERVER_PASSWORD='use-a-long-random-password'
uvicorn app:app --host 0.0.0.0 --port 8000
```

### Firmware

```bash
cd firmware/esp32_posture_node
pio run -t upload
```

CI on `main` builds the debug APK, runs the Android unit tests and the GPU-server pose tests, and produces an unsigned iOS IPA.

## Expo app

The React Native / Expo client lives in `expo/`. It is separate from the Kotlin project in `android/` and the Swift project in `ios/`. Prebuild output stays inside `expo/` so those native trees are not overwritten.

```bash
cd expo
npm install
npx expo start
```

Camera inference needs a native build (`npx expo prebuild`), not Expo Go. Workflows `Expo Android APK` and `Expo iOS unsigned build` produce a release APK and an unsigned iOS bundle. A device IPA still needs your Apple signing.
