import AppKit
import AVFoundation
import Combine
import Foundation
import Speech
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
    private var statusItem: NSStatusItem?

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
        overlayController = DragonOverlayController(
            client: client,
            launcher: launcher,
            character: arguments.character,
            repoRoot: arguments.repoRoot
        )
        overlayController?.show()
        installStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        serverProcess?.stop()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bolt.circle.fill", accessibilityDescription: "Pikachu companion live")
            button.imagePosition = .imageLeading
            button.title = " Pika"
        }
        statusItem = item
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()
        let live = NSMenuItem(title: "Pika is Live", action: nil, keyEquivalent: "")
        live.isEnabled = false
        menu.addItem(live)
        menu.addItem(NSMenuItem.separator())
        let show = NSMenuItem(title: "Open Chat", action: #selector(showPanelFromMenu), keyEquivalent: "o")
        show.target = self
        menu.addItem(show)
        let petOnly = NSMenuItem(title: "Hide to Pet", action: #selector(showPetOnlyFromMenu), keyEquivalent: "m")
        petOnly.target = self
        menu.addItem(petOnly)
        let soundTitle = overlayController?.soundEnabled == true ? "Mute Sounds" : "Unmute Sounds"
        let sound = NSMenuItem(title: soundTitle, action: #selector(toggleSoundFromMenu), keyEquivalent: "")
        sound.target = self
        sound.state = overlayController?.soundEnabled == true ? .on : .off
        menu.addItem(sound)
        menu.addItem(NSMenuItem.separator())
        let reset = NSMenuItem(title: "Delete Pet Data...", action: #selector(resetPetDataFromMenu), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        let close = NSMenuItem(title: "Quit Pika", action: #selector(closeFromMenu), keyEquivalent: "q")
        close.target = self
        menu.addItem(close)
        statusItem?.menu = menu
    }

    @objc private func showPanelFromMenu() {
        overlayController?.showExpanded()
        rebuildStatusMenu()
    }

    @objc private func showPetOnlyFromMenu() {
        overlayController?.showPetOnly()
        rebuildStatusMenu()
    }

    @objc private func toggleSoundFromMenu() {
        overlayController?.toggleSound()
        rebuildStatusMenu()
    }

    @objc private func closeFromMenu() {
        overlayController?.prepareClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            NSApplication.shared.terminate(nil)
        }
    }

    @objc private func resetPetDataFromMenu() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete Pikachu data?"
        alert.informativeText = "This clears bond stats, Sparks, language progress, and window position. The app will quit so the next launch starts fresh."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Self.resetCompanionDefaults()
        overlayController?.prepareClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            NSApplication.shared.terminate(nil)
        }
    }

    private static func resetCompanionDefaults() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("PocketDMCompanion.") {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }
}

struct CompanionArguments {
    let baseURL: URL
    let launchServer: Bool
    let repoRoot: URL
    let character: CompanionCharacter
    let pikaTTSURL: URL?
    let pikaSTTURL: URL?
    let realtimeSTTURL: URL?

    static func parse(_ raw: [String]) -> CompanionArguments {
        var baseURL = URL(string: "http://127.0.0.1:7860")!
        var launchServer = false
        var character = CompanionCharacter.savedDefault
        var pikaTTSURL: URL?
        var pikaSTTURL: URL?
        var realtimeSTTURL: URL?
        var index = 1

        while index < raw.count {
            switch raw[index] {
            case "--attach" where index + 1 < raw.count:
                baseURL = URL(string: raw[index + 1]) ?? baseURL
                index += 2
            case "--pika-tts-url" where index + 1 < raw.count:
                pikaTTSURL = URL(string: raw[index + 1])
                index += 2
            case "--pika-stt-url" where index + 1 < raw.count:
                pikaSTTURL = URL(string: raw[index + 1])
                index += 2
            case "--realtime-stt-url" where index + 1 < raw.count:
                realtimeSTTURL = URL(string: raw[index + 1])
                index += 2
            case "--character", "--pet":
                if index + 1 < raw.count {
                    character = CompanionCharacter.parse(raw[index + 1]) ?? character
                    index += 2
                } else {
                    index += 1
                }
            case "--launch-server":
                launchServer = true
                index += 1
            default:
                index += 1
            }
        }

        let environmentRoot = ProcessInfo.processInfo.environment["POCKETDM_REPO"]
        let repoRoot = URL(fileURLWithPath: environmentRoot ?? FileManager.default.currentDirectoryPath)
        if let environmentCharacter = ProcessInfo.processInfo.environment["POCKETDM_COMPANION_CHARACTER"] {
            character = CompanionCharacter.parse(environmentCharacter) ?? character
        }
        if pikaTTSURL == nil,
           let environmentPikaTTSURL = ProcessInfo.processInfo.environment["POCKETDM_PIKA_TTS_URL"] {
            pikaTTSURL = URL(string: environmentPikaTTSURL)
        }
        if let pikaTTSURL {
            setenv("POCKETDM_PIKA_TTS_URL", pikaTTSURL.absoluteString, 1)
        }
        if pikaSTTURL == nil,
           let environmentPikaSTTURL = ProcessInfo.processInfo.environment["POCKETDM_PIKA_STT_URL"] {
            pikaSTTURL = URL(string: environmentPikaSTTURL)
        }
        if let pikaSTTURL {
            setenv("POCKETDM_PIKA_STT_URL", pikaSTTURL.absoluteString, 1)
        }
        if realtimeSTTURL == nil,
           let environmentRealtimeSTTURL = ProcessInfo.processInfo.environment["POCKETDM_REALTIME_STT_URL"] {
            realtimeSTTURL = URL(string: environmentRealtimeSTTURL)
        }
        if let realtimeSTTURL {
            setenv("POCKETDM_REALTIME_STT_URL", realtimeSTTURL.absoluteString, 1)
        }
        return CompanionArguments(
            baseURL: baseURL,
            launchServer: launchServer,
            repoRoot: repoRoot,
            character: character,
            pikaTTSURL: pikaTTSURL,
            pikaSTTURL: pikaSTTURL,
            realtimeSTTURL: realtimeSTTURL
        )
    }
}

enum CompanionCharacter: String, CaseIterable, Identifiable {
    case pika

    var id: String { rawValue }

    static let defaultsKey = "PocketDMCompanion.character"

    static var savedDefault: CompanionCharacter {
        parse(UserDefaults.standard.string(forKey: defaultsKey)) ?? .pika
    }

    static func parse(_ raw: String?) -> CompanionCharacter? {
        guard let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return nil
        }
        switch normalized {
        case "pika", "pikachu", "/pika", "/pikachu":
            return .pika
        default:
            return nil
        }
    }

    static func isPausedGoldAlias(_ raw: String) -> Bool {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["gold", "golden", "goldie", "mascot", "/gold", "/golden", "/goldie"].contains(normalized)
    }

    var title: String {
        "Pikachu"
    }

    var shortTitle: String {
        "Pika"
    }

    var catchphrase: String {
        "Pika pika!"
    }

    var voiceCatchphrase: String {
        "Pikaa Pikaa!"
    }

    var normalizedCatchphrase: String {
        catchphrase.lowercased().filter(\.isLetter)
    }

    var welcomeBody: String {
        "Your electric partner keeps a tiny bond spark. Pet once each day to earn +1 HP and refill joy."
    }

    var iconName: String {
        "bolt.fill"
    }

    var voiceSummary: String {
        "Cute female chirp voice"
    }

    var voiceProfileName: String {
        "Pika soft voice"
    }

    var selectedVoiceName: String {
        Self.preferredSpeechVoice(for: self)?.name ?? "System voice"
    }

    var commandHint: String {
        "/\(rawValue)"
    }

    var launchHint: String {
        "--character \(rawValue)"
    }

    var voiceRate: Float {
        0.50
    }

    var voiceVolume: Float {
        0.44
    }

    var voicePitch: Float {
        1.30
    }

    var catchphraseVoiceRate: Float {
        0.62
    }

    var catchphraseVoiceVolume: Float {
        0.52
    }

    var catchphraseVoicePitch: Float {
        1.56
    }

    var preferredVoiceNames: [String] {
        ["Sandy", "Nicky", "Shelley", "Flo", "Samantha", "Ava", "Susan", "Victoria"]
    }

    static func preferredSpeechVoice(for character: CompanionCharacter) -> AVSpeechSynthesisVoice? {
        let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        for preferredName in character.preferredVoiceNames {
            if let voice = englishVoices.first(where: { $0.name.localizedCaseInsensitiveContains(preferredName) }) {
                return voice
            }
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    func rewrite(_ text: String) -> String {
        text
    }

    func spriteCandidates(stage: PetGrowthStage, mood: PetMood) -> [String] {
        mood.spriteCandidates(stage: stage)
    }
}

@MainActor
final class DragonOverlayController {
    private static let minimizedSize = NSSize(width: 216, height: 224)
    private static let expandedSize = NSSize(width: 620, height: 620)
    private static let expandedMinimumSize = NSSize(width: 520, height: 430)

    private let panel: NSPanel
    private let model: DragonOverlayModel

    init(client: PocketDMClient, launcher: GameLauncher, character: CompanionCharacter, repoRoot: URL) {
        model = DragonOverlayModel(client: client, launcher: launcher, initialCharacter: character)
        panel = FloatingDragonPanel()
        PetSpriteSheet.externalAssetDirectory = repoRoot.appending(path: "output/sprite-sheets", directoryHint: .isDirectory)

        let content = DragonOverlayView(
            model: model,
            onDrag: { [weak self] delta in
                guard let self else { return }
                var frame = self.panel.frame
                frame.origin.x += delta.width
                frame.origin.y -= delta.height
                self.panel.setFrame(self.clamped(frame), display: true)
            },
            onDragEnded: { [weak self] in
                guard let self else { return }
                self.panel.setFrame(self.clamped(self.panel.frame), display: true)
                self.persistFrame()
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

    func showExpanded() {
        panel.orderFrontRegardless()
        model.setMinimized(false)
        setMinimized(false, animated: false)
        Task { await model.refreshHealth() }
    }

    func showPetOnly() {
        panel.orderFrontRegardless()
        model.setMinimized(true)
        setMinimized(true, animated: false)
    }

    func toggleSound() {
        model.toggleSound()
    }

    func prepareClose() {
        model.prepareClose()
    }

    var soundEnabled: Bool {
        model.soundEnabled
    }

    private func setMinimized(_ minimized: Bool, animated: Bool = true) {
        var frame = panel.frame
        let size = fittedSize(minimized ? Self.minimizedSize : Self.expandedSize, minimum: minimized ? Self.minimizedSize : Self.expandedMinimumSize, relativeTo: frame)
        let top = frame.maxY
        frame.size = size
        frame.origin.y = top - size.height
        panel.setFrame(clamped(frame), display: true, animate: animated)
        persistFrame()
    }

    private func restoreFrame() {
        let defaults = UserDefaults.standard
        let savedX = defaults.double(forKey: "PocketDMCompanion.x")
        let savedY = defaults.double(forKey: "PocketDMCompanion.y")
        let defaultSize = model.minimized ? Self.minimizedSize : Self.expandedSize
        let savedOrigin = NSPoint(x: savedX, y: savedY)
        let savedFrame = NSRect(origin: savedOrigin, size: defaultSize)
        let screen = activeScreen(for: savedFrame).visibleFrame
        let fittedSize = self.fittedSize(defaultSize, minimum: model.minimized ? Self.minimizedSize : Self.expandedMinimumSize, visibleFrame: screen)
        let defaultOrigin = NSPoint(x: screen.maxX - fittedSize.width - 16, y: screen.minY + 72)
        let savedCenter = NSPoint(x: savedFrame.midX, y: savedFrame.midY)
        let savedFrameIsVisible = screen.insetBy(dx: -24, dy: -24).contains(savedCenter)
        let origin = (savedX == 0 && savedY == 0) || !savedFrameIsVisible ? defaultOrigin : savedOrigin
        let restoredFrame = NSRect(origin: origin, size: fittedSize)
        panel.setFrame(clamped(restoredFrame), display: false)
    }

    private func persistFrame() {
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: "PocketDMCompanion.x")
        UserDefaults.standard.set(origin.y, forKey: "PocketDMCompanion.y")
    }

    private func clamped(_ frame: NSRect) -> NSRect {
        let screen = activeScreen(for: frame).visibleFrame
        var next = frame
        let availableWidth = max(Self.minimizedSize.width, screen.width - 16)
        let availableHeight = max(Self.minimizedSize.height, screen.height - 48)
        next.size.width = min(next.width, availableWidth)
        next.size.height = min(next.height, availableHeight)
        let minX = screen.minX + 8
        let maxX = max(minX, screen.maxX - next.width - 8)
        let minY = screen.minY + 8
        let maxY = max(minY, screen.maxY - next.height - 28)
        next.origin.x = min(max(next.origin.x, minX), maxX)
        next.origin.y = min(max(next.origin.y, minY), maxY)
        return next
    }

    private func fittedSize(_ desired: NSSize, minimum: NSSize, relativeTo frame: NSRect) -> NSSize {
        fittedSize(desired, minimum: minimum, visibleFrame: activeScreen(for: frame).visibleFrame)
    }

    private func fittedSize(_ desired: NSSize, minimum: NSSize, visibleFrame: NSRect) -> NSSize {
        let availableWidth = max(Self.minimizedSize.width, visibleFrame.width - 16)
        let availableHeight = max(Self.minimizedSize.height, visibleFrame.height - 48)
        let width = availableWidth >= minimum.width ? min(desired.width, availableWidth) : availableWidth
        let height = availableHeight >= minimum.height ? min(desired.height, availableHeight) : availableHeight
        return NSSize(width: width, height: height)
    }

    private func activeScreen(for frame: NSRect) -> NSScreen {
        if let screen = panel.screen {
            return screen
        }
        if let intersecting = NSScreen.screens.max(by: {
            $0.visibleFrame.intersection(frame).area < $1.visibleFrame.intersection(frame).area
        }), intersecting.visibleFrame.intersects(frame) {
            return intersecting
        }
        let center = NSPoint(x: frame.midX, y: frame.midY)
        if let containing = NSScreen.screens.first(where: { $0.visibleFrame.contains(center) }) {
            return containing
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }
}

private extension NSRect {
    var area: CGFloat {
        max(0, width) * max(0, height)
    }
}

final class FloatingDragonPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 632, height: 610),
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

enum PetDaypartAffirmation: Int, CaseIterable {
    case morning = 1
    case afternoon = 2
    case evening = 4
    case night = 8

    static func current(hour: Int) -> PetDaypartAffirmation {
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<22:
            return .evening
        default:
            return .night
        }
    }

    var title: String {
        switch self {
        case .morning:
            return "Morning Spark"
        case .afternoon:
            return "Afternoon Reset"
        case .evening:
            return "Evening Wrap"
        case .night:
            return "Night Rest"
        }
    }

    var actionTitle: String {
        switch self {
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        case .night:
            return "Night"
        }
    }

    var line: String {
        switch self {
        case .morning:
            return "Start with one tiny win. I will cheer when it lands."
        case .afternoon:
            return "One breath, one sip of water, one clear next step."
        case .evening:
            return "Close one loose thread and let tomorrow begin lighter."
        case .night:
            return "Rest is care. Your spark can wait safely until morning."
        }
    }

    var mood: PetMood {
        switch self {
        case .morning:
            return .happy
        case .afternoon:
            return .stretch
        case .evening:
            return .perch
        case .night:
            return .nap
        }
    }
}

enum VoiceConversationMode {
    case freeform
    case dailyCheckIn

    var listeningLine: String {
        switch self {
        case .freeform:
            return "Listening..."
        case .dailyCheckIn:
            return "Daily check-in. Say how you feel."
        }
    }

    var requestLabel: String {
        switch self {
        case .freeform:
            return "Voice"
        case .dailyCheckIn:
            return "Daily voice"
        }
    }
}

enum VoiceVisualState: String {
    case idle
    case listening
    case transcribing
    case thinking
    case speaking

    var isAnimated: Bool {
        switch self {
        case .idle:
            return false
        case .listening, .transcribing, .thinking, .speaking:
            return true
        }
    }

    var title: String {
        switch self {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .thinking:
            return "Thinking"
        case .speaking:
            return "Pika speaking"
        }
    }
}

struct PetOnlyBubbleContent {
    let title: String
    let body: String
    let footer: String
}

struct CompanionChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
        case status
    }

    let id: UUID
    var role: Role
    var text: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

enum DailyWellnessAction: Int, CaseIterable, Hashable {
    case water = 1
    case stand = 2
    case walk = 4
    case affirm = 8

    var title: String {
        switch self {
        case .water:
            return "Water"
        case .stand:
            return "Stand"
        case .walk:
            return "Walk"
        case .affirm:
            return "Affirm"
        }
    }

    var question: String {
        switch self {
        case .water:
            return "Did you drink water?"
        case .stand:
            return "Did you stand up?"
        case .walk:
            return "Did you take a short walk?"
        case .affirm:
            return "Want one affirmation?"
        }
    }

    var actionTitle: String {
        switch self {
        case .water:
            return "I drank water"
        case .stand:
            return "I stood up"
        case .walk:
            return "I walked"
        case .affirm:
            return "Affirm me"
        }
    }

    var systemImage: String {
        switch self {
        case .water:
            return "drop.fill"
        case .stand:
            return "figure.stand"
        case .walk:
            return "figure.walk"
        case .affirm:
            return "sparkles"
        }
    }

    var vital: PetCareVital {
        switch self {
        case .water:
            return .snack
        case .stand:
            return .rest
        case .walk:
            return .play
        case .affirm:
            return .focus
        }
    }

    var mood: PetMood {
        switch self {
        case .water:
            return .snack
        case .stand:
            return .stretch
        case .walk:
            return .hyper
        case .affirm:
            return .look
        }
    }

    var spokenLine: String {
        switch self {
        case .water:
            return "I drank water."
        case .stand:
            return "I stood up."
        case .walk:
            return "I walked."
        case .affirm:
            return "I did one affirmation."
        }
    }
}

struct MorningWeatherReport: Decodable {
    struct Current: Decodable {
        let temperature2m: Double?
        let apparentTemperature: Double?
        let precipitation: Double?
        let weatherCode: Int?
        let cloudCover: Double?
        let windSpeed10m: Double?

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case precipitation
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case windSpeed10m = "wind_speed_10m"
        }
    }

    let current: Current?
}

@MainActor
final class DragonOverlayModel: ObservableObject {
    private static let petOnlyKey = "PocketDMCompanion.petOnly"
    private static let soundEnabledKey = "PocketDMCompanion.soundEnabled"
    private static let chatMessagesKey = "PocketDMCompanion.chatMessages"
    private static let companionHPKey = "PocketDMCompanion.companionHP"
    private static let companionHealthKey = "PocketDMCompanion.companionHealth"
    private static let happinessKey = "PocketDMCompanion.happiness"
    private static let petStreakKey = "PocketDMCompanion.petStreak"
    private static let lastPetDayKey = "PocketDMCompanion.lastPetDay"
    private static let sparkDustKey = "PocketDMCompanion.sparkDust"
    private static let energyKey = "PocketDMCompanion.energy"
    private static let lastEnergyAtKey = "PocketDMCompanion.lastEnergyAt"
    private static let lastCheerAtKey = "PocketDMCompanion.lastCheerAt"
    private static let cheerIndexKey = "PocketDMCompanion.cheerIndex"
    private static let dailyComboDateKey = "PocketDMCompanion.dailyComboDate"
    private static let dailyComboMaskKey = "PocketDMCompanion.dailyComboMask"
    private static let passiveSparkAtKey = "PocketDMCompanion.passiveSparkAt"
    private static let snackLevelKey = "PocketDMCompanion.snackLevel"
    private static let lessonLevelKey = "PocketDMCompanion.lessonLevel"
    private static let questLevelKey = "PocketDMCompanion.questLevel"
    private static let nestLevelKey = "PocketDMCompanion.nestLevel"
    private static let cheerLevelKey = "PocketDMCompanion.cheerLevel"
    private static let sparkLevelKey = "PocketDMCompanion.sparkLevel"
    private static let focusLevelKey = "PocketDMCompanion.focusLevel"
    private static let cipherLevelKey = "PocketDMCompanion.cipherLevel"
    private static let dailyQuestDateKey = "PocketDMCompanion.dailyQuestDate"
    private static let dailyQuestMaskKey = "PocketDMCompanion.dailyQuestMask"
    private static let dailyBondBoardDateKey = "PocketDMCompanion.dailyBondBoardDate"
    private static let dailyBondBoardMaskKey = "PocketDMCompanion.dailyBondBoardMask"
    private static let bondContractAlbumMaskKey = "PocketDMCompanion.bondContractAlbumMask"
    private static let dailyBoosterDateKey = "PocketDMCompanion.dailyBoosterDate"
    private static let dailyBoosterUsedKey = "PocketDMCompanion.dailyBoosterUsed"
    private static let dailyCipherDateKey = "PocketDMCompanion.dailyCipherDate"
    private static let dailyCipherSolvedKey = "PocketDMCompanion.dailyCipherSolved"
    private static let lastLifecycleAtKey = "PocketDMCompanion.lastLifecycleAt"
    private static let lastComebackChestDayKey = "PocketDMCompanion.lastComebackChestDay"
    private static let careMemoryMaskKey = "PocketDMCompanion.careMemoryMask"
    private static let lifeSceneMaskKey = "PocketDMCompanion.lifeSceneMask"
    private static let dailyBondTimelineDateKey = "PocketDMCompanion.dailyBondTimelineDate"
    private static let dailyBondTimelineOfferedMaskKey = "PocketDMCompanion.dailyBondTimelineOfferedMask"
    private static let dailyBondTimelineSavedMaskKey = "PocketDMCompanion.dailyBondTimelineSavedMask"
    private static let dailyBondTimelineDismissedMaskKey = "PocketDMCompanion.dailyBondTimelineDismissedMask"
    private static let bondTimelineAlbumMaskKey = "PocketDMCompanion.bondTimelineAlbumMask"
    private static let latestBondTimelineRawKey = "PocketDMCompanion.latestBondTimelineRaw"
    private static let careCharmMaskKey = "PocketDMCompanion.careCharmMask"
    private static let evolutionQuestMaskKey = "PocketDMCompanion.evolutionQuestMask"
    private static let growthJourneyMaskKey = "PocketDMCompanion.growthJourneyMask"
    private static let latestGrowthStageRawKey = "PocketDMCompanion.latestGrowthStageRaw"
    private static let lastNeedBonusDayKey = "PocketDMCompanion.lastNeedBonusDay"
    private static let dailyEventDateKey = "PocketDMCompanion.dailyEventDate"
    private static let dailyEventProgressKey = "PocketDMCompanion.dailyEventProgress"
    private static let seasonBadgeMaskKey = "PocketDMCompanion.seasonBadgeMask"
    private static let seasonTrailWeekKey = "PocketDMCompanion.seasonTrailWeek"
    private static let seasonTrailMaskKey = "PocketDMCompanion.seasonTrailMask"
    private static let seasonTrailAlbumMaskKey = "PocketDMCompanion.seasonTrailAlbumMask"
    private static let latestSeasonTrailRawKey = "PocketDMCompanion.latestSeasonTrailRaw"
    private static let dailyFeelingDateKey = "PocketDMCompanion.dailyFeelingDate"
    private static let dailyFeelingMaskKey = "PocketDMCompanion.dailyFeelingMask"
    private static let emotionAlbumMaskKey = "PocketDMCompanion.emotionAlbumMask"
    private static let latestFeelingRawKey = "PocketDMCompanion.latestFeelingRaw"
    private static let dailyEmotionWheelDateKey = "PocketDMCompanion.dailyEmotionWheelDate"
    private static let dailyEmotionWheelRawKey = "PocketDMCompanion.dailyEmotionWheelRaw"
    private static let dailyEmotionEpisodeDateKey = "PocketDMCompanion.dailyEmotionEpisodeDate"
    private static let dailyEmotionEpisodeMaskKey = "PocketDMCompanion.dailyEmotionEpisodeMask"
    private static let emotionEpisodeAlbumMaskKey = "PocketDMCompanion.emotionEpisodeAlbumMask"
    private static let latestEmotionEpisodeRawKey = "PocketDMCompanion.latestEmotionEpisodeRaw"
    private static let dailyEmotionArcDateKey = "PocketDMCompanion.dailyEmotionArcDate"
    private static let dailyEmotionArcMaskKey = "PocketDMCompanion.dailyEmotionArcMask"
    private static let emotionArcAlbumMaskKey = "PocketDMCompanion.emotionArcAlbumMask"
    private static let latestEmotionArcRawKey = "PocketDMCompanion.latestEmotionArcRaw"
    private static let dailyMoodCareDateKey = "PocketDMCompanion.dailyMoodCareDate"
    private static let dailyMoodCareFeelingRawKey = "PocketDMCompanion.dailyMoodCareFeelingRaw"
    private static let dailyMoodCareMaskKey = "PocketDMCompanion.dailyMoodCareMask"
    private static let moodCareAlbumMaskKey = "PocketDMCompanion.moodCareAlbumMask"
    private static let weeklyCareWeekKey = "PocketDMCompanion.weeklyCareWeek"
    private static let weeklyCareCountKey = "PocketDMCompanion.weeklyCareCount"
    private static let weeklyRewardMaskKey = "PocketDMCompanion.weeklyRewardMask"
    private static let weeklyTrailAlbumMaskKey = "PocketDMCompanion.weeklyTrailAlbumMask"
    private static let streakShieldCountKey = "PocketDMCompanion.streakShieldCount"
    private static let recoveryAlbumMaskKey = "PocketDMCompanion.recoveryAlbumMask"
    private static let latestRecoverySceneRawKey = "PocketDMCompanion.latestRecoverySceneRaw"
    private static let dailyNudgeDateKey = "PocketDMCompanion.dailyNudgeDate"
    private static let dailyNudgeOfferedMaskKey = "PocketDMCompanion.dailyNudgeOfferedMask"
    private static let dailyNudgeAnsweredMaskKey = "PocketDMCompanion.dailyNudgeAnsweredMask"
    private static let dailyNudgeDismissedMaskKey = "PocketDMCompanion.dailyNudgeDismissedMask"
    private static let dailyCheerPingDateKey = "PocketDMCompanion.dailyCheerPingDate"
    private static let dailyCheerPingOfferedMaskKey = "PocketDMCompanion.dailyCheerPingOfferedMask"
    private static let dailyCheerPingAnsweredMaskKey = "PocketDMCompanion.dailyCheerPingAnsweredMask"
    private static let dailyCheerPingDismissedMaskKey = "PocketDMCompanion.dailyCheerPingDismissedMask"
    private static let cheerPingAlbumMaskKey = "PocketDMCompanion.cheerPingAlbumMask"
    private static let latestCheerPingRawKey = "PocketDMCompanion.latestCheerPingRaw"
    private static let dailyMoodWeatherDateKey = "PocketDMCompanion.dailyMoodWeatherDate"
    private static let dailyMoodWeatherOfferedMaskKey = "PocketDMCompanion.dailyMoodWeatherOfferedMask"
    private static let dailyMoodWeatherAnsweredMaskKey = "PocketDMCompanion.dailyMoodWeatherAnsweredMask"
    private static let dailyMoodWeatherDismissedMaskKey = "PocketDMCompanion.dailyMoodWeatherDismissedMask"
    private static let moodWeatherAlbumMaskKey = "PocketDMCompanion.moodWeatherAlbumMask"
    private static let latestMoodWeatherRawKey = "PocketDMCompanion.latestMoodWeatherRaw"
    private static let dailyJourneyDateKey = "PocketDMCompanion.dailyJourneyDate"
    private static let dailyJourneyOfferedMaskKey = "PocketDMCompanion.dailyJourneyOfferedMask"
    private static let dailyJourneyAnsweredMaskKey = "PocketDMCompanion.dailyJourneyAnsweredMask"
    private static let dailyJourneyDismissedMaskKey = "PocketDMCompanion.dailyJourneyDismissedMask"
    private static let journeyAlbumMaskKey = "PocketDMCompanion.journeyAlbumMask"
    private static let latestJourneyRawKey = "PocketDMCompanion.latestJourneyRaw"
    private static let dailyVisitDateKey = "PocketDMCompanion.dailyVisitDate"
    private static let dailyVisitOfferedMaskKey = "PocketDMCompanion.dailyVisitOfferedMask"
    private static let dailyVisitAnsweredMaskKey = "PocketDMCompanion.dailyVisitAnsweredMask"
    private static let dailyVisitDismissedMaskKey = "PocketDMCompanion.dailyVisitDismissedMask"
    private static let visitAlbumMaskKey = "PocketDMCompanion.visitAlbumMask"
    private static let latestVisitRawKey = "PocketDMCompanion.latestVisitRaw"
    private static let dailySparkWheelDateKey = "PocketDMCompanion.dailySparkWheelDate"
    private static let dailySparkWheelOfferedMaskKey = "PocketDMCompanion.dailySparkWheelOfferedMask"
    private static let dailySparkWheelStartedMaskKey = "PocketDMCompanion.dailySparkWheelStartedMask"
    private static let dailySparkWheelClaimedMaskKey = "PocketDMCompanion.dailySparkWheelClaimedMask"
    private static let dailySparkWheelDismissedMaskKey = "PocketDMCompanion.dailySparkWheelDismissedMask"
    private static let sparkWheelAlbumMaskKey = "PocketDMCompanion.sparkWheelAlbumMask"
    private static let latestSparkWheelRawKey = "PocketDMCompanion.latestSparkWheelRaw"
    private static let activeSparkWheelRawKey = "PocketDMCompanion.activeSparkWheelRaw"
    private static let activeSparkWheelStartedAtKey = "PocketDMCompanion.activeSparkWheelStartedAt"
    private static let dailyExchangeDateKey = "PocketDMCompanion.dailyExchangeDate"
    private static let dailyExchangeOfferedMaskKey = "PocketDMCompanion.dailyExchangeOfferedMask"
    private static let dailyExchangeAnsweredMaskKey = "PocketDMCompanion.dailyExchangeAnsweredMask"
    private static let dailyExchangeDismissedMaskKey = "PocketDMCompanion.dailyExchangeDismissedMask"
    private static let exchangeAlbumMaskKey = "PocketDMCompanion.exchangeAlbumMask"
    private static let latestExchangeRawKey = "PocketDMCompanion.latestExchangeRaw"
    private static let dailyCheerDialogueDateKey = "PocketDMCompanion.dailyCheerDialogueDate"
    private static let dailyCheerDialogueOfferedMaskKey = "PocketDMCompanion.dailyCheerDialogueOfferedMask"
    private static let dailyCheerDialogueAnsweredMaskKey = "PocketDMCompanion.dailyCheerDialogueAnsweredMask"
    private static let dailyCheerDialogueDismissedMaskKey = "PocketDMCompanion.dailyCheerDialogueDismissedMask"
    private static let cheerDialogueAlbumMaskKey = "PocketDMCompanion.cheerDialogueAlbumMask"
    private static let dailyCheerIntentDateKey = "PocketDMCompanion.dailyCheerIntentDate"
    private static let dailyCheerIntentOfferedMaskKey = "PocketDMCompanion.dailyCheerIntentOfferedMask"
    private static let dailyCheerIntentAnsweredMaskKey = "PocketDMCompanion.dailyCheerIntentAnsweredMask"
    private static let dailyCheerIntentDismissedMaskKey = "PocketDMCompanion.dailyCheerIntentDismissedMask"
    private static let cheerIntentAlbumMaskKey = "PocketDMCompanion.cheerIntentAlbumMask"
    private static let dailyCheerMemoryDateKey = "PocketDMCompanion.dailyCheerMemoryDate"
    private static let dailyCheerMemoryMaskKey = "PocketDMCompanion.dailyCheerMemoryMask"
    private static let cheerMemoryAlbumMaskKey = "PocketDMCompanion.cheerMemoryAlbumMask"
    private static let latestCheerMemoryRawKey = "PocketDMCompanion.latestCheerMemoryRaw"
    private static let dailyCheerScriptDateKey = "PocketDMCompanion.dailyCheerScriptDate"
    private static let dailyCheerScriptOfferedMaskKey = "PocketDMCompanion.dailyCheerScriptOfferedMask"
    private static let dailyCheerScriptAnsweredMaskKey = "PocketDMCompanion.dailyCheerScriptAnsweredMask"
    private static let dailyCheerScriptDismissedMaskKey = "PocketDMCompanion.dailyCheerScriptDismissedMask"
    private static let cheerScriptAlbumMaskKey = "PocketDMCompanion.cheerScriptAlbumMask"
    private static let dailyMoodStoryDateKey = "PocketDMCompanion.dailyMoodStoryDate"
    private static let dailyMoodStoryOfferedMaskKey = "PocketDMCompanion.dailyMoodStoryOfferedMask"
    private static let dailyMoodStoryAnsweredMaskKey = "PocketDMCompanion.dailyMoodStoryAnsweredMask"
    private static let dailyMoodStoryDismissedMaskKey = "PocketDMCompanion.dailyMoodStoryDismissedMask"
    private static let moodStoryAlbumMaskKey = "PocketDMCompanion.moodStoryAlbumMask"
    private static let latestMoodStoryRawKey = "PocketDMCompanion.latestMoodStoryRaw"
    private static let dailyFeelingRitualDateKey = "PocketDMCompanion.dailyFeelingRitualDate"
    private static let dailyFeelingRitualOfferedMaskKey = "PocketDMCompanion.dailyFeelingRitualOfferedMask"
    private static let dailyFeelingRitualAnsweredMaskKey = "PocketDMCompanion.dailyFeelingRitualAnsweredMask"
    private static let dailyFeelingRitualDismissedMaskKey = "PocketDMCompanion.dailyFeelingRitualDismissedMask"
    private static let feelingRitualAlbumMaskKey = "PocketDMCompanion.feelingRitualAlbumMask"
    private static let latestFeelingRitualRawKey = "PocketDMCompanion.latestFeelingRitualRaw"
    private static let dailyCareChestDateKey = "PocketDMCompanion.dailyCareChestDate"
    private static let dailyCareChestOfferedMaskKey = "PocketDMCompanion.dailyCareChestOfferedMask"
    private static let dailyCareChestClaimedMaskKey = "PocketDMCompanion.dailyCareChestClaimedMask"
    private static let dailyCareChestDismissedMaskKey = "PocketDMCompanion.dailyCareChestDismissedMask"
    private static let careChestAlbumMaskKey = "PocketDMCompanion.careChestAlbumMask"
    private static let latestCareChestRawKey = "PocketDMCompanion.latestCareChestRaw"
    private static let dailyFieldNoteDateKey = "PocketDMCompanion.dailyFieldNoteDate"
    private static let dailyFieldNoteOfferedMaskKey = "PocketDMCompanion.dailyFieldNoteOfferedMask"
    private static let dailyFieldNoteSavedMaskKey = "PocketDMCompanion.dailyFieldNoteSavedMask"
    private static let dailyFieldNoteDismissedMaskKey = "PocketDMCompanion.dailyFieldNoteDismissedMask"
    private static let fieldNoteAlbumMaskKey = "PocketDMCompanion.fieldNoteAlbumMask"
    private static let latestFieldNoteRawKey = "PocketDMCompanion.latestFieldNoteRaw"
    private static let dailyScoutTripDateKey = "PocketDMCompanion.dailyScoutTripDate"
    private static let dailyScoutTripStartedMaskKey = "PocketDMCompanion.dailyScoutTripStartedMask"
    private static let dailyScoutTripReturnedMaskKey = "PocketDMCompanion.dailyScoutTripReturnedMask"
    private static let scoutTripAlbumMaskKey = "PocketDMCompanion.scoutTripAlbumMask"
    private static let latestScoutTripRawKey = "PocketDMCompanion.latestScoutTripRaw"
    private static let activeScoutTripRawKey = "PocketDMCompanion.activeScoutTripRaw"
    private static let activeScoutTripStartedAtKey = "PocketDMCompanion.activeScoutTripStartedAt"
    private static let dailyAffectionDateKey = "PocketDMCompanion.dailyAffectionDate"
    private static let dailyAffectionOfferedMaskKey = "PocketDMCompanion.dailyAffectionOfferedMask"
    private static let dailyAffectionGivenMaskKey = "PocketDMCompanion.dailyAffectionGivenMask"
    private static let dailyAffectionDismissedMaskKey = "PocketDMCompanion.dailyAffectionDismissedMask"
    private static let affectionAlbumMaskKey = "PocketDMCompanion.affectionAlbumMask"
    private static let latestAffectionRawKey = "PocketDMCompanion.latestAffectionRaw"
    private static let dailyHomeDateKey = "PocketDMCompanion.dailyHomeDate"
    private static let dailyHomeOfferedMaskKey = "PocketDMCompanion.dailyHomeOfferedMask"
    private static let dailyHomeVisitedMaskKey = "PocketDMCompanion.dailyHomeVisitedMask"
    private static let dailyHomeDismissedMaskKey = "PocketDMCompanion.dailyHomeDismissedMask"
    private static let homeAlbumMaskKey = "PocketDMCompanion.homeAlbumMask"
    private static let latestHomeRoomRawKey = "PocketDMCompanion.latestHomeRoomRaw"
    private static let dailyErrandDateKey = "PocketDMCompanion.dailyErrandDate"
    private static let dailyErrandOfferedMaskKey = "PocketDMCompanion.dailyErrandOfferedMask"
    private static let dailyErrandDoneMaskKey = "PocketDMCompanion.dailyErrandDoneMask"
    private static let dailyErrandDismissedMaskKey = "PocketDMCompanion.dailyErrandDismissedMask"
    private static let errandAlbumMaskKey = "PocketDMCompanion.errandAlbumMask"
    private static let latestErrandRawKey = "PocketDMCompanion.latestErrandRaw"
    private static let dailyUserCheckDateKey = "PocketDMCompanion.dailyUserCheckDate"
    private static let dailyUserCheckOfferedMaskKey = "PocketDMCompanion.dailyUserCheckOfferedMask"
    private static let dailyUserCheckAnsweredMaskKey = "PocketDMCompanion.dailyUserCheckAnsweredMask"
    private static let dailyUserCheckDismissedMaskKey = "PocketDMCompanion.dailyUserCheckDismissedMask"
    private static let userCheckAlbumMaskKey = "PocketDMCompanion.userCheckAlbumMask"
    private static let latestUserCheckRawKey = "PocketDMCompanion.latestUserCheckRaw"
    private static let dailyWishDateKey = "PocketDMCompanion.dailyWishDate"
    private static let dailyWishOfferedMaskKey = "PocketDMCompanion.dailyWishOfferedMask"
    private static let dailyWishFulfilledMaskKey = "PocketDMCompanion.dailyWishFulfilledMask"
    private static let dailyWishDismissedMaskKey = "PocketDMCompanion.dailyWishDismissedMask"
    private static let wishAlbumMaskKey = "PocketDMCompanion.wishAlbumMask"
    private static let latestWishRawKey = "PocketDMCompanion.latestWishRaw"
    private static let dailyToyDateKey = "PocketDMCompanion.dailyToyDate"
    private static let dailyToyOfferedMaskKey = "PocketDMCompanion.dailyToyOfferedMask"
    private static let dailyToyPlayedMaskKey = "PocketDMCompanion.dailyToyPlayedMask"
    private static let dailyToyDismissedMaskKey = "PocketDMCompanion.dailyToyDismissedMask"
    private static let toyAlbumMaskKey = "PocketDMCompanion.toyAlbumMask"
    private static let latestToyRawKey = "PocketDMCompanion.latestToyRaw"
    private static let dailyTrickDateKey = "PocketDMCompanion.dailyTrickDate"
    private static let dailyTrickOfferedMaskKey = "PocketDMCompanion.dailyTrickOfferedMask"
    private static let dailyTrickPracticedMaskKey = "PocketDMCompanion.dailyTrickPracticedMask"
    private static let dailyTrickDismissedMaskKey = "PocketDMCompanion.dailyTrickDismissedMask"
    private static let trickAlbumMaskKey = "PocketDMCompanion.trickAlbumMask"
    private static let latestTrickRawKey = "PocketDMCompanion.latestTrickRaw"
    private static let dailyAmbientDateKey = "PocketDMCompanion.dailyAmbientDate"
    private static let dailyAmbientMaskKey = "PocketDMCompanion.dailyAmbientMask"
    private static let ambientAlbumMaskKey = "PocketDMCompanion.ambientAlbumMask"
    private static let latestAmbientMomentRawKey = "PocketDMCompanion.latestAmbientMomentRaw"
    private static let lastAmbientAtKey = "PocketDMCompanion.lastAmbientAt"
    private static let dailyRouteDateKey = "PocketDMCompanion.dailyRouteDate"
    private static let dailyRouteMaskKey = "PocketDMCompanion.dailyRouteMask"
    private static let dailyRouteOfferedMaskKey = "PocketDMCompanion.dailyRouteOfferedMask"
    private static let dailyRouteDismissedMaskKey = "PocketDMCompanion.dailyRouteDismissedMask"
    private static let routeAlbumMaskKey = "PocketDMCompanion.routeAlbumMask"
    private static let latestRouteStepRawKey = "PocketDMCompanion.latestRouteStepRaw"
    private static let dailyCarePulseDateKey = "PocketDMCompanion.dailyCarePulseDate"
    private static let dailyCarePulseOfferedMaskKey = "PocketDMCompanion.dailyCarePulseOfferedMask"
    private static let dailyCarePulseAnsweredMaskKey = "PocketDMCompanion.dailyCarePulseAnsweredMask"
    private static let dailyCarePulseDismissedMaskKey = "PocketDMCompanion.dailyCarePulseDismissedMask"
    private static let carePulseAlbumMaskKey = "PocketDMCompanion.carePulseAlbumMask"
    private static let latestCarePulseRawKey = "PocketDMCompanion.latestCarePulseRaw"
    private static let dailyCareWindowDateKey = "PocketDMCompanion.dailyCareWindowDate"
    private static let dailyCareWindowMaskKey = "PocketDMCompanion.dailyCareWindowMask"
    private static let careWindowAlbumMaskKey = "PocketDMCompanion.careWindowAlbumMask"
    private static let latestCareWindowRawKey = "PocketDMCompanion.latestCareWindowRaw"
    private static let dailyAffirmationDateKey = "PocketDMCompanion.dailyAffirmationDate"
    private static let dailyAffirmationMaskKey = "PocketDMCompanion.dailyAffirmationMask"
    private static let dailyWellnessDateKey = "PocketDMCompanion.dailyWellnessDate"
    private static let dailyWellnessMaskKey = "PocketDMCompanion.dailyWellnessMask"
    private static let morningWeatherDateKey = "PocketDMCompanion.morningWeatherDate"
    private static let morningWeatherLineKey = "PocketDMCompanion.morningWeatherLine"
    private static let lastWellnessBreakAtKey = "PocketDMCompanion.lastWellnessBreakAt"
    private static let snackVitalKey = "PocketDMCompanion.snackVital"
    private static let restVitalKey = "PocketDMCompanion.restVital"
    private static let playVitalKey = "PocketDMCompanion.playVital"
    private static let focusVitalKey = "PocketDMCompanion.focusVital"
    private static let lastVitalAtKey = "PocketDMCompanion.lastVitalAt"
    private static let maxEnergy = 5
    private static let maxVital = 5
    private static let energyRechargeSeconds: TimeInterval = 30 * 60
    private static let vitalDecaySeconds: TimeInterval = 4 * 60 * 60
    private static let passiveSparkSeconds: TimeInterval = 15 * 60
    private static let initialPetOnlyQuietSeconds: TimeInterval = 90
    private static let cheerCooldownSeconds: TimeInterval = 45 * 60
    private static let ambientCooldownSeconds: TimeInterval = 4 * 60
    private static let wellnessBreakSeconds: TimeInterval = 2 * 60 * 60
    private static let scoutTripSeconds: TimeInterval = 20
    private static let sparkWheelSeconds: TimeInterval = 30
    private static let maxCompanionHealth = 3000
    private static let healthDecayAmount = 5
    private static let healthDecaySeconds: UInt64 = 5
    private static let maxChatMessages = 80
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func weekKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return "\(year)-W\(String(format: "%02d", week))"
    }

    private static func dayGap(from lastDay: String, to date: Date) -> Int? {
        guard let lastDate = dayFormatter.date(from: lastDay) else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: lastDate)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    private static func shortPreview(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func loadChatMessages() -> [CompanionChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: chatMessagesKey),
              let messages = try? JSONDecoder().decode([CompanionChatMessage].self, from: data) else {
            return []
        }
        return Array(messages.suffix(maxChatMessages))
    }

    @Published var companionCharacter = CompanionCharacter.savedDefault
    @Published var message = "Pika pika! Your electric partner keeps a tiny bond spark. Pet once each day to earn +1 HP and refill joy."
    @Published var lastRequest = ""
    @Published var chatMessages = DragonOverlayModel.loadChatMessages()
    @Published var serverLine = "Checking PocketDM..."
    @Published var minimized = true
    @Published var introVideoActive: Bool = !UserDefaults.standard.bool(forKey: "PocketDMCompanion.hasSeenIntro")
    @Published var napVideoActive = false
    @Published var soundEnabled = UserDefaults.standard.object(forKey: DragonOverlayModel.soundEnabledKey) as? Bool ?? true
    @Published var busy = false
    @Published var mood: PetMood = .idle
    @Published var learningMode: LearningMode = .chat
    @Published var isVoiceListening = false
    @Published var handsFreeConversationEnabled = false
    @Published var voiceTranscript = ""
    @Published var voiceStatusLine = "Ready for a daily check-in."
    @Published var voiceVisualState: VoiceVisualState = .idle
    @Published var conversationBubbleActive = false
    @Published var runtimeStackStatus = RuntimeStackStatus.detecting
    @Published var companionHP = UserDefaults.standard.object(forKey: DragonOverlayModel.companionHPKey) as? Int ?? 3
    @Published var celebrationBurstID = 0
    @Published var companionHealth = UserDefaults.standard.object(forKey: DragonOverlayModel.companionHealthKey) as? Int ?? DragonOverlayModel.maxCompanionHealth
    @Published var happiness = UserDefaults.standard.object(forKey: DragonOverlayModel.happinessKey) as? Int ?? 3
    @Published var petStreak = UserDefaults.standard.object(forKey: DragonOverlayModel.petStreakKey) as? Int ?? 0
    @Published var lastPetDay = UserDefaults.standard.string(forKey: DragonOverlayModel.lastPetDayKey) ?? ""
    @Published var sparkDust = UserDefaults.standard.object(forKey: DragonOverlayModel.sparkDustKey) as? Int ?? 12
    @Published var energy = UserDefaults.standard.object(forKey: DragonOverlayModel.energyKey) as? Int ?? DragonOverlayModel.maxEnergy
    @Published var dailyComboDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyComboDateKey) ?? ""
    @Published var dailyComboMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyComboMaskKey) as? Int ?? 0
    @Published var snackLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.snackLevelKey) as? Int ?? 0
    @Published var lessonLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.lessonLevelKey) as? Int ?? 0
    @Published var questLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.questLevelKey) as? Int ?? 0
    @Published var nestLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.nestLevelKey) as? Int ?? 0
    @Published var cheerLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.cheerLevelKey) as? Int ?? 0
    @Published var sparkLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.sparkLevelKey) as? Int ?? 0
    @Published var focusLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.focusLevelKey) as? Int ?? 0
    @Published var cipherLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.cipherLevelKey) as? Int ?? 0
    @Published var dailyQuestDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyQuestDateKey) ?? ""
    @Published var dailyQuestMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyQuestMaskKey) as? Int ?? 0
    @Published var dailyBondBoardDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyBondBoardDateKey) ?? ""
    @Published var dailyBondBoardMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyBondBoardMaskKey) as? Int ?? 0
    @Published var bondContractAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.bondContractAlbumMaskKey) as? Int ?? 0
    @Published var dailyBoosterDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyBoosterDateKey) ?? ""
    @Published var dailyBoosterUsed = UserDefaults.standard.bool(forKey: DragonOverlayModel.dailyBoosterUsedKey)
    @Published var dailyCipherDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCipherDateKey) ?? ""
    @Published var dailyCipherSolved = UserDefaults.standard.bool(forKey: DragonOverlayModel.dailyCipherSolvedKey)
    @Published var careMemoryMask = UserDefaults.standard.object(forKey: DragonOverlayModel.careMemoryMaskKey) as? Int ?? 0
    @Published var lifeSceneMask = UserDefaults.standard.object(forKey: DragonOverlayModel.lifeSceneMaskKey) as? Int ?? 0
    @Published var dailyBondTimelineDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyBondTimelineDateKey) ?? ""
    @Published var dailyBondTimelineOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyBondTimelineOfferedMaskKey) as? Int ?? 0
    @Published var dailyBondTimelineSavedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyBondTimelineSavedMaskKey) as? Int ?? 0
    @Published var dailyBondTimelineDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyBondTimelineDismissedMaskKey) as? Int ?? 0
    @Published var bondTimelineAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.bondTimelineAlbumMaskKey) as? Int ?? 0
    @Published var latestBondTimelineRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestBondTimelineRawKey) as? Int ?? 0
    @Published var careCharmMask = UserDefaults.standard.object(forKey: DragonOverlayModel.careCharmMaskKey) as? Int ?? 0
    @Published var evolutionQuestMask = UserDefaults.standard.object(forKey: DragonOverlayModel.evolutionQuestMaskKey) as? Int ?? 0
    @Published var growthJourneyMask = UserDefaults.standard.object(forKey: DragonOverlayModel.growthJourneyMaskKey) as? Int ?? 0
    @Published var latestGrowthStageRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestGrowthStageRawKey) as? Int ?? 0
    @Published var dailyEventDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyEventDateKey) ?? ""
    @Published var dailyEventProgress = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyEventProgressKey) as? Int ?? 0
    @Published var seasonBadgeMask = UserDefaults.standard.object(forKey: DragonOverlayModel.seasonBadgeMaskKey) as? Int ?? 0
    @Published var seasonTrailWeek = UserDefaults.standard.string(forKey: DragonOverlayModel.seasonTrailWeekKey) ?? ""
    @Published var seasonTrailMask = UserDefaults.standard.object(forKey: DragonOverlayModel.seasonTrailMaskKey) as? Int ?? 0
    @Published var seasonTrailAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.seasonTrailAlbumMaskKey) as? Int ?? 0
    @Published var latestSeasonTrailRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestSeasonTrailRawKey) as? Int ?? 0
    @Published var dailyFeelingDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyFeelingDateKey) ?? ""
    @Published var dailyFeelingMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyFeelingMaskKey) as? Int ?? 0
    @Published var emotionAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.emotionAlbumMaskKey) as? Int ?? 0
    @Published var latestFeelingRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestFeelingRawKey) as? Int ?? 0
    @Published var dailyEmotionWheelDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyEmotionWheelDateKey) ?? ""
    @Published var dailyEmotionWheelRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyEmotionWheelRawKey) as? Int ?? 0
    @Published var dailyEmotionEpisodeDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyEmotionEpisodeDateKey) ?? ""
    @Published var dailyEmotionEpisodeMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyEmotionEpisodeMaskKey) as? Int ?? 0
    @Published var emotionEpisodeAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.emotionEpisodeAlbumMaskKey) as? Int ?? 0
    @Published var latestEmotionEpisodeRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestEmotionEpisodeRawKey) as? Int ?? 0
    @Published var dailyEmotionArcDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyEmotionArcDateKey) ?? ""
    @Published var dailyEmotionArcMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyEmotionArcMaskKey) as? Int ?? 0
    @Published var emotionArcAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.emotionArcAlbumMaskKey) as? Int ?? 0
    @Published var latestEmotionArcRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestEmotionArcRawKey) as? Int ?? 0
    @Published var dailyMoodCareDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyMoodCareDateKey) ?? ""
    @Published var dailyMoodCareFeelingRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyMoodCareFeelingRawKey) as? Int ?? 0
    @Published var dailyMoodCareMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyMoodCareMaskKey) as? Int ?? 0
    @Published var moodCareAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.moodCareAlbumMaskKey) as? Int ?? 0
    @Published var weeklyCareWeek = UserDefaults.standard.string(forKey: DragonOverlayModel.weeklyCareWeekKey) ?? ""
    @Published var weeklyCareCount = UserDefaults.standard.object(forKey: DragonOverlayModel.weeklyCareCountKey) as? Int ?? 0
    @Published var weeklyRewardMask = UserDefaults.standard.object(forKey: DragonOverlayModel.weeklyRewardMaskKey) as? Int ?? 0
    @Published var weeklyTrailAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.weeklyTrailAlbumMaskKey) as? Int ?? 0
    @Published var streakShieldCount = UserDefaults.standard.object(forKey: DragonOverlayModel.streakShieldCountKey) as? Int ?? 0
    @Published var recoveryAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.recoveryAlbumMaskKey) as? Int ?? 0
    @Published var latestRecoverySceneRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestRecoverySceneRawKey) as? Int ?? 0
    @Published var dailyNudgeDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyNudgeDateKey) ?? ""
    @Published var dailyNudgeOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyNudgeOfferedMaskKey) as? Int ?? 0
    @Published var dailyNudgeAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyNudgeAnsweredMaskKey) as? Int ?? 0
    @Published var dailyNudgeDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyNudgeDismissedMaskKey) as? Int ?? 0
    @Published var dailyCheerPingDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCheerPingDateKey) ?? ""
    @Published var dailyCheerPingOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerPingOfferedMaskKey) as? Int ?? 0
    @Published var dailyCheerPingAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerPingAnsweredMaskKey) as? Int ?? 0
    @Published var dailyCheerPingDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerPingDismissedMaskKey) as? Int ?? 0
    @Published var cheerPingAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.cheerPingAlbumMaskKey) as? Int ?? 0
    @Published var latestCheerPingRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestCheerPingRawKey) as? Int ?? 0
    @Published var dailyMoodWeatherDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyMoodWeatherDateKey) ?? ""
    @Published var dailyMoodWeatherOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyMoodWeatherOfferedMaskKey) as? Int ?? 0
    @Published var dailyMoodWeatherAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyMoodWeatherAnsweredMaskKey) as? Int ?? 0
    @Published var dailyMoodWeatherDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyMoodWeatherDismissedMaskKey) as? Int ?? 0
    @Published var moodWeatherAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.moodWeatherAlbumMaskKey) as? Int ?? 0
    @Published var latestMoodWeatherRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestMoodWeatherRawKey) as? Int ?? 0
    @Published var dailyJourneyDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyJourneyDateKey) ?? ""
    @Published var dailyJourneyOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyJourneyOfferedMaskKey) as? Int ?? 0
    @Published var dailyJourneyAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyJourneyAnsweredMaskKey) as? Int ?? 0
    @Published var dailyJourneyDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyJourneyDismissedMaskKey) as? Int ?? 0
    @Published var journeyAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.journeyAlbumMaskKey) as? Int ?? 0
    @Published var latestJourneyRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestJourneyRawKey) as? Int ?? 0
    @Published var dailyVisitDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyVisitDateKey) ?? ""
    @Published var dailyVisitOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyVisitOfferedMaskKey) as? Int ?? 0
    @Published var dailyVisitAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyVisitAnsweredMaskKey) as? Int ?? 0
    @Published var dailyVisitDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyVisitDismissedMaskKey) as? Int ?? 0
    @Published var visitAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.visitAlbumMaskKey) as? Int ?? 0
    @Published var latestVisitRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestVisitRawKey) as? Int ?? 0
    @Published var dailySparkWheelDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailySparkWheelDateKey) ?? ""
    @Published var dailySparkWheelOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailySparkWheelOfferedMaskKey) as? Int ?? 0
    @Published var dailySparkWheelStartedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailySparkWheelStartedMaskKey) as? Int ?? 0
    @Published var dailySparkWheelClaimedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailySparkWheelClaimedMaskKey) as? Int ?? 0
    @Published var dailySparkWheelDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailySparkWheelDismissedMaskKey) as? Int ?? 0
    @Published var sparkWheelAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.sparkWheelAlbumMaskKey) as? Int ?? 0
    @Published var latestSparkWheelRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestSparkWheelRawKey) as? Int ?? 0
    @Published var activeSparkWheelRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.activeSparkWheelRawKey) as? Int ?? 0
    @Published var activeSparkWheelStartedAt = UserDefaults.standard.double(forKey: DragonOverlayModel.activeSparkWheelStartedAtKey)
    @Published var dailyExchangeDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyExchangeDateKey) ?? ""
    @Published var dailyExchangeOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyExchangeOfferedMaskKey) as? Int ?? 0
    @Published var dailyExchangeAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyExchangeAnsweredMaskKey) as? Int ?? 0
    @Published var dailyExchangeDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyExchangeDismissedMaskKey) as? Int ?? 0
    @Published var exchangeAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.exchangeAlbumMaskKey) as? Int ?? 0
    @Published var latestExchangeRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestExchangeRawKey) as? Int ?? 0
    @Published var dailyCheerDialogueDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCheerDialogueDateKey) ?? ""
    @Published var dailyCheerDialogueOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerDialogueOfferedMaskKey) as? Int ?? 0
    @Published var dailyCheerDialogueAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerDialogueAnsweredMaskKey) as? Int ?? 0
    @Published var dailyCheerDialogueDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerDialogueDismissedMaskKey) as? Int ?? 0
    @Published var cheerDialogueAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.cheerDialogueAlbumMaskKey) as? Int ?? 0
    @Published var dailyCheerIntentDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCheerIntentDateKey) ?? ""
    @Published var dailyCheerIntentOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerIntentOfferedMaskKey) as? Int ?? 0
    @Published var dailyCheerIntentAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerIntentAnsweredMaskKey) as? Int ?? 0
    @Published var dailyCheerIntentDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerIntentDismissedMaskKey) as? Int ?? 0
    @Published var cheerIntentAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.cheerIntentAlbumMaskKey) as? Int ?? 0
    @Published var dailyCheerMemoryDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCheerMemoryDateKey) ?? ""
    @Published var dailyCheerMemoryMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerMemoryMaskKey) as? Int ?? 0
    @Published var cheerMemoryAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.cheerMemoryAlbumMaskKey) as? Int ?? 0
    @Published var latestCheerMemoryRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestCheerMemoryRawKey) as? Int ?? 0
    @Published var dailyCheerScriptDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCheerScriptDateKey) ?? ""
    @Published var dailyCheerScriptOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerScriptOfferedMaskKey) as? Int ?? 0
    @Published var dailyCheerScriptAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerScriptAnsweredMaskKey) as? Int ?? 0
    @Published var dailyCheerScriptDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCheerScriptDismissedMaskKey) as? Int ?? 0
    @Published var cheerScriptAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.cheerScriptAlbumMaskKey) as? Int ?? 0
    @Published var dailyMoodStoryDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyMoodStoryDateKey) ?? ""
    @Published var dailyMoodStoryOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyMoodStoryOfferedMaskKey) as? Int ?? 0
    @Published var dailyMoodStoryAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyMoodStoryAnsweredMaskKey) as? Int ?? 0
    @Published var dailyMoodStoryDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyMoodStoryDismissedMaskKey) as? Int ?? 0
    @Published var moodStoryAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.moodStoryAlbumMaskKey) as? Int ?? 0
    @Published var latestMoodStoryRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestMoodStoryRawKey) as? Int ?? 0
    @Published var dailyFeelingRitualDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyFeelingRitualDateKey) ?? ""
    @Published var dailyFeelingRitualOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyFeelingRitualOfferedMaskKey) as? Int ?? 0
    @Published var dailyFeelingRitualAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyFeelingRitualAnsweredMaskKey) as? Int ?? 0
    @Published var dailyFeelingRitualDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyFeelingRitualDismissedMaskKey) as? Int ?? 0
    @Published var feelingRitualAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.feelingRitualAlbumMaskKey) as? Int ?? 0
    @Published var latestFeelingRitualRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestFeelingRitualRawKey) as? Int ?? 0
    @Published var dailyCareChestDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCareChestDateKey) ?? ""
    @Published var dailyCareChestOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCareChestOfferedMaskKey) as? Int ?? 0
    @Published var dailyCareChestClaimedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCareChestClaimedMaskKey) as? Int ?? 0
    @Published var dailyCareChestDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCareChestDismissedMaskKey) as? Int ?? 0
    @Published var careChestAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.careChestAlbumMaskKey) as? Int ?? 0
    @Published var latestCareChestRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestCareChestRawKey) as? Int ?? 0
    @Published var dailyFieldNoteDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyFieldNoteDateKey) ?? ""
    @Published var dailyFieldNoteOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyFieldNoteOfferedMaskKey) as? Int ?? 0
    @Published var dailyFieldNoteSavedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyFieldNoteSavedMaskKey) as? Int ?? 0
    @Published var dailyFieldNoteDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyFieldNoteDismissedMaskKey) as? Int ?? 0
    @Published var fieldNoteAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.fieldNoteAlbumMaskKey) as? Int ?? 0
    @Published var latestFieldNoteRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestFieldNoteRawKey) as? Int ?? 0
    @Published var dailyScoutTripDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyScoutTripDateKey) ?? ""
    @Published var dailyScoutTripStartedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyScoutTripStartedMaskKey) as? Int ?? 0
    @Published var dailyScoutTripReturnedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyScoutTripReturnedMaskKey) as? Int ?? 0
    @Published var scoutTripAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.scoutTripAlbumMaskKey) as? Int ?? 0
    @Published var latestScoutTripRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestScoutTripRawKey) as? Int ?? 0
    @Published var activeScoutTripRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.activeScoutTripRawKey) as? Int ?? 0
    @Published var activeScoutTripStartedAt = UserDefaults.standard.double(forKey: DragonOverlayModel.activeScoutTripStartedAtKey)
    @Published var dailyAffectionDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyAffectionDateKey) ?? ""
    @Published var dailyAffectionOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyAffectionOfferedMaskKey) as? Int ?? 0
    @Published var dailyAffectionGivenMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyAffectionGivenMaskKey) as? Int ?? 0
    @Published var dailyAffectionDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyAffectionDismissedMaskKey) as? Int ?? 0
    @Published var affectionAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.affectionAlbumMaskKey) as? Int ?? 0
    @Published var latestAffectionRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestAffectionRawKey) as? Int ?? 0
    @Published var dailyHomeDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyHomeDateKey) ?? ""
    @Published var dailyHomeOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyHomeOfferedMaskKey) as? Int ?? 0
    @Published var dailyHomeVisitedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyHomeVisitedMaskKey) as? Int ?? 0
    @Published var dailyHomeDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyHomeDismissedMaskKey) as? Int ?? 0
    @Published var homeAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.homeAlbumMaskKey) as? Int ?? 0
    @Published var latestHomeRoomRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestHomeRoomRawKey) as? Int ?? 0
    @Published var dailyErrandDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyErrandDateKey) ?? ""
    @Published var dailyErrandOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyErrandOfferedMaskKey) as? Int ?? 0
    @Published var dailyErrandDoneMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyErrandDoneMaskKey) as? Int ?? 0
    @Published var dailyErrandDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyErrandDismissedMaskKey) as? Int ?? 0
    @Published var errandAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.errandAlbumMaskKey) as? Int ?? 0
    @Published var latestErrandRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestErrandRawKey) as? Int ?? 0
    @Published var dailyUserCheckDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyUserCheckDateKey) ?? ""
    @Published var dailyUserCheckOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyUserCheckOfferedMaskKey) as? Int ?? 0
    @Published var dailyUserCheckAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyUserCheckAnsweredMaskKey) as? Int ?? 0
    @Published var dailyUserCheckDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyUserCheckDismissedMaskKey) as? Int ?? 0
    @Published var userCheckAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.userCheckAlbumMaskKey) as? Int ?? 0
    @Published var latestUserCheckRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestUserCheckRawKey) as? Int ?? 0
    @Published var dailyWishDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyWishDateKey) ?? ""
    @Published var dailyWishOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyWishOfferedMaskKey) as? Int ?? 0
    @Published var dailyWishFulfilledMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyWishFulfilledMaskKey) as? Int ?? 0
    @Published var dailyWishDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyWishDismissedMaskKey) as? Int ?? 0
    @Published var wishAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.wishAlbumMaskKey) as? Int ?? 0
    @Published var latestWishRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestWishRawKey) as? Int ?? 0
    @Published var dailyToyDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyToyDateKey) ?? ""
    @Published var dailyToyOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyToyOfferedMaskKey) as? Int ?? 0
    @Published var dailyToyPlayedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyToyPlayedMaskKey) as? Int ?? 0
    @Published var dailyToyDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyToyDismissedMaskKey) as? Int ?? 0
    @Published var toyAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.toyAlbumMaskKey) as? Int ?? 0
    @Published var latestToyRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestToyRawKey) as? Int ?? 0
    @Published var dailyTrickDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyTrickDateKey) ?? ""
    @Published var dailyTrickOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyTrickOfferedMaskKey) as? Int ?? 0
    @Published var dailyTrickPracticedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyTrickPracticedMaskKey) as? Int ?? 0
    @Published var dailyTrickDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyTrickDismissedMaskKey) as? Int ?? 0
    @Published var trickAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.trickAlbumMaskKey) as? Int ?? 0
    @Published var latestTrickRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestTrickRawKey) as? Int ?? 0
    @Published var dailyAmbientDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyAmbientDateKey) ?? ""
    @Published var dailyAmbientMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyAmbientMaskKey) as? Int ?? 0
    @Published var ambientAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.ambientAlbumMaskKey) as? Int ?? 0
    @Published var latestAmbientMomentRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestAmbientMomentRawKey) as? Int ?? 0
    @Published var dailyRouteDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyRouteDateKey) ?? ""
    @Published var dailyRouteMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyRouteMaskKey) as? Int ?? 0
    @Published var dailyRouteOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyRouteOfferedMaskKey) as? Int ?? 0
    @Published var dailyRouteDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyRouteDismissedMaskKey) as? Int ?? 0
    @Published var routeAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.routeAlbumMaskKey) as? Int ?? 0
    @Published var latestRouteStepRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestRouteStepRawKey) as? Int ?? 0
    @Published var dailyCarePulseDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCarePulseDateKey) ?? ""
    @Published var dailyCarePulseOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCarePulseOfferedMaskKey) as? Int ?? 0
    @Published var dailyCarePulseAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCarePulseAnsweredMaskKey) as? Int ?? 0
    @Published var dailyCarePulseDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCarePulseDismissedMaskKey) as? Int ?? 0
    @Published var carePulseAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.carePulseAlbumMaskKey) as? Int ?? 0
    @Published var latestCarePulseRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestCarePulseRawKey) as? Int ?? 0
    @Published var dailyCareWindowDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCareWindowDateKey) ?? ""
    @Published var dailyCareWindowMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyCareWindowMaskKey) as? Int ?? 0
    @Published var careWindowAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.careWindowAlbumMaskKey) as? Int ?? 0
    @Published var latestCareWindowRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestCareWindowRawKey) as? Int ?? 0
    @Published var dailyAffirmationDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyAffirmationDateKey) ?? ""
    @Published var dailyAffirmationMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyAffirmationMaskKey) as? Int ?? 0
    @Published var dailyWellnessDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyWellnessDateKey) ?? ""
    @Published var dailyWellnessMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyWellnessMaskKey) as? Int ?? 0
    @Published var morningWeatherDate = UserDefaults.standard.string(forKey: DragonOverlayModel.morningWeatherDateKey) ?? ""
    @Published var morningWeatherLine = UserDefaults.standard.string(forKey: DragonOverlayModel.morningWeatherLineKey) ?? "Morning weather is warming up."
    @Published var snackVital = UserDefaults.standard.object(forKey: DragonOverlayModel.snackVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var restVital = UserDefaults.standard.object(forKey: DragonOverlayModel.restVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var playVital = UserDefaults.standard.object(forKey: DragonOverlayModel.playVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var focusVital = UserDefaults.standard.object(forKey: DragonOverlayModel.focusVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var cheerBubble: String?
    @Published var cheerTitle = ""
    @Published var cheerAction = ""
    @Published var cheerRewardLine = ""
    @Published var cheerDaypartRaw = 0
    @Published var cheerPingRaw = 0
    @Published var cheerMoodWeatherRaw = 0
    @Published var cheerJourneyRaw = 0
    @Published var cheerVisitRaw = 0
    @Published var cheerSparkWheelRaw = 0
    @Published var cheerRouteRaw = 0
    @Published var cheerCareVitalRaw = 0
    @Published var cheerExchangeRaw = 0
    @Published var cheerMoodCareStepRaw = 0
    @Published var cheerBondContractRaw = 0
    @Published var cheerBondTimelineRaw = 0
    @Published var cheerDialogueRaw = 0
    @Published var cheerIntentRaw = 0
    @Published var cheerScriptRaw = 0
    @Published var cheerMoodStoryRaw = 0
    @Published var cheerFeelingRitualRaw = 0
    @Published var cheerCareChestRaw = 0
    @Published var cheerFieldNoteRaw = 0
    @Published var cheerScoutTripRaw = 0
    @Published var cheerAffectionRaw = 0
    @Published var cheerHomeRoomRaw = 0
    @Published var cheerErrandRaw = 0
    @Published var cheerUserCheckRaw = 0
    @Published var cheerWishRaw = 0
    @Published var cheerToyRaw = 0
    @Published var cheerTrickRaw = 0
    private var cheerWellnessBreakActive = false
    private var cheerWellnessActionRaw = 0

    let languageCoach = LanguageCoachStore()

    private let client: PocketDMClient
    private let launcher: GameLauncher
    private let soundPlayer = PetSoundPlayer()
    private let voiceTranscriber = VoiceConversationTranscriber()
    private var voiceConversationMode: VoiceConversationMode = .freeform
    private var voiceAutoSendTask: Task<Void, Never>?
    private var handsFreeRestartTask: Task<Void, Never>?
    private var voiceVisualResetTask: Task<Void, Never>?
    private var moodTask: Task<Void, Never>?
    private var energyTask: Task<Void, Never>?
    private var healthTask: Task<Void, Never>?
    private var cheerTask: Task<Void, Never>?
    private var ambientTask: Task<Void, Never>?
    private var scoutTripTask: Task<Void, Never>?
    private var lastEnergyAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastEnergyAtKey)
    private var passiveSparkAt = UserDefaults.standard.double(forKey: DragonOverlayModel.passiveSparkAtKey)
    private var lastLifecycleAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastLifecycleAtKey)
    private var lastAmbientAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastAmbientAtKey)
    private var lastWellnessBreakAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastWellnessBreakAtKey)
    private var lastComebackChestDay = UserDefaults.standard.string(forKey: DragonOverlayModel.lastComebackChestDayKey) ?? ""
    private var lastNeedBonusDay = UserDefaults.standard.string(forKey: DragonOverlayModel.lastNeedBonusDayKey) ?? ""
    private var lastVitalAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastVitalAtKey)
    private let launchedAt = Date().timeIntervalSince1970
    init(client: PocketDMClient, launcher: GameLauncher, initialCharacter: CompanionCharacter) {
        self.client = client
        self.launcher = launcher
        companionCharacter = initialCharacter
        UserDefaults.standard.set(initialCharacter.rawValue, forKey: CompanionCharacter.defaultsKey)
        UserDefaults.standard.set(true, forKey: Self.petOnlyKey)
        message = pikaText(initialCharacter.welcomeBody)
        if chatMessages.isEmpty {
            appendChatMessage(.assistant, message)
        }
        if lastEnergyAt == 0 {
            lastEnergyAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(lastEnergyAt, forKey: Self.lastEnergyAtKey)
        }
        if passiveSparkAt == 0 {
            passiveSparkAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(passiveSparkAt, forKey: Self.passiveSparkAtKey)
        }
        if lastLifecycleAt == 0 {
            lastLifecycleAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(lastLifecycleAt, forKey: Self.lastLifecycleAtKey)
        }
        if lastAmbientAt == 0 {
            lastAmbientAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(lastAmbientAt, forKey: Self.lastAmbientAtKey)
        }
        if lastWellnessBreakAt == 0 {
            lastWellnessBreakAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(lastWellnessBreakAt, forKey: Self.lastWellnessBreakAtKey)
        }
        if lastVitalAt == 0 {
            lastVitalAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(lastVitalAt, forKey: Self.lastVitalAtKey)
        }
        soundPlayer.onVoiceStatus = { [weak self] statusLine in
            guard let self else { return }
            self.voiceStatusLine = statusLine
            self.handleVoicePlaybackStatus(statusLine)
        }
        syncDailyCombo()
        rechargeEnergy()
        applyVitalDecay()
        applyLifecycleCatchup(reason: "launch")
        if let growthNote = recordGrowthJourney(upTo: growthStage, reason: "launch") {
            appendPetNote(growthNote)
            speakPika()
        }
        if let questNote = syncEvolutionQuests() {
            appendPetNote(questNote)
            speakPika()
        }
        let collected = collectPassiveSparks()
        if collected > 0 {
            appendPetNote("Pikachu gathered \(collected) Sparks while you were away.")
            speakPika()
        }
        startEnergyLoop()
        startHealthLoop()
        startCheerLoop()
        startAmbientLoop()
        scheduleScoutTripReturnCheck()
        Task { await refreshMorningWeatherIfNeeded() }
    }

    func refreshHealth() async {
        for attempt in 0..<8 {
            runtimeStackStatus = await client.runtimeStackStatus()
            do {
                serverLine = try await client.healthLine()
                return
            } catch {
                serverLine = attempt == 0 ? "Starting PocketDM..." : "Waiting for PocketDM..."
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
        serverLine = "PocketDM is not reachable yet"
    }

    func openGame() {
        let priorStage = growthStage
        applyVitalDecay()
        lastRequest = "Open"
        message = pikaText("Quest opened. Your buddy marks the map and saves a Spark trail back here.")
        markCombo(.open)
        recordDailyQuest(.adventure)
        if let needNote = awardCareNeed(.adventure) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.focus, by: 1) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.trailMap) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.adventure) {
            message += " \(moodCareNote)"
        }
        if let memoryNote = unlockMemory(.firstQuest) {
            message += " \(memoryNote)"
        }
        appendEmotionScene(trigger: "quest open")
        appendEvolutionNote(from: priorStage)
        speakPika()
        launcher.openGame()
    }

    func setMinimized(_ value: Bool) {
        guard minimized != value else { return }
        minimized = value
        if !value {
            applyLifecycleCatchup(reason: "open")
            applyVitalDecay()
            if let charmNote = unlockCharm(.helloSpark) {
                appendPetNote(charmNote)
                speakPika()
            }
            let collected = collectPassiveSparks()
            if collected > 0 {
                appendPetNote("Pikachu gathered \(collected) passive Sparks.")
                speakPika()
            }
        }
        UserDefaults.standard.set(value, forKey: Self.petOnlyKey)
        play(value ? .minimize : .open)
        if value {
            showCheerIfReady()
        }
    }

    func refreshMorningWeatherIfNeeded(force: Bool = false) async {
        let today = Self.dayFormatter.string(from: Date())
        guard force || morningWeatherDate != today else { return }
        guard let url = morningWeatherURL else {
            morningWeatherDate = today
            morningWeatherLine = fallbackMorningWeatherLine
            persistCare()
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let report = try JSONDecoder().decode(MorningWeatherReport.self, from: data)
            morningWeatherDate = today
            morningWeatherLine = weatherLine(from: report)
            persistCare()
        } catch {
            morningWeatherDate = today
            morningWeatherLine = fallbackMorningWeatherLine
            persistCare()
        }
    }

    private var morningWeatherURL: URL? {
        let environment = ProcessInfo.processInfo.environment
        let latitude = Double(environment["POCKETDM_WEATHER_LAT"] ?? "") ?? 37.7749
        let longitude = Double(environment["POCKETDM_WEATHER_LON"] ?? "") ?? -122.4194
        let temperatureUnit = environment["POCKETDM_WEATHER_TEMP_UNIT"] ?? "fahrenheit"
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,precipitation,weather_code,cloud_cover,wind_speed_10m"),
            URLQueryItem(name: "temperature_unit", value: temperatureUnit),
            URLQueryItem(name: "wind_speed_unit", value: "mph"),
            URLQueryItem(name: "precipitation_unit", value: "inch"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        return components?.url
    }

    private var fallbackMorningWeatherLine: String {
        "The morning weather feels like \(currentMoodWeather.title.lowercased()), doesn't it? Want to do a check-in with me?"
    }

    private func weatherLine(from report: MorningWeatherReport) -> String {
        guard let current = report.current else { return fallbackMorningWeatherLine }
        let code = current.weatherCode ?? 0
        let cloud = current.cloudCover ?? 0
        let precipitation = current.precipitation ?? 0
        let temperature = current.apparentTemperature ?? current.temperature2m
        let weatherText = weatherDescription(code: code, cloudCover: cloud, precipitation: precipitation)
        let tempText = temperature.map { " \(Int($0.rounded()))°" } ?? ""
        return "It's \(weatherText) weather\(tempText), isn't it? Want to do a check-in with me?"
    }

    private func weatherDescription(code: Int, cloudCover: Double, precipitation: Double) -> String {
        if precipitation > 0.05 {
            return "rainy"
        }
        switch code {
        case 0:
            return cloudCover < 35 ? "beautiful" : "softly bright"
        case 1, 2:
            return "partly sunny"
        case 3:
            return "gloomy"
        case 45, 48:
            return "foggy"
        case 51...67, 80...82:
            return "rainy"
        case 71...77, 85...86:
            return "snowy"
        case 95...99:
            return "stormy"
        default:
            return cloudCover >= 75 ? "gloomy" : "gentle"
        }
    }

    @discardableResult
    private func appendChatMessage(_ role: CompanionChatMessage.Role, _ rawText: String) -> UUID? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let message = CompanionChatMessage(role: role, text: text)
        chatMessages.append(message)
        if chatMessages.count > Self.maxChatMessages {
            chatMessages.removeFirst(chatMessages.count - Self.maxChatMessages)
        }
        persistChatMessages()
        return message.id
    }

    private func updateChatMessage(id: UUID?, role: CompanionChatMessage.Role = .assistant, text rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let id,
              let index = chatMessages.firstIndex(where: { $0.id == id }) else {
            appendChatMessage(role, text)
            return
        }
        chatMessages[index].role = role
        chatMessages[index].text = text
        persistChatMessages()
    }

    private func persistChatMessages() {
        if let data = try? JSONEncoder().encode(chatMessages) {
            UserDefaults.standard.set(data, forKey: Self.chatMessagesKey)
        }
    }

    func toggleSound() {
        let next = !soundEnabled
        if soundEnabled {
            play(.minimize)
        }
        soundEnabled = next
        UserDefaults.standard.set(next, forKey: Self.soundEnabledKey)
        voiceStatusLine = next ? "Sound on. Pika voice is ready." : "Muted; text only."
        if next {
            play(.open)
        }
    }

    func toggleVoiceConversation() {
        if isVoiceListening {
            stopVoiceConversation(sendTranscript: true)
        } else {
            startVoiceConversation(mode: .freeform)
        }
    }

    func toggleHandsFreeConversation() {
        if handsFreeConversationEnabled {
            handsFreeConversationEnabled = false
            cancelVoiceAutoSend()
            cancelHandsFreeRestart()
            if isVoiceListening {
                stopVoiceConversation(sendTranscript: false)
            }
            voiceStatusLine = "Realtime paused. Use the mic when you want one turn."
            setMood(.idle)
            return
        }

        handsFreeConversationEnabled = true
        if learningMode != .chat {
            learningMode = .chat
        }
        voiceStatusLine = handsFreeListeningLine
        if !isVoiceListening && !busy {
            startVoiceConversation(mode: .freeform)
        }
    }

    func startDailyVoiceCheckIn() {
        startVoiceConversation(mode: .dailyCheckIn)
    }

    func startVoiceConversation(mode: VoiceConversationMode = .freeform) {
        guard !isVoiceListening else { return }
        cancelHandsFreeRestart()
        voiceVisualResetTask?.cancel()
        if learningMode != .chat {
            learningMode = .chat
        }
        voiceConversationMode = mode
        voiceTranscript = ""
        voiceStatusLine = handsFreeConversationEnabled ? handsFreeListeningLine : mode.listeningLine
        voiceVisualState = .listening
        isVoiceListening = true
        lastRequest = mode.requestLabel
        if mode == .dailyCheckIn {
            let affirmation = currentAffirmation
            message = pikaText("\(affirmation.title): \(affirmation.line)")
        }
        play(.open)
        setMood(.look)

        voiceTranscriber.start(
            onPartial: { [weak self] transcript in
                guard let self else { return }
                self.voiceTranscript = transcript
                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                self.voiceVisualState = .listening
                if self.handsFreeConversationEnabled,
                   (trimmed.isEmpty || trimmed.localizedCaseInsensitiveContains("listening")) {
                    self.voiceStatusLine = self.handsFreeListeningLine
                } else {
                    self.voiceStatusLine = trimmed.isEmpty ? "Listening..." : transcript
                }
            },
            onFinal: { [weak self] transcript in
                self?.finishVoiceConversation(transcript)
            },
            onError: { [weak self] errorLine in
                guard let self else { return }
                self.isVoiceListening = false
                self.voiceStatusLine = errorLine
                self.voiceVisualState = .idle
                self.play(.alert)
                self.setMood(.alert, duration: 1.2)
                self.scheduleHandsFreeRestart(after: 1.2)
            }
        )
        scheduleVoiceAutoSendIfNeeded()
    }

    func stopVoiceConversation(sendTranscript: Bool = false) {
        cancelVoiceAutoSend()
        let transcript = voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let awaitingLocalTranscription = voiceTranscriber.stop(sendRecordedAudio: sendTranscript)
        isVoiceListening = false
        if awaitingLocalTranscription {
            voiceStatusLine = "Transcribing locally..."
            voiceVisualState = .transcribing
            setMood(.thinking)
            return
        }
        if sendTranscript, !transcript.isEmpty {
            finishVoiceConversation(transcript)
        } else {
            voiceStatusLine = handsFreeConversationEnabled ? "Realtime paused for this turn." : "Ready for a daily check-in."
            voiceVisualState = .idle
            voiceConversationMode = .freeform
            scheduleHandsFreeRestart(after: 1.0)
        }
    }

    private func finishVoiceConversation(_ transcript: String) {
        cancelVoiceAutoSend()
        let mode = voiceConversationMode
        voiceConversationMode = .freeform
        voiceTranscriber.stop()
        isVoiceListening = false
        let prompt = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            voiceStatusLine = "I did not catch that. Use the mic and try again."
            voiceVisualState = .idle
            play(.alert)
            setMood(.alert, duration: 1.2)
            scheduleHandsFreeRestart(after: 1.1)
            return
        }
        voiceTranscript = prompt
        conversationBubbleActive = true
        voiceStatusLine = "Heard. Sending: \(Self.shortPreview(prompt, limit: 64))"
        voiceVisualState = .thinking
        let shaped = voiceAssistantPrompt(for: prompt, mode: mode)
        Task {
            await ask(
                shaped.prompt,
                displayRequest: shaped.displayRequest,
                allowLocalCareHandling: shaped.allowLocalCareHandling
            )
        }
    }

    private var handsFreeListeningLine: String {
        "Realtime listening. Speak naturally; I send after a pause."
    }

    private func scheduleVoiceAutoSendIfNeeded() {
        cancelVoiceAutoSend()
        guard handsFreeConversationEnabled else { return }
        voiceAutoSendTask = Task { [weak self] in
            let startedAt = Date()
            var heardSpeech = false
            var lastSpeechAt = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 220_000_000)
                let sample = await MainActor.run { () -> (active: Bool, transcript: String, isLoud: Bool) in
                    guard let self,
                          self.handsFreeConversationEnabled,
                          self.isVoiceListening else {
                        return (false, "", false)
                    }
                    let transcript = self.voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                    let meterPower = self.voiceTranscriber.currentMeterPower()
                    return (true, transcript, meterPower.map { $0 > -38 } ?? false)
                }
                guard sample.active else { return }

                if !sample.transcript.isEmpty || sample.isLoud {
                    heardSpeech = true
                    lastSpeechAt = Date()
                    if sample.isLoud && sample.transcript.isEmpty {
                        await MainActor.run {
                            self?.voiceStatusLine = "I hear you..."
                        }
                    }
                }

                let elapsed = Date().timeIntervalSince(startedAt)
                let quietFor = Date().timeIntervalSince(lastSpeechAt)
                let shouldSend: Bool
                if heardSpeech && quietFor >= 1.25 {
                    await MainActor.run {
                        self?.voiceStatusLine = "Sending after your pause..."
                    }
                    shouldSend = true
                } else if elapsed >= 10.0 {
                    await MainActor.run {
                        guard let self else { return }
                        self.voiceStatusLine = heardSpeech ? "Sending your turn..." : "No voice heard yet; trying this turn."
                    }
                    shouldSend = true
                } else {
                    shouldSend = false
                }
                if shouldSend {
                    await MainActor.run {
                        guard let self,
                              self.handsFreeConversationEnabled,
                              self.isVoiceListening else {
                            return
                        }
                        self.voiceStatusLine = "Sending after your pause..."
                        self.stopVoiceConversation(sendTranscript: true)
                    }
                    return
                }
            }
        }
    }

    private func scheduleHandsFreeRestart(after delay: TimeInterval = 2.2) {
        cancelHandsFreeRestart()
        guard handsFreeConversationEnabled else { return }
        handsFreeRestartTask = Task { [weak self] in
            let nanoseconds = UInt64(max(0.5, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            await MainActor.run {
                guard let self,
                      self.handsFreeConversationEnabled,
                      !self.isVoiceListening,
                      !self.busy,
                      self.learningMode == .chat else {
                    return
                }
                self.startVoiceConversation(mode: .freeform)
            }
        }
    }

    private func cancelVoiceAutoSend() {
        voiceAutoSendTask?.cancel()
        voiceAutoSendTask = nil
    }

    private func cancelHandsFreeRestart() {
        handsFreeRestartTask?.cancel()
        handsFreeRestartTask = nil
    }

    private func markVoiceSpeaking(autoResetAfter delay: TimeInterval = 2.4) {
        guard soundEnabled else { return }
        voiceVisualResetTask?.cancel()
        voiceVisualState = .speaking
        voiceVisualResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                guard let self,
                      !self.isVoiceListening,
                      self.voiceVisualState == .speaking else { return }
                self.voiceVisualState = self.busy ? .thinking : .idle
            }
        }
    }

    private func handleVoicePlaybackStatus(_ statusLine: String) {
        let lowered = statusLine.lowercased()
        if lowered.contains("generating")
            || lowered.contains("playing")
            || lowered.contains("chirp")
            || lowered.contains("voice queued") {
            markVoiceSpeaking()
        } else if lowered.contains("unavailable")
                    || lowered.contains("returned no playable")
                    || lowered.contains("could not play")
                    || lowered.contains("muted") {
            if !isVoiceListening {
                voiceVisualState = busy ? .thinking : .idle
            }
        }
    }

    private func voiceAssistantPrompt(
        for transcript: String,
        mode: VoiceConversationMode
    ) -> (prompt: String, displayRequest: String, allowLocalCareHandling: Bool) {
        switch mode {
        case .freeform:
            return (transcript, transcript, true)
        case .dailyCheckIn:
            let affirmation = currentAffirmation
            let prompt = """
            Daily voice check-in. Time block: \(affirmation.title). Affirmation: \(affirmation.line) User said: \(transcript). Reply as Pikachu in two short sentences: validate the feeling, give one tiny next step, and ask at most one gentle question. Do not give adventure hints unless the user asked for one.
            """
            return (prompt, "Daily: \(Self.shortPreview(transcript, limit: 64))", false)
        }
    }

    func switchCharacter(_ character: CompanionCharacter) {
        guard companionCharacter != character else { return }
        companionCharacter = character
        UserDefaults.standard.set(character.rawValue, forKey: CompanionCharacter.defaultsKey)
        lastRequest = "Character"
        message = pikaText(character.welcomeBody)
        play(.open)
        speakPika(force: true)
        setMood(.happy, duration: 1.4)
    }

    private func handleCharacterCommand(_ prompt: String) -> Bool {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if CompanionCharacter.isPausedGoldAlias(trimmed) {
            lastRequest = trimmed
            message = pikaText("Only Pikachu is active in this demo. Your Pika companion stays live.")
            play(.alert)
            speakPika(force: true)
            setMood(.happy, duration: 1.1)
            return true
        }
        guard trimmed.hasPrefix("/"), let character = CompanionCharacter.parse(trimmed) else { return false }
        switchCharacter(character)
        lastRequest = trimmed
        return true
    }

    func happy() {
        applyVitalDecay()
        message = pikaText("Pikachu perks up. Joy is high and it is ready for a quest or a quick lesson.")
        lastRequest = "Mood"
        conversationBubbleActive = true
        appendChatMessage(.user, "Happy")
        if let vitalNote = refillVital(.play, by: 1) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.helloSpark) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.soothe) {
            message += " \(moodCareNote)"
        }
        appendEmotionScene(trigger: "happy")
        play(.happy)
        appendChatMessage(.assistant, message)
        speakPika()
        setMood(.happy, duration: 1.6)
    }

    func finishIntroVideo() {
        guard introVideoActive else { return }
        introVideoActive = false
        UserDefaults.standard.set(true, forKey: "PocketDMCompanion.hasSeenIntro")
    }

    func nap() {
        applyVitalDecay()
        napVideoActive = true
        message = pikaText("Pikachu curls up for a tiny recharge. It will keep watch quietly.")
        conversationBubbleActive = true
        appendChatMessage(.user, "Nap")
        if let needNote = awardCareNeed(.rest) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.rest, by: 2) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.restNest) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.rest) {
            message += " \(moodCareNote)"
        }
        lastRequest = "Mood"
        appendEmotionScene(trigger: "nap")
        play(.nap)
        appendChatMessage(.assistant, message)
        speakPika()
        setMood(.nap, duration: 2.4)
    }

    func hyper() {
        let priorStage = growthStage
        applyVitalDecay()
        message = pikaText("Pikachu is buzzing with energy. Great moment to ask for a hint or practice a phrase.")
        lastRequest = "Mood"
        conversationBubbleActive = true
        appendChatMessage(.user, "Hyper")
        earnSparkDust(1)
        markCombo(.hyper)
        if let needNote = awardCareNeed(.play) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.play, by: 2) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.playBolt) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.play) {
            message += " \(moodCareNote)"
        }
        appendEmotionScene(trigger: "hyper")
        appendEvolutionNote(from: priorStage)
        play(.hyper)
        appendChatMessage(.assistant, message)
        speakPika()
        setMood(.hyper, duration: 1.5)
    }

    func toggleLearning() {
        if learningMode == .lesson {
            openChat()
        } else {
            openLearning()
        }
    }

    func openChat() {
        guard learningMode != .chat else { return }
        learningMode = .chat
        lastRequest = ""
        message = pikaText("Back to chat. Ask for a hint, check status, or pet for today's bond spark.")
        appendEmotionScene(trigger: "chat return")
        play(.minimize)
        speakPika()
    }

    func openLearning() {
        guard learningMode != .lesson else { return }
        let priorStage = growthStage
        applyVitalDecay()
        learningMode = .lesson
        lastRequest = "Learn"
        message = "Lesson mode opened. Pick a pack, listen, slow it down, then quiz for Joy."
        markCombo(.learn)
        recordDailyQuest(.learn)
        if let needNote = awardCareNeed(.study) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.focus, by: 2) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.studyBell) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.study) {
            message += " \(moodCareNote)"
        }
        if let memoryNote = unlockMemory(.firstLesson) {
            message += " \(memoryNote)"
        }
        appendEmotionScene(trigger: "lesson open")
        appendEvolutionNote(from: priorStage)
        soundPlayer.stopAll()
        voiceStatusLine = "Lesson ready. Press Hear for clean phrase audio."
        setMood(.happy, duration: 1.2)
    }

    func openJournal() {
        guard learningMode != .journal else { return }
        let priorStage = growthStage
        learningMode = .journal
        lastRequest = "Journal"
        message = pikaText("Journal opened. Growth, moods, memories, badges, and today's ritual are all in one place.")
        appendEmotionScene(trigger: "journal")
        appendEvolutionNote(from: priorStage)
        play(.open)
        speakPika()
        setMood(.happy, duration: 1.2)
    }

    func applyLanguageReward(_ reward: LanguagePracticeReward) {
        let priorStage = growthStage
        applyVitalDecay()
        lastRequest = "Language"
        message = lessonMessage(reward.message)
        if reward.correct {
            happiness = min(5, happiness + 1)
            awardCompanionHealth(reward.dailyBond ? 50 : 30)
            earnSparkDust(reward.dailyBond ? 8 : 3)
            if reward.dailyBond {
                companionHP = min(10, companionHP + 1)
            }
            markCombo(.learn)
            recordDailyQuest(.learn)
            if let needNote = awardCareNeed(.study) {
                message += " \(needNote)"
            }
            if let vitalNote = refillVital(.focus, by: reward.dailyBond ? 2 : 1) {
                message += " \(vitalNote)"
            }
            if let charmNote = unlockCharm(.studyBell) {
                message += " \(charmNote)"
            }
            if let moodCareNote = markMoodCare(.study) {
                message += " \(moodCareNote)"
            }
            if let memoryNote = unlockMemory(.firstLesson) {
                message += " \(memoryNote)"
            }
            appendEmotionScene(trigger: "language reward")
            appendEvolutionNote(from: priorStage)
            persistCare()
            voiceStatusLine = "Lesson response saved. Phrase audio stays language-only."
            setMood(.happy, duration: 1.4)
        } else {
            appendEmotionScene(trigger: "lesson retry")
            voiceStatusLine = "Lesson retry ready. Replay the phrase before choosing again."
            setMood(.alert, duration: 1.2)
        }
    }

    func playAffirmation() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let affirmation = currentAffirmation
        dailyAffirmationDate = Self.dayFormatter.string(from: Date())
        dailyAffirmationMask |= affirmation.rawValue
        if nextIncompleteDailyWellnessAction == .affirm {
            dailyWellnessDate = Self.dayFormatter.string(from: Date())
            dailyWellnessMask |= DailyWellnessAction.affirm.rawValue
            companionHP = min(10, companionHP + 1)
            awardCompanionHealth(50)
        }
        lastRequest = affirmation.actionTitle
        conversationBubbleActive = true
        appendChatMessage(.user, affirmation.actionTitle)
        happiness = min(5, happiness + 1)
        earnSparkDust(4)
        message = pikaText("Checking the morning weather, then I will ask the local companion brain for your check-in.")
        let assistantMessageID = appendChatMessage(.assistant, message)
        voiceStatusLine = "Checking weather, then asking the local assistant..."
        markCombo(.pet)
        recordDailyQuest(.cheer)
        if let vitalNote = refillVital(.focus, by: 1) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.focusCharm) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.cheer) {
            message += " \(moodCareNote)"
        }
        appendEmotionScene(trigger: "affirmation")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.send)
        setMood(affirmation.mood, duration: 1.8)
        Task { await finishMorningWeatherAffirmation(affirmation, assistantMessageID: assistantMessageID) }
    }

    func completeDailyWellness(_ action: DailyWellnessAction, recordUserMessage: Bool = true) {
        applyVitalDecay()
        syncDailyCombo()
        guard let expected = nextIncompleteDailyWellnessAction else {
            // All daily checks done — still give a small bonus care tap so the bond keeps
            // growing. Keeps Health improvable on demand (and great for the live demo).
            lastRequest = "Pet"
            conversationBubbleActive = true
            if recordUserMessage {
                appendChatMessage(.user, "Pet me")
            }
            companionHP = min(10, companionHP + 1)
            awardCompanionHealth(20)
            happiness = min(5, happiness + 1)
            earnSparkDust(2)
            celebrationBurstID += 1
            persistCare()
            message = pikaText("Pika pika! Thanks for the pet! Bond HP up and Joy refilled.")
            appendChatMessage(.assistant, message)
            voiceStatusLine = "Petted. Health up."
            play(.happy)
            setMood(.happy, duration: 1.2)
            return
        }
        guard expected == action else {
            lastRequest = action.title
            conversationBubbleActive = true
            if recordUserMessage {
                appendChatMessage(.user, action.actionTitle)
            }
            message = pikaText("One thing at a time. \(expected.question)")
            appendChatMessage(.assistant, message)
            voiceStatusLine = "Next wellness check: \(expected.title)."
            play(.alert)
            setMood(expected.mood, duration: 1.2)
            return
        }

        let priorStage = growthStage
        conversationBubbleActive = true
        if recordUserMessage {
            appendChatMessage(.user, action.actionTitle)
        }
        dailyWellnessDate = Self.dayFormatter.string(from: Date())
        dailyWellnessMask |= action.rawValue
        if action == .affirm {
            dailyAffirmationMask |= currentAffirmation.rawValue
        }
        lastRequest = action.title
        companionHP = min(10, companionHP + 1)
        awardCompanionHealth(action == .walk ? 50 : 40)
        happiness = min(5, happiness + 1)
        celebrationBurstID += 1
        earnSparkDust(action == .affirm ? 4 : 3)
        let vitalNote = refillVital(action.vital, by: action == .walk ? 2 : 1)
        appendEmotionScene(trigger: "wellness \(action.title.lowercased())")
        appendEvolutionNote(from: priorStage)
        persistCare()

        var body = "\(action.spokenLine) Health +1."
        if action == .affirm {
            body += " \(currentAffirmation.title): \(currentAffirmation.line)"
        }
        if let vitalNote {
            body += " \(vitalNote)"
        }
        message = pikaText(body)
        appendChatMessage(.assistant, message)
        voiceStatusLine = action == .affirm ? "Affirmation counted. Health +1." : "\(action.title) counted. Health +1."
        play(action == .walk ? .hyper : .happy)
        speakPikaLine(message, force: true)
        setMood(action.mood, duration: 1.8)
    }

    func spinEmotionWheel() {
        syncDailyCombo()
        let today = Self.dayFormatter.string(from: Date())
        let existing = dailyEmotionWheelFeeling
        let next = existing ?? PetFeeling.allCases.randomElement() ?? .bright
        dailyEmotionWheelDate = today
        dailyEmotionWheelRaw = next.rawValue

        lastRequest = "Emotion wheel"
        conversationBubbleActive = true
        appendChatMessage(.user, "Spin emotion wheel")
        var body = existing == nil
            ? "Emotion wheel landed on \(next.title). Today Pikachu feels \(next.title.lowercased()). \(next.helperLine)"
            : "Today's emotion wheel is still \(next.title). Pikachu feels \(next.title.lowercased()). \(next.helperLine)"
        if let emotionNote = recordEmotionScene(feeling: next, trigger: "emotion wheel") {
            body += " \(emotionNote)"
        }
        message = pikaText(body)
        voiceStatusLine = "Emotion set: \(next.title)."
        persistCare()
        play(.happy)
        appendChatMessage(.assistant, message)
        speakPikaLine(message, force: true)
        setMood(mood(for: next), duration: 3.0)
    }

    private func finishMorningWeatherAffirmation(
        _ affirmation: PetDaypartAffirmation,
        assistantMessageID: UUID?
    ) async {
        await refreshMorningWeatherIfNeeded(force: true)
        let prompt = """
        Morning weather check-in.
        Weather line: \(morningWeatherLine)
        Affirmation title: \(affirmation.title)
        Affirmation line: \(affirmation.line)
        Requirements: reply as Pikachu in one compact line, include Pika pika, keep the full answer useful as text, and ask exactly one check-in invitation. Do not give an adventure hint.
        """
        let fallback = "\(morningWeatherLine) \(affirmation.title): \(affirmation.line) Want to do a check-in with me? Joy +1, Sparks +4."
        do {
            message = pikaText(try await client.assistantReply(for: prompt))
            voiceStatusLine = pikaVoiceStatusLine(prefix: "Morning check-in ready")
        } catch {
            message = pikaText(fallback)
            voiceStatusLine = pikaVoiceStatusLine(prefix: "Morning check-in fallback ready")
        }
        updateChatMessage(id: assistantMessageID, text: message)
        play(.reply)
        speakPikaLine(message, force: true)
    }

    func petDaily(requestLabel: String = "Daily pet", recordUserMessage: Bool = true) {
        let priorStage = growthStage
        applyVitalDecay()
        lastRequest = requestLabel
        conversationBubbleActive = true
        if recordUserMessage {
            appendChatMessage(.user, requestLabel)
        }
        clearCheerBubble()
        syncDailyCombo()
        rechargeEnergy()
        let now = Date()
        let today = Self.dayFormatter.string(from: now)
        let gap = Self.dayGap(from: lastPetDay, to: now)
        if lastPetDay == today {
            happiness = min(5, happiness + 1)
            let energyBonus = spendEnergy() ? " Energy -1." : " Energy is recharging."
            earnSparkDust(2)
            message = pikaText("Already cared for today. Pikachu still leans in. Joy +1, Sparks +2.\(energyBonus)")
        } else {
            let missedDays = max((gap ?? 1) - 1, 0)
            var shieldUsed = false
            var recoveryNote: String?
            if missedDays > 0 {
                if missedDays == 1 && streakShieldCount > 0 {
                    shieldUsed = true
                    streakShieldCount = max(0, streakShieldCount - 1)
                } else {
                    petStreak = 0
                }
                let scene = PetRecoveryScene.scene(daysMissed: missedDays, shieldUsed: shieldUsed)
                recoveryNote = recordRecoveryScene(scene, daysMissed: missedDays, shieldUsed: shieldUsed)
            }
            companionHP = min(10, companionHP + 1)
            happiness = 5
            petStreak += 1
            weeklyCareCount = min(7, weeklyCareCount + 1)
            lastPetDay = today
            _ = spendEnergy()
            earnSparkDust(15)
            if missedDays > 0 {
                let dayText = missedDays == 1 ? "1 day" : "\(missedDays) days"
                let shieldText = shieldUsed ? " A Streak Shield kept the trail warm." : " The streak restarts softly."
                message = pikaText("Comeback care complete after \(dayText). Bond HP +1, Joy refilled, Sparks +15.\(shieldText) \(growthStage.rewardLine)")
            } else {
                message = pikaText("Daily care complete. Bond HP +1, Joy refilled, Sparks +15. \(growthStage.rewardLine)")
            }
            if let recoveryNote {
                message += " \(recoveryNote)"
            }
            if let shieldNote = awardStreakShieldIfNeeded() {
                message += " \(shieldNote)"
            }
            if let streakNote = awardWeeklyCareMilestones() {
                message += " \(streakNote)"
            }
        }
        markCombo(.pet)
        recordDailyQuest(.care)
        if let needNote = awardCareNeed(.affection) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.snack, by: 2) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.snackHeart) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.snack) {
            message += " \(moodCareNote)"
        }
        if let moodCareNote = markMoodCare(.soothe) {
            message += " \(moodCareNote)"
        }
        if let memoryNote = unlockMemory(.firstCare) {
            message += " \(memoryNote)"
        }
        appendEmotionScene(trigger: "daily care")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.pet)
        appendChatMessage(.assistant, message)
        speakPika()
        setMood(.happy, duration: 2.2)
    }

    func ask(
        _ prompt: String,
        displayRequest: String? = nil,
        allowLocalCareHandling: Bool = true
    ) async {
        let priorStage = growthStage
        let asksForHint = isHintPrompt(prompt)
        applyVitalDecay()
        napVideoActive = false
        let requestText = displayRequest ?? prompt
        lastRequest = requestText
        conversationBubbleActive = true
        appendChatMessage(.user, requestText)
        if displayRequest == nil, handleCharacterCommand(prompt) {
            appendChatMessage(.assistant, message)
            return
        }
        if allowLocalCareHandling {
            if let action = wellnessAction(from: prompt) {
                completeDailyWellness(action, recordUserMessage: false)
                scheduleHandsFreeRestart(after: 1.8)
                return
            }
            if handlesCare(prompt) {
                petDaily(requestLabel: prompt, recordUserMessage: false)
                return
            }
        }
        message = pikaText("Thinking...")
        let assistantMessageID = appendChatMessage(.assistant, message)
        voiceStatusLine = asksForHint ? "Looking for one clear hint..." : "Sent. Pikachu is answering..."
        voiceVisualState = .thinking
        busy = true
        play(.send)
        setMood(.thinking)
        defer { busy = false }
        do {
            message = pikaText(try await client.assistantReply(for: prompt))
            let cleanReply = message
            awardCompanionHealth(30)
            voiceStatusLine = pikaVoiceStatusLine(prefix: "Pikachu replied")
            serverLine = "PocketDM companion online"
            earnSparkDust(1)
            if let vitalNote = refillVital(asksForHint ? .focus : .play, by: 1) {
                message += " \(vitalNote)"
            }
            if asksForHint {
                markCombo(.hint)
                recordDailyQuest(.hint)
                if let needNote = awardCareNeed(.adventure) {
                    message += " \(needNote)"
                }
                if let charmNote = unlockCharm(.trailMap) {
                    message += " \(charmNote)"
                }
                if let moodCareNote = markMoodCare(.adventure) {
                    message += " \(moodCareNote)"
                }
                if let moodCareNote = markMoodCare(.focus) {
                    message += " \(moodCareNote)"
                }
                if let memoryNote = unlockMemory(.firstHint) {
                    message += " \(memoryNote)"
                }
            } else if let moodCareNote = markMoodCare(.cheer) {
                message += " \(moodCareNote)"
            }
            appendEmotionScene(trigger: asksForHint ? "hint" : "chat")
            appendEvolutionNote(from: priorStage)
            // Keep the visible + spoken reply clean; the notes above only update pet state.
            message = cleanReply
            updateChatMessage(id: assistantMessageID, text: message)
            play(.reply)
            speakPikaLine(message, force: true)
            setMood(.happy, duration: 1.5)
            scheduleHandsFreeRestart(after: 2.4)
        } catch {
            message = pikaText("I cannot reach the tale yet. Open PocketDM, start a run, then ask me again.")
            voiceStatusLine = "PocketDM is not reachable yet."
            serverLine = "Waiting for local server"
            appendEmotionScene(trigger: "server wait")
            updateChatMessage(id: assistantMessageID, text: message)
            play(.nap)
            speakPikaLine(message, force: true)
            setMood(.nap, duration: 2.4)
            scheduleHandsFreeRestart(after: 3.0)
        }
    }

    func acceptCheerBubble() {
        let priorStage = growthStage
        applyVitalDecay()
        let prompt = cheerTitle.isEmpty ? "Check in" : cheerTitle
        let rewardLine = cheerRewardLine.isEmpty ? "Check-in answered" : cheerRewardLine
        let moodCareStep = PetMoodCareStep(rawValue: cheerMoodCareStepRaw)
        let bondContract = PetBondContract(rawValue: cheerBondContractRaw)
        let bondTimeline = PetBondTimelineChapter(rawValue: cheerBondTimelineRaw)
        let visitBeat = PetVisitBeat(rawValue: cheerVisitRaw)
        let sparkWheelCycle = PetSparkWheelCycle(rawValue: cheerSparkWheelRaw)
        let routeStep = PetDailyRouteStep(rawValue: cheerRouteRaw)
        let carePulseVital = carePulseVital(from: cheerCareVitalRaw)
        let cheerPing = PetCheerPing(rawValue: cheerPingRaw)
        let cheerDialogue = PetCheerDialogue(rawValue: cheerDialogueRaw)
        let feelingRitual = PetFeelingRitual(rawValue: cheerFeelingRitualRaw)
        let careChest = PetCareChest(rawValue: cheerCareChestRaw)
        let cheerIntent = PetCheerIntent(rawValue: cheerIntentRaw) ?? .checkIn
        let cheerDaypart = PetDaypartNudge(rawValue: cheerDaypartRaw)
        let wellnessBreak = cheerWellnessBreakActive
        let wellnessAction = DailyWellnessAction(rawValue: cheerWellnessActionRaw)
        if wellnessBreak {
            clearCheerBubble()
            if let action = wellnessAction ?? nextIncompleteDailyWellnessAction {
                completeDailyWellness(action)
            } else {
                lastRequest = "Wellness"
                message = pikaText("All wellness checks are complete for today. Pikachu keeps today's care spark warm.")
                voiceStatusLine = "Wellness complete for today."
                play(.happy)
                setMood(.happy, duration: 1.2)
            }
            setMinimized(false)
            return
        }

        let journeyNote = recordDailyJourneyAnswer()
        let visitNote = recordVisitAnswer()
        let sparkWheelNote = recordSparkWheelAnswer()
        let routeNote = recordRouteAnswer()
        let carePulseNote = recordCarePulseAnswer()
        let cheerPingNote = recordCheerPingAnswer()
        let exchangeNote = recordExchangeBoardAnswer()
        let daypartNote = recordCheerAnswer()
        let careWindowNote = cheerDaypart == nil ? nil : recordCareWindow(careMoment)
        let dialogueNote = recordCheerDialogueAnswer()
        let scriptNote = recordCheerScriptAnswer()
        let moodStoryNote = recordMoodStoryAnswer()
        let bondTimelineNote = recordBondTimelineAnswer()
        let feelingRitualNote = recordFeelingRitualAnswer()
        let careChestNote = recordCareChestAnswer()
        let fieldNoteNote = recordFieldNoteAnswer()
        let scoutTripNote = recordScoutTripAnswer()
        let affectionNote = recordAffectionAnswer()
        let homeNote = recordHomeRoomAnswer()
        let errandNote = recordErrandAnswer()
        let userCheckNote = recordUserCheckAnswer()
        let wishNote = recordWishAnswer()
        let toyNote = recordToyAnswer()
        let trickNote = recordTrickAnswer()
        let intentNote = recordCheerIntentAnswer()
        let memoryNote = recordCheerMemory(dialogue: cheerDialogue, intent: cheerIntent, daypart: cheerDaypart)
        clearCheerBubble()
        lastRequest = "Cheer"
        happiness = min(5, happiness + 1)
        earnSparkDust(3)
        message = pikaText("\(rewardLine). Pikachu turns \(prompt.lowercased()) into Joy +1 and Sparks +3.")
        let rewardNotes = [
            journeyNote,
            visitNote,
            sparkWheelNote,
            routeNote,
            carePulseNote,
            cheerPingNote,
            exchangeNote,
            daypartNote,
            careWindowNote,
            dialogueNote,
            scriptNote,
            moodStoryNote,
            bondTimelineNote,
            feelingRitualNote,
            careChestNote,
            fieldNoteNote,
            scoutTripNote,
            affectionNote,
            homeNote,
            errandNote,
            userCheckNote,
            wishNote,
            toyNote,
            trickNote,
            intentNote,
            memoryNote
        ].compactMap { $0 }
        if !rewardNotes.isEmpty {
            message += " \(rewardNotes.joined(separator: " "))"
        }
        recordDailyQuest(.cheer)
        if cheerDaypart != nil {
            recordDailyQuest(careMoment.dailyQuest)
        }
        if let needNote = awardCareNeed(.focus) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.focus, by: 2) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.focusCharm) {
            message += " \(charmNote)"
        }
        if let moodCareStep, let moodCareNote = markMoodCare(moodCareStep) {
            message += " \(moodCareNote)"
        }
        if let bondContract, let bondNote = markBondContract(bondContract) {
            message += " \(bondNote)"
            recordDailyQuest(bondContract.quest)
            if let vitalNote = refillVital(bondContract.vital, by: 1) {
                message += " \(vitalNote)"
            }
            if let moodCareNote = markMoodCare(bondContract.moodStep) {
                message += " \(moodCareNote)"
            }
        }
        if let cheerDialogue {
            if let vitalNote = refillVital(cheerDialogue.vital, by: 1) {
                message += " \(vitalNote)"
            }
            if let moodCareNote = markMoodCare(cheerDialogue.moodStep) {
                message += " \(moodCareNote)"
            }
        }
        if let moodCareNote = markMoodCare(.cheer) {
            message += " \(moodCareNote)"
        }
        if let moodCareNote = markMoodCare(.focus) {
            message += " \(moodCareNote)"
        }
        appendEmotionScene(trigger: "cheer")
        appendEvolutionNote(from: priorStage)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheerAtKey)
        persistCare()
        play(.reply)
        speakPikaLine(message, force: true)
        setMood(bondTimeline?.mood ?? sparkWheelCycle?.mood ?? routeStep?.mood ?? carePulseVital?.mood ?? cheerPing?.mood ?? visitBeat?.mood ?? careChest?.mood ?? feelingRitual?.mood ?? .hyper, duration: 1.6)
        setMinimized(false)
    }

    func dismissCheerBubble() {
        recordCheerDismissal()
        recordVisitDismissal()
        recordSparkWheelDismissal()
        recordRouteDismissal()
        recordCarePulseDismissal()
        recordCheerIntentDismissal()
        recordCheerScriptDismissal()
        recordMoodStoryDismissal()
        recordBondTimelineDismissal()
        recordFeelingRitualDismissal()
        recordCareChestDismissal()
        recordFieldNoteDismissal()
        recordAffectionDismissal()
        recordHomeRoomDismissal()
        recordErrandDismissal()
        recordUserCheckDismissal()
        recordWishDismissal()
        recordToyDismissal()
        recordTrickDismissal()
        clearCheerBubble()
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheerAtKey)
        play(.minimize)
    }

    func buyNextUpgrade() {
        applyVitalDecay()
        syncDailyCombo()
        let candidate = nextUpgradeCandidate
        guard sparkDust >= candidate.cost else {
            lastRequest = "Upgrade"
            message = pikaText("\(candidate.name) needs \(candidate.cost) Sparks. You have \(sparkDust). Finish today's combo or pet again.")
            appendEmotionScene(trigger: "upgrade wait")
            play(.alert)
            speakPika()
            setMood(.alert, duration: 1.1)
            return
        }

        let priorStage = growthStage
        sparkDust -= candidate.cost
        switch candidate.kind {
        case .snack:
            snackLevel += 1
        case .lesson:
            lessonLevel += 1
        case .quest:
            questLevel += 1
        case .nest:
            nestLevel += 1
        case .cheer:
            cheerLevel += 1
        case .spark:
            sparkLevel += 1
        case .focus:
            focusLevel += 1
        case .cipher:
            cipherLevel += 1
        }

        lastRequest = "Upgrade"
        message = pikaText("\(candidate.name) upgraded. \(candidate.kind.unlockLine) Passive Sparks now +\(passiveSparkRate) every 15 minutes.")
        markCombo(.upgrade)
        recordDailyQuest(.upgrade)
        if let vitalNote = refillVital(vitalForUpgrade(candidate.kind), by: 2) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.upgradeCard) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.focus) {
            message += " \(moodCareNote)"
        }
        if let memoryNote = unlockMemory(.firstUpgrade) {
            message += " \(memoryNote)"
        }
        appendEmotionScene(trigger: "upgrade")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPika()
        setMood(.happy, duration: 1.4)
    }

    func activateDailyBoost() {
        applyVitalDecay()
        syncDailyCombo()
        guard !dailyBoosterUsed else {
            lastRequest = "Boost"
            message = pikaText("Today's Spark Boost is already spent. It will refill tomorrow.")
            appendEmotionScene(trigger: "spent boost")
            play(.alert)
            speakPika()
            setMood(.alert, duration: 1.0)
            return
        }

        let priorStage = growthStage
        dailyBoosterUsed = true
        dailyBoosterDate = Self.dayFormatter.string(from: Date())
        let sparkGain = 10 + focusLevel * 5
        energy = Self.maxEnergy
        happiness = min(5, happiness + 1)
        sparkDust = min(999, sparkDust + sparkGain)
        lastRequest = "Boost"
        message = pikaText("Spark Boost claimed. Energy refilled, Joy +1, Sparks +\(sparkGain).")
        markCombo(.boost)
        recordDailyQuest(.boost)
        if let needNote = awardCareNeed(.focus) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.focus, by: 2) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.focusCharm) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.focus) {
            message += " \(moodCareNote)"
        }
        if let memoryNote = unlockMemory(.firstBoost) {
            message += " \(memoryNote)"
        }
        appendEmotionScene(trigger: "boost")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.hyper)
        speakPika()
        setMood(.hyper, duration: 1.6)
    }

    func solveDailyCipher() {
        applyVitalDecay()
        syncDailyCombo()
        let cipher = dailyCipher
        guard !dailyCipherSolved else {
            lastRequest = "Cipher"
            message = pikaText("Today's cipher is already solved: \(cipher.answer). New clue tomorrow.")
            appendEmotionScene(trigger: "cipher review")
            play(.happy)
            speakPika()
            setMood(.happy, duration: 1.0)
            return
        }

        let priorStage = growthStage
        dailyCipherSolved = true
        dailyCipherDate = Self.dayFormatter.string(from: Date())
        sparkDust = min(999, sparkDust + cipher.reward)
        happiness = min(5, happiness + 1)
        lastRequest = "Cipher"
        message = pikaText("Daily cipher solved: \(cipher.answer). Joy +1 and Sparks +\(cipher.reward).")
        markCombo(.cipher)
        recordDailyQuest(.cipher)
        if let needNote = awardCareNeed(.puzzle) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.focus, by: 2) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.cipherStone) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.puzzle) {
            message += " \(moodCareNote)"
        }
        if let memoryNote = unlockMemory(.firstCipher) {
            message += " \(memoryNote)"
        }
        appendEmotionScene(trigger: "cipher")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPika()
        setMood(.hyper, duration: 1.5)
    }

    func playDailyEvent() {
        applyVitalDecay()
        syncDailyCombo()
        let event = dailyEvent
        let priorStage = growthStage
        guard dailyEventProgress < event.requiredSteps else {
            lastRequest = "Event"
            message = pikaText("\(event.title) is complete. \(event.badgeTitle) is tucked into the album.")
            appendEmotionScene(trigger: "event review")
            play(.happy)
            speakPika()
            setMood(.happy, duration: 1.0)
            return
        }

        lastRequest = "Event"
        _ = spendEnergy()
        dailyEventProgress += 1
        let stepReward = 5 + sparkLevel + questLevel
        sparkDust = min(999, sparkDust + stepReward)
        happiness = min(5, happiness + 1)
        message = pikaText("\(event.stepLine) Event \(dailyEventProgress)/\(event.requiredSteps): Joy +1, Sparks +\(stepReward).")
        if let vitalNote = refillVital(.play, by: 1) {
            message += " \(vitalNote)"
        }
        if let charmNote = unlockCharm(.eventRibbon) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.play) {
            message += " \(moodCareNote)"
        }
        if let moodCareNote = markMoodCare(.adventure) {
            message += " \(moodCareNote)"
        }
        if let seasonTrailNote = recordSeasonTrailProgress(event: event) {
            message += " \(seasonTrailNote)"
        }

        if dailyEventProgress >= event.requiredSteps {
            let badgeWasNew = seasonBadgeMask & event.rawValue == 0
            seasonBadgeMask |= event.rawValue
            let completionReward = badgeWasNew ? 24 : 12
            sparkDust = min(999, sparkDust + completionReward)
            if badgeWasNew {
                companionHP = min(10, companionHP + 1)
            }
            message += " \(event.completeLine) \(event.badgeTitle) \(badgeWasNew ? "unlocked" : "polished"): Sparks +\(completionReward)\(badgeWasNew ? ", Bond HP +1" : "")."
            setMood(.hyper, duration: 1.8)
        } else {
            setMood(.happy, duration: 1.3)
        }

        appendEmotionScene(trigger: "daily event")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPika()
    }

    func playSparkRoute() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        guard let step = nextRouteStep else {
            lastRequest = "Route"
            message = pikaText("Today's Spark Route is complete. The pet circles the board, checks every receipt, and saves the route for tomorrow.")
            appendEmotionScene(trigger: "daily route")
            play(.happy)
            speakPika()
            setMood(.hyper, duration: 1.4)
            return
        }

        lastRequest = "Route"
        message = pikaText(recordRouteStep(step))
        if let comboAction = step.comboAction {
            markCombo(comboAction)
        }
        recordDailyQuest(step.dailyQuest)
        if let moodCareNote = markMoodCare(step.moodStep) {
            message += " \(moodCareNote)"
        }
        appendEmotionScene(trigger: "daily route")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPika()
        setMood(step.mood, duration: 1.6)
    }

    func playCarePulse() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        guard let vital = nextCarePulseVital else {
            lastRequest = "Care"
            message = pikaText("All urgent care pulses are steady. \(vitalLine)")
            appendEmotionScene(trigger: "care pulse clear")
            persistCare()
            play(.happy)
            speakPika()
            setMood(.happy, duration: 1.4)
            return
        }

        cheerCareVitalRaw = vital.rawValue + 1
        lastRequest = "Care"
        message = pikaText(recordCarePulse(vital))
        recordDailyQuest(vital.dailyQuest)
        appendEmotionScene(trigger: "care pulse")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(vital == .rest ? .nap : .happy)
        speakPikaLine(message, force: true)
        setMood(vital.mood, duration: 1.7)
    }

    func playCheerPing() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        guard let ping = nextCheerPing else {
            lastRequest = "Cheer"
            message = pikaText("Cheer pings are clear for this time window. \(cheerPingLine)")
            appendEmotionScene(trigger: "cheer ping clear")
            persistCare()
            play(.happy)
            speakPika()
            setMood(.happy, duration: 1.3)
            return
        }

        cheerPingRaw = ping.rawValue
        cheerIntentRaw = ping.intent.rawValue
        lastRequest = "Cheer"
        message = pikaText("\(ping.body(stage: growthStage, feeling: petFeeling)) \(recordCheerPingAnswer() ?? ping.rewardLine)")
        recordDailyQuest(.cheer)
        appendEmotionScene(trigger: "cheer ping")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.reply)
        speakPikaLine(message, force: true)
        setMood(ping.mood, duration: 1.7)
    }

    func playCareWindow() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let moment = careMoment
        lastRequest = "Now"
        message = pikaText(recordCareWindow(moment))
        recordDailyQuest(moment.dailyQuest)
        if let moodCareNote = markMoodCare(moment.moodStep) {
            message += " \(moodCareNote)"
        }
        appendEmotionScene(trigger: "care window")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPika()
        setMood(moment.mood, duration: 1.7)
    }

    var nextPetLoopLabel: String {
        if activeScoutTripRaw != 0 {
            return "Next Loop: Scout"
        }
        if nextBondContract != nil {
            return "Next Loop: Bond"
        }
        if nextBondTimelineChapter != nil {
            return "Next Loop: Timeline"
        }
        if nextVisitBeat != nil {
            return "Next Loop: Visit"
        }
        if activeSparkWheelRaw != 0 || nextSparkWheelCycle != nil {
            return "Next Loop: Wheel"
        }
        if nextRouteStep != nil {
            return "Next Loop: Route"
        }
        if nextCarePulseVital != nil {
            return "Next Loop: Care"
        }
        if nextCheerPing != nil {
            return "Next Loop: Cheer"
        }
        if nextDailyErrand != nil {
            return "Next Loop: Errand"
        }
        if nextWish != nil {
            return "Next Loop: Wish"
        }
        if nextHomeRoom != nil {
            return "Next Loop: Home"
        }
        if nextToy != nil {
            return "Next Loop: Toy"
        }
        if nextTrick != nil {
            return "Next Loop: Trick"
        }
        if nextLifeScene != nil {
            return "Next Loop: Life"
        }
        if nextCareChest != nil {
            return "Next Loop: Chest"
        }
        if nextFeelingRitual != nil {
            return "Next Loop: Ritual"
        }
        if nextFieldNote != nil {
            return "Next Loop: Field"
        }
        return "Next Loop: Event"
    }

    func playNextPetLoop() {
        if activeScoutTripRaw != 0 {
            playScoutTrip()
        } else if nextBondContract != nil {
            playBondBoard()
        } else if nextBondTimelineChapter != nil {
            playBondTimeline()
        } else if nextVisitBeat != nil {
            playVisit()
        } else if activeSparkWheelRaw != 0 || nextSparkWheelCycle != nil {
            playSparkWheel()
        } else if nextRouteStep != nil {
            playSparkRoute()
        } else if nextCarePulseVital != nil {
            playCarePulse()
        } else if nextCheerPing != nil {
            playCheerPing()
        } else if nextDailyErrand != nil {
            playDailyErrand()
        } else if nextWish != nil {
            playWish()
        } else if nextHomeRoom != nil {
            playHomeRoom()
        } else if nextToy != nil {
            playToy()
        } else if nextTrick != nil {
            playTrick()
        } else if nextLifeScene != nil {
            playLifeScene()
        } else if nextCareChest != nil {
            playCareChest()
        } else if nextFeelingRitual != nil {
            playFeelingRitual()
        } else if nextFieldNote != nil {
            playFieldNote()
        } else {
            playDailyEvent()
        }
    }

    func playBondBoard() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        guard let contract = nextBondContract else {
            lastRequest = "Board"
            message = pikaText("Bond Board is clear today. Pikachu curls proudly around the finished route.")
            appendEmotionScene(trigger: "bond board")
            play(.happy)
            speakPika()
            setMood(.happy, duration: 1.2)
            return
        }

        lastRequest = "Board"
        message = pikaText("\(contract.title): \(contract.actionLine).")
        if let bondNote = markBondContract(contract) {
            message += " \(bondNote)"
        }
        recordDailyQuest(contract.quest)
        if let vitalNote = refillVital(contract.vital, by: 2) {
            message += " \(vitalNote)"
        }
        if let moodCareNote = markMoodCare(contract.moodStep) {
            message += " \(moodCareNote)"
        }
        appendEmotionScene(trigger: "bond board")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPika()
        setMood(.happy, duration: 1.4)
    }

    func playLifeScene() {
        let priorStage = growthStage
        applyVitalDecay()
        guard let scene = nextLifeScene else {
            lastRequest = "Life"
            message = pikaText("\(growthStage.title) life scenes are complete. Pikachu rests in the story you built together.")
            appendEmotionScene(trigger: "life scene")
            play(.happy)
            speakPika()
            setMood(.happy, duration: 1.2)
            return
        }

        lastRequest = "Life"
        message = pikaText(scene.rewardLine)
        if let sceneNote = unlockLifeScene(scene) {
            message += " \(sceneNote)"
        }
        if let vitalNote = refillVital(scene.vital, by: 2) {
            message += " \(vitalNote)"
        }
        if let moodCareNote = markMoodCare(scene.moodStep) {
            message += " \(moodCareNote)"
        }
        recordDailyQuest(.cheer)
        appendEmotionScene(trigger: "life scene")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPika()
        setMood(.happy, duration: 1.5)
    }

    func playBondTimeline() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let chapter = nextBondTimelineChapter ?? PetBondTimelineChapter(rawValue: latestBondTimelineRaw) ?? .firstHello
        cheerBondTimelineRaw = chapter.rawValue
        lastRequest = "Timeline"
        message = pikaText(saveBondTimelineChapter(chapter) ?? "\(chapter.title) already lives in the Bond Timeline.")
        appendEmotionScene(trigger: "bond timeline")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPikaLine(message, force: true)
        setMood(chapter.mood, duration: 1.7)
    }

    func playVisit() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let beat = nextVisitBeat ?? PetVisitBeat(rawValue: latestVisitRaw) ?? currentVisitBeat
        cheerVisitRaw = beat.rawValue
        lastRequest = "Visit"
        message = pikaText(recordVisit(beat))
        recordDailyQuest(.cheer)
        appendEmotionScene(trigger: "visit log")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.reply)
        speakPikaLine(message, force: true)
        setMood(beat.mood, duration: 1.7)
    }

    func playSparkWheel() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()

        if let active = activeSparkWheelCycle {
            lastRequest = "Wheel"
            if let remaining = sparkWheelRemainingSeconds, remaining > 0 {
                message = pikaText("\(active.title) is spinning. \(remaining)s until the Spark pouch is ready. \(active.startLine(stage: growthStage, feeling: petFeeling))")
                appendEmotionScene(trigger: "spark wheel wait")
                persistCare()
                play(.minimize)
                speakPikaLine(message, force: true)
                setMood(active.mood, duration: 1.4)
                return
            }

            message = pikaText(claimSparkWheel(active))
            recordDailyQuest(.boost)
            appendEmotionScene(trigger: "spark wheel claim")
            appendEvolutionNote(from: priorStage)
            persistCare()
            play(.happy)
            speakPikaLine(message, force: true)
            setMood(active.mood, duration: 1.8)
            return
        }

        let cycle = nextSparkWheelCycle ?? PetSparkWheelCycle(rawValue: latestSparkWheelRaw) ?? .firstWind
        lastRequest = "Wheel"
        message = pikaText(startSparkWheel(cycle))
        appendEmotionScene(trigger: "spark wheel start")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.send)
        speakPikaLine(message, force: true)
        setMood(cycle.mood, duration: 1.7)
    }

    func playFieldNote() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let note = nextFieldNote ?? PetFieldNote(rawValue: latestFieldNoteRaw) ?? .deskScout
        lastRequest = "Field"
        message = pikaText(recordFieldNote(note))
        recordDailyQuest(.cheer)
        appendEmotionScene(trigger: "field note")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.reply)
        speakPikaLine(message, force: true)
        setMood(note.mood, duration: 1.7)
    }

    func playFeelingRitual() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let ritual = nextFeelingRitual ?? PetFeelingRitual(rawValue: latestFeelingRitualRaw) ?? .morningSpark
        cheerFeelingRitualRaw = ritual.rawValue
        lastRequest = "Ritual"
        message = pikaText(recordFeelingRitualAnswer() ?? "\(ritual.title) already helped today. \(ritual.rewardLine)")
        recordDailyQuest(.cheer)
        appendEmotionScene(trigger: "feeling ritual")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.reply)
        speakPikaLine(message, force: true)
        setMood(ritual.mood, duration: 1.7)
    }

    func playCareChest() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let chest = nextCareChest ?? PetCareChest(rawValue: latestCareChestRaw) ?? .morningSpark
        cheerCareChestRaw = chest.rawValue
        lastRequest = "Chest"
        message = pikaText(recordCareChestAnswer() ?? "\(chest.title) is waiting quietly. \(chest.rewardLine).")
        appendEmotionScene(trigger: "care chest")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPikaLine(message, force: true)
        setMood(chest.mood, duration: 1.8)
    }

    func playScoutTrip() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()

        if let active = PetScoutTrip(rawValue: activeScoutTripRaw) {
            lastRequest = "Scout"
            if let remaining = scoutTripRemainingSeconds, remaining > 0 {
                message = pikaText("\(active.title) is still scouting. \(remaining)s until return. \(active.startLine)")
                appendEmotionScene(trigger: "scout wait")
                persistCare()
                play(.minimize)
                speakPikaLine(message, force: true)
                setMood(active.mood, duration: 1.4)
                return
            }

            message = pikaText(recordScoutTripReturn(active))
            recordDailyQuest(.adventure)
            appendEmotionScene(trigger: "scout return")
            appendEvolutionNote(from: priorStage)
            scoutTripTask?.cancel()
            persistCare()
            play(.happy)
            speakPikaLine(message, force: true)
            setMood(.hyper, duration: 1.8)
            return
        }

        let trip = nextScoutTrip ?? PetScoutTrip(rawValue: latestScoutTripRaw) ?? .deskEdge
        activeScoutTripRaw = trip.rawValue
        activeScoutTripStartedAt = Date().timeIntervalSince1970
        dailyScoutTripStartedMask |= trip.rawValue
        dailyScoutTripReturnedMask &= ~trip.rawValue
        latestScoutTripRaw = trip.rawValue
        let energyNote = spendEnergy() ? " Energy -1." : " Energy is recharging."
        lastRequest = "Scout"
        message = pikaText("Scout trip started: \(trip.title). \(trip.startLine)\(energyNote)")
        appendEmotionScene(trigger: "scout start")
        appendEvolutionNote(from: priorStage)
        persistCare()
        scheduleScoutTripReturnCheck()
        play(.send)
        speakPikaLine(message, force: true)
        setMood(trip.mood, duration: 1.8)
    }

    func playWish() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let wish = nextWish ?? PetWish(rawValue: latestWishRaw) ?? .helloPat
        lastRequest = "Wish"
        message = pikaText(recordWish(wish))
        recordDailyQuest(.cheer)
        appendEmotionScene(trigger: "wishbook")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPikaLine(message, force: true)
        setMood(wish.mood, duration: 1.7)
    }

    func playAffectionGesture() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let gesture = nextAffectionGesture ?? PetAffectionGesture(rawValue: latestAffectionRaw) ?? .headPat
        lastRequest = "Bond"
        message = pikaText(recordAffectionGesture(gesture))
        recordDailyQuest(.care)
        if let needNote = awardCareNeed(.affection) {
            message += " \(needNote)"
        }
        appendEmotionScene(trigger: "affection")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPikaLine(message, force: true)
        setMood(gesture.mood, duration: 1.7)
    }

    func playHomeRoom() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let room = nextHomeRoom ?? PetHomeRoom(rawValue: latestHomeRoomRaw) ?? .cozyNest
        lastRequest = "Home"
        message = pikaText(recordHomeRoom(room))
        recordDailyQuest(.care)
        if let needNote = awardCareNeed(room.moodStep == .adventure ? .adventure : .affection) {
            message += " \(needNote)"
        }
        appendEmotionScene(trigger: "home room")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.open)
        speakPikaLine(message, force: true)
        setMood(room.mood, duration: 1.8)
    }

    func playDailyErrand() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let errand = nextDailyErrand ?? PetDailyErrand(rawValue: latestErrandRaw) ?? .sparkGather
        let energyNote = spendEnergy() ? " Energy -1." : " Energy is recharging."
        lastRequest = "Errand"
        message = pikaText("\(recordDailyErrand(errand))\(energyNote)")
        recordDailyQuest(errand.dailyQuest)
        if let needNote = awardCareNeed(errand.careNeed) {
            message += " \(needNote)"
        }
        appendEmotionScene(trigger: "errand")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.send)
        speakPikaLine(message, force: true)
        setMood(errand.mood, duration: 1.8)
    }

    func playUserCheckIn() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let checkIn = nextUserCheckIn ?? PetUserCheckIn(rawValue: latestUserCheckRaw) ?? .bright
        lastRequest = "Check"
        message = pikaText(recordUserCheckIn(checkIn))
        recordDailyQuest(.cheer)
        if let needNote = awardCareNeed(checkIn.careNeed) {
            message += " \(needNote)"
        }
        appendEmotionScene(trigger: "user check")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.reply)
        speakPikaLine(message, force: true)
        setMood(checkIn.mood, duration: 1.8)
    }

    func playToy() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let toy = nextToy ?? PetToy(rawValue: latestToyRaw) ?? .sparkBall
        lastRequest = "Toy"
        message = pikaText(recordToy(toy))
        recordDailyQuest(.cheer)
        appendEmotionScene(trigger: "toybox")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPikaLine(message, force: true)
        setMood(toy.mood, duration: 1.7)
    }

    func playTrick() {
        let priorStage = growthStage
        applyVitalDecay()
        syncDailyCombo()
        let trick = nextTrick ?? PetTrick(rawValue: latestTrickRaw) ?? .helloWave
        lastRequest = "Trick"
        message = pikaText(recordTrick(trick))
        recordDailyQuest(.cheer)
        appendEmotionScene(trigger: "trickbook")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.happy)
        speakPikaLine(message, force: true)
        setMood(trick.mood, duration: 1.7)
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
        message = pikaText("Curling up. See you next check-in.")
        play(.close)
        speakPika()
        setMood(.nap)
    }

    var careLine: String {
        "\(growthStage.title) · \(petFeeling.title) · HP \(companionHP)/10 · Shield \(streakShieldCount)/3"
    }

    var currentAffirmation: PetDaypartAffirmation {
        let hour = Calendar.current.component(.hour, from: Date())
        return PetDaypartAffirmation.current(hour: hour)
    }

    var affirmationLine: String {
        let affirmation = currentAffirmation
        let done = dailyAffirmationMask & affirmation.rawValue != 0
        return "\(affirmation.title) \(done ? "ready tomorrow" : "ready now")"
    }

    var economyLine: String {
        "Sparks \(sparkDust) · Energy \(energy)/\(Self.maxEnergy) · +\(passiveSparkRate)/15m"
    }

    var vitalLine: String {
        PetCareVital.summary(
            snack: snackVital,
            rest: restVital,
            play: playVital,
            focus: focusVital
        )
    }

    var maxVitalLevel: Int {
        Self.maxVital
    }

    var maxEnergyLevel: Int {
        Self.maxEnergy
    }

    var healthProgress: Double {
        Double(min(Self.maxCompanionHealth, max(0, companionHealth))) / Double(Self.maxCompanionHealth)
    }

    var healthLine: String {
        "Health \(min(Self.maxCompanionHealth, max(0, companionHealth)))/\(Self.maxCompanionHealth)"
    }

    var healthValueLine: String {
        "\(min(Self.maxCompanionHealth, max(0, companionHealth)))"
    }

    var voiceTraceLine: String {
        let sttLabel = runtimeStackStatus.stt == "STT ..." ? "STT" : runtimeStackStatus.stt
        let frameLabel = runtimeStackStatus.frames == "Frames ..." ? "ASR frames" : runtimeStackStatus.frames
        let brainLabel = runtimeStackStatus.brain == "Brain ..." ? "LLM" : runtimeStackStatus.brain
        let voiceLabel = runtimeStackStatus.voice == "Voice ..." ? "TTS" : runtimeStackStatus.voice
        return "STT \(sttLabel) · ASR \(frameLabel) · LLM \(brainLabel) · TTS \(voiceLabel)"
    }

    var voiceBubbleLine: String {
        let transcript = voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcript.isEmpty {
            return transcript
        }
        return voiceStatusLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shouldShowAssistantBubble: Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard conversationBubbleActive, !trimmed.isEmpty else { return false }
        return trimmed != pikaText(companionCharacter.welcomeBody)
    }

    var petOnlyBubbleContent: PetOnlyBubbleContent? {
        let voiceLine = voiceBubbleLine
        if isVoiceListening {
            return PetOnlyBubbleContent(
                title: voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Listening" : "You",
                body: voiceLine.isEmpty ? "Listening..." : voiceLine,
                footer: voiceTraceLine
            )
        }
        switch voiceVisualState {
        case .transcribing:
            return PetOnlyBubbleContent(title: "Transcribing", body: voiceLine.isEmpty ? "Turning speech into text..." : voiceLine, footer: voiceTraceLine)
        case .thinking:
            return PetOnlyBubbleContent(title: "Pikachu", body: "Thinking with the local brain...", footer: voiceTraceLine)
        case .speaking:
            let body = shouldShowAssistantBubble ? message : (voiceLine.isEmpty ? "Pikaa Pikaa!" : voiceLine)
            return PetOnlyBubbleContent(title: "Pikachu", body: body, footer: voiceTraceLine)
        case .idle:
            if shouldShowAssistantBubble {
                return PetOnlyBubbleContent(title: "Pikachu", body: message, footer: voiceTraceLine)
            }
            return nil
        case .listening:
            return PetOnlyBubbleContent(title: "Listening", body: voiceLine.isEmpty ? "Listening..." : voiceLine, footer: voiceTraceLine)
        }
    }

    var dailyWellnessProgressLine: String {
        let done = DailyWellnessAction.allCases.filter { dailyWellnessMask & $0.rawValue != 0 }.count
        return "\(done)/\(DailyWellnessAction.allCases.count) today"
    }

    var isDailyWellnessComplete: Bool {
        nextIncompleteDailyWellnessAction == nil
    }

    var nextDailyWellnessAction: DailyWellnessAction {
        nextIncompleteDailyWellnessAction ?? .affirm
    }

    private var nextIncompleteDailyWellnessAction: DailyWellnessAction? {
        DailyWellnessAction.allCases.first { dailyWellnessMask & $0.rawValue == 0 }
    }

    private var dailyEmotionWheelFeeling: PetFeeling? {
        let today = Self.dayFormatter.string(from: Date())
        guard dailyEmotionWheelDate == today else { return nil }
        return PetFeeling(rawValue: dailyEmotionWheelRaw)
    }

    var needLine: String {
        "Need \(careNeed.title): \(careNeed.actionLine)"
    }

    var storyLine: String {
        PetStoryCodex.chapterLine(
            stage: growthStage,
            memoryMask: careMemoryMask,
            streak: petStreak,
            need: careNeed
        )
    }

    var memoryLine: String {
        PetBondMemory.summary(mask: careMemoryMask)
    }

    var lifeSceneLine: String {
        PetLifeScene.summary(mask: lifeSceneMask, stage: growthStage)
    }

    var currentLifeScenes: [PetLifeScene] {
        PetLifeScene.scenes(for: growthStage)
    }

    var bondTimelineLine: String {
        PetBondTimelineChapter.summary(
            offeredMask: dailyBondTimelineOfferedMask,
            savedMask: bondTimelineAlbumMask,
            dismissedMask: dailyBondTimelineDismissedMask,
            latest: PetBondTimelineChapter(rawValue: latestBondTimelineRaw),
            next: nextBondTimelineChapter
        )
    }

    var bondTimelineChapters: [PetBondTimelineChapter] {
        PetBondTimelineChapter.allCases
    }

    var charmLine: String {
        PetCareCharm.summary(mask: careCharmMask)
    }

    var eventLine: String {
        "\(dailyEvent.title) \(dailyEventProgress)/\(dailyEvent.requiredSteps) · \(PetSeasonEvent.badgeSummary(mask: seasonBadgeMask))"
    }

    var seasonTrailLine: String {
        PetSeasonTrailChapter.summary(
            careCount: weeklyCareCount,
            claimedMask: seasonTrailMask,
            albumMask: seasonTrailAlbumMask,
            currentEvent: dailyEvent
        )
    }

    var seasonTrailChapters: [PetSeasonTrailChapter] {
        PetSeasonTrailChapter.allCases
    }

    var emotionLine: String {
        PetFeeling.summary(
            dailyMask: dailyFeelingMask,
            albumMask: emotionAlbumMask,
            latest: PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling
        )
    }

    var moodCareLine: String {
        let done = moodCareRecipe.steps.filter { dailyMoodCareMask & $0.rawValue != 0 }.count
        let next = moodCareRecipe.nextStep(mask: dailyMoodCareMask)?.title ?? "complete"
        return "Mood Care \(moodCareFeeling.title) \(done)/\(moodCareRecipe.steps.count) · next \(next)"
    }

    var moodCareSteps: [PetMoodCareStep] {
        moodCareRecipe.steps
    }

    var comboLine: String {
        let pieces = dailyComboActions.map { action in
            "\(action.label) \(dailyComboMask & action.rawValue == 0 ? "○" : "✓")"
        }
        return "Combo " + pieces.joined(separator: " · ")
    }

    var evolutionLine: String {
        PetGrowthStage.progressLine(companionHP: companionHP, sparkDust: sparkDust)
    }

    var evolutionQuestLine: String {
        PetEvolutionQuest.summary(claimedMask: evolutionQuestMask)
    }

    var taskLine: String {
        let quests = dailyQuests
        let done = quests.filter { dailyQuestMask & $0.rawValue != 0 }.count
        let labels = quests.map { quest in
            "\(quest.shortLabel)\(dailyQuestMask & quest.rawValue == 0 ? "○" : "✓")"
        }
        return "Tasks \(done)/\(quests.count) " + labels.joined(separator: " ")
    }

    var bondBoardLine: String {
        let contracts = dailyBondContracts
        let done = contracts.filter { dailyBondBoardMask & $0.rawValue != 0 }.count
        let next = nextBondContract?.shortLabel ?? "clear"
        return "Bond Board \(done)/\(contracts.count) · next \(next)"
    }

    var bondBoardContracts: [PetBondContract] {
        dailyBondContracts
    }

    var weeklyLine: String {
        let chapters = PetWeeklyTrailChapter.summary(
            careCount: weeklyCareCount,
            albumMask: weeklyTrailAlbumMask
        )
        let milestones = PetStreakMilestone.summary(
            careCount: weeklyCareCount,
            rewardMask: weeklyRewardMask
        )
        return "\(chapters) · \(milestones)"
    }

    var weeklyTrailChapters: [PetWeeklyTrailChapter] {
        PetWeeklyTrailChapter.allCases
    }

    var recoveryLine: String {
        PetRecoveryScene.summary(
            mask: recoveryAlbumMask,
            shieldCount: streakShieldCount,
            latest: PetRecoveryScene(rawValue: latestRecoverySceneRaw)
        )
    }

    var recoveryScenes: [PetRecoveryScene] {
        PetRecoveryScene.allCases
    }

    var ambientLine: String {
        PetAmbientMoment.summary(
            dailyMask: dailyAmbientMask,
            albumMask: ambientAlbumMask,
            latest: PetAmbientMoment(rawValue: latestAmbientMomentRaw)
        )
    }

    var ambientMoments: [PetAmbientMoment] {
        PetAmbientMoment.allCases
    }

    var routeLine: String {
        PetDailyRouteStep.summary(
            dailyMask: dailyRouteMask,
            offeredMask: dailyRouteOfferedMask,
            dismissedMask: dailyRouteDismissedMask,
            albumMask: routeAlbumMask,
            route: dailyRouteSteps,
            latest: PetDailyRouteStep(rawValue: latestRouteStepRaw)
        )
    }

    var routeSteps: [PetDailyRouteStep] {
        dailyRouteSteps
    }

    var carePulseLine: String {
        let offered = PetCareVital.count(mask: dailyCarePulseOfferedMask)
        let answered = PetCareVital.count(mask: dailyCarePulseAnsweredMask)
        let dismissed = PetCareVital.count(mask: dailyCarePulseDismissedMask)
        return "Care Pulses \(answered)/\(PetCareVital.allCases.count) · offered \(offered) · skipped \(dismissed)"
    }

    var carePulseVitals: [PetCareVital] {
        PetCareVital.allCases
    }

    var careWindowLine: String {
        PetCareMoment.summary(
            dailyMask: dailyCareWindowMask,
            albumMask: careWindowAlbumMask,
            current: careMoment
        )
    }

    var careWindowMoments: [PetCareMoment] {
        PetCareMoment.allCases
    }

    var careChestLine: String {
        PetCareChest.summary(
            offeredMask: dailyCareChestOfferedMask,
            claimedMask: dailyCareChestClaimedMask,
            dismissedMask: dailyCareChestDismissedMask,
            albumMask: careChestAlbumMask,
            next: nextCareChest
        )
    }

    var careChests: [PetCareChest] {
        PetCareChest.allCases
    }

    var cheerRhythmLine: String {
        PetDaypartNudge.summary(
            offeredMask: dailyNudgeOfferedMask,
            answeredMask: dailyNudgeAnsweredMask,
            dismissedMask: dailyNudgeDismissedMask
        )
    }

    var cheerPingLine: String {
        let offered = PetCheerPing.count(mask: dailyCheerPingOfferedMask)
        let answered = PetCheerPing.count(mask: dailyCheerPingAnsweredMask)
        let dismissed = PetCheerPing.count(mask: dailyCheerPingDismissedMask)
        let nextText = nextCheerPing.map { "next \($0.shortLabel)" } ?? "day clear"
        return "Cheer Pings \(answered)/\(PetCheerPing.allCases.count) · offered \(offered) · skipped \(dismissed) · \(nextText)"
    }

    var moodWeatherLine: String {
        let offered = PetMoodWeather.count(mask: dailyMoodWeatherOfferedMask)
        let answered = PetMoodWeather.count(mask: dailyMoodWeatherAnsweredMask)
        let dismissed = PetMoodWeather.count(mask: dailyMoodWeatherDismissedMask)
        return "Mood Weather \(currentMoodWeather.title) · answered \(answered)/\(PetMoodWeather.allCases.count) · offered \(offered) · skipped \(dismissed)"
    }

    var dailyJourneyLine: String {
        PetDailyNudgeJourneyPhase.summary(
            offeredMask: dailyJourneyOfferedMask,
            answeredMask: dailyJourneyAnsweredMask,
            dismissedMask: dailyJourneyDismissedMask,
            albumMask: journeyAlbumMask,
            current: dailyJourneyPhase
        )
    }

    var dailyJourneyPhases: [PetDailyNudgeJourneyPhase] {
        PetDailyNudgeJourneyPhase.allCases
    }

    var visitLine: String {
        PetVisitBeat.summary(
            offeredMask: dailyVisitOfferedMask,
            answeredMask: dailyVisitAnsweredMask,
            dismissedMask: dailyVisitDismissedMask,
            albumMask: visitAlbumMask,
            current: currentVisitBeat
        )
    }

    var visitBeats: [PetVisitBeat] {
        PetVisitBeat.allCases
    }

    var sparkWheelLine: String {
        PetSparkWheelCycle.summary(
            offeredMask: dailySparkWheelOfferedMask,
            startedMask: dailySparkWheelStartedMask,
            claimedMask: dailySparkWheelClaimedMask,
            dismissedMask: dailySparkWheelDismissedMask,
            albumMask: sparkWheelAlbumMask,
            active: activeSparkWheelCycle,
            remainingSeconds: sparkWheelRemainingSeconds
        )
    }

    var sparkWheelCycles: [PetSparkWheelCycle] {
        PetSparkWheelCycle.allCases
    }

    var exchangeBoardLine: String {
        PetExchangeBoardStep.summary(
            doneMask: dailyExchangeDoneMask,
            offeredMask: dailyExchangeOfferedMask,
            answeredMask: dailyExchangeAnsweredMask,
            dismissedMask: dailyExchangeDismissedMask,
            next: nextExchangeBoardStep
        )
    }

    var exchangeBoardSteps: [PetExchangeBoardStep] {
        PetExchangeBoardStep.allCases
    }

    var cheerDialogueLine: String {
        PetCheerDialogue.summary(
            offeredMask: dailyCheerDialogueOfferedMask,
            answeredMask: dailyCheerDialogueAnsweredMask,
            dismissedMask: dailyCheerDialogueDismissedMask
        )
    }

    var cheerIntentLine: String {
        PetCheerIntent.summary(
            offeredMask: dailyCheerIntentOfferedMask,
            answeredMask: dailyCheerIntentAnsweredMask,
            dismissedMask: dailyCheerIntentDismissedMask,
            albumMask: cheerIntentAlbumMask
        )
    }

    var cheerMemoryLine: String {
        let latest = PetCheerMemory(rawValue: latestCheerMemoryRaw) ?? .warmCheck
        return PetCheerMemory.summary(
            dailyMask: dailyCheerMemoryMask,
            albumMask: cheerMemoryAlbumMask,
            latest: latest
        )
    }

    var cheerMemories: [PetCheerMemory] {
        PetCheerMemory.allCases
    }

    var cheerScriptLine: String {
        PetCheerScript.summary(
            offeredMask: dailyCheerScriptOfferedMask,
            answeredMask: dailyCheerScriptAnsweredMask,
            dismissedMask: dailyCheerScriptDismissedMask,
            albumMask: cheerScriptAlbumMask
        )
    }

    var cheerScripts: [PetCheerScript] {
        PetCheerScript.allCases
    }

    var moodStoryLine: String {
        PetMoodStory.summary(
            offeredMask: dailyMoodStoryOfferedMask,
            answeredMask: dailyMoodStoryAnsweredMask,
            dismissedMask: dailyMoodStoryDismissedMask,
            albumMask: moodStoryAlbumMask,
            latest: PetMoodStory(rawValue: latestMoodStoryRaw)
        )
    }

    var moodStories: [PetMoodStory] {
        PetMoodStory.allCases
    }

    var feelingRitualLine: String {
        PetFeelingRitual.summary(
            offeredMask: dailyFeelingRitualOfferedMask,
            answeredMask: dailyFeelingRitualAnsweredMask,
            dismissedMask: dailyFeelingRitualDismissedMask,
            albumMask: feelingRitualAlbumMask,
            latest: PetFeelingRitual(rawValue: latestFeelingRitualRaw)
        )
    }

    var feelingRituals: [PetFeelingRitual] {
        PetFeelingRitual.allCases
    }

    var fieldNoteLine: String {
        PetFieldNote.summary(
            offeredMask: dailyFieldNoteOfferedMask,
            savedMask: dailyFieldNoteSavedMask,
            dismissedMask: dailyFieldNoteDismissedMask,
            albumMask: fieldNoteAlbumMask,
            latest: PetFieldNote(rawValue: latestFieldNoteRaw)
        )
    }

    var fieldNotes: [PetFieldNote] {
        PetFieldNote.allCases
    }

    var scoutTripLine: String {
        PetScoutTrip.summary(
            startedMask: dailyScoutTripStartedMask,
            returnedMask: dailyScoutTripReturnedMask,
            albumMask: scoutTripAlbumMask,
            active: PetScoutTrip(rawValue: activeScoutTripRaw),
            remainingSeconds: scoutTripRemainingSeconds,
            latest: PetScoutTrip(rawValue: latestScoutTripRaw)
        )
    }

    var scoutTrips: [PetScoutTrip] {
        PetScoutTrip.allCases
    }

    var scoutTripRemainingSeconds: Int? {
        guard activeScoutTripRaw != 0, activeScoutTripStartedAt > 0 else { return nil }
        let elapsed = Date().timeIntervalSince1970 - activeScoutTripStartedAt
        return max(0, Int(ceil(Self.scoutTripSeconds - elapsed)))
    }

    var affectionLine: String {
        PetAffectionGesture.summary(
            offeredMask: dailyAffectionOfferedMask,
            givenMask: dailyAffectionGivenMask,
            dismissedMask: dailyAffectionDismissedMask,
            albumMask: affectionAlbumMask,
            latest: PetAffectionGesture(rawValue: latestAffectionRaw)
        )
    }

    var affectionGestures: [PetAffectionGesture] {
        PetAffectionGesture.allCases
    }

    var homeLine: String {
        PetHomeRoom.summary(
            offeredMask: dailyHomeOfferedMask,
            visitedMask: dailyHomeVisitedMask,
            dismissedMask: dailyHomeDismissedMask,
            albumMask: homeAlbumMask,
            latest: PetHomeRoom(rawValue: latestHomeRoomRaw)
        )
    }

    var homeRooms: [PetHomeRoom] {
        PetHomeRoom.allCases
    }

    var errandLine: String {
        PetDailyErrand.summary(
            offeredMask: dailyErrandOfferedMask,
            doneMask: dailyErrandDoneMask,
            dismissedMask: dailyErrandDismissedMask,
            albumMask: errandAlbumMask,
            latest: PetDailyErrand(rawValue: latestErrandRaw)
        )
    }

    var dailyErrands: [PetDailyErrand] {
        PetDailyErrand.allCases
    }

    var userCheckLine: String {
        PetUserCheckIn.summary(
            offeredMask: dailyUserCheckOfferedMask,
            answeredMask: dailyUserCheckAnsweredMask,
            dismissedMask: dailyUserCheckDismissedMask,
            albumMask: userCheckAlbumMask,
            latest: PetUserCheckIn(rawValue: latestUserCheckRaw)
        )
    }

    var userCheckIns: [PetUserCheckIn] {
        PetUserCheckIn.allCases
    }

    var wishLine: String {
        PetWish.summary(
            offeredMask: dailyWishOfferedMask,
            fulfilledMask: dailyWishFulfilledMask,
            dismissedMask: dailyWishDismissedMask,
            albumMask: wishAlbumMask,
            latest: PetWish(rawValue: latestWishRaw)
        )
    }

    var wishes: [PetWish] {
        PetWish.allCases
    }

    var toyLine: String {
        PetToy.summary(
            offeredMask: dailyToyOfferedMask,
            playedMask: dailyToyPlayedMask,
            dismissedMask: dailyToyDismissedMask,
            albumMask: toyAlbumMask,
            latest: PetToy(rawValue: latestToyRaw)
        )
    }

    var toys: [PetToy] {
        PetToy.allCases
    }

    var trickLine: String {
        PetTrick.summary(
            offeredMask: dailyTrickOfferedMask,
            practicedMask: dailyTrickPracticedMask,
            dismissedMask: dailyTrickDismissedMask,
            albumMask: trickAlbumMask,
            latest: PetTrick(rawValue: latestTrickRaw),
            stage: growthStage
        )
    }

    var tricks: [PetTrick] {
        PetTrick.allCases
    }

    var cheerIntentTitle: String {
        (PetCheerIntent(rawValue: cheerIntentRaw) ?? .checkIn).title
    }

    var cipherLine: String {
        if dailyCipherSolved {
            return "\(careMoment.title) · Cipher \(dailyCipher.answer) ✓ · Boost \(dailyBoosterUsed ? "used" : "ready")"
        }
        return "\(careMoment.title) · Cipher: \(dailyCipher.clue) · Boost \(dailyBoosterUsed ? "used" : "ready")"
    }

    var upgradeLine: String {
        let next = nextUpgradeCandidate
        return "Next \(next.shortName) \(next.level + 1): \(next.cost) Sparks"
    }

    var upgradeDeckCards: [PetUpgradeDeckCard] {
        [
            PetUpgradeDeckCard(kind: .snack, level: snackLevel),
            PetUpgradeDeckCard(kind: .lesson, level: lessonLevel),
            PetUpgradeDeckCard(kind: .quest, level: questLevel),
            PetUpgradeDeckCard(kind: .nest, level: nestLevel),
            PetUpgradeDeckCard(kind: .cheer, level: cheerLevel),
            PetUpgradeDeckCard(kind: .spark, level: sparkLevel),
            PetUpgradeDeckCard(kind: .focus, level: focusLevel),
            PetUpgradeDeckCard(kind: .cipher, level: cipherLevel)
        ]
    }

    var upgradeDeckLine: String {
        let total = upgradeDeckCards.reduce(0) { $0 + $1.level }
        let unlocked = upgradeDeckCards.filter(\.isUnlocked).count
        let next = nextUpgradeCandidate
        return "Cards \(unlocked)/\(upgradeDeckCards.count) · Levels \(total) · Next \(next.name) \(next.cost)"
    }

    var journalUpgradeProgress: Double {
        Double(upgradeDeckCards.filter(\.isUnlocked).count) / Double(max(1, upgradeDeckCards.count))
    }

    var journalUpgradeCaption: String {
        let next = nextUpgradeCandidate
        return "\(upgradeDeckLine) · \(sparkDust) Sparks held · next \(next.shortName) Lv \(next.level + 1)"
    }

    var journalUpgradeSpriteLine: String {
        "Card sprite: \(nextUpgradeCandidate.kind.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var petScale: CGFloat {
        growthStage.spriteScale
    }

    var loreLine: String {
        PetLoreCodex.line(
            stage: growthStage,
            feeling: petFeeling,
            snackLevel: snackLevel,
            lessonLevel: lessonLevel,
            questLevel: questLevel,
            nestLevel: nestLevel,
            cheerLevel: cheerLevel,
            sparkLevel: sparkLevel,
            focusLevel: focusLevel,
            cipherLevel: cipherLevel
        )
    }

    var journalGrowthCaption: String {
        "\(growthStage.title) · HP \(companionHP)/10 · Sparks \(sparkDust)/420"
    }

    var journalGrowthProgress: Double {
        min(1, max(Double(companionHP) / 10.0, Double(sparkDust) / 420.0))
    }

    var growthJourneyLine: String {
        let latest = PetGrowthStage(rawValue: latestGrowthStageRaw) ?? growthStage
        return PetGrowthStage.summary(mask: growthJourneyMask, latest: latest)
    }

    var growthJourneyStages: [PetGrowthStage] {
        PetGrowthStage.allCases
    }

    var journalGrowthJourneyProgress: Double {
        Double(PetGrowthStage.count(mask: growthJourneyMask)) / Double(PetGrowthStage.allCases.count)
    }

    var journalGrowthJourneyCaption: String {
        "\(growthJourneyLine) · current \(growthStage.title)"
    }

    var journalGrowthJourneySpriteLine: String {
        let latest = PetGrowthStage(rawValue: latestGrowthStageRaw) ?? growthStage
        return "Journey sprite: \(latest.transitionSpriteName)"
    }

    var journalEvolutionQuestProgress: Double {
        Double(PetEvolutionQuest.allCases.filter { evolutionQuestMask & $0.rawValue != 0 }.count) / Double(PetEvolutionQuest.allCases.count)
    }

    var journalEvolutionQuestCaption: String {
        let next = PetEvolutionQuest.allCases.first { evolutionQuestMask & $0.rawValue == 0 }
        if let next {
            let percent = Int((evolutionQuestProgress(for: next) * 100).rounded())
            return "\(evolutionQuestLine) · \(percent)% \(next.shortLabel)"
        }
        return evolutionQuestLine
    }

    var journalEvolutionQuestSpriteLine: String {
        let next = PetEvolutionQuest.allCases.first { evolutionQuestMask & $0.rawValue == 0 }
            ?? PetEvolutionQuest.guardianOath
        return "Evolution sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalMoodCaption: String {
        let latest = PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling
        return "\(latest.title) · \(latest.helperLine)"
    }

    var journalMoodProgress: Double {
        Double(PetFeeling.count(mask: emotionAlbumMask)) / Double(PetFeeling.allCases.count)
    }

    var emotionEpisodeLine: String {
        let latest = PetEmotionEpisode(rawValue: latestEmotionEpisodeRaw) ?? PetEmotionEpisode.episode(
            for: "current",
            feeling: PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling
        )
        return PetEmotionEpisode.summary(
            dailyMask: dailyEmotionEpisodeMask,
            albumMask: emotionEpisodeAlbumMask,
            latest: latest
        )
    }

    var emotionEpisodes: [PetEmotionEpisode] {
        PetEmotionEpisode.allCases
    }

    var journalEmotionEpisodeProgress: Double {
        Double(PetEmotionEpisode.count(mask: emotionEpisodeAlbumMask)) / Double(PetEmotionEpisode.allCases.count)
    }

    var journalEmotionEpisodeCaption: String {
        emotionEpisodeLine
    }

    var journalEmotionEpisodeSpriteLine: String {
        let latest = PetEmotionEpisode(rawValue: latestEmotionEpisodeRaw)
            ?? PetEmotionEpisode.episode(for: "current", feeling: PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling)
        return "Episode sprite: \(latest.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var emotionArcLine: String {
        let feeling = PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling
        let episode = PetEmotionEpisode(rawValue: latestEmotionEpisodeRaw)
            ?? PetEmotionEpisode.episode(for: "current", feeling: feeling)
        let latest = PetEmotionArc(rawValue: latestEmotionArcRaw)
            ?? PetEmotionArc.arc(trigger: "current", feeling: feeling, episode: episode)
        return PetEmotionArc.summary(
            dailyMask: dailyEmotionArcMask,
            albumMask: emotionArcAlbumMask,
            latest: latest
        )
    }

    var emotionArcs: [PetEmotionArc] {
        PetEmotionArc.allCases
    }

    var journalEmotionArcProgress: Double {
        Double(PetEmotionArc.count(mask: emotionArcAlbumMask)) / Double(PetEmotionArc.allCases.count)
    }

    var journalEmotionArcCaption: String {
        let latest = PetEmotionArc(rawValue: latestEmotionArcRaw)
            ?? PetEmotionArc.arc(
                trigger: "current",
                feeling: PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling,
                episode: PetEmotionEpisode(rawValue: latestEmotionEpisodeRaw)
                    ?? PetEmotionEpisode.episode(for: "current", feeling: petFeeling)
            )
        return "\(emotionArcLine) · \(latest.resolutionLine)"
    }

    var journalEmotionArcSpriteLine: String {
        let latest = PetEmotionArc(rawValue: latestEmotionArcRaw)
            ?? PetEmotionArc.arc(
                trigger: "current",
                feeling: PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling,
                episode: PetEmotionEpisode(rawValue: latestEmotionEpisodeRaw)
                    ?? PetEmotionEpisode.episode(for: "current", feeling: petFeeling)
            )
        return "Arc sprites: \(latest.spriteRequestNames.map { $0.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug) }.joined(separator: " · "))"
    }

    var journalMoodStoryProgress: Double {
        Double(PetMoodStory.count(mask: dailyMoodStoryAnsweredMask)) / Double(PetMoodStory.allCases.count)
    }

    var journalMoodStoryCaption: String {
        moodStoryLine
    }

    var journalMoodStorySpriteLine: String {
        let next = PetMoodStory.next(
            feeling: petFeeling,
            careMoment: careMoment,
            stage: growthStage,
            offeredMask: dailyMoodStoryOfferedMask,
            index: PetMoodStory.count(mask: dailyMoodStoryOfferedMask)
                + PetMoodStory.count(mask: dailyMoodStoryAnsweredMask)
        ) ?? PetMoodStory(rawValue: latestMoodStoryRaw) ?? .brightHello
        return "Mood story sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalFeelingRitualProgress: Double {
        Double(PetFeelingRitual.count(mask: feelingRitualAlbumMask)) / Double(PetFeelingRitual.allCases.count)
    }

    var journalFeelingRitualCaption: String {
        feelingRitualLine
    }

    var journalFeelingRitualSpriteLine: String {
        let next = PetFeelingRitual.next(
            feeling: petFeeling,
            offeredMask: dailyFeelingRitualOfferedMask,
            index: PetFeelingRitual.count(mask: dailyFeelingRitualOfferedMask)
                + PetFeelingRitual.count(mask: feelingRitualAlbumMask)
        ) ?? PetFeelingRitual(rawValue: latestFeelingRitualRaw) ?? .morningSpark
        return "Feeling ritual sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalFieldNoteProgress: Double {
        Double(PetFieldNote.count(mask: dailyFieldNoteSavedMask)) / Double(PetFieldNote.allCases.count)
    }

    var journalFieldNoteCaption: String {
        fieldNoteLine
    }

    var journalFieldNoteSpriteLine: String {
        let next = PetFieldNote.next(
            daypart: daypartNudge,
            feeling: petFeeling,
            stage: growthStage,
            offeredMask: dailyFieldNoteOfferedMask,
            index: PetFieldNote.count(mask: dailyFieldNoteOfferedMask)
                + PetFieldNote.count(mask: dailyFieldNoteSavedMask)
        ) ?? PetFieldNote(rawValue: latestFieldNoteRaw) ?? .deskScout
        return "Field note sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalScoutTripProgress: Double {
        Double(PetScoutTrip.count(mask: dailyScoutTripReturnedMask)) / Double(PetScoutTrip.allCases.count)
    }

    var journalScoutTripCaption: String {
        scoutTripLine
    }

    var journalScoutTripSpriteLine: String {
        let next = nextScoutTrip ?? PetScoutTrip(rawValue: latestScoutTripRaw) ?? .deskEdge
        return "Scout sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalAffectionProgress: Double {
        Double(PetAffectionGesture.count(mask: dailyAffectionGivenMask)) / Double(PetAffectionGesture.allCases.count)
    }

    var journalAffectionCaption: String {
        affectionLine
    }

    var journalAffectionSpriteLine: String {
        let next = nextAffectionGesture ?? PetAffectionGesture(rawValue: latestAffectionRaw) ?? .headPat
        return "Bond sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalHomeProgress: Double {
        Double(PetHomeRoom.count(mask: dailyHomeVisitedMask)) / Double(PetHomeRoom.allCases.count)
    }

    var journalHomeCaption: String {
        homeLine
    }

    var journalHomeSpriteLine: String {
        let next = nextHomeRoom ?? PetHomeRoom(rawValue: latestHomeRoomRaw) ?? .cozyNest
        return "Home sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalErrandProgress: Double {
        Double(PetDailyErrand.count(mask: dailyErrandDoneMask)) / Double(PetDailyErrand.allCases.count)
    }

    var journalErrandCaption: String {
        errandLine
    }

    var journalErrandSpriteLine: String {
        let next = nextDailyErrand ?? PetDailyErrand(rawValue: latestErrandRaw) ?? .sparkGather
        return "Errand sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalUserCheckProgress: Double {
        Double(PetUserCheckIn.count(mask: dailyUserCheckAnsweredMask)) / Double(PetUserCheckIn.allCases.count)
    }

    var journalUserCheckCaption: String {
        userCheckLine
    }

    var journalUserCheckSpriteLine: String {
        let next = nextUserCheckIn ?? PetUserCheckIn(rawValue: latestUserCheckRaw) ?? .bright
        return "User check sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalWishProgress: Double {
        Double(PetWish.count(mask: dailyWishFulfilledMask)) / Double(PetWish.allCases.count)
    }

    var journalWishCaption: String {
        wishLine
    }

    var journalWishSpriteLine: String {
        let next = nextWish ?? PetWish(rawValue: latestWishRaw) ?? .helloPat
        return "Wish sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalToyProgress: Double {
        Double(PetToy.count(mask: dailyToyPlayedMask)) / Double(PetToy.allCases.count)
    }

    var journalToyCaption: String {
        toyLine
    }

    var journalToySpriteLine: String {
        let next = nextToy ?? PetToy(rawValue: latestToyRaw) ?? .sparkBall
        return "Toy sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalTrickProgress: Double {
        let unlocked = PetTrick.unlocked(stage: growthStage).count
        return Double(PetTrick.count(mask: dailyTrickPracticedMask)) / Double(max(1, unlocked))
    }

    var journalTrickCaption: String {
        trickLine
    }

    var journalTrickSpriteLine: String {
        let next = nextTrick ?? PetTrick(rawValue: latestTrickRaw) ?? .helloWave
        return "Trick sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalMoodCareProgress: Double {
        moodCareRecipe.progress(mask: dailyMoodCareMask)
    }

    var journalMoodCareCaption: String {
        "\(moodCareLine) · Album \(PetFeeling.count(mask: moodCareAlbumMask))/\(PetFeeling.allCases.count)"
    }

    var journalMoodCareSpriteLine: String {
        let step = moodCareRecipe.nextStep(mask: dailyMoodCareMask) ?? moodCareRecipe.steps.last ?? .soothe
        return "Mood care sprite: pet-\(growthStage.assetSlug)-mood-care-\(moodCareFeeling.assetSlug)-\(step.spriteSlug).png"
    }

    var journalMemoryProgress: Double {
        Double(PetBondMemory.allCases.filter { careMemoryMask & $0.rawValue != 0 }.count) / Double(PetBondMemory.allCases.count)
    }

    var journalLifeSceneProgress: Double {
        Double(PetLifeScene.count(mask: lifeSceneMask, stage: growthStage)) / Double(max(1, currentLifeScenes.count))
    }

    var journalLifeSceneCaption: String {
        let totalDone = PetLifeScene.count(mask: lifeSceneMask)
        return "\(lifeSceneLine) · Album \(totalDone)/\(PetLifeScene.allCases.count)"
    }

    var journalLifeSceneSpriteLine: String {
        let scene = nextLifeScene ?? currentLifeScenes.last ?? .tinyFirstLook
        return "Life sprite: \(scene.spriteRequestName)"
    }

    var journalBondTimelineProgress: Double {
        Double(PetBondTimelineChapter.count(mask: bondTimelineAlbumMask)) / Double(PetBondTimelineChapter.allCases.count)
    }

    var journalBondTimelineCaption: String {
        bondTimelineLine
    }

    var journalBondTimelineSpriteLine: String {
        let chapter = nextBondTimelineChapter ?? PetBondTimelineChapter(rawValue: latestBondTimelineRaw) ?? .firstHello
        return "Timeline sprite: \(chapter.spriteRequestName.replacingOccurrences(of: "{stage}", with: chapter.minimumStage.assetSlug))"
    }

    var journalBadgeCaption: String {
        "\(dailyEvent.title) · \(dailyEventProgress)/\(dailyEvent.requiredSteps) today · \(PetSeasonEvent.badgeSummary(mask: seasonBadgeMask)) · \(seasonTrailLine)"
    }

    var journalBadgeProgress: Double {
        Double(PetSeasonEvent.allCases.filter { seasonBadgeMask & $0.rawValue != 0 }.count) / Double(PetSeasonEvent.allCases.count)
    }

    var journalSeasonTrailProgress: Double {
        Double(PetSeasonTrailChapter.count(mask: seasonTrailMask)) / Double(PetSeasonTrailChapter.allCases.count)
    }

    var journalSeasonTrailCaption: String {
        seasonTrailLine
    }

    var journalSeasonTrailSpriteLine: String {
        let chapter = PetSeasonTrailChapter.preview(careCount: weeklyCareCount, claimedMask: seasonTrailMask)
        return "Season trail sprite: \(chapter.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCharmCaption: String {
        charmLine
    }

    var journalCharmProgress: Double {
        Double(PetCareCharm.allCases.filter { careCharmMask & $0.rawValue != 0 }.count) / Double(PetCareCharm.allCases.count)
    }

    var journalCharmSpriteLine: String {
        let next = PetCareCharm.allCases.first { careCharmMask & $0.rawValue == 0 }
            ?? PetCareCharm.vitalGlow
        return "Charm sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalRitualCaption: String {
        let comboDone = dailyComboActions.filter { dailyComboMask & $0.rawValue != 0 }.count
        let questDone = dailyQuests.filter { dailyQuestMask & $0.rawValue != 0 }.count
        let bondDone = dailyBondContracts.filter { dailyBondBoardMask & $0.rawValue != 0 }.count
        let routeDone = dailyRouteSteps.filter { dailyRouteMask & $0.rawValue != 0 }.count
        let windowDone = PetCareMoment.count(mask: dailyCareWindowMask)
        let chestDone = PetCareChest.count(mask: dailyCareChestClaimedMask)
        let exchangeDone = PetExchangeBoardStep.count(mask: dailyExchangeDoneMask)
        let next = isCareWindowDone(careMoment) ? (nextBondContract?.title ?? nextDailyQuest?.title ?? "Board clear") : "\(careMoment.title) window"
        return "Exchange \(exchangeDone)/\(PetExchangeBoardStep.allCases.count) · Route \(routeDone)/\(dailyRouteSteps.count) · Windows \(windowDone)/\(PetCareMoment.allCases.count) · Chests \(chestDone)/\(PetCareChest.allCases.count) · Combo \(comboDone)/\(dailyComboActions.count) · Tasks \(questDone)/\(dailyQuests.count) · Bonds \(bondDone)/\(dailyBondContracts.count) · Next \(next)"
    }

    var journalRitualProgress: Double {
        let comboDone = dailyComboActions.filter { dailyComboMask & $0.rawValue != 0 }.count
        let questDone = dailyQuests.filter { dailyQuestMask & $0.rawValue != 0 }.count
        let bondDone = dailyBondContracts.filter { dailyBondBoardMask & $0.rawValue != 0 }.count
        let routeDone = dailyRouteSteps.filter { dailyRouteMask & $0.rawValue != 0 }.count
        let windowDone = PetCareMoment.count(mask: dailyCareWindowMask)
        let chestDone = PetCareChest.count(mask: dailyCareChestClaimedMask)
        let exchangeDone = PetExchangeBoardStep.count(mask: dailyExchangeDoneMask)
        let total = PetExchangeBoardStep.allCases.count + dailyRouteSteps.count + PetCareMoment.allCases.count + PetCareChest.allCases.count + dailyComboActions.count + dailyQuests.count + dailyBondContracts.count + dailyEvent.requiredSteps
        let done = exchangeDone + routeDone + windowDone + chestDone + comboDone + questDone + bondDone + min(dailyEventProgress, dailyEvent.requiredSteps)
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    var journalRouteProgress: Double {
        let route = dailyRouteSteps
        let done = route.filter { dailyRouteMask & $0.rawValue != 0 }.count
        return Double(done) / Double(max(1, route.count))
    }

    var journalRouteCaption: String {
        routeLine
    }

    var journalRouteSpriteLine: String {
        let latest = PetDailyRouteStep(rawValue: latestRouteStepRaw)
        let next = dailyRouteSteps.first { dailyRouteMask & $0.rawValue == 0 }
            ?? latest
            ?? .wakeSpark
        return "Route sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCareWindowProgress: Double {
        Double(PetCareMoment.count(mask: dailyCareWindowMask)) / Double(PetCareMoment.allCases.count)
    }

    var journalCareWindowCaption: String {
        let done = PetCareMoment.count(mask: dailyCareWindowMask)
        let albumDone = PetCareMoment.count(mask: careWindowAlbumMask)
        let status = isCareWindowDone(careMoment) ? "done" : "ready"
        return "Windows \(done)/\(PetCareMoment.allCases.count) today · \(careMoment.title) \(status) · Album \(albumDone)/\(PetCareMoment.allCases.count)"
    }

    var journalCareWindowSpriteLine: String {
        let moment = PetCareMoment(rawValue: latestCareWindowRaw) ?? careMoment
        return "Care window sprite: \(moment.spriteRequestName(stage: growthStage))"
    }

    var journalCareChestProgress: Double {
        Double(PetCareChest.count(mask: dailyCareChestClaimedMask)) / Double(PetCareChest.allCases.count)
    }

    var journalCareChestCaption: String {
        careChestLine
    }

    var journalCareChestSpriteLine: String {
        let chest = nextCareChest ?? PetCareChest(rawValue: latestCareChestRaw) ?? .morningSpark
        return "Care chest sprite: \(chest.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalBondBoardProgress: Double {
        let contracts = dailyBondContracts
        let done = contracts.filter { dailyBondBoardMask & $0.rawValue != 0 }.count
        return Double(done) / Double(max(1, contracts.count))
    }

    var journalBondBoardCaption: String {
        let albumDone = PetBondContract.allCases.filter { bondContractAlbumMask & $0.rawValue != 0 }.count
        return "\(bondBoardLine) · Album \(albumDone)/\(PetBondContract.allCases.count)"
    }

    var journalBondBoardSpriteLine: String {
        let contract = nextBondContract ?? dailyBondContracts.last ?? .morningHello
        return "Board sprite: \(contract.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalVitalProgress: Double {
        Double(snackVital + restVital + playVital + focusVital) / Double(Self.maxVital * PetCareVital.allCases.count)
    }

    var journalVitalCaption: String {
        "\(vitalLine) · \(lowestVital.lowLine)"
    }

    var journalVitalSpriteLine: String {
        "Vitals sprite: \(lowestVital.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCarePulseProgress: Double {
        Double(PetCareVital.count(mask: dailyCarePulseAnsweredMask)) / Double(PetCareVital.allCases.count)
    }

    var journalCarePulseCaption: String {
        if let nextCarePulseVital {
            return "\(carePulseLine) · next \(nextCarePulseVital.pulseTitle)"
        }
        return "\(carePulseLine) · all urgent care handled"
    }

    var journalCarePulseSpriteLine: String {
        let vital = nextCarePulseVital
            ?? PetCareVital(rawValue: latestCarePulseRaw - 1)
            ?? lowestVital
        return "Care pulse sprite: \(vital.pulseSpriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalStreakCaption: String {
        let chapters = PetWeeklyTrailChapter.summary(
            careCount: weeklyCareCount,
            albumMask: weeklyTrailAlbumMask
        )
        return "\(chapters) · streak \(petStreak) · shields \(streakShieldCount)/3"
    }

    var journalStreakProgress: Double {
        min(1, Double(max(0, weeklyCareCount)) / 7.0)
    }

    var journalStreakSpriteLine: String {
        let next = PetWeeklyTrailChapter.next(careCount: weeklyCareCount)
            ?? PetWeeklyTrailChapter.latest(careCount: weeklyCareCount)
        return "Week chapter sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalRecoveryProgress: Double {
        Double(PetRecoveryScene.count(mask: recoveryAlbumMask)) / Double(PetRecoveryScene.allCases.count)
    }

    var journalRecoveryCaption: String {
        recoveryLine
    }

    var journalRecoverySpriteLine: String {
        let latest = PetRecoveryScene(rawValue: latestRecoverySceneRaw)
        let next = PetRecoveryScene.allCases.first { recoveryAlbumMask & $0.rawValue == 0 }
            ?? latest
            ?? .softReturn
        return "Recovery sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalAmbientProgress: Double {
        Double(PetAmbientMoment.count(mask: ambientAlbumMask)) / Double(PetAmbientMoment.allCases.count)
    }

    var journalAmbientCaption: String {
        ambientLine
    }

    var journalAmbientSpriteLine: String {
        let latest = PetAmbientMoment(rawValue: latestAmbientMomentRaw)
        let next = PetAmbientMoment.allCases.first { ambientAlbumMask & $0.rawValue == 0 }
            ?? latest
            ?? .firstLook
        return "Ambient sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalExchangeProgress: Double {
        Double(PetExchangeBoardStep.count(mask: dailyExchangeDoneMask)) / Double(PetExchangeBoardStep.allCases.count)
    }

    var journalExchangeCaption: String {
        exchangeBoardLine
    }

    var journalExchangeSpriteLine: String {
        let next = nextExchangeBoardStep
            ?? PetExchangeBoardStep(rawValue: latestExchangeRaw)
            ?? .careTap
        return "Exchange sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCheerProgress: Double {
        let answered = PetDailyNudgeJourneyPhase.count(mask: dailyJourneyAnsweredMask)
            + PetVisitBeat.count(mask: dailyVisitAnsweredMask)
            + PetDaypartNudge.count(mask: dailyNudgeAnsweredMask)
            + PetCheerDialogue.count(mask: dailyCheerDialogueAnsweredMask)
            + PetCheerIntent.count(mask: dailyCheerIntentAnsweredMask)
            + PetCheerScript.count(mask: dailyCheerScriptAnsweredMask)
            + PetMoodStory.count(mask: dailyMoodStoryAnsweredMask)
            + PetFieldNote.count(mask: dailyFieldNoteSavedMask)
            + PetAffectionGesture.count(mask: dailyAffectionGivenMask)
            + PetHomeRoom.count(mask: dailyHomeVisitedMask)
            + PetDailyErrand.count(mask: dailyErrandDoneMask)
            + PetUserCheckIn.count(mask: dailyUserCheckAnsweredMask)
            + PetWish.count(mask: dailyWishFulfilledMask)
            + PetToy.count(mask: dailyToyPlayedMask)
            + PetTrick.count(mask: dailyTrickPracticedMask)
        let total = PetDailyNudgeJourneyPhase.allCases.count + PetVisitBeat.allCases.count + PetDaypartNudge.allCases.count + PetCheerDialogue.allCases.count + PetCheerIntent.allCases.count + PetCheerScript.allCases.count + PetMoodStory.allCases.count + PetFieldNote.allCases.count + PetAffectionGesture.allCases.count + PetHomeRoom.allCases.count + PetDailyErrand.allCases.count + PetUserCheckIn.allCases.count + PetWish.allCases.count + PetToy.allCases.count + PetTrick.allCases.count
        return Double(answered) / Double(max(1, total))
    }

    var journalCheerCaption: String {
        let answered = PetDailyNudgeJourneyPhase.count(mask: dailyJourneyAnsweredMask)
            + PetVisitBeat.count(mask: dailyVisitAnsweredMask)
            + PetDaypartNudge.count(mask: dailyNudgeAnsweredMask)
            + PetCheerDialogue.count(mask: dailyCheerDialogueAnsweredMask)
            + PetCheerIntent.count(mask: dailyCheerIntentAnsweredMask)
            + PetCheerScript.count(mask: dailyCheerScriptAnsweredMask)
            + PetMoodStory.count(mask: dailyMoodStoryAnsweredMask)
            + PetFieldNote.count(mask: dailyFieldNoteSavedMask)
            + PetAffectionGesture.count(mask: dailyAffectionGivenMask)
            + PetHomeRoom.count(mask: dailyHomeVisitedMask)
            + PetDailyErrand.count(mask: dailyErrandDoneMask)
            + PetUserCheckIn.count(mask: dailyUserCheckAnsweredMask)
            + PetWish.count(mask: dailyWishFulfilledMask)
            + PetToy.count(mask: dailyToyPlayedMask)
            + PetTrick.count(mask: dailyTrickPracticedMask)
        let offered = PetDailyNudgeJourneyPhase.count(mask: dailyJourneyOfferedMask)
            + PetVisitBeat.count(mask: dailyVisitOfferedMask)
            + PetDaypartNudge.count(mask: dailyNudgeOfferedMask)
            + PetCheerDialogue.count(mask: dailyCheerDialogueOfferedMask)
            + PetCheerIntent.count(mask: dailyCheerIntentOfferedMask)
            + PetCheerScript.count(mask: dailyCheerScriptOfferedMask)
            + PetMoodStory.count(mask: dailyMoodStoryOfferedMask)
            + PetFieldNote.count(mask: dailyFieldNoteOfferedMask)
            + PetAffectionGesture.count(mask: dailyAffectionOfferedMask)
            + PetHomeRoom.count(mask: dailyHomeOfferedMask)
            + PetDailyErrand.count(mask: dailyErrandOfferedMask)
            + PetUserCheckIn.count(mask: dailyUserCheckOfferedMask)
            + PetWish.count(mask: dailyWishOfferedMask)
            + PetToy.count(mask: dailyToyOfferedMask)
            + PetTrick.count(mask: dailyTrickOfferedMask)
        let journeyAlbumDone = PetDailyNudgeJourneyPhase.count(mask: journeyAlbumMask)
        let visitAlbumDone = PetVisitBeat.count(mask: visitAlbumMask)
        let albumDone = PetCheerDialogue.count(mask: cheerDialogueAlbumMask)
        let intentAlbumDone = PetCheerIntent.count(mask: cheerIntentAlbumMask)
        let scriptAlbumDone = PetCheerScript.count(mask: cheerScriptAlbumMask)
        let moodStoryAlbumDone = PetMoodStory.count(mask: moodStoryAlbumMask)
        let fieldAlbumDone = PetFieldNote.count(mask: fieldNoteAlbumMask)
        let affectionAlbumDone = PetAffectionGesture.count(mask: affectionAlbumMask)
        let homeAlbumDone = PetHomeRoom.count(mask: homeAlbumMask)
        let errandAlbumDone = PetDailyErrand.count(mask: errandAlbumMask)
        let userCheckAlbumDone = PetUserCheckIn.count(mask: userCheckAlbumMask)
        let wishAlbumDone = PetWish.count(mask: wishAlbumMask)
        let toyAlbumDone = PetToy.count(mask: toyAlbumMask)
        let trickAlbumDone = PetTrick.count(mask: trickAlbumMask)
        let total = PetDailyNudgeJourneyPhase.allCases.count
            + PetVisitBeat.allCases.count
            + PetDaypartNudge.allCases.count
            + PetCheerDialogue.allCases.count
            + PetCheerIntent.allCases.count
            + PetCheerScript.allCases.count
            + PetMoodStory.allCases.count
            + PetFieldNote.allCases.count
            + PetAffectionGesture.allCases.count
            + PetHomeRoom.allCases.count
            + PetDailyErrand.allCases.count
            + PetUserCheckIn.allCases.count
            + PetWish.allCases.count
            + PetToy.allCases.count
            + PetTrick.allCases.count
        let albumParts = [
            "Journey \(journeyAlbumDone)/\(PetDailyNudgeJourneyPhase.allCases.count)",
            "Visits \(visitAlbumDone)/\(PetVisitBeat.allCases.count)",
            "Dialogues \(albumDone)/\(PetCheerDialogue.allCases.count)",
            "Types \(intentAlbumDone)/\(PetCheerIntent.allCases.count)",
            "Scripts \(scriptAlbumDone)/\(PetCheerScript.allCases.count)",
            "Mood \(moodStoryAlbumDone)/\(PetMoodStory.allCases.count)",
            "Field \(fieldAlbumDone)/\(PetFieldNote.allCases.count)",
            "Bond \(affectionAlbumDone)/\(PetAffectionGesture.allCases.count)",
            "Home \(homeAlbumDone)/\(PetHomeRoom.allCases.count)",
            "Errands \(errandAlbumDone)/\(PetDailyErrand.allCases.count)",
            "User \(userCheckAlbumDone)/\(PetUserCheckIn.allCases.count)",
            "Wishes \(wishAlbumDone)/\(PetWish.allCases.count)",
            "Toys \(toyAlbumDone)/\(PetToy.allCases.count)",
            "Tricks \(trickAlbumDone)/\(PetTrick.allCases.count)"
        ]
        return "\(answered)/\(total) answered today · \(offered) seen · \(albumParts.joined(separator: " · "))"
    }

    var journalCheerSpriteLine: String {
        let next = PetDaypartNudge.allCases.first { dailyNudgeOfferedMask & $0.rawValue == 0 }
            ?? daypartNudge
        return "Cheer sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCheerPingProgress: Double {
        Double(PetCheerPing.count(mask: dailyCheerPingAnsweredMask)) / Double(PetCheerPing.allCases.count)
    }

    var journalCheerPingCaption: String {
        let album = PetCheerPing.count(mask: cheerPingAlbumMask)
        return "\(cheerPingLine) · Album \(album)/\(PetCheerPing.allCases.count)"
    }

    var journalCheerPingSpriteLine: String {
        let next = nextCheerPing
            ?? PetCheerPing(rawValue: latestCheerPingRaw)
            ?? .wakeSpark
        return "Cheer ping sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalDailyJourneyProgress: Double {
        Double(PetDailyNudgeJourneyPhase.count(mask: dailyJourneyAnsweredMask)) / Double(PetDailyNudgeJourneyPhase.allCases.count)
    }

    var journalDailyJourneyCaption: String {
        dailyJourneyLine
    }

    var journalDailyJourneySpriteLine: String {
        let next = PetDailyNudgeJourneyPhase.allCases.first { dailyJourneyOfferedMask & $0.rawValue == 0 }
            ?? PetDailyNudgeJourneyPhase(rawValue: latestJourneyRaw)
            ?? dailyJourneyPhase
        return "Journey sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalVisitProgress: Double {
        Double(PetVisitBeat.count(mask: dailyVisitAnsweredMask)) / Double(PetVisitBeat.allCases.count)
    }

    var journalVisitCaption: String {
        visitLine
    }

    var journalVisitSpriteLine: String {
        let next = nextVisitBeat
            ?? PetVisitBeat(rawValue: latestVisitRaw)
            ?? currentVisitBeat
        return "Visit sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalSparkWheelProgress: Double {
        Double(PetSparkWheelCycle.count(mask: sparkWheelAlbumMask)) / Double(PetSparkWheelCycle.allCases.count)
    }

    var journalSparkWheelCaption: String {
        sparkWheelLine
    }

    var journalSparkWheelSpriteLine: String {
        let next = activeSparkWheelCycle
            ?? nextSparkWheelCycle
            ?? PetSparkWheelCycle(rawValue: latestSparkWheelRaw)
            ?? .firstWind
        return "Wheel sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCheerDialogueProgress: Double {
        Double(PetCheerDialogue.count(mask: dailyCheerDialogueAnsweredMask)) / Double(PetCheerDialogue.allCases.count)
    }

    var journalCheerDialogueCaption: String {
        cheerDialogueLine
    }

    var journalCheerDialogueSpriteLine: String {
        let next = PetCheerDialogue.next(
            offeredMask: dailyCheerDialogueOfferedMask,
            index: PetCheerDialogue.count(mask: dailyCheerDialogueOfferedMask)
                + PetCheerDialogue.count(mask: dailyCheerDialogueAnsweredMask)
        ) ?? .howAreYou
        return "Dialogue sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCheerIntentProgress: Double {
        Double(PetCheerIntent.count(mask: dailyCheerIntentAnsweredMask)) / Double(PetCheerIntent.allCases.count)
    }

    var journalCheerIntentCaption: String {
        cheerIntentLine
    }

    var journalCheerIntentSpriteLine: String {
        let next = PetCheerIntent.next(
            offeredMask: dailyCheerIntentOfferedMask,
            index: PetCheerIntent.count(mask: dailyCheerIntentOfferedMask)
                + PetCheerIntent.count(mask: dailyCheerIntentAnsweredMask)
        ) ?? .checkIn
        return "Intent sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCheerMemoryProgress: Double {
        Double(PetCheerMemory.count(mask: cheerMemoryAlbumMask)) / Double(PetCheerMemory.allCases.count)
    }

    var journalCheerMemoryCaption: String {
        cheerMemoryLine
    }

    var journalCheerMemorySpriteLine: String {
        let latest = PetCheerMemory(rawValue: latestCheerMemoryRaw) ?? .warmCheck
        return "Memory sprite: \(latest.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCheerScriptProgress: Double {
        Double(PetCheerScript.count(mask: dailyCheerScriptAnsweredMask)) / Double(PetCheerScript.allCases.count)
    }

    var journalCheerScriptCaption: String {
        cheerScriptLine
    }

    var journalCheerScriptSpriteLine: String {
        let next = PetCheerScript.next(
            daypart: daypartNudge,
            intent: PetCheerIntent(rawValue: cheerIntentRaw) ?? .checkIn,
            offeredMask: dailyCheerScriptOfferedMask,
            index: PetCheerScript.count(mask: dailyCheerScriptOfferedMask)
                + PetCheerScript.count(mask: dailyCheerScriptAnsweredMask)
        ) ?? .morningSpark
        return "Script sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalSpriteLine: String {
        let latest = PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling
        return "Next sprite: \(latest.spriteRequestName(stage: growthStage))"
    }

    var journalRuntimeSpriteLine: String {
        "Runtime target: \(mood.preferredSpriteName(stage: growthStage)).png"
    }

    var journalArtContextLine: String {
        let latest = PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling
        return "Stage \(growthStage.assetSlug) · Feeling \(latest.assetSlug)"
    }

    var journalArtPromptLine: String {
        "12-frame transparent strip · no text · no border · no shadow"
    }

    var journalPromptLine: String {
        "\(careNeed.title) ritual: \(careNeed.actionLine). \(storyLine)"
    }

    private func play(_ sound: PetSound) {
        soundPlayer.play(sound, enabled: soundEnabled)
    }

    private func speakPika(force: Bool = false) {
        let line = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if soundEnabled {
            markVoiceSpeaking()
        }
        if line.isEmpty {
            soundPlayer.speakPika(character: companionCharacter, enabled: soundEnabled, force: force)
        } else {
            soundPlayer.speakPikaLine(line, character: companionCharacter, enabled: soundEnabled, force: force)
        }
    }

    private func speakPikaLine(_ text: String, force: Bool = false) {
        if soundEnabled {
            markVoiceSpeaking()
        }
        soundPlayer.speakPikaLine(text, character: companionCharacter, enabled: soundEnabled, force: force)
    }

    private func pikaVoiceStatusLine(prefix: String) -> String {
        if !soundEnabled {
            return "\(prefix). Muted; text only."
        }
        let sidecarURL = ProcessInfo.processInfo.environment["POCKETDM_PIKA_TTS_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sidecarURL.isEmpty {
            return "\(prefix). Pika sidecar voice queued."
        }
        return "\(prefix). Bundled Pika chirp queued."
    }

    private func pikaText(_ text: String) -> String {
        let trimmed = companionCharacter.rewrite(text.trimmingCharacters(in: .whitespacesAndNewlines))
        let normalized = trimmed.lowercased().filter(\.isLetter)
        if normalized.contains(companionCharacter.normalizedCatchphrase) {
            return trimmed
        }
        guard !trimmed.isEmpty else { return companionCharacter.catchphrase }
        return "\(companionCharacter.catchphrase) \(trimmed)"
    }

    private func lessonMessage(_ text: String) -> String {
        companionCharacter.rewrite(text.trimmingCharacters(in: .whitespacesAndNewlines))
            .replacingOccurrences(
                of: #"(?i)\bpika+a?\s*[-,]?\s*pika+a?[!,.:\s-]*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendPetNote(_ note: String) {
        if message.isEmpty || message.localizedCaseInsensitiveContains("thinking") {
            message = pikaText(note)
        } else if message.localizedCaseInsensitiveContains(note) {
            return
        } else {
            message += " \(note)"
        }
    }

    private func clearCheerBubble() {
        cheerBubble = nil
        cheerTitle = ""
        cheerAction = ""
        cheerRewardLine = ""
        cheerDaypartRaw = 0
        cheerPingRaw = 0
        cheerMoodWeatherRaw = 0
        cheerJourneyRaw = 0
        cheerVisitRaw = 0
        cheerSparkWheelRaw = 0
        cheerRouteRaw = 0
        cheerCareVitalRaw = 0
        cheerExchangeRaw = 0
        cheerMoodCareStepRaw = 0
        cheerBondContractRaw = 0
        cheerBondTimelineRaw = 0
        cheerDialogueRaw = 0
        cheerIntentRaw = 0
        cheerScriptRaw = 0
        cheerMoodStoryRaw = 0
        cheerFeelingRitualRaw = 0
        cheerCareChestRaw = 0
        cheerFieldNoteRaw = 0
        cheerScoutTripRaw = 0
        cheerAffectionRaw = 0
        cheerHomeRoomRaw = 0
        cheerErrandRaw = 0
        cheerUserCheckRaw = 0
        cheerWishRaw = 0
        cheerToyRaw = 0
        cheerTrickRaw = 0
        cheerWellnessBreakActive = false
        cheerWellnessActionRaw = 0
    }

    private func persistCare() {
        UserDefaults.standard.set(companionHP, forKey: Self.companionHPKey)
        UserDefaults.standard.set(companionHealth, forKey: Self.companionHealthKey)
        UserDefaults.standard.set(happiness, forKey: Self.happinessKey)
        UserDefaults.standard.set(petStreak, forKey: Self.petStreakKey)
        UserDefaults.standard.set(lastPetDay, forKey: Self.lastPetDayKey)
        UserDefaults.standard.set(sparkDust, forKey: Self.sparkDustKey)
        UserDefaults.standard.set(energy, forKey: Self.energyKey)
        UserDefaults.standard.set(lastEnergyAt, forKey: Self.lastEnergyAtKey)
        UserDefaults.standard.set(dailyComboDate, forKey: Self.dailyComboDateKey)
        UserDefaults.standard.set(dailyComboMask, forKey: Self.dailyComboMaskKey)
        UserDefaults.standard.set(passiveSparkAt, forKey: Self.passiveSparkAtKey)
        UserDefaults.standard.set(snackLevel, forKey: Self.snackLevelKey)
        UserDefaults.standard.set(lessonLevel, forKey: Self.lessonLevelKey)
        UserDefaults.standard.set(questLevel, forKey: Self.questLevelKey)
        UserDefaults.standard.set(nestLevel, forKey: Self.nestLevelKey)
        UserDefaults.standard.set(cheerLevel, forKey: Self.cheerLevelKey)
        UserDefaults.standard.set(sparkLevel, forKey: Self.sparkLevelKey)
        UserDefaults.standard.set(focusLevel, forKey: Self.focusLevelKey)
        UserDefaults.standard.set(cipherLevel, forKey: Self.cipherLevelKey)
        UserDefaults.standard.set(dailyQuestDate, forKey: Self.dailyQuestDateKey)
        UserDefaults.standard.set(dailyQuestMask, forKey: Self.dailyQuestMaskKey)
        UserDefaults.standard.set(dailyBondBoardDate, forKey: Self.dailyBondBoardDateKey)
        UserDefaults.standard.set(dailyBondBoardMask, forKey: Self.dailyBondBoardMaskKey)
        UserDefaults.standard.set(bondContractAlbumMask, forKey: Self.bondContractAlbumMaskKey)
        UserDefaults.standard.set(dailyBoosterDate, forKey: Self.dailyBoosterDateKey)
        UserDefaults.standard.set(dailyBoosterUsed, forKey: Self.dailyBoosterUsedKey)
        UserDefaults.standard.set(dailyCipherDate, forKey: Self.dailyCipherDateKey)
        UserDefaults.standard.set(dailyCipherSolved, forKey: Self.dailyCipherSolvedKey)
        UserDefaults.standard.set(lastLifecycleAt, forKey: Self.lastLifecycleAtKey)
        UserDefaults.standard.set(lastComebackChestDay, forKey: Self.lastComebackChestDayKey)
        UserDefaults.standard.set(careMemoryMask, forKey: Self.careMemoryMaskKey)
        UserDefaults.standard.set(lifeSceneMask, forKey: Self.lifeSceneMaskKey)
        UserDefaults.standard.set(dailyBondTimelineDate, forKey: Self.dailyBondTimelineDateKey)
        UserDefaults.standard.set(dailyBondTimelineOfferedMask, forKey: Self.dailyBondTimelineOfferedMaskKey)
        UserDefaults.standard.set(dailyBondTimelineSavedMask, forKey: Self.dailyBondTimelineSavedMaskKey)
        UserDefaults.standard.set(dailyBondTimelineDismissedMask, forKey: Self.dailyBondTimelineDismissedMaskKey)
        UserDefaults.standard.set(bondTimelineAlbumMask, forKey: Self.bondTimelineAlbumMaskKey)
        UserDefaults.standard.set(latestBondTimelineRaw, forKey: Self.latestBondTimelineRawKey)
        UserDefaults.standard.set(careCharmMask, forKey: Self.careCharmMaskKey)
        UserDefaults.standard.set(evolutionQuestMask, forKey: Self.evolutionQuestMaskKey)
        UserDefaults.standard.set(growthJourneyMask, forKey: Self.growthJourneyMaskKey)
        UserDefaults.standard.set(latestGrowthStageRaw, forKey: Self.latestGrowthStageRawKey)
        UserDefaults.standard.set(lastNeedBonusDay, forKey: Self.lastNeedBonusDayKey)
        UserDefaults.standard.set(dailyEventDate, forKey: Self.dailyEventDateKey)
        UserDefaults.standard.set(dailyEventProgress, forKey: Self.dailyEventProgressKey)
        UserDefaults.standard.set(seasonBadgeMask, forKey: Self.seasonBadgeMaskKey)
        UserDefaults.standard.set(seasonTrailWeek, forKey: Self.seasonTrailWeekKey)
        UserDefaults.standard.set(seasonTrailMask, forKey: Self.seasonTrailMaskKey)
        UserDefaults.standard.set(seasonTrailAlbumMask, forKey: Self.seasonTrailAlbumMaskKey)
        UserDefaults.standard.set(latestSeasonTrailRaw, forKey: Self.latestSeasonTrailRawKey)
        UserDefaults.standard.set(dailyFeelingDate, forKey: Self.dailyFeelingDateKey)
        UserDefaults.standard.set(dailyFeelingMask, forKey: Self.dailyFeelingMaskKey)
        UserDefaults.standard.set(emotionAlbumMask, forKey: Self.emotionAlbumMaskKey)
        UserDefaults.standard.set(latestFeelingRaw, forKey: Self.latestFeelingRawKey)
        UserDefaults.standard.set(dailyEmotionWheelDate, forKey: Self.dailyEmotionWheelDateKey)
        UserDefaults.standard.set(dailyEmotionWheelRaw, forKey: Self.dailyEmotionWheelRawKey)
        UserDefaults.standard.set(dailyEmotionEpisodeDate, forKey: Self.dailyEmotionEpisodeDateKey)
        UserDefaults.standard.set(dailyEmotionEpisodeMask, forKey: Self.dailyEmotionEpisodeMaskKey)
        UserDefaults.standard.set(emotionEpisodeAlbumMask, forKey: Self.emotionEpisodeAlbumMaskKey)
        UserDefaults.standard.set(latestEmotionEpisodeRaw, forKey: Self.latestEmotionEpisodeRawKey)
        UserDefaults.standard.set(dailyEmotionArcDate, forKey: Self.dailyEmotionArcDateKey)
        UserDefaults.standard.set(dailyEmotionArcMask, forKey: Self.dailyEmotionArcMaskKey)
        UserDefaults.standard.set(emotionArcAlbumMask, forKey: Self.emotionArcAlbumMaskKey)
        UserDefaults.standard.set(latestEmotionArcRaw, forKey: Self.latestEmotionArcRawKey)
        UserDefaults.standard.set(dailyMoodCareDate, forKey: Self.dailyMoodCareDateKey)
        UserDefaults.standard.set(dailyMoodCareFeelingRaw, forKey: Self.dailyMoodCareFeelingRawKey)
        UserDefaults.standard.set(dailyMoodCareMask, forKey: Self.dailyMoodCareMaskKey)
        UserDefaults.standard.set(moodCareAlbumMask, forKey: Self.moodCareAlbumMaskKey)
        UserDefaults.standard.set(weeklyCareWeek, forKey: Self.weeklyCareWeekKey)
        UserDefaults.standard.set(weeklyCareCount, forKey: Self.weeklyCareCountKey)
        UserDefaults.standard.set(weeklyRewardMask, forKey: Self.weeklyRewardMaskKey)
        UserDefaults.standard.set(weeklyTrailAlbumMask, forKey: Self.weeklyTrailAlbumMaskKey)
        UserDefaults.standard.set(streakShieldCount, forKey: Self.streakShieldCountKey)
        UserDefaults.standard.set(recoveryAlbumMask, forKey: Self.recoveryAlbumMaskKey)
        UserDefaults.standard.set(latestRecoverySceneRaw, forKey: Self.latestRecoverySceneRawKey)
        UserDefaults.standard.set(dailyNudgeDate, forKey: Self.dailyNudgeDateKey)
        UserDefaults.standard.set(dailyNudgeOfferedMask, forKey: Self.dailyNudgeOfferedMaskKey)
        UserDefaults.standard.set(dailyNudgeAnsweredMask, forKey: Self.dailyNudgeAnsweredMaskKey)
        UserDefaults.standard.set(dailyNudgeDismissedMask, forKey: Self.dailyNudgeDismissedMaskKey)
        UserDefaults.standard.set(dailyCheerPingDate, forKey: Self.dailyCheerPingDateKey)
        UserDefaults.standard.set(dailyCheerPingOfferedMask, forKey: Self.dailyCheerPingOfferedMaskKey)
        UserDefaults.standard.set(dailyCheerPingAnsweredMask, forKey: Self.dailyCheerPingAnsweredMaskKey)
        UserDefaults.standard.set(dailyCheerPingDismissedMask, forKey: Self.dailyCheerPingDismissedMaskKey)
        UserDefaults.standard.set(cheerPingAlbumMask, forKey: Self.cheerPingAlbumMaskKey)
        UserDefaults.standard.set(latestCheerPingRaw, forKey: Self.latestCheerPingRawKey)
        UserDefaults.standard.set(dailyMoodWeatherDate, forKey: Self.dailyMoodWeatherDateKey)
        UserDefaults.standard.set(dailyMoodWeatherOfferedMask, forKey: Self.dailyMoodWeatherOfferedMaskKey)
        UserDefaults.standard.set(dailyMoodWeatherAnsweredMask, forKey: Self.dailyMoodWeatherAnsweredMaskKey)
        UserDefaults.standard.set(dailyMoodWeatherDismissedMask, forKey: Self.dailyMoodWeatherDismissedMaskKey)
        UserDefaults.standard.set(moodWeatherAlbumMask, forKey: Self.moodWeatherAlbumMaskKey)
        UserDefaults.standard.set(latestMoodWeatherRaw, forKey: Self.latestMoodWeatherRawKey)
        UserDefaults.standard.set(dailyJourneyDate, forKey: Self.dailyJourneyDateKey)
        UserDefaults.standard.set(dailyJourneyOfferedMask, forKey: Self.dailyJourneyOfferedMaskKey)
        UserDefaults.standard.set(dailyJourneyAnsweredMask, forKey: Self.dailyJourneyAnsweredMaskKey)
        UserDefaults.standard.set(dailyJourneyDismissedMask, forKey: Self.dailyJourneyDismissedMaskKey)
        UserDefaults.standard.set(journeyAlbumMask, forKey: Self.journeyAlbumMaskKey)
        UserDefaults.standard.set(latestJourneyRaw, forKey: Self.latestJourneyRawKey)
        UserDefaults.standard.set(dailyVisitDate, forKey: Self.dailyVisitDateKey)
        UserDefaults.standard.set(dailyVisitOfferedMask, forKey: Self.dailyVisitOfferedMaskKey)
        UserDefaults.standard.set(dailyVisitAnsweredMask, forKey: Self.dailyVisitAnsweredMaskKey)
        UserDefaults.standard.set(dailyVisitDismissedMask, forKey: Self.dailyVisitDismissedMaskKey)
        UserDefaults.standard.set(visitAlbumMask, forKey: Self.visitAlbumMaskKey)
        UserDefaults.standard.set(latestVisitRaw, forKey: Self.latestVisitRawKey)
        UserDefaults.standard.set(dailySparkWheelDate, forKey: Self.dailySparkWheelDateKey)
        UserDefaults.standard.set(dailySparkWheelOfferedMask, forKey: Self.dailySparkWheelOfferedMaskKey)
        UserDefaults.standard.set(dailySparkWheelStartedMask, forKey: Self.dailySparkWheelStartedMaskKey)
        UserDefaults.standard.set(dailySparkWheelClaimedMask, forKey: Self.dailySparkWheelClaimedMaskKey)
        UserDefaults.standard.set(dailySparkWheelDismissedMask, forKey: Self.dailySparkWheelDismissedMaskKey)
        UserDefaults.standard.set(sparkWheelAlbumMask, forKey: Self.sparkWheelAlbumMaskKey)
        UserDefaults.standard.set(latestSparkWheelRaw, forKey: Self.latestSparkWheelRawKey)
        UserDefaults.standard.set(activeSparkWheelRaw, forKey: Self.activeSparkWheelRawKey)
        UserDefaults.standard.set(activeSparkWheelStartedAt, forKey: Self.activeSparkWheelStartedAtKey)
        UserDefaults.standard.set(dailyExchangeDate, forKey: Self.dailyExchangeDateKey)
        UserDefaults.standard.set(dailyExchangeOfferedMask, forKey: Self.dailyExchangeOfferedMaskKey)
        UserDefaults.standard.set(dailyExchangeAnsweredMask, forKey: Self.dailyExchangeAnsweredMaskKey)
        UserDefaults.standard.set(dailyExchangeDismissedMask, forKey: Self.dailyExchangeDismissedMaskKey)
        UserDefaults.standard.set(exchangeAlbumMask, forKey: Self.exchangeAlbumMaskKey)
        UserDefaults.standard.set(latestExchangeRaw, forKey: Self.latestExchangeRawKey)
        UserDefaults.standard.set(dailyCheerDialogueDate, forKey: Self.dailyCheerDialogueDateKey)
        UserDefaults.standard.set(dailyCheerDialogueOfferedMask, forKey: Self.dailyCheerDialogueOfferedMaskKey)
        UserDefaults.standard.set(dailyCheerDialogueAnsweredMask, forKey: Self.dailyCheerDialogueAnsweredMaskKey)
        UserDefaults.standard.set(dailyCheerDialogueDismissedMask, forKey: Self.dailyCheerDialogueDismissedMaskKey)
        UserDefaults.standard.set(cheerDialogueAlbumMask, forKey: Self.cheerDialogueAlbumMaskKey)
        UserDefaults.standard.set(dailyCheerIntentDate, forKey: Self.dailyCheerIntentDateKey)
        UserDefaults.standard.set(dailyCheerIntentOfferedMask, forKey: Self.dailyCheerIntentOfferedMaskKey)
        UserDefaults.standard.set(dailyCheerIntentAnsweredMask, forKey: Self.dailyCheerIntentAnsweredMaskKey)
        UserDefaults.standard.set(dailyCheerIntentDismissedMask, forKey: Self.dailyCheerIntentDismissedMaskKey)
        UserDefaults.standard.set(cheerIntentAlbumMask, forKey: Self.cheerIntentAlbumMaskKey)
        UserDefaults.standard.set(dailyCheerMemoryDate, forKey: Self.dailyCheerMemoryDateKey)
        UserDefaults.standard.set(dailyCheerMemoryMask, forKey: Self.dailyCheerMemoryMaskKey)
        UserDefaults.standard.set(cheerMemoryAlbumMask, forKey: Self.cheerMemoryAlbumMaskKey)
        UserDefaults.standard.set(latestCheerMemoryRaw, forKey: Self.latestCheerMemoryRawKey)
        UserDefaults.standard.set(dailyCheerScriptDate, forKey: Self.dailyCheerScriptDateKey)
        UserDefaults.standard.set(dailyCheerScriptOfferedMask, forKey: Self.dailyCheerScriptOfferedMaskKey)
        UserDefaults.standard.set(dailyCheerScriptAnsweredMask, forKey: Self.dailyCheerScriptAnsweredMaskKey)
        UserDefaults.standard.set(dailyCheerScriptDismissedMask, forKey: Self.dailyCheerScriptDismissedMaskKey)
        UserDefaults.standard.set(cheerScriptAlbumMask, forKey: Self.cheerScriptAlbumMaskKey)
        UserDefaults.standard.set(dailyMoodStoryDate, forKey: Self.dailyMoodStoryDateKey)
        UserDefaults.standard.set(dailyMoodStoryOfferedMask, forKey: Self.dailyMoodStoryOfferedMaskKey)
        UserDefaults.standard.set(dailyMoodStoryAnsweredMask, forKey: Self.dailyMoodStoryAnsweredMaskKey)
        UserDefaults.standard.set(dailyMoodStoryDismissedMask, forKey: Self.dailyMoodStoryDismissedMaskKey)
        UserDefaults.standard.set(moodStoryAlbumMask, forKey: Self.moodStoryAlbumMaskKey)
        UserDefaults.standard.set(latestMoodStoryRaw, forKey: Self.latestMoodStoryRawKey)
        UserDefaults.standard.set(dailyFeelingRitualDate, forKey: Self.dailyFeelingRitualDateKey)
        UserDefaults.standard.set(dailyFeelingRitualOfferedMask, forKey: Self.dailyFeelingRitualOfferedMaskKey)
        UserDefaults.standard.set(dailyFeelingRitualAnsweredMask, forKey: Self.dailyFeelingRitualAnsweredMaskKey)
        UserDefaults.standard.set(dailyFeelingRitualDismissedMask, forKey: Self.dailyFeelingRitualDismissedMaskKey)
        UserDefaults.standard.set(feelingRitualAlbumMask, forKey: Self.feelingRitualAlbumMaskKey)
        UserDefaults.standard.set(latestFeelingRitualRaw, forKey: Self.latestFeelingRitualRawKey)
        UserDefaults.standard.set(dailyCareChestDate, forKey: Self.dailyCareChestDateKey)
        UserDefaults.standard.set(dailyCareChestOfferedMask, forKey: Self.dailyCareChestOfferedMaskKey)
        UserDefaults.standard.set(dailyCareChestClaimedMask, forKey: Self.dailyCareChestClaimedMaskKey)
        UserDefaults.standard.set(dailyCareChestDismissedMask, forKey: Self.dailyCareChestDismissedMaskKey)
        UserDefaults.standard.set(careChestAlbumMask, forKey: Self.careChestAlbumMaskKey)
        UserDefaults.standard.set(latestCareChestRaw, forKey: Self.latestCareChestRawKey)
        UserDefaults.standard.set(dailyFieldNoteDate, forKey: Self.dailyFieldNoteDateKey)
        UserDefaults.standard.set(dailyFieldNoteOfferedMask, forKey: Self.dailyFieldNoteOfferedMaskKey)
        UserDefaults.standard.set(dailyFieldNoteSavedMask, forKey: Self.dailyFieldNoteSavedMaskKey)
        UserDefaults.standard.set(dailyFieldNoteDismissedMask, forKey: Self.dailyFieldNoteDismissedMaskKey)
        UserDefaults.standard.set(fieldNoteAlbumMask, forKey: Self.fieldNoteAlbumMaskKey)
        UserDefaults.standard.set(latestFieldNoteRaw, forKey: Self.latestFieldNoteRawKey)
        UserDefaults.standard.set(dailyScoutTripDate, forKey: Self.dailyScoutTripDateKey)
        UserDefaults.standard.set(dailyScoutTripStartedMask, forKey: Self.dailyScoutTripStartedMaskKey)
        UserDefaults.standard.set(dailyScoutTripReturnedMask, forKey: Self.dailyScoutTripReturnedMaskKey)
        UserDefaults.standard.set(scoutTripAlbumMask, forKey: Self.scoutTripAlbumMaskKey)
        UserDefaults.standard.set(latestScoutTripRaw, forKey: Self.latestScoutTripRawKey)
        UserDefaults.standard.set(activeScoutTripRaw, forKey: Self.activeScoutTripRawKey)
        UserDefaults.standard.set(activeScoutTripStartedAt, forKey: Self.activeScoutTripStartedAtKey)
        UserDefaults.standard.set(dailyAffectionDate, forKey: Self.dailyAffectionDateKey)
        UserDefaults.standard.set(dailyAffectionOfferedMask, forKey: Self.dailyAffectionOfferedMaskKey)
        UserDefaults.standard.set(dailyAffectionGivenMask, forKey: Self.dailyAffectionGivenMaskKey)
        UserDefaults.standard.set(dailyAffectionDismissedMask, forKey: Self.dailyAffectionDismissedMaskKey)
        UserDefaults.standard.set(affectionAlbumMask, forKey: Self.affectionAlbumMaskKey)
        UserDefaults.standard.set(latestAffectionRaw, forKey: Self.latestAffectionRawKey)
        UserDefaults.standard.set(dailyHomeDate, forKey: Self.dailyHomeDateKey)
        UserDefaults.standard.set(dailyHomeOfferedMask, forKey: Self.dailyHomeOfferedMaskKey)
        UserDefaults.standard.set(dailyHomeVisitedMask, forKey: Self.dailyHomeVisitedMaskKey)
        UserDefaults.standard.set(dailyHomeDismissedMask, forKey: Self.dailyHomeDismissedMaskKey)
        UserDefaults.standard.set(homeAlbumMask, forKey: Self.homeAlbumMaskKey)
        UserDefaults.standard.set(latestHomeRoomRaw, forKey: Self.latestHomeRoomRawKey)
        UserDefaults.standard.set(dailyErrandDate, forKey: Self.dailyErrandDateKey)
        UserDefaults.standard.set(dailyErrandOfferedMask, forKey: Self.dailyErrandOfferedMaskKey)
        UserDefaults.standard.set(dailyErrandDoneMask, forKey: Self.dailyErrandDoneMaskKey)
        UserDefaults.standard.set(dailyErrandDismissedMask, forKey: Self.dailyErrandDismissedMaskKey)
        UserDefaults.standard.set(errandAlbumMask, forKey: Self.errandAlbumMaskKey)
        UserDefaults.standard.set(latestErrandRaw, forKey: Self.latestErrandRawKey)
        UserDefaults.standard.set(dailyUserCheckDate, forKey: Self.dailyUserCheckDateKey)
        UserDefaults.standard.set(dailyUserCheckOfferedMask, forKey: Self.dailyUserCheckOfferedMaskKey)
        UserDefaults.standard.set(dailyUserCheckAnsweredMask, forKey: Self.dailyUserCheckAnsweredMaskKey)
        UserDefaults.standard.set(dailyUserCheckDismissedMask, forKey: Self.dailyUserCheckDismissedMaskKey)
        UserDefaults.standard.set(userCheckAlbumMask, forKey: Self.userCheckAlbumMaskKey)
        UserDefaults.standard.set(latestUserCheckRaw, forKey: Self.latestUserCheckRawKey)
        UserDefaults.standard.set(dailyWishDate, forKey: Self.dailyWishDateKey)
        UserDefaults.standard.set(dailyWishOfferedMask, forKey: Self.dailyWishOfferedMaskKey)
        UserDefaults.standard.set(dailyWishFulfilledMask, forKey: Self.dailyWishFulfilledMaskKey)
        UserDefaults.standard.set(dailyWishDismissedMask, forKey: Self.dailyWishDismissedMaskKey)
        UserDefaults.standard.set(wishAlbumMask, forKey: Self.wishAlbumMaskKey)
        UserDefaults.standard.set(latestWishRaw, forKey: Self.latestWishRawKey)
        UserDefaults.standard.set(dailyToyDate, forKey: Self.dailyToyDateKey)
        UserDefaults.standard.set(dailyToyOfferedMask, forKey: Self.dailyToyOfferedMaskKey)
        UserDefaults.standard.set(dailyToyPlayedMask, forKey: Self.dailyToyPlayedMaskKey)
        UserDefaults.standard.set(dailyToyDismissedMask, forKey: Self.dailyToyDismissedMaskKey)
        UserDefaults.standard.set(toyAlbumMask, forKey: Self.toyAlbumMaskKey)
        UserDefaults.standard.set(latestToyRaw, forKey: Self.latestToyRawKey)
        UserDefaults.standard.set(dailyTrickDate, forKey: Self.dailyTrickDateKey)
        UserDefaults.standard.set(dailyTrickOfferedMask, forKey: Self.dailyTrickOfferedMaskKey)
        UserDefaults.standard.set(dailyTrickPracticedMask, forKey: Self.dailyTrickPracticedMaskKey)
        UserDefaults.standard.set(dailyTrickDismissedMask, forKey: Self.dailyTrickDismissedMaskKey)
        UserDefaults.standard.set(trickAlbumMask, forKey: Self.trickAlbumMaskKey)
        UserDefaults.standard.set(latestTrickRaw, forKey: Self.latestTrickRawKey)
        UserDefaults.standard.set(dailyAmbientDate, forKey: Self.dailyAmbientDateKey)
        UserDefaults.standard.set(dailyAmbientMask, forKey: Self.dailyAmbientMaskKey)
        UserDefaults.standard.set(ambientAlbumMask, forKey: Self.ambientAlbumMaskKey)
        UserDefaults.standard.set(latestAmbientMomentRaw, forKey: Self.latestAmbientMomentRawKey)
        UserDefaults.standard.set(lastAmbientAt, forKey: Self.lastAmbientAtKey)
        UserDefaults.standard.set(lastWellnessBreakAt, forKey: Self.lastWellnessBreakAtKey)
        UserDefaults.standard.set(dailyRouteDate, forKey: Self.dailyRouteDateKey)
        UserDefaults.standard.set(dailyRouteMask, forKey: Self.dailyRouteMaskKey)
        UserDefaults.standard.set(dailyRouteOfferedMask, forKey: Self.dailyRouteOfferedMaskKey)
        UserDefaults.standard.set(dailyRouteDismissedMask, forKey: Self.dailyRouteDismissedMaskKey)
        UserDefaults.standard.set(routeAlbumMask, forKey: Self.routeAlbumMaskKey)
        UserDefaults.standard.set(latestRouteStepRaw, forKey: Self.latestRouteStepRawKey)
        UserDefaults.standard.set(dailyCarePulseDate, forKey: Self.dailyCarePulseDateKey)
        UserDefaults.standard.set(dailyCarePulseOfferedMask, forKey: Self.dailyCarePulseOfferedMaskKey)
        UserDefaults.standard.set(dailyCarePulseAnsweredMask, forKey: Self.dailyCarePulseAnsweredMaskKey)
        UserDefaults.standard.set(dailyCarePulseDismissedMask, forKey: Self.dailyCarePulseDismissedMaskKey)
        UserDefaults.standard.set(carePulseAlbumMask, forKey: Self.carePulseAlbumMaskKey)
        UserDefaults.standard.set(latestCarePulseRaw, forKey: Self.latestCarePulseRawKey)
        UserDefaults.standard.set(dailyCareWindowDate, forKey: Self.dailyCareWindowDateKey)
        UserDefaults.standard.set(dailyCareWindowMask, forKey: Self.dailyCareWindowMaskKey)
        UserDefaults.standard.set(careWindowAlbumMask, forKey: Self.careWindowAlbumMaskKey)
        UserDefaults.standard.set(latestCareWindowRaw, forKey: Self.latestCareWindowRawKey)
        UserDefaults.standard.set(dailyAffirmationDate, forKey: Self.dailyAffirmationDateKey)
        UserDefaults.standard.set(dailyAffirmationMask, forKey: Self.dailyAffirmationMaskKey)
        UserDefaults.standard.set(dailyWellnessDate, forKey: Self.dailyWellnessDateKey)
        UserDefaults.standard.set(dailyWellnessMask, forKey: Self.dailyWellnessMaskKey)
        UserDefaults.standard.set(morningWeatherDate, forKey: Self.morningWeatherDateKey)
        UserDefaults.standard.set(morningWeatherLine, forKey: Self.morningWeatherLineKey)
        UserDefaults.standard.set(snackVital, forKey: Self.snackVitalKey)
        UserDefaults.standard.set(restVital, forKey: Self.restVitalKey)
        UserDefaults.standard.set(playVital, forKey: Self.playVitalKey)
        UserDefaults.standard.set(focusVital, forKey: Self.focusVitalKey)
        UserDefaults.standard.set(lastVitalAt, forKey: Self.lastVitalAtKey)
    }

    private func handlesCare(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        return lowered.contains("pet")
            || lowered.contains("happy")
            || lowered.contains("care")
            || lowered.contains("check in")
            || lowered.contains("check-in")
    }

    private func wellnessAction(from prompt: String) -> DailyWellnessAction? {
        let normalized = Self.normalizedIntentText(prompt)
        if Self.intent(normalized, containsAnyOf: [
            "i drank water",
            "i had water",
            "i drink water",
            "drink water",
            "drank water",
            "had water",
            "water done",
            "hydrated",
            "hydrate done"
        ]) {
            return .water
        }
        if Self.intent(normalized, containsAnyOf: [
            "i stood up",
            "i stand up",
            "stood up",
            "stand up",
            "standing up",
            "i stood",
            "stand done"
        ]) {
            return .stand
        }
        if Self.intent(normalized, containsAnyOf: [
            "i walked",
            "i took a walk",
            "short walk",
            "took a short walk",
            "went for a walk",
            "walked",
            "walk done"
        ]) {
            return .walk
        }
        if Self.intent(normalized, containsAnyOf: [
            "affirm me",
            "daily affirmation",
            "morning affirmation",
            "afternoon affirmation",
            "evening affirmation",
            "night affirmation",
            "i did one affirmation",
            "affirmation done",
            "do affirmation"
        ]) {
            return .affirm
        }
        return nil
    }

    private static func normalizedIntentText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func intent(_ normalized: String, containsAnyOf phrases: [String]) -> Bool {
        phrases.contains { normalized.contains($0) }
    }

    private func isHintPrompt(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        return lowered.contains("hint")
            || lowered.contains("help")
            || lowered.contains("status")
            || lowered.contains("what next")
    }

    var growthStage: PetGrowthStage {
        PetGrowthStage(companionHP: companionHP, sparkDust: sparkDust)
    }

    private var petFeeling: PetFeeling {
        PetFeeling(
            happiness: happiness,
            energy: energy,
            comboComplete: isDailyComboComplete,
            dailyTasksComplete: isDailyQuestSetComplete,
            cipherSolved: dailyCipherSolved,
            boosterReady: !dailyBoosterUsed,
            sparkDust: sparkDust,
            streak: petStreak,
            minimized: minimized,
            hour: currentHour
        )
    }

    private var moodCareFeeling: PetFeeling {
        PetFeeling(rawValue: dailyMoodCareFeelingRaw) ?? petFeeling
    }

    private var moodCareRecipe: PetMoodCareRecipe {
        moodCareFeeling.careRecipe
    }

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var careMoment: PetCareMoment {
        PetCareMoment(hour: currentHour)
    }

    private var dailyJourneyPhase: PetDailyNudgeJourneyPhase {
        PetDailyNudgeJourneyPhase.current(hour: currentHour)
    }

    private var currentVisitBeat: PetVisitBeat {
        PetVisitBeat.current(
            hour: currentHour,
            feeling: petFeeling,
            careNeed: careNeed,
            index: PetVisitBeat.count(mask: dailyVisitOfferedMask)
                + PetVisitBeat.count(mask: dailyVisitAnsweredMask)
        )
    }

    private var nextVisitBeat: PetVisitBeat? {
        PetVisitBeat.next(
            hour: currentHour,
            feeling: petFeeling,
            careNeed: careNeed,
            offeredMask: dailyVisitOfferedMask,
            answeredMask: dailyVisitAnsweredMask,
            index: PetVisitBeat.count(mask: dailyVisitOfferedMask)
                + PetVisitBeat.count(mask: dailyVisitAnsweredMask)
        )
    }

    private var activeSparkWheelCycle: PetSparkWheelCycle? {
        PetSparkWheelCycle(rawValue: activeSparkWheelRaw)
    }

    private var sparkWheelRemainingSeconds: Int? {
        guard activeSparkWheelRaw != 0, activeSparkWheelStartedAt > 0 else { return nil }
        let elapsed = Date().timeIntervalSince1970 - activeSparkWheelStartedAt
        return max(0, Int(ceil(Self.sparkWheelSeconds - elapsed)))
    }

    private var nextSparkWheelCycle: PetSparkWheelCycle? {
        guard activeSparkWheelRaw == 0 else { return activeSparkWheelCycle }
        return PetSparkWheelCycle.next(
            hour: currentHour,
            feeling: petFeeling,
            careNeed: careNeed,
            offeredMask: dailySparkWheelOfferedMask,
            claimedMask: dailySparkWheelClaimedMask,
            index: PetSparkWheelCycle.count(mask: dailySparkWheelOfferedMask)
                + PetSparkWheelCycle.count(mask: dailySparkWheelClaimedMask)
        )
    }

    private var daypartNudge: PetDaypartNudge {
        PetDaypartNudge(moment: careMoment)
    }

    private var nextCheerPing: PetCheerPing? {
        PetCheerPing.next(
            hour: currentHour,
            offeredMask: dailyCheerPingOfferedMask,
            answeredMask: dailyCheerPingAnsweredMask,
            index: PetCheerPing.count(mask: dailyCheerPingOfferedMask)
                + PetCheerPing.count(mask: dailyCheerPingAnsweredMask)
        )
    }

    private var currentMoodWeather: PetMoodWeather {
        PetMoodWeather.current(
            hour: currentHour,
            feeling: petFeeling,
            lowestVital: lowestVital
        )
    }

    private var nextMoodWeather: PetMoodWeather? {
        let weather = currentMoodWeather
        guard dailyMoodWeatherAnsweredMask & weather.rawValue == 0 else { return nil }
        return weather
    }

    private var dailyExchangeDoneMask: Int {
        PetExchangeBoardStep.allCases.reduce(0) { mask, step in
            isExchangeBoardStepComplete(step) ? mask | step.rawValue : mask
        }
    }

    private var nextExchangeBoardStep: PetExchangeBoardStep? {
        PetExchangeBoardStep.allCases.first {
            !isExchangeBoardStepComplete($0) && dailyExchangeOfferedMask & $0.rawValue == 0
        } ?? PetExchangeBoardStep.allCases.first {
            !isExchangeBoardStepComplete($0)
        }
    }

    private var careNeed: PetCareNeed {
        PetCareNeed.daily(
            for: dailyQuestDate.isEmpty ? Self.dayFormatter.string(from: Date()) : dailyQuestDate,
            hour: currentHour
        )
    }

    private var lowestVital: PetCareVital {
        PetCareVital.lowest(
            snack: snackVital,
            rest: restVital,
            play: playVital,
            focus: focusVital
        )
    }

    private var nextCarePulseVital: PetCareVital? {
        carePulseCandidates.first { vital in
            vitalLevel(for: vital) <= 2
                && dailyCarePulseAnsweredMask & vital.maskValue == 0
        }
    }

    private var nextUnofferedCarePulseVital: PetCareVital? {
        carePulseCandidates.first { vital in
            vitalLevel(for: vital) <= 2
                && dailyCarePulseAnsweredMask & vital.maskValue == 0
                && dailyCarePulseOfferedMask & vital.maskValue == 0
        }
    }

    private var carePulseCandidates: [PetCareVital] {
        PetCareVital.allCases.sorted { lhs, rhs in
            let lhsLevel = vitalLevel(for: lhs)
            let rhsLevel = vitalLevel(for: rhs)
            if lhsLevel == rhsLevel {
                return lhs.rawValue < rhs.rawValue
            }
            return lhsLevel < rhsLevel
        }
    }

    private var dailyEvent: PetSeasonEvent {
        PetSeasonEvent.daily(for: dailyEventDate.isEmpty ? Self.dayFormatter.string(from: Date()) : dailyEventDate)
    }

    func vitalLevel(for vital: PetCareVital) -> Int {
        switch vital {
        case .snack:
            return snackVital
        case .rest:
            return restVital
        case .play:
            return playVital
        case .focus:
            return focusVital
        }
    }

    func evolutionQuestProgress(for quest: PetEvolutionQuest) -> Double {
        quest.progress(
            companionHP: companionHP,
            sparkDust: sparkDust,
            memoryMask: careMemoryMask,
            charmMask: careCharmMask,
            badgeMask: seasonBadgeMask,
            weeklyRewardMask: weeklyRewardMask
        )
    }

    func isEvolutionQuestComplete(_ quest: PetEvolutionQuest) -> Bool {
        evolutionQuestProgress(for: quest) >= 1
    }

    func isEvolutionQuestClaimed(_ quest: PetEvolutionQuest) -> Bool {
        evolutionQuestMask & quest.rawValue != 0
    }

    func isGrowthJourneyUnlocked(_ stage: PetGrowthStage) -> Bool {
        growthJourneyMask & stage.rawValue != 0
    }

    func isBondTimelineSaved(_ chapter: PetBondTimelineChapter) -> Bool {
        bondTimelineAlbumMask & chapter.rawValue != 0
    }

    func isBondTimelineEligible(_ chapter: PetBondTimelineChapter) -> Bool {
        chapter.isEligible(
            companionHP: companionHP,
            sparkDust: sparkDust,
            streak: petStreak,
            stage: growthStage
        )
    }

    func isSeasonTrailChapterReady(_ chapter: PetSeasonTrailChapter) -> Bool {
        weeklyCareCount >= chapter.requiredDays
    }

    func isSeasonTrailChapterClaimed(_ chapter: PetSeasonTrailChapter) -> Bool {
        seasonTrailMask & chapter.rawValue != 0
    }

    func isSeasonTrailChapterInAlbum(_ chapter: PetSeasonTrailChapter) -> Bool {
        seasonTrailAlbumMask & chapter.rawValue != 0
    }

    func isMoodCareStepDone(_ step: PetMoodCareStep) -> Bool {
        dailyMoodCareMask & step.rawValue != 0
    }

    func isMoodCareFeelingComplete(_ feeling: PetFeeling) -> Bool {
        moodCareAlbumMask & feeling.rawValue != 0
    }

    func isEmotionEpisodeSeenToday(_ episode: PetEmotionEpisode) -> Bool {
        dailyEmotionEpisodeMask & episode.rawValue != 0
    }

    func isEmotionEpisodeUnlocked(_ episode: PetEmotionEpisode) -> Bool {
        emotionEpisodeAlbumMask & episode.rawValue != 0
    }

    func isEmotionArcSeenToday(_ arc: PetEmotionArc) -> Bool {
        dailyEmotionArcMask & arc.rawValue != 0
    }

    func isEmotionArcUnlocked(_ arc: PetEmotionArc) -> Bool {
        emotionArcAlbumMask & arc.rawValue != 0
    }

    func isBondContractDone(_ contract: PetBondContract) -> Bool {
        dailyBondBoardMask & contract.rawValue != 0
    }

    func isBondContractUnlocked(_ contract: PetBondContract) -> Bool {
        bondContractAlbumMask & contract.rawValue != 0
    }

    func isCheerDialogueAnswered(_ dialogue: PetCheerDialogue) -> Bool {
        dailyCheerDialogueAnsweredMask & dialogue.rawValue != 0
    }

    func isCheerDialogueUnlocked(_ dialogue: PetCheerDialogue) -> Bool {
        cheerDialogueAlbumMask & dialogue.rawValue != 0
    }

    func isCheerIntentAnswered(_ intent: PetCheerIntent) -> Bool {
        dailyCheerIntentAnsweredMask & intent.rawValue != 0
    }

    func isCheerIntentUnlocked(_ intent: PetCheerIntent) -> Bool {
        cheerIntentAlbumMask & intent.rawValue != 0
    }

    func isCheerPingAnswered(_ ping: PetCheerPing) -> Bool {
        dailyCheerPingAnsweredMask & ping.rawValue != 0
    }

    func isCheerPingUnlocked(_ ping: PetCheerPing) -> Bool {
        cheerPingAlbumMask & ping.rawValue != 0
            || dailyCheerPingOfferedMask & ping.rawValue != 0
            || nextCheerPing == ping
    }

    func isCheerMemorySeenToday(_ memory: PetCheerMemory) -> Bool {
        dailyCheerMemoryMask & memory.rawValue != 0
    }

    func isCheerMemoryUnlocked(_ memory: PetCheerMemory) -> Bool {
        cheerMemoryAlbumMask & memory.rawValue != 0
    }

    func isDailyJourneyAnswered(_ phase: PetDailyNudgeJourneyPhase) -> Bool {
        dailyJourneyAnsweredMask & phase.rawValue != 0
    }

    func isDailyJourneyUnlocked(_ phase: PetDailyNudgeJourneyPhase) -> Bool {
        journeyAlbumMask & phase.rawValue != 0
    }

    func isVisitBeatAnswered(_ beat: PetVisitBeat) -> Bool {
        dailyVisitAnsweredMask & beat.rawValue != 0
    }

    func isVisitBeatUnlocked(_ beat: PetVisitBeat) -> Bool {
        visitAlbumMask & beat.rawValue != 0
    }

    func isSparkWheelStarted(_ cycle: PetSparkWheelCycle) -> Bool {
        dailySparkWheelStartedMask & cycle.rawValue != 0
    }

    func isSparkWheelClaimed(_ cycle: PetSparkWheelCycle) -> Bool {
        dailySparkWheelClaimedMask & cycle.rawValue != 0
    }

    func isSparkWheelUnlocked(_ cycle: PetSparkWheelCycle) -> Bool {
        sparkWheelAlbumMask & cycle.rawValue != 0
    }

    func isExchangeBoardStepDone(_ step: PetExchangeBoardStep) -> Bool {
        isExchangeBoardStepComplete(step)
    }

    func isExchangeBoardStepUnlocked(_ step: PetExchangeBoardStep) -> Bool {
        isExchangeBoardStepComplete(step)
            || exchangeAlbumMask & step.rawValue != 0
            || dailyExchangeOfferedMask & step.rawValue != 0
            || nextExchangeBoardStep == step
    }

    private func isExchangeBoardStepComplete(_ step: PetExchangeBoardStep) -> Bool {
        switch step {
        case .careTap:
            return lastPetDay == Self.dayFormatter.string(from: Date())
                || dailyQuestMask & PetDailyQuest.care.rawValue != 0
        case .comboCards:
            return isDailyComboComplete
        case .taskBoard:
            return isDailyQuestSetComplete
        case .cipherKey:
            return dailyCipherSolved
        case .sparkBoost:
            return dailyBoosterUsed
        case .upgradeCard:
            return dailyQuestMask & PetDailyQuest.upgrade.rawValue != 0
                || dailyComboMask & PetComboAction.upgrade.rawValue != 0
        case .passiveScout:
            return dailyAmbientMask != 0
                || dailyScoutTripReturnedMask != 0
                || lastComebackChestDay == Self.dayFormatter.string(from: Date())
        case .cheerReply:
            return dailyCheerIntentAnsweredMask != 0
                || dailyJourneyAnsweredMask != 0
                || dailyNudgeAnsweredMask != 0
        }
    }

    func isCheerScriptAnswered(_ script: PetCheerScript) -> Bool {
        dailyCheerScriptAnsweredMask & script.rawValue != 0
    }

    func isCheerScriptUnlocked(_ script: PetCheerScript) -> Bool {
        cheerScriptAlbumMask & script.rawValue != 0
    }

    func isMoodStoryAnswered(_ story: PetMoodStory) -> Bool {
        dailyMoodStoryAnsweredMask & story.rawValue != 0
    }

    func isMoodStoryUnlocked(_ story: PetMoodStory) -> Bool {
        moodStoryAlbumMask & story.rawValue != 0
    }

    func isFeelingRitualAnswered(_ ritual: PetFeelingRitual) -> Bool {
        dailyFeelingRitualAnsweredMask & ritual.rawValue != 0
    }

    func isFeelingRitualUnlocked(_ ritual: PetFeelingRitual) -> Bool {
        feelingRitualAlbumMask & ritual.rawValue != 0
    }

    func isCareChestClaimed(_ chest: PetCareChest) -> Bool {
        dailyCareChestClaimedMask & chest.rawValue != 0
    }

    func isCareChestUnlocked(_ chest: PetCareChest) -> Bool {
        careChestAlbumMask & chest.rawValue != 0
    }

    func isFieldNoteSavedToday(_ note: PetFieldNote) -> Bool {
        dailyFieldNoteSavedMask & note.rawValue != 0
    }

    func isFieldNoteUnlocked(_ note: PetFieldNote) -> Bool {
        fieldNoteAlbumMask & note.rawValue != 0
    }

    func isScoutTripStarted(_ trip: PetScoutTrip) -> Bool {
        dailyScoutTripStartedMask & trip.rawValue != 0
    }

    func isScoutTripReturned(_ trip: PetScoutTrip) -> Bool {
        dailyScoutTripReturnedMask & trip.rawValue != 0
    }

    func isScoutTripUnlocked(_ trip: PetScoutTrip) -> Bool {
        scoutTripAlbumMask & trip.rawValue != 0
    }

    func isAffectionGiven(_ gesture: PetAffectionGesture) -> Bool {
        dailyAffectionGivenMask & gesture.rawValue != 0
    }

    func isAffectionUnlocked(_ gesture: PetAffectionGesture) -> Bool {
        affectionAlbumMask & gesture.rawValue != 0
    }

    func isHomeRoomVisited(_ room: PetHomeRoom) -> Bool {
        dailyHomeVisitedMask & room.rawValue != 0
    }

    func isHomeRoomUnlocked(_ room: PetHomeRoom) -> Bool {
        homeAlbumMask & room.rawValue != 0
    }

    func isErrandDone(_ errand: PetDailyErrand) -> Bool {
        dailyErrandDoneMask & errand.rawValue != 0
    }

    func isErrandUnlocked(_ errand: PetDailyErrand) -> Bool {
        errandAlbumMask & errand.rawValue != 0
    }

    func isUserCheckAnswered(_ checkIn: PetUserCheckIn) -> Bool {
        dailyUserCheckAnsweredMask & checkIn.rawValue != 0
    }

    func isUserCheckUnlocked(_ checkIn: PetUserCheckIn) -> Bool {
        userCheckAlbumMask & checkIn.rawValue != 0
    }

    func isWishFulfilled(_ wish: PetWish) -> Bool {
        dailyWishFulfilledMask & wish.rawValue != 0
    }

    func isWishUnlocked(_ wish: PetWish) -> Bool {
        wishAlbumMask & wish.rawValue != 0
    }

    func isToyPlayed(_ toy: PetToy) -> Bool {
        dailyToyPlayedMask & toy.rawValue != 0
    }

    func isToyUnlocked(_ toy: PetToy) -> Bool {
        toyAlbumMask & toy.rawValue != 0
    }

    func isTrickPracticed(_ trick: PetTrick) -> Bool {
        dailyTrickPracticedMask & trick.rawValue != 0
    }

    func isTrickUnlocked(_ trick: PetTrick) -> Bool {
        trick.isUnlocked(stage: growthStage) || trickAlbumMask & trick.rawValue != 0
    }

    func isLifeSceneUnlocked(_ scene: PetLifeScene) -> Bool {
        lifeSceneMask & scene.rawValue != 0
    }

    func isWeeklyTrailChapterUnlocked(_ chapter: PetWeeklyTrailChapter) -> Bool {
        weeklyCareCount >= chapter.requiredDays
    }

    func isWeeklyTrailChapterInAlbum(_ chapter: PetWeeklyTrailChapter) -> Bool {
        weeklyTrailAlbumMask & chapter.rawValue != 0
    }

    func isRecoverySceneUnlocked(_ scene: PetRecoveryScene) -> Bool {
        recoveryAlbumMask & scene.rawValue != 0
    }

    func isAmbientMomentSeenToday(_ moment: PetAmbientMoment) -> Bool {
        dailyAmbientMask & moment.rawValue != 0
    }

    func isAmbientMomentUnlocked(_ moment: PetAmbientMoment) -> Bool {
        ambientAlbumMask & moment.rawValue != 0
    }

    func isRouteStepDone(_ step: PetDailyRouteStep) -> Bool {
        dailyRouteMask & step.rawValue != 0
    }

    func isRouteStepUnlocked(_ step: PetDailyRouteStep) -> Bool {
        routeAlbumMask & step.rawValue != 0
            || dailyRouteOfferedMask & step.rawValue != 0
            || nextRouteStep == step
    }

    func isCarePulseAnswered(_ vital: PetCareVital) -> Bool {
        dailyCarePulseAnsweredMask & vital.maskValue != 0
    }

    func isCarePulseUnlocked(_ vital: PetCareVital) -> Bool {
        carePulseAlbumMask & vital.maskValue != 0
            || dailyCarePulseOfferedMask & vital.maskValue != 0
            || nextCarePulseVital == vital
    }

    func isCareWindowDone(_ moment: PetCareMoment) -> Bool {
        dailyCareWindowMask & moment.rawValue != 0
    }

    func isCareWindowUnlocked(_ moment: PetCareMoment) -> Bool {
        careWindowAlbumMask & moment.rawValue != 0
    }

    private func setVital(_ vital: PetCareVital, value: Int) {
        let clamped = min(Self.maxVital, max(0, value))
        switch vital {
        case .snack:
            snackVital = clamped
        case .rest:
            restVital = clamped
        case .play:
            playVital = clamped
        case .focus:
            focusVital = clamped
        }
    }

    private func refillVital(_ vital: PetCareVital, by amount: Int = 2) -> String? {
        let previous = vitalLevel(for: vital)
        let next = min(Self.maxVital, previous + max(0, amount))
        guard next > previous else { return nil }

        setVital(vital, value: next)
        persistCare()
        var notes = ["Vitals: \(vital.title) \(next)/\(Self.maxVital). \(vital.refillLine)"]
        if let charmNote = unlockVitalGlowIfReady() {
            notes.append(charmNote)
        }
        return notes.joined(separator: " ")
    }

    private func vitalForUpgrade(_ kind: PetUpgradeKind) -> PetCareVital {
        switch kind {
        case .snack:
            return .snack
        case .nest:
            return .rest
        case .quest, .cheer, .spark:
            return .play
        case .lesson, .focus, .cipher:
            return .focus
        }
    }

    private func applyVitalDecay() {
        let now = Date().timeIntervalSince1970
        if lastVitalAt == 0 {
            lastVitalAt = now
            persistCare()
            return
        }

        let elapsed = now - lastVitalAt
        guard elapsed >= Self.vitalDecaySeconds else { return }

        let ticks = min(3, Int(elapsed / Self.vitalDecaySeconds))
        guard ticks > 0 else { return }

        for vital in PetCareVital.allCases {
            setVital(vital, value: vitalLevel(for: vital) - ticks)
        }
        lastVitalAt += Double(ticks) * Self.vitalDecaySeconds
        if PetCareVital.allCases.contains(where: { vitalLevel(for: $0) <= 1 }) {
            happiness = max(1, happiness - 1)
        }
        persistCare()
    }

    private func awardCareNeed(_ completed: PetCareNeed) -> String? {
        let today = Self.dayFormatter.string(from: Date())
        guard careNeed.rawValue == completed.rawValue, lastNeedBonusDay != today else { return nil }

        lastNeedBonusDay = today
        let reward = 10 + sparkLevel * 2
        happiness = min(5, happiness + 1)
        sparkDust = min(999, sparkDust + reward)
        persistCare()
        return "\(careNeed.title) need met: Joy +1, Sparks +\(reward). \(careNeed.rewardLine)"
    }

    private func unlockMemory(_ memory: PetBondMemory) -> String? {
        guard careMemoryMask & memory.rawValue == 0 else { return nil }

        careMemoryMask |= memory.rawValue
        sparkDust = min(999, sparkDust + memory.sparkReward)
        persistCare()
        return "Memory unlocked: \(memory.title). \(memory.unlockLine) Sparks +\(memory.sparkReward)."
    }

    private func unlockCharm(_ charm: PetCareCharm) -> String? {
        guard careCharmMask & charm.rawValue == 0 else { return nil }

        careCharmMask |= charm.rawValue
        let reward = 8 + sparkLevel
        sparkDust = min(999, sparkDust + reward)
        persistCare()
        return "Charm found: \(charm.title). \(charm.unlockLine) Sparks +\(reward)."
    }

    private func markMoodCare(_ step: PetMoodCareStep) -> String? {
        syncDailyCombo()
        let recipe = moodCareRecipe
        guard recipe.steps.contains(step), dailyMoodCareMask & step.rawValue == 0 else { return nil }

        dailyMoodCareMask |= step.rawValue
        let done = recipe.steps.filter { dailyMoodCareMask & $0.rawValue != 0 }.count
        var notes = ["Mood care: \(step.title) \(done)/\(recipe.steps.count) for \(recipe.feeling.title)."]

        if recipe.isComplete(mask: dailyMoodCareMask),
           moodCareAlbumMask & recipe.feeling.rawValue == 0 {
            moodCareAlbumMask |= recipe.feeling.rawValue
            let reward = 12 + sparkLevel * 2
            sparkDust = min(999, sparkDust + reward)
            happiness = min(5, happiness + 1)
            notes.append("\(recipe.title) complete: Joy +1, Sparks +\(reward). \(recipe.feeling.discoveryLine)")
            play(.happy)
            setMood(.hyper, duration: 1.4)
        }

        persistCare()
        return notes.joined(separator: " ")
    }

    private func unlockVitalGlowIfReady() -> String? {
        let isGlowing = PetCareVital.allCases.allSatisfy { vitalLevel(for: $0) >= Self.maxVital }
        guard isGlowing else { return nil }
        return unlockCharm(.vitalGlow)
    }

    private func syncEvolutionQuests() -> String? {
        var notes: [String] = []
        for quest in PetEvolutionQuest.allCases where evolutionQuestMask & quest.rawValue == 0 {
            guard isEvolutionQuestComplete(quest) else { continue }

            evolutionQuestMask |= quest.rawValue
            sparkDust = min(999, sparkDust + quest.sparkReward)
            if quest.bondHPReward > 0 {
                companionHP = min(10, companionHP + quest.bondHPReward)
            }
            notes.append(
                "\(quest.title) complete: \(quest.loreLine) \(quest.targetStage.title) path lit. Sparks +\(quest.sparkReward)\(quest.bondHPReward > 0 ? ", Bond HP +\(quest.bondHPReward)" : "")."
            )
        }

        guard !notes.isEmpty else { return nil }
        persistCare()
        return notes.joined(separator: " ")
    }

    private func recordGrowthJourney(upTo stage: PetGrowthStage, reason: String) -> String? {
        let reachedStages = PetGrowthStage.reachedStages(upTo: stage)
        let newStages = reachedStages.filter { growthJourneyMask & $0.rawValue == 0 }
        latestGrowthStageRaw = stage.rawValue
        guard !newStages.isEmpty else {
            persistCare()
            return nil
        }

        for reached in newStages {
            growthJourneyMask |= reached.rawValue
        }

        let sparkBonus = min(5, sparkLevel)
        let sparkReward = newStages.reduce(0) { total, reached in
            total + reached.journeySparkReward + sparkBonus
        }
        sparkDust = min(999, sparkDust + sparkReward)
        happiness = min(5, happiness + 1)

        let latest = newStages.last ?? stage
        let stageNames = newStages.map(\.title).joined(separator: ", ")
        var notes = [
            "Growth journey saved after \(reason): \(stageNames). \(latest.arrivalLine) Joy +1, Sparks +\(sparkReward)."
        ]
        if let vitalNote = refillVital(latest.vital, by: 1) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(latest.moodStep) {
            notes.append(moodCareNote)
        }

        persistCare()
        return notes.joined(separator: " ")
    }

    private func appendEmotionScene(trigger: String) {
        if let emotionNote = recordEmotionScene(trigger: trigger) {
            message += " \(emotionNote)"
        }
    }

    private func recordEmotionScene(trigger: String) -> String? {
        syncDailyCombo()
        return recordEmotionScene(feeling: emotionFeeling(for: trigger), trigger: trigger)
    }

    private func recordEmotionScene(feeling: PetFeeling, trigger: String) -> String? {
        let bit = feeling.rawValue
        let seenToday = dailyFeelingMask & bit != 0
        let seenEver = emotionAlbumMask & bit != 0
        latestFeelingRaw = bit

        var notes: [String] = []
        if !seenToday {
            dailyFeelingMask |= bit
        }
        if !seenEver {
            emotionAlbumMask |= bit
            let reward = 10 + sparkLevel * 2
            sparkDust = min(999, sparkDust + reward)
            notes.append("Mood discovered after \(trigger): \(feeling.title). \(feeling.discoveryLine) Sparks +\(reward).")
        } else if !seenToday {
            let reward = 3
            sparkDust = min(999, sparkDust + reward)
            notes.append("Mood logged after \(trigger): \(feeling.title), Sparks +\(reward).")
        }

        if let episodeNote = recordEmotionEpisode(trigger: trigger, feeling: feeling) {
            notes.append(episodeNote)
        }
        let episode = PetEmotionEpisode.episode(for: trigger, feeling: feeling)
        if let arcNote = recordEmotionArc(trigger: trigger, feeling: feeling, episode: episode) {
            notes.append(arcNote)
        }

        persistCare()
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    private func recordEmotionEpisode(trigger: String, feeling: PetFeeling) -> String? {
        let episode = PetEmotionEpisode.episode(for: trigger, feeling: feeling)
        let bit = episode.rawValue
        let seenToday = dailyEmotionEpisodeMask & bit != 0
        let seenEver = emotionEpisodeAlbumMask & bit != 0
        latestEmotionEpisodeRaw = bit
        guard !seenToday || !seenEver else { return nil }

        if !seenToday {
            dailyEmotionEpisodeMask |= bit
        }
        if !seenEver {
            emotionEpisodeAlbumMask |= bit
            let reward = episode.sparkReward + min(4, sparkLevel)
            sparkDust = min(999, sparkDust + reward)
            var notes = ["Episode saved: \(episode.title). \(episode.storyLine) Sparks +\(reward)."]
            if let vitalNote = refillVital(episode.vital, by: 1) {
                notes.append(vitalNote)
            }
            if let moodCareNote = markMoodCare(episode.careStep) {
                notes.append(moodCareNote)
            }
            return notes.joined(separator: " ")
        }

        let reward = 2
        sparkDust = min(999, sparkDust + reward)
        return "Episode revisited: \(episode.title), Sparks +\(reward)."
    }

    private func recordEmotionArc(trigger: String, feeling: PetFeeling, episode: PetEmotionEpisode) -> String? {
        let arc = PetEmotionArc.arc(trigger: trigger, feeling: feeling, episode: episode)
        let bit = arc.rawValue
        let seenToday = dailyEmotionArcMask & bit != 0
        let seenEver = emotionArcAlbumMask & bit != 0
        latestEmotionArcRaw = bit
        guard !seenToday || !seenEver else { return nil }

        if !seenToday {
            dailyEmotionArcMask |= bit
        }
        if !seenEver {
            emotionArcAlbumMask |= bit
            let reward = arc.sparkReward + min(3, cheerLevel)
            sparkDust = min(999, sparkDust + reward)
            var notes = ["Emotion arc saved: \(arc.title). \(arc.resolutionLine) Sparks +\(reward)."]
            if let vitalNote = refillVital(arc.vital, by: 1) {
                notes.append(vitalNote)
            }
            if let moodCareNote = markMoodCare(arc.moodStep) {
                notes.append(moodCareNote)
            }
            return notes.joined(separator: " ")
        }

        let reward = 2
        sparkDust = min(999, sparkDust + reward)
        return "Emotion arc revisited: \(arc.title), Sparks +\(reward)."
    }

    private func emotionFeeling(for trigger: String) -> PetFeeling {
        switch trigger {
        case "happy", "chat return":
            return .bright
        case "daily care":
            return .grateful
        case "nap":
            return .sleepy
        case "hyper", "daily event":
            return .playful
        case "boost", "spent boost":
            return .overcharged
        case "lesson open", "language reward":
            return .focused
        case "lesson retry", "server wait":
            return .comfort
        case "hint", "chat", "cipher", "cipher review":
            return .curious
        case "quest open", "cheer", "affirmation":
            return .eager
        case "bond board":
            return .determined
        case "upgrade":
            return .proud
        case "upgrade wait":
            return .restless
        case "event review":
            return .celebrating
        case "journal":
            return .proud
        case "life scene":
            return .proud
        case "ambient":
            return .comfort
        case "daily route":
            return .determined
        case "emotion wheel":
            return dailyEmotionWheelFeeling ?? petFeeling
        default:
            return petFeeling
        }
    }

    private func mood(for feeling: PetFeeling) -> PetMood {
        switch feeling {
        case .bright, .eager, .proud, .celebrating, .grateful:
            return .happy
        case .overcharged, .playful, .determined, .restless:
            return .hyper
        case .focused, .curious, .protective:
            return .look
        case .comfort, .lonely:
            return .stretch
        case .hungry:
            return .snack
        case .sleepy:
            return .nap
        }
    }

    private func appendEvolutionNote(from priorStage: PetGrowthStage) {
        if let questNote = syncEvolutionQuests() {
            message += " \(questNote)"
        }
        let nextStage = growthStage
        guard priorStage.title != nextStage.title else { return }

        message += " Evolution glow: \(nextStage.title). \(nextStage.rewardLine)"
        if let journeyNote = recordGrowthJourney(upTo: nextStage, reason: "evolution") {
            message += " \(journeyNote)"
        }
        if let memoryNote = unlockMemory(.firstEvolution) {
            message += " \(memoryNote)"
        }
    }

    private func spendEnergy() -> Bool {
        rechargeEnergy()
        guard energy > 0 else { return false }
        energy -= 1
        persistCare()
        return true
    }

    private func earnSparkDust(_ amount: Int) {
        sparkDust = min(999, sparkDust + amount)
        persistCare()
    }

    private var passiveSparkRate: Int {
        max(1, 1 + snackLevel + lessonLevel + questLevel + nestLevel + cheerLevel + sparkLevel)
    }

    private func collectPassiveSparks() -> Int {
        let now = Date().timeIntervalSince1970
        let elapsed = now - passiveSparkAt
        guard elapsed >= Self.passiveSparkSeconds else { return 0 }
        let ticks = Int(elapsed / Self.passiveSparkSeconds)
        let earned = min(80, ticks * passiveSparkRate)
        guard earned > 0 else { return 0 }
        sparkDust = min(999, sparkDust + earned)
        passiveSparkAt += Double(ticks) * Self.passiveSparkSeconds
        if sparkDust >= 999 {
            passiveSparkAt = now
        }
        persistCare()
        return earned
    }

    private func applyLifecycleCatchup(reason: String) {
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastLifecycleAt
        guard elapsed >= 60 * 60 else { return }

        let hours = Int(elapsed / (60 * 60))
        var notes: [String] = []
        if let decayLine = PetLifecycleRules.decayLine(hoursIdle: hours) {
            happiness = max(1, happiness - 1)
            notes.append(decayLine)
        }

        let today = Self.dayFormatter.string(from: Date())
        if lastComebackChestDay != today,
           let reward = PetLifecycleRules.comebackReward(hoursAway: hours, nestLevel: nestLevel, sparkLevel: sparkLevel) {
            lastComebackChestDay = today
            sparkDust = min(999, sparkDust + reward.sparks)
            happiness = min(5, happiness + reward.joy)
            energy = min(Self.maxEnergy, energy + reward.energy)
            notes.append(reward.line)
            if let memoryNote = unlockMemory(.firstComeback) {
                notes.append(memoryNote)
            }
        }

        lastLifecycleAt = now
        if !notes.isEmpty {
            lastRequest = reason == "launch" ? "Welcome back" : "Comeback"
            message = pikaText(notes.joined(separator: " "))
            speakPika()
        }
        persistCare()
    }

    private func syncDailyCombo() {
        let today = Self.dayFormatter.string(from: Date())
        let week = Self.weekKey(for: Date())
        var changed = false
        if weeklyCareWeek != week {
            weeklyCareWeek = week
            weeklyCareCount = 0
            weeklyRewardMask = 0
            changed = true
        }
        if seasonTrailWeek != week {
            seasonTrailWeek = week
            seasonTrailMask = 0
            changed = true
        }
        if dailyNudgeDate != today {
            dailyNudgeDate = today
            dailyNudgeOfferedMask = 0
            dailyNudgeAnsweredMask = 0
            dailyNudgeDismissedMask = 0
            changed = true
        }
        if dailyCheerPingDate != today {
            dailyCheerPingDate = today
            dailyCheerPingOfferedMask = 0
            dailyCheerPingAnsweredMask = 0
            dailyCheerPingDismissedMask = 0
            changed = true
        }
        if dailyMoodWeatherDate != today {
            dailyMoodWeatherDate = today
            dailyMoodWeatherOfferedMask = 0
            dailyMoodWeatherAnsweredMask = 0
            dailyMoodWeatherDismissedMask = 0
            changed = true
        }
        if dailyJourneyDate != today {
            dailyJourneyDate = today
            dailyJourneyOfferedMask = 0
            dailyJourneyAnsweredMask = 0
            dailyJourneyDismissedMask = 0
            changed = true
        }
        if dailyVisitDate != today {
            dailyVisitDate = today
            dailyVisitOfferedMask = 0
            dailyVisitAnsweredMask = 0
            dailyVisitDismissedMask = 0
            changed = true
        }
        if dailySparkWheelDate != today {
            dailySparkWheelDate = today
            dailySparkWheelOfferedMask = 0
            dailySparkWheelStartedMask = 0
            dailySparkWheelClaimedMask = 0
            dailySparkWheelDismissedMask = 0
            changed = true
        }
        if dailyExchangeDate != today {
            dailyExchangeDate = today
            dailyExchangeOfferedMask = 0
            dailyExchangeAnsweredMask = 0
            dailyExchangeDismissedMask = 0
            changed = true
        }
        if dailyCheerDialogueDate != today {
            dailyCheerDialogueDate = today
            dailyCheerDialogueOfferedMask = 0
            dailyCheerDialogueAnsweredMask = 0
            dailyCheerDialogueDismissedMask = 0
            changed = true
        }
        if dailyCheerIntentDate != today {
            dailyCheerIntentDate = today
            dailyCheerIntentOfferedMask = 0
            dailyCheerIntentAnsweredMask = 0
            dailyCheerIntentDismissedMask = 0
            changed = true
        }
        if dailyCheerMemoryDate != today {
            dailyCheerMemoryDate = today
            dailyCheerMemoryMask = 0
            changed = true
        }
        if dailyCheerScriptDate != today {
            dailyCheerScriptDate = today
            dailyCheerScriptOfferedMask = 0
            dailyCheerScriptAnsweredMask = 0
            dailyCheerScriptDismissedMask = 0
            changed = true
        }
        if dailyMoodStoryDate != today {
            dailyMoodStoryDate = today
            dailyMoodStoryOfferedMask = 0
            dailyMoodStoryAnsweredMask = 0
            dailyMoodStoryDismissedMask = 0
            changed = true
        }
        if dailyFieldNoteDate != today {
            dailyFieldNoteDate = today
            dailyFieldNoteOfferedMask = 0
            dailyFieldNoteSavedMask = 0
            dailyFieldNoteDismissedMask = 0
            changed = true
        }
        if dailyScoutTripDate != today {
            dailyScoutTripDate = today
            dailyScoutTripStartedMask = 0
            dailyScoutTripReturnedMask = 0
            changed = true
        }
        if dailyAffectionDate != today {
            dailyAffectionDate = today
            dailyAffectionOfferedMask = 0
            dailyAffectionGivenMask = 0
            dailyAffectionDismissedMask = 0
            changed = true
        }
        if dailyHomeDate != today {
            dailyHomeDate = today
            dailyHomeOfferedMask = 0
            dailyHomeVisitedMask = 0
            dailyHomeDismissedMask = 0
            changed = true
        }
        if dailyErrandDate != today {
            dailyErrandDate = today
            dailyErrandOfferedMask = 0
            dailyErrandDoneMask = 0
            dailyErrandDismissedMask = 0
            changed = true
        }
        if dailyUserCheckDate != today {
            dailyUserCheckDate = today
            dailyUserCheckOfferedMask = 0
            dailyUserCheckAnsweredMask = 0
            dailyUserCheckDismissedMask = 0
            changed = true
        }
        if dailyWishDate != today {
            dailyWishDate = today
            dailyWishOfferedMask = 0
            dailyWishFulfilledMask = 0
            dailyWishDismissedMask = 0
            changed = true
        }
        if dailyToyDate != today {
            dailyToyDate = today
            dailyToyOfferedMask = 0
            dailyToyPlayedMask = 0
            dailyToyDismissedMask = 0
            changed = true
        }
        if dailyTrickDate != today {
            dailyTrickDate = today
            dailyTrickOfferedMask = 0
            dailyTrickPracticedMask = 0
            dailyTrickDismissedMask = 0
            changed = true
        }
        if dailyAmbientDate != today {
            dailyAmbientDate = today
            dailyAmbientMask = 0
            changed = true
        }
        if dailyRouteDate != today {
            dailyRouteDate = today
            dailyRouteMask = 0
            dailyRouteOfferedMask = 0
            dailyRouteDismissedMask = 0
            changed = true
        }
        if dailyCarePulseDate != today {
            dailyCarePulseDate = today
            dailyCarePulseOfferedMask = 0
            dailyCarePulseAnsweredMask = 0
            dailyCarePulseDismissedMask = 0
            changed = true
        }
        if dailyCareWindowDate != today {
            dailyCareWindowDate = today
            dailyCareWindowMask = 0
            changed = true
        }
        if dailyAffirmationDate != today {
            dailyAffirmationDate = today
            dailyAffirmationMask = 0
            changed = true
        }
        if dailyWellnessDate != today {
            dailyWellnessDate = today
            dailyWellnessMask = 0
            changed = true
        }
        if dailyComboDate != today {
            dailyComboDate = today
            dailyComboMask = 0
            changed = true
        }
        if dailyQuestDate != today {
            dailyQuestDate = today
            dailyQuestMask = 0
            changed = true
        }
        if dailyBondBoardDate != today {
            dailyBondBoardDate = today
            dailyBondBoardMask = 0
            changed = true
        }
        if dailyBoosterDate != today {
            dailyBoosterDate = today
            dailyBoosterUsed = false
            changed = true
        }
        if dailyCipherDate != today {
            dailyCipherDate = today
            dailyCipherSolved = false
            changed = true
        }
        if dailyEventDate != today {
            dailyEventDate = today
            dailyEventProgress = 0
            changed = true
        }
        if dailyFeelingDate != today {
            dailyFeelingDate = today
            dailyFeelingMask = 0
            changed = true
        }
        if dailyEmotionWheelDate != today {
            dailyEmotionWheelDate = today
            dailyEmotionWheelRaw = 0
            changed = true
        }
        if dailyBondTimelineDate != today {
            dailyBondTimelineDate = today
            dailyBondTimelineOfferedMask = 0
            dailyBondTimelineSavedMask = 0
            dailyBondTimelineDismissedMask = 0
            changed = true
        }
        if dailyEmotionEpisodeDate != today {
            dailyEmotionEpisodeDate = today
            dailyEmotionEpisodeMask = 0
            changed = true
        }
        if dailyEmotionArcDate != today {
            dailyEmotionArcDate = today
            dailyEmotionArcMask = 0
            changed = true
        }
        if dailyMoodCareDate != today {
            dailyMoodCareDate = today
            dailyMoodCareFeelingRaw = petFeeling.rawValue
            dailyMoodCareMask = 0
            changed = true
        }
        if dailyFeelingRitualDate != today {
            dailyFeelingRitualDate = today
            dailyFeelingRitualOfferedMask = 0
            dailyFeelingRitualAnsweredMask = 0
            dailyFeelingRitualDismissedMask = 0
            changed = true
        }
        if dailyCareChestDate != today {
            dailyCareChestDate = today
            dailyCareChestOfferedMask = 0
            dailyCareChestClaimedMask = 0
            dailyCareChestDismissedMask = 0
            changed = true
        }
        guard changed else { return }
        persistCare()
    }

    private func recordRecoveryScene(_ scene: PetRecoveryScene, daysMissed: Int, shieldUsed: Bool) -> String? {
        latestRecoverySceneRaw = scene.rawValue
        let shieldLine = shieldUsed ? " Shield \(streakShieldCount)/3 left." : ""
        guard recoveryAlbumMask & scene.rawValue == 0 else {
            return "\(scene.title) remembered.\(shieldLine)"
        }

        recoveryAlbumMask |= scene.rawValue
        sparkDust = min(999, sparkDust + scene.sparkReward)
        happiness = min(5, happiness + scene.joyReward)
        var notes = [
            "\(scene.rewardLine) Joy +\(scene.joyReward), Sparks +\(scene.sparkReward).\(shieldLine)"
        ]
        if let vitalNote = refillVital(scene.vital, by: 1) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(scene.moodStep) {
            notes.append(moodCareNote)
        }
        return notes.joined(separator: " ")
    }

    private func awardStreakShieldIfNeeded() -> String? {
        var notes: [String] = []
        if petStreak > 0, petStreak % 3 == 0, streakShieldCount < 3 {
            streakShieldCount += 1
            notes.append("Streak Shield earned: \(streakShieldCount)/3 ready for a missed day.")
        }
        if recoveryAlbumMask != 0,
           petStreak >= 3,
           recoveryAlbumMask & PetRecoveryScene.streakRekindled.rawValue == 0,
           let rekindled = recordRecoveryScene(.streakRekindled, daysMissed: 0, shieldUsed: false) {
            notes.append(rekindled)
        }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    private func awardWeeklyCareMilestones() -> String? {
        let chapters = PetWeeklyTrailChapter.newlyUnlocked(
            careCount: weeklyCareCount,
            albumMask: weeklyTrailAlbumMask
        )
        let milestones = PetStreakMilestone.newlyUnlocked(
            careCount: weeklyCareCount,
            rewardMask: weeklyRewardMask
        )
        guard !chapters.isEmpty || !milestones.isEmpty else { return nil }

        let priorMask = weeklyRewardMask
        var notes: [String] = []
        for chapter in chapters {
            weeklyTrailAlbumMask |= chapter.rawValue
            sparkDust = min(999, sparkDust + chapter.sparkReward)
            happiness = min(5, happiness + chapter.joyReward)
            if chapter.bondHPReward > 0 {
                companionHP = min(10, companionHP + chapter.bondHPReward)
            }
            notes.append(
                "\(chapter.rewardLine) Joy +\(chapter.joyReward), Sparks +\(chapter.sparkReward)\(chapter.bondHPReward > 0 ? ", Bond HP +\(chapter.bondHPReward)" : "")."
            )
            if let vitalNote = refillVital(chapter.vital, by: 1) {
                notes.append(vitalNote)
            }
            if let moodCareNote = markMoodCare(chapter.moodStep) {
                notes.append(moodCareNote)
            }
        }

        for milestone in milestones {
            weeklyRewardMask |= milestone.rawValue
            sparkDust = min(999, sparkDust + milestone.sparkReward)
            happiness = min(5, happiness + milestone.joyReward)
            if milestone.bondHPReward > 0 {
                companionHP = min(10, companionHP + milestone.bondHPReward)
            }
            notes.append(
                "\(milestone.title): \(milestone.rewardLine) Joy +\(milestone.joyReward), Sparks +\(milestone.sparkReward)\(milestone.bondHPReward > 0 ? ", Bond HP +\(milestone.bondHPReward)" : "")."
            )
        }
        if priorMask != weeklyRewardMask || !chapters.isEmpty {
            setMood(.hyper, duration: 1.8)
            play(.happy)
            if let charmNote = unlockCharm(.weeklyTrail) {
                notes.append(charmNote)
            }
        }
        persistCare()
        return notes.joined(separator: " ")
    }

    private func recordSeasonTrailProgress(event: PetSeasonEvent) -> String? {
        syncDailyCombo()
        guard let chapter = PetSeasonTrailChapter.next(
            careCount: weeklyCareCount,
            claimedMask: seasonTrailMask
        ) else {
            return nil
        }

        seasonTrailMask |= chapter.rawValue
        seasonTrailAlbumMask |= chapter.rawValue
        latestSeasonTrailRaw = chapter.rawValue
        let sparkReward = chapter.sparkReward + sparkLevel + questLevel
        sparkDust = min(999, sparkDust + sparkReward)
        happiness = min(5, happiness + chapter.joyReward)
        if chapter.bondHPReward > 0 {
            companionHP = min(10, companionHP + chapter.bondHPReward)
        }

        var notes = [
            "\(chapter.rewardLine) \(event.title) advances the Season Trail: Joy +\(chapter.joyReward), Sparks +\(sparkReward)\(chapter.bondHPReward > 0 ? ", Bond HP +\(chapter.bondHPReward)" : "")."
        ]
        if let vitalNote = refillVital(chapter.vital, by: 1) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(chapter.moodStep) {
            notes.append(moodCareNote)
        }
        if chapter == .guardianFinale, let charmNote = unlockCharm(.eventRibbon) {
            notes.append(charmNote)
        }
        setMood(chapter.mood, duration: 1.7)
        persistCare()
        return notes.joined(separator: " ")
    }

    private func recordDailyJourneyAnswer() -> String? {
        syncDailyCombo()
        guard let phase = PetDailyNudgeJourneyPhase(rawValue: cheerJourneyRaw) else { return nil }
        let wasAnswered = dailyJourneyAnsweredMask & phase.rawValue != 0
        dailyJourneyOfferedMask |= phase.rawValue
        dailyJourneyAnsweredMask |= phase.rawValue
        dailyJourneyDismissedMask &= ~phase.rawValue
        journeyAlbumMask |= phase.rawValue
        latestJourneyRaw = phase.rawValue
        guard !wasAnswered else {
            persistCare()
            return nil
        }

        let reward = phase.sparkReward + min(3, cheerLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        var notes = ["\(phase.title) saved in Daily Journey: \(phase.rewardLine). Joy +1, Sparks +\(reward)."]
        if let vitalNote = refillVital(phase.vital, by: 1) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(phase.moodStep) {
            notes.append(moodCareNote)
        }
        persistCare()
        return notes.joined(separator: " ")
    }

    private func recordVisitAnswer() -> String? {
        syncDailyCombo()
        guard let beat = PetVisitBeat(rawValue: cheerVisitRaw) else { return nil }
        return recordVisit(beat)
    }

    private func recordVisit(_ beat: PetVisitBeat) -> String {
        syncDailyCombo()
        let wasAnswered = dailyVisitAnsweredMask & beat.rawValue != 0
        let wasUnlocked = visitAlbumMask & beat.rawValue != 0
        dailyVisitOfferedMask |= beat.rawValue
        dailyVisitAnsweredMask |= beat.rawValue
        dailyVisitDismissedMask &= ~beat.rawValue
        visitAlbumMask |= beat.rawValue
        latestVisitRaw = beat.rawValue

        guard !wasAnswered else {
            persistCare()
            return "\(beat.title) is already saved today. \(beat.rewardLine)."
        }

        let reward = (wasUnlocked ? 3 : beat.sparkReward) + min(4, cheerLevel + focusLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "Visit logged: \(beat.title). \(beat.rewardLine). Joy +1, Sparks +\(reward)."
        ]
        if let vitalNote = refillVital(beat.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(beat.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Visit Log album unlocked: \(beat.shortLabel).")
        }
        if !wasUnlocked, PetVisitBeat.allCases.allSatisfy({ (visitAlbumMask | beat.rawValue) & $0.rawValue != 0 }) {
            companionHP = min(10, companionHP + 1)
            sparkDust = min(999, sparkDust + 40)
            notes.append("Full Visit Log complete: Bond HP +1 and Sparks +40.")
        }
        persistCare()
        setMood(beat.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private func recordSparkWheelAnswer() -> String? {
        syncDailyCombo()
        guard let cycle = PetSparkWheelCycle(rawValue: cheerSparkWheelRaw) else { return nil }
        if activeSparkWheelRaw == cycle.rawValue {
            if let remaining = sparkWheelRemainingSeconds, remaining > 0 {
                return "\(cycle.title) is still spinning: \(remaining)s left."
            }
            return claimSparkWheel(cycle)
        }
        return startSparkWheel(cycle)
    }

    private func startSparkWheel(_ cycle: PetSparkWheelCycle) -> String {
        syncDailyCombo()
        if let active = activeSparkWheelCycle {
            return "\(active.title) is already spinning. \(active.startLine(stage: growthStage, feeling: petFeeling))"
        }

        activeSparkWheelRaw = cycle.rawValue
        activeSparkWheelStartedAt = Date().timeIntervalSince1970
        dailySparkWheelOfferedMask |= cycle.rawValue
        dailySparkWheelStartedMask |= cycle.rawValue
        dailySparkWheelDismissedMask &= ~cycle.rawValue
        latestSparkWheelRaw = cycle.rawValue
        let energyNote = spendEnergy() ? " Energy -1." : " Energy is recharging."
        persistCare()
        return "Spark Wheel started: \(cycle.title). \(cycle.startLine(stage: growthStage, feeling: petFeeling))\(energyNote)"
    }

    private func claimSparkWheel(_ cycle: PetSparkWheelCycle) -> String {
        syncDailyCombo()
        let wasClaimedToday = dailySparkWheelClaimedMask & cycle.rawValue != 0
        let wasUnlocked = sparkWheelAlbumMask & cycle.rawValue != 0
        dailySparkWheelOfferedMask |= cycle.rawValue
        dailySparkWheelStartedMask |= cycle.rawValue
        dailySparkWheelClaimedMask |= cycle.rawValue
        dailySparkWheelDismissedMask &= ~cycle.rawValue
        sparkWheelAlbumMask |= cycle.rawValue
        latestSparkWheelRaw = cycle.rawValue
        activeSparkWheelRaw = 0
        activeSparkWheelStartedAt = 0

        guard !wasClaimedToday else {
            persistCare()
            return "\(cycle.title) was already claimed today. \(cycle.returnLine(stage: growthStage, feeling: petFeeling))"
        }

        let passiveBonus = min(18, passiveSparkRate + sparkLevel * 2)
        let reward = (wasUnlocked ? 6 : cycle.sparkReward) + passiveBonus
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "\(cycle.rewardLine). \(cycle.returnLine(stage: growthStage, feeling: petFeeling)) Joy +1, Sparks +\(reward)."
        ]
        if let vitalNote = refillVital(cycle.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(cycle.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Spark Wheel album unlocked: \(cycle.shortLabel).")
        }
        if !wasUnlocked, PetSparkWheelCycle.allCases.allSatisfy({ sparkWheelAlbumMask & $0.rawValue != 0 }) {
            companionHP = min(10, companionHP + 1)
            sparkDust = min(999, sparkDust + 45)
            notes.append("Full Spark Wheel cycle complete: Bond HP +1 and Sparks +45.")
        }
        persistCare()
        setMood(cycle.mood, duration: 1.8)
        return notes.joined(separator: " ")
    }

    private func recordExchangeBoardAnswer() -> String? {
        syncDailyCombo()
        guard let step = PetExchangeBoardStep(rawValue: cheerExchangeRaw) else { return nil }
        let wasAnswered = dailyExchangeAnsweredMask & step.rawValue != 0
        dailyExchangeOfferedMask |= step.rawValue
        dailyExchangeAnsweredMask |= step.rawValue
        dailyExchangeDismissedMask &= ~step.rawValue
        exchangeAlbumMask |= step.rawValue
        latestExchangeRaw = step.rawValue
        guard !wasAnswered else {
            persistCare()
            return nil
        }

        let reward = isExchangeBoardStepComplete(step) ? 8 + sparkLevel : 4 + min(3, cheerLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        persistCare()
        return "Spark Exchange logged \(step.title): \(step.rewardLine). Joy +1, Sparks +\(reward)."
    }

    private func recordCheerAnswer() -> String? {
        syncDailyCombo()
        guard let daypart = PetDaypartNudge(rawValue: cheerDaypartRaw) else { return nil }
        let wasAnswered = dailyNudgeAnsweredMask & daypart.rawValue != 0
        dailyNudgeOfferedMask |= daypart.rawValue
        dailyNudgeAnsweredMask |= daypart.rawValue
        dailyNudgeDismissedMask &= ~daypart.rawValue
        guard !wasAnswered else {
            persistCare()
            return nil
        }

        let reward = 4 + cheerLevel + sparkLevel
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        persistCare()
        return "\(daypart.title) logged in Cheer Rhythm: Joy +1, Sparks +\(reward)."
    }

    private func recordCheerPingAnswer() -> String? {
        syncDailyCombo()
        guard let ping = PetCheerPing(rawValue: cheerPingRaw) else { return nil }
        let wasAnswered = dailyCheerPingAnsweredMask & ping.rawValue != 0
        let wasUnlocked = cheerPingAlbumMask & ping.rawValue != 0
        dailyCheerPingOfferedMask |= ping.rawValue
        dailyCheerPingAnsweredMask |= ping.rawValue
        dailyCheerPingDismissedMask &= ~ping.rawValue
        cheerPingAlbumMask |= ping.rawValue
        latestCheerPingRaw = ping.rawValue
        guard !wasAnswered else {
            let smallReward = 2 + min(2, cheerLevel)
            sparkDust = min(999, sparkDust + smallReward)
            persistCare()
            return "\(ping.title) already answered today. Sparks +\(smallReward)."
        }

        let reward = 6 + cheerLevel + min(4, sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        var notes = [
            "\(ping.title) saved in Cheer Pings: \(ping.rewardLine). Joy +1, Sparks +\(reward)."
        ]
        if !wasUnlocked {
            notes.append("Cheer ping album unlocked: \(ping.shortLabel).")
        }
        if let vitalNote = refillVital(ping.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(ping.moodStep) {
            notes.append(moodCareNote)
        }
        persistCare()
        setMood(ping.mood, duration: 1.6)
        return notes.joined(separator: " ")
    }

    private func recordCheerDialogueAnswer() -> String? {
        syncDailyCombo()
        guard let dialogue = PetCheerDialogue(rawValue: cheerDialogueRaw) else { return nil }
        let wasAnswered = dailyCheerDialogueAnsweredMask & dialogue.rawValue != 0
        dailyCheerDialogueOfferedMask |= dialogue.rawValue
        dailyCheerDialogueAnsweredMask |= dialogue.rawValue
        dailyCheerDialogueDismissedMask &= ~dialogue.rawValue
        cheerDialogueAlbumMask |= dialogue.rawValue
        guard !wasAnswered else {
            persistCare()
            return nil
        }

        let reward = 5 + cheerLevel + sparkLevel
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        persistCare()
        return "\(dialogue.title) saved in Cheer Dialogues: Joy +1, Sparks +\(reward). \(dialogue.rewardReceipt)"
    }

    private func recordCheerScriptAnswer() -> String? {
        syncDailyCombo()
        guard let script = PetCheerScript(rawValue: cheerScriptRaw) else { return nil }
        let wasAnswered = dailyCheerScriptAnsweredMask & script.rawValue != 0
        dailyCheerScriptOfferedMask |= script.rawValue
        dailyCheerScriptAnsweredMask |= script.rawValue
        dailyCheerScriptDismissedMask &= ~script.rawValue
        cheerScriptAlbumMask |= script.rawValue
        guard !wasAnswered else {
            persistCare()
            return nil
        }

        let reward = script.sparkReward + cheerLevel + min(3, sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        var notes = ["\(script.title) saved in Cheer Scripts: Joy +1, Sparks +\(reward)."]
        if let vitalNote = refillVital(script.vital, by: 1) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(script.moodStep) {
            notes.append(moodCareNote)
        }
        persistCare()
        return notes.joined(separator: " ")
    }

    private func recordMoodStoryAnswer() -> String? {
        syncDailyCombo()
        guard let story = PetMoodStory(rawValue: cheerMoodStoryRaw) else { return nil }
        let wasAnswered = dailyMoodStoryAnsweredMask & story.rawValue != 0
        let wasUnlocked = moodStoryAlbumMask & story.rawValue != 0
        dailyMoodStoryOfferedMask |= story.rawValue
        dailyMoodStoryAnsweredMask |= story.rawValue
        dailyMoodStoryDismissedMask &= ~story.rawValue
        moodStoryAlbumMask |= story.rawValue
        latestMoodStoryRaw = story.rawValue
        guard !wasAnswered || !wasUnlocked else {
            persistCare()
            return nil
        }

        let reward = story.sparkReward + cheerLevel + min(4, sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        var notes = ["Mood story saved: \(story.title). \(story.rewardLine) Joy +1, Sparks +\(reward)."]
        if let vitalNote = refillVital(story.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(story.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Mood story album unlocked: \(story.shortLabel).")
        }
        persistCare()
        setMood(story.mood, duration: 1.6)
        return notes.joined(separator: " ")
    }

    private func recordFeelingRitualAnswer() -> String? {
        syncDailyCombo()
        guard let ritual = PetFeelingRitual(rawValue: cheerFeelingRitualRaw) else { return nil }
        let wasAnswered = dailyFeelingRitualAnsweredMask & ritual.rawValue != 0
        let wasUnlocked = feelingRitualAlbumMask & ritual.rawValue != 0
        dailyFeelingRitualOfferedMask |= ritual.rawValue
        dailyFeelingRitualAnsweredMask |= ritual.rawValue
        dailyFeelingRitualDismissedMask &= ~ritual.rawValue
        feelingRitualAlbumMask |= ritual.rawValue
        latestFeelingRitualRaw = ritual.rawValue
        guard !wasAnswered || !wasUnlocked else {
            persistCare()
            return nil
        }

        let reward = ritual.sparkReward + min(5, cheerLevel + focusLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        var notes = ["Feeling ritual saved: \(ritual.title). \(ritual.rewardLine) Joy +1, Sparks +\(reward)."]
        if let vitalNote = refillVital(ritual.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(ritual.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Feeling ritual album unlocked: \(ritual.shortLabel).")
        }
        persistCare()
        setMood(ritual.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private func recordCareChestAnswer() -> String? {
        syncDailyCombo()
        guard let chest = PetCareChest(rawValue: cheerCareChestRaw) else { return nil }
        return recordCareChest(chest)
    }

    private func recordCareChest(_ chest: PetCareChest) -> String? {
        syncDailyCombo()
        let wasClaimed = dailyCareChestClaimedMask & chest.rawValue != 0
        let wasUnlocked = careChestAlbumMask & chest.rawValue != 0
        dailyCareChestOfferedMask |= chest.rawValue
        dailyCareChestClaimedMask |= chest.rawValue
        dailyCareChestDismissedMask &= ~chest.rawValue
        careChestAlbumMask |= chest.rawValue
        latestCareChestRaw = chest.rawValue
        guard !wasClaimed || !wasUnlocked else {
            let smallReward = 2 + min(2, sparkLevel)
            sparkDust = min(999, sparkDust + smallReward)
            persistCare()
            return "\(chest.title) is already open today. \(chest.rewardLine), Sparks +\(smallReward)."
        }

        let reward = chest.sparkReward + min(6, sparkLevel + cheerLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + chest.joyReward)
        recordDailyQuest(chest.dailyQuest)
        var notes = ["Care chest opened: \(chest.title). \(chest.rewardLine). Joy +\(chest.joyReward), Sparks +\(reward)."]
        if let vitalNote = refillVital(chest.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(chest.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Care chest album unlocked: \(chest.shortLabel).")
        }
        persistCare()
        setMood(chest.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private func recordFieldNoteAnswer() -> String? {
        syncDailyCombo()
        guard let note = PetFieldNote(rawValue: cheerFieldNoteRaw) else { return nil }
        return recordFieldNote(note)
    }

    private func recordScoutTripAnswer() -> String? {
        syncDailyCombo()
        guard let trip = PetScoutTrip(rawValue: cheerScoutTripRaw) else { return nil }
        guard activeScoutTripRaw == trip.rawValue, (scoutTripRemainingSeconds ?? 1) == 0 else { return nil }
        return recordScoutTripReturn(trip)
    }

    private func recordAffectionAnswer() -> String? {
        syncDailyCombo()
        guard let gesture = PetAffectionGesture(rawValue: cheerAffectionRaw) else { return nil }
        return recordAffectionGesture(gesture)
    }

    private func recordHomeRoomAnswer() -> String? {
        syncDailyCombo()
        guard let room = PetHomeRoom(rawValue: cheerHomeRoomRaw) else { return nil }
        return recordHomeRoom(room)
    }

    private func recordErrandAnswer() -> String? {
        syncDailyCombo()
        guard let errand = PetDailyErrand(rawValue: cheerErrandRaw) else { return nil }
        return recordDailyErrand(errand)
    }

    private func recordUserCheckAnswer() -> String? {
        syncDailyCombo()
        guard let checkIn = PetUserCheckIn(rawValue: cheerUserCheckRaw) else { return nil }
        return recordUserCheckIn(checkIn)
    }

    private func recordWishAnswer() -> String? {
        syncDailyCombo()
        guard let wish = PetWish(rawValue: cheerWishRaw) else { return nil }
        return recordWish(wish)
    }

    private func recordToyAnswer() -> String? {
        syncDailyCombo()
        guard let toy = PetToy(rawValue: cheerToyRaw) else { return nil }
        return recordToy(toy)
    }

    private func recordTrickAnswer() -> String? {
        syncDailyCombo()
        guard let trick = PetTrick(rawValue: cheerTrickRaw) else { return nil }
        return recordTrick(trick)
    }

    private func recordFieldNote(_ note: PetFieldNote) -> String {
        syncDailyCombo()
        let wasSavedToday = dailyFieldNoteSavedMask & note.rawValue != 0
        let wasUnlocked = fieldNoteAlbumMask & note.rawValue != 0
        dailyFieldNoteOfferedMask |= note.rawValue
        dailyFieldNoteSavedMask |= note.rawValue
        dailyFieldNoteDismissedMask &= ~note.rawValue
        fieldNoteAlbumMask |= note.rawValue
        latestFieldNoteRaw = note.rawValue

        guard !wasSavedToday else {
            persistCare()
            return "\(note.title) is already in today's field journal. \(note.fieldLine)"
        }

        let reward = (wasUnlocked ? 2 : note.sparkReward) + min(4, questLevel + focusLevel)
        sparkDust = min(999, sparkDust + reward)
        if !wasUnlocked {
            happiness = min(5, happiness + 1)
        }

        var notes = [
            "Field note saved: \(note.title). \(note.body(stage: growthStage, feeling: petFeeling)) Sparks +\(reward)\(!wasUnlocked ? ", Joy +1" : "")."
        ]
        if let vitalNote = refillVital(note.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(note.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Field journal unlocked: \(note.shortLabel).")
        }
        persistCare()
        setMood(note.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private func recordScoutTripReturn(_ trip: PetScoutTrip) -> String {
        syncDailyCombo()
        let wasReturnedToday = dailyScoutTripReturnedMask & trip.rawValue != 0
        let wasUnlocked = scoutTripAlbumMask & trip.rawValue != 0
        dailyScoutTripStartedMask |= trip.rawValue
        dailyScoutTripReturnedMask |= trip.rawValue
        scoutTripAlbumMask |= trip.rawValue
        latestScoutTripRaw = trip.rawValue
        activeScoutTripRaw = 0
        activeScoutTripStartedAt = 0
        scoutTripTask?.cancel()

        guard !wasReturnedToday else {
            persistCare()
            return "\(trip.title) already returned today. \(trip.returnLine(stage: growthStage, feeling: petFeeling))"
        }

        let reward = (wasUnlocked ? 3 : trip.sparkReward) + min(5, questLevel + sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        if !wasUnlocked {
            happiness = min(5, happiness + 1)
        }

        var notes = [
            "Scout returned: \(trip.title). \(trip.returnLine(stage: growthStage, feeling: petFeeling)) Sparks +\(reward)\(!wasUnlocked ? ", Joy +1" : "")."
        ]
        if let vitalNote = refillVital(trip.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(trip.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Scout album unlocked: \(trip.shortLabel).")
        }
        persistCare()
        setMood(trip.mood, duration: 1.6)
        return notes.joined(separator: " ")
    }

    private func recordAffectionGesture(_ gesture: PetAffectionGesture) -> String {
        syncDailyCombo()
        let wasGivenToday = dailyAffectionGivenMask & gesture.rawValue != 0
        let wasUnlocked = affectionAlbumMask & gesture.rawValue != 0
        dailyAffectionOfferedMask |= gesture.rawValue
        dailyAffectionGivenMask |= gesture.rawValue
        dailyAffectionDismissedMask &= ~gesture.rawValue
        affectionAlbumMask |= gesture.rawValue
        latestAffectionRaw = gesture.rawValue

        guard !wasGivenToday else {
            persistCare()
            return "\(gesture.title) already warmed the bond today. \(gesture.careLine(stage: growthStage, feeling: petFeeling))"
        }

        let reward = (wasUnlocked ? 3 : gesture.sparkReward) + min(5, cheerLevel + nestLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "Bond gesture: \(gesture.title). \(gesture.careLine(stage: growthStage, feeling: petFeeling)) Joy +1, Sparks +\(reward)."
        ]
        if let vitalNote = refillVital(gesture.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(gesture.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Bond album unlocked: \(gesture.shortLabel).")
        }
        persistCare()
        setMood(gesture.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private func recordHomeRoom(_ room: PetHomeRoom) -> String {
        syncDailyCombo()
        let wasHomeComplete = PetHomeRoom.allCases.allSatisfy { dailyHomeVisitedMask & $0.rawValue != 0 }
        let wasVisitedToday = dailyHomeVisitedMask & room.rawValue != 0
        let wasUnlocked = homeAlbumMask & room.rawValue != 0
        dailyHomeOfferedMask |= room.rawValue
        dailyHomeVisitedMask |= room.rawValue
        dailyHomeDismissedMask &= ~room.rawValue
        homeAlbumMask |= room.rawValue
        latestHomeRoomRaw = room.rawValue

        guard !wasVisitedToday else {
            persistCare()
            return "\(room.title) already feels lived-in today. \(room.visitLine(stage: growthStage, feeling: petFeeling))"
        }

        let reward = (wasUnlocked ? 3 : room.sparkReward) + min(6, nestLevel + sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "Home room visited: \(room.title). \(room.visitLine(stage: growthStage, feeling: petFeeling)) Joy +1, Sparks +\(reward)."
        ]
        if let vitalNote = refillVital(room.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(room.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Home album unlocked: \(room.shortLabel).")
        }
        if !wasHomeComplete, PetHomeRoom.allCases.allSatisfy({ dailyHomeVisitedMask & $0.rawValue != 0 }) {
            companionHP = min(10, companionHP + 1)
            sparkDust = min(999, sparkDust + 40)
            notes.append("Full home round complete: Bond HP +1 and Sparks +40.")
        }
        persistCare()
        setMood(room.mood, duration: 1.8)
        return notes.joined(separator: " ")
    }

    private func recordDailyErrand(_ errand: PetDailyErrand) -> String {
        syncDailyCombo()
        let wasErrandSetComplete = PetDailyErrand.allCases.allSatisfy { dailyErrandDoneMask & $0.rawValue != 0 }
        let wasDoneToday = dailyErrandDoneMask & errand.rawValue != 0
        let wasUnlocked = errandAlbumMask & errand.rawValue != 0
        dailyErrandOfferedMask |= errand.rawValue
        dailyErrandDoneMask |= errand.rawValue
        dailyErrandDismissedMask &= ~errand.rawValue
        errandAlbumMask |= errand.rawValue
        latestErrandRaw = errand.rawValue

        guard !wasDoneToday else {
            persistCare()
            return "\(errand.title) already came back today. \(errand.runLine(stage: growthStage, feeling: petFeeling))"
        }

        let reward = (wasUnlocked ? 4 : errand.sparkReward) + min(6, questLevel + sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "Errand complete: \(errand.title). \(errand.runLine(stage: growthStage, feeling: petFeeling)) Joy +1, Sparks +\(reward)."
        ]
        if let vitalNote = refillVital(errand.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(errand.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Errand album unlocked: \(errand.shortLabel).")
        }
        if !wasErrandSetComplete, PetDailyErrand.allCases.allSatisfy({ dailyErrandDoneMask & $0.rawValue != 0 }) {
            companionHP = min(10, companionHP + 1)
            sparkDust = min(999, sparkDust + 44)
            notes.append("Full errand board complete: Bond HP +1 and Sparks +44.")
        }
        persistCare()
        setMood(errand.mood, duration: 1.8)
        return notes.joined(separator: " ")
    }

    private func recordUserCheckIn(_ checkIn: PetUserCheckIn) -> String {
        syncDailyCombo()
        let wasCheckSetComplete = PetUserCheckIn.allCases.allSatisfy { dailyUserCheckAnsweredMask & $0.rawValue != 0 }
        let wasAnsweredToday = dailyUserCheckAnsweredMask & checkIn.rawValue != 0
        let wasUnlocked = userCheckAlbumMask & checkIn.rawValue != 0
        dailyUserCheckOfferedMask |= checkIn.rawValue
        dailyUserCheckAnsweredMask |= checkIn.rawValue
        dailyUserCheckDismissedMask &= ~checkIn.rawValue
        userCheckAlbumMask |= checkIn.rawValue
        latestUserCheckRaw = checkIn.rawValue

        guard !wasAnsweredToday else {
            persistCare()
            return "\(checkIn.title) is already saved today. \(checkIn.supportLine)"
        }

        let reward = (wasUnlocked ? 4 : checkIn.sparkReward) + min(6, cheerLevel + focusLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "User check-in: \(checkIn.title). \(checkIn.supportLine) Joy +1, Sparks +\(reward)."
        ]
        if let vitalNote = refillVital(checkIn.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(checkIn.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("User check album unlocked: \(checkIn.shortLabel).")
        }
        if !wasCheckSetComplete, PetUserCheckIn.allCases.allSatisfy({ dailyUserCheckAnsweredMask & $0.rawValue != 0 }) {
            companionHP = min(10, companionHP + 1)
            sparkDust = min(999, sparkDust + 36)
            notes.append("Full user check round complete: Bond HP +1 and Sparks +36.")
        }
        persistCare()
        setMood(checkIn.mood, duration: 1.8)
        return notes.joined(separator: " ")
    }

    private func recordWish(_ wish: PetWish) -> String {
        syncDailyCombo()
        let wasFulfilledToday = dailyWishFulfilledMask & wish.rawValue != 0
        let wasUnlocked = wishAlbumMask & wish.rawValue != 0
        dailyWishOfferedMask |= wish.rawValue
        dailyWishFulfilledMask |= wish.rawValue
        dailyWishDismissedMask &= ~wish.rawValue
        wishAlbumMask |= wish.rawValue
        latestWishRaw = wish.rawValue

        guard !wasFulfilledToday else {
            persistCare()
            return "\(wish.title) is already fulfilled today. \(wish.wishLine)"
        }

        let reward = (wasUnlocked ? 3 : wish.sparkReward) + min(5, cheerLevel + sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "Wish fulfilled: \(wish.title). \(wish.body(stage: growthStage, feeling: petFeeling)) Joy +1, Sparks +\(reward)."
        ]
        if let vitalNote = refillVital(wish.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(wish.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Wishbook album unlocked: \(wish.shortLabel).")
        }
        persistCare()
        setMood(wish.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private func recordToy(_ toy: PetToy) -> String {
        syncDailyCombo()
        let wasPlayedToday = dailyToyPlayedMask & toy.rawValue != 0
        let wasUnlocked = toyAlbumMask & toy.rawValue != 0
        dailyToyOfferedMask |= toy.rawValue
        dailyToyPlayedMask |= toy.rawValue
        dailyToyDismissedMask &= ~toy.rawValue
        toyAlbumMask |= toy.rawValue
        latestToyRaw = toy.rawValue

        guard !wasPlayedToday else {
            persistCare()
            return "\(toy.title) already got playtime today. \(toy.playLine(stage: growthStage, feeling: petFeeling))"
        }

        let reward = (wasUnlocked ? 3 : toy.sparkReward) + min(5, sparkLevel + cheerLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "Toybox play: \(toy.title). \(toy.playLine(stage: growthStage, feeling: petFeeling)) Joy +1, Sparks +\(reward)."
        ]
        if let vitalNote = refillVital(toy.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(toy.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Toybox album unlocked: \(toy.shortLabel).")
        }
        persistCare()
        setMood(toy.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private func recordTrick(_ trick: PetTrick) -> String {
        syncDailyCombo()
        guard trick.isUnlocked(stage: growthStage) else {
            let nextStage = trick.requiredStage.title
            persistCare()
            return "\(trick.title) unlocks when Pikachu reaches \(nextStage). \(PetGrowthStage.progressLine(companionHP: companionHP, sparkDust: sparkDust))"
        }

        let wasPracticedToday = dailyTrickPracticedMask & trick.rawValue != 0
        let wasUnlocked = trickAlbumMask & trick.rawValue != 0
        dailyTrickOfferedMask |= trick.rawValue
        dailyTrickPracticedMask |= trick.rawValue
        dailyTrickDismissedMask &= ~trick.rawValue
        trickAlbumMask |= trick.rawValue
        latestTrickRaw = trick.rawValue

        guard !wasPracticedToday else {
            persistCare()
            return "\(trick.title) already got practice today. \(trick.performLine(stage: growthStage, feeling: petFeeling))"
        }

        let reward = (wasUnlocked ? 3 : trick.sparkReward) + min(5, sparkLevel + cheerLevel + focusLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "Trick practiced: \(trick.title). \(trick.performLine(stage: growthStage, feeling: petFeeling)) Joy +1, Sparks +\(reward)."
        ]
        if let vitalNote = refillVital(trick.vital, by: wasUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(trick.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasUnlocked {
            notes.append("Trickbook album unlocked: \(trick.shortLabel).")
        }
        persistCare()
        setMood(trick.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private func recordCheerIntentAnswer() -> String? {
        syncDailyCombo()
        guard let intent = PetCheerIntent(rawValue: cheerIntentRaw) else { return nil }
        let wasAnswered = dailyCheerIntentAnsweredMask & intent.rawValue != 0
        dailyCheerIntentOfferedMask |= intent.rawValue
        dailyCheerIntentAnsweredMask |= intent.rawValue
        dailyCheerIntentDismissedMask &= ~intent.rawValue
        cheerIntentAlbumMask |= intent.rawValue
        guard !wasAnswered else {
            persistCare()
            return nil
        }

        let reward = intent.sparkReward + cheerLevel + min(3, sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        var notes = ["\(intent.title) saved in Check-in Types: Joy +1, Sparks +\(reward). \(intent.receiptLine)"]
        if let vitalNote = refillVital(intent.vital, by: 1) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(intent.moodStep) {
            notes.append(moodCareNote)
        }
        persistCare()
        return notes.joined(separator: " ")
    }

    private func recordCheerMemory(dialogue: PetCheerDialogue?, intent: PetCheerIntent, daypart: PetDaypartNudge?) -> String? {
        syncDailyCombo()
        let memory = PetCheerMemory.scene(dialogue: dialogue, intent: intent, daypart: daypart)
        let bit = memory.rawValue
        let seenToday = dailyCheerMemoryMask & bit != 0
        let seenEver = cheerMemoryAlbumMask & bit != 0
        latestCheerMemoryRaw = bit
        guard !seenToday || !seenEver else {
            persistCare()
            return nil
        }

        if !seenToday {
            dailyCheerMemoryMask |= bit
        }
        if !seenEver {
            cheerMemoryAlbumMask |= bit
            let reward = memory.sparkReward + min(4, cheerLevel)
            sparkDust = min(999, sparkDust + reward)
            var notes = ["Cheer memory saved: \(memory.title). \(memory.storyLine) Sparks +\(reward)."]
            if let vitalNote = refillVital(memory.vital, by: 1) {
                notes.append(vitalNote)
            }
            if let moodCareNote = markMoodCare(memory.moodStep) {
                notes.append(moodCareNote)
            }
            persistCare()
            return notes.joined(separator: " ")
        }

        let reward = 2
        sparkDust = min(999, sparkDust + reward)
        persistCare()
        return "Cheer memory revisited: \(memory.title), Sparks +\(reward)."
    }

    private func recordCheerDismissal() {
        syncDailyCombo()
        var changed = false
        if let phase = PetDailyNudgeJourneyPhase(rawValue: cheerJourneyRaw) {
            dailyJourneyOfferedMask |= phase.rawValue
            dailyJourneyDismissedMask |= phase.rawValue
            latestJourneyRaw = phase.rawValue
            changed = true
        }
        if let step = PetExchangeBoardStep(rawValue: cheerExchangeRaw) {
            dailyExchangeOfferedMask |= step.rawValue
            dailyExchangeDismissedMask |= step.rawValue
            latestExchangeRaw = step.rawValue
            changed = true
        }
        if let daypart = PetDaypartNudge(rawValue: cheerDaypartRaw) {
            dailyNudgeOfferedMask |= daypart.rawValue
            dailyNudgeDismissedMask |= daypart.rawValue
            changed = true
        }
        if let ping = PetCheerPing(rawValue: cheerPingRaw) {
            dailyCheerPingOfferedMask |= ping.rawValue
            dailyCheerPingDismissedMask |= ping.rawValue
            latestCheerPingRaw = ping.rawValue
            changed = true
        }
        if let dialogue = PetCheerDialogue(rawValue: cheerDialogueRaw) {
            dailyCheerDialogueOfferedMask |= dialogue.rawValue
            dailyCheerDialogueDismissedMask |= dialogue.rawValue
            changed = true
        }
        guard changed else { return }
        persistCare()
    }

    private func recordVisitDismissal() {
        syncDailyCombo()
        guard let beat = PetVisitBeat(rawValue: cheerVisitRaw) else { return }
        dailyVisitOfferedMask |= beat.rawValue
        dailyVisitDismissedMask |= beat.rawValue
        latestVisitRaw = beat.rawValue
        persistCare()
    }

    private func recordSparkWheelDismissal() {
        syncDailyCombo()
        guard let cycle = PetSparkWheelCycle(rawValue: cheerSparkWheelRaw) else { return }
        dailySparkWheelOfferedMask |= cycle.rawValue
        dailySparkWheelDismissedMask |= cycle.rawValue
        latestSparkWheelRaw = cycle.rawValue
        persistCare()
    }

    private func recordCheerIntentDismissal() {
        syncDailyCombo()
        guard let intent = PetCheerIntent(rawValue: cheerIntentRaw) else { return }
        dailyCheerIntentOfferedMask |= intent.rawValue
        dailyCheerIntentDismissedMask |= intent.rawValue
        persistCare()
    }

    private func recordCheerScriptDismissal() {
        syncDailyCombo()
        guard let script = PetCheerScript(rawValue: cheerScriptRaw) else { return }
        dailyCheerScriptOfferedMask |= script.rawValue
        dailyCheerScriptDismissedMask |= script.rawValue
        persistCare()
    }

    private func recordMoodStoryDismissal() {
        syncDailyCombo()
        guard let story = PetMoodStory(rawValue: cheerMoodStoryRaw) else { return }
        dailyMoodStoryOfferedMask |= story.rawValue
        dailyMoodStoryDismissedMask |= story.rawValue
        latestMoodStoryRaw = story.rawValue
        persistCare()
    }

    private func recordBondTimelineDismissal() {
        syncDailyCombo()
        guard let chapter = PetBondTimelineChapter(rawValue: cheerBondTimelineRaw) else { return }
        dailyBondTimelineOfferedMask |= chapter.rawValue
        dailyBondTimelineDismissedMask |= chapter.rawValue
        latestBondTimelineRaw = chapter.rawValue
        persistCare()
    }

    private func recordFeelingRitualDismissal() {
        syncDailyCombo()
        guard let ritual = PetFeelingRitual(rawValue: cheerFeelingRitualRaw) else { return }
        dailyFeelingRitualOfferedMask |= ritual.rawValue
        dailyFeelingRitualDismissedMask |= ritual.rawValue
        latestFeelingRitualRaw = ritual.rawValue
        persistCare()
    }

    private func recordCareChestDismissal() {
        syncDailyCombo()
        guard let chest = PetCareChest(rawValue: cheerCareChestRaw) else { return }
        dailyCareChestOfferedMask |= chest.rawValue
        dailyCareChestDismissedMask |= chest.rawValue
        latestCareChestRaw = chest.rawValue
        persistCare()
    }

    private func recordFieldNoteDismissal() {
        syncDailyCombo()
        guard let note = PetFieldNote(rawValue: cheerFieldNoteRaw) else { return }
        dailyFieldNoteOfferedMask |= note.rawValue
        dailyFieldNoteDismissedMask |= note.rawValue
        latestFieldNoteRaw = note.rawValue
        persistCare()
    }

    private func recordAffectionDismissal() {
        syncDailyCombo()
        guard let gesture = PetAffectionGesture(rawValue: cheerAffectionRaw) else { return }
        dailyAffectionOfferedMask |= gesture.rawValue
        dailyAffectionDismissedMask |= gesture.rawValue
        latestAffectionRaw = gesture.rawValue
        persistCare()
    }

    private func recordHomeRoomDismissal() {
        syncDailyCombo()
        guard let room = PetHomeRoom(rawValue: cheerHomeRoomRaw) else { return }
        dailyHomeOfferedMask |= room.rawValue
        dailyHomeDismissedMask |= room.rawValue
        latestHomeRoomRaw = room.rawValue
        persistCare()
    }

    private func recordErrandDismissal() {
        syncDailyCombo()
        guard let errand = PetDailyErrand(rawValue: cheerErrandRaw) else { return }
        dailyErrandOfferedMask |= errand.rawValue
        dailyErrandDismissedMask |= errand.rawValue
        latestErrandRaw = errand.rawValue
        persistCare()
    }

    private func recordUserCheckDismissal() {
        syncDailyCombo()
        guard let checkIn = PetUserCheckIn(rawValue: cheerUserCheckRaw) else { return }
        dailyUserCheckOfferedMask |= checkIn.rawValue
        dailyUserCheckDismissedMask |= checkIn.rawValue
        latestUserCheckRaw = checkIn.rawValue
        persistCare()
    }

    private func recordWishDismissal() {
        syncDailyCombo()
        guard let wish = PetWish(rawValue: cheerWishRaw) else { return }
        dailyWishOfferedMask |= wish.rawValue
        dailyWishDismissedMask |= wish.rawValue
        latestWishRaw = wish.rawValue
        persistCare()
    }

    private func recordToyDismissal() {
        syncDailyCombo()
        guard let toy = PetToy(rawValue: cheerToyRaw) else { return }
        dailyToyOfferedMask |= toy.rawValue
        dailyToyDismissedMask |= toy.rawValue
        latestToyRaw = toy.rawValue
        persistCare()
    }

    private func recordTrickDismissal() {
        syncDailyCombo()
        guard let trick = PetTrick(rawValue: cheerTrickRaw) else { return }
        dailyTrickOfferedMask |= trick.rawValue
        dailyTrickDismissedMask |= trick.rawValue
        latestTrickRaw = trick.rawValue
        persistCare()
    }

    private func recordAmbientMoment(_ moment: PetAmbientMoment) -> String {
        syncDailyCombo()
        latestAmbientMomentRaw = moment.rawValue
        let seenToday = dailyAmbientMask & moment.rawValue != 0
        let seenEver = ambientAlbumMask & moment.rawValue != 0
        dailyAmbientMask |= moment.rawValue
        ambientAlbumMask |= moment.rawValue

        guard !seenToday else {
            persistCare()
            return "\(moment.title) passed by again. \(moment.line)"
        }

        let reward = seenEver ? 1 : moment.sparkReward
        sparkDust = min(999, sparkDust + reward)
        if !seenEver {
            happiness = min(5, happiness + 1)
        }
        var notes = ["\(moment.title): \(moment.line) Sparks +\(reward)\(!seenEver ? ", Joy +1" : "")."]
        if let vitalNote = refillVital(moment.vital, by: seenEver ? 1 : 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(moment.moodStep) {
            notes.append(moodCareNote)
        }
        persistCare()
        return notes.joined(separator: " ")
    }

    private func recordRouteStep(_ step: PetDailyRouteStep) -> String {
        syncDailyCombo()
        latestRouteStepRaw = step.rawValue
        let wasDone = dailyRouteMask & step.rawValue != 0
        let wasAlbumUnlocked = routeAlbumMask & step.rawValue != 0
        let wasComplete = isDailyRouteComplete
        dailyRouteOfferedMask |= step.rawValue
        dailyRouteDismissedMask &= ~step.rawValue
        dailyRouteMask |= step.rawValue
        routeAlbumMask |= step.rawValue

        guard !wasDone else {
            persistCare()
            return "\(step.title) is already on today's Spark Route. \(step.rewardLine)"
        }

        let reward = step.sparkReward + min(5, sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        let done = dailyRouteSteps.filter { dailyRouteMask & $0.rawValue != 0 }.count
        var notes = [
            "\(step.title) \(done)/\(dailyRouteSteps.count): \(step.actionLine). \(step.rewardLine) Joy +1, Sparks +\(reward)."
        ]
        if !wasAlbumUnlocked {
            notes.append("Route album unlocked: \(step.shortLabel).")
        }
        if let vitalNote = refillVital(step.vital, by: wasAlbumUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if !wasComplete, isDailyRouteComplete {
            companionHP = min(10, companionHP + 1)
            let completeReward = 24 + sparkLevel * 2
            sparkDust = min(999, sparkDust + completeReward)
            notes.append("Spark Route complete: Bond HP +1 and Sparks +\(completeReward).")
            if let charmNote = unlockCharm(.sparkRoute) {
                notes.append(charmNote)
            }
            play(.happy)
            setMood(.hyper, duration: 1.9)
        }

        persistCare()
        return notes.joined(separator: " ")
    }

    private func recordRouteAnswer() -> String? {
        guard let step = PetDailyRouteStep(rawValue: cheerRouteRaw) else { return nil }
        if let comboAction = step.comboAction {
            markCombo(comboAction)
        }
        recordDailyQuest(step.dailyQuest)
        let routeNote = recordRouteStep(step)
        if let moodCareNote = markMoodCare(step.moodStep) {
            return "\(routeNote) \(moodCareNote)"
        }
        return routeNote
    }

    private func recordRouteDismissal() {
        guard let step = PetDailyRouteStep(rawValue: cheerRouteRaw) else { return }
        dailyRouteOfferedMask |= step.rawValue
        dailyRouteDismissedMask |= step.rawValue
        latestRouteStepRaw = step.rawValue
        persistCare()
    }

    private func carePulseVital(from raw: Int) -> PetCareVital? {
        PetCareVital(rawValue: raw - 1)
    }

    private func recordCarePulseAnswer() -> String? {
        guard let vital = carePulseVital(from: cheerCareVitalRaw) else { return nil }
        return recordCarePulse(vital)
    }

    private func recordCarePulse(_ vital: PetCareVital) -> String {
        syncDailyCombo()
        let bit = vital.maskValue
        let wasAnswered = dailyCarePulseAnsweredMask & bit != 0
        let wasUnlocked = carePulseAlbumMask & bit != 0
        let wasComplete = PetCareVital.allCases.allSatisfy { dailyCarePulseAnsweredMask & $0.maskValue != 0 }
        dailyCarePulseOfferedMask |= bit
        dailyCarePulseAnsweredMask |= bit
        dailyCarePulseDismissedMask &= ~bit
        carePulseAlbumMask |= bit
        latestCarePulseRaw = vital.rawValue + 1

        guard !wasAnswered else {
            let smallReward = 2 + min(2, cheerLevel)
            sparkDust = min(999, sparkDust + smallReward)
            var notes = ["\(vital.pulseTitle) already answered today. \(vital.pulseRewardLine), Sparks +\(smallReward)."]
            if let vitalNote = refillVital(vital, by: 1) {
                notes.append(vitalNote)
            }
            persistCare()
            return notes.joined(separator: " ")
        }

        let reward = 10 + cheerLevel + min(4, sparkLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        var notes = [
            "\(vital.pulseTitle): \(vital.pulseBody) \(vital.pulseRewardLine). Joy +1, Sparks +\(reward)."
        ]
        if !wasUnlocked {
            notes.append("Care pulse album unlocked: \(vital.title).")
        }
        if let vitalNote = refillVital(vital, by: wasUnlocked ? 2 : 3) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(vital.moodStep) {
            notes.append(moodCareNote)
        }
        if !wasComplete, PetCareVital.allCases.allSatisfy({ dailyCarePulseAnsweredMask & $0.maskValue != 0 }) {
            companionHP = min(10, companionHP + 1)
            let completeReward = 20 + sparkLevel
            sparkDust = min(999, sparkDust + completeReward)
            notes.append("All care pulses answered today: Bond HP +1 and Sparks +\(completeReward).")
            if let charmNote = unlockCharm(.vitalGlow) {
                notes.append(charmNote)
            }
            play(.happy)
        }

        persistCare()
        setMood(vital.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private func recordCarePulseDismissal() {
        guard let vital = carePulseVital(from: cheerCareVitalRaw) else { return }
        dailyCarePulseOfferedMask |= vital.maskValue
        dailyCarePulseDismissedMask |= vital.maskValue
        latestCarePulseRaw = vital.rawValue + 1
        persistCare()
    }

    private func recordCareWindow(_ moment: PetCareMoment) -> String {
        syncDailyCombo()
        let wasComplete = isCareWindowSetComplete
        let wasDoneToday = dailyCareWindowMask & moment.rawValue != 0
        let wasAlbumUnlocked = careWindowAlbumMask & moment.rawValue != 0
        dailyCareWindowMask |= moment.rawValue
        careWindowAlbumMask |= moment.rawValue
        latestCareWindowRaw = moment.rawValue

        guard !wasDoneToday else {
            let smallReward = 2 + cheerLevel
            sparkDust = min(999, sparkDust + smallReward)
            happiness = min(5, happiness + 1)
            var notes = ["\(moment.title) window is already warm. \(moment.rewardLine) Joy +1, Sparks +\(smallReward)."]
            if let vitalNote = refillVital(moment.vital, by: 1) {
                notes.append(vitalNote)
            }
            persistCare()
            return notes.joined(separator: " ")
        }

        let done = PetCareMoment.count(mask: dailyCareWindowMask)
        let reward = 8 + cheerLevel + sparkLevel
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        var notes = [
            "\(moment.title) window \(done)/\(PetCareMoment.allCases.count): \(moment.actionLine). \(moment.rewardLine) Joy +1, Sparks +\(reward)."
        ]
        if !wasAlbumUnlocked {
            notes.append("Care window album unlocked: \(moment.shortLabel).")
        }
        if let vitalNote = refillVital(moment.vital, by: wasAlbumUnlocked ? 1 : 2) {
            notes.append(vitalNote)
        }
        if !wasComplete, isCareWindowSetComplete {
            companionHP = min(10, companionHP + 1)
            let completeReward = 28 + sparkLevel * 2
            sparkDust = min(999, sparkDust + completeReward)
            notes.append("All five care windows complete: Bond HP +1 and Sparks +\(completeReward).")
            if let charmNote = unlockCharm(.weeklyTrail) {
                notes.append(charmNote)
            }
            play(.happy)
            setMood(.hyper, duration: 1.9)
        }

        persistCare()
        return notes.joined(separator: " ")
    }

    private func markCombo(_ action: PetComboAction) {
        syncDailyCombo()
        let wasComplete = isDailyComboComplete
        dailyComboMask |= action.rawValue
        if !wasComplete, isDailyComboComplete {
            sparkDust = min(999, sparkDust + 25)
            happiness = min(5, happiness + 1)
            message += " Daily combo complete: Joy +1 and Sparks +25."
            play(.happy)
            setMood(.hyper, duration: 1.8)
        }
        persistCare()
    }

    private func recordDailyQuest(_ quest: PetDailyQuest) {
        syncDailyCombo()
        let wasComplete = isDailyQuestSetComplete
        guard dailyQuestMask & quest.rawValue == 0 else {
            persistCare()
            return
        }

        dailyQuestMask |= quest.rawValue
        let reward = 6 + questLevel + sparkLevel
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        message += " Task clear: \(quest.title) +\(reward) Sparks."
        if !wasComplete, isDailyQuestSetComplete {
            companionHP = min(10, companionHP + 1)
            sparkDust = min(999, sparkDust + 30)
            message += " Daily board complete: Bond HP +1 and Sparks +30."
            if let memoryNote = unlockMemory(.firstBoard) {
                message += " \(memoryNote)"
            }
            play(.happy)
            setMood(.hyper, duration: 1.8)
        }
        persistCare()
    }

    private func markBondContract(_ contract: PetBondContract) -> String? {
        syncDailyCombo()
        let wasComplete = isBondBoardComplete
        guard dailyBondBoardMask & contract.rawValue == 0 else {
            persistCare()
            return nil
        }

        dailyBondBoardMask |= contract.rawValue
        bondContractAlbumMask |= contract.rawValue
        let done = dailyBondContracts.filter { dailyBondBoardMask & $0.rawValue != 0 }.count
        let reward = contract.sparkReward + sparkLevel + cheerLevel
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = [
            "Bond Board: \(contract.shortLabel) \(done)/\(dailyBondContracts.count), Joy +1, Sparks +\(reward). \(contract.rewardLine)"
        ]

        if !wasComplete, isBondBoardComplete {
            companionHP = min(10, companionHP + 1)
            sparkDust = min(999, sparkDust + 35)
            notes.append("Bond Board complete: Bond HP +1 and Sparks +35.")
            if let memoryNote = unlockMemory(.firstBoard) {
                notes.append(memoryNote)
            }
            play(.happy)
            setMood(.hyper, duration: 1.8)
        }

        persistCare()
        return notes.joined(separator: " ")
    }

    private func unlockLifeScene(_ scene: PetLifeScene) -> String? {
        guard lifeSceneMask & scene.rawValue == 0 else { return nil }

        let wasStageComplete = isLifeSceneStageComplete
        lifeSceneMask |= scene.rawValue
        let reward = scene.sparkReward + sparkLevel
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)

        var notes = ["Life scene saved: \(scene.title), Joy +1, Sparks +\(reward)."]
        if !wasStageComplete, isLifeSceneStageComplete {
            sparkDust = min(999, sparkDust + scene.sparkReward)
            notes.append("\(scene.stage.title) life chapter complete: Sparks +\(scene.sparkReward).")
            play(.happy)
            setMood(.hyper, duration: 1.7)
        }

        persistCare()
        return notes.joined(separator: " ")
    }

    private func recordBondTimelineAnswer() -> String? {
        syncDailyCombo()
        guard let chapter = PetBondTimelineChapter(rawValue: cheerBondTimelineRaw) else { return nil }
        return saveBondTimelineChapter(chapter)
    }

    private func saveBondTimelineChapter(_ chapter: PetBondTimelineChapter) -> String? {
        syncDailyCombo()
        guard chapter.isEligible(
            companionHP: companionHP,
            sparkDust: sparkDust,
            streak: petStreak,
            stage: growthStage
        ) else {
            return "\(chapter.title) is still growing. Needs \(chapter.minimumStage.title), \(chapter.requiredHP) HP, \(chapter.requiredSparks) Sparks, and streak \(chapter.requiredStreak)."
        }

        let wasSaved = bondTimelineAlbumMask & chapter.rawValue != 0
        dailyBondTimelineOfferedMask |= chapter.rawValue
        dailyBondTimelineSavedMask |= chapter.rawValue
        dailyBondTimelineDismissedMask &= ~chapter.rawValue
        bondTimelineAlbumMask |= chapter.rawValue
        latestBondTimelineRaw = chapter.rawValue
        guard !wasSaved else {
            persistCare()
            return nil
        }

        let reward = chapter.sparkReward + min(6, sparkLevel + cheerLevel)
        sparkDust = min(999, sparkDust + reward)
        happiness = min(5, happiness + 1)
        var notes = ["Bond timeline saved: \(chapter.title). \(chapter.storyLine) Joy +1, Sparks +\(reward)."]
        if let vitalNote = refillVital(chapter.vital, by: 2) {
            notes.append(vitalNote)
        }
        if let moodCareNote = markMoodCare(chapter.moodStep) {
            notes.append(moodCareNote)
        }
        persistCare()
        setMood(chapter.mood, duration: 1.7)
        return notes.joined(separator: " ")
    }

    private var isDailyComboComplete: Bool {
        dailyComboActions.allSatisfy { dailyComboMask & $0.rawValue != 0 }
    }

    private var isDailyQuestSetComplete: Bool {
        dailyQuests.allSatisfy { dailyQuestMask & $0.rawValue != 0 }
    }

    private var isBondBoardComplete: Bool {
        dailyBondContracts.allSatisfy { dailyBondBoardMask & $0.rawValue != 0 }
    }

    private var isDailyRouteComplete: Bool {
        dailyRouteSteps.allSatisfy { dailyRouteMask & $0.rawValue != 0 }
    }

    private var isCareWindowSetComplete: Bool {
        PetCareMoment.allCases.allSatisfy { dailyCareWindowMask & $0.rawValue != 0 }
    }

    private var isLifeSceneStageComplete: Bool {
        currentLifeScenes.allSatisfy { lifeSceneMask & $0.rawValue != 0 }
    }

    private var nextUpgradeCandidate: PetUpgradeCandidate {
        [
            PetUpgradeCandidate(kind: .snack, level: snackLevel),
            PetUpgradeCandidate(kind: .lesson, level: lessonLevel),
            PetUpgradeCandidate(kind: .quest, level: questLevel),
            PetUpgradeCandidate(kind: .nest, level: nestLevel),
            PetUpgradeCandidate(kind: .cheer, level: cheerLevel),
            PetUpgradeCandidate(kind: .spark, level: sparkLevel),
            PetUpgradeCandidate(kind: .focus, level: focusLevel),
            PetUpgradeCandidate(kind: .cipher, level: cipherLevel)
        ].min { $0.cost < $1.cost } ?? PetUpgradeCandidate(kind: .snack, level: snackLevel)
    }

    private var dailyComboActions: [PetComboAction] {
        PetComboAction.dailyCombo(for: dailyComboDate.isEmpty ? Self.dayFormatter.string(from: Date()) : dailyComboDate)
    }

    private var dailyQuests: [PetDailyQuest] {
        PetDailyQuest.dailyDeck(for: dailyQuestDate.isEmpty ? Self.dayFormatter.string(from: Date()) : dailyQuestDate)
    }

    private var nextDailyQuest: PetDailyQuest? {
        dailyQuests.first { dailyQuestMask & $0.rawValue == 0 }
    }

    private var dailyBondContracts: [PetBondContract] {
        PetBondContract.dailyDeck(for: dailyBondBoardDate.isEmpty ? Self.dayFormatter.string(from: Date()) : dailyBondBoardDate)
    }

    private var nextBondContract: PetBondContract? {
        dailyBondContracts.first { dailyBondBoardMask & $0.rawValue == 0 }
    }

    private var dailyRouteSteps: [PetDailyRouteStep] {
        PetDailyRouteStep.dailyRoute(for: dailyRouteDate.isEmpty ? Self.dayFormatter.string(from: Date()) : dailyRouteDate)
    }

    private var nextRouteStep: PetDailyRouteStep? {
        dailyRouteSteps.first { dailyRouteMask & $0.rawValue == 0 }
    }

    private var nextFieldNote: PetFieldNote? {
        PetFieldNote.next(
            daypart: daypartNudge,
            feeling: petFeeling,
            stage: growthStage,
            offeredMask: dailyFieldNoteOfferedMask,
            index: PetFieldNote.count(mask: dailyFieldNoteOfferedMask)
                + PetFieldNote.count(mask: dailyFieldNoteSavedMask)
        )
    }

    private var nextFeelingRitual: PetFeelingRitual? {
        PetFeelingRitual.next(
            feeling: petFeeling,
            offeredMask: dailyFeelingRitualOfferedMask,
            index: PetFeelingRitual.count(mask: dailyFeelingRitualOfferedMask)
                + PetFeelingRitual.count(mask: feelingRitualAlbumMask)
        )
    }

    private var nextCareChest: PetCareChest? {
        PetCareChest.nextReady(
            claimedMask: dailyCareChestClaimedMask,
            offeredMask: dailyCareChestOfferedMask,
            hour: currentHour,
            careMoment: careMoment,
            lowestVital: lowestVital,
            comebackReady: canShowComebackNudge,
            energy: energy,
            index: PetCareChest.count(mask: dailyCareChestClaimedMask)
                + PetCareChest.count(mask: careChestAlbumMask),
            preferUnseen: false
        )
    }

    private var nextUnseenCareChest: PetCareChest? {
        PetCareChest.nextReady(
            claimedMask: dailyCareChestClaimedMask,
            offeredMask: dailyCareChestOfferedMask,
            hour: currentHour,
            careMoment: careMoment,
            lowestVital: lowestVital,
            comebackReady: canShowComebackNudge,
            energy: energy,
            index: PetCareChest.count(mask: dailyCareChestOfferedMask),
            preferUnseen: true
        )
    }

    private var nextScoutTrip: PetScoutTrip? {
        PetScoutTrip.next(
            daypart: daypartNudge,
            feeling: petFeeling,
            stage: growthStage,
            startedMask: dailyScoutTripStartedMask,
            index: PetScoutTrip.count(mask: dailyScoutTripStartedMask)
                + PetScoutTrip.count(mask: dailyScoutTripReturnedMask)
        )
    }

    private var nextWish: PetWish? {
        PetWish.next(
            daypart: daypartNudge,
            feeling: petFeeling,
            careNeed: careNeed,
            stage: growthStage,
            offeredMask: dailyWishOfferedMask,
            index: PetWish.count(mask: dailyWishOfferedMask)
                + PetWish.count(mask: dailyWishFulfilledMask)
        )
    }

    private var nextAffectionGesture: PetAffectionGesture? {
        PetAffectionGesture.next(
            daypart: daypartNudge,
            feeling: petFeeling,
            careNeed: careNeed,
            stage: growthStage,
            offeredMask: dailyAffectionOfferedMask,
            givenMask: dailyAffectionGivenMask,
            index: PetAffectionGesture.count(mask: dailyAffectionOfferedMask)
                + PetAffectionGesture.count(mask: dailyAffectionGivenMask)
        )
    }

    private var nextHomeRoom: PetHomeRoom? {
        PetHomeRoom.next(
            hour: currentHour,
            feeling: petFeeling,
            careNeed: careNeed,
            offeredMask: dailyHomeOfferedMask,
            visitedMask: dailyHomeVisitedMask,
            index: PetHomeRoom.count(mask: dailyHomeOfferedMask)
                + PetHomeRoom.count(mask: dailyHomeVisitedMask)
        )
    }

    private var nextDailyErrand: PetDailyErrand? {
        PetDailyErrand.next(
            hour: currentHour,
            feeling: petFeeling,
            careNeed: careNeed,
            offeredMask: dailyErrandOfferedMask,
            doneMask: dailyErrandDoneMask,
            index: PetDailyErrand.count(mask: dailyErrandOfferedMask)
                + PetDailyErrand.count(mask: dailyErrandDoneMask)
        )
    }

    private var nextUserCheckIn: PetUserCheckIn? {
        PetUserCheckIn.next(
            daypart: daypartNudge,
            feeling: petFeeling,
            careNeed: careNeed,
            offeredMask: dailyUserCheckOfferedMask,
            answeredMask: dailyUserCheckAnsweredMask,
            index: PetUserCheckIn.count(mask: dailyUserCheckOfferedMask)
                + PetUserCheckIn.count(mask: dailyUserCheckAnsweredMask)
        )
    }

    private var nextToy: PetToy? {
        PetToy.next(
            daypart: daypartNudge,
            feeling: petFeeling,
            careNeed: careNeed,
            playedMask: dailyToyPlayedMask,
            index: PetToy.count(mask: dailyToyOfferedMask)
                + PetToy.count(mask: dailyToyPlayedMask)
        )
    }

    private var nextTrick: PetTrick? {
        PetTrick.next(
            stage: growthStage,
            feeling: petFeeling,
            careNeed: careNeed,
            practicedMask: dailyTrickPracticedMask,
            index: PetTrick.count(mask: dailyTrickOfferedMask)
                + PetTrick.count(mask: dailyTrickPracticedMask)
        )
    }

    private var nextLifeScene: PetLifeScene? {
        currentLifeScenes.first { lifeSceneMask & $0.rawValue == 0 }
    }

    private var nextBondTimelineChapter: PetBondTimelineChapter? {
        PetBondTimelineChapter.next(
            albumMask: bondTimelineAlbumMask,
            offeredMask: dailyBondTimelineOfferedMask,
            companionHP: companionHP,
            sparkDust: sparkDust,
            streak: petStreak,
            stage: growthStage,
            index: PetBondTimelineChapter.count(mask: bondTimelineAlbumMask)
                + PetBondTimelineChapter.count(mask: dailyBondTimelineSavedMask),
            preferUnseen: false
        )
    }

    private var nextUnseenBondTimelineChapter: PetBondTimelineChapter? {
        PetBondTimelineChapter.next(
            albumMask: bondTimelineAlbumMask,
            offeredMask: dailyBondTimelineOfferedMask,
            companionHP: companionHP,
            sparkDust: sparkDust,
            streak: petStreak,
            stage: growthStage,
            index: PetBondTimelineChapter.count(mask: dailyBondTimelineOfferedMask),
            preferUnseen: true
        )
    }

    private var dailyCipher: PetDailyCipher {
        PetDailyCipher.daily(
            for: dailyCipherDate.isEmpty ? Self.dayFormatter.string(from: Date()) : dailyCipherDate,
            cipherLevel: cipherLevel
        )
    }

    private var effectiveCheerCooldown: TimeInterval {
        max(8 * 60, Self.cheerCooldownSeconds - Double(min(6, cheerLevel)) * 6 * 60)
    }

    private func rechargeEnergy() {
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastEnergyAt
        guard elapsed >= Self.energyRechargeSeconds else { return }
        let restored = Int(elapsed / Self.energyRechargeSeconds)
        guard restored > 0 else { return }
        energy = min(Self.maxEnergy, energy + restored)
        lastEnergyAt += Double(restored) * Self.energyRechargeSeconds
        if energy == Self.maxEnergy {
            lastEnergyAt = now
        }
        persistCare()
    }

    private func startEnergyLoop() {
        energyTask?.cancel()
        energyTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    self?.syncDailyCombo()
                    self?.rechargeEnergy()
                    self?.applyVitalDecay()
                    self?.applyLifecycleCatchup(reason: "timer")
                    _ = self?.collectPassiveSparks()
                }
            }
        }
    }

    private func startHealthLoop() {
        healthTask?.cancel()
        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.healthDecaySeconds * 1_000_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    self?.decayCompanionHealth()
                }
            }
        }
    }

    private func decayCompanionHealth() {
        let next = max(0, companionHealth - Self.healthDecayAmount)
        guard next != companionHealth else { return }
        companionHealth = next
        UserDefaults.standard.set(companionHealth, forKey: Self.companionHealthKey)
    }

    private func awardCompanionHealth(_ amount: Int) {
        let next = min(Self.maxCompanionHealth, max(0, companionHealth + amount))
        guard next != companionHealth else { return }
        companionHealth = next
        UserDefaults.standard.set(companionHealth, forKey: Self.companionHealthKey)
    }

    private func startCheerLoop() {
        cheerTask?.cancel()
        cheerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            while !Task.isCancelled {
                await MainActor.run {
                    guard self?.showWellnessBreakIfReady() != true else { return }
                    self?.showCheerIfReady()
                }
                try? await Task.sleep(nanoseconds: 5 * 60_000_000_000)
            }
        }
    }

    private func startAmbientLoop() {
        ambientTask?.cancel()
        ambientTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            while !Task.isCancelled {
                await MainActor.run {
                    guard self?.showWellnessBreakIfReady() != true else { return }
                    self?.showAmbientMomentIfReady()
                }
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private func scheduleScoutTripReturnCheck() {
        scoutTripTask?.cancel()
        guard let remaining = scoutTripRemainingSeconds else { return }
        scoutTripTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(1, remaining)) * 1_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                self?.showCheerIfReady()
            }
        }
    }

    private func showAmbientMomentIfReady() {
        syncDailyCombo()
        guard cheerBubble == nil, !busy, learningMode == .chat, mood == .idle else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastAmbientAt >= Self.ambientCooldownSeconds else { return }

        let index = PetAmbientMoment.count(mask: dailyAmbientMask) + PetAmbientMoment.count(mask: ambientAlbumMask)
        let moment = PetAmbientMoment.next(
            dailyMask: dailyAmbientMask,
            lowestVital: lowestVital,
            hour: currentHour,
            index: index
        )
        lastAmbientAt = now
        lastRequest = "Ambient"
        message = pikaText(recordAmbientMoment(moment))
        appendEmotionScene(trigger: "ambient")
        persistCare()
        setMood(moment.mood, duration: 2.6)
    }

    @discardableResult
    private func showWellnessBreakIfReady() -> Bool {
        syncDailyCombo()
        guard !launchQuietPeriodActive else { return false }
        guard minimized, cheerBubble == nil, !busy, learningMode == .chat else { return false }
        let now = Date().timeIntervalSince1970
        guard now - lastWellnessBreakAt >= Self.wellnessBreakSeconds else { return false }

        guard let action = nextIncompleteDailyWellnessAction else { return false }
        cheerTitle = action.title
        cheerAction = action.actionTitle
        cheerRewardLine = "Health +1"
        cheerIntentRaw = PetCheerIntent.care.rawValue
        cheerWellnessBreakActive = true
        cheerWellnessActionRaw = action.rawValue
        lastRequest = action.title
        let body = "Hey, it has been two hours. \(action.question) One tiny check-in, then I will cheer."
        cheerBubble = pikaText(body)
        message = cheerBubble ?? body
        lastWellnessBreakAt = now
        UserDefaults.standard.set(now, forKey: Self.lastWellnessBreakAtKey)
        UserDefaults.standard.set(now, forKey: Self.lastCheerAtKey)
        setMood(action.mood, duration: 2.4)
        return true
    }

    private func showCheerIfReady() {
        syncDailyCombo()
        guard !launchQuietPeriodActive else { return }
        guard minimized, cheerBubble == nil else { return }
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        let lastCheerAt = defaults.double(forKey: Self.lastCheerAtKey)
        let activeScoutTrip = PetScoutTrip(rawValue: activeScoutTripRaw)
        let shouldUseScoutReturn = activeScoutTrip != nil && (scoutTripRemainingSeconds ?? 1) == 0
        let activeWheel = activeSparkWheelCycle
        let shouldUseSparkWheelClaim = !shouldUseScoutReturn
            && activeWheel != nil
            && (sparkWheelRemainingSeconds ?? 1) == 0
        let journey = dailyJourneyPhase
        let shouldUseJourney = !shouldUseScoutReturn && !shouldUseSparkWheelClaim && dailyJourneyOfferedMask & journey.rawValue == 0
        let daypart = daypartNudge
        let shouldUseDaypart = !shouldUseScoutReturn && !shouldUseSparkWheelClaim && !shouldUseJourney && dailyNudgeOfferedMask & daypart.rawValue == 0
        let nextVisit = nextVisitBeat
        let shouldUseVisit = !shouldUseScoutReturn
            && !shouldUseSparkWheelClaim
            && !shouldUseJourney
            && !shouldUseDaypart
            && nextVisit != nil
            && (dailyVisitOfferedMask & (nextVisit?.rawValue ?? 0)) == 0
        let nextWheel = nextSparkWheelCycle
        let shouldUseSparkWheelStart = !shouldUseScoutReturn
            && !shouldUseSparkWheelClaim
            && !shouldUseJourney
            && !shouldUseDaypart
            && !shouldUseVisit
            && activeWheel == nil
            && nextWheel != nil
            && (dailySparkWheelOfferedMask & (nextWheel?.rawValue ?? 0)) == 0
        let nextRoute = nextRouteStep
        let shouldUseRoute = !shouldUseScoutReturn
            && !shouldUseSparkWheelClaim
            && !shouldUseJourney
            && !shouldUseDaypart
            && !shouldUseVisit
            && !shouldUseSparkWheelStart
            && nextRoute != nil
            && (dailyRouteOfferedMask & (nextRoute?.rawValue ?? 0)) == 0
        let nextCarePulse = nextUnofferedCarePulseVital
        let shouldUseCarePulse = !shouldUseScoutReturn
            && !shouldUseSparkWheelClaim
            && !shouldUseJourney
            && !shouldUseDaypart
            && !shouldUseVisit
            && !shouldUseSparkWheelStart
            && !shouldUseRoute
            && nextCarePulse != nil
        let nextPing = nextCheerPing
        let shouldUseCheerPing = !shouldUseScoutReturn
            && !shouldUseSparkWheelClaim
            && !shouldUseJourney
            && !shouldUseDaypart
            && !shouldUseVisit
            && !shouldUseSparkWheelStart
            && !shouldUseRoute
            && !shouldUseCarePulse
            && nextPing != nil
        let nextExchange = nextExchangeBoardStep
        let shouldUseExchange = !shouldUseScoutReturn
            && !shouldUseSparkWheelClaim
            && !shouldUseJourney
            && !shouldUseDaypart
            && !shouldUseVisit
            && !shouldUseSparkWheelStart
            && !shouldUseRoute
            && !shouldUseCarePulse
            && !shouldUseCheerPing
            && nextExchange != nil
            && (dailyExchangeOfferedMask & (nextExchange?.rawValue ?? 0)) == 0
        let index = defaults.integer(forKey: Self.cheerIndexKey)
        let nextChest = nextUnseenCareChest
        let shouldUseCareChest = !shouldUseScoutReturn
            && !shouldUseSparkWheelClaim
            && !shouldUseJourney
            && !shouldUseDaypart
            && !shouldUseVisit
            && !shouldUseSparkWheelStart
            && !shouldUseRoute
            && !shouldUseCarePulse
            && !shouldUseCheerPing
            && !shouldUseExchange
            && nextChest != nil
            && (dailyCareChestOfferedMask & (nextChest?.rawValue ?? 0)) == 0
        let nextTimeline = nextUnseenBondTimelineChapter
        let shouldUseBondTimeline = !shouldUseScoutReturn
            && !shouldUseSparkWheelClaim
            && !shouldUseJourney
            && !shouldUseDaypart
            && !shouldUseVisit
            && !shouldUseSparkWheelStart
            && !shouldUseRoute
            && !shouldUseCarePulse
            && !shouldUseCheerPing
            && !shouldUseExchange
            && !shouldUseCareChest
            && nextTimeline != nil
            && (dailyBondTimelineOfferedMask & (nextTimeline?.rawValue ?? 0)) == 0
        guard shouldUseScoutReturn || shouldUseSparkWheelClaim || shouldUseJourney || shouldUseDaypart || shouldUseVisit || shouldUseSparkWheelStart || shouldUseRoute || shouldUseCarePulse || shouldUseCheerPing || shouldUseExchange || shouldUseCareChest || shouldUseBondTimeline || lastCheerAt == 0 || now - lastCheerAt >= effectiveCheerCooldown else { return }

        let nextMoodStory = PetMoodStory.next(
            feeling: petFeeling,
            careMoment: careMoment,
            stage: growthStage,
            offeredMask: dailyMoodStoryOfferedMask,
            index: index
        )
        let nextFeelingRitual = PetFeelingRitual.next(
            feeling: petFeeling,
            offeredMask: dailyFeelingRitualOfferedMask,
            index: index
        )
        let nextFieldNote = PetFieldNote.next(
            daypart: daypart,
            feeling: petFeeling,
            stage: growthStage,
            offeredMask: dailyFieldNoteOfferedMask,
            index: index
        )
        let nextAffection = PetAffectionGesture.next(
            daypart: daypart,
            feeling: petFeeling,
            careNeed: careNeed,
            stage: growthStage,
            offeredMask: dailyAffectionOfferedMask,
            givenMask: dailyAffectionGivenMask,
            index: index
        )
        let nextHomeRoom = PetHomeRoom.next(
            hour: currentHour,
            feeling: petFeeling,
            careNeed: careNeed,
            offeredMask: dailyHomeOfferedMask,
            visitedMask: dailyHomeVisitedMask,
            index: index
        )
        let nextErrand = PetDailyErrand.next(
            hour: currentHour,
            feeling: petFeeling,
            careNeed: careNeed,
            offeredMask: dailyErrandOfferedMask,
            doneMask: dailyErrandDoneMask,
            index: index
        )
        let nextUserCheck = PetUserCheckIn.next(
            daypart: daypart,
            feeling: petFeeling,
            careNeed: careNeed,
            offeredMask: dailyUserCheckOfferedMask,
            answeredMask: dailyUserCheckAnsweredMask,
            index: index
        )
        let nextWish = PetWish.next(
            daypart: daypart,
            feeling: petFeeling,
            careNeed: careNeed,
            stage: growthStage,
            offeredMask: dailyWishOfferedMask,
            index: index
        )
        let nextToy = PetToy.next(
            daypart: daypart,
            feeling: petFeeling,
            careNeed: careNeed,
            playedMask: dailyToyPlayedMask,
            index: index
        )
        let nextTrick = PetTrick.next(
            stage: growthStage,
            feeling: petFeeling,
            careNeed: careNeed,
            practicedMask: dailyTrickPracticedMask,
            index: index
        )
        let canUseSecondaryCheer = !shouldUseScoutReturn && !shouldUseSparkWheelClaim && !shouldUseJourney && !shouldUseDaypart && !shouldUseVisit && !shouldUseSparkWheelStart && !shouldUseRoute && !shouldUseCarePulse && !shouldUseCheerPing && !shouldUseExchange && !shouldUseCareChest && !shouldUseBondTimeline
        let shouldUseUserCheck = canUseSecondaryCheer && nextUserCheck != nil && (index % 3 == 0 || petFeeling == .lonely || petFeeling == .restless || petFeeling == .focused)
        let shouldUseErrand = canUseSecondaryCheer && !shouldUseUserCheck && nextErrand != nil && (careNeed == .adventure || petFeeling == .curious || index % 7 == 1)
        let shouldUseAffection = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && nextAffection != nil && (careNeed == .affection || index % 5 == 0)
        let shouldUseHome = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && nextHomeRoom != nil && index % 6 == 2
        let shouldUseWish = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && nextWish != nil && index % 4 == 0
        let shouldUseToy = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && !shouldUseWish && nextToy != nil && index % 5 == 2
        let shouldUseTrick = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && !shouldUseWish && !shouldUseToy && nextTrick != nil && index % 6 == 4
        let shouldUseMoodStory = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && !shouldUseWish && !shouldUseToy && !shouldUseTrick && nextMoodStory != nil && index % 3 == 1
        let feelingRitualUrgent: Bool = {
            switch petFeeling {
            case .lonely, .comfort, .restless, .overcharged, .sleepy, .hungry:
                return true
            default:
                return false
            }
        }()
        let shouldUseFeelingRitual = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && nextFeelingRitual != nil && (feelingRitualUrgent || index % 4 == 2)
        let shouldUseFieldNote = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && !shouldUseFeelingRitual && nextFieldNote != nil && index % 4 == 3
        let nextMoodCareStep = moodCareRecipe.nextStep(mask: dailyMoodCareMask)
        let shouldUseMoodCare = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && !shouldUseFieldNote && nextMoodCareStep != nil && index % 2 == 0
        let nextContract = nextBondContract
        let shouldUseBondBoard = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && !shouldUseFieldNote && !shouldUseMoodCare && nextContract != nil && index % 3 == 2
        let nextDialogue = PetCheerDialogue.next(offeredMask: dailyCheerDialogueOfferedMask, index: index)
        let nextScript = PetCheerScript.next(
            daypart: daypart,
            intent: shouldUseFieldNote ? .fieldNote : (shouldUseErrand ? .quest : (shouldUseUserCheck ? .checkIn : (shouldUseAffection || shouldUseHome || shouldUseWish || shouldUseToy || shouldUseTrick ? .care : (shouldUseFeelingRitual ? (nextFeelingRitual?.intent ?? .feeling) : (nextMoodStory?.intent ?? nextDialogue?.intent ?? .checkIn))))),
            offeredMask: dailyCheerScriptOfferedMask,
            index: index
        )
        let shouldUseScript = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && !shouldUseFeelingRitual && !shouldUseFieldNote && !shouldUseMoodCare && !shouldUseBondBoard && nextScript != nil && (index % 2 == 1 || nextDialogue == nil)
        let shouldUseDialogue = canUseSecondaryCheer && !shouldUseUserCheck && !shouldUseErrand && !shouldUseAffection && !shouldUseHome && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && !shouldUseFieldNote && !shouldUseMoodCare && !shouldUseBondBoard && !shouldUseScript && nextDialogue != nil
        let prompt: PetNudgeLibrary.PetCheerPrompt
        if shouldUseScoutReturn, let activeScoutTrip {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: "Scout Returned",
                body: "\(activeScoutTrip.title) came back with a tiny desktop report. Want to collect it?",
                action: "Collect Scout",
                rewardLine: "\(activeScoutTrip.title) returned",
                intent: .quest
            )
        } else if shouldUseSparkWheelClaim, let activeWheel {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: "Spark Wheel Ready",
                body: "\(activeWheel.title) is full. \(activeWheel.returnLine(stage: growthStage, feeling: petFeeling)) Want to collect the pouch?",
                action: "Collect Wheel",
                rewardLine: activeWheel.rewardLine,
                intent: .boost
            )
        } else if shouldUseJourney {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: journey.title,
                body: journey.body,
                action: journey.action,
                rewardLine: journey.rewardLine,
                intent: journey.intent
            )
        } else if shouldUseDaypart {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: daypart.title,
                body: daypart.body,
                action: daypart.action,
                rewardLine: daypart.rewardLine
            )
        } else if shouldUseVisit, let nextVisit {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextVisit.title,
                body: nextVisit.body(stage: growthStage, feeling: petFeeling, careNeed: careNeed),
                action: nextVisit.action,
                rewardLine: nextVisit.rewardLine,
                intent: nextVisit.intent
            )
        } else if shouldUseSparkWheelStart, let nextWheel {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextWheel.title,
                body: nextWheel.startLine(stage: growthStage, feeling: petFeeling),
                action: nextWheel.action,
                rewardLine: "\(nextWheel.title) started",
                intent: .boost
            )
        } else if shouldUseRoute, let nextRoute {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: "Spark Route",
                body: "\(nextRoute.title) is ready on today's care route. \(nextRoute.actionLine).",
                action: nextRoute.shortLabel,
                rewardLine: "\(nextRoute.title) route step answered",
                intent: nextRoute.cheerIntent
            )
        } else if shouldUseCarePulse, let nextCarePulse {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextCarePulse.pulseTitle,
                body: nextCarePulse.pulseBody,
                action: nextCarePulse.pulseAction,
                rewardLine: nextCarePulse.pulseRewardLine,
                intent: .care
            )
        } else if shouldUseCheerPing, let nextPing {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextPing.title,
                body: nextPing.body(stage: growthStage, feeling: petFeeling),
                action: nextPing.action,
                rewardLine: nextPing.rewardLine,
                intent: nextPing.intent
            )
        } else if shouldUseExchange, let nextExchange {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: "Spark Exchange",
                body: nextExchange.body,
                action: nextExchange.action,
                rewardLine: nextExchange.rewardLine,
                intent: nextExchange.intent
            )
        } else if shouldUseCareChest, let nextChest {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextChest.title,
                body: nextChest.body(stage: growthStage, feeling: petFeeling),
                action: nextChest.action,
                rewardLine: nextChest.rewardLine,
                intent: .care
            )
        } else if shouldUseBondTimeline, let nextTimeline {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextTimeline.title,
                body: nextTimeline.body(stage: growthStage),
                action: nextTimeline.action,
                rewardLine: nextTimeline.rewardLine,
                intent: .feeling
            )
        } else if shouldUseUserCheck, let nextUserCheck {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextUserCheck.title,
                body: nextUserCheck.body(stage: growthStage, feeling: petFeeling),
                action: nextUserCheck.action,
                rewardLine: "\(nextUserCheck.title) answered",
                intent: .checkIn
            )
        } else if shouldUseErrand, let nextErrand {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextErrand.title,
                body: "Errand board is ready: \(nextErrand.runLine(stage: growthStage, feeling: petFeeling))",
                action: nextErrand.action,
                rewardLine: "\(nextErrand.title) complete",
                intent: .quest
            )
        } else if shouldUseAffection, let nextAffection {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextAffection.title,
                body: "Bond care wants \(nextAffection.title). \(nextAffection.careLine(stage: growthStage, feeling: petFeeling))",
                action: nextAffection.action,
                rewardLine: "\(nextAffection.title) given",
                intent: .care
            )
        } else if shouldUseHome, let nextHomeRoom {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextHomeRoom.title,
                body: "Home room is ready: \(nextHomeRoom.visitLine(stage: growthStage, feeling: petFeeling))",
                action: nextHomeRoom.action,
                rewardLine: "\(nextHomeRoom.title) visited",
                intent: .care
            )
        } else if shouldUseWish, let nextWish {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextWish.title,
                body: nextWish.body(stage: growthStage, feeling: petFeeling),
                action: nextWish.action,
                rewardLine: "\(nextWish.title) fulfilled",
                intent: .care
            )
        } else if shouldUseToy, let nextToy {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextToy.title,
                body: "Toybox wants \(nextToy.title). \(nextToy.playLine(stage: growthStage, feeling: petFeeling))",
                action: nextToy.action,
                rewardLine: "\(nextToy.title) played",
                intent: .care
            )
        } else if shouldUseTrick, let nextTrick {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextTrick.title,
                body: "Trickbook wants practice. \(nextTrick.performLine(stage: growthStage, feeling: petFeeling))",
                action: nextTrick.action,
                rewardLine: "\(nextTrick.title) practiced",
                intent: .care
            )
        } else if shouldUseMoodStory, let nextMoodStory {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextMoodStory.title,
                body: nextMoodStory.body(stage: growthStage),
                action: nextMoodStory.action,
                rewardLine: nextMoodStory.rewardLine,
                intent: nextMoodStory.intent
            )
        } else if shouldUseFeelingRitual, let nextFeelingRitual {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextFeelingRitual.title,
                body: nextFeelingRitual.body(stage: growthStage),
                action: nextFeelingRitual.action,
                rewardLine: nextFeelingRitual.rewardLine,
                intent: nextFeelingRitual.intent
            )
        } else if shouldUseFieldNote, let nextFieldNote {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextFieldNote.title,
                body: nextFieldNote.body(stage: growthStage, feeling: petFeeling),
                action: nextFieldNote.action,
                rewardLine: "\(nextFieldNote.title) saved",
                intent: .fieldNote
            )
        } else if shouldUseMoodCare, let nextMoodCareStep {
            prompt = PetNudgeLibrary.moodCarePrompt(
                feeling: moodCareFeeling,
                recipe: moodCareRecipe,
                step: nextMoodCareStep,
                stage: growthStage
            )
        } else if shouldUseBondBoard, let nextContract {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: "Bond Board",
                body: "\(nextContract.title) is ready. Want to \(nextContract.actionLine)?",
                action: "Open \(nextContract.shortLabel)",
                rewardLine: "\(nextContract.title) answered",
                intent: .board
            )
        } else if shouldUseScript, let nextScript {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextScript.title,
                body: nextScript.body,
                action: nextScript.action,
                rewardLine: nextScript.rewardLine,
                intent: nextScript.intent
            )
        } else if shouldUseDialogue, let nextDialogue {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: nextDialogue.title,
                body: nextDialogue.body,
                action: nextDialogue.action,
                rewardLine: nextDialogue.rewardLine,
                intent: nextDialogue.intent
            )
        } else {
            prompt = PetNudgeLibrary.cheerPrompt(
                feeling: petFeeling,
                stage: growthStage,
                combo: dailyComboActions,
                comboMask: dailyComboMask,
                nextQuest: nextDailyQuest,
                cipher: dailyCipher,
                cipherSolved: dailyCipherSolved,
                boosterReady: !dailyBoosterUsed,
                careMoment: careMoment,
                careNeed: careNeed,
                seasonEvent: dailyEvent,
                eventProgress: dailyEventProgress,
                comebackReady: canShowComebackNudge,
                energy: energy,
                sparkDust: sparkDust,
                index: index
            )
        }
        cheerTitle = prompt.title
        cheerAction = prompt.action
        cheerRewardLine = prompt.rewardLine
        cheerJourneyRaw = shouldUseJourney ? journey.rawValue : 0
        cheerVisitRaw = shouldUseVisit ? (nextVisit?.rawValue ?? 0) : 0
        cheerSparkWheelRaw = shouldUseSparkWheelClaim
            ? (activeWheel?.rawValue ?? 0)
            : (shouldUseSparkWheelStart ? (nextWheel?.rawValue ?? 0) : 0)
        cheerRouteRaw = shouldUseRoute ? (nextRoute?.rawValue ?? 0) : 0
        cheerCareVitalRaw = shouldUseCarePulse ? (nextCarePulse?.rawValue ?? -1) + 1 : 0
        cheerPingRaw = shouldUseCheerPing ? (nextPing?.rawValue ?? 0) : 0
        cheerExchangeRaw = shouldUseExchange ? (nextExchange?.rawValue ?? 0) : 0
        cheerDaypartRaw = shouldUseDaypart ? daypart.rawValue : 0
        cheerMoodCareStepRaw = shouldUseMoodCare ? (nextMoodCareStep?.rawValue ?? 0) : 0
        cheerBondContractRaw = shouldUseBondBoard ? (nextContract?.rawValue ?? 0) : 0
        cheerBondTimelineRaw = shouldUseBondTimeline ? (nextTimeline?.rawValue ?? 0) : 0
        cheerDialogueRaw = shouldUseDialogue ? (nextDialogue?.rawValue ?? 0) : 0
        cheerScriptRaw = shouldUseScript ? (nextScript?.rawValue ?? 0) : 0
        cheerMoodStoryRaw = shouldUseMoodStory ? (nextMoodStory?.rawValue ?? 0) : 0
        cheerFeelingRitualRaw = shouldUseFeelingRitual ? (nextFeelingRitual?.rawValue ?? 0) : 0
        cheerCareChestRaw = shouldUseCareChest ? (nextChest?.rawValue ?? 0) : 0
        cheerFieldNoteRaw = shouldUseFieldNote ? (nextFieldNote?.rawValue ?? 0) : 0
        cheerScoutTripRaw = shouldUseScoutReturn ? (activeScoutTrip?.rawValue ?? 0) : 0
        cheerAffectionRaw = shouldUseAffection ? (nextAffection?.rawValue ?? 0) : 0
        cheerHomeRoomRaw = shouldUseHome ? (nextHomeRoom?.rawValue ?? 0) : 0
        cheerErrandRaw = shouldUseErrand ? (nextErrand?.rawValue ?? 0) : 0
        cheerUserCheckRaw = shouldUseUserCheck ? (nextUserCheck?.rawValue ?? 0) : 0
        cheerWishRaw = shouldUseWish ? (nextWish?.rawValue ?? 0) : 0
        cheerToyRaw = shouldUseToy ? (nextToy?.rawValue ?? 0) : 0
        cheerTrickRaw = shouldUseTrick ? (nextTrick?.rawValue ?? 0) : 0
        cheerIntentRaw = prompt.intent.rawValue
        cheerWellnessBreakActive = false
        cheerBubble = pikaText(prompt.body)
        dailyCheerIntentOfferedMask |= prompt.intent.rawValue
        dailyCheerIntentDismissedMask &= ~prompt.intent.rawValue
        if shouldUseScoutReturn, let activeScoutTrip {
            latestScoutTripRaw = activeScoutTrip.rawValue
            persistCare()
        } else if shouldUseJourney {
            dailyJourneyOfferedMask |= journey.rawValue
            dailyJourneyDismissedMask &= ~journey.rawValue
            latestJourneyRaw = journey.rawValue
            persistCare()
        } else if shouldUseDaypart {
            dailyNudgeOfferedMask |= daypart.rawValue
            dailyNudgeDismissedMask &= ~daypart.rawValue
            persistCare()
        } else if shouldUseVisit, let nextVisit {
            dailyVisitOfferedMask |= nextVisit.rawValue
            dailyVisitDismissedMask &= ~nextVisit.rawValue
            latestVisitRaw = nextVisit.rawValue
            persistCare()
        } else if shouldUseSparkWheelClaim, let activeWheel {
            dailySparkWheelOfferedMask |= activeWheel.rawValue
            latestSparkWheelRaw = activeWheel.rawValue
            persistCare()
        } else if shouldUseSparkWheelStart, let nextWheel {
            dailySparkWheelOfferedMask |= nextWheel.rawValue
            dailySparkWheelDismissedMask &= ~nextWheel.rawValue
            latestSparkWheelRaw = nextWheel.rawValue
            persistCare()
        } else if shouldUseRoute, let nextRoute {
            dailyRouteOfferedMask |= nextRoute.rawValue
            dailyRouteDismissedMask &= ~nextRoute.rawValue
            latestRouteStepRaw = nextRoute.rawValue
            persistCare()
        } else if shouldUseCarePulse, let nextCarePulse {
            dailyCarePulseOfferedMask |= nextCarePulse.maskValue
            dailyCarePulseDismissedMask &= ~nextCarePulse.maskValue
            latestCarePulseRaw = nextCarePulse.rawValue + 1
            persistCare()
        } else if shouldUseCheerPing, let nextPing {
            dailyCheerPingOfferedMask |= nextPing.rawValue
            dailyCheerPingDismissedMask &= ~nextPing.rawValue
            latestCheerPingRaw = nextPing.rawValue
            persistCare()
        } else if shouldUseExchange, let nextExchange {
            dailyExchangeOfferedMask |= nextExchange.rawValue
            dailyExchangeDismissedMask &= ~nextExchange.rawValue
            latestExchangeRaw = nextExchange.rawValue
            persistCare()
        } else if shouldUseCareChest, let nextChest {
            dailyCareChestOfferedMask |= nextChest.rawValue
            dailyCareChestDismissedMask &= ~nextChest.rawValue
            latestCareChestRaw = nextChest.rawValue
            persistCare()
        } else if shouldUseBondTimeline, let nextTimeline {
            dailyBondTimelineOfferedMask |= nextTimeline.rawValue
            dailyBondTimelineDismissedMask &= ~nextTimeline.rawValue
            latestBondTimelineRaw = nextTimeline.rawValue
            persistCare()
        } else if shouldUseAffection, let nextAffection {
            dailyAffectionOfferedMask |= nextAffection.rawValue
            dailyAffectionDismissedMask &= ~nextAffection.rawValue
            latestAffectionRaw = nextAffection.rawValue
            persistCare()
        } else if shouldUseHome, let nextHomeRoom {
            dailyHomeOfferedMask |= nextHomeRoom.rawValue
            dailyHomeDismissedMask &= ~nextHomeRoom.rawValue
            latestHomeRoomRaw = nextHomeRoom.rawValue
            persistCare()
        } else if shouldUseErrand, let nextErrand {
            dailyErrandOfferedMask |= nextErrand.rawValue
            dailyErrandDismissedMask &= ~nextErrand.rawValue
            latestErrandRaw = nextErrand.rawValue
            persistCare()
        } else if shouldUseUserCheck, let nextUserCheck {
            dailyUserCheckOfferedMask |= nextUserCheck.rawValue
            dailyUserCheckDismissedMask &= ~nextUserCheck.rawValue
            latestUserCheckRaw = nextUserCheck.rawValue
            persistCare()
        } else if shouldUseWish, let nextWish {
            dailyWishOfferedMask |= nextWish.rawValue
            dailyWishDismissedMask &= ~nextWish.rawValue
            latestWishRaw = nextWish.rawValue
            persistCare()
        } else if shouldUseToy, let nextToy {
            dailyToyOfferedMask |= nextToy.rawValue
            dailyToyDismissedMask &= ~nextToy.rawValue
            latestToyRaw = nextToy.rawValue
            persistCare()
        } else if shouldUseTrick, let nextTrick {
            dailyTrickOfferedMask |= nextTrick.rawValue
            dailyTrickDismissedMask &= ~nextTrick.rawValue
            latestTrickRaw = nextTrick.rawValue
            persistCare()
        } else if shouldUseDialogue, let nextDialogue {
            dailyCheerDialogueOfferedMask |= nextDialogue.rawValue
            dailyCheerDialogueDismissedMask &= ~nextDialogue.rawValue
            persistCare()
        } else if shouldUseScript, let nextScript {
            dailyCheerScriptOfferedMask |= nextScript.rawValue
            dailyCheerScriptDismissedMask &= ~nextScript.rawValue
            persistCare()
        } else if shouldUseMoodStory, let nextMoodStory {
            dailyMoodStoryOfferedMask |= nextMoodStory.rawValue
            dailyMoodStoryDismissedMask &= ~nextMoodStory.rawValue
            latestMoodStoryRaw = nextMoodStory.rawValue
            persistCare()
        } else if shouldUseFeelingRitual, let nextFeelingRitual {
            dailyFeelingRitualOfferedMask |= nextFeelingRitual.rawValue
            dailyFeelingRitualDismissedMask &= ~nextFeelingRitual.rawValue
            latestFeelingRitualRaw = nextFeelingRitual.rawValue
            persistCare()
        } else if shouldUseFieldNote, let nextFieldNote {
            dailyFieldNoteOfferedMask |= nextFieldNote.rawValue
            dailyFieldNoteDismissedMask &= ~nextFieldNote.rawValue
            latestFieldNoteRaw = nextFieldNote.rawValue
            persistCare()
        }
        persistCare()
        defaults.set(index + 1, forKey: Self.cheerIndexKey)
        defaults.set(now, forKey: Self.lastCheerAtKey)
        let promptMood: PetMood
        if shouldUseScoutReturn {
            promptMood = activeScoutTrip?.mood ?? .hyper
        } else if shouldUseJourney {
            promptMood = journey.mood
        } else if shouldUseVisit {
            promptMood = nextVisit?.mood ?? .look
        } else if shouldUseSparkWheelClaim {
            promptMood = activeWheel?.mood ?? .hyper
        } else if shouldUseSparkWheelStart {
            promptMood = nextWheel?.mood ?? .hyper
        } else if shouldUseRoute {
            promptMood = nextRoute?.mood ?? .hyper
        } else if shouldUseCarePulse {
            promptMood = nextCarePulse?.mood ?? .look
        } else if shouldUseCheerPing {
            promptMood = nextPing?.mood ?? .look
        } else if shouldUseExchange {
            promptMood = nextExchange?.mood ?? .hyper
        } else if shouldUseCareChest {
            promptMood = nextChest?.mood ?? .happy
        } else if shouldUseBondTimeline {
            promptMood = nextTimeline?.mood ?? .look
        } else if shouldUseAffection {
            promptMood = nextAffection?.mood ?? .happy
        } else if shouldUseHome {
            promptMood = nextHomeRoom?.mood ?? .happy
        } else if shouldUseErrand {
            promptMood = nextErrand?.mood ?? .patrol
        } else if shouldUseUserCheck {
            promptMood = nextUserCheck?.mood ?? .look
        } else if shouldUseWish {
            promptMood = nextWish?.mood ?? .hyper
        } else if shouldUseToy {
            promptMood = nextToy?.mood ?? .hyper
        } else if shouldUseTrick {
            promptMood = nextTrick?.mood ?? .hyper
        } else if shouldUseMoodStory {
            promptMood = nextMoodStory?.mood ?? .hyper
        } else if shouldUseFeelingRitual {
            promptMood = nextFeelingRitual?.mood ?? .look
        } else if shouldUseFieldNote {
            promptMood = nextFieldNote?.mood ?? .hyper
        } else {
            promptMood = .hyper
        }
        setMood(promptMood, duration: 1.2)
    }

    private var launchQuietPeriodActive: Bool {
        Date().timeIntervalSince1970 - launchedAt < Self.initialPetOnlyQuietSeconds
    }

    private var canShowComebackNudge: Bool {
        let today = Self.dayFormatter.string(from: Date())
        let elapsed = Date().timeIntervalSince1970 - lastLifecycleAt
        return lastComebackChestDay != today && elapsed >= 4 * 60 * 60
    }
}

enum PetMood: String, CaseIterable {
    case idle
    case happy
    case nap
    case hyper
    case alert
    case thinking
    case look
    case perch
    case snack
    case stretch
    case patrol
    case spark
    case sleepGuard
    case peek

    var dailyWheelTitle: String {
        switch self {
        case .happy:
            return "Joy"
        case .look:
            return "Curious"
        case .hyper, .spark:
            return "Hyper"
        case .snack:
            return "Cozy"
        case .stretch:
            return "Reset"
        case .nap:
            return "Sleepy"
        default:
            return "Bright"
        }
    }

    var dailyWheelFeeling: String {
        switch self {
        case .happy:
            return "cheerful"
        case .look:
            return "curious"
        case .hyper:
            return "extra playful"
        case .spark:
            return "sparkly and alert"
        case .snack:
            return "comforted"
        case .stretch:
            return "fresh after a tiny reset"
        case .nap:
            return "soft and sleepy"
        default:
            return "bright"
        }
    }

    var fallbackAssetName: String {
        switch self {
        case .idle, .happy, .look, .perch, .snack, .stretch, .peek:
            return "pet-happy"
        case .nap:
            return "pet-nap"
        case .hyper, .patrol, .spark:
            return "pet-hyper"
        case .alert, .thinking, .sleepGuard:
            return "pet-alert"
        }
    }

    func spriteCandidates(stage: PetGrowthStage) -> [String] {
        let prefix = "pet-\(stage.assetSlug)"
        let stageCandidates: [String]
        switch self {
        case .idle:
            stageCandidates = [
                "\(prefix)-eager-idle-look-smile",
                "\(prefix)-idle-look-smile",
                "\(prefix)-bright"
            ]
        case .happy:
            stageCandidates = [
                "\(prefix)-happy",
                "\(prefix)-grateful-care-streak",
                "\(prefix)-bright"
            ]
        case .nap:
            stageCandidates = [
                "\(prefix)-sleepy-nap",
                "\(prefix)-nap",
                "\(prefix)-need-rest"
            ]
        case .hyper:
            stageCandidates = [
                "\(prefix)-hyper",
                "\(prefix)-playful-wiggle",
                "\(prefix)-eager-idle-look-smile"
            ]
        case .alert:
            stageCandidates = [
                "\(prefix)-alert",
                "\(prefix)-curious-listen",
                "\(prefix)-focused-watch-mode"
            ]
        case .thinking:
            stageCandidates = [
                "\(prefix)-curious-listen",
                "\(prefix)-focused-watch-mode",
                "\(prefix)-alert"
            ]
        case .look:
            stageCandidates = [
                "\(prefix)-ambient-first-look",
                "\(prefix)-eager-idle-look-smile",
                "\(prefix)-idle-look-smile"
            ]
        case .perch:
            stageCandidates = [
                "\(prefix)-ambient-desk-perch",
                "\(prefix)-focused-watch-mode",
                "\(prefix)-curious-listen"
            ]
        case .snack:
            stageCandidates = [
                "\(prefix)-ambient-snack-sniff",
                "\(prefix)-need-snack",
                "\(prefix)-snacky"
            ]
        case .stretch:
            stageCandidates = [
                "\(prefix)-ambient-soft-stretch",
                "\(prefix)-mood-care-rest",
                "\(prefix)-gentle"
            ]
        case .patrol:
            stageCandidates = [
                "\(prefix)-ambient-spark-patrol",
                "\(prefix)-playful-wiggle",
                "\(prefix)-hyper"
            ]
        case .spark:
            stageCandidates = [
                "\(prefix)-ambient-cheek-spark",
                "\(prefix)-overcharged",
                "\(prefix)-hyper"
            ]
        case .sleepGuard:
            stageCandidates = [
                "\(prefix)-ambient-sleepy-guard",
                "\(prefix)-sleepy-nap",
                "\(prefix)-protective"
            ]
        case .peek:
            stageCandidates = [
                "\(prefix)-ambient-journal-peek",
                "\(prefix)-journal-open",
                "\(prefix)-proud"
            ]
        }
        return stageCandidates + [fallbackAssetName]
    }

    func preferredSpriteName(stage: PetGrowthStage) -> String {
        spriteCandidates(stage: stage).first ?? fallbackAssetName
    }

    var frameSequence: [Int] {
        switch self {
        case .idle:
            return [8, 8, 8, 0, 0, 10, 10, 1, 2, 3, 3, 0]
        case .thinking:
            return [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0, 0]
        case .hyper:
            return [0, 3, 5, 6, 7, 8, 9, 10, 11, 4, 2, 1]
        case .look:
            return [0, 0, 1, 1, 2, 3, 4, 5, 5, 4, 3, 0]
        case .perch, .sleepGuard:
            return [0, 1, 1, 2, 2, 3, 2, 1, 0, 0, 4, 4]
        case .snack, .stretch, .peek:
            return [0, 1, 2, 3, 4, 5, 5, 4, 3, 2, 1, 0]
        case .patrol, .spark:
            return [0, 2, 4, 6, 8, 10, 11, 9, 7, 5, 3, 1]
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
    case pikaReply
    case pikaQuestion
    case pikaExcited
    case pikaElectric

    var resourceNames: [String] {
        switch self {
        case .happy:
            return ["pika-voice-excited", "chirp-happy", "pika-cc0-pep-2"]
        case .nap:
            return ["pika-voice-soft", "chirp-nap"]
        case .hyper:
            return ["pika-voice-electric", "pika-cc0-zap", "chirp-hyper"]
        case .alert:
            return ["pika-voice-question", "chirp-alert"]
        case .reply:
            return ["chirp-reply", "pika-voice-reply"]
        case .send:
            return ["chirp-send", "pika-cc0-pep-1"]
        case .open:
            return ["pika-cc0-pep-2", "chirp-open"]
        case .minimize:
            return ["chirp-minimize", "pika-cc0-power-up"]
        case .close:
            return ["chirp-close", "pika-cc0-power-up"]
        case .pet:
            return ["pika-cc0-pep-2", "chirp-pet"]
        case .pikaReply:
            return ["pika-voice-reply", "chirp-reply"]
        case .pikaQuestion:
            return ["pika-voice-question", "chirp-alert"]
        case .pikaExcited:
            return ["pika-voice-excited", "pika-cc0-pep-2", "chirp-happy"]
        case .pikaElectric:
            return ["pika-voice-electric", "pika-cc0-zap", "chirp-hyper"]
        }
    }

    var resourceExtensions: [String] {
        switch self {
        case .happy, .hyper, .alert, .reply, .pikaReply, .pikaQuestion, .pikaExcited, .pikaElectric:
            return ["wav", "mp3"]
        default:
            return ["wav", "mp3"]
        }
    }

    var volume: Float {
        switch self {
        case .pikaReply, .pikaQuestion:
            return 0.42
        case .pikaExcited:
            return 0.44
        case .pikaElectric:
            return 0.38
        case .hyper:
            return 0.32
        case .reply, .open, .pet:
            return 0.28
        case .send, .minimize, .close:
            return 0.22
        default:
            return 0.26
        }
    }

    var cooldown: TimeInterval {
        switch self {
        case .pikaReply, .pikaQuestion, .pikaExcited:
            return 0.65
        case .pikaElectric:
            return 0.85
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

    var isMascotVoice: Bool {
        switch self {
        case .pikaReply, .pikaQuestion, .pikaExcited, .pikaElectric:
            return true
        default:
            return false
        }
    }
}

@MainActor
final class VoiceConversationTranscriber {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var localRecorder: AVAudioRecorder?
    private var localRecordingURL: URL?
    private var localOnPartial: (@MainActor (String) -> Void)?
    private var localOnFinal: (@MainActor (String) -> Void)?
    private var localOnError: (@MainActor (String) -> Void)?
    private var isStopping = false
    private let realtimeSTTURL: URL? = {
        let raw = ProcessInfo.processInfo.environment["POCKETDM_REALTIME_STT_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }()
    private let localSTTURL: URL? = {
        let raw = ProcessInfo.processInfo.environment["POCKETDM_PIKA_STT_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }()

    func start(
        onPartial: @escaping @MainActor (String) -> Void,
        onFinal: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        if realtimeSTTURL != nil || localSTTURL != nil {
            startLocalRecording(onPartial: onPartial, onFinal: onFinal, onError: onError)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            requestSpeechAuthorization(onPartial: onPartial, onFinal: onFinal, onError: onError)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    guard granted else {
                        onError(Self.microphoneAuthorizationMessage(for: .denied))
                        return
                    }
                    self.requestSpeechAuthorization(onPartial: onPartial, onFinal: onFinal, onError: onError)
                }
            }
        case .denied, .restricted:
            onError(Self.microphoneAuthorizationMessage(for: AVCaptureDevice.authorizationStatus(for: .audio)))
        @unknown default:
            onError("Microphone is unavailable on this Mac.")
        }
    }

    private func requestSpeechAuthorization(
        onPartial: @escaping @MainActor (String) -> Void,
        onFinal: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                guard status == .authorized else {
                    onError(Self.authorizationMessage(for: status))
                    return
                }
                self.startAuthorized(onPartial: onPartial, onFinal: onFinal, onError: onError)
            }
        }
    }

    @discardableResult
    func stop(sendRecordedAudio: Bool = false) -> Bool {
        isStopping = true
        if let localRecorder {
            let recordingURL = localRecordingURL
            localRecorder.stop()
            self.localRecorder = nil
            localRecordingURL = nil
            guard sendRecordedAudio, let recordingURL else {
                recordingURL?.deleteQuietly()
                return false
            }
            transcribeLocalRecording(recordingURL)
            return true
        }
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        return false
    }

    func currentMeterPower() -> Float? {
        guard let localRecorder else { return nil }
        localRecorder.updateMeters()
        return localRecorder.averagePower(forChannel: 0)
    }

    private func startLocalRecording(
        onPartial: @escaping @MainActor (String) -> Void,
        onFinal: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startAuthorizedLocalRecording(onPartial: onPartial, onFinal: onFinal, onError: onError)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    guard granted else {
                        onError(Self.microphoneAuthorizationMessage(for: .denied))
                        return
                    }
                    self.startAuthorizedLocalRecording(onPartial: onPartial, onFinal: onFinal, onError: onError)
                }
            }
        case .denied, .restricted:
            onError(Self.microphoneAuthorizationMessage(for: AVCaptureDevice.authorizationStatus(for: .audio)))
        @unknown default:
            onError("Microphone is unavailable on this Mac.")
        }
    }

    private func startAuthorizedLocalRecording(
        onPartial: @escaping @MainActor (String) -> Void,
        onFinal: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        _ = stop()
        isStopping = false
        localOnPartial = onPartial
        localOnFinal = onFinal
        localOnError = onError
        let recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pika-stt-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        do {
            let recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw CompanionError.badResponse
            }
            localRecorder = recorder
            localRecordingURL = recordingURL
            if realtimeSTTURL != nil {
                onPartial("Realtime listening...")
            } else {
                onPartial("Listening locally...")
            }
        } catch {
            recordingURL.deleteQuietly()
            onError("Local microphone recording failed: \(error.localizedDescription)")
        }
    }

    private func transcribeLocalRecording(_ recordingURL: URL) {
        guard realtimeSTTURL != nil || localSTTURL != nil else {
            recordingURL.deleteQuietly()
            localOnError?("Local STT URL is missing.")
            return
        }
        let realtimeSTTURL = realtimeSTTURL
        let localSTTURL = localSTTURL
        let onPartial = localOnPartial
        let onFinal = localOnFinal
        let onError = localOnError
        localOnPartial = nil
        localOnFinal = nil
        localOnError = nil
        Task {
            defer { recordingURL.deleteQuietly() }
            do {
                let transcript = try await Self.transcribeBestRecording(
                    recordingURL,
                    realtimeEndpoint: realtimeSTTURL,
                    localEndpoint: localSTTURL
                ) { partial in
                    await MainActor.run {
                        onPartial?(partial)
                    }
                }
                await MainActor.run {
                    onFinal?(transcript)
                }
            } catch {
                await MainActor.run {
                    onError?("Local STT failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private static func transcribeBestRecording(
        _ recordingURL: URL,
        realtimeEndpoint: URL?,
        localEndpoint: URL?,
        onPartial: @escaping (String) async -> Void
    ) async throws -> String {
        if let realtimeEndpoint {
            do {
                return try await transcribeRealtimeRecording(recordingURL, endpoint: realtimeEndpoint, onPartial: onPartial)
            } catch {
                guard let localEndpoint else { throw error }
                await onPartial("Realtime STT failed; trying local STT...")
                return try await transcribeRecording(recordingURL, endpoint: localEndpoint)
            }
        }
        guard let localEndpoint else { throw CompanionError.badResponse }
        return try await transcribeRecording(recordingURL, endpoint: localEndpoint)
    }

    private static func transcribeRecording(_ recordingURL: URL, endpoint: URL) async throws -> String {
        let url = transcribeEndpoint(from: endpoint)
        let boundary = "PocketDMPikaSTT-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "content-type")
        var body = Data()
        body.appendMultipartBoundary(boundary)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"speech.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(try Data(contentsOf: recordingURL))
        body.append("\r\n")
        body.appendMultipartBoundary(boundary, closing: true)
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw CompanionError.badResponse
        }
        let decoded = try JSONDecoder().decode(LocalSTTResponse.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func transcribeRealtimeRecording(
        _ recordingURL: URL,
        endpoint: URL,
        onPartial: @escaping (String) async -> Void
    ) async throws -> String {
        let url = realtimeTranscribeEndpoint(from: endpoint)
        let socket = URLSession.shared.webSocketTask(with: url)
        socket.resume()
        defer { socket.cancel(with: .normalClosure, reason: nil) }

        let audio = try Data(contentsOf: recordingURL)
        try await socket.send(.string(#"{"type":"start","format":"wav","sample_rate":16000}"#))
        let chunkSize = 64 * 1024
        var offset = 0
        while offset < audio.count {
            let end = min(offset + chunkSize, audio.count)
            try await socket.send(.data(Data(audio[offset..<end])))
            offset = end
        }
        try await socket.send(.string(#"{"type":"end"}"#))
        for _ in 0..<32 {
            let message = try await socket.receive()
            let data: Data
            switch message {
            case .data(let payload):
                data = payload
            case .string(let text):
                data = Data(text.utf8)
            @unknown default:
                continue
            }
            let frame = try JSONDecoder().decode(RealtimeSTTFrame.self, from: data)
            switch frame.type {
            case "partial":
                if let text = frame.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !text.isEmpty {
                    await onPartial(text)
                }
            case "final":
                let text = frame.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !text.isEmpty else { throw CompanionError.badResponse }
                return text
            case "error":
                throw NSError(
                    domain: "PocketDMRealtimeSTT",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: frame.message ?? "Realtime STT failed"]
                )
            default:
                continue
            }
        }
        throw NSError(
            domain: "PocketDMRealtimeSTT",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Realtime STT did not return a final transcript"]
        )
    }

    private static func transcribeEndpoint(from endpoint: URL) -> URL {
        if endpoint.pathComponents.last == "transcribe" {
            return endpoint
        }
        return endpoint.appending(path: "transcribe")
    }

    private static func realtimeTranscribeEndpoint(from endpoint: URL) -> URL {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return endpoint
        }
        if components.scheme == "http" {
            components.scheme = "ws"
        } else if components.scheme == "https" {
            components.scheme = "wss"
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            components.path = "/ws/transcribe"
        } else if path == "ws/transcribe" || path.hasSuffix("/ws/transcribe") {
            components.path = "/" + path
        } else if path == "transcribe" || path.hasSuffix("/transcribe") {
            components.path = "/" + path
        } else {
            components.path = "/" + path + "/ws/transcribe"
        }
        return components.url ?? endpoint
    }

    private struct LocalSTTResponse: Decodable {
        let text: String
    }

    private struct RealtimeSTTFrame: Decodable {
        let type: String
        let text: String?
        let message: String?
    }

    private func startAuthorized(
        onPartial: @escaping @MainActor (String) -> Void,
        onFinal: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        stop()
        isStopping = false
        guard let recognizer else {
            onError("Speech recognition is not available on this Mac.")
            return
        }
        guard recognizer.isAvailable else {
            onError("Speech recognition is not ready yet.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.isStopping = true
                        self.stop()
                        onFinal(transcript)
                    } else {
                        onPartial(transcript)
                    }
                } else if let error, !self.isStopping {
                    self.stop()
                    onError("I could not hear clearly: \(error.localizedDescription)")
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            onPartial("")
        } catch {
            stop()
            onError("Microphone failed to start: \(error.localizedDescription)")
        }
    }

    private static func authorizationMessage(for status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .denied:
            return "Speech permission is denied. Enable it in System Settings."
        case .restricted:
            return "Speech recognition is restricted on this Mac."
        case .notDetermined:
            return "Speech permission was not granted yet."
        case .authorized:
            return "Speech is ready."
        @unknown default:
            return "Speech recognition is unavailable."
        }
    }

    private static func microphoneAuthorizationMessage(for status: AVAuthorizationStatus) -> String {
        switch status {
        case .denied:
            return "Microphone permission is denied. Enable it in System Settings."
        case .restricted:
            return "Microphone access is restricted on this Mac."
        case .notDetermined:
            return "Microphone permission was not granted yet."
        case .authorized:
            return "Microphone is ready."
        @unknown default:
            return "Microphone is unavailable on this Mac."
        }
    }
}

@MainActor
final class PetSoundPlayer {
    private var cache: [PetSound: NSSound] = [:]
    private var lastPlayed: [PetSound: Date] = [:]
    private let speech = AVSpeechSynthesizer()
    private var lastPikaAt = Date.distantPast
    private var externalVoiceSound: NSSound?
    var onVoiceStatus: ((String) -> Void)?

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
        if player.play(), sound.isMascotVoice {
            onVoiceStatus?("Played bundled Pika chirp.")
        }
    }

    func speakPika(character: CompanionCharacter, enabled: Bool, force: Bool = false) {
        if character == .pika {
            playPikaReaction(.pikaExcited, voiceLine: character.voiceCatchphrase, enabled: enabled, force: force)
            return
        }
        speak(character.voiceCatchphrase, character: character, enabled: enabled, force: force)
    }

    func speakPikaLine(_ text: String, character: CompanionCharacter, enabled: Bool, force: Bool = false) {
        if character == .pika {
            playPikaReaction(for: text, enabled: enabled, force: force)
            return
        }
        speak(pikaVoiceLine(from: text, character: character), character: character, enabled: enabled, force: force)
    }

    private func playPikaReaction(for text: String, enabled: Bool, force: Bool) {
        let voiceLine = pikaVoiceLine(from: text, character: .pika)
        playPikaReaction(pikaReactionSound(for: text), voiceLine: voiceLine, enabled: enabled, force: force)
    }

    private func pikaReactionSound(for text: String) -> PetSound {
        let lowercased = text.lowercased()
        if lowercased.contains("cannot")
            || lowercased.contains("not reachable")
            || lowercased.contains("did not catch")
            || lowercased.contains("try again")
            || lowercased.contains("missing") {
            return .pikaQuestion
        } else if lowercased.contains("spark")
            || lowercased.contains("hyper")
            || lowercased.contains("electric")
            || lowercased.contains("charge") {
            return .pikaElectric
        } else if lowercased.contains("complete")
            || lowercased.contains("joy")
            || lowercased.contains("great")
            || lowercased.contains("happy")
            || lowercased.contains("ready") {
            return .pikaExcited
        } else {
            return .pikaReply
        }
    }

    private func playPikaReaction(_ sound: PetSound, voiceLine: String? = nil, enabled: Bool, force: Bool) {
        guard enabled else {
            onVoiceStatus?("Muted; text only.")
            return
        }
        let now = Date()
        guard force || now.timeIntervalSince(lastPikaAt) >= 1.0 else { return }
        guard force || !recentlyPlayedMascotSound(at: now) else { return }
        lastPikaAt = now
        speech.stopSpeaking(at: .immediate)

        if let endpoint = Self.externalPikaTTSURL, let voiceLine {
            onVoiceStatus?("Generating Pika voice...")
            Task { [weak self] in
                guard let self else { return }
                let didPlay = await self.playExternalVoice(voiceLine, endpoint: endpoint)
                if !didPlay {
                    self.onVoiceStatus?("Pika voice fallback: bundled chirp.")
                    self.play(sound, enabled: enabled)
                }
            }
            return
        }

        play(sound, enabled: enabled)
    }

    private func recentlyPlayedMascotSound(at now: Date) -> Bool {
        let mascotSounds: [PetSound] = [
            .happy,
            .hyper,
            .alert,
            .reply,
            .pikaReply,
            .pikaQuestion,
            .pikaExcited,
            .pikaElectric
        ]
        return mascotSounds.contains { sound in
            guard let last = lastPlayed[sound] else { return false }
            return now.timeIntervalSince(last) < 0.22
        }
    }

    private func speak(_ line: String, character: CompanionCharacter, enabled: Bool, force: Bool) {
        guard enabled else {
            onVoiceStatus?("Muted; text only.")
            return
        }
        let now = Date()
        guard force || now.timeIntervalSince(lastPikaAt) >= 1.4 else { return }
        lastPikaAt = now
        speech.stopSpeaking(at: .immediate)

        if character == .pika {
            let sound = pikaReactionSound(for: line)
            if let endpoint = Self.externalPikaTTSURL {
                let voiceLine = pikaVoiceLine(from: line, character: character)
                onVoiceStatus?("Generating Pika voice...")
                Task { [weak self] in
                    guard let self else { return }
                    let didPlay = await self.playExternalVoice(voiceLine, endpoint: endpoint)
                    if !didPlay {
                        self.onVoiceStatus?("Pika voice fallback: bundled chirp.")
                        self.play(sound, enabled: enabled)
                    }
                }
            } else {
                play(sound, enabled: enabled)
            }
            return
        }

        speakSystem(line, character: character)
    }

    private func speakSystem(_ line: String, character: CompanionCharacter) {
        onVoiceStatus?("Playing system voice: \(character.selectedVoiceName).")
        for part in speechParts(from: line, character: character) {
            let utterance = AVSpeechUtterance(string: part.text)
            utterance.rate = part.rate
            utterance.volume = part.volume
            utterance.pitchMultiplier = part.pitch
            utterance.postUtteranceDelay = part.pause
            utterance.voice = CompanionCharacter.preferredSpeechVoice(for: character)
            speech.speak(utterance)
        }
    }

    private func playExternalVoice(_ line: String, endpoint: URL) async -> Bool {
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            let configuredTimeout = ProcessInfo.processInfo.environment["POCKETDM_PIKA_TTS_TIMEOUT"]
                .flatMap(Double.init) ?? 45
            request.timeoutInterval = max(8, configuredTimeout)
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try JSONEncoder().encode(ExternalPikaTTSRequest(text: line, voice: "pika-signature", format: "wav"))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let player = NSSound(data: data) else {
                onVoiceStatus?("Pika voice sidecar returned no playable audio.")
                return false
            }
            externalVoiceSound?.stop()
            externalVoiceSound = player
            player.volume = 1.0
            let didPlay = player.play()
            onVoiceStatus?(didPlay ? "Playing Pika sidecar voice." : "Pika sidecar audio could not play.")
            return didPlay
        } catch {
            onVoiceStatus?("Pika voice sidecar unavailable.")
            return false
        }
    }

    private func speechParts(
        from line: String,
        character: CompanionCharacter
    ) -> [(text: String, rate: Float, volume: Float, pitch: Float, pause: TimeInterval)] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard character == .pika else {
            return [(trimmed, character.voiceRate, character.voiceVolume, character.voicePitch, 0)]
        }

        if Self.isPikaVoiceOnly(trimmed) {
            return [(trimmed, character.catchphraseVoiceRate, character.catchphraseVoiceVolume, character.catchphraseVoicePitch, 0)]
        }

        let body = trimmed
            .replacingOccurrences(
                of: #"(?i)^\s*pika[\s,-]+pika[!,.:\s-]*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard body != trimmed else {
            return [(trimmed, character.voiceRate, character.voiceVolume, character.voicePitch, 0)]
        }

        var parts = [
            (
                text: character.catchphrase,
                rate: character.catchphraseVoiceRate,
                volume: character.catchphraseVoiceVolume,
                pitch: character.catchphraseVoicePitch,
                pause: TimeInterval(0.06)
            )
        ]
        if !body.isEmpty {
            parts.append((body, character.voiceRate, character.voiceVolume, character.voicePitch, 0))
        }
        return parts
    }

    private func pikaVoiceLine(from text: String, character: CompanionCharacter) -> String {
        guard character == .pika else {
            return character.rewrite(text)
        }

        // Speak the pet's actual reply as full cheerful sentences. The brain caps
        // replies to ~1-2 sentences, so VoxCPM stays snappy. The "Pika pika!"
        // catchphrase that opens most replies keeps the mascot character on-brand.
        let lowercased = text.lowercased()
        if lowercased.contains("thinking") {
            // Transient placeholder; emit a tiny thinking chirp instead of TTS-ing "Thinking...".
            return "Pikaa..."
        }
        let spoken = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return character.voiceCatchphrase }
        let maxCharacters = 300
        guard spoken.count > maxCharacters else { return spoken }
        let clipped = spoken.prefix(maxCharacters)
        if let lastStop = clipped.lastIndex(where: { ".!?".contains($0) }) {
            return String(clipped[...lastStop])
        }
        return clipped.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func isPikaVoiceOnly(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .filter { $0.isLetter }
        guard !normalized.isEmpty else { return false }
        return normalized.allSatisfy { "pika".contains($0) }
    }

    private func pikaSpeechLine(from text: String, character: CompanionCharacter) -> String {
        // Legacy long-form speech helper kept for non-signature fallback experiments.
        let rewritten = character.rewrite(text)
        let withoutCatchphrase = rewritten.replacingOccurrences(
            of: #"(?i)\bpika[\s,-]+pika[!,.:\s-]*"#,
            with: "",
            options: .regularExpression
        )
        let compacted = withoutCatchphrase
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compacted.isEmpty else { return character.catchphrase }
        let maxCharacters = 180
        let clipped = compacted.count > maxCharacters
            ? String(compacted.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
            : compacted
        return "\(character.catchphrase) \(clipped)"
    }

    func stopAll() {
        for player in cache.values {
            player.stop()
        }
        speech.stopSpeaking(at: .immediate)
    }

    private func soundInstance(for sound: PetSound) -> NSSound? {
        if let cached = cache[sound] {
            return cached
        }
        guard let url = sound.resourceNames.lazy.compactMap({ resourceName in
            sound.resourceExtensions.lazy.compactMap { fileExtension in
                Bundle.module.url(forResource: resourceName, withExtension: fileExtension)
            }.first
        }).first else {
            return nil
        }
        let player = NSSound(contentsOf: url, byReference: false)
        cache[sound] = player
        return player
    }

    private static var externalPikaTTSURL: URL? {
        guard let raw = ProcessInfo.processInfo.environment["POCKETDM_PIKA_TTS_URL"],
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(string: raw)
    }

    private struct ExternalPikaTTSRequest: Encodable {
        let text: String
        let voice: String
        let format: String
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
    @State private var petControlsHovering = false
    @State private var showingSettings = false
    @State private var showingDemoTools = false
    @State private var showingRuntimeStack = false
    @State private var showingDailyDetails = false
    @State private var journalPage: PetJournalPage = .growth

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
        .onChange(of: model.minimized) { _, minimized in
            showingSettings = false
            showingDemoTools = false
            showingRuntimeStack = false
            showingDailyDetails = false
            petHovering = false
            petControlsHovering = false
            onSizeChange(minimized)
        }
    }

    private var petOnlyBody: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.76)) {
                        model.setMinimized(false)
                    }
                } label: {
                    AnimatedPetSprite(
                        character: model.companionCharacter,
                        stage: model.growthStage,
                        mood: model.mood,
                        size: min(CGFloat(petHovering ? 190 : 182) * model.petScale, 198)
                    )
                    .overlay(petVideoOverlay)
                }
                .buttonStyle(.plain)
                .contentShape(PetHoverShape())
                .simultaneousGesture(dragGesture)
                .onHover { isHovering in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                        petHovering = isHovering
                    }
                }
                .accessibilityLabel("Open \(model.companionCharacter.title) chat")

                if model.voiceVisualState.isAnimated {
                    AudioWaveView(state: model.voiceVisualState, compact: true)
                        .frame(width: 82, height: 22)
                        .offset(x: -62, y: 154)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.88).combined(with: .opacity))
                }

                petHoverControls
                    .padding(.top, 2)
                    .padding(.trailing, 0)
            }
            .frame(width: 204, height: 204)
            .contentShape(Rectangle())

            if let bubble = model.petOnlyBubbleContent {
                HStack(alignment: .top, spacing: 5) {
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.76)) {
                            model.setMinimized(false)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bubble.title)
                                .font(.system(size: 9.5, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .lineLimit(1)
                            Text(bubble.body)
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                            Text(bubble.footer)
                                .font(.system(size: 8.5, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.58))
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .frame(width: 172, alignment: .leading)
                        .background(Color.ivory, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.9), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(model.companionCharacter.title) conversation")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: 4, y: 0)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if showingSettings {
                petOnlySettingsPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 216, height: 224)
        .contentShape(Rectangle())
        .onHover { isHovering in
            guard !isHovering else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                petHovering = false
                petControlsHovering = false
            }
        }
    }

    private var petControlsVisible: Bool {
        petHovering || petControlsHovering || showingSettings
    }

    private var petHoverControls: some View {
        Group {
            if petControlsVisible {
                VStack(spacing: 6) {
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            showingSettings.toggle()
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(DragonIconButtonStyle(kind: showingSettings ? .primary : .secondary))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Open \(model.companionCharacter.title) settings")

                    if model.minimized {
                        Button {
                            closeCompanion()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(DragonIconButtonStyle(kind: .secondary))
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Close \(model.companionCharacter.title)")
                    }
                }
                .onHover { isHovering in
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
                        petControlsHovering = isHovering
                    }
                }
                .transition(.scale(scale: 0.86, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.14), value: petControlsVisible)
    }

    private var petOnlySettingsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.circle.fill")
                    .foregroundStyle(Color.gold)
                Text("Pikachu live")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.76)) {
                        model.setMinimized(false)
                    }
                } label: {
                    Label("Show", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(MiniPanelButtonStyle(kind: .primary))

                Button {
                    closeCompanion()
                } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(MiniPanelButtonStyle(kind: .danger))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(width: 176)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.32), lineWidth: 1))
        .padding(.bottom, 4)
        .onHover { isHovering in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
                if !isHovering && !petHovering {
                    showingSettings = false
                }
            }
        }
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerBar(isCompact: false)

            VStack(alignment: .leading, spacing: 8) {
                if model.learningMode != .chat || showingDemoTools {
                    modeControls
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if showingSettings {
                    characterSettingsPanel
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if model.learningMode == .lesson {
                    ScrollView(.vertical, showsIndicators: false) {
                        LanguageCoachPanel(
                            coach: model.languageCoach,
                            onReward: { reward in
                                model.applyLanguageReward(reward)
                            }
                        )
                    }
                    .frame(maxHeight: 456)
                } else if model.learningMode == .journal {
                    ScrollView(.vertical, showsIndicators: false) {
                        PetJournalPanel(model: model, page: $journalPage)
                    }
                    .frame(maxHeight: 456)
                } else {
                    expandedChatPanel
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.22), lineWidth: 1))
        }
        .padding(8)
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 410, maxHeight: .infinity)
        .background(.clear)
    }

    private var expandedChatPanel: some View {
        VStack(alignment: .center, spacing: 8) {
            expandedPetStage
            chatTranscript(isCompact: false)
            inputRow(isCompact: false)
            expandedQuickActions

            if showingDemoTools {
                dailyCarePromptPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
                voiceConversationPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
                gameActionPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder private var petVideoOverlay: some View {
        if model.introVideoActive {
            TransparentVideoView(resource: "pet-intro-greeting", onFinished: { model.finishIntroVideo() })
                .frame(width: 230, height: 230)
                .allowsHitTesting(false)
                .transition(.opacity)
        } else if model.napVideoActive {
            TransparentVideoView(resource: "pet-nap")
                .frame(width: 230, height: 230)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private var expandedPetStage: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: -2) {
                gameHealthBar
                    .frame(width: 260)
                    .zIndex(1)

                AnimatedPetSprite(
                    character: model.companionCharacter,
                    stage: model.growthStage,
                    mood: model.mood,
                    size: min(CGFloat(petHovering ? 188 : 178) * model.petScale, 198)
                )
                .frame(width: 252, height: 184)
                .overlay(petVideoOverlay)
                .contentShape(PetHoverShape())
                .onHover { isHovering in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                        petHovering = isHovering
                    }
                }

                if model.voiceVisualState == .listening || model.voiceVisualState == .speaking {
                    AudioWaveView(state: model.voiceVisualState, compact: false)
                        .frame(width: 122, height: 28)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else if model.busy || model.voiceVisualState == .thinking || model.voiceVisualState == .transcribing {
                    thinkingIndicator
                        .transition(.scale.combined(with: .opacity))
                }

                dailyCareNudge
            }
            .frame(maxWidth: .infinity, alignment: .center)

            petHoverControls
                .padding(.top, 2)
                .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .center)
        .overlay(ConfettiBurstView(trigger: model.celebrationBurstID))
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            ThinkingDotsView()
            Text(model.voiceVisualState == .transcribing ? "Listening to you…" : "Pikachu is thinking…")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.92))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
        .overlay(Capsule().stroke(Color.gold.opacity(0.35), lineWidth: 1))
    }

    private var careStatusPanel: some View {
        let action = model.nextDailyWellnessAction
        let promptText = model.isDailyWellnessComplete ? "Wellness complete for today." : action.question

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Health")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Spacer(minLength: 0)
                Text("\(model.healthValueLine) HP")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.gold)
                    .lineLimit(1)
            }

            gameHealthBar

            VStack(alignment: .leading, spacing: 8) {
                missionCard("Now", text: promptText, systemImage: action.systemImage)
                HStack(spacing: 7) {
                    Button {
                        model.completeDailyWellness(action)
                    } label: {
                        Label(model.isDailyWellnessComplete ? "Pet me" : action.actionTitle, systemImage: action.systemImage)
                    }
                    .buttonStyle(MiniPanelButtonStyle(kind: .primary))
                    .disabled(model.busy || model.isVoiceListening)

                    Button {
                        model.spinEmotionWheel()
                    } label: {
                        Image(systemName: "dial.high.fill")
                    }
                    .buttonStyle(MiniPanelButtonStyle(kind: .primary))
                    .disabled(model.busy || model.isVoiceListening)
                    .accessibilityLabel("Spin Pikachu's mood")
                }
                Text(model.serverLine)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(0.62))
                    .lineLimit(1)
            }
        }
        .frame(width: 240, alignment: .topLeading)
        .padding(12)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.18), lineWidth: 1))
    }

    private var healthBar: some View {
        gameHealthBar
    }

    private var gameHealthBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .center) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.58))
                    Capsule()
                        .fill(healthBarTint)
                        .frame(width: max(18, proxy.size.width * model.healthProgress))
                        .animation(.easeInOut(duration: 0.9), value: model.healthProgress)
                    Capsule()
                        .stroke(Color.ivory.opacity(0.2), lineWidth: 1)
                }

                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .black))
                    Text(model.healthValueLine)
                    Text("HP")
                        .foregroundStyle(Color.ivory.opacity(0.72))
                }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(model.healthProgress >= 0.7 ? Color.black : Color.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            }
        }
        .frame(height: 22)
        .shadow(color: .black.opacity(0.34), radius: 8, x: 0, y: 3)
        .accessibilityLabel("Pikachu health \(model.healthValueLine) HP")
    }

    private var dailyCareNudge: some View {
        let action = model.nextDailyWellnessAction
        let promptText = model.isDailyWellnessComplete ? "Pet Pikachu to keep the bond glowing!" : action.question

        return HStack(spacing: 8) {
            Image(systemName: action.systemImage)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.gold)
                .frame(width: 18)

            Text(promptText)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)

            Button {
                model.completeDailyWellness(action)
            } label: {
                Text(model.isDailyWellnessComplete ? "Pet me" : action.actionTitle)
            }
            .buttonStyle(DragonMiniButtonStyle(kind: .primary))
            .frame(width: 112)
            .disabled(model.busy || model.isVoiceListening)

            Button {
                model.spinEmotionWheel()
            } label: {
                Image(systemName: "dial.high.fill")
            }
            .buttonStyle(DragonIconMiniButtonStyle(kind: .secondary))
            .disabled(model.busy || model.isVoiceListening)
            .accessibilityLabel("Spin Pikachu's mood")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: 340)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.ivory.opacity(0.1), lineWidth: 1))
    }

    private var legacyHealthBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.42))
                Capsule()
                    .fill(healthBarTint)
                    .frame(width: max(12, proxy.size.width * model.healthProgress))
                Capsule()
                    .stroke(Color.ivory.opacity(0.18), lineWidth: 1)
            }
        }
        .frame(height: 16)
    }

    private var healthBarTint: Color {
        if model.healthProgress >= 0.7 {
            return Color(red: 0.40, green: 0.92, blue: 0.34)
        }
        if model.healthProgress >= 0.35 {
            return .gold
        }
        return .dangerRed
    }

    private var companionHealthHUD: some View {
        let action = model.nextDailyWellnessAction
        let promptText = model.isDailyWellnessComplete ? "Pet Pikachu to keep the bond glowing!" : action.question

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Health")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Text("\(model.healthValueLine) HP")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(healthBarTint)
                Spacer(minLength: 0)
                Text(model.dailyWellnessProgressLine)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(0.58))
                    .lineLimit(1)
            }

            gameHealthBar

            HStack(spacing: 7) {
                Label(promptText, systemImage: action.systemImage)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                Button {
                    model.completeDailyWellness(action)
                } label: {
                    Text(model.isDailyWellnessComplete ? "Pet me" : action.actionTitle)
                }
                .buttonStyle(DragonMiniButtonStyle(kind: .primary))
                .frame(width: 112)
                .disabled(model.busy || model.isVoiceListening)

                Button {
                    model.spinEmotionWheel()
                } label: {
                    Image(systemName: "dial.high.fill")
                }
                .buttonStyle(DragonIconMiniButtonStyle(kind: .secondary))
                .disabled(model.busy || model.isVoiceListening)
                .accessibilityLabel("Spin Pikachu's mood")
            }
        }
        .padding(9)
        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.ivory.opacity(0.1), lineWidth: 1))
    }

    private func statusTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.66))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 10)
        .background(Color.gold.opacity(0.92), in: RoundedRectangle(cornerRadius: 7))
    }

    private func missionCard(_ title: String, text: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.gold)
                .frame(width: 18, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(0.62))
                    .lineLimit(1)
                Text(text)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.ivory.opacity(0.1), lineWidth: 1))
    }

    private func hudCaptionLine(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legacyCareStatusPanel: some View {
        VStack(spacing: 4) {
            Text(model.serverLine)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.84))
                .lineLimit(2)
            Text(model.careLine)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold)
                .lineLimit(2)
            Text(model.emotionLine)
                .font(.system(size: 8.4, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.54)
            Text(model.moodCareLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.48)
            Text(model.loreLine)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.76))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text(model.economyLine)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Text(model.vitalLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.48)
            Text(model.needLine)
                .font(.system(size: 8.8, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.56)
            Text(model.affectionLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
            Text(model.homeLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
            Text(model.errandLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
            Text(model.userCheckLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
            Text(model.wishLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
            Text(model.toyLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
            Text(model.trickLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
            Text(model.storyLine)
                .font(.system(size: 8.4, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.58)
            Text(model.lifeSceneLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.48)
            Text(model.eventLine)
                .font(.system(size: 8.5, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.56)
            Text(model.seasonTrailLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.48)
            Text(model.comboLine)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(model.evolutionLine)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            Text(model.evolutionQuestLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.48)
            Text(model.taskLine)
                .font(.system(size: 8.5, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            Text(model.bondBoardLine)
                .font(.system(size: 8.4, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.52)
            Text(model.weeklyLine)
                .font(.system(size: 8.4, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.52)
            Text(model.careWindowLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
            Text(model.cheerRhythmLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.48)
            Text(model.cheerDialogueLine)
                .font(.system(size: 8.1, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.44)
            Text(model.fieldNoteLine)
                .font(.system(size: 8.1, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.64))
                .lineLimit(1)
                .minimumScaleFactor(0.44)
            Text(model.scoutTripLine)
                .font(.system(size: 8.1, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.44)
            Text(model.cipherLine)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            Text(model.upgradeLine)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(model.upgradeDeckLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.48)
            Text(model.memoryLine)
                .font(.system(size: 8.3, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.64))
                .lineLimit(1)
                .minimumScaleFactor(0.56)
            Text(model.charmLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.48)
        }
        .multilineTextAlignment(.center)
        .frame(width: 170)
        .frame(minHeight: 194)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.18), lineWidth: 1))
    }

    private func headerBar(isCompact: Bool) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: isCompact ? 13 : 15, weight: .bold))
                    .foregroundStyle(Color.ivory.opacity(0.68))
                Text(model.companionCharacter.title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityLabel("Drag \(model.companionCharacter.title) panel")
            soundButton
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.76)) {
                    model.setMinimized(true)
                }
            } label: {
                Label("Hide", systemImage: "minus")
            }
            .buttonStyle(HeaderPillButtonStyle(kind: .secondary))
            .accessibilityLabel("Minimize \(model.companionCharacter.title) to pet")
        }
        .padding(.horizontal, 10)
        .frame(height: isCompact ? 44 : 52)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 7))
    }

    private var characterSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(Color.gold)
                Text("Pikachu Settings")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Spacer(minLength: 0)
                Text("Live")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(0.56))
            }

            HStack(alignment: .center, spacing: 8) {
                Label("Pika only", systemImage: model.companionCharacter.iconName)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black)
                    .frame(width: 104, height: 36)
                    .background(Color.gold, in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.companionCharacter.voiceSummary): \(model.companionCharacter.selectedVoiceName)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Text("Pikachu-only mode. The menu-bar Pika item can show, mute, or close the pet.")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ivory.opacity(0.68))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    showingRuntimeStack.toggle()
                }
            } label: {
                Label(showingRuntimeStack ? "Hide stack" : "Stack details", systemImage: "checkmark.seal.fill")
            }
            .buttonStyle(DragonButtonStyle(kind: .secondary))

            if showingRuntimeStack {
                runtimeStackPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.76)) {
                        model.setMinimized(true)
                    }
                } label: {
                    Label("Pet only", systemImage: "minus")
                }
                .buttonStyle(DragonButtonStyle(kind: .secondary))

                Button {
                    closeCompanion()
                } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(DragonButtonStyle(kind: .danger))
            }
        }
        .padding(10)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.2), lineWidth: 1))
    }

    private func chatTranscript(isCompact: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: isCompact ? 5 : 8) {
                    if model.chatMessages.isEmpty {
                        chatLine(label: model.companionCharacter.title, text: model.message, isCompact: isCompact)
                    } else {
                        ForEach(model.chatMessages) { chatMessage in
                            chatLine(chatMessage, isCompact: isCompact)
                                .id(chatMessage.id)
                        }
                    }

                    if model.isVoiceListening || model.voiceVisualState == .transcribing {
                        chatLine(label: model.voiceVisualState.title, text: model.voiceBubbleLine, isCompact: isCompact)
                            .id("voice-status")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.trailing, 2)
            }
            .onAppear {
                scrollToLatestChatMessage(with: proxy)
            }
            .onChange(of: model.chatMessages.count) {
                scrollToLatestChatMessage(with: proxy)
            }
            .onChange(of: model.voiceTranscript) {
                scrollToLatestChatMessage(with: proxy)
            }
        }
        .padding(isCompact ? 8 : 12)
        .frame(maxWidth: .infinity, minHeight: isCompact ? 64 : 130, maxHeight: isCompact ? 92 : 180, alignment: .topLeading)
        .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.26), lineWidth: 1))
    }

    private func scrollToLatestChatMessage(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if model.isVoiceListening || model.voiceVisualState == .transcribing {
                proxy.scrollTo("voice-status", anchor: .bottom)
            } else if let last = model.chatMessages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func chatLine(_ chatMessage: CompanionChatMessage, isCompact: Bool) -> some View {
        let label: String
        switch chatMessage.role {
        case .user:
            label = "You"
        case .assistant:
            label = model.companionCharacter.title
        case .status:
            label = "Status"
        }
        return chatLine(label: label, text: chatMessage.text, isCompact: isCompact)
    }

    private func chatLine(label: String, text: String, isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
            Text(label)
                .font(.system(size: isCompact ? 11 : 15, weight: .black, design: .rounded))
                .foregroundStyle(label == "You" ? Color.gold : Color.ivory.opacity(0.72))
                .lineLimit(1)
            Text(text)
                .font(.system(size: isCompact ? 12 : 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory)
                .lineLimit(isCompact ? 2 : nil)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dailyCarePromptPanel: some View {
        let action = model.nextDailyWellnessAction
        let promptText = model.isDailyWellnessComplete ? "Wellness complete for today." : action.question

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ivory.opacity(0.64))
                    Text(promptText)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color.gold)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.healthLine)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ivory)
                    Text(model.dailyWellnessProgressLine)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ivory.opacity(0.62))
                }
            }

            healthBar

            HStack(spacing: 9) {
                Button {
                    model.completeDailyWellness(action)
                } label: {
                    Label(action.actionTitle, systemImage: action.systemImage)
                }
                .buttonStyle(DragonButtonStyle(kind: .primary))
                .accessibilityLabel(action.actionTitle)
                .disabled(model.isDailyWellnessComplete)

                Button {
                    model.spinEmotionWheel()
                } label: {
                    Label("Spin mood", systemImage: "dial.high.fill")
                }
                .buttonStyle(DragonButtonStyle(kind: .secondary))
                .accessibilityLabel("Spin Pikachu's mood")
            }
        }
        .padding(12)
        .background(.black.opacity(0.44), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.22), lineWidth: 1))
        .disabled(model.busy || model.isVoiceListening)
    }

    private var voiceConversationPanel: some View {
        let affirmation = model.currentAffirmation

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.isVoiceListening ? "Listening" : "Voice")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ivory.opacity(0.64))
                    Text(model.voiceStatusLine)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.gold)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                        showingDailyDetails.toggle()
                    }
                } label: {
                    Label(showingDailyDetails ? "Less" : "Routine", systemImage: showingDailyDetails ? "chevron.up" : "sparkles")
                }
                .buttonStyle(DragonButtonStyle(kind: .secondary))
                .frame(width: 126)
                .accessibilityLabel(showingDailyDetails ? "Hide daily routine" : "Show daily routine")
            }

            HStack(spacing: 9) {
                Button {
                    if model.isVoiceListening {
                        model.toggleVoiceConversation()
                    } else {
                        beginVoiceFromExpanded()
                    }
                } label: {
                    Image(systemName: model.isVoiceListening ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(DragonIconButtonStyle(kind: .primary))
                .keyboardShortcut("v", modifiers: [.command, .option])
                .accessibilityLabel(model.isVoiceListening ? "Stop listening and send transcript" : "Start talking to Pikachu")
                .accessibilityHint("Command Option V starts or sends a voice conversation.")
                .disabled(model.busy && !model.isVoiceListening)

                Button {
                    model.playAffirmation()
                } label: {
                    Label("Affirm", systemImage: "sparkles")
                }
                .buttonStyle(DragonButtonStyle(kind: .secondary))
                .accessibilityLabel("Play today's affirmation")
                .accessibilityHint("Reads the current morning, afternoon, evening, or night affirmation.")
                .disabled(model.busy || model.isVoiceListening)
            }

            if showingDailyDetails {
                Text("\(affirmation.title): \(affirmation.line)")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Color.gold.opacity(0.92), in: RoundedRectangle(cornerRadius: 7))
                    .transition(.move(edge: .top).combined(with: .opacity))

                HStack(spacing: 9) {
                    Button {
                        beginVoiceFromExpanded(mode: .dailyCheckIn)
                    } label: {
                        Label("Daily check-in", systemImage: "sun.max.fill")
                    }
                    .buttonStyle(DragonButtonStyle(kind: .secondary))
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .accessibilityLabel("Start daily voice check-in")
                    .accessibilityHint("Starts a guided check-in using today's affirmation.")
                    .disabled(model.busy || model.isVoiceListening)

                    Button {
                        toggleHandsFreeFromExpanded()
                    } label: {
                        Image(systemName: model.handsFreeConversationEnabled ? "pause.fill" : "dot.radiowaves.left.and.right")
                    }
                    .buttonStyle(DragonIconButtonStyle(kind: model.handsFreeConversationEnabled ? .primary : .secondary))
                    .keyboardShortcut("l", modifiers: [.command, .option])
                    .accessibilityLabel(model.handsFreeConversationEnabled ? "Pause hands-free conversation" : "Start hands-free conversation")
                    .accessibilityHint("Realtime voice records short turns, sends them automatically, and listens again after Pikachu replies.")
                    .disabled(model.busy && !model.handsFreeConversationEnabled)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(9)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(model.isVoiceListening ? 0.56 : 0.18), lineWidth: 1))
    }

    private var runtimeStackPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.gold)
                Text("Live local stack")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(0.72))
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                ForEach(model.runtimeStackStatus.chips) { chip in
                    HStack(spacing: 5) {
                        Image(systemName: chip.systemImage)
                            .font(.system(size: 11, weight: .black))
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(chip.title)
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ivory.opacity(0.58))
                                .lineLimit(1)
                            Text(chip.value)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ivory)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(0.11), lineWidth: 1))
                }
            }
        }
        .padding(9)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.16), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live local stack. \(model.runtimeStackStatus.chips.map { "\($0.title) \($0.value)" }.joined(separator: ", "))")
    }

    private var gameActionPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Care")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.64))
            HStack(spacing: 7) {
                Button {
                    model.petDaily()
                } label: {
                    Label("Pet", systemImage: "heart.fill")
                }
                .buttonStyle(DragonButtonStyle(kind: model.mood == .happy ? .primary : .secondary))

                Button {
                    model.nap()
                } label: {
                    Label("Nap", systemImage: "moon.zzz.fill")
                }
                .buttonStyle(DragonButtonStyle(kind: model.mood == .nap ? .primary : .secondary))

                Button {
                    model.hyper()
                } label: {
                    Label("Hyper", systemImage: "bolt.fill")
                }
                .buttonStyle(DragonButtonStyle(kind: model.mood == .hyper ? .primary : .secondary))
            }

            Button {
                model.playNextPetLoop()
            } label: {
                Label(model.nextPetLoopLabel, systemImage: "sparkles")
            }
            .buttonStyle(DragonButtonStyle(kind: .primary))
            .accessibilityLabel("Play the next pet loop")
            .accessibilityHint("Runs the next available bond, errand, wish, home, toy, trick, life, field, or event loop.")
            .frame(maxWidth: .infinity)
        }
        .disabled(model.busy || model.isVoiceListening)
    }

    private var expandedQuickActions: some View {
        HStack(spacing: 7) {
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    showingDemoTools = false
                    model.openLearning()
                }
            } label: {
                Image(systemName: "book.fill")
            }
            .buttonStyle(DragonButtonStyle(kind: .secondary))
            .accessibilityLabel("Open language lessons")
            .disabled(model.busy)

            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    showingDemoTools.toggle()
                }
            } label: {
                Image(systemName: showingDemoTools ? "chevron.up" : "slider.horizontal.3")
            }
            .buttonStyle(DragonButtonStyle(kind: showingDemoTools ? .primary : .secondary))
            .accessibilityLabel(showingDemoTools ? "Hide care tools" : "Show care tools")
            .disabled(model.busy)
        }
        .accessibilityElement(children: .contain)
    }

    private func beginVoiceFromExpanded(mode: VoiceConversationMode = .freeform) {
        // Stay expanded while talking — never collapse to pet-only on mic start.
        model.startVoiceConversation(mode: mode)
    }

    private func toggleHandsFreeFromExpanded() {
        // Stay expanded while talking — never collapse to pet-only on mic start.
        model.toggleHandsFreeConversation()
    }

    private func toggleSingleTurnVoiceFromExpanded() {
        if model.handsFreeConversationEnabled {
            model.toggleHandsFreeConversation()
            return
        }
        if model.isVoiceListening {
            model.toggleVoiceConversation()
        } else {
            beginVoiceFromExpanded()
        }
    }

    private func toggleRealtimeVoiceFromExpanded() {
        toggleHandsFreeFromExpanded()
    }

    private var microphonePermissionNeedsPrompt: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined
    }

    private var modeControls: some View {
        HStack(spacing: 6) {
            modeButton("Chat", mode: .chat) {
                model.openChat()
            }
            modeButton("Learn", mode: .lesson) {
                model.openLearning()
            }
            modeButton("Journal", mode: .journal) {
                model.openJournal()
            }
        }
        .disabled(model.busy)
    }

    private func modeButton(_ label: String, mode: LearningMode, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(DragonButtonStyle(kind: model.learningMode == mode ? .primary : .secondary))
    }

    private func inputRow(isCompact: Bool) -> some View {
        HStack(spacing: 7) {
            TextField("Ask \(model.companionCharacter.title)", text: $customPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: isCompact ? 13 : 20, weight: .semibold))
                .padding(.horizontal, isCompact ? 10 : 12)
                .frame(height: isCompact ? 40 : 58)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(0.12), lineWidth: 1))
                .foregroundStyle(Color.ivory)
                .disabled(model.busy)
                .onSubmit(submitPrompt)
                .accessibilityLabel("Ask Pikachu")
            Button(model.busy ? "..." : "Enter") {
                submitPrompt()
            }
            .buttonStyle(DragonButtonStyle())
            .frame(width: isCompact ? 78 : 104)
            .accessibilityLabel("Send message to Pikachu")
            .disabled(!canSubmit)

            if !isCompact {
                Button {
                    toggleRealtimeVoiceFromExpanded()
                } label: {
                    Image(systemName: model.handsFreeConversationEnabled ? "waveform.circle.fill" : "waveform.circle")
                }
                .buttonStyle(DragonIconButtonStyle(kind: model.handsFreeConversationEnabled ? .primary : .secondary))
                .keyboardShortcut("l", modifiers: [.command, .option])
                .accessibilityLabel(model.handsFreeConversationEnabled ? "Pause realtime voice" : "Start realtime voice")
                .accessibilityHint("Realtime voice listens for short turns and sends after a pause.")
                .disabled(model.busy && !model.handsFreeConversationEnabled)

                Button {
                    toggleSingleTurnVoiceFromExpanded()
                } label: {
                    Image(systemName: model.isVoiceListening && !model.handsFreeConversationEnabled ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(DragonIconButtonStyle(kind: model.isVoiceListening && !model.handsFreeConversationEnabled ? .primary : .secondary))
                .keyboardShortcut("v", modifiers: [.command, .option])
                .accessibilityLabel(model.isVoiceListening && !model.handsFreeConversationEnabled ? "Stop listening and send transcript" : "Start speech to text")
                .accessibilityHint("The mic records one turn and sends it to Pikachu.")
                .disabled(model.busy && !(model.isVoiceListening && !model.handsFreeConversationEnabled))
            }
        }
    }

    private var soundButton: some View {
        Button {
            model.toggleSound()
        } label: {
            Image(systemName: model.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
        }
        .buttonStyle(DragonIconButtonStyle(kind: .secondary))
        .opacity(model.soundEnabled ? 1 : 0.62)
        .accessibilityLabel(model.soundEnabled ? "Mute \(model.companionCharacter.title) sounds" : "Unmute \(model.companionCharacter.title) sounds")
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

enum PetJournalPage: String, CaseIterable {
    case growth
    case moods
    case memories
    case badges
    case rituals
    case streak
    case cards
    case art

    var label: String {
        switch self {
        case .growth:
            return "Grow"
        case .moods:
            return "Mood"
        case .memories:
            return "Memory"
        case .badges:
            return "Badge"
        case .rituals:
            return "Today"
        case .streak:
            return "Week"
        case .cards:
            return "Cards"
        case .art:
            return "Art"
        }
    }
}

struct PetJournalPanel: View {
    @ObservedObject var model: DragonOverlayModel
    @Binding var page: PetJournalPage

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("Pet Journal")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Spacer(minLength: 0)
                Text(model.careLine)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach(PetJournalPage.allCases, id: \.self) { item in
                    Button(item.label) {
                        page = item
                    }
                    .buttonStyle(JournalTabButtonStyle(selected: page == item))
                }
            }

            pageContent
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 216, alignment: .topLeading)
        .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.26), lineWidth: 1))
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .growth:
            journalHero("Growth", value: model.journalGrowthProgress, caption: model.journalGrowthCaption)
            detailLine(model.evolutionLine)
            detailLine(model.loreLine)
            journalHero("Growth Journey", value: model.journalGrowthJourneyProgress, caption: model.journalGrowthJourneyCaption)
            growthJourneyGrid
            artLine(model.journalGrowthJourneySpriteLine)
            journalHero("Bond Timeline", value: model.journalBondTimelineProgress, caption: model.journalBondTimelineCaption)
            bondTimelineGrid
            artLine(model.journalBondTimelineSpriteLine)
            journalHero("Life Scenes", value: model.journalLifeSceneProgress, caption: model.journalLifeSceneCaption)
            lifeSceneGrid
            artLine(model.journalLifeSceneSpriteLine)
            journalHero("Evolution Quests", value: model.journalEvolutionQuestProgress, caption: model.journalEvolutionQuestCaption)
            evolutionQuestGrid
            artLine(model.journalEvolutionQuestSpriteLine)
            detailLine(model.journalArtContextLine)
        case .moods:
            journalHero("Mood Album", value: model.journalMoodProgress, caption: model.journalMoodCaption)
            moodGrid
            journalHero("Emotion Episodes", value: model.journalEmotionEpisodeProgress, caption: model.journalEmotionEpisodeCaption)
            emotionEpisodeGrid
            artLine(model.journalEmotionEpisodeSpriteLine)
            journalHero("Emotion Arcs", value: model.journalEmotionArcProgress, caption: model.journalEmotionArcCaption)
            emotionArcGrid
            artLine(model.journalEmotionArcSpriteLine)
            journalHero("Mood Stories", value: model.journalMoodStoryProgress, caption: model.journalMoodStoryCaption)
            moodStoryGrid
            artLine(model.journalMoodStorySpriteLine)
            journalHero("Feeling Rituals", value: model.journalFeelingRitualProgress, caption: model.journalFeelingRitualCaption)
            feelingRitualGrid
            artLine(model.journalFeelingRitualSpriteLine)
            journalHero("Mood Care", value: model.journalMoodCareProgress, caption: model.journalMoodCareCaption)
            moodCareGrid
            artLine(model.journalMoodCareSpriteLine)
        case .memories:
            journalHero("Memories", value: model.journalMemoryProgress, caption: model.memoryLine)
            memoryList
            journalHero("Field Notes", value: model.journalFieldNoteProgress, caption: model.journalFieldNoteCaption)
            fieldNoteGrid
            artLine(model.journalFieldNoteSpriteLine)
            journalHero("Bond Gestures", value: model.journalAffectionProgress, caption: model.journalAffectionCaption)
            affectionGrid
            artLine(model.journalAffectionSpriteLine)
            journalHero("Home Rooms", value: model.journalHomeProgress, caption: model.journalHomeCaption)
            homeRoomGrid
            artLine(model.journalHomeSpriteLine)
            journalHero("Errand Board", value: model.journalErrandProgress, caption: model.journalErrandCaption)
            errandGrid
            artLine(model.journalErrandSpriteLine)
            journalHero("User Check-ins", value: model.journalUserCheckProgress, caption: model.journalUserCheckCaption)
            userCheckGrid
            artLine(model.journalUserCheckSpriteLine)
            journalHero("Wishbook", value: model.journalWishProgress, caption: model.journalWishCaption)
            wishGrid
            artLine(model.journalWishSpriteLine)
            journalHero("Toybox", value: model.journalToyProgress, caption: model.journalToyCaption)
            toyGrid
            artLine(model.journalToySpriteLine)
            journalHero("Trickbook", value: model.journalTrickProgress, caption: model.journalTrickCaption)
            trickGrid
            artLine(model.journalTrickSpriteLine)
            journalHero("Scout Trips", value: model.journalScoutTripProgress, caption: model.journalScoutTripCaption)
            scoutTripGrid
            artLine(model.journalScoutTripSpriteLine)
            journalHero("Current Stage Life", value: model.journalLifeSceneProgress, caption: model.lifeSceneLine)
            lifeSceneGrid
        case .badges:
            journalHero("Badges", value: model.journalBadgeProgress, caption: model.journalBadgeCaption)
            badgeGrid
            journalHero("Season Trail", value: model.journalSeasonTrailProgress, caption: model.journalSeasonTrailCaption)
            seasonTrailGrid
            artLine(model.journalSeasonTrailSpriteLine)
            journalHero("Care Charms", value: model.journalCharmProgress, caption: model.journalCharmCaption)
            charmGrid
            artLine(model.journalCharmSpriteLine)
        case .rituals:
            journalHero("Today's Ritual", value: model.journalRitualProgress, caption: model.journalRitualCaption)
            journalHero("Spark Exchange", value: model.journalExchangeProgress, caption: model.journalExchangeCaption)
            exchangeBoardGrid
            artLine(model.journalExchangeSpriteLine)
            journalHero("Spark Route", value: model.journalRouteProgress, caption: model.journalRouteCaption)
            sparkRouteGrid
            artLine(model.journalRouteSpriteLine)
            journalHero("Care Windows", value: model.journalCareWindowProgress, caption: model.journalCareWindowCaption)
            careWindowGrid
            artLine(model.journalCareWindowSpriteLine)
            journalHero("Care Chests", value: model.journalCareChestProgress, caption: model.journalCareChestCaption)
            careChestGrid
            artLine(model.journalCareChestSpriteLine)
            detailLine(model.needLine)
            detailLine(model.comboLine)
            detailLine(model.taskLine)
            journalHero("Bond Board", value: model.journalBondBoardProgress, caption: model.journalBondBoardCaption)
            bondContractGrid
            artLine(model.journalBondBoardSpriteLine)
            journalHero("Care Vitals", value: model.journalVitalProgress, caption: model.journalVitalCaption)
            vitalGrid
            artLine(model.journalVitalSpriteLine)
            journalHero("Care Pulses", value: model.journalCarePulseProgress, caption: model.journalCarePulseCaption)
            carePulseGrid
            artLine(model.journalCarePulseSpriteLine)
            journalHero("Ambient Life", value: model.journalAmbientProgress, caption: model.journalAmbientCaption)
            ambientGrid
            artLine(model.journalAmbientSpriteLine)
            journalHero("Field Notes", value: model.journalFieldNoteProgress, caption: model.journalFieldNoteCaption)
            fieldNoteGrid
            artLine(model.journalFieldNoteSpriteLine)
            journalHero("Bond Gestures", value: model.journalAffectionProgress, caption: model.journalAffectionCaption)
            affectionGrid
            artLine(model.journalAffectionSpriteLine)
            journalHero("Home Rooms", value: model.journalHomeProgress, caption: model.journalHomeCaption)
            homeRoomGrid
            artLine(model.journalHomeSpriteLine)
            journalHero("Errand Board", value: model.journalErrandProgress, caption: model.journalErrandCaption)
            errandGrid
            artLine(model.journalErrandSpriteLine)
            journalHero("User Check-ins", value: model.journalUserCheckProgress, caption: model.journalUserCheckCaption)
            userCheckGrid
            artLine(model.journalUserCheckSpriteLine)
            journalHero("Wishbook", value: model.journalWishProgress, caption: model.journalWishCaption)
            wishGrid
            artLine(model.journalWishSpriteLine)
            journalHero("Toybox", value: model.journalToyProgress, caption: model.journalToyCaption)
            toyGrid
            artLine(model.journalToySpriteLine)
            journalHero("Trickbook", value: model.journalTrickProgress, caption: model.journalTrickCaption)
            trickGrid
            artLine(model.journalTrickSpriteLine)
            journalHero("Scout Trips", value: model.journalScoutTripProgress, caption: model.journalScoutTripCaption)
            scoutTripGrid
            artLine(model.journalScoutTripSpriteLine)
            journalHero("Daily Journey", value: model.journalDailyJourneyProgress, caption: model.journalDailyJourneyCaption)
            dailyJourneyGrid
            artLine(model.journalDailyJourneySpriteLine)
            journalHero("Visit Log", value: model.journalVisitProgress, caption: model.journalVisitCaption)
            visitGrid
            artLine(model.journalVisitSpriteLine)
            journalHero("Cheer Rhythm", value: model.journalCheerProgress, caption: model.journalCheerCaption)
            detailLine(model.cheerRhythmLine)
            artLine(model.journalCheerSpriteLine)
            journalHero("Cheer Pings", value: model.journalCheerPingProgress, caption: model.journalCheerPingCaption)
            cheerPingGrid
            artLine(model.journalCheerPingSpriteLine)
            journalHero("Cheer Dialogues", value: model.journalCheerDialogueProgress, caption: model.journalCheerDialogueCaption)
            cheerDialogueGrid
            artLine(model.journalCheerDialogueSpriteLine)
            journalHero("Check-in Types", value: model.journalCheerIntentProgress, caption: model.journalCheerIntentCaption)
            cheerIntentGrid
            artLine(model.journalCheerIntentSpriteLine)
            journalHero("Cheer Memories", value: model.journalCheerMemoryProgress, caption: model.journalCheerMemoryCaption)
            cheerMemoryGrid
            artLine(model.journalCheerMemorySpriteLine)
            journalHero("Cheer Scriptbook", value: model.journalCheerScriptProgress, caption: model.journalCheerScriptCaption)
            cheerScriptGrid
            artLine(model.journalCheerScriptSpriteLine)
            journalHero("Mood Stories", value: model.journalMoodStoryProgress, caption: model.journalMoodStoryCaption)
            moodStoryGrid
            artLine(model.journalMoodStorySpriteLine)
            journalHero("Feeling Rituals", value: model.journalFeelingRitualProgress, caption: model.journalFeelingRitualCaption)
            feelingRitualGrid
            artLine(model.journalFeelingRitualSpriteLine)
            detailLine(model.cipherLine)
        case .streak:
            journalHero("Week Trail", value: model.journalStreakProgress, caption: model.journalStreakCaption)
            streakGrid
            detailLine(model.weeklyLine)
            milestoneGrid
            artLine(model.journalStreakSpriteLine)
            journalHero("Streak Recovery", value: model.journalRecoveryProgress, caption: model.journalRecoveryCaption)
            recoveryGrid
            artLine(model.journalRecoverySpriteLine)
        case .cards:
            journalHero("Upgrade Cards", value: model.journalUpgradeProgress, caption: model.journalUpgradeCaption)
            upgradeDeckGrid
            detailLine(model.upgradeLine)
            artLine(model.journalUpgradeSpriteLine)
            journalHero("Spark Wheel", value: model.journalSparkWheelProgress, caption: model.journalSparkWheelCaption)
            sparkWheelGrid
            artLine(model.journalSparkWheelSpriteLine)
        case .art:
            journalTitleBlock("Sprite Brief", caption: model.journalArtContextLine)
            artLine(model.journalRuntimeSpriteLine)
            artLine(model.journalSpriteLine)
            detailLine(model.journalArtPromptLine)
            detailLine(model.journalPromptLine)
        }
    }

    private func journalHero(_ title: String, value: Double, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(0.92))
                Spacer(minLength: 0)
                Text("\(Int((min(max(value, 0), 1) * 100).rounded()))%")
                    .font(.system(size: 8.8, weight: .black, design: .rounded))
                    .foregroundStyle(Color.gold)
            }
            Text(caption)
                .font(.system(size: 8.6, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            ProgressView(value: min(max(value, 0), 1))
                .progressViewStyle(.linear)
                .tint(Color.gold)
                .frame(height: 4)
        }
    }

    private func journalTitleBlock(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10.5, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.92))
            Text(caption)
                .font(.system(size: 8.6, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var moodGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4), spacing: 3) {
            ForEach(PetFeeling.allCases, id: \.rawValue) { feeling in
                journalChip(feeling.title, isUnlocked: model.emotionAlbumMask & feeling.rawValue != 0)
            }
        }
    }

    private var emotionEpisodeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.emotionEpisodes, id: \.rawValue) { episode in
                let today = model.isEmotionEpisodeSeenToday(episode)
                let unlocked = model.isEmotionEpisodeUnlocked(episode)
                journalChip("\(episode.shortLabel)\(today ? " ✓" : "")", isUnlocked: unlocked || today)
            }
        }
    }

    private var emotionArcGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.emotionArcs, id: \.rawValue) { arc in
                let today = model.isEmotionArcSeenToday(arc)
                let unlocked = model.isEmotionArcUnlocked(arc)
                journalChip("\(arc.shortLabel)\(today ? " ✓" : "")", isUnlocked: unlocked || today)
            }
        }
    }

    private var moodStoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.moodStories, id: \.rawValue) { story in
                let answered = model.isMoodStoryAnswered(story)
                let unlocked = model.isMoodStoryUnlocked(story)
                journalChip("\(story.shortLabel)\(answered ? " ✓" : "")", isUnlocked: answered || unlocked)
            }
        }
    }

    private var feelingRitualGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.feelingRituals, id: \.rawValue) { ritual in
                let answered = model.isFeelingRitualAnswered(ritual)
                let unlocked = model.isFeelingRitualUnlocked(ritual)
                journalChip("\(ritual.shortLabel)\(answered ? " ✓" : "")", isUnlocked: answered || unlocked)
            }
        }
    }

    private var cheerPingGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(PetCheerPing.allCases, id: \.rawValue) { ping in
                let answered = model.isCheerPingAnswered(ping)
                let unlocked = model.isCheerPingUnlocked(ping)
                journalChip("\(ping.shortLabel)\(answered ? " ✓" : "")", isUnlocked: answered || unlocked)
            }
        }
    }

    private var fieldNoteGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.fieldNotes, id: \.rawValue) { note in
                let saved = model.isFieldNoteSavedToday(note)
                let unlocked = model.isFieldNoteUnlocked(note)
                journalChip("\(note.shortLabel)\(saved ? " ✓" : "")", isUnlocked: saved || unlocked)
            }
        }
    }

    private var scoutTripGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 3) {
            ForEach(model.scoutTrips, id: \.rawValue) { trip in
                let returned = model.isScoutTripReturned(trip)
                let unlocked = model.isScoutTripUnlocked(trip)
                let started = model.isScoutTripStarted(trip)
                let suffix = returned ? " ✓" : (started ? " ..." : "")
                journalChip("\(trip.shortLabel)\(suffix)", isUnlocked: returned || unlocked)
            }
        }
    }

    private var affectionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.affectionGestures, id: \.rawValue) { gesture in
                let given = model.isAffectionGiven(gesture)
                let unlocked = model.isAffectionUnlocked(gesture)
                journalChip("\(gesture.shortLabel)\(given ? " ✓" : "")", isUnlocked: given || unlocked)
            }
        }
    }

    private var homeRoomGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.homeRooms, id: \.rawValue) { room in
                let visited = model.isHomeRoomVisited(room)
                let unlocked = model.isHomeRoomUnlocked(room)
                journalChip("\(room.shortLabel)\(visited ? " ✓" : "")", isUnlocked: visited || unlocked)
            }
        }
    }

    private var errandGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.dailyErrands, id: \.rawValue) { errand in
                let done = model.isErrandDone(errand)
                let unlocked = model.isErrandUnlocked(errand)
                journalChip("\(errand.shortLabel)\(done ? " ✓" : "")", isUnlocked: done || unlocked)
            }
        }
    }

    private var userCheckGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.userCheckIns, id: \.rawValue) { checkIn in
                let answered = model.isUserCheckAnswered(checkIn)
                let unlocked = model.isUserCheckUnlocked(checkIn)
                journalChip("\(checkIn.shortLabel)\(answered ? " ✓" : "")", isUnlocked: answered || unlocked)
            }
        }
    }

    private var wishGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.wishes, id: \.rawValue) { wish in
                let fulfilled = model.isWishFulfilled(wish)
                let unlocked = model.isWishUnlocked(wish)
                journalChip("\(wish.shortLabel)\(fulfilled ? " ✓" : "")", isUnlocked: fulfilled || unlocked)
            }
        }
    }

    private var toyGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 3) {
            ForEach(model.toys, id: \.rawValue) { toy in
                let played = model.isToyPlayed(toy)
                let unlocked = model.isToyUnlocked(toy)
                journalChip("\(toy.shortLabel)\(played ? " ✓" : "")", isUnlocked: played || unlocked)
            }
        }
    }

    private var trickGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 3) {
            ForEach(model.tricks, id: \.rawValue) { trick in
                let practiced = model.isTrickPracticed(trick)
                let unlocked = model.isTrickUnlocked(trick)
                journalChip("\(trick.shortLabel)\(practiced ? " ✓" : "")", isUnlocked: practiced || unlocked)
            }
        }
    }

    private var moodCareGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(model.moodCareSteps, id: \.rawValue) { step in
                journalChip(step.shortLabel, isUnlocked: model.isMoodCareStepDone(step))
            }
        }
    }

    private var evolutionQuestGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 3) {
            ForEach(PetEvolutionQuest.allCases, id: \.rawValue) { quest in
                evolutionQuestChip(quest)
            }
        }
    }

    private var lifeSceneGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(model.currentLifeScenes, id: \.rawValue) { scene in
                journalChip(scene.shortLabel, isUnlocked: model.isLifeSceneUnlocked(scene))
            }
        }
    }

    private var growthJourneyGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 3) {
            ForEach(model.growthJourneyStages, id: \.rawValue) { stage in
                journalChip(stage.shortLabel, isUnlocked: model.isGrowthJourneyUnlocked(stage))
            }
        }
    }

    private var bondTimelineGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.bondTimelineChapters, id: \.rawValue) { chapter in
                let saved = model.isBondTimelineSaved(chapter)
                let eligible = model.isBondTimelineEligible(chapter)
                let suffix = saved ? " ✓" : (eligible ? " +" : "")
                journalChip("\(chapter.shortLabel)\(suffix)", isUnlocked: saved || eligible)
            }
        }
    }

    private func evolutionQuestChip(_ quest: PetEvolutionQuest) -> some View {
        let claimed = model.isEvolutionQuestClaimed(quest)
        let complete = model.isEvolutionQuestComplete(quest)
        let progress = Int((model.evolutionQuestProgress(for: quest) * 100).rounded())
        let label = claimed ? "\(quest.shortLabel) ✓" : "\(quest.shortLabel) \(min(100, progress))%"
        return Text(label)
            .font(.system(size: 7.5, weight: .black, design: .rounded))
            .foregroundStyle(claimed ? Color.black : Color.ivory.opacity(complete ? 0.86 : 0.62))
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .frame(height: 18)
            .frame(maxWidth: .infinity)
            .background(claimed ? Color.gold.opacity(0.9) : Color.black.opacity(complete ? 0.44 : 0.3), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ivory.opacity(claimed ? 0 : 0.14), lineWidth: 1))
    }

    private var memoryList: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(PetBondMemory.allCases, id: \.rawValue) { memory in
                compactStatusLine(memory.title, isUnlocked: model.careMemoryMask & memory.rawValue != 0)
            }
        }
    }

    private var badgeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 3) {
            ForEach(PetSeasonEvent.allCases, id: \.rawValue) { event in
                journalChip(event.badgeTitle, isUnlocked: model.seasonBadgeMask & event.rawValue != 0)
            }
        }
    }

    private var seasonTrailGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(model.seasonTrailChapters, id: \.rawValue) { chapter in
                let claimed = model.isSeasonTrailChapterClaimed(chapter)
                let ready = model.isSeasonTrailChapterReady(chapter)
                let saved = model.isSeasonTrailChapterInAlbum(chapter)
                journalChip("\(chapter.shortLabel) \(chapter.title)\(claimed || saved ? " ✓" : "")", isUnlocked: claimed || ready || saved)
            }
        }
    }

    private var charmGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4), spacing: 3) {
            ForEach(PetCareCharm.allCases, id: \.rawValue) { charm in
                journalChip("\(charm.shortLabel) \(charm.title)", isUnlocked: model.careCharmMask & charm.rawValue != 0)
            }
        }
    }

    private var streakGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(model.weeklyTrailChapters, id: \.rawValue) { chapter in
                let unlocked = model.isWeeklyTrailChapterUnlocked(chapter)
                let saved = model.isWeeklyTrailChapterInAlbum(chapter)
                journalChip("\(chapter.shortLabel) \(chapter.title)\(saved ? " ✓" : "")", isUnlocked: unlocked)
            }
        }
    }

    private var milestoneGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 3) {
            ForEach(PetStreakMilestone.allCases, id: \.rawValue) { milestone in
                journalChip("\(milestone.shortLabel) \(milestone.title)", isUnlocked: model.weeklyRewardMask & milestone.rawValue != 0)
            }
        }
    }

    private var recoveryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(model.recoveryScenes, id: \.rawValue) { scene in
                journalChip("\(scene.shortLabel) \(scene.title)", isUnlocked: model.isRecoverySceneUnlocked(scene))
            }
        }
    }

    private var vitalGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(PetCareVital.allCases, id: \.self) { vital in
                vitalChip(vital)
            }
        }
    }

    private var carePulseGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.carePulseVitals, id: \.self) { vital in
                let answered = model.isCarePulseAnswered(vital)
                let unlocked = model.isCarePulseUnlocked(vital)
                journalChip("\(vital.shortLabel)\(answered ? " ✓" : "")", isUnlocked: answered || unlocked)
            }
        }
    }

    private var ambientGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.ambientMoments, id: \.rawValue) { moment in
                let today = model.isAmbientMomentSeenToday(moment)
                let unlocked = model.isAmbientMomentUnlocked(moment)
                journalChip("\(moment.shortLabel)\(today ? " ✓" : "")", isUnlocked: unlocked || today)
            }
        }
    }

    private var sparkRouteGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(model.routeSteps, id: \.rawValue) { step in
                let done = model.isRouteStepDone(step)
                let unlocked = model.isRouteStepUnlocked(step)
                journalChip("\(step.shortLabel)\(done ? " ✓" : "")", isUnlocked: done || unlocked)
            }
        }
    }

    private var careWindowGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 3) {
            ForEach(model.careWindowMoments, id: \.rawValue) { moment in
                let done = model.isCareWindowDone(moment)
                let unlocked = model.isCareWindowUnlocked(moment)
                journalChip("\(moment.shortLabel)\(done ? " ✓" : "")", isUnlocked: done || unlocked)
            }
        }
    }

    private var careChestGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.careChests, id: \.rawValue) { chest in
                let claimed = model.isCareChestClaimed(chest)
                let unlocked = model.isCareChestUnlocked(chest)
                journalChip("\(chest.shortLabel)\(claimed ? " ✓" : "")", isUnlocked: claimed || unlocked)
            }
        }
    }

    private var bondContractGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.bondBoardContracts, id: \.rawValue) { contract in
                bondContractChip(contract)
            }
        }
    }

    private var dailyJourneyGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.dailyJourneyPhases, id: \.rawValue) { phase in
                let answered = model.isDailyJourneyAnswered(phase)
                let unlocked = model.isDailyJourneyUnlocked(phase)
                journalChip("\(phase.shortLabel)\(answered ? " ✓" : "")", isUnlocked: answered || unlocked)
            }
        }
    }

    private var visitGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 3) {
            ForEach(model.visitBeats, id: \.rawValue) { beat in
                let answered = model.isVisitBeatAnswered(beat)
                let unlocked = model.isVisitBeatUnlocked(beat)
                journalChip("\(beat.shortLabel)\(answered ? " ✓" : "")", isUnlocked: answered || unlocked)
            }
        }
    }

    private var exchangeBoardGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.exchangeBoardSteps, id: \.rawValue) { step in
                let done = model.isExchangeBoardStepDone(step)
                let unlocked = model.isExchangeBoardStepUnlocked(step)
                journalChip("\(step.shortLabel)\(done ? " ✓" : "")", isUnlocked: done || unlocked)
            }
        }
    }

    private var cheerDialogueGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(PetCheerDialogue.allCases, id: \.rawValue) { dialogue in
                cheerDialogueChip(dialogue)
            }
        }
    }

    private var cheerIntentGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(PetCheerIntent.allCases, id: \.rawValue) { intent in
                cheerIntentChip(intent)
            }
        }
    }

    private var cheerMemoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(model.cheerMemories, id: \.rawValue) { memory in
                let today = model.isCheerMemorySeenToday(memory)
                let unlocked = model.isCheerMemoryUnlocked(memory)
                journalChip("\(memory.shortLabel)\(today ? " ✓" : "")", isUnlocked: unlocked || today)
            }
        }
    }

    private var cheerScriptGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(model.cheerScripts, id: \.rawValue) { script in
                let answered = model.isCheerScriptAnswered(script)
                let unlocked = model.isCheerScriptUnlocked(script)
                journalChip("\(script.shortLabel)\(answered ? " ✓" : "")", isUnlocked: unlocked || answered)
            }
        }
    }

    private func cheerDialogueChip(_ dialogue: PetCheerDialogue) -> some View {
        let answered = model.isCheerDialogueAnswered(dialogue)
        let unlocked = model.isCheerDialogueUnlocked(dialogue)
        return Text("\(dialogue.shortLabel) \(answered ? "✓" : unlocked ? "•" : "○")")
            .font(.system(size: 7.4, weight: .black, design: .rounded))
            .foregroundStyle(answered ? Color.black : Color.ivory.opacity(unlocked ? 0.78 : 0.62))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .frame(height: 18)
            .frame(maxWidth: .infinity)
            .background(answered ? Color.gold.opacity(0.92) : Color.black.opacity(unlocked ? 0.42 : 0.32), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ivory.opacity(answered ? 0 : 0.12), lineWidth: 1))
    }

    private func cheerIntentChip(_ intent: PetCheerIntent) -> some View {
        let answered = model.isCheerIntentAnswered(intent)
        let unlocked = model.isCheerIntentUnlocked(intent)
        return Text("\(intent.shortLabel) \(answered ? "✓" : unlocked ? "•" : "○")")
            .font(.system(size: 7.4, weight: .black, design: .rounded))
            .foregroundStyle(answered ? Color.black : Color.ivory.opacity(unlocked ? 0.78 : 0.62))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .frame(height: 18)
            .frame(maxWidth: .infinity)
            .background(answered ? Color.gold.opacity(0.92) : Color.black.opacity(unlocked ? 0.42 : 0.32), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ivory.opacity(answered ? 0 : 0.12), lineWidth: 1))
    }

    private func bondContractChip(_ contract: PetBondContract) -> some View {
        let done = model.isBondContractDone(contract)
        let unlocked = model.isBondContractUnlocked(contract)
        return Text("\(contract.shortLabel) \(done ? "✓" : unlocked ? "•" : "○")")
            .font(.system(size: 7.4, weight: .black, design: .rounded))
            .foregroundStyle(done ? Color.black : Color.ivory.opacity(unlocked ? 0.78 : 0.62))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .frame(height: 18)
            .frame(maxWidth: .infinity)
            .background(done ? Color.gold.opacity(0.92) : Color.black.opacity(unlocked ? 0.42 : 0.32), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ivory.opacity(done ? 0 : 0.12), lineWidth: 1))
    }

    private func vitalChip(_ vital: PetCareVital) -> some View {
        let level = model.vitalLevel(for: vital)
        let healthy = level >= 3
        return Text("\(vital.shortLabel) \(level)/\(model.maxVitalLevel)")
            .font(.system(size: 7.5, weight: .black, design: .rounded))
            .foregroundStyle(healthy ? Color.black : Color.ivory.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .frame(height: 18)
            .frame(maxWidth: .infinity)
            .background(healthy ? Color.gold.opacity(0.9) : Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ivory.opacity(healthy ? 0 : 0.14), lineWidth: 1))
    }

    private var upgradeDeckGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 3) {
            ForEach(model.upgradeDeckCards) { card in
                upgradeCardChip(card)
            }
        }
    }

    private var sparkWheelGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 3) {
            ForEach(model.sparkWheelCycles, id: \.rawValue) { cycle in
                let claimed = model.isSparkWheelClaimed(cycle)
                let started = model.isSparkWheelStarted(cycle)
                let unlocked = model.isSparkWheelUnlocked(cycle)
                let suffix = claimed ? " ✓" : (started ? " •" : "")
                journalChip("\(cycle.shortLabel)\(suffix)", isUnlocked: claimed || unlocked || started)
            }
        }
    }

    private func upgradeCardChip(_ card: PetUpgradeDeckCard) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(card.kind.shortName) Lv \(card.level)")
                .font(.system(size: 7.5, weight: .black, design: .rounded))
                .foregroundStyle(card.isUnlocked ? Color.black : Color.ivory.opacity(0.7))
                .lineLimit(1)
            Text("next \(card.nextCost)")
                .font(.system(size: 6.6, weight: .black, design: .rounded))
                .foregroundStyle(card.isUnlocked ? Color.black.opacity(0.7) : Color.ivory.opacity(0.48))
                .lineLimit(1)
        }
        .frame(height: 27)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 5)
        .background(card.isUnlocked ? Color.gold.opacity(0.92) : Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ivory.opacity(card.isUnlocked ? 0 : 0.12), lineWidth: 1))
    }

    private func journalChip(_ text: String, isUnlocked: Bool) -> some View {
        Text("\(text) \(isUnlocked ? "✓" : "○")")
            .font(.system(size: 7.5, weight: .black, design: .rounded))
            .foregroundStyle(isUnlocked ? Color.black : Color.ivory.opacity(0.66))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .frame(height: 18)
            .frame(maxWidth: .infinity)
            .background(isUnlocked ? Color.gold.opacity(0.92) : Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ivory.opacity(isUnlocked ? 0 : 0.12), lineWidth: 1))
    }

    private func compactStatusLine(_ text: String, isUnlocked: Bool) -> some View {
        Text("\(isUnlocked ? "✓" : "○") \(text)")
            .font(.system(size: 8.6, weight: .black, design: .rounded))
            .foregroundStyle(isUnlocked ? Color.gold : Color.ivory.opacity(0.62))
            .lineLimit(1)
            .minimumScaleFactor(0.66)
    }

    private func detailLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8.8, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ivory.opacity(0.7))
            .lineLimit(2)
            .minimumScaleFactor(0.58)
    }

    private func artLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8.8, weight: .black, design: .monospaced))
            .foregroundStyle(Color.gold.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.46)
    }
}

struct LanguageCoachPanel: View {
    @ObservedObject var coach: LanguageCoachStore
    let onReward: (LanguagePracticeReward) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            packPicker
            Text(coach.progressLine)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold)
                .lineLimit(2)
            lessonCard
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 468, alignment: .topLeading)
        .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.26), lineWidth: 1))
    }

    private var packPicker: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            ForEach(coach.packs) { pack in
                Button {
                    coach.selectPack(pack)
                } label: {
                    Text(pack.nativeTitle)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(coach.selectedPackID == pack.id ? Color.black : Color.ivory)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                        .frame(maxWidth: .infinity, minHeight: 58)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(coach.stepTitle)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(1)
            stepContent
            Text(coach.feedback)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.78))
                .lineLimit(3)
                .frame(minHeight: 68, alignment: .topLeading)
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
            Text("Language spark logged for today.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory)
                .lineLimit(2)
            Button("Review Again") {
                coach.restartLesson()
            }
            .buttonStyle(DragonButtonStyle())
        }
    }

    private var phraseBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(coach.currentCard.target)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.52)
            Text(coach.currentCard.romanization)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(coach.currentCard.english)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.88))
                .lineLimit(1)
            Text(coach.currentCard.pronunciationTip)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(3)
        }
        .padding(12)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.ivory.opacity(0.12), lineWidth: 1))
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
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(Color.ivory)
            .lineLimit(3)
            .frame(minHeight: 70, alignment: .bottomLeading)
    }

    private func lessonChoice(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .lineLimit(2)
        }
        .buttonStyle(LanguageChoiceButtonStyle())
    }
}

struct AudioWaveView: View {
    let state: VoiceVisualState
    let compact: Bool

    @State private var pulsing = false

    private var barCount: Int { compact ? 5 : 7 }

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 3 : 4) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(color(for: state).opacity(opacity(for: index)))
                    .frame(width: compact ? 4 : 5, height: height(for: index))
            }
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 4 : 5)
        .background(.black.opacity(0.58), in: Capsule())
        .overlay(Capsule().stroke(color(for: state).opacity(0.5), lineWidth: 1))
        .onAppear {
            updatePulse()
        }
        .onChange(of: state) {
            updatePulse()
        }
        .onDisappear {
            pulsing = false
        }
        .accessibilityLabel("\(state.title) audio wave")
    }

    private var isAudioActive: Bool {
        state == .listening || state == .speaking
    }

    private func updatePulse() {
        if isAudioActive {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                pulsing = false
            }
        }
    }

    private func height(for index: Int) -> CGFloat {
        let base: CGFloat = compact ? 8 : 10
        let spread: CGFloat = compact ? 10 : 14
        let wave = (index % 3 == 1) == pulsing
        let stateBoost: CGFloat
        switch state {
        case .listening:
            stateBoost = 1.0
        case .transcribing, .thinking:
            stateBoost = 0.72
        case .speaking:
            stateBoost = 1.18
        case .idle:
            stateBoost = 0.2
        }
        return base + (wave ? spread : spread * 0.34) * stateBoost
    }

    private func opacity(for index: Int) -> Double {
        if state == .idle { return 0.32 }
        return pulsing == (index.isMultiple(of: 2)) ? 0.96 : 0.58
    }

    private func color(for state: VoiceVisualState) -> Color {
        switch state {
        case .listening:
            return .electricBlue
        case .transcribing, .thinking:
            return .gold
        case .speaking:
            return .sparkLight
        case .idle:
            return .ivory
        }
    }
}

struct ConfettiBurstView: View {
    let trigger: Int

    private struct Piece: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let drop: CGFloat
        let color: Color
        let size: CGFloat
        let spin: Double
    }

    @State private var pieces: [Piece] = []
    @State private var animate = false

    private let palette: [Color] = [.gold, .electricBlue, .sparkLight, .ivory, .orange, .green]

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 1.7)
                    .rotationEffect(.degrees(animate ? piece.spin : 0))
                    .offset(
                        x: animate ? CGFloat(cos(piece.angle)) * piece.distance : 0,
                        y: animate ? CGFloat(sin(piece.angle)) * piece.distance + piece.drop : 0
                    )
                    .opacity(animate ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) {
            fire()
        }
    }

    private func fire() {
        pieces = (0..<28).map { _ in
            Piece(
                angle: Double.random(in: 0...(2 * Double.pi)),
                distance: CGFloat.random(in: 55...150),
                drop: CGFloat.random(in: 30...90),
                color: palette.randomElement() ?? .gold,
                size: CGFloat.random(in: 5...9),
                spin: Double.random(in: -260...260)
            )
        }
        animate = false
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 1.15)) {
                animate = true
            }
        }
    }
}

final class TransparentVideoNSView: NSView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var loopObserver: NSObjectProtocol?
    private var endObserver: NSObjectProtocol?
    private var currentResource: String?
    var onFinished: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }

    func play(resource: String, loop: Bool) {
        guard currentResource != resource else { return }
        currentResource = resource
        cleanup()
        guard let url = Bundle.module.url(forResource: resource, withExtension: "mov") else {
            onFinished?()
            return
        }
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.actionAtItemEnd = loop ? .none : .pause
        let avLayer = AVPlayerLayer(player: avPlayer)
        avLayer.videoGravity = .resizeAspectFill
        avLayer.backgroundColor = NSColor.clear.cgColor
        avLayer.isOpaque = false
        avLayer.frame = bounds
        layer?.addSublayer(avLayer)
        player = avPlayer
        playerLayer = avLayer
        if loop {
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { [weak avPlayer] _ in
                avPlayer?.seek(to: .zero)
                avPlayer?.play()
            }
        } else {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { [weak self] _ in
                self?.onFinished?()
            }
        }
        avPlayer.play()
    }

    private func cleanup() {
        if let loopObserver { NotificationCenter.default.removeObserver(loopObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        loopObserver = nil
        endObserver = nil
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }

    deinit { cleanup() }
}

struct TransparentVideoView: NSViewRepresentable {
    let resource: String
    var loop: Bool = false
    var onFinished: (() -> Void)? = nil

    func makeNSView(context: Context) -> TransparentVideoNSView {
        let view = TransparentVideoNSView()
        view.onFinished = onFinished
        view.play(resource: resource, loop: loop)
        return view
    }

    func updateNSView(_ nsView: TransparentVideoNSView, context: Context) {
        nsView.onFinished = onFinished
        nsView.play(resource: resource, loop: loop)
    }
}

struct ThinkingDotsView: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.32, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gold)
                    .frame(width: 7, height: 7)
                    .opacity(phase == index ? 1.0 : 0.32)
                    .scaleEffect(phase == index ? 1.25 : 0.8)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.28)) {
                phase = (phase + 1) % 3
            }
        }
        .accessibilityLabel("Thinking")
    }
}

struct AnimatedPetSprite: View {
    let character: CompanionCharacter
    let stage: PetGrowthStage
    let mood: PetMood
    let size: CGFloat

    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let image = PetSpriteSheet.image(character: character, stage: stage, mood: mood, frame: frameIndex) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .contentShape(PetHoverShape())
        .onReceive(timer) { _ in
            frameIndex = (frameIndex + 1) % mood.frameSequence.count
        }
        .onChange(of: mood) {
            frameIndex = 0
        }
        .onChange(of: stage) {
            frameIndex = 0
        }
        .onChange(of: character) {
            frameIndex = 0
        }
    }
}

struct PetHoverShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let body = CGRect(
            x: rect.minX + rect.width * 0.18,
            y: rect.minY + rect.height * 0.16,
            width: rect.width * 0.54,
            height: rect.height * 0.74
        )
        path.addEllipse(in: body)

        let head = CGRect(
            x: rect.minX + rect.width * 0.21,
            y: rect.minY + rect.height * 0.03,
            width: rect.width * 0.48,
            height: rect.height * 0.42
        )
        path.addEllipse(in: head)

        var leftEar = Path()
        leftEar.move(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.16))
        leftEar.addLine(to: CGPoint(x: rect.minX + rect.width * 0.23, y: rect.minY + rect.height * 0.00))
        leftEar.addLine(to: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.minY + rect.height * 0.15))
        leftEar.closeSubpath()
        path.addPath(leftEar)

        var rightEar = Path()
        rightEar.move(to: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.15))
        rightEar.addLine(to: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.03))
        rightEar.addLine(to: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.23))
        rightEar.closeSubpath()
        path.addPath(rightEar)

        var tail = Path()
        tail.move(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.34))
        tail.addLine(to: CGPoint(x: rect.minX + rect.width * 0.98, y: rect.minY + rect.height * 0.18))
        tail.addLine(to: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.49))
        tail.addLine(to: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.55))
        tail.closeSubpath()
        path.addPath(tail)

        return path
    }
}

@MainActor
enum PetSpriteSheet {
    static let frameCount = 12
    static var externalAssetDirectory: URL?
    private static var cache: [String: [NSImage]] = [:]

    static func image(character: CompanionCharacter, stage: PetGrowthStage, mood: PetMood, frame: Int) -> NSImage? {
        let frames = frames(character: character, stage: stage, mood: mood)
        guard !frames.isEmpty else { return nil }
        let sequence = mood.frameSequence
        let frameNumber = sequence[frame % sequence.count]
        return frames[frameNumber % frames.count]
    }

    static func resolvedAssetName(character: CompanionCharacter, stage: PetGrowthStage, mood: PetMood) -> String {
        let candidates = character.spriteCandidates(stage: stage, mood: mood)
            + mood.spriteCandidates(stage: stage)
            + [mood.fallbackAssetName]
        return candidates.first { assetURL(for: $0) != nil }
            ?? mood.fallbackAssetName
    }

    private static func frames(character: CompanionCharacter, stage: PetGrowthStage, mood: PetMood) -> [NSImage] {
        let assetName = resolvedAssetName(character: character, stage: stage, mood: mood)
        let cacheKey = "\(character.rawValue):\(assetName)"
        if let cached = cache[cacheKey] {
            return cached
        }
        guard
            let url = assetURL(for: assetName),
            let sheet = NSImage(contentsOf: url),
            let cgImage = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            cache[cacheKey] = []
            return []
        }

        let layout = sheetLayout(width: cgImage.width, height: cgImage.height)
        let frameWidth = cgImage.width / layout.columns
        let frameHeight = cgImage.height / layout.rows
        let shouldCleanBackground = isExternalAsset(url)
        let frames = (0..<min(frameCount, layout.columns * layout.rows)).compactMap { index -> NSImage? in
            let column = index % layout.columns
            let row = index / layout.columns
            let rect = CGRect(x: column * frameWidth, y: row * frameHeight, width: frameWidth, height: frameHeight)
            guard let cropped = cgImage.cropping(to: rect) else { return nil }
            let frameImage = shouldCleanBackground ? (cleanExternalFrameBackground(cropped) ?? cropped) : cropped
            return NSImage(
                cgImage: frameImage,
                size: NSSize(width: CGFloat(frameWidth), height: CGFloat(frameHeight))
            )
        }
        cache[cacheKey] = frames
        return frames
    }

    private static func assetURL(for assetName: String) -> URL? {
        if let bundleURL = Bundle.module.url(forResource: assetName, withExtension: "png") {
            return bundleURL
        }
        if let externalURL = externalAssetDirectory?.appending(path: "\(assetName).png"),
           FileManager.default.fileExists(atPath: externalURL.path) {
            return externalURL
        }
        return nil
    }

    private static func isExternalAsset(_ url: URL) -> Bool {
        guard let externalAssetDirectory else { return false }
        return url.standardizedFileURL.path.hasPrefix(externalAssetDirectory.standardizedFileURL.path)
    }

    private static func cleanExternalFrameBackground(_ cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 2, height > 2 else { return cgImage }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        let didDraw = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didDraw else { return nil }

        let background = backgroundSample(pixels: pixels, width: width, height: height)
        var transparent = [Bool](repeating: false, count: width * height)
        var stack: [Int] = []

        func enqueue(_ x: Int, _ y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else { return }
            let position = y * width + x
            guard !transparent[position],
                  isExternalBackgroundPixel(
                    pixels: pixels,
                    position: position,
                    background: background,
                    strict: true
                  ) else {
                return
            }
            transparent[position] = true
            stack.append(position)
        }

        for x in 0..<width {
            enqueue(x, 0)
            enqueue(x, height - 1)
        }
        for y in 0..<height {
            enqueue(0, y)
            enqueue(width - 1, y)
        }

        while let position = stack.popLast() {
            let x = position % width
            let y = position / width
            enqueue(x - 1, y)
            enqueue(x + 1, y)
            enqueue(x, y - 1)
            enqueue(x, y + 1)
        }

        var softened = transparent
        for y in 0..<height {
            for x in 0..<width {
                let position = y * width + x
                guard !transparent[position],
                      isExternalBackgroundPixel(
                        pixels: pixels,
                        position: position,
                        background: background,
                        strict: false
                      ) else {
                    continue
                }
                let touchesTransparent =
                    (x > 0 && transparent[position - 1])
                    || (x + 1 < width && transparent[position + 1])
                    || (y > 0 && transparent[position - width])
                    || (y + 1 < height && transparent[position + width])
                if touchesTransparent {
                    softened[position] = true
                }
            }
        }

        for position in 0..<softened.count where softened[position] {
            let offset = position * bytesPerPixel
            pixels[offset] = 0
            pixels[offset + 1] = 0
            pixels[offset + 2] = 0
            pixels[offset + 3] = 0
        }

        return pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return nil
            }
            return context.makeImage()
        }
    }

    private static func backgroundSample(
        pixels: [UInt8],
        width: Int,
        height: Int
    ) -> (r: Double, g: Double, b: Double) {
        let inset = max(0, min(6, min(width, height) / 28))
        let points = [
            (inset, inset),
            (width - 1 - inset, inset),
            (inset, height - 1 - inset),
            (width - 1 - inset, height - 1 - inset),
            (width / 2, inset),
            (width / 2, height - 1 - inset),
            (inset, height / 2),
            (width - 1 - inset, height / 2)
        ]
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var count = 0.0
        for point in points {
            let x = min(max(point.0, 0), width - 1)
            let y = min(max(point.1, 0), height - 1)
            let offset = (y * width + x) * 4
            guard pixels[offset + 3] > 0 else { continue }
            red += Double(pixels[offset])
            green += Double(pixels[offset + 1])
            blue += Double(pixels[offset + 2])
            count += 1
        }
        guard count > 0 else { return (255, 255, 255) }
        return (red / count, green / count, blue / count)
    }

    private static func isExternalBackgroundPixel(
        pixels: [UInt8],
        position: Int,
        background: (r: Double, g: Double, b: Double),
        strict: Bool
    ) -> Bool {
        let offset = position * 4
        guard pixels[offset + 3] > 0 else { return false }

        let red = Double(pixels[offset])
        let green = Double(pixels[offset + 1])
        let blue = Double(pixels[offset + 2])
        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let saturation = (maxChannel - minChannel) / max(maxChannel, 1)
        let distance = sqrt(
            pow(red - background.r, 2)
            + pow(green - background.g, 2)
            + pow(blue - background.b, 2)
        )

        let petYellow = red > 130 && green > 88 && blue < 155 && red > blue + 32 && green > blue + 8
        let petRed = red > 140 && green < 150 && blue < 150 && red > green + 18
        let warmPetShadow = red > 85 && green > 45 && green < 150 && blue < 130 && red > blue + 16 && saturation > 0.17
        if petYellow || petRed || warmPetShadow {
            return false
        }

        let lightNeutral = maxChannel > 128 && saturation < 0.24
        let sheetGridLine = maxChannel > 54 && maxChannel < 188 && saturation < 0.18
        if strict {
            return distance < 48 || (distance < 82 && lightNeutral) || (distance < 170 && sheetGridLine)
        }
        return distance < 72 || (distance < 104 && lightNeutral) || (distance < 190 && sheetGridLine)
    }

    private static func sheetLayout(width: Int, height: Int) -> (columns: Int, rows: Int) {
        let aspect = Double(width) / Double(max(1, height))
        if aspect > 6.0 {
            return (frameCount, 1)
        }
        return (6, 2)
    }
}

struct DragonButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case danger
    }

    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .background(background, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(stroke, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
    }

    private var foreground: Color {
        switch kind {
        case .primary:
            return .black
        case .secondary, .danger:
            return .ivory
        }
    }

    private var background: Color {
        switch kind {
        case .primary:
            return .gold
        case .secondary:
            return .black.opacity(0.34)
        case .danger:
            return .dangerRed.opacity(0.84)
        }
    }

    private var stroke: Color {
        switch kind {
        case .primary:
            return .clear
        case .secondary:
            return .ivory.opacity(0.18)
        case .danger:
            return .ivory.opacity(0.24)
        }
    }
}

struct DragonMiniButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9.4, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? Color.black : Color.ivory)
            .frame(height: 24)
            .frame(maxWidth: .infinity)
            .background(kind == .primary ? Color.gold : Color.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(kind == .primary ? 0 : 0.16), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
    }
}

struct DragonIconMiniButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? Color.black : Color.ivory)
            .frame(width: 24, height: 24)
            .background(kind == .primary ? Color.gold : Color.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(kind == .primary ? 0 : 0.16), lineWidth: 1))
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
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? Color.black : Color.ivory)
            .frame(width: 44, height: 44)
            .background(kind == .primary ? Color.gold : Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(kind == .primary ? 0 : 0.18), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
    }
}

struct MiniPanelButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case danger
    }

    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .black, design: .rounded))
            .foregroundStyle(kind == .primary ? Color.black : Color.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .background(kind == .primary ? Color.gold : Color.dangerRed.opacity(0.84), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(kind == .primary ? 0 : 0.22), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
    }
}

struct HeaderPillButtonStyle: ButtonStyle {
    enum Kind {
        case secondary
        case danger
    }

    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .black, design: .rounded))
            .foregroundStyle(Color.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(width: kind == .danger ? 76 : 66, height: 40)
            .background(kind == .danger ? Color.dangerRed.opacity(0.84) : Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(kind == .danger ? 0.24 : 0.18), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
    }
}

struct LanguageChoiceButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .black, design: .rounded))
            .foregroundStyle(Color.ivory)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .frame(minHeight: 62)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ivory.opacity(0.18), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
    }
}

struct JournalTabButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9.5, weight: .black, design: .rounded))
            .foregroundStyle(selected ? Color.black : Color.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.gold : Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ivory.opacity(selected ? 0 : 0.16), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48)
    }
}

struct RuntimeStackStatus: Equatable {
    let brain: String
    let stt: String
    let frames: String
    let voice: String

    static let detecting = RuntimeStackStatus(
        brain: "Brain ...",
        stt: "STT ...",
        frames: "Frames ...",
        voice: "Voice ..."
    )

    var chips: [RuntimeStackChip] {
        [
            RuntimeStackChip(title: "Brain", value: brain, systemImage: "cpu.fill"),
            RuntimeStackChip(title: "STT", value: stt, systemImage: "waveform"),
            RuntimeStackChip(title: "Frames", value: frames, systemImage: "dot.radiowaves.left.and.right"),
            RuntimeStackChip(title: "Voice", value: voice, systemImage: "speaker.wave.2.fill")
        ]
    }
}

struct RuntimeStackChip: Identifiable, Equatable {
    let title: String
    let value: String
    let systemImage: String
    var id: String { title }
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

    func runtimeStackStatus() async -> RuntimeStackStatus {
        let environment = ProcessInfo.processInfo.environment
        async let stt = Self.sidecarLabel(
            rawURL: environment["POCKETDM_PIKA_STT_URL"],
            defaultLabel: environment["POCKETDM_PIKA_STT_URL"] == nil ? "macOS" : "STT",
            value: { health in
                if health.backend == "faster-whisper" { return "Whisper" }
                return health.backend?.capitalized ?? "STT"
            }
        )
        async let frames = Self.sidecarLabel(
            rawURL: environment["POCKETDM_REALTIME_STT_URL"],
            defaultLabel: environment["POCKETDM_REALTIME_STT_URL"] == nil ? "Off" : "Frames",
            value: { health in
                guard let model = health.model?.lowercased() else {
                    return health.backend == "stub" ? "Demo" : "Frames"
                }
                if model.contains("nemotron") {
                    return health.backend == "stub" ? "ASR stub" : "Nemotron"
                }
                return "Frames"
            }
        )
        async let voice = Self.sidecarLabel(
            rawURL: environment["POCKETDM_PIKA_TTS_URL"],
            defaultLabel: environment["POCKETDM_PIKA_TTS_URL"] == nil ? "Chirp" : "Voice",
            value: { health in
                if health.backend == "voxcpm" { return "VoxCPM" }
                if health.backend == "stub" { return "Chirp" }
                return health.backend?.capitalized ?? "Voice"
            }
        )
        async let brain = Self.llamaModelLabel(environment: environment)

        return RuntimeStackStatus(
            brain: await brain,
            stt: await stt,
            frames: await frames,
            voice: await voice
        )
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

    private static func brainLabel(environment: [String: String]) -> String {
        let model = environment["POCKETDM_LLAMA_SERVER_MODEL"]
            ?? environment["POCKETDM_ASSISTANT_LLAMA_MODEL"]
            ?? environment["POCKETDM_LLAMA_MODEL"]
            ?? environment["POCKETDM_ASSISTANT_MODEL"]
            ?? ""
        return brainLabel(for: model, environment: environment)
    }

    private static func brainLabel(for model: String, environment: [String: String]) -> String {
        let lowercased = model.lowercased()
        if lowercased.contains("minicpm5") { return "MiniCPM5" }
        if lowercased.contains("qwen") { return "Qwen" }
        if lowercased.contains("gemma") { return "Gemma" }
        if lowercased.contains("llama") { return "llama.cpp" }
        if environment["POCKETDM_LLAMA_SERVER_URL"] != nil || environment["POCKETDM_ASSISTANT_LLAMA_URL"] != nil {
            return model.isEmpty ? "Local LLM" : model
        }
        return "Rules"
    }

    private static func llamaModelLabel(environment: [String: String]) async -> String {
        let rawURL = environment["POCKETDM_LLAMA_SERVER_URL"] ?? environment["POCKETDM_ASSISTANT_LLAMA_URL"]
        guard let rawURL, let modelsURL = modelsEndpoint(from: rawURL) else {
            return brainLabel(environment: environment)
        }
        do {
            var request = URLRequest(url: modelsURL)
            request.timeoutInterval = 0.9
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return brainLabel(environment: environment)
            }
            let models = try JSONDecoder().decode(LocalModelListResponse.self, from: data)
            guard let model = models.data.first?.id else {
                return brainLabel(environment: environment)
            }
            return brainLabel(for: model, environment: environment)
        } catch {
            return brainLabel(environment: environment)
        }
    }

    private static func sidecarLabel(
        rawURL: String?,
        defaultLabel: String,
        value: @escaping (SidecarHealthResponse) -> String
    ) async -> String {
        guard let rawURL,
              let healthURL = healthEndpoint(from: rawURL) else {
            return defaultLabel
        }
        do {
            var request = URLRequest(url: healthURL)
            request.timeoutInterval = 0.9
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return "\(defaultLabel) cold"
            }
            let health = try JSONDecoder().decode(SidecarHealthResponse.self, from: data)
            return value(health)
        } catch {
            return "\(defaultLabel) cold"
        }
    }

    private static func healthEndpoint(from rawURL: String) -> URL? {
        guard var components = URLComponents(string: rawURL) else { return nil }
        if components.scheme == "ws" {
            components.scheme = "http"
        } else if components.scheme == "wss" {
            components.scheme = "https"
        }
        let path = components.path
        if path.hasSuffix("/health") {
            return components.url
        }
        if path.hasSuffix("/tts")
            || path.hasSuffix("/transcribe")
            || path.hasSuffix("/transcribe-file")
            || path.hasSuffix("/ws/transcribe") {
            var parts = path.split(separator: "/").map(String.init)
            if parts.suffix(2) == ["ws", "transcribe"] {
                parts.removeLast(2)
            } else {
                parts.removeLast()
            }
            components.path = "/" + (parts + ["health"]).joined(separator: "/")
        } else {
            components.path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty
                ? "/health"
                : "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/health"
        }
        return components.url
    }

    private static func modelsEndpoint(from rawURL: String) -> URL? {
        guard var components = URLComponents(string: rawURL) else { return nil }
        components.path = "/v1/models"
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

private struct LocalModelListResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

private struct SidecarHealthResponse: Decodable {
    let backend: String?
    let loaded: Bool?
    let model: String?
    let fallback_backend: String?
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

private extension URL {
    func deleteQuietly() {
        try? FileManager.default.removeItem(at: self)
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendMultipartBoundary(_ boundary: String, closing: Bool = false) {
        append("--\(boundary)\(closing ? "--" : "")\r\n")
    }
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
    static let dangerRed = Color(red: 0.72, green: 0.18, blue: 0.16)
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
