import Foundation
import SwiftUI

enum PetGrowthStage: Int, CaseIterable {
    case tinySpark = 1
    case pocketPal = 2
    case trailBuddy = 4
    case stormScout = 8
    case stormGuardian = 16

    init(companionHP: Int, sparkDust: Int) {
        if companionHP >= 10 || sparkDust >= 420 {
            self = .stormGuardian
        } else if companionHP >= 8 || sparkDust >= 240 {
            self = .stormScout
        } else if companionHP >= 6 || sparkDust >= 120 {
            self = .trailBuddy
        } else if companionHP >= 4 || sparkDust >= 50 {
            self = .pocketPal
        } else {
            self = .tinySpark
        }
    }

    var title: String {
        switch self {
        case .tinySpark:
            return "Tiny Spark"
        case .pocketPal:
            return "Pocket Pal"
        case .trailBuddy:
            return "Trail Buddy"
        case .stormScout:
            return "Storm Scout"
        case .stormGuardian:
            return "Storm Guardian"
        }
    }

    var shortLabel: String {
        switch self {
        case .tinySpark:
            return "Tiny"
        case .pocketPal:
            return "Pal"
        case .trailBuddy:
            return "Trail"
        case .stormScout:
            return "Scout"
        case .stormGuardian:
            return "Guard"
        }
    }

    var assetSlug: String {
        switch self {
        case .tinySpark:
            return "tiny-spark"
        case .pocketPal:
            return "pocket-pal"
        case .trailBuddy:
            return "trail-buddy"
        case .stormScout:
            return "storm-scout"
        case .stormGuardian:
            return "storm-guardian"
        }
    }

    var arrivalLine: String {
        switch self {
        case .tinySpark:
            return "It looks up for the first time and decides the desktop is safe."
        case .pocketPal:
            return "It recognizes the user's rhythm and starts returning affection."
        case .trailBuddy:
            return "It trusts the path enough to walk beside quests and lessons."
        case .stormScout:
            return "It begins scouting tasks, check-ins, and hard moments before being asked."
        case .stormGuardian:
            return "It becomes a calm guardian of the daily loop and the user's returns."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .tinySpark, .pocketPal:
            return .snack
        case .trailBuddy, .stormScout:
            return .focus
        case .stormGuardian:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .tinySpark:
            return .soothe
        case .pocketPal:
            return .cheer
        case .trailBuddy:
            return .adventure
        case .stormScout:
            return .focus
        case .stormGuardian:
            return .rest
        }
    }

    var journeySparkReward: Int {
        switch self {
        case .tinySpark:
            return 8
        case .pocketPal:
            return 12
        case .trailBuddy:
            return 18
        case .stormScout:
            return 26
        case .stormGuardian:
            return 40
        }
    }

    var previousStage: PetGrowthStage? {
        guard let index = Self.allCases.firstIndex(of: self), index > 0 else { return nil }
        return Self.allCases[index - 1]
    }

    var arrivalSpriteName: String {
        "pet-\(assetSlug)-growth-arrival.png"
    }

    var transitionSpriteName: String {
        guard let previousStage else { return arrivalSpriteName }
        return "pet-\(previousStage.assetSlug)-evolve-to-\(assetSlug).png"
    }

    var spriteScale: CGFloat {
        switch self {
        case .tinySpark:
            return 0.88
        case .pocketPal:
            return 0.95
        case .trailBuddy:
            return 1.0
        case .stormScout:
            return 1.06
        case .stormGuardian:
            return 1.12
        }
    }

    var rewardLine: String {
        switch self {
        case .tinySpark:
            return "It is still tiny, but the bond is catching."
        case .pocketPal:
            return "It recognizes your rhythm now."
        case .trailBuddy:
            return "It trusts you enough to travel beside you."
        case .stormScout:
            return "It has started scouting the next quest before you ask."
        case .stormGuardian:
            return "It feels like a real guardian of your daily quests."
        }
    }

    var loreLine: String {
        switch self {
        case .tinySpark:
            return "A small spark is learning your voice."
        case .pocketPal:
            return "Your pal keeps a little campfire in its cheeks."
        case .trailBuddy:
            return "It marks safe paths through the adventure."
        case .stormScout:
            return "It stores tiny thunder maps for hard days."
        case .stormGuardian:
            return "It guards the streak like a pocket storm."
        }
    }

    static func progressLine(companionHP: Int, sparkDust: Int) -> String {
        let milestones: [(PetGrowthStage, Int, Int)] = [
            (.pocketPal, 4, 50),
            (.trailBuddy, 6, 120),
            (.stormScout, 8, 240),
            (.stormGuardian, 10, 420)
        ]
        guard let next = milestones.first(where: { _, hp, sparks in
            companionHP < hp && sparkDust < sparks
        }) else {
            return "Evolution: final form unlocked."
        }

        let hpNeed = max(0, next.1 - companionHP)
        let sparkNeed = max(0, next.2 - sparkDust)
        return "Next \(next.0.title): \(hpNeed) HP or \(sparkNeed) Sparks"
    }

    static func reachedStages(upTo stage: PetGrowthStage) -> [PetGrowthStage] {
        guard let index = allCases.firstIndex(of: stage) else { return [] }
        return Array(allCases.prefix(index + 1))
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(mask: Int, latest: PetGrowthStage) -> String {
        let count = count(mask: mask)
        return "Growth Journey \(count)/\(allCases.count) · Latest \(latest.title)"
    }
}

enum PetLifeScene: Int, CaseIterable {
    case tinyFirstLook = 1
    case tinyDeskNest = 2
    case tinySparkTrail = 4
    case pocketMorningHop = 8
    case pocketSnackTrust = 16
    case pocketFirstPrompt = 32
    case trailMapStep = 64
    case trailBraveCheck = 128
    case trailPhraseCamp = 256
    case scoutWindowWatch = 512
    case scoutFocusPatrol = 1024
    case scoutStormPractice = 2048
    case guardianQuietOath = 4096
    case guardianFullTrail = 8192
    case guardianReturnGlow = 16384

    var stage: PetGrowthStage {
        switch self {
        case .tinyFirstLook, .tinyDeskNest, .tinySparkTrail:
            return .tinySpark
        case .pocketMorningHop, .pocketSnackTrust, .pocketFirstPrompt:
            return .pocketPal
        case .trailMapStep, .trailBraveCheck, .trailPhraseCamp:
            return .trailBuddy
        case .scoutWindowWatch, .scoutFocusPatrol, .scoutStormPractice:
            return .stormScout
        case .guardianQuietOath, .guardianFullTrail, .guardianReturnGlow:
            return .stormGuardian
        }
    }

    var title: String {
        switch self {
        case .tinyFirstLook:
            return "First Look"
        case .tinyDeskNest:
            return "Desk Nest"
        case .tinySparkTrail:
            return "Spark Trail"
        case .pocketMorningHop:
            return "Morning Hop"
        case .pocketSnackTrust:
            return "Snack Trust"
        case .pocketFirstPrompt:
            return "First Prompt"
        case .trailMapStep:
            return "Map Step"
        case .trailBraveCheck:
            return "Brave Check"
        case .trailPhraseCamp:
            return "Phrase Camp"
        case .scoutWindowWatch:
            return "Window Watch"
        case .scoutFocusPatrol:
            return "Focus Patrol"
        case .scoutStormPractice:
            return "Storm Practice"
        case .guardianQuietOath:
            return "Quiet Oath"
        case .guardianFullTrail:
            return "Full Trail"
        case .guardianReturnGlow:
            return "Return Glow"
        }
    }

    var shortLabel: String {
        switch self {
        case .tinyFirstLook:
            return "Look"
        case .tinyDeskNest:
            return "Nest"
        case .tinySparkTrail:
            return "Trail"
        case .pocketMorningHop:
            return "Hop"
        case .pocketSnackTrust:
            return "Trust"
        case .pocketFirstPrompt:
            return "Ask"
        case .trailMapStep:
            return "Map"
        case .trailBraveCheck:
            return "Brave"
        case .trailPhraseCamp:
            return "Phrase"
        case .scoutWindowWatch:
            return "Watch"
        case .scoutFocusPatrol:
            return "Patrol"
        case .scoutStormPractice:
            return "Storm"
        case .guardianQuietOath:
            return "Oath"
        case .guardianFullTrail:
            return "Full"
        case .guardianReturnGlow:
            return "Glow"
        }
    }

    var storyLine: String {
        switch self {
        case .tinyFirstLook:
            return "It looks up, finds your cursor, and decides this desk is safe."
        case .tinyDeskNest:
            return "It makes a tiny nest at the screen edge and peeks out when you return."
        case .tinySparkTrail:
            return "It leaves three little Sparks so it can find the way back to you."
        case .pocketMorningHop:
            return "It recognizes the start of the day and hops before the first task."
        case .pocketSnackTrust:
            return "It accepts a snack, then waits instead of grabbing the whole stash."
        case .pocketFirstPrompt:
            return "It learns to ask a gentle question before offering help."
        case .trailMapStep:
            return "It unfolds a small trail map and marks one safe step forward."
        case .trailBraveCheck:
            return "It checks your face, then walks beside the brave little move."
        case .trailPhraseCamp:
            return "It builds a phrase camp and repeats one line until it glows."
        case .scoutWindowWatch:
            return "It watches the edge of the screen for returning focus."
        case .scoutFocusPatrol:
            return "It patrols quietly around a task and keeps distractions outside."
        case .scoutStormPractice:
            return "It practices tiny storm sparks so big feelings do not feel too big."
        case .guardianQuietOath:
            return "It promises to guard the daily loop without shame or pressure."
        case .guardianFullTrail:
            return "It walks the full trail and remembers every small care mark."
        case .guardianReturnGlow:
            return "It glows when you come back, because returning is part of the bond."
        }
    }

    var rewardLine: String {
        "\(stage.title) scene: \(storyLine)"
    }

    var sparkReward: Int {
        switch stage {
        case .tinySpark:
            return 8
        case .pocketPal:
            return 12
        case .trailBuddy:
            return 16
        case .stormScout:
            return 22
        case .stormGuardian:
            return 30
        }
    }

    var vital: PetCareVital {
        switch self {
        case .tinyFirstLook, .pocketFirstPrompt, .trailBraveCheck, .scoutWindowWatch, .guardianQuietOath:
            return .focus
        case .tinyDeskNest, .scoutStormPractice, .guardianReturnGlow:
            return .rest
        case .pocketMorningHop, .tinySparkTrail, .trailMapStep, .scoutFocusPatrol, .guardianFullTrail:
            return .play
        case .pocketSnackTrust, .trailPhraseCamp:
            return .snack
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .tinyFirstLook, .tinyDeskNest, .pocketSnackTrust, .guardianQuietOath:
            return .soothe
        case .tinySparkTrail, .trailMapStep, .trailBraveCheck, .guardianFullTrail:
            return .adventure
        case .pocketMorningHop, .scoutStormPractice:
            return .play
        case .pocketFirstPrompt, .scoutWindowWatch, .scoutFocusPatrol:
            return .focus
        case .trailPhraseCamp:
            return .study
        case .guardianReturnGlow:
            return .cheer
        }
    }

    var spriteRequestName: String {
        switch self {
        case .tinyFirstLook:
            return "pet-tiny-spark-life-first-look.png"
        case .tinyDeskNest:
            return "pet-tiny-spark-life-desk-nest.png"
        case .tinySparkTrail:
            return "pet-tiny-spark-life-spark-trail.png"
        case .pocketMorningHop:
            return "pet-pocket-pal-life-morning-hop.png"
        case .pocketSnackTrust:
            return "pet-pocket-pal-life-snack-trust.png"
        case .pocketFirstPrompt:
            return "pet-pocket-pal-life-first-prompt.png"
        case .trailMapStep:
            return "pet-trail-buddy-life-map-step.png"
        case .trailBraveCheck:
            return "pet-trail-buddy-life-brave-check.png"
        case .trailPhraseCamp:
            return "pet-trail-buddy-life-phrase-camp.png"
        case .scoutWindowWatch:
            return "pet-storm-scout-life-window-watch.png"
        case .scoutFocusPatrol:
            return "pet-storm-scout-life-focus-patrol.png"
        case .scoutStormPractice:
            return "pet-storm-scout-life-storm-practice.png"
        case .guardianQuietOath:
            return "pet-storm-guardian-life-quiet-oath.png"
        case .guardianFullTrail:
            return "pet-storm-guardian-life-full-trail.png"
        case .guardianReturnGlow:
            return "pet-storm-guardian-life-return-glow.png"
        }
    }

