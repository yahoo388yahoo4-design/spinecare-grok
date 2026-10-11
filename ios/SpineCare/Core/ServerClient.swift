import Foundation

/// GPU coaching server client — mirrors Android ServerConfig/ServerClient.
/// Offline-first: AUTO tries the server and falls back to on-device; ON_DEVICE
/// never touches the network.
final class ServerConfig: ObservableObject {
    static let shared = ServerConfig()

    enum Mode: Int { case auto = 0, onDevice = 1, server = 2 }

    @Published var url: String
    @Published var user: String
    @Published var pass: String
    @Published var mode: Mode
    @Published var frameIntervalMs: Int
    @Published var serverFrameIntervalMs: Int
    @Published var minConfidence: Double
    @Published var haptics: Bool
    @Published var audioCues: Bool
    @Published var recordSessions: Bool

    private let d = UserDefaults.standard
    private init() {
        url = d.string(forKey: "server_url") ?? "http://192.168.1.188:8300"
        user = d.string(forKey: "server_user") ?? ""
        pass = d.string(forKey: "server_pass") ?? ""
        mode = Mode(rawValue: d.integer(forKey: "mode")) ?? .auto
        frameIntervalMs = d.object(forKey: "frame_ms") as? Int ?? 150
        serverFrameIntervalMs = d.object(forKey: "server_frame_ms") as? Int ?? 100
        minConfidence = d.object(forKey: "min_conf") as? Double ?? 0.5
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        audioCues = d.object(forKey: "audio_cues") as? Bool ?? false
        recordSessions = d.object(forKey: "record_sessions") as? Bool ?? true
    }
    func save() {
        d.set(url, forKey: "server_url"); d.set(user, forKey: "server_user")
        d.set(pass, forKey: "server_pass"); d.set(mode.rawValue, forKey: "mode")
        d.set(frameIntervalMs, forKey: "frame_ms"); d.set(serverFrameIntervalMs, forKey: "server_frame_ms")
        d.set(minConfidence, forKey: "min_conf"); d.set(haptics, forKey: "haptics")
        d.set(audioCues, forKey: "audio_cues"); d.set(recordSessions, forKey: "record_sessions")
    }

    func testConnection(_ done: @escaping (String) -> Void) {
        guard let u = URL(string: url.trimmingCharacters(in: .whitespaces) + "/health") else {
            done("Invalid URL"); return
        }
        var req = URLRequest(url: u, timeoutInterval: 5)
        if !user.isEmpty {
            let cred = Data("\(user):\(pass)".utf8).base64EncodedString()
            req.setValue("Basic \(cred)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err { done("Unreachable: \(err.localizedDescription)"); return }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            done(code == 200 ? "OK — \(body.prefix(120))" : "HTTP \(code)")
        }.resume()
    }
}

/// WebSocket streaming client (URLSessionWebSocketTask).
final class ServerClient {
    private var task: URLSessionWebSocketTask?
    private var connected = false

    func connect(_ base: String, user: String, pass: String, onResult: @escaping ([String: Any]) -> Void) {
        guard let ws = URL(string: base.replacingOccurrences(of: "http", with: "ws") + "/ws/session") else { return }
        var req = URLRequest(url: ws)
        if !user.isEmpty {
            let cred = Data("\(user):\(pass)".utf8).base64EncodedString()
            req.setValue("Basic \(cred)", forHTTPHeaderField: "Authorization")
        }
        task = URLSession.shared.webSocketTask(with: req)
        task?.resume(); connected = true
        receiveLoop(onResult)
    }

    private func receiveLoop(_ onResult: @escaping ([String: Any]) -> Void) {
        task?.receive { [weak self] result in
            if case .success(let msg) = result, case .string(let s) = msg,
               let data = s.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                onResult(obj)
            }
            self?.receiveLoop(onResult)
        }
    }

    func send(_ obj: [String: Any]) {
        guard connected, let data = try? JSONSerialization.data(withJSONObject: obj),
              let s = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(s)) { _ in }
    }

    func disconnect() { task?.cancel(); connected = false }
}
