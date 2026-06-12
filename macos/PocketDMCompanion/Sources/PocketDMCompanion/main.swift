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
        let size = minimized ? NSSize(width: 184, height: 190) : NSSize(width: 500, height: 386)
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
            ? NSPoint(x: screen.maxX - 516, y: screen.minY + 72)
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 386),
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
    private static let petOnlyKey = "PocketDMCompanion.petOnly"
    private static let soundEnabledKey = "PocketDMCompanion.soundEnabled"
    private static let companionHPKey = "PocketDMCompanion.companionHP"
    private static let happinessKey = "PocketDMCompanion.happiness"
    private static let petStreakKey = "PocketDMCompanion.petStreak"
    private static let lastPetDayKey = "PocketDMCompanion.lastPetDay"
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @Published var message = "Your electric partner keeps a tiny bond spark. Pet once each day to earn +1 HP and refill joy."
    @Published var lastRequest = ""
    @Published var serverLine = "Checking PocketDM..."
    @Published var minimized = true
    @Published var soundEnabled = UserDefaults.standard.object(forKey: DragonOverlayModel.soundEnabledKey) as? Bool ?? true
    @Published var busy = false
    @Published var mood: PetMood = .idle
    @Published var learningMode: LearningMode = .chat
    @Published var companionHP = UserDefaults.standard.object(forKey: DragonOverlayModel.companionHPKey) as? Int ?? 3
    @Published var happiness = UserDefaults.standard.object(forKey: DragonOverlayModel.happinessKey) as? Int ?? 3
    @Published var petStreak = UserDefaults.standard.object(forKey: DragonOverlayModel.petStreakKey) as? Int ?? 0
    @Published var lastPetDay = UserDefaults.standard.string(forKey: DragonOverlayModel.lastPetDayKey) ?? ""

    let languageCoach = LanguageCoachStore()

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
        guard minimized != value else { return }
        minimized = value
        UserDefaults.standard.set(value, forKey: Self.petOnlyKey)
        play(value ? .minimize : .open)
    }

    func toggleSound() {
        let next = !soundEnabled
        if soundEnabled {
            play(.minimize)
        }
        soundEnabled = next
        UserDefaults.standard.set(next, forKey: Self.soundEnabledKey)
        if next {
            play(.open)
        }
    }

    func happy() {
        message = "Happy."
        lastRequest = "Mood"
        play(.happy)
        setMood(.happy, duration: 1.6)
    }

    func nap() {
        message = "Nap."
        lastRequest = "Mood"
        play(.nap)
        setMood(.nap, duration: 2.4)
    }

    func hyper() {
        message = "Hyper."
        lastRequest = "Mood"
        play(.hyper)
        setMood(.hyper, duration: 1.5)
    }

    func toggleLearning() {
        learningMode = learningMode == .lesson ? .chat : .lesson
        if learningMode == .lesson {
            lastRequest = "Learn"
            message = "Pick Spanish or Mandarin, listen, then quiz."
            play(.open)
            languageCoach.speakCurrent()
            setMood(.happy, duration: 1.2)
        } else {
            lastRequest = ""
            message = "Back to chat. Ask for a hint or pet for today's spark."
            play(.minimize)
        }
    }

    func applyLanguageReward(_ reward: LanguagePracticeReward) {
        lastRequest = "Language"
        message = reward.message
        if reward.correct {
            happiness = min(5, happiness + 1)
            if reward.dailyBond {
                companionHP = min(10, companionHP + 1)
            }
            persistCare()
            play(reward.dailyBond ? .pet : .happy)
            setMood(.happy, duration: 1.4)
        } else {
            play(.alert)
            setMood(.alert, duration: 1.2)
        }
    }

    func petDaily(requestLabel: String = "Daily pet") {
        lastRequest = requestLabel
        let today = Self.dayFormatter.string(from: Date())
        if lastPetDay == today {
            happiness = min(5, happiness + 1)
            message = "Already cared for today. Still happy to hear from you. Joy +1."
        } else {
            companionHP = min(10, companionHP + 1)
            happiness = 5
            petStreak += 1
            lastPetDay = today
            message = "Pikachu brightened up. +1 Bond HP today."
        }
        persistCare()
        play(.pet)
        setMood(.happy, duration: 2.2)
    }

    func ask(_ prompt: String) async {
        lastRequest = prompt
        if handlesCare(prompt) {
            petDaily(requestLabel: prompt)
            return
        }
        message = "Thinking..."
        busy = true
        play(.send)
        setMood(.thinking)
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
                self?.mood = .idle
            }
        }
    }

    func prepareClose() {
        lastRequest = "Close"
        message = "Curling up. See you next check-in."
        play(.close)
        setMood(.nap)
    }

    var careLine: String {
        "Bond HP \(companionHP)/10 · Joy \(happiness)/5 · Day \(petStreak)"
    }

    private func play(_ sound: PetSound) {
        soundPlayer.play(sound, enabled: soundEnabled)
    }

    private func persistCare() {
        UserDefaults.standard.set(companionHP, forKey: Self.companionHPKey)
        UserDefaults.standard.set(happiness, forKey: Self.happinessKey)
        UserDefaults.standard.set(petStreak, forKey: Self.petStreakKey)
        UserDefaults.standard.set(lastPetDay, forKey: Self.lastPetDayKey)
    }

    private func handlesCare(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        return lowered.contains("pet") || lowered.contains("happy") || lowered.contains("care")
    }
}

