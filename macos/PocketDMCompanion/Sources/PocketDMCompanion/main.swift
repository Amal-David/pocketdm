import AppKit
import Combine
import Foundation
import SwiftUI

@main
struct PocketDMCompanionApp {
    static func main() {
        let arguments = CompanionArguments.parse(CommandLine.arguments)
        let app = NSApplication.shared
        let delegate = AppDelegate(arguments: arguments)
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let arguments: CompanionArguments
    private var overlayController: DragonOverlayController?
    private var serverProcess: PocketDMServerProcess?

    init(arguments: CompanionArguments) {
        self.arguments = arguments
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if arguments.launchServer {
            let process = PocketDMServerProcess(repoRoot: arguments.repoRoot)
            process.start()
            serverProcess = process
        }

        let client = PocketDMClient(baseURL: arguments.baseURL)
        let launcher = GameLauncher(baseURL: arguments.baseURL)
        overlayController = DragonOverlayController(client: client, launcher: launcher)
        overlayController?.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        serverProcess?.stop()
    }
}

struct CompanionArguments {
    let baseURL: URL
    let launchServer: Bool
    let repoRoot: URL

    static func parse(_ raw: [String]) -> CompanionArguments {
        var baseURL = URL(string: "http://127.0.0.1:7860")!
        var launchServer = false
        var index = 1

        while index < raw.count {
            switch raw[index] {
            case "--attach" where index + 1 < raw.count:
                baseURL = URL(string: raw[index + 1]) ?? baseURL
                index += 2
            case "--launch-server":
                launchServer = true
                index += 1
            default:
                index += 1
            }
        }

        let environmentRoot = ProcessInfo.processInfo.environment["POCKETDM_REPO"]
        let repoRoot = URL(fileURLWithPath: environmentRoot ?? FileManager.default.currentDirectoryPath)
        return CompanionArguments(baseURL: baseURL, launchServer: launchServer, repoRoot: repoRoot)
    }
}

@MainActor
final class DragonOverlayController {
    private let panel: NSPanel
    private let model: DragonOverlayModel

    init(client: PocketDMClient, launcher: GameLauncher) {
        model = DragonOverlayModel(client: client, launcher: launcher)
        panel = FloatingDragonPanel()

        let content = DragonOverlayView(
            model: model,
            onDrag: { [weak panel] delta in
                guard let panel else { return }
                var frame = panel.frame
                frame.origin.x += delta.width
                frame.origin.y -= delta.height
                panel.setFrame(frame, display: true)
            },
            onDragEnded: { [weak self] in
                self?.persistFrame()
            },
            onSizeChange: { [weak self] minimized in
                self?.setMinimized(minimized)
            }
        )

        let hostingView = NSHostingView(rootView: content)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        panel.contentView = hostingView
        restoreFrame()
        setMinimized(model.minimized)
    }

    func show() {
        panel.orderFrontRegardless()
        Task { await model.refreshHealth() }
    }

    private func setMinimized(_ minimized: Bool) {
        let size = minimized ? NSSize(width: 426, height: 136) : NSSize(width: 386, height: 318)
        var frame = panel.frame
        let top = frame.maxY
        frame.size = size
        frame.origin.y = top - size.height
        panel.setFrame(clamped(frame), display: true, animate: true)
        persistFrame()
    }

    private func restoreFrame() {
        let defaults = UserDefaults.standard
        let savedX = defaults.double(forKey: "PocketDMCompanion.x")
        let savedY = defaults.double(forKey: "PocketDMCompanion.y")
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let origin = savedX == 0 && savedY == 0
            ? NSPoint(x: screen.maxX - 402, y: screen.minY + 72)
            : NSPoint(x: savedX, y: savedY)
        panel.setFrameOrigin(origin)
    }

    private func persistFrame() {
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: "PocketDMCompanion.x")
        UserDefaults.standard.set(origin.y, forKey: "PocketDMCompanion.y")
    }

    private func clamped(_ frame: NSRect) -> NSRect {
        guard let screen = NSScreen.main?.visibleFrame else { return frame }
        var next = frame
        next.origin.x = min(max(next.origin.x, screen.minX + 8), screen.maxX - next.width - 8)
        next.origin.y = min(max(next.origin.y, screen.minY + 8), screen.maxY - next.height - 8)
        return next
    }
}