    static func scenes(for stage: PetGrowthStage) -> [PetLifeScene] {
        allCases.filter { $0.stage == stage }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func count(mask: Int, stage: PetGrowthStage) -> Int {
        scenes(for: stage).filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(mask: Int, stage: PetGrowthStage) -> String {
        let scenes = scenes(for: stage)
        let done = scenes.filter { mask & $0.rawValue != 0 }.count
        let next = scenes.first { mask & $0.rawValue == 0 }
        return "Life Scenes \(stage.title) \(done)/\(scenes.count) · next \(next?.title ?? "stage complete")"
    }
}

enum PetEvolutionQuest: Int, CaseIterable {
    case firstBond = 1
    case trustTrail = 2
    case scoutTraining = 4
    case guardianOath = 8

    var title: String {
        switch self {
        case .firstBond:
            return "First Bond"
        case .trustTrail:
            return "Trust Trail"
        case .scoutTraining:
            return "Scout Training"
        case .guardianOath:
            return "Guardian Oath"
        }
    }

    var shortLabel: String {
        switch self {
        case .firstBond:
            return "Bond"
        case .trustTrail:
            return "Trust"
        case .scoutTraining:
            return "Scout"
        case .guardianOath:
            return "Oath"
        }
    }

    var targetStage: PetGrowthStage {
        switch self {
        case .firstBond:
            return .pocketPal
        case .trustTrail:
            return .trailBuddy
        case .scoutTraining:
            return .stormScout
        case .guardianOath:
            return .stormGuardian
        }
    }

    var actionLine: String {
        switch self {
        case .firstBond:
            return "Pet once and gather the first bond spark."
        case .trustTrail:
            return "Create three memories or gather enough trail Sparks."
        case .scoutTraining:
            return "Fill the charm album or collect a strong Spark reserve."
        case .guardianOath:
            return "Complete a weekly trail, earn badges, or reach full Bond HP."
        }
    }

    var loreLine: String {
        switch self {
        case .firstBond:
            return "The tiny spark learns your hello means safety."
        case .trustTrail:
            return "It starts walking beside you instead of waiting behind."
        case .scoutTraining:
            return "It studies your rhythms and scouts the next quest early."
        case .guardianOath:
            return "It promises to guard your daily loop without guilt."
        }
    }

    var spriteRequestName: String {
        switch self {
        case .firstBond:
            return "pet-{stage}-evolution-quest-first-bond.png"
        case .trustTrail:
            return "pet-{stage}-evolution-quest-trust-trail.png"
        case .scoutTraining:
            return "pet-{stage}-evolution-quest-scout-training.png"
        case .guardianOath:
            return "pet-{stage}-evolution-quest-guardian-oath.png"
        }
    }

    var sparkReward: Int {
        switch self {
        case .firstBond:
            return 10
        case .trustTrail:
            return 18
        case .scoutTraining:
            return 28
        case .guardianOath:
            return 42
        }
    }

    var bondHPReward: Int {
        switch self {
        case .firstBond, .trustTrail:
            return 1
        case .scoutTraining:
            return 2
        case .guardianOath:
            return 0
        }
    }

    func progress(
        companionHP: Int,
        sparkDust: Int,
        memoryMask: Int,
        charmMask: Int,
        badgeMask: Int,
        weeklyRewardMask: Int
    ) -> Double {
        switch self {
        case .firstBond:
            let hp = Double(min(companionHP, 4)) / 4.0
            let sparks = Double(min(sparkDust, 50)) / 50.0
            return max(hp, sparks)
        case .trustTrail:
            let memories = Double(min(PetBondMemory.count(mask: memoryMask), 3)) / 3.0
            let hp = Double(min(companionHP, 6)) / 6.0
            let sparks = Double(min(sparkDust, 120)) / 120.0
            return max(memories, hp, sparks)
        case .scoutTraining:
            let charms = Double(min(PetCareCharm.count(mask: charmMask), 6)) / 6.0
            let hp = Double(min(companionHP, 8)) / 8.0
            let sparks = Double(min(sparkDust, 240)) / 240.0
            return max(charms, hp, sparks)
        case .guardianOath:
            let weekly = weeklyRewardMask & PetStreakMilestone.daySeven.rawValue != 0 ? 1.0 : 0.0
            let badges = Double(min(PetSeasonEvent.count(mask: badgeMask), 3)) / 3.0
            let hp = Double(min(companionHP, 10)) / 10.0
            return max(weekly, badges, hp)
        }
    }

    func isComplete(
        companionHP: Int,
        sparkDust: Int,
        memoryMask: Int,
        charmMask: Int,
        badgeMask: Int,
        weeklyRewardMask: Int
    ) -> Bool {
        progress(
            companionHP: companionHP,
            sparkDust: sparkDust,
            memoryMask: memoryMask,
            charmMask: charmMask,
            badgeMask: badgeMask,
            weeklyRewardMask: weeklyRewardMask
        ) >= 1
    }

    static func summary(claimedMask: Int) -> String {
        let claimed = allCases.filter { claimedMask & $0.rawValue != 0 }.count
        let next = allCases.first { claimedMask & $0.rawValue == 0 }
        return "Evolution Quests \(claimed)/\(allCases.count) · next \(next?.targetStage.title ?? "guardian path complete")"
    }
}

enum PetFeeling: Int, CaseIterable {
    case bright = 1
    case eager = 2
    case proud = 4
    case overcharged = 8
    case focused = 16
    case celebrating = 32
    case protective = 64
    case comfort = 128
    case playful = 256
    case grateful = 512
    case determined = 1024
    case restless = 2048
    case hungry = 4096
    case sleepy = 8192
    case curious = 16384
    case lonely = 32768

    init(
        happiness: Int,
        energy: Int,
        comboComplete: Bool,
        dailyTasksComplete: Bool,
        cipherSolved: Bool,
        boosterReady: Bool,
        sparkDust: Int,
        streak: Int,
        minimized: Bool,
        hour: Int
    ) {
        if energy == 0 {
            self = .sleepy
        } else if happiness <= 1 {
            self = .lonely
        } else if dailyTasksComplete && comboComplete && cipherSolved {
            self = .celebrating
        } else if hour >= 22 || hour < 6 {
            self = .protective
        } else if boosterReady && energy >= 4 {
            self = .overcharged
        } else if energy <= 1 {
            self = .hungry
        } else if streak >= 3 && happiness >= 5 {
            self = .grateful
        } else if comboComplete {
            self = .proud
        } else if minimized {
            self = .focused
        } else if streak == 0 || sparkDust < 20 {
            self = .curious
        } else if happiness <= 2 {
            self = .comfort
        } else if sparkDust >= 240 {
            self = .determined
        } else if sparkDust >= 120 {
            self = .restless
        } else if energy >= 4 && happiness >= 4 {
            self = .playful
        } else {
            self = .eager
        }
    }

    var title: String {
        switch self {
        case .bright:
            return "Bright"
        case .eager:
            return "Eager"
        case .proud:
            return "Proud"
        case .overcharged:
            return "Overcharged"
        case .focused:
            return "Focused"
        case .celebrating:
            return "Celebrating"
        case .protective:
            return "Protective"
        case .comfort:
            return "Gentle"
        case .playful:
            return "Playful"
        case .grateful:
            return "Grateful"
        case .determined:
            return "Determined"
        case .restless:
            return "Restless"
        case .hungry:
            return "Snacky"
        case .sleepy:
            return "Sleepy"
        case .curious:
            return "Curious"
        case .lonely:
            return "Lonely"
        }
    }

    var helperLine: String {
        switch self {
        case .bright:
            return "Ready for a tiny quest."
        case .eager:
            return "Wants one more combo step."
        case .proud:
            return "Combo glow is warm."
        case .overcharged:
            return "A daily boost is ready."
        case .focused:
            return "Keeping watch from the corner."
        case .celebrating:
            return "Today's board is glowing."
        case .protective:
            return "Quietly guarding the late hours."
        case .comfort:
            return "Wants to make the next step smaller."
        case .playful:
            return "Wants a small burst of movement."
        case .grateful:
            return "Remembers the care streak."
        case .determined:
            return "Ready to grow into the next form."
        case .restless:
            return "Sparks are asking for an upgrade."
        case .hungry:
            return "Energy is low; a snack upgrade helps."
        case .sleepy:
            return "Needs recharge time."
        case .curious:
            return "Looking for today's first spark."
        case .lonely:
            return "A quick pet would help."
        }
    }

    var discoveryLine: String {
        switch self {
        case .bright:
            return "It learned a fresh-start face."
        case .eager:
            return "It learned the look-up-and-smile greeting."
        case .proud:
            return "It learned to show off a finished combo."
        case .overcharged:
            return "It learned to carry extra sparks safely."
        case .focused:
            return "It learned quiet watch mode."
        case .celebrating:
            return "It learned a full-board victory dance."
        case .protective:
            return "It learned a late-night guardian stance."
        case .comfort:
            return "It learned gentle recovery."
        case .playful:
            return "It learned a happy wiggle."
        case .grateful:
            return "It learned a care-streak thank you."
        case .determined:
            return "It learned the ready-to-grow pose."
        case .restless:
            return "It learned to ask for an upgrade."
        case .hungry:
            return "It learned the snacky wobble."
        case .sleepy:
            return "It learned the soft recharge loop."
        case .curious:
            return "It learned the first-spark head tilt."
        case .lonely:
            return "It learned to ask for care without shame."
        }
    }

    var assetSlug: String {
        switch self {
        case .bright:
            return "bright-idle"
        case .eager:
            return "eager-idle-look-smile"
        case .proud:
            return "proud-combo-complete"
        case .overcharged:
            return "overcharged-spark-boost-ready"
        case .focused:
            return "focused-watch-mode"
        case .celebrating:
            return "celebrating-board-complete"
        case .protective:
            return "protective-night-watch"
        case .comfort:
            return "gentle-comfort"
        case .playful:
            return "playful-wiggle"
        case .grateful:
            return "grateful-care-streak"
        case .determined:
            return "determined-grow-ready"
        case .restless:
            return "restless-upgrade-ready"
        case .hungry:
            return "snacky-low-energy"
        case .sleepy:
            return "sleepy-nap"
        case .curious:
            return "curious-listen"
        case .lonely:
            return "lonely-comeback"
        }
    }

    func spriteRequestName(stage: PetGrowthStage) -> String {
        "pet-\(stage.assetSlug)-\(assetSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(dailyMask: Int, albumMask: Int, latest: PetFeeling) -> String {
        "Moods \(count(mask: dailyMask))/\(allCases.count) today · Album \(count(mask: albumMask))/\(allCases.count): \(latest.title)"
    }
}

enum PetEmotionEpisode: Int, CaseIterable {
    case freshStart = 1
    case warmCare = 2
    case sleepyNest = 4
    case playfulBurst = 8
    case overcharge = 16
    case studyFocus = 32
    case gentleRepair = 64
    case curiousClue = 128
    case braveQuest = 256
    case careContract = 512
    case proudUpgrade = 1024
    case restlessCard = 2048
    case celebrationEvent = 4096
    case guardianNight = 8192
    case snackyLow = 16384
    case lonelyReturn = 32768

    var title: String {
        switch self {
        case .freshStart:
            return "Fresh Start"
        case .warmCare:
            return "Warm Care"
        case .sleepyNest:
            return "Sleepy Nest"
        case .playfulBurst:
            return "Playful Burst"
        case .overcharge:
            return "Overcharge"
        case .studyFocus:
            return "Study Focus"
        case .gentleRepair:
            return "Gentle Repair"
        case .curiousClue:
            return "Curious Clue"
        case .braveQuest:
            return "Brave Quest"
        case .careContract:
            return "Care Contract"
        case .proudUpgrade:
            return "Proud Upgrade"
        case .restlessCard:
            return "Restless Card"
        case .celebrationEvent:
            return "Event Glow"
        case .guardianNight:
            return "Night Watch"
        case .snackyLow:
            return "Snacky Low"
        case .lonelyReturn:
            return "Lonely Return"
        }
    }

    var shortLabel: String {
        switch self {
        case .freshStart:
            return "Fresh"
        case .warmCare:
            return "Care"
        case .sleepyNest:
            return "Nest"
        case .playfulBurst:
            return "Play"
        case .overcharge:
            return "Volt"
        case .studyFocus:
            return "Study"
        case .gentleRepair:
            return "Repair"
        case .curiousClue:
            return "Clue"
        case .braveQuest:
            return "Brave"
        case .careContract:
            return "Board"
        case .proudUpgrade:
            return "Proud"
        case .restlessCard:
            return "Card"
        case .celebrationEvent:
            return "Glow"
        case .guardianNight:
            return "Night"
        case .snackyLow:
            return "Snack"
        case .lonelyReturn:
            return "Return"
        }
    }

    var feeling: PetFeeling {
        switch self {
        case .freshStart:
            return .bright
        case .warmCare:
            return .grateful
        case .sleepyNest:
            return .sleepy
        case .playfulBurst:
            return .playful
        case .overcharge:
            return .overcharged
        case .studyFocus:
            return .focused
        case .gentleRepair:
            return .comfort
        case .curiousClue:
            return .curious
        case .braveQuest:
            return .eager
        case .careContract:
            return .determined
        case .proudUpgrade:
            return .proud
        case .restlessCard:
            return .restless
        case .celebrationEvent:
            return .celebrating
        case .guardianNight:
            return .protective
        case .snackyLow:
            return .hungry
        case .lonelyReturn:
            return .lonely
        }
    }

    var storyLine: String {
        switch self {
        case .freshStart:
            return "It looks down, looks up, and chooses a tiny fresh start."
        case .warmCare:
            return "A daily pet becomes proof that the bond is remembered."
        case .sleepyNest:
            return "It curls into a small nest and lets rest count as progress."
        case .playfulBurst:
            return "Extra sparks turn into a safe, happy burst."
        case .overcharge:
            return "A bright charge gets routed into something useful."
        case .studyFocus:
            return "It listens to one phrase and holds focus beside the user."
        case .gentleRepair:
            return "A miss or wait becomes a smaller, kinder next step."
        case .curiousClue:
            return "A question turns into a clue the pet can carry."
        case .braveQuest:
            return "It marks one brave step before the whole quest path."
        case .careContract:
            return "A daily contract becomes a visible care receipt."
        case .proudUpgrade:
            return "It sees a new charm and stands a little taller."
        case .restlessCard:
            return "Restless sparks point toward the next card without shame."
        case .celebrationEvent:
            return "A finished event becomes a warm, contained glow."
        case .guardianNight:
            return "It guards the quiet hours without asking for more."
        case .snackyLow:
            return "Low energy turns into a gentle snack request."
        case .lonelyReturn:
            return "Waiting becomes a welcome-back scene, not a punishment."
        }
    }

    var careStep: PetMoodCareStep {
        switch self {
        case .freshStart, .warmCare:
            return .soothe
        case .sleepyNest, .guardianNight:
            return .rest
        case .playfulBurst, .celebrationEvent:
            return .play
        case .overcharge, .studyFocus, .careContract:
            return .focus
        case .gentleRepair, .lonelyReturn:
            return .cheer
        case .curiousClue:
            return .puzzle
        case .braveQuest:
            return .adventure
        case .proudUpgrade:
            return .cheer
        case .restlessCard:
            return .focus
        case .snackyLow:
            return .snack
        }
    }

    var vital: PetCareVital {
        switch self {
        case .warmCare, .snackyLow:
            return .snack
        case .sleepyNest, .gentleRepair, .guardianNight, .lonelyReturn:
            return .rest
        case .playfulBurst, .celebrationEvent, .braveQuest:
            return .play
        case .freshStart, .overcharge, .studyFocus, .curiousClue, .careContract, .proudUpgrade, .restlessCard:
            return .focus
        }
    }

    var sparkReward: Int {
        switch self {
        case .freshStart, .warmCare, .sleepyNest, .gentleRepair, .snackyLow, .lonelyReturn:
            return 5
        case .playfulBurst, .studyFocus, .curiousClue, .braveQuest, .guardianNight:
            return 7
        case .overcharge, .careContract, .proudUpgrade, .restlessCard, .celebrationEvent:
            return 9
        }
    }

    var assetSlug: String {
        switch self {
        case .freshStart:
            return "fresh-start"
        case .warmCare:
            return "warm-care"
        case .sleepyNest:
            return "sleepy-nest"
        case .playfulBurst:
            return "playful-burst"
        case .overcharge:
            return "overcharge"
        case .studyFocus:
            return "study-focus"
        case .gentleRepair:
            return "gentle-repair"
        case .curiousClue:
            return "curious-clue"
        case .braveQuest:
            return "brave-quest"
        case .careContract:
            return "care-contract"
        case .proudUpgrade:
            return "proud-upgrade"
        case .restlessCard:
            return "restless-card"
        case .celebrationEvent:
            return "event-glow"
        case .guardianNight:
            return "night-watch"
        case .snackyLow:
            return "snacky-low"
        case .lonelyReturn:
            return "lonely-return"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-emotion-episode-\(assetSlug).png"
    }

    static func episode(for trigger: String, feeling: PetFeeling) -> PetEmotionEpisode {
        switch trigger {
        case "happy", "chat return":
            return .freshStart
        case "daily care":
            return .warmCare
        case "nap":
            return .sleepyNest
        case "hyper":
            return .playfulBurst
        case "boost", "spent boost":
            return .overcharge
        case "lesson open", "language reward":
            return .studyFocus
        case "lesson retry", "server wait":
            return .gentleRepair
        case "hint", "chat", "cipher", "cipher review":
            return .curiousClue
        case "quest open", "cheer":
            return .braveQuest
        case "bond board":
            return .careContract
        case "upgrade", "journal", "life scene":
            return .proudUpgrade
        case "upgrade wait":
            return .restlessCard
        case "daily event", "event review":
            return .celebrationEvent
        default:
            switch feeling {
            case .bright:
                return .freshStart
            case .eager:
                return .braveQuest
            case .proud:
                return .proudUpgrade
            case .overcharged:
                return .overcharge
            case .focused:
                return .studyFocus
            case .celebrating:
                return .celebrationEvent
            case .protective:
                return .guardianNight
            case .comfort:
                return .gentleRepair
            case .playful:
                return .playfulBurst
            case .grateful:
                return .warmCare
            case .determined:
                return .careContract
            case .restless:
                return .restlessCard
            case .hungry:
                return .snackyLow
            case .sleepy:
                return .sleepyNest
            case .curious:
                return .curiousClue
            case .lonely:
                return .lonelyReturn
            }
        }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(dailyMask: Int, albumMask: Int, latest: PetEmotionEpisode) -> String {
        "Episodes \(count(mask: dailyMask))/\(allCases.count) today · Album \(count(mask: albumMask))/\(allCases.count): \(latest.title)"
    }
}

enum PetMoodCareStep: Int, CaseIterable {
    case soothe = 1
    case snack = 2
    case rest = 4
    case play = 8
    case study = 16
    case adventure = 32
    case focus = 64
    case puzzle = 128
    case cheer = 256

    var title: String {
        switch self {
        case .soothe:
            return "Soothe"
        case .snack:
            return "Snack"
        case .rest:
            return "Rest"
        case .play:
            return "Play"
        case .study:
            return "Study"
        case .adventure:
            return "Adventure"
        case .focus:
            return "Focus"
        case .puzzle:
            return "Puzzle"
        case .cheer:
            return "Cheer"
        }
    }

    var shortLabel: String {
        switch self {
        case .soothe:
            return "Soothe"
        case .snack:
            return "Snack"
        case .rest:
            return "Rest"
        case .play:
            return "Play"
        case .study:
            return "Study"
        case .adventure:
            return "Quest"
        case .focus:
            return "Focus"
        case .puzzle:
            return "Puzzle"
        case .cheer:
            return "Cheer"
        }
    }

    var spriteSlug: String {
        switch self {
        case .soothe:
            return "soothe"
        case .snack:
            return "snack"
        case .rest:
            return "rest"
        case .play:
            return "play"
        case .study:
            return "study"
        case .adventure:
            return "adventure"
        case .focus:
            return "focus"
        case .puzzle:
            return "puzzle"
        case .cheer:
            return "cheer"
        }
    }
}

struct PetMoodCareRecipe {
    let feeling: PetFeeling
    let steps: [PetMoodCareStep]

    var title: String {
        "\(feeling.title) Care"
    }

    var actionLine: String {
        steps.map(\.title).joined(separator: " + ")
    }

    func progress(mask: Int) -> Double {
        guard !steps.isEmpty else { return 0 }
        let done = steps.filter { mask & $0.rawValue != 0 }.count
        return Double(done) / Double(steps.count)
    }

    func isComplete(mask: Int) -> Bool {
        steps.allSatisfy { mask & $0.rawValue != 0 }
    }

    func nextStep(mask: Int) -> PetMoodCareStep? {
        steps.first { mask & $0.rawValue == 0 }
    }

    func spriteRequestName(stage: PetGrowthStage) -> String {
        let step = nextStep(mask: 0) ?? steps.first ?? .soothe
        return "pet-\(stage.assetSlug)-mood-care-\(feeling.assetSlug)-\(step.spriteSlug).png"
    }
}

extension PetFeeling {
    var careRecipe: PetMoodCareRecipe {
        switch self {
        case .bright:
            return PetMoodCareRecipe(feeling: self, steps: [.soothe, .play, .adventure])
        case .eager:
            return PetMoodCareRecipe(feeling: self, steps: [.play, .adventure, .focus])
        case .proud:
            return PetMoodCareRecipe(feeling: self, steps: [.cheer, .play, .focus])
        case .overcharged:
            return PetMoodCareRecipe(feeling: self, steps: [.play, .focus, .rest])
        case .focused:
            return PetMoodCareRecipe(feeling: self, steps: [.focus, .study, .cheer])
        case .celebrating:
            return PetMoodCareRecipe(feeling: self, steps: [.cheer, .play, .soothe])
        case .protective:
            return PetMoodCareRecipe(feeling: self, steps: [.rest, .soothe, .focus])
        case .comfort:
            return PetMoodCareRecipe(feeling: self, steps: [.soothe, .rest, .cheer])
        case .playful:
            return PetMoodCareRecipe(feeling: self, steps: [.play, .adventure, .snack])
        case .grateful:
            return PetMoodCareRecipe(feeling: self, steps: [.soothe, .cheer, .study])
        case .determined:
            return PetMoodCareRecipe(feeling: self, steps: [.focus, .adventure, .puzzle])
        case .restless:
            return PetMoodCareRecipe(feeling: self, steps: [.play, .focus, .adventure])
        case .hungry:
            return PetMoodCareRecipe(feeling: self, steps: [.snack, .soothe, .rest])
        case .sleepy:
            return PetMoodCareRecipe(feeling: self, steps: [.rest, .soothe, .snack])
        case .curious:
            return PetMoodCareRecipe(feeling: self, steps: [.study, .puzzle, .adventure])
        case .lonely:
            return PetMoodCareRecipe(feeling: self, steps: [.soothe, .cheer, .play])
        }
    }
}

enum PetComboAction: Int, CaseIterable {
    case pet = 1
    case hint = 2
    case learn = 4
    case hyper = 8
    case upgrade = 16
    case open = 32
    case cipher = 64
    case boost = 128

    static func dailyCombo(for dateKey: String) -> [PetComboAction] {
        let seed = dateKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let decks: [[PetComboAction]] = [
            [.pet, .hint, .learn],
            [.pet, .hyper, .open],
            [.learn, .hint, .upgrade],
            [.pet, .learn, .hyper],
            [.hint, .open, .upgrade],
            [.pet, .open, .learn],
            [.pet, .cipher, .boost],
            [.hint, .cipher, .learn],
            [.upgrade, .boost, .open]
        ]
        return decks[seed % decks.count]
    }

    var label: String {
        switch self {
        case .pet:
            return "Pet"
        case .hint:
            return "Hint"
        case .learn:
            return "Learn"
        case .hyper:
            return "Hyper"
        case .upgrade:
            return "Upgrade"
        case .open:
            return "Open"
        case .cipher:
            return "Cipher"
        case .boost:
            return "Boost"
        }
    }

    var nudgeText: String {
        switch self {
        case .pet:
            return "pet once"
        case .hint:
            return "ask for a hint"
        case .learn:
            return "practice one phrase"
        case .hyper:
            return "wake the hyper spark"
        case .upgrade:
            return "buy one upgrade"
        case .open:
            return "open the quest"
        case .cipher:
            return "solve today's tiny cipher"
        case .boost:
            return "use today's spark boost"
        }
    }

    var cheerIntent: PetCheerIntent {
        switch self {
        case .pet:
            return .care
        case .hint, .open:
            return .quest
        case .learn:
            return .lesson
        case .hyper:
            return .tinyWin
        case .upgrade:
            return .upgrade
        case .cipher:
            return .puzzle
        case .boost:
            return .boost
        }
    }
}

enum PetUpgradeKind: CaseIterable {
    case snack
    case lesson
    case quest
    case nest
    case cheer
    case spark
    case focus
    case cipher

    var baseCost: Int {
        switch self {
        case .snack:
            return 20
        case .lesson:
            return 28
        case .quest:
            return 34
        case .nest:
            return 42
        case .cheer:
            return 48
        case .spark:
            return 56
        case .focus:
            return 64
        case .cipher:
            return 72
        }
    }

    var name: String {
        switch self {
        case .snack:
            return "Snack Bowl"
        case .lesson:
            return "Study Bell"
        case .quest:
            return "Quest Map"
        case .nest:
            return "Cozy Nest"
        case .cheer:
            return "Cheer Signal"
        case .spark:
            return "Spark Wheel"
        case .focus:
            return "Focus Charm"
        case .cipher:
            return "Cipher Stone"
        }
    }

    var shortName: String {
        switch self {
        case .snack:
            return "Snack"
        case .lesson:
            return "Study"
        case .quest:
            return "Quest"
        case .nest:
            return "Nest"
        case .cheer:
            return "Cheer"
        case .spark:
            return "Wheel"
        case .focus:
            return "Focus"
        case .cipher:
            return "Cipher"
        }
    }

    var unlockLine: String {
        switch self {
        case .snack:
            return "Energy refills feel warmer."
        case .lesson:
            return "Language practice gives a brighter spark."
        case .quest:
            return "Hints feel more adventurous."
        case .nest:
            return "Comeback rewards feel safer."
        case .cheer:
            return "Check-ins can arrive a little sooner."
        case .spark:
            return "Passive Sparks and task rewards climb."
        case .focus:
            return "Daily boosts carry more energy."
        case .cipher:
            return "Daily ciphers pay brighter rewards."
        }
    }

    var spriteRequestName: String {
        switch self {
        case .snack:
            return "pet-{stage}-card-snack-bowl.png"
        case .lesson:
            return "pet-{stage}-card-study-bell.png"
        case .quest:
            return "pet-{stage}-card-quest-map.png"
        case .nest:
            return "pet-{stage}-card-cozy-nest.png"
        case .cheer:
            return "pet-{stage}-card-cheer-signal.png"
        case .spark:
            return "pet-{stage}-card-spark-wheel.png"
        case .focus:
            return "pet-{stage}-card-focus-charm.png"
        case .cipher:
            return "pet-{stage}-card-cipher-stone.png"
        }
    }
}

struct PetUpgradeCandidate {
    let kind: PetUpgradeKind
    let level: Int

    var cost: Int {
        kind.baseCost * (level + 1)
    }

    var name: String {
        kind.name
    }

    var shortName: String {
        kind.shortName
    }
}

struct PetUpgradeDeckCard: Identifiable {
    let kind: PetUpgradeKind
    let level: Int

    var id: String {
        kind.shortName
    }

    var nextCost: Int {
        kind.baseCost * (level + 1)
    }

    var isUnlocked: Bool {
        level > 0
    }

    var levelLine: String {
        "Lv \(level) · next \(nextCost)"
    }

    var statusLine: String {
        isUnlocked ? kind.unlockLine : "Locked behavior: \(kind.unlockLine)"
    }
}

enum PetDailyQuest: Int, CaseIterable {
    case care = 1
    case hint = 2
    case learn = 4
    case adventure = 8
    case upgrade = 16
    case cheer = 32
    case cipher = 64
    case boost = 128

    static func dailyDeck(for dateKey: String) -> [PetDailyQuest] {
        let seed = dateKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let decks: [[PetDailyQuest]] = [
            [.care, .hint, .learn, .cipher],
            [.care, .adventure, .boost, .cheer],
            [.learn, .hint, .upgrade, .cipher],
            [.care, .learn, .boost, .adventure],
            [.hint, .cheer, .upgrade, .cipher],
            [.care, .boost, .learn, .upgrade]
        ]
        return decks[seed % decks.count]
    }

    var title: String {
        switch self {
        case .care:
            return "Daily Care"
        case .hint:
            return "Ask Hint"
        case .learn:
            return "Practice Phrase"
        case .adventure:
            return "Open Quest"
        case .upgrade:
            return "Buy Upgrade"
        case .cheer:
            return "Answer Cheer"
        case .cipher:
            return "Daily Cipher"
        case .boost:
            return "Spark Boost"
        }
    }

    var shortLabel: String {
        switch self {
        case .care:
            return "Care"
        case .hint:
            return "Hint"
        case .learn:
            return "Learn"
        case .adventure:
            return "Quest"
        case .upgrade:
            return "Up"
        case .cheer:
            return "Cheer"
        case .cipher:
            return "Cipher"
        case .boost:
            return "Boost"
        }
    }

    var nudgeText: String {
        switch self {
        case .care:
            return "pet me once"
        case .hint:
            return "ask for one hint"
        case .learn:
            return "practice one phrase"
        case .adventure:
            return "open the adventure"
        case .upgrade:
            return "buy the next card"
        case .cheer:
            return "answer a check-in"
        case .cipher:
            return "solve today's cipher"
        case .boost:
            return "claim the spark boost"
        }
    }

    var cheerIntent: PetCheerIntent {
        switch self {
        case .care, .cheer:
            return .care
        case .hint, .adventure:
            return .quest
        case .learn:
            return .lesson
        case .upgrade:
            return .upgrade
        case .cipher:
            return .puzzle
        case .boost:
            return .boost
        }
    }
}

enum PetBondContract: Int, CaseIterable {
    case morningHello = 1
    case snackCache = 2
    case focusPerch = 4
    case phraseSpark = 8
    case tinyExpedition = 16
    case cipherWhisper = 32
    case restNest = 64
    case upgradePolish = 128
    case cheerSignal = 256
    case storyTrail = 512

    static func dailyDeck(for dateKey: String) -> [PetBondContract] {
        let seed = dateKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let decks: [[PetBondContract]] = [
            [.morningHello, .focusPerch, .phraseSpark, .storyTrail],
            [.snackCache, .tinyExpedition, .cipherWhisper, .cheerSignal],
            [.morningHello, .phraseSpark, .upgradePolish, .restNest],
            [.focusPerch, .storyTrail, .snackCache, .cipherWhisper],
            [.tinyExpedition, .cheerSignal, .phraseSpark, .upgradePolish],
            [.restNest, .morningHello, .focusPerch, .storyTrail]
        ]
        return decks[seed % decks.count]
    }

    var title: String {
        switch self {
        case .morningHello:
            return "Morning Hello"
        case .snackCache:
            return "Snack Cache"
        case .focusPerch:
            return "Focus Perch"
        case .phraseSpark:
            return "Phrase Spark"
        case .tinyExpedition:
            return "Tiny Expedition"
        case .cipherWhisper:
            return "Cipher Whisper"
        case .restNest:
            return "Rest Nest"
        case .upgradePolish:
            return "Upgrade Polish"
        case .cheerSignal:
            return "Cheer Signal"
        case .storyTrail:
            return "Story Trail"
        }
    }

    var shortLabel: String {
        switch self {
        case .morningHello:
            return "Hello"
        case .snackCache:
            return "Snack"
        case .focusPerch:
            return "Focus"
        case .phraseSpark:
            return "Phrase"
        case .tinyExpedition:
            return "Trail"
        case .cipherWhisper:
            return "Cipher"
        case .restNest:
            return "Rest"
        case .upgradePolish:
            return "Polish"
        case .cheerSignal:
            return "Cheer"
        case .storyTrail:
            return "Story"
        }
    }

    var actionLine: String {
        switch self {
        case .morningHello:
            return "say hello and give one safe tap"
        case .snackCache:
            return "refill the little snack stash"
        case .focusPerch:
            return "let the buddy sit beside one task"
        case .phraseSpark:
            return "practice one language spark"
        case .tinyExpedition:
            return "send the buddy down a tiny trail"
        case .cipherWhisper:
            return "solve one small secret together"
        case .restNest:
            return "let the buddy curl up and recover"
        case .upgradePolish:
            return "polish one kit card"
        case .cheerSignal:
            return "answer one warm check-in"
        case .storyTrail:
            return "open the next story breadcrumb"
        }
    }

    var rewardLine: String {
        switch self {
        case .morningHello:
            return "The first spark of the day feels safe."
        case .snackCache:
            return "A full snack cache steadies the mood."
        case .focusPerch:
            return "It learns your work rhythm without pressure."
        case .phraseSpark:
            return "A phrase becomes a tiny shared ritual."
        case .tinyExpedition:
            return "The trail map gets one brighter mark."
        case .cipherWhisper:
            return "The secret word becomes a keepsake."
        case .restNest:
            return "Rest teaches it that quiet also counts."
        case .upgradePolish:
            return "The kit feels cared for, not only bought."
        case .cheerSignal:
            return "The check-in turns into a bond receipt."
        case .storyTrail:
            return "A new breadcrumb joins the day story."
        }
    }

    var sparkReward: Int {
        switch self {
        case .morningHello, .snackCache, .restNest:
            return 9
        case .focusPerch, .phraseSpark, .cheerSignal:
            return 12
        case .tinyExpedition, .cipherWhisper, .storyTrail:
            return 14
        case .upgradePolish:
            return 16
        }
    }

    var vital: PetCareVital {
        switch self {
        case .snackCache, .morningHello:
            return .snack
        case .restNest:
            return .rest
        case .tinyExpedition, .cheerSignal, .storyTrail:
            return .play
        case .focusPerch, .phraseSpark, .cipherWhisper, .upgradePolish:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .morningHello:
            return .soothe
        case .snackCache:
            return .snack
        case .focusPerch:
            return .focus
        case .phraseSpark:
            return .study
        case .tinyExpedition, .storyTrail:
            return .adventure
        case .cipherWhisper:
            return .puzzle
        case .restNest:
            return .rest
        case .upgradePolish:
            return .focus
        case .cheerSignal:
            return .cheer
        }
    }

    var quest: PetDailyQuest {
        switch self {
        case .morningHello, .snackCache, .restNest:
            return .care
        case .focusPerch, .cheerSignal:
            return .cheer
        case .phraseSpark:
            return .learn
        case .tinyExpedition, .storyTrail:
            return .adventure
        case .cipherWhisper:
            return .cipher
        case .upgradePolish:
            return .upgrade
        }
    }

    var spriteRequestName: String {
        switch self {
        case .morningHello:
            return "pet-{stage}-bond-board-morning-hello.png"
        case .snackCache:
            return "pet-{stage}-bond-board-snack-cache.png"
        case .focusPerch:
            return "pet-{stage}-bond-board-focus-perch.png"
        case .phraseSpark:
            return "pet-{stage}-bond-board-phrase-spark.png"
        case .tinyExpedition:
            return "pet-{stage}-bond-board-tiny-expedition.png"
        case .cipherWhisper:
            return "pet-{stage}-bond-board-cipher-whisper.png"
        case .restNest:
            return "pet-{stage}-bond-board-rest-nest.png"
        case .upgradePolish:
            return "pet-{stage}-bond-board-upgrade-polish.png"
        case .cheerSignal:
            return "pet-{stage}-bond-board-cheer-signal.png"
        case .storyTrail:
            return "pet-{stage}-bond-board-story-trail.png"
        }
    }
}

struct PetDailyCipher {
    let clue: String
    let answer: String
    let reward: Int

    static func daily(for dateKey: String, cipherLevel: Int) -> PetDailyCipher {
        let seed = dateKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let bank = [
            ("Tiny thunder word", "SPARK"),
            ("Best daily care word", "BOND"),
            ("What the pet guards", "QUEST"),
            ("Mood after a good lesson", "JOY"),
            ("Comeback treasure", "CHEST"),
            ("Soft night mode", "NEST"),
            ("Helpful whisper", "HINT"),
            ("Brave little step", "TRY")
        ]
        let entry = bank[seed % bank.count]
        return PetDailyCipher(clue: entry.0, answer: entry.1, reward: 16 + cipherLevel * 4)
    }
}

enum PetCareMoment {
    case sunrise
    case focus
    case afternoon
    case evening
    case night

    init(hour: Int) {
        switch hour {
        case 5..<10:
            self = .sunrise
        case 10..<14:
            self = .focus
        case 14..<18:
            self = .afternoon
        case 18..<22:
            self = .evening
        default:
            self = .night
        }
    }

    var title: String {
        switch self {
        case .sunrise:
            return "Sunrise"
        case .focus:
            return "Focus"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        case .night:
            return "Night"
        }
    }

    var nudgeLine: String {
        switch self {
        case .sunrise:
            return "Morning spark check. Want to pick one tiny quest?"
        case .focus:
            return "Focus window. I can sit with you for one clean step."
        case .afternoon:
            return "Afternoon wobble check. Need a boost or a softer task?"
        case .evening:
            return "Evening campfire check. Want to close one loop?"
        case .night:
            return "Quiet night watch. I can keep this gentle."
        }
    }
}

enum PetDaypartNudge: Int, CaseIterable {
    case sunrise = 1
    case focus = 2
    case afternoon = 4
    case evening = 8
    case night = 16

    init(moment: PetCareMoment) {
        switch moment {
        case .sunrise:
            self = .sunrise
        case .focus:
            self = .focus
        case .afternoon:
            self = .afternoon
        case .evening:
            self = .evening
        case .night:
            self = .night
        }
    }

    var title: String {
        switch self {
        case .sunrise:
            return "Sunrise Check"
        case .focus:
            return "Focus Buddy"
        case .afternoon:
            return "Afternoon Reset"
        case .evening:
            return "Evening Loop"
        case .night:
            return "Night Watch"
        }
    }

    var body: String {
        switch self {
        case .sunrise:
            return "How are you doing this morning? Want one tiny quest?"
        case .focus:
            return "What is happening over there? I can sit with one task."
        case .afternoon:
            return "Energy check. Need a boost, stretch, or softer step?"
        case .evening:
            return "Want to close one loop before the campfire goes quiet?"
        case .night:
            return "I can keep this gentle. Want a soft check-in?"
        }
    }

    var action: String {
        switch self {
        case .sunrise:
            return "Open morning quest"
        case .focus:
            return "Start focus check"
        case .afternoon:
            return "Open reset"
        case .evening:
            return "Close one loop"
        case .night:
            return "Open night watch"
        }
    }

    var rewardLine: String {
        switch self {
        case .sunrise:
            return "Sunrise check-in answered"
        case .focus:
            return "Focus check-in answered"
        case .afternoon:
            return "Afternoon reset answered"
        case .evening:
            return "Evening loop answered"
        case .night:
            return "Night watch answered"
        }
    }

    var spriteRequestName: String {
        switch self {
        case .sunrise:
            return "pet-{stage}-daypart-sunrise-check.png"
        case .focus:
            return "pet-{stage}-daypart-focus-buddy.png"
        case .afternoon:
            return "pet-{stage}-daypart-afternoon-reset.png"
        case .evening:
            return "pet-{stage}-daypart-evening-loop.png"
        case .night:
            return "pet-{stage}-daypart-night-watch.png"
        }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(offeredMask: Int, answeredMask: Int, dismissedMask: Int) -> String {
        let offered = count(mask: offeredMask)
        let answered = count(mask: answeredMask)
        let dismissed = count(mask: dismissedMask)
        let next = allCases.first { offeredMask & $0.rawValue == 0 }
        let nextText = next.map { "Next \($0.title)" } ?? "All five check-ins seen"
        return "Cheer Rhythm \(answered)/\(allCases.count) answered · \(offered) seen · \(dismissed) skipped · \(nextText)"
    }
}

enum PetCheerDialogue: Int, CaseIterable {
    case howAreYou = 1
    case whatsHappening = 2
    case tinyWin = 4
    case tooMuch = 8
    case focusStart = 16
    case softReset = 32
    case braveNext = 64
    case quietCompany = 128

    var title: String {
        switch self {
        case .howAreYou:
            return "How are you?"
        case .whatsHappening:
            return "What is happening?"
        case .tinyWin:
            return "Tiny win"
        case .tooMuch:
            return "Too much?"
        case .focusStart:
            return "Start beside me"
        case .softReset:
            return "Soft reset"
        case .braveNext:
            return "Brave next"
        case .quietCompany:
            return "Quiet company"
        }
    }

    var shortLabel: String {
        switch self {
        case .howAreYou:
            return "How"
        case .whatsHappening:
            return "What"
        case .tinyWin:
            return "Win"
        case .tooMuch:
            return "Ease"
        case .focusStart:
            return "Start"
        case .softReset:
            return "Reset"
        case .braveNext:
            return "Next"
        case .quietCompany:
            return "Sit"
        }
    }

    var body: String {
        switch self {
        case .howAreYou:
            return "How are you doing? I can hold one tiny thought with you."
        case .whatsHappening:
            return "What is happening over there? Tell me one small piece."
        case .tinyWin:
            return "Did anything go even a little right? I want to save that spark."
        case .tooMuch:
            return "Does it feel like too much? We can shrink it to one soft step."
        case .focusStart:
            return "Want me to sit beside the first minute while you start?"
        case .softReset:
            return "Want a reset? Breathe, stretch, then one tiny click."
        case .braveNext:
            return "What is the next brave little move? I can walk beside it."
        case .quietCompany:
            return "No big quest needed. Want quiet company for a moment?"
        }
    }

    var action: String {
        switch self {
        case .howAreYou:
            return "Open gentle check-in"
        case .whatsHappening:
            return "Open chat"
        case .tinyWin:
            return "Save tiny win"
        case .tooMuch:
            return "Open soft step"
        case .focusStart:
            return "Start first minute"
        case .softReset:
            return "Open reset"
        case .braveNext:
            return "Open next step"
        case .quietCompany:
            return "Sit together"
        }
    }

    var rewardLine: String {
        switch self {
        case .howAreYou:
            return "Gentle check-in answered"
        case .whatsHappening:
            return "What-is-happening check-in answered"
        case .tinyWin:
            return "Tiny win saved"
        case .tooMuch:
            return "Soft-step check-in answered"
        case .focusStart:
            return "First-minute check-in answered"
        case .softReset:
            return "Reset check-in answered"
        case .braveNext:
            return "Brave-next check-in answered"
        case .quietCompany:
            return "Quiet-company check-in answered"
        }
    }

    var rewardReceipt: String {
        switch self {
        case .howAreYou:
            return "Pikachu stores the answer as a warm check-in."
        case .whatsHappening:
            return "The messy middle becomes one named spark."
        case .tinyWin:
            return "A tiny win joins the day trail."
        case .tooMuch:
            return "The big feeling shrinks into one gentler step."
        case .focusStart:
            return "The first minute gets a companion perch."
        case .softReset:
            return "A reset glow clears space around the next step."
        case .braveNext:
            return "The next move gets a small courage mark."
        case .quietCompany:
            return "Quiet company counts as care."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .howAreYou, .tooMuch, .quietCompany:
            return .rest
        case .whatsHappening, .focusStart, .braveNext:
            return .focus
        case .tinyWin, .softReset:
            return .play
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .howAreYou, .tooMuch, .quietCompany:
            return .soothe
        case .whatsHappening, .focusStart:
            return .focus
        case .tinyWin:
            return .cheer
        case .softReset:
            return .rest
        case .braveNext:
            return .adventure
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .howAreYou:
            return .feeling
        case .whatsHappening:
            return .checkIn
        case .tinyWin:
            return .tinyWin
        case .tooMuch:
            return .feeling
        case .focusStart:
            return .focus
        case .softReset:
            return .reset
        case .braveNext:
            return .quest
        case .quietCompany:
            return .rest
        }
    }

    var spriteRequestName: String {
        switch self {
        case .howAreYou:
            return "pet-{stage}-cheer-dialogue-how-are-you.png"
        case .whatsHappening:
            return "pet-{stage}-cheer-dialogue-whats-happening.png"
        case .tinyWin:
            return "pet-{stage}-cheer-dialogue-tiny-win.png"
        case .tooMuch:
            return "pet-{stage}-cheer-dialogue-too-much.png"
        case .focusStart:
            return "pet-{stage}-cheer-dialogue-focus-start.png"
        case .softReset:
            return "pet-{stage}-cheer-dialogue-soft-reset.png"
        case .braveNext:
            return "pet-{stage}-cheer-dialogue-brave-next.png"
        case .quietCompany:
            return "pet-{stage}-cheer-dialogue-quiet-company.png"
        }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(offeredMask: Int, index: Int) -> PetCheerDialogue? {
        let remaining = allCases.filter { offeredMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }
        return remaining[index % remaining.count]
    }

    static func summary(offeredMask: Int, answeredMask: Int, dismissedMask: Int) -> String {
        let offered = count(mask: offeredMask)
        let answered = count(mask: answeredMask)
        let dismissed = count(mask: dismissedMask)
        let nextText = next(offeredMask: offeredMask, index: offered + answered + dismissed)
            .map { "Next \($0.title)" } ?? "All dialogue checks seen"
        return "Cheer Dialogues \(answered)/\(allCases.count) answered · \(offered) seen · \(dismissed) skipped · \(nextText)"
    }
}

enum PetCareNeed: Int, CaseIterable {
    case affection
    case study
    case adventure
    case rest
    case play
    case focus
    case puzzle

    static func daily(for dateKey: String, hour: Int) -> PetCareNeed {
        if hour >= 22 || hour < 6 {
            return .rest
        }

        let seed = dateKey.unicodeScalars.reduce(hour / 3) { $0 + Int($1.value) }
        return allCases[seed % allCases.count]
    }

    var title: String {
        switch self {
        case .affection:
            return "Affection"
        case .study:
            return "Study"
        case .adventure:
            return "Adventure"
        case .rest:
            return "Rest"
        case .play:
            return "Play"
        case .focus:
            return "Focus"
        case .puzzle:
            return "Puzzle"
        }
    }

    var actionLine: String {
        switch self {
        case .affection:
            return "pet once"
        case .study:
            return "practice one phrase"
        case .adventure:
            return "open the quest or ask a hint"
        case .rest:
            return "take a tiny nap"
        case .play:
            return "tap Hyper"
        case .focus:
            return "claim Boost or answer a check-in"
        case .puzzle:
            return "solve the cipher"
        }
    }

    var nudgeLine: String {
        "Care need: \(title). Want to \(actionLine)?"
    }

    var rewardLine: String {
        switch self {
        case .affection:
            return "Its cheeks warm because you noticed it."
        case .study:
            return "It repeats the sound proudly."
        case .adventure:
            return "It marks one more safe trail on the map."
        case .rest:
            return "Its breathing settles into a softer rhythm."
        case .play:
            return "It burns off extra sparks in a happy hop."
        case .focus:
            return "It sits beside the task and keeps watch."
        case .puzzle:
            return "It stores the answer in a tiny thunder note."
        }
    }

    var spriteRequestName: String {
        switch self {
        case .affection:
            return "pet-{stage}-need-affection.png"
        case .study:
            return "pet-{stage}-need-study.png"
        case .adventure:
            return "pet-{stage}-need-adventure.png"
        case .rest:
            return "pet-{stage}-need-rest.png"
        case .play:
            return "pet-{stage}-need-play.png"
        case .focus:
            return "pet-{stage}-need-focus.png"
        case .puzzle:
            return "pet-{stage}-need-puzzle.png"
        }
    }
}

enum PetCareVital: Int, CaseIterable, Hashable {
    case snack
    case rest
    case play
    case focus

    var title: String {
        switch self {
        case .snack:
            return "Snack"
        case .rest:
            return "Rest"
        case .play:
            return "Play"
        case .focus:
            return "Focus"
        }
    }

    var shortLabel: String {
        switch self {
        case .snack:
            return "S"
        case .rest:
            return "R"
        case .play:
            return "P"
        case .focus:
            return "F"
        }
    }

    var refillLine: String {
        switch self {
        case .snack:
            return "Cheeks warm up after care."
        case .rest:
            return "Breathing settles into a softer loop."
        case .play:
            return "Extra sparks burn off in a happy hop."
        case .focus:
            return "It sits beside the next tiny task."
        }
    }

    var lowLine: String {
        switch self {
        case .snack:
            return "Snack is low; pet once or claim a snack card."
        case .rest:
            return "Rest is low; Nap helps it recover."
        case .play:
            return "Play is low; Hyper gives it movement."
        case .focus:
            return "Focus is low; Learn, Hint, or Boost helps."
        }
    }

    var spriteRequestName: String {
        switch self {
        case .snack:
            return "pet-{stage}-vital-snack-low.png"
        case .rest:
            return "pet-{stage}-vital-rest-low.png"
        case .play:
            return "pet-{stage}-vital-play-low.png"
        case .focus:
            return "pet-{stage}-vital-focus-low.png"
        }
    }

    static func lowest(snack: Int, rest: Int, play: Int, focus: Int) -> PetCareVital {
        let pairs: [(PetCareVital, Int)] = [
            (.snack, snack),
            (.rest, rest),
            (.play, play),
            (.focus, focus)
        ]
        return pairs.min { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.rawValue < rhs.0.rawValue
            }
            return lhs.1 < rhs.1
        }?.0 ?? .snack
    }

    static func summary(snack: Int, rest: Int, play: Int, focus: Int) -> String {
        let low = lowest(snack: snack, rest: rest, play: play, focus: focus)
        return "Vitals S\(snack) R\(rest) P\(play) F\(focus) · low \(low.title)"
    }
}

enum PetBondMemory: Int, CaseIterable {
    case firstCare = 1
    case firstHint = 2
    case firstLesson = 4
    case firstQuest = 8
    case firstUpgrade = 16
    case firstComeback = 32
    case firstCipher = 64
    case firstBoost = 128
    case firstBoard = 256
    case firstEvolution = 512

    var title: String {
        switch self {
        case .firstCare:
            return "First Care"
        case .firstHint:
            return "First Hint"
        case .firstLesson:
            return "First Lesson"
        case .firstQuest:
            return "First Quest"
        case .firstUpgrade:
            return "First Upgrade"
        case .firstComeback:
            return "First Comeback"
        case .firstCipher:
            return "First Cipher"
        case .firstBoost:
            return "First Boost"
        case .firstBoard:
            return "First Full Board"
        case .firstEvolution:
            return "First Evolution"
        }
    }

    var unlockLine: String {
        switch self {
        case .firstCare:
            return "It learned your hand is safe."
        case .firstHint:
            return "It learned how to point at a trail."
        case .firstLesson:
            return "It learned your study voice."
        case .firstQuest:
            return "It learned where adventures begin."
        case .firstUpgrade:
            return "It learned the kit can grow."
        case .firstComeback:
            return "It learned you return after silence."
        case .firstCipher:
            return "It learned to keep tiny secrets."
        case .firstBoost:
            return "It learned how to burst into motion."
        case .firstBoard:
            return "It learned a full day can glow."
        case .firstEvolution:
            return "It learned care can change its shape."
        }
    }

    var sparkReward: Int {
        switch self {
        case .firstEvolution:
            return 24
        case .firstBoard, .firstComeback:
            return 16
        default:
            return 8
        }
    }

    static func summary(mask: Int) -> String {
        let unlocked = allCases.filter { mask & $0.rawValue != 0 }
        guard let last = unlocked.last else {
            return "Memories 0/\(allCases.count): First Care waiting"
        }
        return "Memories \(unlocked.count)/\(allCases.count): \(last.title)"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }
}

enum PetStoryCodex {
    static func chapterLine(
        stage: PetGrowthStage,
        memoryMask: Int,
        streak: Int,
        need: PetCareNeed
    ) -> String {
        let memoryCount = PetBondMemory.allCases.filter { memoryMask & $0.rawValue != 0 }.count
        if stage == .stormGuardian {
            return "Story: Guardian chapter, \(memoryCount) memories kept."
        }
        if streak >= 7 {
            return "Story: Week-streak trail, today it wants \(need.title.lowercased())."
        }
        if memoryCount >= 6 {
            return "Story: Trust map growing, \(need.title.lowercased()) scene open."
        }
        if memoryCount >= 3 {
            return "Story: Campfire chapter, bond rituals are working."
        }
        return "Story: First trail, help it learn \(need.title.lowercased())."
    }
}

enum PetCareCharm: Int, CaseIterable {
    case helloSpark = 1
    case snackHeart = 2
    case studyBell = 4
    case trailMap = 8
    case restNest = 16
    case playBolt = 32
    case focusCharm = 64
    case cipherStone = 128
    case eventRibbon = 256
    case upgradeCard = 512
    case weeklyTrail = 1024
    case vitalGlow = 2048

    var title: String {
        switch self {
        case .helloSpark:
            return "Hello Spark"
        case .snackHeart:
            return "Snack Heart"
        case .studyBell:
            return "Study Bell"
        case .trailMap:
            return "Trail Map"
        case .restNest:
            return "Rest Nest"
        case .playBolt:
            return "Play Bolt"
        case .focusCharm:
            return "Focus Charm"
        case .cipherStone:
            return "Cipher Stone"
        case .eventRibbon:
            return "Event Ribbon"
        case .upgradeCard:
            return "Upgrade Card"
        case .weeklyTrail:
            return "Weekly Trail"
        case .vitalGlow:
            return "Vital Glow"
        }
    }

    var shortLabel: String {
        switch self {
        case .helloSpark:
            return "Hi"
        case .snackHeart:
            return "Sn"
        case .studyBell:
            return "St"
        case .trailMap:
            return "Map"
        case .restNest:
            return "Nap"
        case .playBolt:
            return "Run"
        case .focusCharm:
            return "Do"
        case .cipherStone:
            return "Cy"
        case .eventRibbon:
            return "Ev"
        case .upgradeCard:
            return "Up"
        case .weeklyTrail:
            return "Wk"
        case .vitalGlow:
            return "All"
        }
    }

    var unlockLine: String {
        switch self {
        case .helloSpark:
            return "It recognizes your daily hello."
        case .snackHeart:
            return "It trusts care as a snack ritual."
        case .studyBell:
            return "It keeps your study voice in the album."
        case .trailMap:
            return "It knows where adventure starts."
        case .restNest:
            return "It learned that rest is allowed."
        case .playBolt:
            return "It saved a happy movement loop."
        case .focusCharm:
            return "It can sit beside a task without rushing."
        case .cipherStone:
            return "It stores one tiny solved secret."
        case .eventRibbon:
            return "It remembers today's special activity."
        case .upgradeCard:
            return "It knows its kit can grow."
        case .weeklyTrail:
            return "It can see the week becoming a path."
        case .vitalGlow:
            return "All four care vitals glowed at once."
        }
    }

    var spriteRequestName: String {
        switch self {
        case .helloSpark:
            return "pet-{stage}-charm-hello-spark.png"
        case .snackHeart:
            return "pet-{stage}-charm-snack-heart.png"
        case .studyBell:
            return "pet-{stage}-charm-study-bell.png"
        case .trailMap:
            return "pet-{stage}-charm-trail-map.png"
        case .restNest:
            return "pet-{stage}-charm-rest-nest.png"
        case .playBolt:
            return "pet-{stage}-charm-play-bolt.png"
        case .focusCharm:
            return "pet-{stage}-charm-focus-charm.png"
        case .cipherStone:
            return "pet-{stage}-charm-cipher-stone.png"
        case .eventRibbon:
            return "pet-{stage}-charm-event-ribbon.png"
        case .upgradeCard:
            return "pet-{stage}-charm-upgrade-card.png"
        case .weeklyTrail:
            return "pet-{stage}-charm-weekly-trail.png"
        case .vitalGlow:
            return "pet-{stage}-charm-vital-glow.png"
        }
    }

    static func summary(mask: Int) -> String {
        let count = allCases.filter { mask & $0.rawValue != 0 }.count
        let next = allCases.first { mask & $0.rawValue == 0 }
        return "Charms \(count)/\(allCases.count) · next \(next?.title ?? "album complete")"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }
}

enum PetSeasonEvent: Int, CaseIterable {
    case sparkPicnic = 1
    case studyParade = 2
    case skySprint = 4
    case riddleTrail = 8
    case cozyCampfire = 16
    case rescueWalk = 32

    static func daily(for dateKey: String) -> PetSeasonEvent {
        let seed = dateKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return allCases[seed % allCases.count]
    }

    var title: String {
        switch self {
        case .sparkPicnic:
            return "Spark Picnic"
        case .studyParade:
            return "Study Parade"
        case .skySprint:
            return "Sky Sprint"
        case .riddleTrail:
            return "Riddle Trail"
        case .cozyCampfire:
            return "Cozy Campfire"
        case .rescueWalk:
            return "Rescue Walk"
        }
    }

    var badgeTitle: String {
        switch self {
        case .sparkPicnic:
            return "Picnic Badge"
        case .studyParade:
            return "Study Badge"
        case .skySprint:
            return "Sprint Badge"
        case .riddleTrail:
            return "Riddle Badge"
        case .cozyCampfire:
            return "Campfire Badge"
        case .rescueWalk:
            return "Rescue Badge"
        }
    }

    var requiredSteps: Int {
        switch self {
        case .sparkPicnic, .cozyCampfire:
            return 2
        case .studyParade, .riddleTrail:
            return 3
        case .skySprint, .rescueWalk:
            return 4
        }
    }

    var actionLine: String {
        switch self {
        case .sparkPicnic:
            return "gather snack sparks"
        case .studyParade:
            return "repeat tiny phrases"
        case .skySprint:
            return "burn energy in happy bursts"
        case .riddleTrail:
            return "follow clue crumbs"
        case .cozyCampfire:
            return "close the day gently"
        case .rescueWalk:
            return "check the trail for lost sparks"
        }
    }

    var nudgeLine: String {
        "\(title) is open. Want to \(actionLine)?"
    }

    var stepLine: String {
        switch self {
        case .sparkPicnic:
            return "It packs one tiny snack spark."
        case .studyParade:
            return "It marches one phrase forward."
        case .skySprint:
            return "It sprints a tiny loop around the desk."
        case .riddleTrail:
            return "It uncovers one clue crumb."
        case .cozyCampfire:
            return "It adds one warm ember to the campfire."
        case .rescueWalk:
            return "It checks one bend in the trail."
        }
    }

    var completeLine: String {
        switch self {
        case .sparkPicnic:
            return "Picnic blanket full of Sparks."
        case .studyParade:
            return "Study parade finished with a proud bow."
        case .skySprint:
            return "Sprint trail crackles with clean energy."
        case .riddleTrail:
            return "Riddle trail solved and tucked away."
        case .cozyCampfire:
            return "Campfire closed the day softly."
        case .rescueWalk:
            return "Lost Sparks found and guided home."
        }
    }

    var spriteRequestName: String {
        switch self {
        case .sparkPicnic:
            return "pet-{stage}-event-spark-picnic.png"
        case .studyParade:
            return "pet-{stage}-event-study-parade.png"
        case .skySprint:
            return "pet-{stage}-event-sky-sprint.png"
        case .riddleTrail:
            return "pet-{stage}-event-riddle-trail.png"
        case .cozyCampfire:
            return "pet-{stage}-event-cozy-campfire.png"
        case .rescueWalk:
            return "pet-{stage}-event-rescue-walk.png"
        }
    }

    static func badgeSummary(mask: Int) -> String {
        let count = allCases.filter { mask & $0.rawValue != 0 }.count
        return "Badges \(count)/\(allCases.count)"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }
}

enum PetStreakMilestone: Int, CaseIterable {
    case dayOne = 1
    case dayThree = 2
    case dayFive = 4
    case daySeven = 8

    var requiredDays: Int {
        switch self {
        case .dayOne:
            return 1
        case .dayThree:
            return 3
        case .dayFive:
            return 5
        case .daySeven:
            return 7
        }
    }

    var title: String {
        switch self {
        case .dayOne:
            return "First Spark"
        case .dayThree:
            return "Warm Trail"
        case .dayFive:
            return "Trust Charm"
        case .daySeven:
            return "Week Guardian"
        }
    }

    var shortLabel: String {
        switch self {
        case .dayOne:
            return "D1"
        case .dayThree:
            return "D3"
        case .dayFive:
            return "D5"
        case .daySeven:
            return "D7"
        }
    }

    var sparkReward: Int {
        switch self {
        case .dayOne:
            return 8
        case .dayThree:
            return 18
        case .dayFive:
            return 28
        case .daySeven:
            return 45
        }
    }

    var joyReward: Int {
        switch self {
        case .dayOne, .dayThree:
            return 1
        case .dayFive, .daySeven:
            return 2
        }
    }

    var bondHPReward: Int {
        switch self {
        case .dayOne, .dayThree:
            return 0
        case .dayFive, .daySeven:
            return 1
        }
    }

    var rewardLine: String {
        switch self {
        case .dayOne:
            return "The week trail lights its first spark."
        case .dayThree:
            return "It remembers you kept returning."
        case .dayFive:
            return "A trust charm joins the journal."
        case .daySeven:
            return "The full week glows like a tiny storm."
        }
    }

    var spriteRequestName: String {
        switch self {
        case .dayOne:
            return "pet-{stage}-week-day-1-first-spark.png"
        case .dayThree:
            return "pet-{stage}-week-day-3-warm-trail.png"
        case .dayFive:
            return "pet-{stage}-week-day-5-trust-charm.png"
        case .daySeven:
            return "pet-{stage}-week-day-7-guardian-glow.png"
        }
    }

    static func newlyUnlocked(careCount: Int, rewardMask: Int) -> [PetStreakMilestone] {
        allCases.filter { milestone in
            careCount >= milestone.requiredDays && rewardMask & milestone.rawValue == 0
        }
    }

    static func summary(careCount: Int, rewardMask: Int) -> String {
        let unlocked = allCases.filter { rewardMask & $0.rawValue != 0 }.count
        let cappedCount = min(7, max(0, careCount))
        if cappedCount >= 7 {
            return "Week Trail \(cappedCount)/7 · Rewards \(unlocked)/\(allCases.count) · Guardian glow ready"
        }
        let next = allCases.first { careCount < $0.requiredDays }
        let nextLabel = next.map { "Next \($0.shortLabel) \($0.title)" } ?? "All rewards ready"
        return "Week Trail \(cappedCount)/7 · Rewards \(unlocked)/\(allCases.count) · \(nextLabel)"
    }
}

enum PetWeeklyTrailChapter: Int, CaseIterable {
    case firstHello = 1
    case snackPromise = 2
    case focusPerch = 4
    case braveLoop = 8
    case lessonSpark = 16
    case softRest = 32
    case guardianGlow = 64

    var requiredDays: Int {
        switch self {
        case .firstHello:
            return 1
        case .snackPromise:
            return 2
        case .focusPerch:
            return 3
        case .braveLoop:
            return 4
        case .lessonSpark:
            return 5
        case .softRest:
            return 6
        case .guardianGlow:
            return 7
        }
    }

    var title: String {
        switch self {
        case .firstHello:
            return "First Hello"
        case .snackPromise:
            return "Snack Promise"
        case .focusPerch:
            return "Focus Perch"
        case .braveLoop:
            return "Brave Loop"
        case .lessonSpark:
            return "Lesson Spark"
        case .softRest:
            return "Soft Rest"
        case .guardianGlow:
            return "Guardian Glow"
        }
    }

    var shortLabel: String {
        "D\(requiredDays)"
    }

    var storyLine: String {
        switch self {
        case .firstHello:
            return "It learns the shape of your first check-in."
        case .snackPromise:
            return "It saves one snack spark for the next return."
        case .focusPerch:
            return "It finds a quiet perch beside your work."
        case .braveLoop:
            return "It walks one small loop before the quest grows."
        case .lessonSpark:
            return "It repeats one phrase until the spark sticks."
        case .softRest:
            return "It guards a softer ending instead of pushing."
        case .guardianGlow:
            return "The whole week turns into a tiny guardian glow."
        }
    }

    var rewardLine: String {
        "\(title): \(storyLine)"
    }

    var sparkReward: Int {
        switch self {
        case .firstHello:
            return 6
        case .snackPromise:
            return 8
        case .focusPerch:
            return 10
        case .braveLoop:
            return 12
        case .lessonSpark:
            return 14
        case .softRest:
            return 16
        case .guardianGlow:
            return 24
        }
    }

    var joyReward: Int {
        self == .guardianGlow ? 2 : 1
    }

    var bondHPReward: Int {
        self == .guardianGlow ? 1 : 0
    }

    var vital: PetCareVital {
        switch self {
        case .firstHello, .snackPromise:
            return .snack
        case .focusPerch, .lessonSpark:
            return .focus
        case .braveLoop:
            return .play
        case .softRest, .guardianGlow:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .firstHello:
            return .soothe
        case .snackPromise:
            return .snack
        case .focusPerch:
            return .focus
        case .braveLoop:
            return .adventure
        case .lessonSpark:
            return .study
        case .softRest:
            return .rest
        case .guardianGlow:
            return .cheer
        }
    }

    var spriteRequestName: String {
        switch self {
        case .firstHello:
            return "pet-{stage}-week-chapter-day-1-first-hello.png"
        case .snackPromise:
            return "pet-{stage}-week-chapter-day-2-snack-promise.png"
        case .focusPerch:
            return "pet-{stage}-week-chapter-day-3-focus-perch.png"
        case .braveLoop:
            return "pet-{stage}-week-chapter-day-4-brave-loop.png"
        case .lessonSpark:
            return "pet-{stage}-week-chapter-day-5-lesson-spark.png"
        case .softRest:
            return "pet-{stage}-week-chapter-day-6-soft-rest.png"
        case .guardianGlow:
            return "pet-{stage}-week-chapter-day-7-guardian-glow.png"
        }
    }

    static func count(careCount: Int) -> Int {
        allCases.filter { careCount >= $0.requiredDays }.count
    }

    static func albumCount(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func latest(careCount: Int) -> PetWeeklyTrailChapter {
        allCases.last { careCount >= $0.requiredDays } ?? .firstHello
    }

    static func next(careCount: Int) -> PetWeeklyTrailChapter? {
        allCases.first { careCount < $0.requiredDays }
    }

    static func newlyUnlocked(careCount: Int, albumMask: Int) -> [PetWeeklyTrailChapter] {
        allCases.filter { chapter in
            careCount >= chapter.requiredDays && albumMask & chapter.rawValue == 0
        }
    }

    static func summary(careCount: Int, albumMask: Int) -> String {
        let done = count(careCount: careCount)
        let album = albumCount(mask: albumMask)
        let nextText = next(careCount: careCount).map { "Next \($0.shortLabel) \($0.title)" }
            ?? "Guardian week complete"
        return "Week Chapters \(done)/\(allCases.count) · Album \(album)/\(allCases.count) · \(nextText)"
    }
}

enum PetRecoveryScene: Int, CaseIterable {
    case softReturn = 1
    case shieldSaved = 2
    case quietRepair = 4
    case moonNap = 8
    case stormShelter = 16
    case streakRekindled = 32

    var title: String {
        switch self {
        case .softReturn:
            return "Soft Return"
        case .shieldSaved:
            return "Shield Saved"
        case .quietRepair:
            return "Quiet Repair"
        case .moonNap:
            return "Moon Nap"
        case .stormShelter:
            return "Storm Shelter"
        case .streakRekindled:
            return "Streak Rekindled"
        }
    }

    var shortLabel: String {
        switch self {
        case .softReturn:
            return "Back"
        case .shieldSaved:
            return "Shield"
        case .quietRepair:
            return "Repair"
        case .moonNap:
            return "Moon"
        case .stormShelter:
            return "Shelter"
        case .streakRekindled:
            return "Rekindle"
        }
    }

    var storyLine: String {
        switch self {
        case .softReturn:
            return "It notices the missed day and chooses a gentle hello instead of guilt."
        case .shieldSaved:
            return "A stored streak shield glows once and keeps the trail warm."
        case .quietRepair:
            return "It sits beside the user and patches the bond with a small ritual."
        case .moonNap:
            return "It slept through the gap and wakes up ready to try again."
        case .stormShelter:
            return "It built a tiny shelter around the bond while the user was away."
        case .streakRekindled:
            return "After returning, the next steady streak turns into a comeback keepsake."
        }
    }

    var rewardLine: String {
        "\(title): \(storyLine)"
    }

    var sparkReward: Int {
        switch self {
        case .softReturn:
            return 8
        case .shieldSaved:
            return 12
        case .quietRepair:
            return 14
        case .moonNap:
            return 18
        case .stormShelter:
            return 24
        case .streakRekindled:
            return 30
        }
    }

    var joyReward: Int {
        switch self {
        case .softReturn, .shieldSaved, .quietRepair:
            return 1
        case .moonNap, .stormShelter, .streakRekindled:
            return 2
        }
    }

    var vital: PetCareVital {
        switch self {
        case .softReturn, .shieldSaved:
            return .snack
        case .quietRepair, .streakRekindled:
            return .focus
        case .moonNap, .stormShelter:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .softReturn:
            return .soothe
        case .shieldSaved:
            return .cheer
        case .quietRepair:
            return .focus
        case .moonNap:
            return .rest
        case .stormShelter:
            return .soothe
        case .streakRekindled:
            return .play
        }
    }

    var spriteRequestName: String {
        switch self {
        case .softReturn:
            return "pet-{stage}-recovery-soft-return.png"
        case .shieldSaved:
            return "pet-{stage}-recovery-shield-saved.png"
        case .quietRepair:
            return "pet-{stage}-recovery-quiet-repair.png"
        case .moonNap:
            return "pet-{stage}-recovery-moon-nap.png"
        case .stormShelter:
            return "pet-{stage}-recovery-storm-shelter.png"
        case .streakRekindled:
            return "pet-{stage}-recovery-streak-rekindled.png"
        }
    }

    static func scene(daysMissed: Int, shieldUsed: Bool) -> PetRecoveryScene {
        if shieldUsed {
            return .shieldSaved
        }
        if daysMissed <= 1 {
            return .softReturn
        }
        if daysMissed <= 3 {
            return .quietRepair
        }
        if daysMissed <= 6 {
            return .moonNap
        }
        return .stormShelter
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(mask: Int, shieldCount: Int, latest: PetRecoveryScene?) -> String {
        let latestText = latest.map { "Latest \($0.title)" } ?? "No comeback scene yet"
        return "Recovery \(count(mask: mask))/\(allCases.count) · Shields \(shieldCount)/3 · \(latestText)"
    }
}

struct PetComebackReward {
    let sparks: Int
    let joy: Int
    let energy: Int
    let chestName: String

    var line: String {
        "\(chestName) opened: Joy +\(joy), Energy +\(energy), Sparks +\(sparks)."
    }
}

enum PetLifecycleRules {
    static func comebackReward(hoursAway: Int, nestLevel: Int, sparkLevel: Int) -> PetComebackReward? {
        guard hoursAway >= 4 else { return nil }
        let chest: String
        let base: Int
        if hoursAway >= 24 {
            chest = "Storm Chest"
            base = 28
        } else if hoursAway >= 12 {
            chest = "Moon Chest"
            base = 20
        } else {
            chest = "Pocket Chest"
            base = 12
        }

        return PetComebackReward(
            sparks: min(80, base + nestLevel * 4 + sparkLevel * 3),
            joy: hoursAway >= 12 ? 2 : 1,
            energy: hoursAway >= 8 ? 2 : 1,
            chestName: chest
        )
    }

    static func decayLine(hoursIdle: Int) -> String? {
        if hoursIdle >= 18 {
            return "It waited a long while, so Joy softened by 1. A quick pet repairs it."
        }
        if hoursIdle >= 8 {
            return "It got a little lonely while waiting. One check-in warms it back up."
        }
        return nil
    }
}

enum PetCheerIntent: Int, CaseIterable {
    case checkIn = 1
    case feeling = 2
    case focus = 4
    case tinyWin = 8
    case reset = 16
    case quest = 32
    case lesson = 64
    case rest = 128
    case comeback = 256
    case board = 512
    case puzzle = 1024
    case boost = 2048
    case upgrade = 4096
    case event = 8192
    case care = 16384

    var title: String {
        switch self {
        case .checkIn:
            return "Gentle Check"
        case .feeling:
            return "Feeling Check"
        case .focus:
            return "Focus Start"
        case .tinyWin:
            return "Tiny Win"
        case .reset:
            return "Soft Reset"
        case .quest:
            return "Quest Nudge"
        case .lesson:
            return "Lesson Spark"
        case .rest:
            return "Rest Watch"
        case .comeback:
            return "Comeback"
        case .board:
            return "Board Contract"
        case .puzzle:
            return "Puzzle Clue"
        case .boost:
            return "Spark Boost"
        case .upgrade:
            return "Upgrade"
        case .event:
            return "Event Step"
        case .care:
            return "Care Ritual"
        }
    }

    var shortLabel: String {
        switch self {
        case .checkIn:
            return "Hi"
        case .feeling:
            return "Feel"
        case .focus:
            return "Focus"
        case .tinyWin:
            return "Win"
        case .reset:
            return "Reset"
        case .quest:
            return "Quest"
        case .lesson:
            return "Learn"
        case .rest:
            return "Rest"
        case .comeback:
            return "Back"
        case .board:
            return "Board"
        case .puzzle:
            return "Clue"
        case .boost:
            return "Boost"
        case .upgrade:
            return "Card"
        case .event:
            return "Event"
        case .care:
            return "Care"
        }
    }

    var receiptLine: String {
        switch self {
        case .checkIn:
            return "A warm check-in joins today's trail."
        case .feeling:
            return "A feeling got named instead of ignored."
        case .focus:
            return "The first minute gets a companion perch."
        case .tinyWin:
            return "A tiny win is saved as proof of motion."
        case .reset:
            return "The next step gets smaller and softer."
        case .quest:
            return "The quest path gets one safe marker."
        case .lesson:
            return "One phrase turns into a lesson spark."
        case .rest:
            return "Rest counts as care, not falling behind."
        case .comeback:
            return "Coming back becomes part of the bond."
        case .board:
            return "A care contract gets a visible receipt."
        case .puzzle:
            return "A clue becomes one solved spark."
        case .boost:
            return "Extra energy is routed into the next loop."
        case .upgrade:
            return "Stored Sparks point toward the next charm."
        case .event:
            return "Today's event gets one story beat."
        case .care:
            return "The current care ritual gets answered."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .checkIn, .feeling, .reset, .rest, .comeback:
            return .rest
        case .focus, .lesson, .board, .puzzle, .boost, .upgrade:
            return .focus
        case .tinyWin, .quest, .event:
            return .play
        case .care:
            return .snack
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .checkIn, .feeling, .comeback:
            return .soothe
        case .focus, .boost, .upgrade:
            return .focus
        case .tinyWin:
            return .cheer
        case .reset, .rest:
            return .rest
        case .quest, .event:
            return .adventure
        case .lesson:
            return .study
        case .board, .care:
            return .cheer
        case .puzzle:
            return .puzzle
        }
    }

    var spriteSlug: String {
        switch self {
        case .checkIn:
            return "gentle-check"
        case .feeling:
            return "feeling-check"
        case .focus:
            return "focus-start"
        case .tinyWin:
            return "tiny-win"
        case .reset:
            return "soft-reset"
        case .quest:
            return "quest-nudge"
        case .lesson:
            return "lesson-spark"
        case .rest:
            return "rest-watch"
        case .comeback:
            return "comeback"
        case .board:
            return "board-contract"
        case .puzzle:
            return "puzzle-clue"
        case .boost:
            return "spark-boost"
        case .upgrade:
            return "upgrade"
        case .event:
            return "event-step"
        case .care:
            return "care-ritual"
        }
    }

    var sparkReward: Int {
        switch self {
        case .checkIn, .feeling, .reset, .rest:
            return 3
        case .focus, .tinyWin, .care:
            return 4
        case .quest, .lesson, .board, .puzzle:
            return 5
        case .comeback, .boost, .upgrade, .event:
            return 6
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-proactive-intent-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(offeredMask: Int, index: Int) -> PetCheerIntent? {
        let remaining = allCases.filter { offeredMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }
        return remaining[index % remaining.count]
    }

    static func summary(offeredMask: Int, answeredMask: Int, dismissedMask: Int, albumMask: Int) -> String {
        let answered = count(mask: answeredMask)
        let offered = count(mask: offeredMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let nextText = next(offeredMask: offeredMask, index: offered + answered + dismissed)
            .map { "Next \($0.title)" } ?? "All check-in types seen"
        return "Check-in Types \(answered)/\(allCases.count) answered · \(offered) seen · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(nextText)"
    }
}

enum PetCheerMemory: Int, CaseIterable {
    case warmCheck = 1
    case whatsHappening = 2
    case tinyWinSaved = 4
    case overwhelmSoftened = 8
    case firstMinute = 16
    case softReset = 32
    case braveStep = 64
    case quietCompany = 128
    case sunriseHello = 256
    case focusPerch = 512
    case afternoonReset = 1024
    case eveningClose = 2048
    case nightWatch = 4096
    case lessonSpark = 8192
    case comebackGlow = 16384
    case careContract = 32768
    case puzzleClue = 65536
    case boostRouted = 131072
    case upgradeWish = 262144
    case eventBeat = 524288
    case careRitual = 1048576

    var title: String {
        switch self {
        case .warmCheck:
            return "Warm Check"
        case .whatsHappening:
            return "What Happened"
        case .tinyWinSaved:
            return "Tiny Win Saved"
        case .overwhelmSoftened:
            return "Too Much Softened"
        case .firstMinute:
            return "First Minute"
        case .softReset:
            return "Soft Reset"
        case .braveStep:
            return "Brave Step"
        case .quietCompany:
            return "Quiet Company"
        case .sunriseHello:
            return "Sunrise Hello"
        case .focusPerch:
            return "Focus Perch"
        case .afternoonReset:
            return "Afternoon Reset"
        case .eveningClose:
            return "Evening Close"
        case .nightWatch:
            return "Night Watch"
        case .lessonSpark:
            return "Lesson Spark"
        case .comebackGlow:
            return "Comeback Glow"
        case .careContract:
            return "Care Contract"
        case .puzzleClue:
            return "Puzzle Clue"
        case .boostRouted:
            return "Boost Routed"
        case .upgradeWish:
            return "Upgrade Wish"
        case .eventBeat:
            return "Event Beat"
        case .careRitual:
            return "Care Ritual"
        }
    }

    var shortLabel: String {
        switch self {
        case .warmCheck:
            return "Warm"
        case .whatsHappening:
            return "What"
        case .tinyWinSaved:
            return "Win"
        case .overwhelmSoftened:
            return "Ease"
        case .firstMinute:
            return "Min"
        case .softReset:
            return "Reset"
        case .braveStep:
            return "Brave"
        case .quietCompany:
            return "Quiet"
        case .sunriseHello:
            return "Sun"
        case .focusPerch:
            return "Focus"
        case .afternoonReset:
            return "Noon"
        case .eveningClose:
            return "Eve"
        case .nightWatch:
            return "Night"
        case .lessonSpark:
            return "Learn"
        case .comebackGlow:
            return "Back"
        case .careContract:
            return "Board"
        case .puzzleClue:
            return "Clue"
        case .boostRouted:
            return "Boost"
        case .upgradeWish:
            return "Card"
        case .eventBeat:
            return "Event"
        case .careRitual:
            return "Care"
        }
    }

    var storyLine: String {
        switch self {
        case .warmCheck:
            return "The pet asks how you are and keeps the answer gently."
        case .whatsHappening:
            return "A messy moment becomes one named spark it can carry."
        case .tinyWinSaved:
            return "One small win is saved as proof that the day moved."
        case .overwhelmSoftened:
            return "A too-large feeling gets folded into one softer step."
        case .firstMinute:
            return "The pet sits beside the first minute so starting feels less alone."
        case .softReset:
            return "A breath and stretch clear a little room around the next click."
        case .braveStep:
            return "The next brave move gets a tiny trail marker."
        case .quietCompany:
            return "Quiet company becomes care even when nothing big happens."
        case .sunriseHello:
            return "The day starts with recognition instead of pressure."
        case .focusPerch:
            return "It perches beside one task and keeps watch."
        case .afternoonReset:
            return "Low afternoon energy becomes a reset, not a failure."
        case .eveningClose:
            return "One open loop gets tucked beside the campfire."
        case .nightWatch:
            return "The pet guards the quiet hours with no urgency."
        case .lessonSpark:
            return "One phrase becomes a bright study keepsake."
        case .comebackGlow:
            return "Returning becomes part of the bond instead of a missed streak."
        case .careContract:
            return "A daily board task becomes a care receipt."
        case .puzzleClue:
            return "A clue is carried safely until the next puzzle step."
        case .boostRouted:
            return "Extra energy gets routed into a calmer next loop."
        case .upgradeWish:
            return "Saved Sparks point toward the next charm without shame."
        case .eventBeat:
            return "Today's event gets one warm story beat."
        case .careRitual:
            return "The current care need is answered and remembered."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .warmCheck, .overwhelmSoftened, .quietCompany, .nightWatch, .comebackGlow:
            return .rest
        case .whatsHappening, .firstMinute, .focusPerch, .lessonSpark, .careContract, .puzzleClue, .boostRouted, .upgradeWish:
            return .focus
        case .tinyWinSaved, .braveStep, .sunriseHello, .afternoonReset, .eveningClose, .eventBeat:
            return .play
        case .softReset, .careRitual:
            return .snack
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .warmCheck, .overwhelmSoftened, .quietCompany, .comebackGlow:
            return .soothe
        case .whatsHappening, .firstMinute, .focusPerch, .boostRouted, .upgradeWish:
            return .focus
        case .tinyWinSaved, .careContract, .careRitual:
            return .cheer
        case .softReset, .nightWatch:
            return .rest
        case .braveStep, .eventBeat, .eveningClose:
            return .adventure
        case .sunriseHello, .afternoonReset:
            return .play
        case .lessonSpark:
            return .study
        case .puzzleClue:
            return .puzzle
        }
    }

    var sparkReward: Int {
        switch self {
        case .warmCheck, .whatsHappening, .overwhelmSoftened, .quietCompany, .sunriseHello, .nightWatch:
            return 4
        case .tinyWinSaved, .firstMinute, .softReset, .braveStep, .focusPerch, .afternoonReset, .eveningClose, .careRitual:
            return 5
        case .lessonSpark, .comebackGlow, .careContract, .puzzleClue, .boostRouted, .upgradeWish, .eventBeat:
            return 6
        }
    }

    var spriteSlug: String {
        switch self {
        case .warmCheck:
            return "warm-check"
        case .whatsHappening:
            return "whats-happening"
        case .tinyWinSaved:
            return "tiny-win-saved"
        case .overwhelmSoftened:
            return "overwhelm-softened"
        case .firstMinute:
            return "first-minute"
        case .softReset:
            return "soft-reset"
        case .braveStep:
            return "brave-step"
        case .quietCompany:
            return "quiet-company"
        case .sunriseHello:
            return "sunrise-hello"
        case .focusPerch:
            return "focus-perch"
        case .afternoonReset:
            return "afternoon-reset"
        case .eveningClose:
            return "evening-close"
        case .nightWatch:
            return "night-watch"
        case .lessonSpark:
            return "lesson-spark"
        case .comebackGlow:
            return "comeback-glow"
        case .careContract:
            return "care-contract"
        case .puzzleClue:
            return "puzzle-clue"
        case .boostRouted:
            return "boost-routed"
        case .upgradeWish:
            return "upgrade-wish"
        case .eventBeat:
            return "event-beat"
        case .careRitual:
            return "care-ritual"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-cheer-memory-\(spriteSlug).png"
    }

    static func scene(dialogue: PetCheerDialogue?, intent: PetCheerIntent, daypart: PetDaypartNudge?) -> PetCheerMemory {
        if let dialogue {
            switch dialogue {
            case .howAreYou:
                return .warmCheck
            case .whatsHappening:
                return .whatsHappening
            case .tinyWin:
                return .tinyWinSaved
            case .tooMuch:
                return .overwhelmSoftened
            case .focusStart:
                return .firstMinute
            case .softReset:
                return .softReset
            case .braveNext:
                return .braveStep
            case .quietCompany:
                return .quietCompany
            }
        }

        if let daypart {
            switch daypart {
            case .sunrise:
                return .sunriseHello
            case .focus:
                return .focusPerch
            case .afternoon:
                return .afternoonReset
            case .evening:
                return .eveningClose
            case .night:
                return .nightWatch
            }
        }

        switch intent {
        case .checkIn:
            return .warmCheck
        case .feeling:
            return .overwhelmSoftened
        case .focus:
            return .firstMinute
        case .tinyWin:
            return .tinyWinSaved
        case .reset:
            return .softReset
        case .quest:
            return .braveStep
        case .lesson:
            return .lessonSpark
        case .rest:
            return .quietCompany
        case .comeback:
            return .comebackGlow
        case .board:
            return .careContract
        case .puzzle:
            return .puzzleClue
        case .boost:
            return .boostRouted
        case .upgrade:
            return .upgradeWish
        case .event:
            return .eventBeat
        case .care:
            return .careRitual
        }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(dailyMask: Int, albumMask: Int, latest: PetCheerMemory) -> String {
        let today = count(mask: dailyMask)
        let album = count(mask: albumMask)
        return "Cheer Memories \(today) today · Album \(album)/\(allCases.count) · Latest \(latest.title)"
    }
}

enum PetLoreCodex {
    static func line(
        stage: PetGrowthStage,
        feeling: PetFeeling,
        snackLevel: Int,
        lessonLevel: Int,
        questLevel: Int,
        nestLevel: Int,
        cheerLevel: Int,
        sparkLevel: Int,
        focusLevel: Int,
        cipherLevel: Int
    ) -> String {
        let strongestUpgrade = [
            ("snack", snackLevel),
            ("lesson", lessonLevel),
            ("quest", questLevel),
            ("nest", nestLevel),
            ("cheer", cheerLevel),
            ("spark", sparkLevel),
            ("focus", focusLevel),
            ("cipher", cipherLevel)
        ].max { $0.1 < $1.1 }

        if let strongestUpgrade, strongestUpgrade.1 > 0 {
            return "\(stage.loreLine) Favorite charm: \(strongestUpgrade.0)."
        }
        return "\(stage.loreLine) \(feeling.helperLine)"
    }
}

enum PetNudgeLibrary {
    struct PetCheerPrompt {
        let title: String
        let body: String
        let action: String
        let rewardLine: String
        let intent: PetCheerIntent

        init(
            title: String,
            body: String,
            action: String,
            rewardLine: String,
            intent: PetCheerIntent = .checkIn
        ) {
            self.title = title
            self.body = body
            self.action = action
            self.rewardLine = rewardLine
            self.intent = intent
        }

        var bubbleText: String {
            "\(title): \(body)"
        }
    }

    static func moodCarePrompt(
        feeling: PetFeeling,
        recipe: PetMoodCareRecipe,
        step: PetMoodCareStep,
        stage: PetGrowthStage
    ) -> PetCheerPrompt {
        let body: String
        switch step {
        case .soothe:
            body = "I feel \(feeling.title.lowercased()). Can we do one gentle check-in?"
        case .snack:
            body = "My \(feeling.title.lowercased()) mood wants a tiny snack spark."
        case .rest:
            body = "I can keep watch. Want to let this mood rest for a moment?"
        case .play:
            body = "This mood has extra sparks. Want a tiny play burst?"
        case .study:
            body = "I am listening. Want to practice one small phrase together?"
        case .adventure:
            body = "This mood wants a little trail. Want one tiny quest step?"
        case .focus:
            body = "I can sit beside the task. Want one quiet focus spark?"
        case .puzzle:
            body = "This mood is curious. Want to solve one tiny clue?"
        case .cheer:
            body = "How are you doing? I can turn this into a warm check-in."
        }

        let intent: PetCheerIntent
        switch step {
        case .soothe, .cheer:
            intent = .feeling
        case .snack:
            intent = .care
        case .rest:
            intent = .rest
        case .play:
            intent = .tinyWin
        case .study:
            intent = .lesson
        case .adventure:
            intent = .quest
        case .focus:
            intent = .focus
        case .puzzle:
            intent = .puzzle
        }

        return PetCheerPrompt(
            title: "\(feeling.title) care",
            body: body,
            action: step == .rest ? "Open a rest check-in" : "Open \(step.title) care",
            rewardLine: "\(recipe.title) \(step.title) answered for \(stage.title)",
            intent: intent
        )
    }

    static func cheerPrompt(
        feeling: PetFeeling,
        stage: PetGrowthStage,
        combo: [PetComboAction],
        comboMask: Int,
        nextQuest: PetDailyQuest?,
        cipher: PetDailyCipher,
        cipherSolved: Bool,
        boosterReady: Bool,
        careMoment: PetCareMoment,
        careNeed: PetCareNeed,
        seasonEvent: PetSeasonEvent,
        eventProgress: Int,
        comebackReady: Bool,
        energy: Int,
        sparkDust: Int,
        index: Int
    ) -> PetCheerPrompt {
        if comebackReady {
            return PetCheerPrompt(
                title: "Welcome back",
                body: "I saved a small chest while you were away.",
                action: "Open the comeback check-in",
                rewardLine: "Comeback answered",
                intent: .comeback
            )
        }
        if energy == 0 {
            return PetCheerPrompt(
                title: "Soft recharge",
                body: "I am sleepy, but I saved your quest.",
                action: "Open a gentle check-in",
                rewardLine: "Quiet check-in answered",
                intent: .rest
            )
        }
        if index % 3 == 1 {
            return PetCheerPrompt(
                title: "\(careNeed.title) check",
                body: "How are you doing? Want to \(careNeed.actionLine)?",
                action: "Open the care ritual",
                rewardLine: "\(careNeed.title) check-in answered",
                intent: .care
            )
        }
        if eventProgress < seasonEvent.requiredSteps {
            return PetCheerPrompt(
                title: seasonEvent.title,
                body: "Want to \(seasonEvent.actionLine)?",
                action: "Open today's event",
                rewardLine: "\(seasonEvent.title) check-in answered",
                intent: .event
            )
        }
        if index % 5 == 0 {
            return PetCheerPrompt(
                title: careMoment.title,
                body: careMoment.nudgeLine,
                action: "Open the time-of-day check-in",
                rewardLine: "\(careMoment.title) check-in answered",
                intent: .checkIn
            )
        }
        if boosterReady {
            return PetCheerPrompt(
                title: "Boost ready",
                body: "Want a quick burst before the next quest?",
                action: "Open Spark Boost",
                rewardLine: "Boost check-in answered",
                intent: .boost
            )
        }
        if !cipherSolved {
            return PetCheerPrompt(
                title: "Tiny cipher",
                body: "\(cipher.clue). I can solve it with you.",
                action: "Open today's cipher",
                rewardLine: "Cipher check-in answered",
                intent: .puzzle
            )
        }
        if sparkDust >= 80 {
            return PetCheerPrompt(
                title: "Kit upgrade",
                body: "\(sparkDust) Sparks are glowing. Want an upgrade?",
                action: "Open upgrade",
                rewardLine: "Upgrade check-in answered",
                intent: .upgrade
            )
        }
        if let nextQuest {
            return PetCheerPrompt(
                title: "Daily board",
                body: "How are you doing? Want to \(nextQuest.nudgeText)?",
                action: "Open today's board",
                rewardLine: "\(nextQuest.title) check-in answered",
                intent: nextQuest.cheerIntent
            )
        }
        if let nextAction = combo.first(where: { comboMask & $0.rawValue == 0 }) {
            return PetCheerPrompt(
                title: "Tiny combo",
                body: "How are you doing? Want to \(nextAction.nudgeText)?",
                action: "Open the combo step",
                rewardLine: "\(nextAction.label) combo check-in answered",
                intent: nextAction.cheerIntent
            )
        }

        let fallback = [
            PetCheerPrompt(title: stage.title, body: "Want one brave click?", action: "Open a tiny quest", rewardLine: "Tiny quest check-in answered", intent: .quest),
            PetCheerPrompt(title: "I kept watch", body: "Want a 60-second quest?", action: "Open a short quest", rewardLine: "Watch check-in answered", intent: .quest),
            PetCheerPrompt(title: "\(feeling.title) mood", body: "Need a hint or a phrase?", action: "Open a mood check-in", rewardLine: "\(feeling.title) check-in answered", intent: .feeling),
            PetCheerPrompt(title: "Tiny lesson", body: "Want one phrase and one proud spark?", action: "Open a phrase", rewardLine: "Lesson check-in answered", intent: .lesson),
            PetCheerPrompt(title: "Tiny reset", body: "Breathe, stretch, then one spark?", action: "Open a reset", rewardLine: "Reset check-in answered", intent: .reset),
            PetCheerPrompt(title: "Pika check", body: "What is happening over there?", action: "Open chat", rewardLine: "Chat check-in answered", intent: .checkIn),
            PetCheerPrompt(title: "I found a task", body: "Want me to sit with you while you start?", action: "Open focus mode", rewardLine: "Focus check-in answered", intent: .focus),
            PetCheerPrompt(title: "Warm bond", body: "No big quest needed. One tap is enough.", action: "Open a gentle check-in", rewardLine: "Bond check-in answered", intent: .care)
        ]
        return fallback[index % fallback.count]
    }

    static func cheerLine(
        feeling: PetFeeling,
        stage: PetGrowthStage,
        combo: [PetComboAction],
        comboMask: Int,
        nextQuest: PetDailyQuest?,
        cipher: PetDailyCipher,
        cipherSolved: Bool,
        boosterReady: Bool,
        careMoment: PetCareMoment,
        careNeed: PetCareNeed,
        seasonEvent: PetSeasonEvent,
        eventProgress: Int,
        comebackReady: Bool,
        energy: Int,
        sparkDust: Int,
        index: Int
    ) -> String {
        cheerPrompt(
            feeling: feeling,
            stage: stage,
            combo: combo,
            comboMask: comboMask,
            nextQuest: nextQuest,
            cipher: cipher,
            cipherSolved: cipherSolved,
            boosterReady: boosterReady,
            careMoment: careMoment,
            careNeed: careNeed,
            seasonEvent: seasonEvent,
            eventProgress: eventProgress,
            comebackReady: comebackReady,
            energy: energy,
            sparkDust: sparkDust,
            index: index
        ).bubbleText
    }
}
