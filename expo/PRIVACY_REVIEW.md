# Privacy review

- No patient reports, medical images, patient identifiers, or patient-specific findings are included.
- No account system or automatic cloud backup is implemented. An optional user-configured remote analysis endpoint exists; it is off by default.
- Users can explicitly open the device share sheet to export CSV-formatted session/check-in data. Shared content may leave the device if the user selects another app or recipient; notes may contain sensitive health information, so avoid identifiers and review the export before sharing.
- MediaPipe estimates pose landmarks on-device from live camera frames. Frames are not saved or uploaded. Google’s MediaPipe Tasks privacy notice states that the SDK may send performance/utilization metrics when connected; users are informed in Settings. If remote enhancement and landmark sharing are explicitly enabled, landmark coordinates are sent to the configured server.
- The remote server URL, username, and sharing preferences are stored locally; the password is stored with Expo SecureStore. HTTPS is strongly recommended. Explicit HTTP mode is intended only for a trusted private LAN because HTTP Basic credentials are otherwise unencrypted.
- The app can estimate general pose landmarks locally, but it does not perform clinical assessment or validate movement safety. The sample remote server only computes technical landmark visibility.
- Do not commit patient data, signing keys, API tokens, provisioning profiles, or health records.
- The build pipeline uploads only the generated APK as a GitHub Actions artifact.