final class FloatingDragonPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 386, height: 318),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class DragonOverlayModel: ObservableObject {
    private static let soundEnabledKey = "PocketDMCompanion.soundEnabled"

    @Published var message = "Pika-pika. I am on your desktop now."
    @Published var serverLine = "Checking PocketDM..."
    @Published var minimized = UserDefaults.standard.bool(forKey: "PocketDMCompanion.minimized")
    @Published var soundEnabled = UserDefaults.standard.object(forKey: DragonOverlayModel.soundEnabledKey) as? Bool ?? true
    @Published var busy = false
    @Published var mood: PetMood = .happy

    private let client: PocketDMClient
    private let launcher: GameLauncher
    private let soundPlayer = PetSoundPlayer()
    private var moodTask: Task<Void, Never>?

    init(client: PocketDMClient, launcher: GameLauncher) {
        self.client = client
        self.launcher = launcher
    }

    func refreshHealth() async {
        do {
            serverLine = try await client.healthLine()
        } catch {
            serverLine = "PocketDM is not reachable yet"
        }
    }

    func openGame() {
        launcher.openGame()
    }

    func setMinimized(_ value: Bool) {
        minimized = value
        UserDefaults.standard.set(value, forKey: "PocketDMCompanion.minimized")
    }

    func toggleSound() {
        soundEnabled.toggle()
        UserDefaults.standard.set(soundEnabled, forKey: Self.soundEnabledKey)
        if !soundEnabled {
            soundPlayer.stopAll()
        }
    }

    func happy() {
        message = "Happy."
        play(.happy)
        setMood(.happy, duration: 1.6)
    }

    func nap() {
        message = "Nap."
        play(.nap)
        setMood(.nap, duration: 2.4)
    }

    func hyper() {
        message = "Hyper."
        play(.hyper)
        setMood(.hyper, duration: 1.5)
    }

    func ask(_ prompt: String) async {
        busy = true
        play(.alert)
        setMood(.alert)
        defer { busy = false }
        do {
            message = try await client.assistantReply(for: prompt)
            serverLine = "PocketDM companion online"
            play(.reply)
            setMood(.happy, duration: 1.5)
        } catch {
            message = "I cannot reach the tale yet. Open PocketDM, start a run, then ask me again."
            serverLine = "Waiting for local server"
            play(.nap)
            setMood(.nap, duration: 2.4)
        }
    }

    func setMood(_ next: PetMood, duration: TimeInterval? = nil) {
        moodTask?.cancel()
        mood = next
        guard let duration else { return }
        moodTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                self?.mood = .happy
            }
        }
    }

    private func play(_ sound: PetSound) {
        soundPlayer.play(sound, enabled: soundEnabled)
    }
}

enum PetMood: String, CaseIterable {
    case happy
    case nap
    case hyper
    case alert

    var assetName: String {
        switch self {
        case .happy:
            return "pet-happy"
        case .nap:
            return "pet-nap"
        case .hyper:
            return "pet-hyper"
        case .alert:
            return "pet-alert"
        }
    }
}

enum PetSound: CaseIterable {
    case happy
    case nap
    case hyper
    case alert
    case reply

    var resourceName: String {
        switch self {
        case .happy:
            return "chirp-happy"
        case .nap:
            return "chirp-nap"
        case .hyper:
            return "chirp-hyper"
        case .alert:
            return "chirp-alert"
        case .reply:
            return "chirp-reply"
        }
    }

    var volume: Float {
        switch self {
        case .hyper:
            return 0.18
        case .reply:
            return 0.17
        default:
            return 0.15
        }
    }
}

@MainActor
final class PetSoundPlayer {
    private var cache: [PetSound: NSSound] = [:]

    func play(_ sound: PetSound, enabled: Bool) {
        guard enabled, let player = soundInstance(for: sound) else { return }
        player.stop()
        player.currentTime = 0
        player.volume = sound.volume
        player.play()
    }

    func stopAll() {
        for player in cache.values {
            player.stop()
        }
    }

    private func soundInstance(for sound: PetSound) -> NSSound? {
        if let cached = cache[sound] {
            return cached
        }
        guard let url = Bundle.module.url(forResource: sound.resourceName, withExtension: "wav") else {
            return nil
        }
        let player = NSSound(contentsOf: url, byReference: false)
        cache[sound] = player
        return player
    }
}

