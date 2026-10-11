import Foundation

/// Append-only JSONL session store (mirrors Android LocalStore), plus lookup of
/// recorded videos for the Sessions review tab.
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

    func save(exerciseId: String, reps: Int, metrics: [String: Double], cues: [String: Int],
              frames: Int, source: String, videoURL: URL?, recordedFrames: Int) {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var rec = SessionRecord(ts: Int(Date().timeIntervalSince1970), date: df.string(from: Date()),
                                exercise: exerciseId, reps: reps, avg: metrics,
                                frames: frames, source: source)
        if let v = videoURL { rec.video = v.path; rec.recordedFrames = recordedFrames }
        if let line = try? JSONEncoder().encode(rec) {
            if let fh = try? FileHandle(forWritingTo: url) {
                fh.seekToEndOfFile(); fh.write(line + Data("\n".utf8)); fh.closeFile()
            } else {
                try? (String(data: line, encoding: .utf8)! + "\n").write(to: url, atomically: true,
                                                                         encoding: .utf8)
            }
        }
        load()
    }

    func load() {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { sessions = []; return }
        sessions = text.split(separator: "\n").compactMap {
            try? JSONDecoder().decode(SessionRecord.self, from: Data($0.utf8))
        }.reversed()
    }

    func videoExists(_ rec: SessionRecord) -> Bool {
        guard let v = rec.video else { return false }
        return FileManager.default.fileExists(atPath: v)
    }
}