enum PetMood: String, CaseIterable {
    case idle
    case happy
    case nap
    case hyper
    case alert
    case thinking

    var assetName: String {
        switch self {
        case .idle, .happy:
            return "pet-happy"
        case .nap:
            return "pet-nap"
        case .hyper:
            return "pet-hyper"
        case .alert, .thinking:
            return "pet-alert"
        }
    }

    var frameSequence: [Int] {
        switch self {
        case .idle:
            return [8, 8, 8, 0, 0, 10, 10, 1, 2, 3, 3, 0]
        case .thinking:
            return [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0, 0]
        case .hyper:
            return [0, 3, 5, 6, 7, 8, 9, 10, 11, 4, 2, 1]
        default:
            return Array(0..<12)
        }
    }
}

enum PetSound: CaseIterable {
    case happy
    case nap
    case hyper
    case alert
    case reply
    case send
    case open
    case minimize
    case close
    case pet

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
        case .send:
            return "chirp-send"
        case .open:
            return "chirp-open"
        case .minimize:
            return "chirp-minimize"
        case .close:
            return "chirp-close"
        case .pet:
            return "chirp-pet"
        }
    }

    var volume: Float {
        switch self {
        case .hyper:
            return 0.18
        case .reply, .open, .pet:
            return 0.17
        case .send, .minimize, .close:
            return 0.13
        default:
            return 0.15
        }
    }

    var cooldown: TimeInterval {
        switch self {
        case .reply, .open, .minimize:
            return 0.5
        case .happy, .hyper:
            return 0.7
        case .nap:
            return 1.0
        case .send:
            return 0.15
        case .pet:
            return 1.5
        case .alert:
            return 2.0
        case .close:
            return 0
        }
    }
}

@MainActor
final class PetSoundPlayer {
    private var cache: [PetSound: NSSound] = [:]
    private var lastPlayed: [PetSound: Date] = [:]

    func play(_ sound: PetSound, enabled: Bool) {
        guard enabled, let player = soundInstance(for: sound) else { return }
        let now = Date()
        if let last = lastPlayed[sound], now.timeIntervalSince(last) < sound.cooldown {
            return
        }
        lastPlayed[sound] = now
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
    @State private var petHovering = false

    var body: some View {
        ZStack {
            if model.minimized {
                petOnlyBody
                    .transition(.scale(scale: 0.84, anchor: .center).combined(with: .opacity))
            } else {
                expandedBody
                    .transition(.scale(scale: 0.92, anchor: .topLeading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: model.minimized)
    }

    private var petOnlyBody: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.76)) {
                    model.setMinimized(false)
                    onSizeChange(false)
                }
            } label: {
                AnimatedPetSprite(mood: model.mood, size: petHovering ? 166 : 158)
                    .shadow(color: .black.opacity(petHovering ? 0.22 : 0.14), radius: petHovering ? 16 : 10, y: 7)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(dragGesture)
            .accessibilityLabel("Open Pikachu chat")

            if petHovering {
                Button {
                    closeCompanion()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(DragonIconButtonStyle(kind: .secondary))
                .frame(width: 30, height: 28)
                .accessibilityLabel("Close Pikachu")
                .transition(.opacity)
            }
        }
        .frame(width: 184, height: 190)
        .contentShape(Rectangle())
        .onHover { isHovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                petHovering = isHovering
            }
        }
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 9) {
            headerBar(isCompact: false)

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 8) {
                    AnimatedPetSprite(mood: model.mood, size: 176)
                    careStatusPanel
                }

