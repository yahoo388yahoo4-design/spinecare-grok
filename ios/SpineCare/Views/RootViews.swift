import SwiftUI
import AVKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .allButUpsideDown

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

/// Portrait or landscape, from the button or by turning the phone.
final class OrientationController: ObservableObject {
    static let shared = OrientationController()
    @Published var landscape = false

    private init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.landscape = CameraOrientation.interfaceOrientation().isLandscape
        }
    }

    func rotate() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let toLandscape = !(scene?.interfaceOrientation.isLandscape ?? landscape)
        landscape = toLandscape
        let mask: UIInterfaceOrientationMask = toLandscape ? .landscapeRight : .portrait
        AppDelegate.orientationLock = mask
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        scene?.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AppDelegate.orientationLock = .allButUpsideDown
            scene?.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

@main
struct SpineCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
                        Text("Start an exercise, then press Stop & Save. The session is kept on this iPhone, with the recording when Record is on.")
                            .font(.callout).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding()
                    }
                } else {
                    List(store.sessions) { rec in
                        NavigationLink {
                            SessionDetailView(rec: rec)
                        } label: {
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
                                if store.resolvedVideo(rec) != nil {
                                    Text("Recording · \(rec.recordedFrames ?? 0) frames")
                                        .font(.caption).foregroundStyle(.green)
                                } else {
                                    Text("No recording for this session")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .onAppear { store.load() }
        }
    }
}

struct SessionDetailView: View {
    let rec: SessionRecord
    @State private var player: AVPlayer?
    @State private var missing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 320)
                        .background(Color.black)
                } else if missing {
                    Text("This session was saved, but the video file is not on the phone. Start again with Record on and stay in frame until you press Stop & Save.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Text(Plan.byId(rec.exercise)?.name ?? rec.exercise).font(.title2)
                Text("\(rec.date) · reps \(rec.reps) · \(rec.source)")
                    .font(.callout).foregroundStyle(.secondary)
                if !rec.avg.isEmpty {
                    Text(rec.avg.map { "\($0.key) \(String(format: "%.1f", $0.value))" }.joined(separator: "\n"))
                        .font(.system(.body, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Session review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { open() }
        .onDisappear { player?.pause() }
    }

    private func open() {
        guard player == nil else { return }
        guard let url = SessionStore.shared.resolvedVideo(rec) else { missing = true; return }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 1000 else { missing = true; return }
        let next = AVPlayer(url: url)
        player = next
        next.play()
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
