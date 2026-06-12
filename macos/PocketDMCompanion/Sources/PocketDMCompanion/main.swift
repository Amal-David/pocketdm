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
    private static let maxEnergy = 5
    private static let energyRechargeSeconds: TimeInterval = 30 * 60
    private static let passiveSparkSeconds: TimeInterval = 15 * 60
    private static let cheerCooldownSeconds: TimeInterval = 2 * 60 * 60
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
    @Published var minimized = UserDefaults.standard.object(forKey: DragonOverlayModel.petOnlyKey) as? Bool ?? true
    @Published var soundEnabled = UserDefaults.standard.object(forKey: DragonOverlayModel.soundEnabledKey) as? Bool ?? true
    @Published var busy = false
    @Published var mood: PetMood = .idle
    @Published var learningMode: LearningMode = .chat
    @Published var companionHP = UserDefaults.standard.object(forKey: DragonOverlayModel.companionHPKey) as? Int ?? 3
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
    @Published var cheerBubble: String?

    let languageCoach = LanguageCoachStore()

    private let client: PocketDMClient
    private let launcher: GameLauncher
    private let soundPlayer = PetSoundPlayer()
    private var moodTask: Task<Void, Never>?
    private var energyTask: Task<Void, Never>?
    private var cheerTask: Task<Void, Never>?
    private var lastEnergyAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastEnergyAtKey)
    private var passiveSparkAt = UserDefaults.standard.double(forKey: DragonOverlayModel.passiveSparkAtKey)
    init(client: PocketDMClient, launcher: GameLauncher) {
        self.client = client
        self.launcher = launcher
        if lastEnergyAt == 0 {
            lastEnergyAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(lastEnergyAt, forKey: Self.lastEnergyAtKey)
        }
        if passiveSparkAt == 0 {
            passiveSparkAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(passiveSparkAt, forKey: Self.passiveSparkAtKey)
        }
        syncDailyCombo()
        rechargeEnergy()
        let collected = collectPassiveSparks()
        if collected > 0 {
            message = "Welcome back. Pikachu gathered \(collected) Sparks while you were away."
        }
        startEnergyLoop()
        startCheerLoop()
    }

    func refreshHealth() async {
        for attempt in 0..<8 {
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
        markCombo(.open)
        launcher.openGame()
    }

    func setMinimized(_ value: Bool) {
        guard minimized != value else { return }
        minimized = value
        if !value {
            let collected = collectPassiveSparks()
            if collected > 0 {
                message = "Welcome back. Pikachu gathered \(collected) passive Sparks."
            }
        }
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
        message = "Pikachu perks up. Joy is high and it is ready for a quest or a quick lesson."
        lastRequest = "Mood"
        play(.happy)
        setMood(.happy, duration: 1.6)
    }

    func nap() {
        message = "Pikachu curls up for a tiny recharge. It will keep watch quietly."
        lastRequest = "Mood"
        play(.nap)
        setMood(.nap, duration: 2.4)
    }

    func hyper() {
        message = "Pikachu is buzzing with energy. Great moment to ask for a hint or practice a phrase."
        lastRequest = "Mood"
        earnSparkDust(1)
        markCombo(.hyper)
        play(.hyper)
        setMood(.hyper, duration: 1.5)
    }

    func toggleLearning() {
        learningMode = learningMode == .lesson ? .chat : .lesson
        if learningMode == .lesson {
            lastRequest = "Learn"
            message = "Lesson mode opened. Pick a pack, listen once, slow it down, then quiz for Joy."
            markCombo(.learn)
            play(.open)
            languageCoach.speakCurrent()
            setMood(.happy, duration: 1.2)
        } else {
            lastRequest = ""
            message = "Back to chat. Ask for a hint, check status, or pet for today's bond spark."
            play(.minimize)
        }
    }

    func applyLanguageReward(_ reward: LanguagePracticeReward) {
        lastRequest = "Language"
        message = reward.message
        if reward.correct {
            happiness = min(5, happiness + 1)
            earnSparkDust(reward.dailyBond ? 8 : 3)
            if reward.dailyBond {
                companionHP = min(10, companionHP + 1)
            }
            markCombo(.learn)
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
        cheerBubble = nil
        rechargeEnergy()
        let today = Self.dayFormatter.string(from: Date())
        if lastPetDay == today {
            happiness = min(5, happiness + 1)
            let energyBonus = spendEnergy() ? " Energy -1." : " Energy is recharging."
            earnSparkDust(2)
            message = "Already cared for today. Pikachu still leans in. Joy +1, Sparks +2.\(energyBonus)"
        } else {
            companionHP = min(10, companionHP + 1)
            happiness = 5
            petStreak += 1
            lastPetDay = today
            _ = spendEnergy()
            earnSparkDust(15)
            message = "Daily care complete. Bond HP +1, Joy refilled, Sparks +15. \(growthStage.rewardLine)"
        }
        markCombo(.pet)
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
            earnSparkDust(1)
            if isHintPrompt(prompt) {
                markCombo(.hint)
            }
            play(.reply)
            setMood(.happy, duration: 1.5)
        } catch {
            message = "I cannot reach the tale yet. Open PocketDM, start a run, then ask me again."
            serverLine = "Waiting for local server"
            play(.nap)
            setMood(.nap, duration: 2.4)
        }
    }

    func acceptCheerBubble() {
        let prompt = cheerBubble ?? "Check in"
        cheerBubble = nil
        lastRequest = "Cheer"
        happiness = min(5, happiness + 1)
        earnSparkDust(3)
        message = "\(prompt) Pikachu turns it into Joy +1 and Sparks +3. Open the game for one tiny quest."
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheerAtKey)
        persistCare()
        play(.reply)
        setMood(.hyper, duration: 1.6)
        setMinimized(false)
    }

    func dismissCheerBubble() {
        cheerBubble = nil
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheerAtKey)
        play(.minimize)
    }

    func buyNextUpgrade() {
        syncDailyCombo()
        let candidate = nextUpgradeCandidate
        guard sparkDust >= candidate.cost else {
            lastRequest = "Upgrade"
            message = "\(candidate.name) needs \(candidate.cost) Sparks. You have \(sparkDust). Finish today's combo or pet again."
            play(.alert)
            setMood(.alert, duration: 1.1)
            return
        }

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
        }

        lastRequest = "Upgrade"
        message = "\(candidate.name) upgraded. \(candidate.kind.unlockLine) Passive Sparks now +\(passiveSparkRate) every 15 minutes."
        markCombo(.upgrade)
        persistCare()
        play(.happy)
        setMood(.happy, duration: 1.4)
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
        "\(growthStage.title) · \(petFeeling.title) · HP \(companionHP)/10"
    }

    var economyLine: String {
        "Sparks \(sparkDust) · Energy \(energy)/\(Self.maxEnergy) · Streak \(petStreak)d"
    }

    var comboLine: String {
        let pieces = dailyComboActions.map { action in
            "\(action.label) \(dailyComboMask & action.rawValue == 0 ? "○" : "✓")"
        }
        return "Combo " + pieces.joined(separator: " · ")
    }

    var upgradeLine: String {
        let next = nextUpgradeCandidate
        return "Next \(next.shortName) \(next.level + 1): \(next.cost) Sparks"
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
            cheerLevel: cheerLevel
        )
    }

    private func play(_ sound: PetSound) {
        soundPlayer.play(sound, enabled: soundEnabled)
    }

    private func persistCare() {
        UserDefaults.standard.set(companionHP, forKey: Self.companionHPKey)
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
    }

    private func handlesCare(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        return lowered.contains("pet")
            || lowered.contains("happy")
            || lowered.contains("care")
            || lowered.contains("check in")
            || lowered.contains("check-in")
    }

    private func isHintPrompt(_ prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        return lowered.contains("hint")
            || lowered.contains("help")
            || lowered.contains("status")
            || lowered.contains("what next")
    }

    private var growthStage: PetGrowthStage {
        PetGrowthStage(companionHP: companionHP, sparkDust: sparkDust)
    }

    private var petFeeling: PetFeeling {
        PetFeeling(
            happiness: happiness,
            energy: energy,
            comboComplete: isDailyComboComplete,
            sparkDust: sparkDust,
            streak: petStreak
        )
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
        max(1, 1 + snackLevel + lessonLevel + questLevel + nestLevel + cheerLevel)
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

    private func syncDailyCombo() {
        let today = Self.dayFormatter.string(from: Date())
        guard dailyComboDate != today else { return }
        dailyComboDate = today
        dailyComboMask = 0
        persistCare()
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

    private var isDailyComboComplete: Bool {
        dailyComboActions.allSatisfy { dailyComboMask & $0.rawValue != 0 }
    }

    private var nextUpgradeCandidate: PetUpgradeCandidate {
        [
            PetUpgradeCandidate(kind: .snack, level: snackLevel),
            PetUpgradeCandidate(kind: .lesson, level: lessonLevel),
            PetUpgradeCandidate(kind: .quest, level: questLevel),
            PetUpgradeCandidate(kind: .nest, level: nestLevel),
            PetUpgradeCandidate(kind: .cheer, level: cheerLevel)
        ].min { $0.cost < $1.cost } ?? PetUpgradeCandidate(kind: .snack, level: snackLevel)
    }

    private var dailyComboActions: [PetComboAction] {
        PetComboAction.dailyCombo(for: dailyComboDate.isEmpty ? Self.dayFormatter.string(from: Date()) : dailyComboDate)
    }

    private var effectiveCheerCooldown: TimeInterval {
        max(30 * 60, Self.cheerCooldownSeconds - Double(cheerLevel) * 15 * 60)
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
                    _ = self?.collectPassiveSparks()
                }
            }
        }
    }

    private func startCheerLoop() {
        cheerTask?.cancel()
        cheerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            while !Task.isCancelled {
                await MainActor.run {
                    self?.showCheerIfReady()
                }
                try? await Task.sleep(nanoseconds: 15 * 60_000_000_000)
            }
        }
    }

    private func showCheerIfReady() {
        guard minimized, cheerBubble == nil else { return }
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        let lastCheerAt = defaults.double(forKey: Self.lastCheerAtKey)
        guard lastCheerAt == 0 || now - lastCheerAt >= effectiveCheerCooldown else { return }

        let index = defaults.integer(forKey: Self.cheerIndexKey)
        cheerBubble = PetNudgeLibrary.cheerLine(
            feeling: petFeeling,
            stage: growthStage,
            combo: dailyComboActions,
            comboMask: dailyComboMask,
            energy: energy,
            sparkDust: sparkDust,
            index: index
        )
        defaults.set(index + 1, forKey: Self.cheerIndexKey)
        defaults.set(now, forKey: Self.lastCheerAtKey)
        play(.happy)
        setMood(.hyper, duration: 1.2)
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
        .onChange(of: model.minimized) { _, minimized in
            onSizeChange(minimized)
        }
    }

    private var petOnlyBody: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.76)) {
                    if model.cheerBubble == nil {
                        model.setMinimized(false)
                    } else {
                        model.acceptCheerBubble()
                    }
                }
            } label: {
                AnimatedPetSprite(mood: model.mood, size: CGFloat(petHovering ? 166 : 158) * model.petScale)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(dragGesture)
            .accessibilityLabel("Open Pikachu chat")

            if let cheerBubble = model.cheerBubble {
                HStack(alignment: .top, spacing: 5) {
                    Button {
                        model.acceptCheerBubble()
                    } label: {
                        Text(cheerBubble)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.black)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .frame(width: 139, alignment: .leading)
                            .background(Color.ivory, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gold.opacity(0.9), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Pikachu check-in")

                    Button {
                        model.dismissCheerBubble()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.78))
                            .frame(width: 22, height: 22)
                            .background(Color.ivory.opacity(0.92), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss Pikachu check-in")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: 2, y: 0)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

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
                    AnimatedPetSprite(mood: model.mood, size: 176 * model.petScale)
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
                            Button("Upgrade") {
                                model.buyNextUpgrade()
                            }
                            .buttonStyle(DragonButtonStyle(kind: .secondary))
                            .disabled(model.busy)
                            Button("Open") {
                                model.openGame()
                            }
                            .buttonStyle(DragonButtonStyle(kind: .secondary))
                            .accessibilityLabel("Open PocketDM")
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
            Text(model.comboLine)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(model.upgradeLine)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .multilineTextAlignment(.center)
        .frame(width: 170)
        .frame(minHeight: 98)
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
                Text("Pikachu")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityLabel("Drag Pikachu panel")
            soundButton
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.76)) {
                    model.setMinimized(true)
                }
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(DragonIconButtonStyle(kind: .secondary))
            .accessibilityLabel("Minimize Pikachu to pet")
            Button {
                closeCompanion()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(DragonIconButtonStyle(kind: .secondary))
            .accessibilityLabel("Close Pikachu")
        }
        .padding(.horizontal, 10)
        .frame(height: isCompact ? 30 : 34)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 7))
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
        .buttonStyle(DragonIconButtonStyle(kind: .secondary))
        .opacity(model.soundEnabled ? 1 : 0.62)
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
