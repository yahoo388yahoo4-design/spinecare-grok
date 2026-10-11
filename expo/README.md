# SpineCare Mobile

Cross-platform React Native / Expo prototype for Android and iOS. Interface languages: English and Romanian.

## Implemented in the current app

- Six screens: Today, Plan, Session, Camera, Progress, and Settings.
- English/Romanian interface switch.
- Local exercise plan selection and custom clinician-approved exercise entries.
- Clinician instructions, target sets/repetitions, optional video URL, and delete controls.
- Session timer, manual set counter, session completion history, and symptom check-ins (0–10).
- On-device persistence for plans, custom entries, sessions, check-ins, and non-secret settings using AsyncStorage.
- CSV-formatted local data sharing through the device share sheet.
- **On-device MediaPipe Pose Landmarker integration** using a native React Native/Vision Camera module. The Android and iOS build workflows download the lightweight pose model and bundle it with the native app so inference does not need a network connection after installation. This requires a native development/release build; Expo Go cannot load the native module.
- Settings for local pose processing, CPU/GPU delegate, frame processing rate, remote server URL/IP, analysis endpoint, username, password, remote opt-in, landmark sharing, and explicit insecure-private-LAN HTTP allowance.
- Remote server connection check. If the server is unreachable, the app continues local operation and does not wait for a remote result.
- Remote enhancement sends pose landmarks only, never camera frames. Password is stored using platform secure storage; other preferences remain local.
- Optional example FastAPI service in `server/` with authenticated `/health` and `/analyze/pose` endpoints. Its current remote summary is a technical landmark-visibility check, not a clinical assessment.
- Camera preview and front/side/back/oblique framing guidance.
- Safety, privacy, and emergency symptom notices.
- GitHub Actions Android APK build and iOS bundle-validation workflows. A signed iOS IPA is not produced.

## Important limits and next validation

- MediaPipe landmarks describe estimated visible body keypoints. They do not diagnose spinal alignment, disc protrusions, nerve compression, bone lesions, or whether an exercise is safe.
- Automatic clinically meaningful repetition counting, movement-quality scoring, personalized rehabilitation advice, and a clinician-reviewed exercise/video catalogue are **not** claimed as complete.
- The example remote server does not run a large AI model; it demonstrates authenticated offload and returns a basic visibility summary. Replace/extend it only with a separately validated algorithm.
- Native build success is not the same as device testing. Camera permissions, model packaging, GPU compatibility, thermal behavior, network loss, server authentication, and Android/iOS devices still need testing before use.
- No cloud accounts, data synchronization, clinician dashboard, or automatic backup are included.
- Do not use the app for unsupervised rehabilitation. A clinician must approve exercises and doses, particularly given the reported cervical findings and C6 lesion.

## Run locally
- Node.js 20+
- `npm install`
- Download the MediaPipe Lite model before a native build:
  - macOS/Linux: `mkdir -p assets/models && curl -L --fail -o assets/models/pose_landmarker_lite.task https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task`
  - Windows PowerShell: `New-Item -ItemType Directory -Force assets/models; Invoke-WebRequest https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task -OutFile assets/models/pose_landmarker_lite.task`
- `npx expo prebuild` then build a native development/release app. Native MediaPipe and Vision Camera modules do not run in Expo Go.
- `npx expo start` is useful for the JS development server, but camera inference requires the native build.

## Android APK
GitHub Actions builds a release APK on pushes to `main`. Open **Actions**, choose the latest **Android APK** run, and download the `spinecare-android-apk` artifact after a successful run.

## iOS IPA
A device-installable IPA requires an Apple Developer account, signing credentials, and a provisioning profile. Configure EAS and Apple signing credentials securely; never commit certificates, private keys, profiles, or tokens.

## Medical safety
This is a prototype, not a medical device or a substitute for clinical care. It does not diagnose spinal conditions or measure disc protrusions, nerve compression, cysts, or bone lesions. The example exercise entries and animations are placeholders, not treatment recommendations. Given the described cervical findings including a focal C6 lesion, have the treating clinician explicitly approve the movements, range, repetitions, and stop rules before any use. Stop and seek urgent medical assessment for new or progressive weakness, loss of coordination, gait/balance difficulty, or bowel/bladder changes.

## Privacy
No patient reports, scans, identifiers, or patient-specific findings are included in this repository. Session, symptom, and settings data remain on-device. Camera frames are processed locally and are not recorded or transmitted. Google’s MediaPipe Tasks privacy notice says the SDK may send performance/utilization metrics when connected; this is disclosed in Settings. If remote enhancement and landmark sharing are explicitly enabled, the app sends pose coordinates (not camera frames) to the configured server. Remote credentials are stored using platform secure storage. Use HTTPS whenever possible; the insecure HTTP option should be limited to a trusted private LAN. Review the server code and firewall configuration before deployment. Avoid identifying details in notes. Uninstalling the app or clearing app data may remove local history. Do not commit patient data or secrets to source control, logs, issues, or build artifacts.

The optional landmark server for this app is in `../server/landmarks/`, not inside this folder.
