import SwiftUI

struct SensorsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Phone sensors (in use)") {
                    Label("Camera → Apple Vision body pose (on-device)", systemImage: "camera")
                    Label("Depth/LiDAR → used when the device exposes it (ARKit)", systemImage: "cube.transparent")
                    Label("Accelerometer+gyro → posture context (Core Motion)", systemImage: "iphone")
                    Label("HealthKit → steps, sleep import", systemImage: "heart")
                }
                Section("ESP32 posture nodes (BLE)") {
                    Text("Two 6-DOF IMU nodes (BMI270 + ESP32-C3): head + upper trunk.\nService 0xFFF0; notify 0xFFF1 (head) / 0xFFF2 (trunk).\nPayload: seq, pitch/roll/yaw (0.01°), accel (mg), gyro (0.1 dps) — 20 bytes.")
                        .font(.callout)
                    Text("Firmware source: firmware/esp32_posture_node/ in the project.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("What sensors can and cannot measure") {
                    Text("CAN: body-segment angles, movement tempo, reps, posture trends, activity, sleep position (bed mat).")
                    Text("CANNOT: vertebral positions, disc protrusions, nerve compression, C6 lesion stability — imaging only.")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Sensors")
        }
    }
}

struct SettingsView: View {
    @ObservedObject var cfg = ServerConfig.shared
    @State private var status = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Coaching mode") {
                    Picker("Mode", selection: $cfg.mode) {
                        Text("Auto (server if reachable)").tag(ServerConfig.Mode.auto)
                        Text("On-device only (offline)").tag(ServerConfig.Mode.onDevice)
                        Text("GPU server required").tag(ServerConfig.Mode.server)
                    }
                }
                Section("GPU server") {
                    TextField("Server URL", text: $cfg.url, prompt: Text("http://192.168.1.188:8300"))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("User", text: $cfg.user)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $cfg.pass)
                    Button("Test connection") {
                        status = "Testing \(cfg.url) …"
                        cfg.testConnection { status = $0 }
                    }
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Section("Tuning") {
                    Stepper("Analysis interval: \(cfg.frameIntervalMs) ms", value: $cfg.frameIntervalMs, in: 50...1000, step: 25)
                    Stepper("Server send interval: \(cfg.serverFrameIntervalMs) ms", value: $cfg.serverFrameIntervalMs, in: 50...1000, step: 25)
                    VStack(alignment: .leading) {
                        Text("Min confidence: \(cfg.minConfidence, specifier: "%.2f")")
                        Slider(value: $cfg.minConfidence, in: 0.1...0.9)
                    }
                    Toggle("Haptic cues", isOn: $cfg.haptics)
                    Toggle("Audio cues", isOn: $cfg.audioCues)
                    Toggle("Record sessions with sensor overlay (local MP4, review in Sessions tab)", isOn: $cfg.recordSessions)
                }
                Section {
                    Button("Save settings") { cfg.save(); status = "Saved" }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
