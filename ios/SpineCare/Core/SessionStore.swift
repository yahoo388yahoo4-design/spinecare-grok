import Foundation

/// Append-only JSONL session store. Video paths are file names inside
/// Documents/recordings so a review still opens after the app is reopened.
struct SessionRecord: Codable, Identifiable {
    var id: Int { ts }
    let ts: Int
    let date: String
    let exercise: String
    let reps: Int
    let avg: [String: Double]
    let frames: Int
    let source: String
    var video: String?
    var recordedFrames: Int?
}

final class SessionStore: ObservableObject {
    static let shared = SessionStore()
    @Published var sessions: [SessionRecord] = []

    private let url: URL
    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("data", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("sessions.jsonl")
        load()
    }

    static func recordingsDir() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Accepts a stored file name or an older absolute path.
    func resolvedVideo(_ rec: SessionRecord) -> URL? {
        guard let v = rec.video, !v.isEmpty else { return nil }
        let dir = Self.recordingsDir()
        if v.hasPrefix("/") {
            if FileManager.default.fileExists(atPath: v) { return URL(fileURLWithPath: v) }
            let fallback = dir.appendingPathComponent((v as NSString).lastPathComponent)
            return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
        }
        let file = dir.appendingPathComponent(v)
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    func save(exerciseId: String, reps: Int, metrics: [String: Double], cues: [String: Int],
              frames: Int, source: String, videoURL: URL?, recordedFrames: Int) {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var rec = SessionRecord(ts: Int(Date().timeIntervalSince1970 * 1000), date: df.string(from: Date()),
                                exercise: exerciseId, reps: reps, avg: metrics,
                                frames: frames, source: source)
        if let v = videoURL, recordedFrames > 0 {
            rec.video = v.lastPathComponent
            rec.recordedFrames = recordedFrames
        }
        guard let line = try? JSONEncoder().encode(rec) else { return }
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let fh = try FileHandle(forWritingTo: url)
            defer { try? fh.close() }
            try fh.seekToEnd()
            fh.write(line)
            fh.write(Data("\n".utf8))
        } catch {
            return
        }
        load()
    }

    func load() {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { sessions = []; return }
        sessions = text.split(separator: "\n").compactMap {
            try? JSONDecoder().decode(SessionRecord.self, from: Data($0.utf8))
        }.reversed()
    }
}
