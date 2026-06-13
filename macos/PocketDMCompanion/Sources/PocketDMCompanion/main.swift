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
        overlayController = DragonOverlayController(
            client: client,
            launcher: launcher,
            character: arguments.character,
            repoRoot: arguments.repoRoot
        )
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
    let character: CompanionCharacter

    static func parse(_ raw: [String]) -> CompanionArguments {
        var baseURL = URL(string: "http://127.0.0.1:7860")!
        var launchServer = false
        var character = CompanionCharacter.savedDefault
        var index = 1

        while index < raw.count {
            switch raw[index] {
            case "--attach" where index + 1 < raw.count:
                baseURL = URL(string: raw[index + 1]) ?? baseURL
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
        return CompanionArguments(baseURL: baseURL, launchServer: launchServer, repoRoot: repoRoot, character: character)
    }
}

enum CompanionCharacter: String, CaseIterable, Identifiable {
    case pika
    case golden

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
        case "gold", "golden", "goldie", "mascot", "/gold", "/golden", "/goldie":
            return .golden
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .pika:
            return "Pikachu"
        case .golden:
            return "Goldie"
        }
    }

    var shortTitle: String {
        switch self {
        case .pika:
            return "Pika"
        case .golden:
            return "Goldie"
        }
    }

    var catchphrase: String {
        switch self {
        case .pika:
            return "Pika pika!"
        case .golden:
            return "Glim glim!"
        }
    }

    var normalizedCatchphrase: String {
        catchphrase.lowercased().filter(\.isLetter)
    }

    var welcomeBody: String {
        switch self {
        case .pika:
            return "Your electric partner keeps a tiny bond spark. Pet once each day to earn +1 HP and refill joy."
        case .golden:
            return "Your golden 3D mascot is loaded. It keeps the same pet loop, with softer sparkle energy for the demo."
        }
    }

    var iconName: String {
        switch self {
        case .pika:
            return "bolt.fill"
        case .golden:
            return "sparkles"
        }
    }

    var voiceSummary: String {
        switch self {
        case .pika:
            return "Cute high voice"
        case .golden:
            return "Soft golden voice"
        }
    }

    var voiceRate: Float {
        switch self {
        case .pika:
            return 0.54
        case .golden:
            return 0.46
        }
    }

    var voiceVolume: Float {
        switch self {
        case .pika:
            return 0.44
        case .golden:
            return 0.40
        }
    }

    var voicePitch: Float {
        switch self {
        case .pika:
            return 1.36
        case .golden:
            return 1.12
        }
    }

    var preferredVoiceNames: [String] {
        switch self {
        case .pika:
            return ["Nicky", "Samantha", "Ava"]
        case .golden:
            return ["Samantha", "Ava", "Alex"]
        }
    }

    func rewrite(_ text: String) -> String {
        guard self == .golden else { return text }
        return text
            .replacingOccurrences(of: #"(?i)\bpika[\s,-]+pika\b"#, with: "Glim glim", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\bpikachu\b"#, with: title, options: .regularExpression)
    }

    func spriteCandidates(stage: PetGrowthStage, mood: PetMood) -> [String] {
        switch self {
        case .pika:
            return mood.spriteCandidates(stage: stage)
        case .golden:
            switch mood {
            case .idle:
                return ["pet-buddy-idle-look-smile", "pet-baby-idle-look-smile"]
            case .happy, .look:
                return ["pet-buddy-pet-reaction", "pet-buddy-idle-look-smile"]
            case .nap, .sleepGuard:
                return ["pet-buddy-nap", "pet-buddy-need-rest"]
            case .hyper, .spark, .patrol:
                return ["pet-buddy-hyper", "pet-buddy-spark-boost", "pet-buddy-event-sky-sprint"]
            case .alert:
                return ["pet-buddy-cheer-bubble", "pet-buddy-proactive-checkin"]
            case .thinking, .peek:
                return ["pet-buddy-daily-cipher", "pet-buddy-need-puzzle", "pet-buddy-learn"]
            case .perch:
                return ["pet-buddy-need-focus", "pet-buddy-proactive-focus-checkin"]
            case .snack:
                return ["pet-buddy-event-spark-picnic", "pet-buddy-need-affection"]
            case .stretch:
                return ["pet-buddy-mood-repair", "pet-buddy-comeback"]
            }
        }
    }
}

@MainActor
final class DragonOverlayController {
    private let panel: NSPanel
    private let model: DragonOverlayModel

