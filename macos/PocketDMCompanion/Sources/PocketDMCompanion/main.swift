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

        panel.contentView = NSHostingView(rootView: content)
        restoreFrame()
        setMinimized(model.minimized)
    }

    func show() {
        panel.orderFrontRegardless()
        Task { await model.refreshHealth() }
    }

    private func setMinimized(_ minimized: Bool) {
        let size = minimized ? NSSize(width: 168, height: 74) : NSSize(width: 360, height: 292)
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
            ? NSPoint(x: screen.maxX - 390, y: screen.minY + 72)
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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 292),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
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
    @Published var message = "I am Ember. I can hover above your Mac while PocketDM runs."
    @Published var serverLine = "Checking PocketDM..."
    @Published var minimized = UserDefaults.standard.bool(forKey: "PocketDMCompanion.minimized")
    @Published var busy = false

    private let client: PocketDMClient
    private let launcher: GameLauncher

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

    func ask(_ prompt: String) async {
        busy = true
        defer { busy = false }
        do {
            message = try await client.assistantReply(for: prompt)
            serverLine = "PocketDM companion online"
        } catch {
            message = "I cannot reach the tale yet. Open PocketDM, start a run, then ask me again."
            serverLine = "Waiting for local server"
        }
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
        Button {
            model.setMinimized(false)
            onSizeChange(false)
        } label: {
            HStack(spacing: 8) {
                dragonGlyph(size: 48)
                Text("Ember")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
            }
            .padding(8)
            .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gold.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var expandedBody: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ivory.opacity(0.72))
                Text("Ember")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Spacer()
                Button {
                    model.setMinimized(true)
                    onSizeChange(true)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ivory)
                .accessibilityLabel("Minimize dragon overlay")
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
                dragonGlyph(size: 136)
                    .shadow(color: .black.opacity(0.42), radius: 12, y: 10)

                VStack(spacing: 8) {
                    Text(model.serverLine)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ivory.opacity(0.82))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Button("Hint") { Task { await model.ask("hint") } }
                        Button("Status") { Task { await model.ask("status") } }
                    }
                    .buttonStyle(DragonButtonStyle())
                    .disabled(model.busy)

                    HStack(spacing: 7) {
                        TextField("Ask Ember", text: $customPrompt)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 9)
                            .frame(height: 34)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(Color.ivory)
                        Button("Ask") {
                            let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                            customPrompt = ""
                            guard !prompt.isEmpty else { return }
                            Task { await model.ask(prompt) }
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
        .frame(width: 360, height: 292)
        .background(.clear)
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

    private func dragonGlyph(size: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [Color.emerald, Color.deepTeal], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.58, height: size * 0.38)
                .offset(x: -size * 0.08, y: size * 0.14)
            Capsule()
                .fill(Color.wing)
                .frame(width: size * 0.48, height: size * 0.18)
                .rotationEffect(.degrees(-32))
                .offset(x: -size * 0.2, y: -size * 0.12)
            Capsule()
                .fill(Color.wing)
                .frame(width: size * 0.46, height: size * 0.16)
                .rotationEffect(.degrees(24))
                .offset(x: size * 0.14, y: -size * 0.08)
            Circle()
                .fill(LinearGradient(colors: [Color.emeraldLight, Color.emerald], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(x: size * 0.24, y: -size * 0.12)
            Circle()
                .fill(Color.ivory)
                .frame(width: size * 0.06)
                .offset(x: size * 0.32, y: -size * 0.15)
            Circle()
                .fill(.black)
                .frame(width: size * 0.032)
                .offset(x: size * 0.335, y: -size * 0.15)
            Triangle()
                .fill(Color.gold)
                .frame(width: size * 0.12, height: size * 0.18)
                .rotationEffect(.degrees(-8))
                .offset(x: size * 0.14, y: -size * 0.31)
            Triangle()
                .fill(Color.gold)
                .frame(width: size * 0.12, height: size * 0.18)
                .rotationEffect(.degrees(18))
                .offset(x: size * 0.3, y: -size * 0.3)
        }
        .frame(width: size, height: size)
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
                premise: "A floating desktop dragon checks on the adventure.",
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
    static let emerald = Color(red: 0.14, green: 0.42, blue: 0.34)
    static let emeraldLight = Color(red: 0.48, green: 0.78, blue: 0.55)
    static let deepTeal = Color(red: 0.08, green: 0.22, blue: 0.2)
    static let wing = Color(red: 0.74, green: 0.28, blue: 0.2)
}