struct DragonOverlayView: View {
    @ObservedObject var model: DragonOverlayModel
    let onDrag: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onSizeChange: (Bool) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var customPrompt = ""

    var body: some View {
        if model.minimized {
            minimizedBody
        } else {
            expandedBody
        }
    }

    private var minimizedBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ivory.opacity(0.66))
                Text("Pikachu")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Spacer()
                soundButton
                Button {
                    model.setMinimized(false)
                    onSizeChange(false)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ivory)
                .frame(width: 26, height: 24)
                .accessibilityLabel("Expand Pikachu chat")
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 7))
            .gesture(dragGesture)

            HStack(spacing: 8) {
                AnimatedPetSprite(mood: model.mood, size: 58)

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.message)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ivory)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)

                    HStack(spacing: 6) {
                        TextField("Ask Pikachu", text: $customPrompt)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .frame(height: 30)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(Color.ivory)
                            .onSubmit(submitPrompt)
                        Button {
                            submitPrompt()
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .buttonStyle(DragonIconButtonStyle(kind: .primary))
                        .disabled(model.busy)
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 426, height: 136)
        .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.32), lineWidth: 1))
    }

    private var expandedBody: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ivory.opacity(0.72))
                Text("Pikachu")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Spacer()
                soundButton
                Button {
                    model.setMinimized(true)
                    onSizeChange(true)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ivory)
                .accessibilityLabel("Minimize electric familiar overlay")
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 7))
            .gesture(dragGesture)

            Text(model.message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory)
                .frame(maxWidth: 302, minHeight: 58, alignment: .topLeading)
                .padding(12)
                .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.38), lineWidth: 1))

            HStack(alignment: .bottom, spacing: 10) {
                AnimatedPetSprite(mood: model.mood, size: 154)

                VStack(spacing: 8) {
                    Text(model.serverLine)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ivory.opacity(0.82))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Button("Hint") { Task { await model.ask("hint") } }
                        Button("Happy") { model.happy() }
                    }
                    .buttonStyle(DragonButtonStyle())
                    .disabled(model.busy)

                    HStack(spacing: 8) {
                        Button("Nap") { model.nap() }
                        Button("Hyper") { model.hyper() }
                    }
                    .buttonStyle(DragonButtonStyle())
                    .disabled(model.busy)

                    HStack(spacing: 7) {
                        TextField("Ask Pikachu", text: $customPrompt)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 9)
                            .frame(height: 34)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(Color.ivory)
                            .onSubmit(submitPrompt)
                        Button("Ask") {
                            submitPrompt()
                        }
                        .buttonStyle(DragonButtonStyle())
                        .disabled(model.busy)
                    }

                    Button("Open PocketDM") {
                        model.openGame()
                    }
                    .buttonStyle(DragonButtonStyle(kind: .secondary))
                }
                .frame(width: 190)
            }
        }
        .padding(8)
        .frame(width: 386, height: 318)
        .background(.clear)
    }

    private var soundButton: some View {
        Button {
            model.toggleSound()
        } label: {
            Image(systemName: model.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.soundEnabled ? Color.ivory : Color.ivory.opacity(0.58))
        .frame(width: 26, height: 24)
        .accessibilityLabel(model.soundEnabled ? "Mute Pikachu sounds" : "Unmute Pikachu sounds")
    }

    private func submitPrompt() {
        let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        customPrompt = ""
        guard !prompt.isEmpty else { return }
        Task { await model.ask(prompt) }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let delta = CGSize(
                    width: value.translation.width - dragOffset.width,
                    height: value.translation.height - dragOffset.height
                )
                dragOffset = value.translation
                onDrag(delta)
            }
            .onEnded { _ in
                dragOffset = .zero
                onDragEnded()
            }
    }

}

struct AnimatedPetSprite: View {
    let mood: PetMood
    let size: CGFloat

    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let image = PetSpriteSheet.image(for: mood, frame: frameIndex) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "bolt.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.gold)
                    .padding(size * 0.22)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onReceive(timer) { _ in
            frameIndex = (frameIndex + 1) % PetSpriteSheet.frameCount
        }
        .onChange(of: mood) {
            frameIndex = 0
        }
    }
}

@MainActor
enum PetSpriteSheet {
    static let frameCount = 12
    private static var cache: [PetMood: [NSImage]] = [:]