    init(client: PocketDMClient, launcher: GameLauncher, character: CompanionCharacter, repoRoot: URL) {
        model = DragonOverlayModel(client: client, launcher: launcher, initialCharacter: character)
        panel = FloatingDragonPanel()
        PetSpriteSheet.externalAssetDirectory = repoRoot.appending(path: "output/sprite-sheets", directoryHint: .isDirectory)

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
        let size = minimized ? NSSize(width: 184, height: 190) : NSSize(width: 500, height: 500)
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
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
    private static let careCharmMaskKey = "PocketDMCompanion.careCharmMask"
    private static let evolutionQuestMaskKey = "PocketDMCompanion.evolutionQuestMask"
    private static let growthJourneyMaskKey = "PocketDMCompanion.growthJourneyMask"
    private static let latestGrowthStageRawKey = "PocketDMCompanion.latestGrowthStageRaw"
    private static let lastNeedBonusDayKey = "PocketDMCompanion.lastNeedBonusDay"
    private static let dailyEventDateKey = "PocketDMCompanion.dailyEventDate"
    private static let dailyEventProgressKey = "PocketDMCompanion.dailyEventProgress"
    private static let seasonBadgeMaskKey = "PocketDMCompanion.seasonBadgeMask"
    private static let dailyFeelingDateKey = "PocketDMCompanion.dailyFeelingDate"
    private static let dailyFeelingMaskKey = "PocketDMCompanion.dailyFeelingMask"
    private static let emotionAlbumMaskKey = "PocketDMCompanion.emotionAlbumMask"
    private static let latestFeelingRawKey = "PocketDMCompanion.latestFeelingRaw"
    private static let dailyEmotionEpisodeDateKey = "PocketDMCompanion.dailyEmotionEpisodeDate"
    private static let dailyEmotionEpisodeMaskKey = "PocketDMCompanion.dailyEmotionEpisodeMask"
    private static let emotionEpisodeAlbumMaskKey = "PocketDMCompanion.emotionEpisodeAlbumMask"
    private static let latestEmotionEpisodeRawKey = "PocketDMCompanion.latestEmotionEpisodeRaw"
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
    private static let routeAlbumMaskKey = "PocketDMCompanion.routeAlbumMask"
    private static let latestRouteStepRawKey = "PocketDMCompanion.latestRouteStepRaw"
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
    private static let ambientCooldownSeconds: TimeInterval = 4 * 60
    private static let scoutTripSeconds: TimeInterval = 20
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

    @Published var companionCharacter = CompanionCharacter.savedDefault
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
    @Published var dailyBondBoardDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyBondBoardDateKey) ?? ""
    @Published var dailyBondBoardMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyBondBoardMaskKey) as? Int ?? 0
    @Published var bondContractAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.bondContractAlbumMaskKey) as? Int ?? 0
    @Published var dailyBoosterDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyBoosterDateKey) ?? ""
    @Published var dailyBoosterUsed = UserDefaults.standard.bool(forKey: DragonOverlayModel.dailyBoosterUsedKey)
    @Published var dailyCipherDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyCipherDateKey) ?? ""
    @Published var dailyCipherSolved = UserDefaults.standard.bool(forKey: DragonOverlayModel.dailyCipherSolvedKey)
    @Published var careMemoryMask = UserDefaults.standard.object(forKey: DragonOverlayModel.careMemoryMaskKey) as? Int ?? 0
    @Published var lifeSceneMask = UserDefaults.standard.object(forKey: DragonOverlayModel.lifeSceneMaskKey) as? Int ?? 0
    @Published var careCharmMask = UserDefaults.standard.object(forKey: DragonOverlayModel.careCharmMaskKey) as? Int ?? 0
    @Published var evolutionQuestMask = UserDefaults.standard.object(forKey: DragonOverlayModel.evolutionQuestMaskKey) as? Int ?? 0
    @Published var growthJourneyMask = UserDefaults.standard.object(forKey: DragonOverlayModel.growthJourneyMaskKey) as? Int ?? 0
    @Published var latestGrowthStageRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestGrowthStageRawKey) as? Int ?? 0
    @Published var dailyEventDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyEventDateKey) ?? ""
    @Published var dailyEventProgress = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyEventProgressKey) as? Int ?? 0
    @Published var seasonBadgeMask = UserDefaults.standard.object(forKey: DragonOverlayModel.seasonBadgeMaskKey) as? Int ?? 0
    @Published var dailyFeelingDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyFeelingDateKey) ?? ""
    @Published var dailyFeelingMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyFeelingMaskKey) as? Int ?? 0
    @Published var emotionAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.emotionAlbumMaskKey) as? Int ?? 0
    @Published var latestFeelingRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestFeelingRawKey) as? Int ?? 0
    @Published var dailyEmotionEpisodeDate = UserDefaults.standard.string(forKey: DragonOverlayModel.dailyEmotionEpisodeDateKey) ?? ""
    @Published var dailyEmotionEpisodeMask = UserDefaults.standard.object(forKey: DragonOverlayModel.dailyEmotionEpisodeMaskKey) as? Int ?? 0
    @Published var emotionEpisodeAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.emotionEpisodeAlbumMaskKey) as? Int ?? 0
    @Published var latestEmotionEpisodeRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestEmotionEpisodeRawKey) as? Int ?? 0
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
    @Published var routeAlbumMask = UserDefaults.standard.object(forKey: DragonOverlayModel.routeAlbumMaskKey) as? Int ?? 0
    @Published var latestRouteStepRaw = UserDefaults.standard.object(forKey: DragonOverlayModel.latestRouteStepRawKey) as? Int ?? 0
    @Published var snackVital = UserDefaults.standard.object(forKey: DragonOverlayModel.snackVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var restVital = UserDefaults.standard.object(forKey: DragonOverlayModel.restVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var playVital = UserDefaults.standard.object(forKey: DragonOverlayModel.playVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var focusVital = UserDefaults.standard.object(forKey: DragonOverlayModel.focusVitalKey) as? Int ?? DragonOverlayModel.maxVital
    @Published var cheerBubble: String?
    @Published var cheerTitle = ""
    @Published var cheerAction = ""
    @Published var cheerRewardLine = ""
    @Published var cheerDaypartRaw = 0
    @Published var cheerMoodCareStepRaw = 0
    @Published var cheerBondContractRaw = 0
    @Published var cheerDialogueRaw = 0
    @Published var cheerIntentRaw = 0
    @Published var cheerScriptRaw = 0
    @Published var cheerMoodStoryRaw = 0
    @Published var cheerFieldNoteRaw = 0
    @Published var cheerScoutTripRaw = 0
    @Published var cheerWishRaw = 0
    @Published var cheerToyRaw = 0
    @Published var cheerTrickRaw = 0

    let languageCoach = LanguageCoachStore()

    private let client: PocketDMClient
    private let launcher: GameLauncher
    private let soundPlayer = PetSoundPlayer()
    private var moodTask: Task<Void, Never>?
    private var energyTask: Task<Void, Never>?
    private var cheerTask: Task<Void, Never>?
    private var ambientTask: Task<Void, Never>?
    private var scoutTripTask: Task<Void, Never>?
    private var lastEnergyAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastEnergyAtKey)
    private var passiveSparkAt = UserDefaults.standard.double(forKey: DragonOverlayModel.passiveSparkAtKey)
    private var lastLifecycleAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastLifecycleAtKey)
    private var lastAmbientAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastAmbientAtKey)
    private var lastComebackChestDay = UserDefaults.standard.string(forKey: DragonOverlayModel.lastComebackChestDayKey) ?? ""
    private var lastNeedBonusDay = UserDefaults.standard.string(forKey: DragonOverlayModel.lastNeedBonusDayKey) ?? ""
    private var lastVitalAt = UserDefaults.standard.double(forKey: DragonOverlayModel.lastVitalAtKey)
    init(client: PocketDMClient, launcher: GameLauncher, initialCharacter: CompanionCharacter) {
        self.client = client
        self.launcher = launcher
        companionCharacter = initialCharacter
        UserDefaults.standard.set(initialCharacter.rawValue, forKey: CompanionCharacter.defaultsKey)
        message = pikaText(initialCharacter.welcomeBody)
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
        if lastVitalAt == 0 {
            lastVitalAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(lastVitalAt, forKey: Self.lastVitalAtKey)
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
        startCheerLoop()
        startAmbientLoop()
        scheduleScoutTripReturnCheck()
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
        guard trimmed.hasPrefix("/"), let character = CompanionCharacter.parse(trimmed) else { return false }
        switchCharacter(character)
        lastRequest = trimmed
        return true
    }

    func happy() {
        applyVitalDecay()
        message = pikaText("Pikachu perks up. Joy is high and it is ready for a quest or a quick lesson.")
        lastRequest = "Mood"
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
        if let charmNote = unlockCharm(.restNest) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.rest) {
            message += " \(moodCareNote)"
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
        if let charmNote = unlockCharm(.playBolt) {
            message += " \(charmNote)"
        }
        if let moodCareNote = markMoodCare(.play) {
            message += " \(moodCareNote)"
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
        play(.open)
        speakPika()
        languageCoach.speakCurrent()
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
            play(reward.dailyBond ? .pet : .happy)
            speakPikaLine(message, force: true)
            setMood(.happy, duration: 1.4)
        } else {
            appendEmotionScene(trigger: "lesson retry")
            play(.alert)
            speakPikaLine(message, force: true)
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
        speakPika()
        setMood(.happy, duration: 2.2)
    }

    func ask(_ prompt: String) async {
        let priorStage = growthStage
        let asksForHint = isHintPrompt(prompt)
        applyVitalDecay()
        lastRequest = prompt
        if handleCharacterCommand(prompt) {
            return
        }
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
            play(.reply)
            speakPikaLine(message, force: true)
            setMood(.happy, duration: 1.5)
        } catch {
            message = pikaText("I cannot reach the tale yet. Open PocketDM, start a run, then ask me again.")
            serverLine = "Waiting for local server"
            appendEmotionScene(trigger: "server wait")
            play(.nap)
            speakPikaLine(message, force: true)
            setMood(.nap, duration: 2.4)
        }
    }

    func acceptCheerBubble() {
        let priorStage = growthStage
        applyVitalDecay()
        let prompt = cheerTitle.isEmpty ? "Check in" : cheerTitle
        let rewardLine = cheerRewardLine.isEmpty ? "Check-in answered" : cheerRewardLine
        let moodCareStep = PetMoodCareStep(rawValue: cheerMoodCareStepRaw)
        let bondContract = PetBondContract(rawValue: cheerBondContractRaw)
        let cheerDialogue = PetCheerDialogue(rawValue: cheerDialogueRaw)
        let cheerIntent = PetCheerIntent(rawValue: cheerIntentRaw) ?? .checkIn
        let cheerDaypart = PetDaypartNudge(rawValue: cheerDaypartRaw)
        let daypartNote = recordCheerAnswer()
        let dialogueNote = recordCheerDialogueAnswer()
        let scriptNote = recordCheerScriptAnswer()
        let moodStoryNote = recordMoodStoryAnswer()
        let fieldNoteNote = recordFieldNoteAnswer()
        let scoutTripNote = recordScoutTripAnswer()
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
        if let daypartNote {
            message += " \(daypartNote)"
        }
        if let dialogueNote {
            message += " \(dialogueNote)"
        }
        if let scriptNote {
            message += " \(scriptNote)"
        }
        if let moodStoryNote {
            message += " \(moodStoryNote)"
        }
        if let fieldNoteNote {
            message += " \(fieldNoteNote)"
        }
        if let scoutTripNote {
            message += " \(scoutTripNote)"
        }
        if let wishNote {
            message += " \(wishNote)"
        }
        if let toyNote {
            message += " \(toyNote)"
        }
        if let trickNote {
            message += " \(trickNote)"
        }
        if let intentNote {
            message += " \(intentNote)"
        }
        if let memoryNote {
            message += " \(memoryNote)"
        }
        recordDailyQuest(.cheer)
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
        setMood(.hyper, duration: 1.6)
        setMinimized(false)
    }

    func dismissCheerBubble() {
        recordCheerDismissal()
        recordCheerIntentDismissal()
        recordCheerScriptDismissal()
        recordMoodStoryDismissal()
        recordFieldNoteDismissal()
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

    var lifeSceneLine: String {
        PetLifeScene.summary(mask: lifeSceneMask, stage: growthStage)
    }

    var currentLifeScenes: [PetLifeScene] {
        PetLifeScene.scenes(for: growthStage)
    }

    var charmLine: String {
        PetCareCharm.summary(mask: careCharmMask)
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
            albumMask: routeAlbumMask,
            route: dailyRouteSteps,
            latest: PetDailyRouteStep(rawValue: latestRouteStepRaw)
        )
    }

    var routeSteps: [PetDailyRouteStep] {
        dailyRouteSteps
    }

    var cheerRhythmLine: String {
        PetDaypartNudge.summary(
            offeredMask: dailyNudgeOfferedMask,
            answeredMask: dailyNudgeAnsweredMask,
            dismissedMask: dailyNudgeDismissedMask
        )
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

    var journalMoodStoryProgress: Double {
        Double(PetMoodStory.count(mask: dailyMoodStoryAnsweredMask)) / Double(PetMoodStory.allCases.count)
    }

    var journalMoodStoryCaption: String {
        moodStoryLine
    }

    var journalMoodStorySpriteLine: String {
        let next = PetMoodStory.next(
            feeling: petFeeling,
            offeredMask: dailyMoodStoryOfferedMask,
            index: PetMoodStory.count(mask: dailyMoodStoryOfferedMask)
                + PetMoodStory.count(mask: dailyMoodStoryAnsweredMask)
        ) ?? PetMoodStory(rawValue: latestMoodStoryRaw) ?? .brightHello
        return "Mood story sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
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

    var journalBadgeCaption: String {
        "\(dailyEvent.title) · \(dailyEventProgress)/\(dailyEvent.requiredSteps) today · \(PetSeasonEvent.badgeSummary(mask: seasonBadgeMask))"
    }

    var journalBadgeProgress: Double {
        Double(PetSeasonEvent.allCases.filter { seasonBadgeMask & $0.rawValue != 0 }.count) / Double(PetSeasonEvent.allCases.count)
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
        let next = nextBondContract?.title ?? nextDailyQuest?.title ?? "Board clear"
        return "Route \(routeDone)/\(dailyRouteSteps.count) · Combo \(comboDone)/\(dailyComboActions.count) · Tasks \(questDone)/\(dailyQuests.count) · Bonds \(bondDone)/\(dailyBondContracts.count) · Next \(next)"
    }

    var journalRitualProgress: Double {
        let comboDone = dailyComboActions.filter { dailyComboMask & $0.rawValue != 0 }.count
        let questDone = dailyQuests.filter { dailyQuestMask & $0.rawValue != 0 }.count
        let bondDone = dailyBondContracts.filter { dailyBondBoardMask & $0.rawValue != 0 }.count
        let routeDone = dailyRouteSteps.filter { dailyRouteMask & $0.rawValue != 0 }.count
        let total = dailyRouteSteps.count + dailyComboActions.count + dailyQuests.count + dailyBondContracts.count + dailyEvent.requiredSteps
        let done = routeDone + comboDone + questDone + bondDone + min(dailyEventProgress, dailyEvent.requiredSteps)
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

    var journalCheerProgress: Double {
        let answered = PetDaypartNudge.count(mask: dailyNudgeAnsweredMask)
            + PetCheerDialogue.count(mask: dailyCheerDialogueAnsweredMask)
            + PetCheerIntent.count(mask: dailyCheerIntentAnsweredMask)
            + PetCheerScript.count(mask: dailyCheerScriptAnsweredMask)
            + PetMoodStory.count(mask: dailyMoodStoryAnsweredMask)
            + PetFieldNote.count(mask: dailyFieldNoteSavedMask)
            + PetWish.count(mask: dailyWishFulfilledMask)
            + PetToy.count(mask: dailyToyPlayedMask)
            + PetTrick.count(mask: dailyTrickPracticedMask)
        let total = PetDaypartNudge.allCases.count + PetCheerDialogue.allCases.count + PetCheerIntent.allCases.count + PetCheerScript.allCases.count + PetMoodStory.allCases.count + PetFieldNote.allCases.count + PetWish.allCases.count + PetToy.allCases.count + PetTrick.allCases.count
        return Double(answered) / Double(max(1, total))
    }

    var journalCheerCaption: String {
        let answered = PetDaypartNudge.count(mask: dailyNudgeAnsweredMask)
            + PetCheerDialogue.count(mask: dailyCheerDialogueAnsweredMask)
            + PetCheerIntent.count(mask: dailyCheerIntentAnsweredMask)
            + PetCheerScript.count(mask: dailyCheerScriptAnsweredMask)
            + PetMoodStory.count(mask: dailyMoodStoryAnsweredMask)
            + PetFieldNote.count(mask: dailyFieldNoteSavedMask)
            + PetWish.count(mask: dailyWishFulfilledMask)
            + PetToy.count(mask: dailyToyPlayedMask)
            + PetTrick.count(mask: dailyTrickPracticedMask)
        let offered = PetDaypartNudge.count(mask: dailyNudgeOfferedMask)
            + PetCheerDialogue.count(mask: dailyCheerDialogueOfferedMask)
            + PetCheerIntent.count(mask: dailyCheerIntentOfferedMask)
            + PetCheerScript.count(mask: dailyCheerScriptOfferedMask)
            + PetMoodStory.count(mask: dailyMoodStoryOfferedMask)
            + PetFieldNote.count(mask: dailyFieldNoteOfferedMask)
            + PetWish.count(mask: dailyWishOfferedMask)
            + PetToy.count(mask: dailyToyOfferedMask)
            + PetTrick.count(mask: dailyTrickOfferedMask)
        let albumDone = PetCheerDialogue.count(mask: cheerDialogueAlbumMask)
        let intentAlbumDone = PetCheerIntent.count(mask: cheerIntentAlbumMask)
        let scriptAlbumDone = PetCheerScript.count(mask: cheerScriptAlbumMask)
        let moodStoryAlbumDone = PetMoodStory.count(mask: moodStoryAlbumMask)
        let fieldAlbumDone = PetFieldNote.count(mask: fieldNoteAlbumMask)
        let wishAlbumDone = PetWish.count(mask: wishAlbumMask)
        let toyAlbumDone = PetToy.count(mask: toyAlbumMask)
        let trickAlbumDone = PetTrick.count(mask: trickAlbumMask)
        return "\(answered)/\(PetDaypartNudge.allCases.count + PetCheerDialogue.allCases.count + PetCheerIntent.allCases.count + PetCheerScript.allCases.count + PetMoodStory.allCases.count + PetFieldNote.allCases.count + PetWish.allCases.count + PetToy.allCases.count + PetTrick.allCases.count) answered today · \(offered) seen · Dialogues \(albumDone)/\(PetCheerDialogue.allCases.count) · Types \(intentAlbumDone)/\(PetCheerIntent.allCases.count) · Scripts \(scriptAlbumDone)/\(PetCheerScript.allCases.count) · Mood \(moodStoryAlbumDone)/\(PetMoodStory.allCases.count) · Field \(fieldAlbumDone)/\(PetFieldNote.allCases.count) · Wishes \(wishAlbumDone)/\(PetWish.allCases.count) · Toys \(toyAlbumDone)/\(PetToy.allCases.count) · Tricks \(trickAlbumDone)/\(PetTrick.allCases.count)"
    }

    var journalCheerSpriteLine: String {
        let next = PetDaypartNudge.allCases.first { dailyNudgeOfferedMask & $0.rawValue == 0 }
            ?? daypartNudge
        return "Cheer sprite: \(next.spriteRequestName.replacingOccurrences(of: "{stage}", with: growthStage.assetSlug))"
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
        if line.isEmpty {
            soundPlayer.speakPika(character: companionCharacter, enabled: soundEnabled, force: force)
        } else {
            soundPlayer.speakPikaLine(line, character: companionCharacter, enabled: soundEnabled, force: force)
        }
    }

    private func speakPikaLine(_ text: String, force: Bool = false) {
        soundPlayer.speakPikaLine(text, character: companionCharacter, enabled: soundEnabled, force: force)
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
        cheerMoodCareStepRaw = 0
        cheerBondContractRaw = 0
        cheerDialogueRaw = 0
        cheerIntentRaw = 0
        cheerScriptRaw = 0
        cheerMoodStoryRaw = 0
        cheerFieldNoteRaw = 0
        cheerScoutTripRaw = 0
        cheerWishRaw = 0
        cheerToyRaw = 0
        cheerTrickRaw = 0
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
        UserDefaults.standard.set(careCharmMask, forKey: Self.careCharmMaskKey)
        UserDefaults.standard.set(evolutionQuestMask, forKey: Self.evolutionQuestMaskKey)
        UserDefaults.standard.set(growthJourneyMask, forKey: Self.growthJourneyMaskKey)
        UserDefaults.standard.set(latestGrowthStageRaw, forKey: Self.latestGrowthStageRawKey)
        UserDefaults.standard.set(lastNeedBonusDay, forKey: Self.lastNeedBonusDayKey)
        UserDefaults.standard.set(dailyEventDate, forKey: Self.dailyEventDateKey)
        UserDefaults.standard.set(dailyEventProgress, forKey: Self.dailyEventProgressKey)
        UserDefaults.standard.set(seasonBadgeMask, forKey: Self.seasonBadgeMaskKey)
        UserDefaults.standard.set(dailyFeelingDate, forKey: Self.dailyFeelingDateKey)
        UserDefaults.standard.set(dailyFeelingMask, forKey: Self.dailyFeelingMaskKey)
        UserDefaults.standard.set(emotionAlbumMask, forKey: Self.emotionAlbumMaskKey)
        UserDefaults.standard.set(latestFeelingRaw, forKey: Self.latestFeelingRawKey)
        UserDefaults.standard.set(dailyEmotionEpisodeDate, forKey: Self.dailyEmotionEpisodeDateKey)
        UserDefaults.standard.set(dailyEmotionEpisodeMask, forKey: Self.dailyEmotionEpisodeMaskKey)
        UserDefaults.standard.set(emotionEpisodeAlbumMask, forKey: Self.emotionEpisodeAlbumMaskKey)
        UserDefaults.standard.set(latestEmotionEpisodeRaw, forKey: Self.latestEmotionEpisodeRawKey)
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
        UserDefaults.standard.set(dailyRouteDate, forKey: Self.dailyRouteDateKey)
        UserDefaults.standard.set(dailyRouteMask, forKey: Self.dailyRouteMaskKey)
        UserDefaults.standard.set(routeAlbumMask, forKey: Self.routeAlbumMaskKey)
        UserDefaults.standard.set(latestRouteStepRaw, forKey: Self.latestRouteStepRawKey)
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

    func isCheerMemorySeenToday(_ memory: PetCheerMemory) -> Bool {
        dailyCheerMemoryMask & memory.rawValue != 0
    }

    func isCheerMemoryUnlocked(_ memory: PetCheerMemory) -> Bool {
        cheerMemoryAlbumMask & memory.rawValue != 0
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
        let feeling = emotionFeeling(for: trigger)
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
        default:
            return petFeeling
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
        if dailyNudgeDate != today {
            dailyNudgeDate = today
            dailyNudgeOfferedMask = 0
            dailyNudgeAnsweredMask = 0
            dailyNudgeDismissedMask = 0
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
        if dailyEmotionEpisodeDate != today {
            dailyEmotionEpisodeDate = today
            dailyEmotionEpisodeMask = 0
            changed = true
        }
        if dailyMoodCareDate != today {
            dailyMoodCareDate = today
            dailyMoodCareFeelingRaw = petFeeling.rawValue
            dailyMoodCareMask = 0
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
        if let daypart = PetDaypartNudge(rawValue: cheerDaypartRaw) {
            dailyNudgeOfferedMask |= daypart.rawValue
            dailyNudgeDismissedMask |= daypart.rawValue
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

    private func recordFieldNoteDismissal() {
        syncDailyCombo()
        guard let note = PetFieldNote(rawValue: cheerFieldNoteRaw) else { return }
        dailyFieldNoteOfferedMask |= note.rawValue
        dailyFieldNoteDismissedMask |= note.rawValue
        latestFieldNoteRaw = note.rawValue
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

    private func startAmbientLoop() {
        ambientTask?.cancel()
        ambientTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            while !Task.isCancelled {
                await MainActor.run {
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
        play(.happy)
        setMood(moment.mood, duration: 2.6)
    }

    private func showCheerIfReady() {
        syncDailyCombo()
        guard minimized, cheerBubble == nil else { return }
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        let lastCheerAt = defaults.double(forKey: Self.lastCheerAtKey)
        let activeScoutTrip = PetScoutTrip(rawValue: activeScoutTripRaw)
        let shouldUseScoutReturn = activeScoutTrip != nil && (scoutTripRemainingSeconds ?? 1) == 0
        guard shouldUseScoutReturn || lastCheerAt == 0 || now - lastCheerAt >= effectiveCheerCooldown else { return }

        let index = defaults.integer(forKey: Self.cheerIndexKey)
        let daypart = daypartNudge
        let shouldUseDaypart = !shouldUseScoutReturn && dailyNudgeOfferedMask & daypart.rawValue == 0
        let nextMoodStory = PetMoodStory.next(
            feeling: petFeeling,
            offeredMask: dailyMoodStoryOfferedMask,
            index: index
        )
        let nextFieldNote = PetFieldNote.next(
            daypart: daypart,
            feeling: petFeeling,
            stage: growthStage,
            offeredMask: dailyFieldNoteOfferedMask,
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
        let shouldUseWish = !shouldUseScoutReturn && !shouldUseDaypart && nextWish != nil && index % 4 == 0
        let shouldUseToy = !shouldUseScoutReturn && !shouldUseDaypart && !shouldUseWish && nextToy != nil && index % 5 == 2
        let shouldUseTrick = !shouldUseScoutReturn && !shouldUseDaypart && !shouldUseWish && !shouldUseToy && nextTrick != nil && index % 6 == 4
        let shouldUseMoodStory = !shouldUseScoutReturn && !shouldUseDaypart && !shouldUseWish && !shouldUseToy && !shouldUseTrick && nextMoodStory != nil && index % 3 == 1
        let shouldUseFieldNote = !shouldUseScoutReturn && !shouldUseDaypart && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && nextFieldNote != nil && index % 4 == 3
        let nextMoodCareStep = moodCareRecipe.nextStep(mask: dailyMoodCareMask)
        let shouldUseMoodCare = !shouldUseScoutReturn && !shouldUseDaypart && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && !shouldUseFieldNote && nextMoodCareStep != nil && index % 2 == 0
        let nextContract = nextBondContract
        let shouldUseBondBoard = !shouldUseScoutReturn && !shouldUseDaypart && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && !shouldUseFieldNote && !shouldUseMoodCare && nextContract != nil && index % 3 == 2
        let nextDialogue = PetCheerDialogue.next(offeredMask: dailyCheerDialogueOfferedMask, index: index)
        let nextScript = PetCheerScript.next(
            daypart: daypart,
            intent: shouldUseFieldNote ? .fieldNote : (shouldUseWish || shouldUseToy || shouldUseTrick ? .care : (nextMoodStory?.intent ?? nextDialogue?.intent ?? .checkIn)),
            offeredMask: dailyCheerScriptOfferedMask,
            index: index
        )
        let shouldUseScript = !shouldUseScoutReturn && !shouldUseDaypart && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && !shouldUseFieldNote && !shouldUseMoodCare && !shouldUseBondBoard && nextScript != nil && (index % 2 == 1 || nextDialogue == nil)
        let shouldUseDialogue = !shouldUseScoutReturn && !shouldUseDaypart && !shouldUseWish && !shouldUseToy && !shouldUseTrick && !shouldUseMoodStory && !shouldUseFieldNote && !shouldUseMoodCare && !shouldUseBondBoard && !shouldUseScript && nextDialogue != nil
        let prompt: PetNudgeLibrary.PetCheerPrompt
        if shouldUseScoutReturn, let activeScoutTrip {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: "Scout Returned",
                body: "\(activeScoutTrip.title) came back with a tiny desktop report. Want to collect it?",
                action: "Collect Scout",
                rewardLine: "\(activeScoutTrip.title) returned",
                intent: .quest
            )
        } else if shouldUseDaypart {
            prompt = PetNudgeLibrary.PetCheerPrompt(
                title: daypart.title,
                body: daypart.body,
                action: daypart.action,
                rewardLine: daypart.rewardLine
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
        cheerDaypartRaw = shouldUseDaypart ? daypart.rawValue : 0
        cheerMoodCareStepRaw = shouldUseMoodCare ? (nextMoodCareStep?.rawValue ?? 0) : 0
        cheerBondContractRaw = shouldUseBondBoard ? (nextContract?.rawValue ?? 0) : 0
        cheerDialogueRaw = shouldUseDialogue ? (nextDialogue?.rawValue ?? 0) : 0
        cheerScriptRaw = shouldUseScript ? (nextScript?.rawValue ?? 0) : 0
        cheerMoodStoryRaw = shouldUseMoodStory ? (nextMoodStory?.rawValue ?? 0) : 0
        cheerFieldNoteRaw = shouldUseFieldNote ? (nextFieldNote?.rawValue ?? 0) : 0
        cheerScoutTripRaw = shouldUseScoutReturn ? (activeScoutTrip?.rawValue ?? 0) : 0
        cheerWishRaw = shouldUseWish ? (nextWish?.rawValue ?? 0) : 0
        cheerToyRaw = shouldUseToy ? (nextToy?.rawValue ?? 0) : 0
        cheerTrickRaw = shouldUseTrick ? (nextTrick?.rawValue ?? 0) : 0
        cheerIntentRaw = prompt.intent.rawValue
        cheerBubble = pikaText(prompt.body)
        dailyCheerIntentOfferedMask |= prompt.intent.rawValue
        dailyCheerIntentDismissedMask &= ~prompt.intent.rawValue
        if shouldUseScoutReturn, let activeScoutTrip {
            latestScoutTripRaw = activeScoutTrip.rawValue
            persistCare()
        } else if shouldUseDaypart {
            dailyNudgeOfferedMask |= daypart.rawValue
            dailyNudgeDismissedMask &= ~daypart.rawValue
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
        } else if shouldUseFieldNote, let nextFieldNote {
            dailyFieldNoteOfferedMask |= nextFieldNote.rawValue
            dailyFieldNoteDismissedMask &= ~nextFieldNote.rawValue
            latestFieldNoteRaw = nextFieldNote.rawValue
            persistCare()
        }
        persistCare()
        defaults.set(index + 1, forKey: Self.cheerIndexKey)
        defaults.set(now, forKey: Self.lastCheerAtKey)
        play(.happy)
        speakPikaLine(cheerBubble ?? prompt.body, force: true)
        let promptMood: PetMood
        if shouldUseScoutReturn {
            promptMood = activeScoutTrip?.mood ?? .hyper
        } else if shouldUseWish {
            promptMood = nextWish?.mood ?? .hyper
        } else if shouldUseToy {
            promptMood = nextToy?.mood ?? .hyper
        } else if shouldUseTrick {
            promptMood = nextTrick?.mood ?? .hyper
        } else if shouldUseMoodStory {
            promptMood = nextMoodStory?.mood ?? .hyper
        } else if shouldUseFieldNote {
            promptMood = nextFieldNote?.mood ?? .hyper
        } else {
            promptMood = .hyper
        }
        setMood(promptMood, duration: 1.2)
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

    func speakPika(character: CompanionCharacter, enabled: Bool, force: Bool = false) {
        speak(character.catchphrase, character: character, enabled: enabled, force: force)
    }

    func speakPikaLine(_ text: String, character: CompanionCharacter, enabled: Bool, force: Bool = false) {
        speak(pikaSpeechLine(from: text, character: character), character: character, enabled: enabled, force: force)
    }

    private func speak(_ line: String, character: CompanionCharacter, enabled: Bool, force: Bool) {
        guard enabled else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastPikaAt) >= 1.4 else { return }
        lastPikaAt = now
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: line)
        utterance.rate = character.voiceRate
        utterance.volume = character.voiceVolume
        utterance.pitchMultiplier = character.voicePitch
        utterance.voice = preferredVoice(for: character)
        speech.speak(utterance)
    }

    private func pikaSpeechLine(from text: String, character: CompanionCharacter) -> String {
        // Keep the spoken pet voice aligned with the visible assistant line:
        // exactly one character catchphrase lead-in, then a concise reply preview.
        let rewritten = character.rewrite(text)
        let withoutCatchphrase = rewritten.replacingOccurrences(
            of: #"(?i)\b(pika[\s,-]+pika|glim[\s,-]+glim)[!,.:\s-]*"#,
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

    private func preferredVoice(for character: CompanionCharacter) -> AVSpeechSynthesisVoice? {
        let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        for preferredName in character.preferredVoiceNames {
            if let voice = englishVoices.first(where: { $0.name.localizedCaseInsensitiveContains(preferredName) }) {
                return voice
            }
        }
        return AVSpeechSynthesisVoice(language: "en-US")
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
    @State private var showingSettings = false
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
                AnimatedPetSprite(character: model.companionCharacter, stage: model.growthStage, mood: model.mood, size: CGFloat(petHovering ? 166 : 158) * model.petScale)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(dragGesture)
            .accessibilityLabel("Open \(model.companionCharacter.title) chat")

            if let cheerBubble = model.cheerBubble {
                HStack(alignment: .top, spacing: 5) {
                    Button {
                        model.acceptCheerBubble()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.cheerTitle.isEmpty ? "\(model.companionCharacter.shortTitle) check" : model.cheerTitle)
                                .font(.system(size: 9.5, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .lineLimit(1)
                            Text(cheerBubble)
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundStyle(Color.black)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                            Text("\(model.cheerIntentTitle) · \(model.cheerAction.isEmpty ? "Open check-in" : model.cheerAction)")
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
                    .accessibilityLabel("Open \(model.companionCharacter.title) check-in")

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
                    .accessibilityLabel("Dismiss \(model.companionCharacter.title) check-in")
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
                .accessibilityLabel("Close \(model.companionCharacter.title)")
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
            if showingSettings {
                characterSettingsPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 8) {
                    AnimatedPetSprite(character: model.companionCharacter, stage: model.growthStage, mood: model.mood, size: 176 * model.petScale)
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
                            Button("Route") {
                                model.playSparkRoute()
                            }
                            .buttonStyle(DragonButtonStyle(kind: .secondary))
                            .disabled(model.busy)
                            Button("Scout") {
                                model.playScoutTrip()
                            }
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
                            Button("Life") {
                                model.playLifeScene()
                            }
                            .buttonStyle(DragonButtonStyle(kind: .secondary))
                            .disabled(model.busy)
                            Button("Board") {
                                model.playBondBoard()
                            }
                            .buttonStyle(DragonButtonStyle(kind: .secondary))
                            .disabled(model.busy)
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
        .frame(width: 500, height: 500)
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
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    showingSettings.toggle()
                }
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(DragonIconButtonStyle(kind: showingSettings ? .primary : .secondary))
            .accessibilityLabel("Open character settings")
            soundButton
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.76)) {
                    model.setMinimized(true)
                }
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(DragonIconButtonStyle(kind: .secondary))
            .accessibilityLabel("Minimize \(model.companionCharacter.title) to pet")
            Button {
                closeCompanion()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(DragonIconButtonStyle(kind: .secondary))
            .accessibilityLabel("Close \(model.companionCharacter.title)")
        }
        .padding(.horizontal, 10)
        .frame(height: isCompact ? 30 : 34)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 7))
    }

    private var characterSettingsPanel: some View {
        HStack(alignment: .center, spacing: 8) {
            ForEach(CompanionCharacter.allCases) { character in
                Button {
                    model.switchCharacter(character)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: character.iconName)
                        Text(character.shortTitle)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                }
                .buttonStyle(DragonButtonStyle(kind: model.companionCharacter == character ? .primary : .secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.companionCharacter.voiceSummary)
                    .font(.system(size: 9.4, weight: .black, design: .rounded))
                    .foregroundStyle(Color.gold)
                    .lineLimit(1)
                Text("/\(model.companionCharacter.rawValue) · --character \(model.companionCharacter.rawValue)")
                    .font(.system(size: 8.8, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.ivory.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .frame(width: 168, alignment: .leading)
        }
        .padding(8)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.gold.opacity(0.2), lineWidth: 1))
    }

    private func chatTranscript(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 3 : 6) {
            if !model.lastRequest.isEmpty {
                chatLine(label: "You", text: model.lastRequest, isCompact: isCompact)
            }
            chatLine(label: model.companionCharacter.title, text: model.message, isCompact: isCompact)
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
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Button("Pet") { model.petDaily() }
                    .buttonStyle(DragonButtonStyle(kind: model.mood == .happy ? .primary : .secondary))
                Button("Nap") { model.nap() }
                    .buttonStyle(DragonButtonStyle(kind: model.mood == .nap ? .primary : .secondary))
                Button("Hyper") { model.hyper() }
                    .buttonStyle(DragonButtonStyle(kind: model.mood == .hyper ? .primary : .secondary))
            }
            HStack(spacing: 5) {
                Button("Field") { model.playFieldNote() }
                    .buttonStyle(DragonButtonStyle(kind: model.mood == .peek ? .primary : .secondary))
                Button("Wish") { model.playWish() }
                    .buttonStyle(DragonButtonStyle(kind: model.mood == .look ? .primary : .secondary))
                Button("Toy") { model.playToy() }
                    .buttonStyle(DragonButtonStyle(kind: .secondary))
                Button("Trick") { model.playTrick() }
                    .buttonStyle(DragonButtonStyle(kind: .secondary))
            }
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
            TextField("Ask \(model.companionCharacter.title)", text: $customPrompt)
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
            journalHero("Growth Journey", value: model.journalGrowthJourneyProgress, caption: model.journalGrowthJourneyCaption)
            growthJourneyGrid
            artLine(model.journalGrowthJourneySpriteLine)
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
            journalHero("Mood Stories", value: model.journalMoodStoryProgress, caption: model.journalMoodStoryCaption)
            moodStoryGrid
            artLine(model.journalMoodStorySpriteLine)
            journalHero("Mood Care", value: model.journalMoodCareProgress, caption: model.journalMoodCareCaption)
            moodCareGrid
            artLine(model.journalMoodCareSpriteLine)
        case .memories:
            journalHero("Memories", value: model.journalMemoryProgress, caption: model.memoryLine)
            memoryList
            journalHero("Field Notes", value: model.journalFieldNoteProgress, caption: model.journalFieldNoteCaption)
            fieldNoteGrid
            artLine(model.journalFieldNoteSpriteLine)
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
            journalHero("Care Charms", value: model.journalCharmProgress, caption: model.journalCharmCaption)
            charmGrid
            artLine(model.journalCharmSpriteLine)
        case .rituals:
            journalHero("Today's Ritual", value: model.journalRitualProgress, caption: model.journalRitualCaption)
            journalHero("Spark Route", value: model.journalRouteProgress, caption: model.journalRouteCaption)
            sparkRouteGrid
            artLine(model.journalRouteSpriteLine)
            detailLine(model.needLine)
            detailLine(model.comboLine)
            detailLine(model.taskLine)
            journalHero("Bond Board", value: model.journalBondBoardProgress, caption: model.journalBondBoardCaption)
            bondContractGrid
            artLine(model.journalBondBoardSpriteLine)
            journalHero("Care Vitals", value: model.journalVitalProgress, caption: model.journalVitalCaption)
            vitalGrid
            artLine(model.journalVitalSpriteLine)
            journalHero("Ambient Life", value: model.journalAmbientProgress, caption: model.journalAmbientCaption)
            ambientGrid
            artLine(model.journalAmbientSpriteLine)
            journalHero("Field Notes", value: model.journalFieldNoteProgress, caption: model.journalFieldNoteCaption)
            fieldNoteGrid
            artLine(model.journalFieldNoteSpriteLine)
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
            journalHero("Cheer Rhythm", value: model.journalCheerProgress, caption: model.journalCheerCaption)
            detailLine(model.cheerRhythmLine)
            artLine(model.journalCheerSpriteLine)
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

    private var moodStoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.moodStories, id: \.rawValue) { story in
                let answered = model.isMoodStoryAnswered(story)
                let unlocked = model.isMoodStoryUnlocked(story)
                journalChip("\(story.shortLabel)\(answered ? " ✓" : "")", isUnlocked: answered || unlocked)
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

    private var bondContractGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
            ForEach(model.bondBoardContracts, id: \.rawValue) { contract in
                bondContractChip(contract)
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
        .contentShape(Rectangle())
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
        let frames = (0..<min(frameCount, layout.columns * layout.rows)).compactMap { index -> NSImage? in
            let column = index % layout.columns
            let row = index / layout.columns
            let rect = CGRect(x: column * frameWidth, y: row * frameHeight, width: frameWidth, height: frameHeight)
            guard let cropped = cgImage.cropping(to: rect) else { return nil }
            return NSImage(
                cgImage: cropped,
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