                VStack(alignment: .leading, spacing: 9) {
                    if model.learningMode == .lesson {
                        LanguageCoachPanel(
                            coach: model.languageCoach,
                            onReward: { reward in
                                model.applyLanguageReward(reward)
                            }
                        )
                    } else {
                        chatTranscript(isCompact: false)
                    }
                    emotionControls

                    if model.learningMode == .chat {
                        inputRow(isCompact: false)

                        HStack(spacing: 8) {
                            Button("Hint") { Task { await model.ask("hint") } }
                                .buttonStyle(DragonButtonStyle(kind: .secondary))
                                .disabled(model.busy)
                            Button("Open PocketDM") {
                                model.openGame()
                            }
                            .buttonStyle(DragonButtonStyle(kind: .secondary))
                        }
                    }
                }
                .frame(width: 268)
                .padding(8)
                .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.22), lineWidth: 1))
            }
        }
        .padding(8)
        .frame(width: 500, height: 386)
        .background(.clear)
    }

    private var careStatusPanel: some View {
        VStack(spacing: 4) {
            Text(model.serverLine)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.84))
                .lineLimit(2)
            Text(model.careLine)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold)
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .frame(width: 170)
        .frame(minHeight: 50)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.18), lineWidth: 1))
    }

    private func headerBar(isCompact: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: isCompact ? 13 : 15, weight: .bold))
                .foregroundStyle(Color.ivory.opacity(0.68))
            Text("Pikachu")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory)
            Spacer()
            soundButton
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.76)) {
                    model.setMinimized(true)
                    onSizeChange(true)
                }
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ivory)
            .frame(width: 26, height: 24)
            .accessibilityLabel("Minimize Pikachu to pet")
            Button {
                closeCompanion()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ivory)
            .frame(width: 26, height: 24)
            .accessibilityLabel("Close Pikachu")
        }
        .padding(.horizontal, 10)
        .frame(height: isCompact ? 30 : 34)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 7))
        .gesture(dragGesture)
    }

    private func chatTranscript(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 3 : 6) {
            if !model.lastRequest.isEmpty {
                chatLine(label: "You", text: model.lastRequest, isCompact: isCompact)
            }
            chatLine(label: "Pikachu", text: model.message, isCompact: isCompact)
        }
        .padding(isCompact ? 8 : 10)
        .frame(maxWidth: .infinity, minHeight: isCompact ? 56 : 142, alignment: .topLeading)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.26), lineWidth: 1))
    }

    private func chatLine(label: String, text: String, isCompact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: isCompact ? 10 : 11, weight: .black, design: .rounded))
                .foregroundStyle(label == "You" ? Color.gold : Color.ivory.opacity(0.72))
                .frame(width: isCompact ? 44 : 56, alignment: .leading)
            Text(text)
                .font(.system(size: isCompact ? 11 : 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory)
                .lineLimit(isCompact ? 2 : 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emotionControls: some View {
        HStack(spacing: 6) {
            Button("Pet") { model.petDaily() }
                .buttonStyle(DragonButtonStyle(kind: model.mood == .happy ? .primary : .secondary))
            Button("Learn") { model.toggleLearning() }
                .buttonStyle(DragonButtonStyle(kind: model.learningMode == .lesson ? .primary : .secondary))
            Button("Nap") { model.nap() }
                .buttonStyle(DragonButtonStyle(kind: model.mood == .nap ? .primary : .secondary))
            Button("Hyper") { model.hyper() }
                .buttonStyle(DragonButtonStyle(kind: model.mood == .hyper ? .primary : .secondary))
        }
        .disabled(model.busy)
    }

    private func inputRow(isCompact: Bool) -> some View {
        HStack(spacing: 7) {
            TextField("Ask Pikachu", text: $customPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                .padding(.horizontal, 9)
                .frame(height: isCompact ? 32 : 36)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(0.12), lineWidth: 1))
                .foregroundStyle(Color.ivory)
                .disabled(model.busy)
                .onSubmit(submitPrompt)
            Button(model.busy ? "..." : "Enter") {
                submitPrompt()
            }
            .buttonStyle(DragonButtonStyle())
            .frame(width: isCompact ? 72 : 82)
            .disabled(!canSubmit)
        }
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

    private var canSubmit: Bool {
        !model.busy && !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitPrompt() {
        let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        customPrompt = ""
        guard !prompt.isEmpty else { return }
        Task { await model.ask(prompt) }
    }

    private func closeCompanion() {
        model.prepareClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            NSApplication.shared.terminate(nil)
        }
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

struct LanguageCoachPanel: View {
    @ObservedObject var coach: LanguageCoachStore
    let onReward: (LanguagePracticeReward) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            packPicker
            Text(coach.progressLine)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            lessonCard
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 216, alignment: .topLeading)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.26), lineWidth: 1))
    }

    private var packPicker: some View {
        HStack(spacing: 6) {
            ForEach(coach.packs) { pack in
                Button {
                    coach.selectPack(pack)
                    coach.speakCurrent()
                } label: {
                    Text(pack.nativeTitle)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(coach.selectedPackID == pack.id ? Color.black : Color.ivory)
                        .frame(width: 121, height: 34)
                        .background(
                            coach.selectedPackID == pack.id ? Color.gold : Color.black.opacity(0.34),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.ivory.opacity(coach.selectedPackID == pack.id ? 0 : 0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var lessonCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(coach.stepTitle)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(1)
            stepContent
            Text(coach.feedback)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.78))
                .lineLimit(2)
                .frame(minHeight: 24, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch coach.step {
        case .teach:
            phraseBlock
            soundRow
            Button("Start Quiz") {
                coach.startQuiz()
            }
            .buttonStyle(DragonButtonStyle())
        case .meaningQuiz:
            prompt("What does \(coach.currentCard.target) mean?")
            ForEach(coach.meaningChoices, id: \.self) { choice in
                lessonChoice(choice) {
                    onReward(coach.submitMeaning(choice))
                }
            }
        case .phraseQuiz:
            prompt("Pick: \(coach.currentCard.english)")
            ForEach(coach.phraseChoices, id: \.self) { choice in
                lessonChoice(choice) {
                    onReward(coach.submitPhrase(choice))
                }
            }
        case .repeatPrompt:
            phraseBlock
            soundRow
            Button("I Said It") {
                onReward(coach.finishRepeat())
            }
            .buttonStyle(DragonButtonStyle())
        case .complete:
            prompt("Three phrases cleared.")
            Text("Pikachu logged today's language spark.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory)
                .lineLimit(2)
            Button("Review Again") {
                coach.restartLesson()
            }
            .buttonStyle(DragonButtonStyle())
        }
    }

    private var phraseBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(coach.currentCard.target)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(coach.currentCard.romanization)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(coach.currentCard.english)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.88))
                .lineLimit(1)
            Text(coach.currentCard.pronunciationTip)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(2)
        }
    }

    private var soundRow: some View {
        HStack(spacing: 7) {
            Button("Hear") {
                coach.speakCurrent()
            }
            .buttonStyle(DragonButtonStyle(kind: .secondary))
            Button("Slow") {
                coach.speakCurrent(slow: true)
            }
            .buttonStyle(DragonButtonStyle(kind: .secondary))
        }
    }

    private func prompt(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.ivory)
            .lineLimit(2)
            .frame(minHeight: 30, alignment: .bottomLeading)
    }

    private func lessonChoice(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        }
        .buttonStyle(LanguageChoiceButtonStyle())
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
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onReceive(timer) { _ in
            frameIndex = (frameIndex + 1) % mood.frameSequence.count
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
        let sequence = mood.frameSequence
        let frameNumber = sequence[frame % sequence.count]
        return frames[frameNumber % frames.count]
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

    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? Color.black : Color.ivory)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background(kind == .primary ? Color.gold : Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(kind == .primary ? 0 : 0.18), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
    }
}

struct DragonIconButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? Color.black : Color.ivory)
            .frame(width: 34, height: 30)
            .background(kind == .primary ? Color.gold : Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(kind == .primary ? 0 : 0.18), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
    }
}

struct LanguageChoiceButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(Color.ivory)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(0.18), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
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
