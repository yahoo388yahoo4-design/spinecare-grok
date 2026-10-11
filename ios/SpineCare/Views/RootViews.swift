import SwiftUI
import AVKit

@main
struct SpineCareApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Home", systemImage: "house") }
            ExercisesView().tabItem { Label("Exercises", systemImage: "figure.walk") }
            SessionsView().tabItem { Label("Sessions", systemImage: "film") }
            SensorsView().tabItem { Label("Sensors", systemImage: "dot.radiowaves.left.and.right") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Recovery plan") {
                    Text("C2–C7 disc protrusions, right C5/C7 radiculopathy, mild cervico-dorsal scoliosis, C6 lesion under imaging follow-up.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section("Safety") {
                    Text("All plans require clinician sign-off. Stop on: progressive weakness, hand clumsiness, gait change, bowel/bladder change — seek urgent care.")
                        .font(.callout).foregroundStyle(.red)
                }
                Section("Follow-up") {
                    Text("C6 lesion: repeat imaging per radiologist (6–12 weeks). Sensors cannot assess bone or nerve — imaging only.")
                        .font(.callout)
                }
            }
            .navigationTitle("SpineCare")
        }
    }
}

/// Sessions tab: saved sessions with per-session metrics and the recorded
/// video (sensor overlay burned in) playable in-app.
struct SessionsView: View {
    @ObservedObject var store = SessionStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No sessions yet").font(.headline)
                        Text("Run an exercise from the Exercises tab. With recording on, each session is saved with the skeleton, angles and cues burned into the video.")
                            .font(.callout).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding()
                    }
                } else {
                    List(store.sessions) { rec in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(rec.date) · \(Plan.byId(rec.exercise)?.name ?? rec.exercise)")
                                .font(.headline)
                            Text("reps=\(rec.reps) · frames=\(rec.frames) · [\(rec.source)]")
                                .font(.caption).foregroundStyle(.secondary)
                            if !rec.avg.isEmpty {
                                Text(rec.avg.map { "\($0.key)=\(String(format: "%.1f", $0.value))" }
                                        .joined(separator: "  "))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            if let v = rec.video, store.videoExists(rec) {
                                NavigationLink("▶ Review recording (\(rec.recordedFrames ?? 0) frames)") {
                                    VideoReviewView(url: URL(fileURLWithPath: v))
                                }
                            } else if rec.video != nil {
                                Text("recording file missing").font(.caption).foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Sessions")
            .onAppear { store.load() }
        }
    }
}

struct VideoReviewView: View {
    let url: URL
    var body: some View {
        VideoPlayer(player: AVPlayer(url: url))
            .ignoresSafeArea()
            .navigationTitle("Session review")
            .onDisappear {}
    }
}

struct ExercisesView: View {
    var body: some View {
        NavigationStack {
            List(Plan.exercises) { ex in
                NavigationLink(value: ex.id) {
                    VStack(alignment: .leading) {
                        Text(ex.name).font(.headline)
                        Text("\(ex.view.uppercased()) view · target \(ex.targetReps) reps · \(ex.clinicianApproved ? "clinician-approved" : "pending approval")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Exercises")
            .navigationDestination(for: String.self) { id in
                if let ex = Plan.byId(id) { ExerciseSessionView(exercise: ex) }
            }
        }
    }
}