    static func image(for mood: PetMood, frame: Int) -> NSImage? {
        let frames = frames(for: mood)
        guard !frames.isEmpty else { return nil }
        return frames[frame % frames.count]
    }

    private static func frames(for mood: PetMood) -> [NSImage] {
        if let cached = cache[mood] {
            return cached
        }
        guard
            let url = Bundle.module.url(forResource: mood.assetName, withExtension: "png"),
            let sheet = NSImage(contentsOf: url),
            let cgImage = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            cache[mood] = []
            return []
        }

        let frameWidth = cgImage.width / frameCount
        let frameHeight = cgImage.height
        let frames = (0..<frameCount).compactMap { index -> NSImage? in
            let rect = CGRect(x: index * frameWidth, y: 0, width: frameWidth, height: frameHeight)
            guard let cropped = cgImage.cropping(to: rect) else { return nil }
            return NSImage(
                cgImage: cropped,
                size: NSSize(width: CGFloat(frameWidth), height: CGFloat(frameHeight))
            )
        }
        cache[mood] = frames
        return frames
    }
}

struct DragonButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? Color.black : Color.ivory)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background(kind == .primary ? Color.gold : Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(kind == .primary ? 0 : 0.18), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct DragonIconButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? Color.black : Color.ivory)
            .frame(width: 34, height: 30)
            .background(kind == .primary ? Color.gold : Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(kind == .primary ? 0 : 0.18), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct BoltTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.36))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.36))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.54))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.58))
        path.closeSubpath()
        return path
    }
}

actor PocketDMClient {
    private let baseURL: URL
    private var sessionID: String?

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func healthLine() async throws -> String {
        let url = baseURL.appending(path: "health")
        let (_, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw CompanionError.badResponse
        }
        return "PocketDM server online"
    }

    func assistantReply(for message: String) async throws -> String {
        if sessionID == nil {
            sessionID = try await startSession()
        }
        let payload = AssistantRequest(session_id: sessionID!, message: message)
        let response: AssistantResponse = try await post(payload, path: "api/assistant")
        return response.reply
    }

    private func startSession() async throws -> String {
        let response: StartResponse = try await post(
            StartRequest(
                genre: "whispering_wood",
                premise: "A floating electric familiar checks on the adventure.",
                voice: "lore"
            ),
            path: "api/start"
        )
        return response.session_id
    }

    private func post<Request: Encodable, Response: Decodable>(_ payload: Request, path: String) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw CompanionError.badResponse
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

struct StartRequest: Encodable {
    let genre: String
    let premise: String
    let voice: String
}

struct StartResponse: Decodable {
    let session_id: String
}

struct AssistantRequest: Encodable {
    let session_id: String
    let message: String
}

struct AssistantResponse: Decodable {
    let reply: String
}

enum CompanionError: Error {
    case badResponse
}

final class GameLauncher {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func openGame() {
        NSWorkspace.shared.open(baseURL)
    }
}

final class PocketDMServerProcess {
    private let repoRoot: URL
    private var process: Process?

    init(repoRoot: URL) {
        self.repoRoot = repoRoot
    }

    func start() {
        guard process == nil else { return }
        let next = Process()
        next.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        next.arguments = ["uv", "run", "python", "app.py"]
        next.currentDirectoryURL = repoRoot
        next.environment = ProcessInfo.processInfo.environment
        do {
            try next.run()
            process = next
        } catch {
            process = nil
        }
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}

private extension Color {
    static let ivory = Color(red: 1.0, green: 0.96, blue: 0.84)
    static let gold = Color(red: 0.94, green: 0.72, blue: 0.34)
    static let emerald = Color(red: 0.96, green: 0.66, blue: 0.1)
    static let emeraldLight = Color(red: 1.0, green: 0.94, blue: 0.4)
    static let deepTeal = Color(red: 0.82, green: 0.36, blue: 0.04)
    static let wing = Color(red: 1.0, green: 0.84, blue: 0.18)
    static let sparkLight = Color(red: 1.0, green: 0.92, blue: 0.28)
    static let sparkAmber = Color(red: 0.91, green: 0.5, blue: 0.06)
    static let sparkDark = Color(red: 0.12, green: 0.08, blue: 0.05)
    static let sparkCheek = Color(red: 0.98, green: 0.25, blue: 0.22)
    static let electricBlue = Color(red: 0.38, green: 0.92, blue: 1.0)
}
