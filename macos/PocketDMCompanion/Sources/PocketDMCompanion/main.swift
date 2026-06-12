import AppKit
import AVFoundation
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
        let size = minimized ? NSSize(width: 184, height: 190) : NSSize(width: 500, height: 430)
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
        let defaultOrigin = NSPoint(x: screen.maxX - 516, y: screen.minY + 72)
        let savedOrigin = NSPoint(x: savedX, y: savedY)
        let savedFrame = NSRect(origin: savedOrigin, size: panel.frame.size)
        let savedCenter = NSPoint(x: savedFrame.midX, y: savedFrame.midY)
        let savedFrameIsVisible = screen.insetBy(dx: -24, dy: -24).contains(savedCenter)
        let origin = (savedX == 0 && savedY == 0) || !savedFrameIsVisible ? defaultOrigin : savedOrigin
        let restoredFrame = NSRect(origin: origin, size: panel.frame.size)
        panel.setFrame(clamped(restoredFrame), display: false)
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 430),
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
    private static let sparkLevelKey = "PocketDMCompanion.sparkLevel"
    private static let focusLevelKey = "PocketDMCompanion.focusLevel"
    private static let cipherLevelKey = "PocketDMCompanion.cipherLevel"
    private static let dailyQuestDateKey = "PocketDMCompanion.dailyQuestDate"
    private static let dailyQuestMaskKey = "PocketDMCompanion.dailyQuestMask"
    private static let dailyBoosterDateKey = "PocketDMCompanion.dailyBoosterDate"
    private static let dailyBoosterUsedKey = "PocketDMCompanion.dailyBoosterUsed"
    private static let dailyCipherDateKey = "PocketDMCompanion.dailyCipherDate"
    private static let dailyCipherSolvedKey = "PocketDMCompanion.dailyCipherSolved"
    private static let lastLifecycleAtKey = "PocketDMCompanion.lastLifecycleAt"
    private static let lastComebackChestDayKey = "PocketDMCompanion.lastComebackChestDay"
    private static let careMemoryMaskKey = "PocketDMCompanion.careMemoryMask"
    private static let lastNeedBonusDayKey = "PocketDMCompanion.lastNeedBonusDay"
    private static let dailyEventDateKey = "PocketDMCompanion.dailyEventDate"
    private static let dailyEventProgressKey = "PocketDMCompanion.dailyEventProgress"
    private static let seasonBadgeMaskKey = "PocketDMCompanion.seasonBadgeMask"
    private static let dailyFeelingDateKey = "PocketDMCompanion.dailyFeelingDate"
    private static let dailyFeelingMaskKey = "PocketDMCompanion.dailyFeelingMask"
    private static let emotionAlbumMaskKey = "PocketDMCompanion.emotionAlbumMask"
    private static let latestFeelingRawKey = "PocketDMCompanion.latestFeelingRaw"
    private static let weeklyCareWeekKey = "PocketDMCompanion.weeklyCareWeek"
    private static let weeklyCareCountKey = "PocketDMCompanion.weeklyCareCount"
    private static let weeklyRewardMaskKey = "PocketDMCompanion.weeklyRewardMask"
    private static let dailyNudgeDateKey = "PocketDMCompanion.dailyNudgeDate"
    private static let dailyNudgeOfferedMaskKey = "PocketDMCompanion.dailyNudgeOfferedMask"
    private static let dailyNudgeAnsweredMaskKey = "PocketDMCompanion.dailyNudgeAnsweredMask"
    private static let dailyNudgeDismissedMaskKey = "PocketDMCompanion.dailyNudgeDismissedMask"
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
    private static let cheerCooldownSeconds: TimeInterval = 2 * 60 * 60
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

    @Published var message = "Pika pika! Your electric partner keeps a tiny bond spark. Pet once each day to earn +1 HP and refill joy."
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
    @Published var sparkLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.sparkLevelKey) as? Int ?? 0
    @Published var focusLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.focusLevelKey) as? Int ?? 0
    @Published var cipherLevel = UserDefaults.standard.object(forKey: DragonOverlayModel.cipherLevelKey) as? Int ?? 0
    @Published var dailyQuestDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyQuestDateKey) ?? ""
    @Published var dailyQuestMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyQuestMaskKey) as? Int ?? 0
    @Published var dailyBoosterDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyBoosterDateKey) ?? ""
    @Published var dailyBoosterUsed = UserDefaults.standard.bool(forKey: DragonOverlayModel.dailyBoosterUsedKey)
    @Published var dailyCipherDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCipherDateKey) ?? ""
    @Published var dailyCipherSolved = UserDefaults.standard.bool(forKey: DragonOverlayModel.dailyCipherSolvedKey)
    @Published var careMemoryMask = UserDefaults.standard.object(forKey: DragonOverlayModel.careMemoryMaskKey) as? Int ?? 0
    @Published var dailyEventDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyEventDateKey) ?? ""
    @Published var dailyEventProgress = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyEventProgressKey) as? Int ?? 0
    @Published var seasonBadgeMask = UserDefaults.standard.object(forKey: DragonOverlayModel.seasonBadgeMaskKey) as? Int ?? 0
    @Published var dailyFeelingDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyFeelingDateKey) ?? ""
    @Published var dailyFeelingMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyFeelingMaskKey) as? Int ?? 0
    @Published var emotionAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.emotionAlbumMaskKey) as? Int ?? 0
    @Published var latestFeelingRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestFeelingRawKey) as? Int ?? 0
    @Published var weeklyCareWeek = UserDefaults.standard.string(forKey: DragonOverlayModel.weeklyCareWeekKey) ?? ""
    @Published var weeklyCareCount = UserDefaults.standard.object(forKey: DragonOverlayModel.weeklyCareCountKey) as? Int ?? 0
    @Published var weeklyRewardMask = UserDefaults.standard.object(forKey: DragonOverlayModel.weeklyRewardMaskKey) as? Int ?? 0
    @Published var dailyNudgeDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyNudgeDateKey) ?? ""
    @Published var dailyNudgeOfferedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyNudgeOfferedMaskKey) as? Int ?? 0
    @Published var dailyNudgeAnsweredMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyNudgeAnsweredMaskKey) as? Int ?? 0
    @Published var dailyNudgeDismissedMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyNudgeDismissedMaskKey) as? Int ?? 0
    @Published var snackVital = UserDefaults.standard.object(forKey: DragonOverlayModel.snackVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var restVital = UserDefaults.standard.object(forKey: DragonOverlayModel.restVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var playVital = UserDefaults.standard.object(forKey: DragonOverlayModel.playVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var focusVital = UserDefaults.standard.object(forKey: DragonOverlayModel.focusVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var cheerBubble: String?
    @Published var cheerTitle = ""
    @Published var cheerAction = ""
    @Published var cheerRewardLine = ""
    @Published var cheerDaypartRaw = 0

    let languageCoach = LanguageCoachStore()

    private let client: PocketDMClient
    private let launcher: GameLauncher
    private let soundPlayer = PetSoundPlayer()
    private var moodTask: Task<Void, Never>?
    private var energyTask: Task<Void, Never>?
    private var cheerTask: Task<Void, Never>?
    private var lastEnergyAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastEnergyAtKey)
    private var passiveSparkAt = UserDefaults.standard.double(forKey: DragonOverlayModel.passiveSparkAtKey)
    private var lastLifecycleAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastLifecycleAtKey)
    private var lastComebackChestDay = UserDefaults.standard.string(forKey: DragonOverlayModel.lastComebackChestDayKey) ?? ""
    private var lastNeedBonusDay = UserDefaults.standard.string(forKey: DragonOverlayModel.lastNeedBonusDayKey) ?? ""
    private var lastVitalAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastVitalAtKey)
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
        if lastLifecycleAt == 0 {
            lastLifecycleAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(lastLifecycleAt, forKey: Self.lastLifecycleAtKey)
        }
        if lastVitalAt == 0 {
            lastVitalAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(lastVitalAt, forKey: Self.lastVitalAtKey)
        }
        syncDailyCombo()
        rechargeEnergy()
        applyVitalDecay()
        applyLifecycleCatchup(reason: "launch")
        let collected = collectPassiveSparks()
        if collected > 0 {
            appendPetNote("Pikachu gathered \(collected) Sparks while you were away.")
            speakPika()
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
            let collected = collectPassiveSparks()
            if collected > 0 {
                appendPetNote("Pikachu gathered \(collected) passive Sparks.")
                speakPika()
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
        applyVitalDecay()
        message = pikaText("Pikachu perks up. Joy is high and it is ready for a quest or a quick lesson.")
        lastRequest = "Mood"
        if let vitalNote = refillVital(.play, by: 1) {
            message += " \(vitalNote)"
        }
        appendEmotionScene(trigger: "happy")
        play(.happy)
        speakPika()
        setMood(.happy, duration: 1.6)
    }

    func nap() {
        applyVitalDecay()
        message = pikaText("Pikachu curls up for a tiny recharge. It will keep watch quietly.")
        if let needNote = awardCareNeed(.rest) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.rest, by: 2) {
            message += " \(vitalNote)"
        }
        lastRequest = "Mood"
        appendEmotionScene(trigger: "nap")
        play(.nap)
        speakPika()
        setMood(.nap, duration: 2.4)
    }

    func hyper() {
        let priorStage = growthStage
        applyVitalDecay()
        message = pikaText("Pikachu is buzzing with energy. Great moment to ask for a hint or practice a phrase.")
        lastRequest = "Mood"
        earnSparkDust(1)
        markCombo(.hyper)
        if let needNote = awardCareNeed(.play) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.play, by: 2) {
            message += " \(vitalNote)"
        }
        appendEmotionScene(trigger: "hyper")
        appendEvolutionNote(from: priorStage)
        play(.hyper)
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
        message = pikaText("Lesson mode opened. Pick a pack, listen once, slow it down, then quiz for Joy.")
        markCombo(.learn)
        recordDailyQuest(.learn)
        if let needNote = awardCareNeed(.study) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.focus, by: 2) {
            message += " \(vitalNote)"
        }
        if let memoryNote = unlockMemory(.firstLesson) {
            message += " \(memoryNote)"
        }
        appendEmotionScene(trigger: "lesson open")
        appendEvolutionNote(from: priorStage)
        play(.open)
        speakPika()
        languageCoach.speakCurrent()
        setMood(.happy, duration: 1.2)
    }

    func openJournal() {
        guard learningMode != .journal else { return }
        learningMode = .journal
        lastRequest = "Journal"
        message = pikaText("Journal opened. Growth, moods, memories, badges, and today's ritual are all in one place.")
        appendEmotionScene(trigger: "journal")
        play(.open)
        speakPika()
        setMood(.happy, duration: 1.2)
    }

    func applyLanguageReward(_ reward: LanguagePracticeReward) {
        let priorStage = growthStage
        applyVitalDecay()
        lastRequest = "Language"
        message = pikaText(reward.message)
        if reward.correct {
            happiness = min(5, happiness + 1)
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
            if let memoryNote = unlockMemory(.firstLesson) {
                message += " \(memoryNote)"
            }
            appendEmotionScene(trigger: "language reward")
            appendEvolutionNote(from: priorStage)
            persistCare()
            play(reward.dailyBond ? .pet : .happy)
            speakPika()
            setMood(.happy, duration: 1.4)
        } else {
            appendEmotionScene(trigger: "lesson retry")
            play(.alert)
            speakPika()
            setMood(.alert, duration: 1.2)
        }
    }

    func petDaily(requestLabel: String = "Daily pet") {
        let priorStage = growthStage
        applyVitalDecay()
        lastRequest = requestLabel
        clearCheerBubble()
        syncDailyCombo()
        rechargeEnergy()
        let today = Self.dayFormatter.string(from: Date())
        if lastPetDay == today {
            happiness = min(5, happiness + 1)
            let energyBonus = spendEnergy() ? " Energy -1." : " Energy is recharging."
            earnSparkDust(2)
            message = pikaText("Already cared for today. Pikachu still leans in. Joy +1, Sparks +2.\(energyBonus)")
        } else {
            companionHP = min(10, companionHP + 1)
            happiness = 5
            petStreak += 1
            weeklyCareCount = min(7, weeklyCareCount + 1)
            lastPetDay = today
            _ = spendEnergy()
            earnSparkDust(15)
            message = pikaText("Daily care complete. Bond HP +1, Joy refilled, Sparks +15. \(growthStage.rewardLine)")
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
        if let memoryNote = unlockMemory(.firstCare) {
            message += " \(memoryNote)"
        }
        appendEmotionScene(trigger: "daily care")
        appendEvolutionNote(from: priorStage)
        persistCare()
        play(.pet)
        speakPika()
        setMood(.happy, duration: 2.2)
    }

    func ask(_ prompt: String) async {
        let priorStage = growthStage
        let asksForHint = isHintPrompt(prompt)
        applyVitalDecay()
        lastRequest = prompt
        if handlesCare(prompt) {
            petDaily(requestLabel: prompt)
            return
        }
        message = pikaText("Thinking...")
        busy = true
        play(.send)
        setMood(.thinking)
        defer { busy = false }
        do {
            message = pikaText(try await client.assistantReply(for: prompt))
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
                if let memoryNote = unlockMemory(.firstHint) {
                    message += " \(memoryNote)"
                }
            }
            appendEmotionScene(trigger: asksForHint ? "hint" : "chat")
            appendEvolutionNote(from: priorStage)
            play(.reply)
            speakPika(force: true)
            setMood(.happy, duration: 1.5)
        } catch {
            message = pikaText("I cannot reach the tale yet. Open PocketDM, start a run, then ask me again.")
            serverLine = "Waiting for local server"
            appendEmotionScene(trigger: "server wait")
            play(.nap)
            speakPika(force: true)
            setMood(.nap, duration: 2.4)
        }
    }

    func acceptCheerBubble() {
        let priorStage = growthStage
        applyVitalDecay()
        let prompt = cheerTitle.isEmpty ? "Check in" : cheerTitle
        let rewardLine = cheerRewardLine.isEmpty ? "Check-in answered" : cheerRewardLine
        let daypartNote = recordCheerAnswer()
        clearCheerBubble()
        lastRequest = "Cheer"
        happiness = min(5, happiness + 1)
        earnSparkDust(3)
        message = pikaText("\(rewardLine). Pikachu turns \(prompt.lowercased()) into Joy +1 and Sparks +3.")
        if let daypartNote {
            message += " \(daypartNote)"
        }
        recordDailyQuest(.cheer)
        if let needNote = awardCareNeed(.focus) {
            message += " \(needNote)"
        }
        if let vitalNote = refillVital(.focus, by: 2) {
            message += " \(vitalNote)"
        }
        appendEmotionScene(trigger: "cheer")
        appendEvolutionNote(from: priorStage)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheerAtKey)
        persistCare()
        play(.reply)
        speakPika()
        setMood(.hyper, duration: 1.6)
        setMinimized(false)
    }

    func dismissCheerBubble() {
        recordCheerDismissal()
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
        "\(growthStage.title) · \(petFeeling.title) · HP \(companionHP)/10"
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

    var eventLine: String {
        "\(dailyEvent.title) \(dailyEventProgress)/\(dailyEvent.requiredSteps) · \(PetSeasonEvent.badgeSummary(mask: seasonBadgeMask))"
    }

    var emotionLine: String {
        PetFeeling.summary(
            dailyMask: dailyFeelingMask,
            albumMask: emotionAlbumMask,
            latest: PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling
        )
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

    var taskLine: String {
        let quests = dailyQuests
        let done = quests.filter { dailyQuestMask & $0.rawValue != 0 }.count
        let labels = quests.map { quest in
            "\(quest.shortLabel)\(dailyQuestMask & quest.rawValue == 0 ? "○" : "✓")"
        }
        return "Tasks \(done)/\(quests.count) " + labels.joined(separator: " ")
    }

    var weeklyLine: String {
        PetStreakMilestone.summary(careCount: weeklyCareCount, rewardMask: weeklyRewardMask)
    }

    var cheerRhythmLine: String {
        PetDaypartNudge.summary(
            offeredMask: dailyNudgeOfferedMask,
            answeredMask: dailyNudgeAnsweredMask,
            dismissedMask: dailyNudgeDismissedMask
        )
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

    var journalMoodCaption: String {
        let latest = PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling
        return "\(latest.title) · \(latest.helperLine)"
    }

    var journalMoodProgress: Double {
        Double(PetFeeling.count(mask: emotionAlbumMask)) / Double(PetFeeling.allCases.count)
    }

    var journalMemoryProgress: Double {
        Double(PetBondMemory.allCases.filter { careMemoryMask & $0.rawValue != 0 }.count) / Double(PetBondMemory.allCases.count)
    }

    var journalBadgeCaption: String {
        "\(dailyEvent.title) · \(dailyEventProgress)/\(dailyEvent.requiredSteps) today · \(PetSeasonEvent.badgeSummary(mask: seasonBadgeMask))"
    }

    var journalBadgeProgress: Double {
        Double(PetSeasonEvent.allCases.filter { seasonBadgeMask & $0.rawValue != 0 }.count) / Double(PetSeasonEvent.allCases.count)
    }

    var journalRitualCaption: String {
        let comboDone = dailyComboActions.filter { dailyComboMask & $0.rawValue != 0 }.count
        let questDone = dailyQuests.filter { dailyQuestMask & $0.rawValue != 0 }.count
        let next = nextDailyQuest?.title ?? "Board clear"
        return "Combo \(comboDone)/\(dailyComboActions.count) · Tasks \(questDone)/\(dailyQuests.count) · Next \(next)"
    }

    var journalRitualProgress: Double {
        let comboDone = dailyComboActions.filter { dailyComboMask & $0.rawValue != 0 }.count
        let questDone = dailyQuests.filter { dailyQuestMask & $0.rawValue != 0 }.count
        let total = dailyComboActions.count + dailyQuests.count + dailyEvent.requiredSteps
        let done = comboDone + questDone + min(dailyEventProgress, dailyEvent.requiredSteps)
        return total == 0 ? 0 : Double(done) / Double(total)
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

    var journalStreakCaption: String {
        "This week \(min(7, weeklyCareCount))/7 care days · total streak \(petStreak)"
    }

    var journalStreakProgress: Double {
        min(1, Double(max(0, weeklyCareCount)) / 7.0)
    }

    var journalStreakSpriteLine: String {
        let next = PetStreakMilestone.allCases.first { weeklyCareCount < $0.requiredDays }
            ?? PetStreakMilestone.daySeven
        return "Week sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalCheerProgress: Double {
        Double(PetDaypartNudge.count(mask: dailyNudgeAnsweredMask)) / Double(PetDaypartNudge.allCases.count)
    }

    var journalCheerCaption: String {
        "\(PetDaypartNudge.count(mask: dailyNudgeAnsweredMask))/\(PetDaypartNudge.allCases.count) answered today · \(PetDaypartNudge.count(mask: dailyNudgeOfferedMask)) seen"
    }

    var journalCheerSpriteLine: String {
        let next = PetDaypartNudge.allCases.first { dailyNudgeOfferedMask & $0.rawValue == 0 }
            ?? daypartNudge
        return "Cheer sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
    }

    var journalSpriteLine: String {
        let latest = PetFeeling(rawValue: latestFeelingRaw) ?? petFeeling
        return "Next sprite: \(latest.spriteRequestName(stage: growthStage))"
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
        soundPlayer.speakPika(enabled: soundEnabled, force: force)
    }

    private func pikaText(_ text: String) -> String {
        let normalized = text.lowercased().filter(\.isLetter)
        if normalized.contains("pikapika") {
            return text
        }
        return "Pika pika! \(text)"
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
        UserDefaults.standard.set(sparkLevel, forKey: Self.sparkLevelKey)
        UserDefaults.standard.set(focusLevel, forKey: Self.focusLevelKey)
        UserDefaults.standard.set(cipherLevel, forKey: Self.cipherLevelKey)
        UserDefaults.standard.set(dailyQuestDate, forKey: Self.dailyQuestDateKey)
        UserDefaults.standard.set(dailyQuestMask, forKey: Self.dailyQuestMaskKey)
        UserDefaults.standard.set(dailyBoosterDate, forKey: Self.dailyBoosterDateKey)
        UserDefaults.standard.set(dailyBoosterUsed, forKey: Self.dailyBoosterUsedKey)
        UserDefaults.standard.set(dailyCipherDate, forKey: Self.dailyCipherDateKey)
        UserDefaults.standard.set(dailyCipherSolved, forKey: Self.dailyCipherSolvedKey)
        UserDefaults.standard.set(lastLifecycleAt, forKey: Self.lastLifecycleAtKey)
        UserDefaults.standard.set(lastComebackChestDay, forKey: Self.lastComebackChestDayKey)
        UserDefaults.standard.set(careMemoryMask, forKey: Self.careMemoryMaskKey)
        UserDefaults.standard.set(lastNeedBonusDay, forKey: Self.lastNeedBonusDayKey)
        UserDefaults.standard.set(dailyEventDate, forKey: Self.dailyEventDateKey)
        UserDefaults.standard.set(dailyEventProgress, forKey: Self.dailyEventProgressKey)
        UserDefaults.standard.set(seasonBadgeMask, forKey: Self.seasonBadgeMaskKey)
        UserDefaults.standard.set(dailyFeelingDate, forKey: Self.dailyFeelingDateKey)
        UserDefaults.standard.set(dailyFeelingMask, forKey: Self.dailyFeelingMaskKey)
        UserDefaults.standard.set(emotionAlbumMask, forKey: Self.emotionAlbumMaskKey)
        UserDefaults.standard.set(latestFeelingRaw, forKey: Self.latestFeelingRawKey)
        UserDefaults.standard.set(weeklyCareWeek, forKey: Self.weeklyCareWeekKey)
        UserDefaults.standard.set(weeklyCareCount, forKey: Self.weeklyCareCountKey)
        UserDefaults.standard.set(weeklyRewardMask, forKey: Self.weeklyRewardMaskKey)
        UserDefaults.standard.set(dailyNudgeDate, forKey: Self.dailyNudgeDateKey)
        UserDefaults.standard.set(dailyNudgeOfferedMask, forKey: Self.dailyNudgeOfferedMaskKey)
        UserDefaults.standard.set(dailyNudgeAnsweredMask, forKey: Self.dailyNudgeAnsweredMaskKey)
        UserDefaults.standard.set(dailyNudgeDismissedMask, forKey: Self.dailyNudgeDismissedMaskKey)
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
            dailyTasksComplete: isDailyQuestSetComplete,
            cipherSolved: dailyCipherSolved,
            boosterReady: !dailyBoosterUsed,
            sparkDust: sparkDust,
            streak: petStreak,
            minimized: minimized,
            hour: currentHour
        )
    }

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var careMoment: PetCareMoment {
        PetCareMoment(hour: currentHour)
    }

    private var daypartNudge: PetDaypartNudge {
        PetDaypartNudge(moment: careMoment)
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
        return "Vitals: \(vital.title) \(next)/\(Self.maxVital). \(vital.refillLine)"
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

    private func appendEmotionScene(trigger: String) {
        if let emotionNote = recordEmotionScene(trigger: trigger) {
            message += " \(emotionNote)"
        }
    }

    private func recordEmotionScene(trigger: String) -> String? {
        syncDailyCombo()
        let feeling = emotionFeeling(for: trigger)
        let bit = feeling.rawValue
        let seenToday = dailyFeelingMask & bit != 0
        let seenEver = emotionAlbumMask & bit != 0
        latestFeelingRaw = bit
        guard !seenToday || !seenEver else {
            persistCare()
            return nil
        }

        dailyFeelingMask |= bit
        if !seenEver {
            emotionAlbumMask |= bit
            let reward = 10 + sparkLevel * 2
            sparkDust = min(999, sparkDust + reward)
            persistCare()
            return "Mood discovered after \(trigger): \(feeling.title). \(feeling.discoveryLine) Sparks +\(reward)."
        }

        let reward = 3
        sparkDust = min(999, sparkDust + reward)
        persistCare()
        return "Mood logged after \(trigger): \(feeling.title), Sparks +\(reward)."
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
        case "quest open", "cheer":
            return .eager
        case "upgrade":
            return .proud
        case "upgrade wait":
            return .restless
        case "event review":
            return .celebrating
        case "journal":
            return .proud
        default:
            return petFeeling
        }
    }

    private func appendEvolutionNote(from priorStage: PetGrowthStage) {
        let nextStage = growthStage
        guard priorStage.title != nextStage.title else { return }

        message += " Evolution glow: \(nextStage.title). \(nextStage.rewardLine)"
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
        if dailyNudgeDate != today {
            dailyNudgeDate = today
            dailyNudgeOfferedMask = 0
            dailyNudgeAnsweredMask = 0
            dailyNudgeDismissedMask = 0
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
        guard changed else { return }
        persistCare()
    }

    private func awardWeeklyCareMilestones() -> String? {
        let milestones = PetStreakMilestone.newlyUnlocked(
            careCount: weeklyCareCount,
            rewardMask: weeklyRewardMask
        )
        guard !milestones.isEmpty else { return nil }

        let priorMask = weeklyRewardMask
        var notes: [String] = []
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
        if priorMask != weeklyRewardMask {
            setMood(.hyper, duration: 1.8)
            play(.happy)
        }
        persistCare()
        return notes.joined(separator: " ")
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

    private func recordCheerDismissal() {
        syncDailyCombo()
        guard let daypart = PetDaypartNudge(rawValue: cheerDaypartRaw) else { return }
        dailyNudgeOfferedMask |= daypart.rawValue
        dailyNudgeDismissedMask |= daypart.rawValue
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

    private var isDailyComboComplete: Bool {
        dailyComboActions.allSatisfy { dailyComboMask & $0.rawValue != 0 }
    }

    private var isDailyQuestSetComplete: Bool {
        dailyQuests.allSatisfy { dailyQuestMask & $0.rawValue != 0 }
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

    private var dailyCipher: PetDailyCipher {
        PetDailyCipher.daily(
            for: dailyCipherDate.isEmpty ? Self.dayFormatter.string(from: Date()) : dailyCipherDate,
            cipherLevel: cipherLevel
        )
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
                    self?.applyVitalDecay()
                    self?.applyLifecycleCatchup(reason: "timer")
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
        syncDailyCombo()
        guard minimized, cheerBubble == nil else { return }
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        let lastCheerAt = defaults.double(forKey: Self.lastCheerAtKey)
        guard lastCheerAt == 0 || now - lastCheerAt >= effectiveCheerCooldown else { return }

        let index = defaults.integer(forKey: Self.cheerIndexKey)
        let daypart = daypartNudge
        let shouldUseDaypart = dailyNudgeOfferedMask & daypart.rawValue == 0
        let prompt = shouldUseDaypart
            ? PetNudgeLibrary.PetCheerPrompt(
                title: daypart.title,
                body: daypart.body,
                action: daypart.action,
                rewardLine: daypart.rewardLine
            )
            : PetNudgeLibrary.cheerPrompt(
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
        cheerTitle = prompt.title
        cheerAction = prompt.action
        cheerRewardLine = prompt.rewardLine
        cheerDaypartRaw = shouldUseDaypart ? daypart.rawValue : 0
        cheerBubble = pikaText(prompt.body)
        if shouldUseDaypart {
            dailyNudgeOfferedMask |= daypart.rawValue
            dailyNudgeDismissedMask &= ~daypart.rawValue
            persistCare()
        }
        defaults.set(index + 1, forKey: Self.cheerIndexKey)
        defaults.set(now, forKey: Self.lastCheerAtKey)
        play(.happy)
        speakPika()
        setMood(.hyper, duration: 1.2)
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
    private let speech = AVSpeechSynthesizer()
    private var lastPikaAt = Date.distantPast

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

    func speakPika(enabled: Bool, force: Bool = false) {
        guard enabled else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastPikaAt) >= 1.4 else { return }
        lastPikaAt = now
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "Pika pika!")
        utterance.rate = 0.48
        utterance.volume = 0.42
        utterance.pitchMultiplier = 1.18
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speech.speak(utterance)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.cheerTitle.isEmpty ? "Pika check" : model.cheerTitle)
                                .font(.system(size: 9.5, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .lineLimit(1)
                            Text(cheerBubble)
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                            Text(model.cheerAction.isEmpty ? "Open check-in" : model.cheerAction)
                                .font(.system(size: 8.5, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.58))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .frame(width: 146, alignment: .leading)
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
                    modeControls

                    if model.learningMode == .lesson {
                        LanguageCoachPanel(
                            coach: model.languageCoach,
                            onReward: { reward in
                                model.applyLanguageReward(reward)
                            }
                        )
                    } else if model.learningMode == .journal {
                        PetJournalPanel(model: model, page: $journalPage)
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

                        HStack(spacing: 8) {
                            Button("Boost") {
                                model.activateDailyBoost()
                            }
                            .buttonStyle(DragonButtonStyle(kind: .secondary))
                            .disabled(model.busy)
                            Button("Cipher") {
                                model.solveDailyCipher()
                            }
                            .buttonStyle(DragonButtonStyle(kind: .secondary))
                            .disabled(model.busy)
                            Button("Event") {
                                model.playDailyEvent()
                            }
                            .buttonStyle(DragonButtonStyle(kind: .secondary))
                            .disabled(model.busy)
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
        .frame(width: 500, height: 430)
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
            Text(model.emotionLine)
                .font(.system(size: 8.4, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.54)
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
            Text(model.storyLine)
                .font(.system(size: 8.4, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.58)
            Text(model.eventLine)
                .font(.system(size: 8.5, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.56)
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
            Text(model.taskLine)
                .font(.system(size: 8.5, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            Text(model.weeklyLine)
                .font(.system(size: 8.4, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.52)
            Text(model.cheerRhythmLine)
                .font(.system(size: 8.2, weight: .black, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.48)
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
        .frame(maxWidth: .infinity, minHeight: isCompact ? 56 : 118, alignment: .topLeading)
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
        HStack(spacing: 7) {
            Button("Pet") { model.petDaily() }
                .buttonStyle(DragonButtonStyle(kind: model.mood == .happy ? .primary : .secondary))
            Button("Nap") { model.nap() }
                .buttonStyle(DragonButtonStyle(kind: model.mood == .nap ? .primary : .secondary))
            Button("Hyper") { model.hyper() }
                .buttonStyle(DragonButtonStyle(kind: model.mood == .hyper ? .primary : .secondary))
        }
        .disabled(model.busy)
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

            HStack(spacing: 4) {
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
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.26), lineWidth: 1))
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .growth:
            journalHero("Growth", value: model.journalGrowthProgress, caption: model.journalGrowthCaption)
            detailLine(model.evolutionLine)
            detailLine(model.loreLine)
            detailLine(model.journalArtContextLine)
        case .moods:
            journalHero("Mood Album", value: model.journalMoodProgress, caption: model.journalMoodCaption)
            moodGrid
        case .memories:
            journalHero("Memories", value: model.journalMemoryProgress, caption: model.memoryLine)
            memoryList
        case .badges:
            journalHero("Badges", value: model.journalBadgeProgress, caption: model.journalBadgeCaption)
            badgeGrid
        case .rituals:
            journalHero("Today's Ritual", value: model.journalRitualProgress, caption: model.journalRitualCaption)
            detailLine(model.needLine)
            detailLine(model.comboLine)
            detailLine(model.taskLine)
            journalHero("Care Vitals", value: model.journalVitalProgress, caption: model.journalVitalCaption)
            vitalGrid
            artLine(model.journalVitalSpriteLine)
            journalHero("Cheer Rhythm", value: model.journalCheerProgress, caption: model.journalCheerCaption)
            detailLine(model.cheerRhythmLine)
            artLine(model.journalCheerSpriteLine)
            detailLine(model.cipherLine)
        case .streak:
            journalHero("Week Trail", value: model.journalStreakProgress, caption: model.journalStreakCaption)
            streakGrid
            detailLine(model.weeklyLine)
            artLine(model.journalStreakSpriteLine)
        case .cards:
            journalHero("Upgrade Cards", value: model.journalUpgradeProgress, caption: model.journalUpgradeCaption)
            upgradeDeckGrid
            detailLine(model.upgradeLine)
            artLine(model.journalUpgradeSpriteLine)
        case .art:
            journalTitleBlock("Sprite Brief", caption: model.journalArtContextLine)
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

    private var streakGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 3) {
            ForEach(PetStreakMilestone.allCases, id: \.rawValue) { milestone in
                journalChip("\(milestone.shortLabel) \(milestone.title)", isUnlocked: model.weeklyRewardMask & milestone.rawValue != 0)
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

struct JournalTabButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 8.7, weight: .black, design: .rounded))
            .foregroundStyle(selected ? Color.black : Color.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .frame(height: 24)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.gold : Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.ivory.opacity(selected ? 0 : 0.16), lineWidth: 1))
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
