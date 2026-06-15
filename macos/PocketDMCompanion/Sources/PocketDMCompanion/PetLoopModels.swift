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
        case "bond board", "care window":
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

enum PetEmotionArc: Int, CaseIterable {
    case firstTrust = 1
    case braveStart = 2
    case proudGlow = 4
    case overchargeGround = 8
    case focusPerch = 16
    case celebrationShare = 32
    case nightGuardian = 64
    case gentleRepair = 128
    case playfulSprint = 256
    case gratefulKeepsake = 512
    case growReady = 1024
    case restlessRedirect = 2048
    case snackRescue = 4096
    case sleepNest = 8192
    case curiousTrail = 16384
    case lonelyComeback = 32768

    var title: String {
        switch self {
        case .firstTrust:
            return "First Trust"
        case .braveStart:
            return "Brave Start"
        case .proudGlow:
            return "Proud Glow"
        case .overchargeGround:
            return "Overcharge Ground"
        case .focusPerch:
            return "Focus Perch"
        case .celebrationShare:
            return "Shared Celebration"
        case .nightGuardian:
            return "Night Guardian"
        case .gentleRepair:
            return "Gentle Repair"
        case .playfulSprint:
            return "Playful Sprint"
        case .gratefulKeepsake:
            return "Grateful Keepsake"
        case .growReady:
            return "Grow Ready"
        case .restlessRedirect:
            return "Restless Redirect"
        case .snackRescue:
            return "Snack Rescue"
        case .sleepNest:
            return "Sleep Nest"
        case .curiousTrail:
            return "Curious Trail"
        case .lonelyComeback:
            return "Lonely Comeback"
        }
    }

    var shortLabel: String {
        switch self {
        case .firstTrust:
            return "Trust"
        case .braveStart:
            return "Brave"
        case .proudGlow:
            return "Proud"
        case .overchargeGround:
            return "Ground"
        case .focusPerch:
            return "Focus"
        case .celebrationShare:
            return "Share"
        case .nightGuardian:
            return "Guard"
        case .gentleRepair:
            return "Repair"
        case .playfulSprint:
            return "Sprint"
        case .gratefulKeepsake:
            return "Thanks"
        case .growReady:
            return "Grow"
        case .restlessRedirect:
            return "Redirect"
        case .snackRescue:
            return "Snack"
        case .sleepNest:
            return "Nest"
        case .curiousTrail:
            return "Trail"
        case .lonelyComeback:
            return "Return"
        }
    }

    var feeling: PetFeeling {
        switch self {
        case .firstTrust:
            return .bright
        case .braveStart:
            return .eager
        case .proudGlow:
            return .proud
        case .overchargeGround:
            return .overcharged
        case .focusPerch:
            return .focused
        case .celebrationShare:
            return .celebrating
        case .nightGuardian:
            return .protective
        case .gentleRepair:
            return .comfort
        case .playfulSprint:
            return .playful
        case .gratefulKeepsake:
            return .grateful
        case .growReady:
            return .determined
        case .restlessRedirect:
            return .restless
        case .snackRescue:
            return .hungry
        case .sleepNest:
            return .sleepy
        case .curiousTrail:
            return .curious
        case .lonelyComeback:
            return .lonely
        }
    }

    var openingLine: String {
        switch self {
        case .firstTrust:
            return "It looks down, looks up, then smiles when the user notices."
        case .braveStart:
            return "It bounces at the edge of a task and asks for one tiny first step."
        case .proudGlow:
            return "It holds a completed spark close before showing it off."
        case .overchargeGround:
            return "Too much charge crackles around it until the user helps route it."
        case .focusPerch:
            return "It climbs into a quiet perch and watches the next action."
        case .celebrationShare:
            return "It wants the win to be seen, not rushed past."
        case .nightGuardian:
            return "It lowers its voice and guards the late desktop."
        case .gentleRepair:
            return "It notices a rough moment and makes the next step smaller."
        case .playfulSprint:
            return "It asks for a small burst of movement before settling."
        case .gratefulKeepsake:
            return "It remembers the care streak and makes a keepsake from it."
        case .growReady:
            return "It stands taller because the bond is close to changing shape."
        case .restlessRedirect:
            return "Restless sparks circle until they become one useful card."
        case .snackRescue:
            return "Low energy makes it wobble gently toward a snack cue."
        case .sleepNest:
            return "It curls into a nest and lets tiredness be visible."
        case .curiousTrail:
            return "It tilts its head at a mystery and wants one clue."
        case .lonelyComeback:
            return "It waits without blame, then brightens at the user's return."
        }
    }

    var careLine: String {
        switch self {
        case .firstTrust:
            return "Care beat: pet once, then let the greeting animation finish."
        case .braveStart:
            return "Care beat: name one next action and reward the start."
        case .proudGlow:
            return "Care beat: pause on the completed work and save it to memory."
        case .overchargeGround:
            return "Care beat: use focus, water, or rest to ground the charge."
        case .focusPerch:
            return "Care beat: keep the pet still while the user works."
        case .celebrationShare:
            return "Care beat: cheer once, then offer a soft next loop."
        case .nightGuardian:
            return "Care beat: close a loose thread and protect rest."
        case .gentleRepair:
            return "Care beat: soothe first, then ask for a smaller task."
        case .playfulSprint:
            return "Care beat: spend one energy burst without breaking flow."
        case .gratefulKeepsake:
            return "Care beat: turn the streak into a visible charm."
        case .growReady:
            return "Care beat: complete the growth quest and preview the next form."
        case .restlessRedirect:
            return "Care beat: convert fidget energy into an upgrade choice."
        case .snackRescue:
            return "Care beat: snack, refill, and slow the animation."
        case .sleepNest:
            return "Care beat: nap, dim sparks, and mark rest as progress."
        case .curiousTrail:
            return "Care beat: ask one hint or solve one small puzzle."
        case .lonelyComeback:
            return "Care beat: welcome back, refill joy, and avoid guilt."
        }
    }

    var resolutionLine: String {
        switch self {
        case .firstTrust:
            return "Resolved into a reliable hello."
        case .braveStart:
            return "Resolved into first-step courage."
        case .proudGlow:
            return "Resolved into a saved proof of progress."
        case .overchargeGround:
            return "Resolved into contained energy."
        case .focusPerch:
            return "Resolved into quiet company."
        case .celebrationShare:
            return "Resolved into a shared win."
        case .nightGuardian:
            return "Resolved into permission to rest."
        case .gentleRepair:
            return "Resolved into a kinder retry."
        case .playfulSprint:
            return "Resolved into playful momentum."
        case .gratefulKeepsake:
            return "Resolved into a bond keepsake."
        case .growReady:
            return "Resolved into evolution readiness."
        case .restlessRedirect:
            return "Resolved into a chosen upgrade."
        case .snackRescue:
            return "Resolved into refilled care."
        case .sleepNest:
            return "Resolved into protected recharge."
        case .curiousTrail:
            return "Resolved into a clue trail."
        case .lonelyComeback:
            return "Resolved into warm return memory."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .firstTrust, .gratefulKeepsake, .snackRescue:
            return .snack
        case .nightGuardian, .gentleRepair, .sleepNest, .lonelyComeback:
            return .rest
        case .braveStart, .playfulSprint, .celebrationShare:
            return .play
        case .proudGlow, .overchargeGround, .focusPerch, .growReady, .restlessRedirect, .curiousTrail:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .firstTrust, .gentleRepair, .lonelyComeback:
            return .soothe
        case .snackRescue:
            return .snack
        case .nightGuardian, .sleepNest:
            return .rest
        case .playfulSprint, .celebrationShare:
            return .play
        case .curiousTrail:
            return .puzzle
        case .braveStart, .growReady:
            return .adventure
        case .focusPerch, .overchargeGround, .restlessRedirect:
            return .focus
        case .proudGlow, .gratefulKeepsake:
            return .cheer
        }
    }

    var mood: PetMood {
        switch self {
        case .firstTrust, .proudGlow, .celebrationShare, .gratefulKeepsake:
            return .happy
        case .braveStart, .playfulSprint, .overchargeGround, .restlessRedirect:
            return .hyper
        case .focusPerch, .growReady:
            return .perch
        case .nightGuardian, .sleepNest:
            return .nap
        case .gentleRepair, .lonelyComeback, .snackRescue:
            return .stretch
        case .curiousTrail:
            return .thinking
        }
    }

    var sparkReward: Int {
        switch self {
        case .firstTrust, .gentleRepair, .snackRescue, .sleepNest, .lonelyComeback:
            return 4
        case .braveStart, .focusPerch, .playfulSprint, .gratefulKeepsake, .curiousTrail:
            return 6
        case .proudGlow, .overchargeGround, .celebrationShare, .growReady, .restlessRedirect, .nightGuardian:
            return 8
        }
    }

    var assetSlug: String {
        switch self {
        case .firstTrust:
            return "first-trust"
        case .braveStart:
            return "brave-start"
        case .proudGlow:
            return "proud-glow"
        case .overchargeGround:
            return "overcharge-ground"
        case .focusPerch:
            return "focus-perch"
        case .celebrationShare:
            return "celebration-share"
        case .nightGuardian:
            return "night-guardian"
        case .gentleRepair:
            return "gentle-repair"
        case .playfulSprint:
            return "playful-sprint"
        case .gratefulKeepsake:
            return "grateful-keepsake"
        case .growReady:
            return "grow-ready"
        case .restlessRedirect:
            return "restless-redirect"
        case .snackRescue:
            return "snack-rescue"
        case .sleepNest:
            return "sleep-nest"
        case .curiousTrail:
            return "curious-trail"
        case .lonelyComeback:
            return "lonely-comeback"
        }
    }

    var spriteRequestNames: [String] {
        [
            "pet-{stage}-emotion-arc-\(assetSlug)-trigger.png",
            "pet-{stage}-emotion-arc-\(assetSlug)-care.png",
            "pet-{stage}-emotion-arc-\(assetSlug)-resolve.png"
        ]
    }

    var primarySpriteRequestName: String {
        spriteRequestNames[0]
    }

    static func arc(trigger: String, feeling: PetFeeling, episode: PetEmotionEpisode) -> PetEmotionArc {
        switch trigger {
        case "daily care", "happy", "affirmation":
            return .firstTrust
        case "quest open", "hint":
            return .braveStart
        case "upgrade", "journal", "life scene":
            return .proudGlow
        case "boost", "spent boost", "hyper":
            return .overchargeGround
        case "lesson open", "language reward", "care window":
            return .focusPerch
        case "daily event", "event review":
            return .celebrationShare
        case "nap":
            return .sleepNest
        case "server wait", "lesson retry":
            return .gentleRepair
        case "chat", "chat return", "user check":
            return .curiousTrail
        case "upgrade wait":
            return .restlessRedirect
        case "scout return":
            return .lonelyComeback
        default:
            switch episode {
            case .freshStart:
                return .firstTrust
            case .warmCare:
                return .gratefulKeepsake
            case .sleepyNest:
                return .sleepNest
            case .playfulBurst:
                return .playfulSprint
            case .overcharge:
                return .overchargeGround
            case .studyFocus:
                return .focusPerch
            case .gentleRepair:
                return .gentleRepair
            case .curiousClue:
                return .curiousTrail
            case .braveQuest:
                return .braveStart
            case .careContract:
                return .growReady
            case .proudUpgrade:
                return .proudGlow
            case .restlessCard:
                return .restlessRedirect
            case .celebrationEvent:
                return .celebrationShare
            case .guardianNight:
                return .nightGuardian
            case .snackyLow:
                return .snackRescue
            case .lonelyReturn:
                return .lonelyComeback
            }
        }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(dailyMask: Int, albumMask: Int, latest: PetEmotionArc) -> String {
        "Arcs \(count(mask: dailyMask))/\(allCases.count) today · Album \(count(mask: albumMask))/\(allCases.count): \(latest.title)"
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

enum PetSparkWheelCycle: Int, CaseIterable {
    case firstWind = 1
    case morningCharge = 2
    case focusSpin = 4
    case cheerLoop = 8
    case questCoil = 16
    case nightDrift = 32

    static func current(hour: Int, feeling: PetFeeling, careNeed: PetCareNeed, index: Int) -> PetSparkWheelCycle {
        switch feeling {
        case .focused, .determined:
            return .focusSpin
        case .proud, .celebrating, .grateful:
            return .cheerLoop
        case .curious, .eager:
            return .questCoil
        case .sleepy, .comfort:
            return .nightDrift
        default:
            break
        }

        switch careNeed {
        case .focus, .study:
            return .focusSpin
        case .adventure, .puzzle:
            return .questCoil
        case .rest:
            return .nightDrift
        case .affection:
            return .cheerLoop
        case .play:
            break
        }

        switch hour {
        case 5..<10:
            return .morningCharge
        case 10..<14:
            return .focusSpin
        case 14..<18:
            return index % 2 == 0 ? .questCoil : .cheerLoop
        case 18..<23:
            return .nightDrift
        default:
            return .firstWind
        }
    }

    var title: String {
        switch self {
        case .firstWind:
            return "First Wheel Wind"
        case .morningCharge:
            return "Morning Charge"
        case .focusSpin:
            return "Focus Spin"
        case .cheerLoop:
            return "Cheer Loop"
        case .questCoil:
            return "Quest Coil"
        case .nightDrift:
            return "Night Drift"
        }
    }

    var shortLabel: String {
        switch self {
        case .firstWind:
            return "Wind"
        case .morningCharge:
            return "AM"
        case .focusSpin:
            return "Focus"
        case .cheerLoop:
            return "Cheer"
        case .questCoil:
            return "Quest"
        case .nightDrift:
            return "Night"
        }
    }

    var action: String {
        switch self {
        case .firstWind:
            return "Wind wheel"
        case .morningCharge:
            return "Start charge"
        case .focusSpin:
            return "Start focus spin"
        case .cheerLoop:
            return "Start cheer loop"
        case .questCoil:
            return "Start quest coil"
        case .nightDrift:
            return "Start night drift"
        }
    }

    func startLine(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .firstWind:
            return "\(stage.shortLabel) winds the Spark Wheel for the first time and listens for the tiny hum."
        case .morningCharge:
            return "\(stage.shortLabel) spins a morning charge so the desk has a small return reward waiting."
        case .focusSpin:
            return "\(stage.shortLabel) starts a quiet focus spin while the cursor settles."
        case .cheerLoop:
            return "\(stage.shortLabel) loops the \(feeling.title.lowercased()) spark into a small morale charge."
        case .questCoil:
            return "\(stage.shortLabel) coils a quest spark and promises to bring back one useful glow."
        case .nightDrift:
            return "\(stage.shortLabel) lets the wheel drift softly so rest still earns a tiny return."
        }
    }

    func returnLine(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .firstWind:
            return "\(stage.shortLabel) returns with the first wheel pouch and looks proud of the sound."
        case .morningCharge:
            return "\(stage.shortLabel) brings back a morning Spark pouch before the day runs away."
        case .focusSpin:
            return "\(stage.shortLabel) returns from focus watch with a small steady glow."
        case .cheerLoop:
            return "\(stage.shortLabel) turns the \(feeling.title.lowercased()) loop into stored cheer."
        case .questCoil:
            return "\(stage.shortLabel) trots back from the quest coil with trail Sparks."
        case .nightDrift:
            return "\(stage.shortLabel) wakes from the soft wheel drift and keeps the return gentle."
        }
    }

    var rewardLine: String {
        switch self {
        case .firstWind:
            return "First wheel pouch ready"
        case .morningCharge:
            return "Morning wheel pouch ready"
        case .focusSpin:
            return "Focus wheel pouch ready"
        case .cheerLoop:
            return "Cheer wheel pouch ready"
        case .questCoil:
            return "Quest wheel pouch ready"
        case .nightDrift:
            return "Night wheel pouch ready"
        }
    }

    var vital: PetCareVital {
        switch self {
        case .firstWind, .morningCharge, .cheerLoop:
            return .play
        case .focusSpin, .questCoil:
            return .focus
        case .nightDrift:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .firstWind, .morningCharge, .cheerLoop:
            return .cheer
        case .focusSpin:
            return .focus
        case .questCoil:
            return .adventure
        case .nightDrift:
            return .rest
        }
    }

    var mood: PetMood {
        switch self {
        case .firstWind, .morningCharge, .cheerLoop:
            return .hyper
        case .focusSpin:
            return .perch
        case .questCoil:
            return .patrol
        case .nightDrift:
            return .nap
        }
    }

    var sparkReward: Int {
        switch self {
        case .firstWind:
            return 12
        case .morningCharge:
            return 14
        case .focusSpin, .cheerLoop:
            return 16
        case .questCoil:
            return 18
        case .nightDrift:
            return 15
        }
    }

    var spriteSlug: String {
        switch self {
        case .firstWind:
            return "first-wind"
        case .morningCharge:
            return "morning-charge"
        case .focusSpin:
            return "focus-spin"
        case .cheerLoop:
            return "cheer-loop"
        case .questCoil:
            return "quest-coil"
        case .nightDrift:
            return "night-drift"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-spark-wheel-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        hour: Int,
        feeling: PetFeeling,
        careNeed: PetCareNeed,
        offeredMask: Int,
        claimedMask: Int,
        index: Int
    ) -> PetSparkWheelCycle? {
        let unavailable = offeredMask | claimedMask
        let remaining = allCases.filter { unavailable & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }
        let preferred = current(hour: hour, feeling: feeling, careNeed: careNeed, index: index)
        if remaining.contains(preferred) {
            return preferred
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        offeredMask: Int,
        startedMask: Int,
        claimedMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        active: PetSparkWheelCycle?,
        remainingSeconds: Int?
    ) -> String {
        let offered = count(mask: offeredMask)
        let started = count(mask: startedMask)
        let claimed = count(mask: claimedMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let activeText: String
        if let active, let remainingSeconds {
            activeText = remainingSeconds > 0
                ? "\(active.shortLabel) \(remainingSeconds)s"
                : "\(active.shortLabel) ready"
        } else {
            activeText = "wheel idle"
        }
        return "Spark Wheel \(claimed)/\(allCases.count) claimed · \(started) spun · \(offered) offered · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(activeText)"
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

enum PetCheerPing: Int, CaseIterable {
    case wakeSpark = 1
    case firstStep = 2
    case waterSnack = 4
    case focusPerch = 8
    case tinyWin = 16
    case stretchReset = 32
    case eveningWrap = 64
    case nightNest = 128

    static func next(hour: Int, offeredMask: Int, answeredMask: Int, index: Int) -> PetCheerPing? {
        let eligible = allCases.filter {
            $0.isEligible(hour: hour)
                && offeredMask & $0.rawValue == 0
                && answeredMask & $0.rawValue == 0
        }
        guard !eligible.isEmpty else { return nil }
        return eligible[index % eligible.count]
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    var title: String {
        switch self {
        case .wakeSpark:
            return "Wake Spark"
        case .firstStep:
            return "First Step"
        case .waterSnack:
            return "Care Check"
        case .focusPerch:
            return "Focus Perch"
        case .tinyWin:
            return "Tiny Win"
        case .stretchReset:
            return "Stretch Reset"
        case .eveningWrap:
            return "Evening Wrap"
        case .nightNest:
            return "Night Nest"
        }
    }

    var shortLabel: String {
        switch self {
        case .wakeSpark:
            return "Wake"
        case .firstStep:
            return "Step"
        case .waterSnack:
            return "Care"
        case .focusPerch:
            return "Focus"
        case .tinyWin:
            return "Win"
        case .stretchReset:
            return "Reset"
        case .eveningWrap:
            return "Wrap"
        case .nightNest:
            return "Nest"
        }
    }

    var action: String {
        switch self {
        case .wakeSpark:
            return "Say Hi"
        case .firstStep:
            return "Name Step"
        case .waterSnack:
            return "Tiny Care"
        case .focusPerch:
            return "Start Focus"
        case .tinyWin:
            return "Save Win"
        case .stretchReset:
            return "Reset"
        case .eveningWrap:
            return "Wrap Loop"
        case .nightNest:
            return "Rest Watch"
        }
    }

    func body(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .wakeSpark:
            return "\(stage.shortLabel) looks down, looks up, then smiles at you. How are you arriving today?"
        case .firstStep:
            return "\(stage.shortLabel) taps the desk once. What is the smallest first step worth guarding?"
        case .waterSnack:
            return "\(stage.shortLabel) nudges a tiny care signal. Water, snack, or one softer breath?"
        case .focusPerch:
            return "\(stage.shortLabel) is ready to perch beside one useful minute. Want to start now?"
        case .tinyWin:
            return "\(stage.shortLabel) saw a \(feeling.title.lowercased()) spark. Want to save one tiny win before it vanishes?"
        case .stretchReset:
            return "\(stage.shortLabel) sees the day getting noisy. Want one reset before the next push?"
        case .eveningWrap:
            return "\(stage.shortLabel) circles back in evening mode. Want to close one loop cleanly?"
        case .nightNest:
            return "\(stage.shortLabel) curls near the corner. Can rest count as real care tonight?"
        }
    }

    var rewardLine: String {
        switch self {
        case .wakeSpark:
            return "Morning spark saved"
        case .firstStep:
            return "First step guarded"
        case .waterSnack:
            return "Care signal answered"
        case .focusPerch:
            return "Focus perch started"
        case .tinyWin:
            return "Tiny win pocketed"
        case .stretchReset:
            return "Reset loop softened"
        case .eveningWrap:
            return "Evening loop wrapped"
        case .nightNest:
            return "Rest watch started"
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .wakeSpark:
            return .checkIn
        case .firstStep, .focusPerch:
            return .focus
        case .waterSnack:
            return .care
        case .tinyWin:
            return .tinyWin
        case .stretchReset:
            return .reset
        case .eveningWrap:
            return .feeling
        case .nightNest:
            return .rest
        }
    }

    var vital: PetCareVital {
        switch self {
        case .wakeSpark, .tinyWin, .stretchReset:
            return .play
        case .firstStep, .focusPerch:
            return .focus
        case .waterSnack:
            return .snack
        case .eveningWrap, .nightNest:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .wakeSpark, .tinyWin:
            return .cheer
        case .firstStep, .focusPerch:
            return .focus
        case .waterSnack:
            return .snack
        case .stretchReset:
            return .play
        case .eveningWrap:
            return .soothe
        case .nightNest:
            return .rest
        }
    }

    var mood: PetMood {
        switch self {
        case .wakeSpark, .tinyWin:
            return .happy
        case .firstStep, .focusPerch:
            return .perch
        case .waterSnack:
            return .snack
        case .stretchReset:
            return .stretch
        case .eveningWrap:
            return .look
        case .nightNest:
            return .nap
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-cheer-ping-\(assetSlug).png"
    }

    private var assetSlug: String {
        switch self {
        case .wakeSpark:
            return "wake-spark"
        case .firstStep:
            return "first-step"
        case .waterSnack:
            return "water-snack"
        case .focusPerch:
            return "focus-perch"
        case .tinyWin:
            return "tiny-win"
        case .stretchReset:
            return "stretch-reset"
        case .eveningWrap:
            return "evening-wrap"
        case .nightNest:
            return "night-nest"
        }
    }

    private func isEligible(hour: Int) -> Bool {
        switch self {
        case .wakeSpark:
            return (5..<10).contains(hour)
        case .firstStep:
            return (7..<12).contains(hour)
        case .waterSnack:
            return (10..<16).contains(hour)
        case .focusPerch:
            return (9..<18).contains(hour)
        case .tinyWin:
            return (12..<20).contains(hour)
        case .stretchReset:
            return (14..<21).contains(hour)
        case .eveningWrap:
            return (17..<22).contains(hour)
        case .nightNest:
            return hour >= 21 || hour < 5
        }
    }
}

enum PetMoodWeather: Int, CaseIterable {
    case sunriseSpark = 1
    case focusCloud = 2
    case snackDrizzle = 4
    case playStorm = 8
    case quietNest = 16
    case proudSunbreak = 32
    case lonelyFog = 64
    case nightGlow = 128

    static func current(hour: Int, feeling: PetFeeling, lowestVital: PetCareVital) -> PetMoodWeather {
        if hour >= 21 || hour < 5 || feeling == .sleepy {
            return .nightGlow
        }
        switch lowestVital {
        case .snack where feeling == .hungry:
            return .snackDrizzle
        case .rest where feeling == .protective || feeling == .comfort:
            return .quietNest
        case .play where feeling == .overcharged || feeling == .restless || feeling == .playful:
            return .playStorm
        case .focus where feeling == .focused || feeling == .determined:
            return .focusCloud
        default:
            break
        }
        switch feeling {
        case .lonely, .comfort:
            return .lonelyFog
        case .proud, .celebrating, .grateful:
            return .proudSunbreak
        case .focused, .determined:
            return .focusCloud
        case .overcharged, .restless, .playful:
            return .playStorm
        case .hungry:
            return .snackDrizzle
        case .sleepy, .protective:
            return .quietNest
        case .bright, .eager, .curious:
            return hour < 12 ? .sunriseSpark : .focusCloud
        }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    var title: String {
        switch self {
        case .sunriseSpark:
            return "Sunrise Spark"
        case .focusCloud:
            return "Focus Cloud"
        case .snackDrizzle:
            return "Snack Drizzle"
        case .playStorm:
            return "Play Storm"
        case .quietNest:
            return "Quiet Nest"
        case .proudSunbreak:
            return "Proud Sunbreak"
        case .lonelyFog:
            return "Lonely Fog"
        case .nightGlow:
            return "Night Glow"
        }
    }

    var shortLabel: String {
        switch self {
        case .sunriseSpark:
            return "Sun"
        case .focusCloud:
            return "Focus"
        case .snackDrizzle:
            return "Snack"
        case .playStorm:
            return "Storm"
        case .quietNest:
            return "Nest"
        case .proudSunbreak:
            return "Proud"
        case .lonelyFog:
            return "Fog"
        case .nightGlow:
            return "Night"
        }
    }

    var action: String {
        switch self {
        case .sunriseSpark:
            return "Catch Spark"
        case .focusCloud:
            return "Clear Cloud"
        case .snackDrizzle:
            return "Warm Snack"
        case .playStorm:
            return "Ground Sparks"
        case .quietNest:
            return "Nest Care"
        case .proudSunbreak:
            return "Save Glow"
        case .lonelyFog:
            return "Reach Back"
        case .nightGlow:
            return "Guard Rest"
        }
    }

    func body(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .sunriseSpark:
            return "\(stage.shortLabel) has sunrise sparks around its ears. It wants to catch the first tiny bright move."
        case .focusCloud:
            return "\(stage.shortLabel) is under a focus cloud. It can sit quietly beside one useful minute."
        case .snackDrizzle:
            return "\(stage.shortLabel) has snack drizzle cheeks. A small refill would make the weather warmer."
        case .playStorm:
            return "\(stage.shortLabel) has a play storm building. It needs one safe spark burst before it scatters."
        case .quietNest:
            return "\(stage.shortLabel) is making quiet nest weather. Rest can count as care right now."
        case .proudSunbreak:
            return "\(stage.shortLabel) has a proud sunbreak. Want to save this little win in the weather log?"
        case .lonelyFog:
            return "\(stage.shortLabel) is in a lonely fog. One gentle tap would help it find you again."
        case .nightGlow:
            return "\(stage.shortLabel) has a night glow and wants to guard the room instead of asking for more."
        }
    }

    var rewardLine: String {
        switch self {
        case .sunriseSpark:
            return "First spark caught"
        case .focusCloud:
            return "Focus cloud cleared"
        case .snackDrizzle:
            return "Snack weather warmed"
        case .playStorm:
            return "Play storm grounded"
        case .quietNest:
            return "Nest weather settled"
        case .proudSunbreak:
            return "Proud glow saved"
        case .lonelyFog:
            return "Lonely fog softened"
        case .nightGlow:
            return "Night glow guarded"
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .sunriseSpark, .proudSunbreak:
            return .tinyWin
        case .focusCloud:
            return .focus
        case .snackDrizzle, .quietNest:
            return .care
        case .playStorm:
            return .reset
        case .lonelyFog:
            return .feeling
        case .nightGlow:
            return .rest
        }
    }

    var vital: PetCareVital {
        switch self {
        case .snackDrizzle:
            return .snack
        case .quietNest, .nightGlow:
            return .rest
        case .playStorm, .sunriseSpark, .proudSunbreak, .lonelyFog:
            return .play
        case .focusCloud:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .sunriseSpark, .proudSunbreak:
            return .cheer
        case .focusCloud:
            return .focus
        case .snackDrizzle:
            return .snack
        case .playStorm:
            return .play
        case .quietNest, .nightGlow:
            return .rest
        case .lonelyFog:
            return .soothe
        }
    }

    var mood: PetMood {
        switch self {
        case .sunriseSpark, .proudSunbreak:
            return .happy
        case .focusCloud:
            return .perch
        case .snackDrizzle:
            return .snack
        case .playStorm:
            return .hyper
        case .quietNest, .nightGlow:
            return .nap
        case .lonelyFog:
            return .look
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-mood-weather-\(assetSlug).png"
    }

    private var assetSlug: String {
        switch self {
        case .sunriseSpark:
            return "sunrise-spark"
        case .focusCloud:
            return "focus-cloud"
        case .snackDrizzle:
            return "snack-drizzle"
        case .playStorm:
            return "play-storm"
        case .quietNest:
            return "quiet-nest"
        case .proudSunbreak:
            return "proud-sunbreak"
        case .lonelyFog:
            return "lonely-fog"
        case .nightGlow:
            return "night-glow"
        }
    }
}

enum PetExchangeBoardStep: Int, CaseIterable {
    case careTap = 1
    case comboCards = 2
    case taskBoard = 4
    case cipherKey = 8
    case sparkBoost = 16
    case upgradeCard = 32
    case passiveScout = 64
    case cheerReply = 128

    var title: String {
        switch self {
        case .careTap:
            return "Care Tap"
        case .comboCards:
            return "Daily Combo"
        case .taskBoard:
            return "Task Board"
        case .cipherKey:
            return "Cipher Key"
        case .sparkBoost:
            return "Spark Boost"
        case .upgradeCard:
            return "Upgrade Card"
        case .passiveScout:
            return "Passive Scout"
        case .cheerReply:
            return "Cheer Reply"
        }
    }

    var shortLabel: String {
        switch self {
        case .careTap:
            return "Care"
        case .comboCards:
            return "Combo"
        case .taskBoard:
            return "Board"
        case .cipherKey:
            return "Cipher"
        case .sparkBoost:
            return "Boost"
        case .upgradeCard:
            return "Card"
        case .passiveScout:
            return "Scout"
        case .cheerReply:
            return "Cheer"
        }
    }

    var body: String {
        switch self {
        case .careTap:
            return "Start the exchange with one tiny care tap. It turns attention into Bond HP."
        case .comboCards:
            return "Three combo cards are waiting. Clear them to make today's Sparks feel earned."
        case .taskBoard:
            return "The board has a few small jobs. Pick one and let it become progress."
        case .cipherKey:
            return "A tiny cipher is glowing. Solve it before the day resets."
        case .sparkBoost:
            return "Today's boost is charged. Claim it when you want a visible burst."
        case .upgradeCard:
            return "One card wants polish. Upgrades make the pet's loop stronger tomorrow."
        case .passiveScout:
            return "Send the pet into quiet scout mode so it can bring back passive Sparks."
        case .cheerReply:
            return "Answer one check-in. The pet remembers that you came back."
        }
    }

    var action: String {
        switch self {
        case .careTap:
            return "Pet Once"
        case .comboCards:
            return "Open Combo"
        case .taskBoard:
            return "Open Board"
        case .cipherKey:
            return "Solve Cipher"
        case .sparkBoost:
            return "Claim Boost"
        case .upgradeCard:
            return "Polish Card"
        case .passiveScout:
            return "Send Scout"
        case .cheerReply:
            return "Reply"
        }
    }

    var rewardLine: String {
        switch self {
        case .careTap:
            return "care tap started the daily exchange"
        case .comboCards:
            return "combo cards are now part of today's path"
        case .taskBoard:
            return "task board step is visible"
        case .cipherKey:
            return "cipher key is ready"
        case .sparkBoost:
            return "spark boost is charged"
        case .upgradeCard:
            return "upgrade card route is visible"
        case .passiveScout:
            return "passive scout route is open"
        case .cheerReply:
            return "cheer reply keeps the bond alive"
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .careTap, .cheerReply:
            return .care
        case .comboCards, .taskBoard:
            return .board
        case .cipherKey:
            return .puzzle
        case .sparkBoost, .passiveScout:
            return .boost
        case .upgradeCard:
            return .upgrade
        }
    }

    var mood: PetMood {
        switch self {
        case .careTap, .cheerReply:
            return .happy
        case .comboCards, .taskBoard, .upgradeCard:
            return .hyper
        case .cipherKey:
            return .thinking
        case .sparkBoost:
            return .spark
        case .passiveScout:
            return .patrol
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-exchange-\(assetSlug).png"
    }

    private var assetSlug: String {
        switch self {
        case .careTap:
            return "care-tap"
        case .comboCards:
            return "combo-cards"
        case .taskBoard:
            return "task-board"
        case .cipherKey:
            return "cipher-key"
        case .sparkBoost:
            return "spark-boost"
        case .upgradeCard:
            return "upgrade-card"
        case .passiveScout:
            return "passive-scout"
        case .cheerReply:
            return "cheer-reply"
        }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(
        doneMask: Int,
        offeredMask: Int,
        answeredMask: Int,
        dismissedMask: Int,
        next: PetExchangeBoardStep?
    ) -> String {
        let done = count(mask: doneMask)
        let offered = count(mask: offeredMask)
        let answered = count(mask: answeredMask)
        let dismissed = count(mask: dismissedMask)
        return "Spark Exchange \(done)/\(allCases.count) · nudges \(answered)/\(offered) answered, \(dismissed) skipped · next \(next?.title ?? "board clear")"
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

enum PetDailyRouteStep: Int, CaseIterable {
    case wakeSpark = 1
    case careTap = 2
    case snackStash = 4
    case focusPerch = 8
    case lessonSpark = 16
    case questTrail = 32
    case cipherPulse = 64
    case upgradePolish = 128
    case cheerCall = 256
    case boostRush = 512
    case ambientPatrol = 1024
    case bedtimeNest = 2048

    static func dailyRoute(for dateKey: String) -> [PetDailyRouteStep] {
        let seed = dateKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let routes: [[PetDailyRouteStep]] = [
            [.wakeSpark, .careTap, .focusPerch, .lessonSpark, .cheerCall, .bedtimeNest],
            [.wakeSpark, .snackStash, .questTrail, .cipherPulse, .boostRush, .ambientPatrol],
            [.careTap, .lessonSpark, .upgradePolish, .focusPerch, .questTrail, .bedtimeNest],
            [.wakeSpark, .cheerCall, .snackStash, .cipherPulse, .ambientPatrol, .boostRush],
            [.careTap, .focusPerch, .questTrail, .upgradePolish, .cheerCall, .bedtimeNest],
            [.wakeSpark, .lessonSpark, .cipherPulse, .boostRush, .ambientPatrol, .snackStash]
        ]
        return routes[seed % routes.count]
    }

    var title: String {
        switch self {
        case .wakeSpark:
            return "Wake Spark"
        case .careTap:
            return "Care Tap"
        case .snackStash:
            return "Snack Stash"
        case .focusPerch:
            return "Focus Perch"
        case .lessonSpark:
            return "Lesson Spark"
        case .questTrail:
            return "Quest Trail"
        case .cipherPulse:
            return "Cipher Pulse"
        case .upgradePolish:
            return "Upgrade Polish"
        case .cheerCall:
            return "Cheer Call"
        case .boostRush:
            return "Boost Rush"
        case .ambientPatrol:
            return "Ambient Patrol"
        case .bedtimeNest:
            return "Bedtime Nest"
        }
    }

    var shortLabel: String {
        switch self {
        case .wakeSpark:
            return "Wake"
        case .careTap:
            return "Care"
        case .snackStash:
            return "Snack"
        case .focusPerch:
            return "Focus"
        case .lessonSpark:
            return "Lesson"
        case .questTrail:
            return "Quest"
        case .cipherPulse:
            return "Cipher"
        case .upgradePolish:
            return "Polish"
        case .cheerCall:
            return "Cheer"
        case .boostRush:
            return "Boost"
        case .ambientPatrol:
            return "Patrol"
        case .bedtimeNest:
            return "Nest"
        }
    }

    var actionLine: String {
        switch self {
        case .wakeSpark:
            return "wake the pet and let it find you"
        case .careTap:
            return "give one visible care tap"
        case .snackStash:
            return "check the tiny snack stash"
        case .focusPerch:
            return "let it perch beside one task"
        case .lessonSpark:
            return "practice one phrase together"
        case .questTrail:
            return "open the next adventure trail"
        case .cipherPulse:
            return "solve one tiny daily secret"
        case .upgradePolish:
            return "polish one kit card"
        case .cheerCall:
            return "answer or save one check-in"
        case .boostRush:
            return "claim the daily spark rush"
        case .ambientPatrol:
            return "watch it do one desk patrol"
        case .bedtimeNest:
            return "close with a quiet nest moment"
        }
    }

    var rewardLine: String {
        switch self {
        case .wakeSpark:
            return "The first look becomes today's anchor."
        case .careTap:
            return "Affection turns into a clean bond receipt."
        case .snackStash:
            return "A full stash keeps the pet from feeling ignored."
        case .focusPerch:
            return "The desk becomes safer for one small task."
        case .lessonSpark:
            return "A phrase becomes part of the shared routine."
        case .questTrail:
            return "The map gains one bright breadcrumb."
        case .cipherPulse:
            return "A secret word gets tucked into the journal."
        case .upgradePolish:
            return "The kit feels maintained, not merely purchased."
        case .cheerCall:
            return "The check-in becomes relationship memory."
        case .boostRush:
            return "The day gets a controlled energy burst."
        case .ambientPatrol:
            return "The idle animation earns story value."
        case .bedtimeNest:
            return "The pet learns that closing gently counts."
        }
    }

    var sparkReward: Int {
        switch self {
        case .wakeSpark, .careTap, .snackStash, .bedtimeNest:
            return 6
        case .focusPerch, .lessonSpark, .cheerCall, .ambientPatrol:
            return 8
        case .questTrail, .cipherPulse, .upgradePolish, .boostRush:
            return 10
        }
    }

    var vital: PetCareVital {
        switch self {
        case .wakeSpark, .careTap, .snackStash:
            return .snack
        case .bedtimeNest:
            return .rest
        case .questTrail, .cheerCall, .boostRush, .ambientPatrol:
            return .play
        case .focusPerch, .lessonSpark, .cipherPulse, .upgradePolish:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .wakeSpark, .careTap:
            return .soothe
        case .snackStash:
            return .snack
        case .focusPerch, .upgradePolish:
            return .focus
        case .lessonSpark:
            return .study
        case .questTrail, .ambientPatrol:
            return .adventure
        case .cipherPulse:
            return .puzzle
        case .cheerCall:
            return .cheer
        case .boostRush:
            return .play
        case .bedtimeNest:
            return .rest
        }
    }

    var mood: PetMood {
        switch self {
        case .wakeSpark:
            return .look
        case .careTap, .snackStash, .lessonSpark, .cheerCall:
            return .happy
        case .focusPerch, .upgradePolish:
            return .perch
        case .questTrail, .ambientPatrol:
            return .patrol
        case .cipherPulse:
            return .thinking
        case .boostRush:
            return .hyper
        case .bedtimeNest:
            return .nap
        }
    }

    var comboAction: PetComboAction? {
        switch self {
        case .wakeSpark, .careTap, .snackStash, .bedtimeNest:
            return .pet
        case .focusPerch, .cheerCall:
            return nil
        case .lessonSpark:
            return .learn
        case .questTrail:
            return .open
        case .cipherPulse:
            return .cipher
        case .upgradePolish:
            return .upgrade
        case .boostRush:
            return .boost
        case .ambientPatrol:
            return .hyper
        }
    }

    var cheerIntent: PetCheerIntent {
        switch self {
        case .wakeSpark, .careTap, .snackStash, .bedtimeNest:
            return .care
        case .focusPerch, .cheerCall:
            return .checkIn
        case .lessonSpark:
            return .lesson
        case .questTrail, .ambientPatrol:
            return .quest
        case .cipherPulse:
            return .puzzle
        case .upgradePolish:
            return .upgrade
        case .boostRush:
            return .boost
        }
    }

    var dailyQuest: PetDailyQuest {
        switch self {
        case .wakeSpark, .careTap, .snackStash, .bedtimeNest:
            return .care
        case .focusPerch, .cheerCall:
            return .cheer
        case .lessonSpark:
            return .learn
        case .questTrail, .ambientPatrol:
            return .adventure
        case .cipherPulse:
            return .cipher
        case .upgradePolish:
            return .upgrade
        case .boostRush:
            return .boost
        }
    }

    var spriteRequestName: String {
        switch self {
        case .wakeSpark:
            return "pet-{stage}-route-wake-spark.png"
        case .careTap:
            return "pet-{stage}-route-care-tap.png"
        case .snackStash:
            return "pet-{stage}-route-snack-stash.png"
        case .focusPerch:
            return "pet-{stage}-route-focus-perch.png"
        case .lessonSpark:
            return "pet-{stage}-route-lesson-spark.png"
        case .questTrail:
            return "pet-{stage}-route-quest-trail.png"
        case .cipherPulse:
            return "pet-{stage}-route-cipher-pulse.png"
        case .upgradePolish:
            return "pet-{stage}-route-upgrade-polish.png"
        case .cheerCall:
            return "pet-{stage}-route-cheer-call.png"
        case .boostRush:
            return "pet-{stage}-route-boost-rush.png"
        case .ambientPatrol:
            return "pet-{stage}-route-ambient-patrol.png"
        case .bedtimeNest:
            return "pet-{stage}-route-bedtime-nest.png"
        }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(
        dailyMask: Int,
        offeredMask: Int = 0,
        dismissedMask: Int = 0,
        albumMask: Int,
        route: [PetDailyRouteStep],
        latest: PetDailyRouteStep?
    ) -> String {
        let done = route.filter { dailyMask & $0.rawValue != 0 }.count
        let offered = route.filter { offeredMask & $0.rawValue != 0 }.count
        let dismissed = route.filter { dismissedMask & $0.rawValue != 0 }.count
        let album = count(mask: albumMask)
        let next = route.first { dailyMask & $0.rawValue == 0 }
        let nextText = next.map { "Next \($0.title)" } ?? "Route complete"
        let latestText = latest.map { "Latest \($0.title)" } ?? "fresh route"
        return "Spark Route \(done)/\(route.count) today · \(offered) offered · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(nextText) · \(latestText)"
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

enum PetCareMoment: Int, CaseIterable {
    case sunrise = 1
    case focus = 2
    case afternoon = 4
    case evening = 8
    case night = 16

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

    var shortLabel: String {
        switch self {
        case .sunrise:
            return "Rise"
        case .focus:
            return "Focus"
        case .afternoon:
            return "Reset"
        case .evening:
            return "Loop"
        case .night:
            return "Nest"
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

    var actionLine: String {
        switch self {
        case .sunrise:
            return "look down, look up, and greet the user"
        case .focus:
            return "perch beside one clean task"
        case .afternoon:
            return "shake off the wobble and refill a little spark"
        case .evening:
            return "close one open loop before the day softens"
        case .night:
            return "curl into the quiet nest and guard the streak"
        }
    }

    var rewardLine: String {
        switch self {
        case .sunrise:
            return "The day starts with a remembered hello."
        case .focus:
            return "The desk gets one protected focus perch."
        case .afternoon:
            return "The low-energy wobble becomes a reset."
        case .evening:
            return "One unfinished loop gets a campfire marker."
        case .night:
            return "Rest counts as care, not absence."
        }
    }

    var dailyQuest: PetDailyQuest {
        switch self {
        case .sunrise, .night:
            return .care
        case .focus:
            return .cheer
        case .afternoon:
            return .boost
        case .evening:
            return .adventure
        }
    }

    var vital: PetCareVital {
        switch self {
        case .sunrise, .afternoon:
            return .snack
        case .focus:
            return .focus
        case .evening:
            return .play
        case .night:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .sunrise:
            return .soothe
        case .focus:
            return .focus
        case .afternoon:
            return .snack
        case .evening:
            return .adventure
        case .night:
            return .rest
        }
    }

    var mood: PetMood {
        switch self {
        case .sunrise:
            return .look
        case .focus:
            return .perch
        case .afternoon:
            return .stretch
        case .evening:
            return .happy
        case .night:
            return .nap
        }
    }

    var spriteSlug: String {
        switch self {
        case .sunrise:
            return "sunrise-greeting"
        case .focus:
            return "focus-perch"
        case .afternoon:
            return "afternoon-reset"
        case .evening:
            return "evening-loop"
        case .night:
            return "night-nest"
        }
    }

    func spriteRequestName(stage: PetGrowthStage) -> String {
        "pet-\(stage.assetSlug)-care-window-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(dailyMask: Int, albumMask: Int, current: PetCareMoment) -> String {
        let done = count(mask: dailyMask)
        let albumDone = count(mask: albumMask)
        let currentStatus = dailyMask & current.rawValue == 0 ? "ready" : "done"
        return "Care Windows \(done)/\(allCases.count) today · \(current.title) \(currentStatus) · Album \(albumDone)/\(allCases.count)"
    }
}

enum PetCareChest: Int, CaseIterable {
    case morningSpark = 1
    case focusCrate = 2
    case snackCache = 4
    case playBox = 8
    case eveningCoffer = 16
    case nightNest = 32
    case comebackCache = 64

    var title: String {
        switch self {
        case .morningSpark:
            return "Morning Spark Chest"
        case .focusCrate:
            return "Focus Crate"
        case .snackCache:
            return "Snack Cache"
        case .playBox:
            return "Play Box"
        case .eveningCoffer:
            return "Evening Coffer"
        case .nightNest:
            return "Night Nest Chest"
        case .comebackCache:
            return "Comeback Cache"
        }
    }

    var shortLabel: String {
        switch self {
        case .morningSpark:
            return "Morning"
        case .focusCrate:
            return "Focus"
        case .snackCache:
            return "Snack"
        case .playBox:
            return "Play"
        case .eveningCoffer:
            return "Evening"
        case .nightNest:
            return "Night"
        case .comebackCache:
            return "Return"
        }
    }

    var action: String {
        switch self {
        case .morningSpark:
            return "Open Morning"
        case .focusCrate:
            return "Open Focus"
        case .snackCache:
            return "Open Snack"
        case .playBox:
            return "Open Play"
        case .eveningCoffer:
            return "Open Evening"
        case .nightNest:
            return "Open Night"
        case .comebackCache:
            return "Open Return"
        }
    }

    func body(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .morningSpark:
            return "\(stage.shortLabel) found a morning spark chest. Want to open it before the day scatters?"
        case .focusCrate:
            return "\(stage.shortLabel) pushed a focus crate beside the desk. Want one clean-task reward?"
        case .snackCache:
            return "\(stage.shortLabel) is guarding a snack cache. \(feeling.title) energy needs a refill."
        case .playBox:
            return "\(stage.shortLabel) brought the play box. Want to burn off one happy burst?"
        case .eveningCoffer:
            return "The evening coffer is warm. Want to close one loop and save the glow?"
        case .nightNest:
            return "\(stage.shortLabel) tucked a night chest into the nest. Want rest to count as care?"
        case .comebackCache:
            return "\(stage.shortLabel) saved a comeback cache while you were away. Want to collect it gently?"
        }
    }

    var rewardLine: String {
        switch self {
        case .morningSpark:
            return "Morning spark claimed"
        case .focusCrate:
            return "Focus crate opened"
        case .snackCache:
            return "Snack cache shared"
        case .playBox:
            return "Play box opened"
        case .eveningCoffer:
            return "Evening coffer closed"
        case .nightNest:
            return "Night nest chest saved"
        case .comebackCache:
            return "Comeback cache collected"
        }
    }

    var sparkReward: Int {
        switch self {
        case .morningSpark, .snackCache, .nightNest:
            return 8
        case .focusCrate, .playBox:
            return 10
        case .eveningCoffer:
            return 12
        case .comebackCache:
            return 14
        }
    }

    var joyReward: Int {
        switch self {
        case .comebackCache, .nightNest:
            return 2
        default:
            return 1
        }
    }

    var vital: PetCareVital {
        switch self {
        case .morningSpark, .snackCache:
            return .snack
        case .focusCrate:
            return .focus
        case .playBox, .eveningCoffer:
            return .play
        case .nightNest, .comebackCache:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .morningSpark:
            return .soothe
        case .focusCrate:
            return .focus
        case .snackCache:
            return .snack
        case .playBox:
            return .play
        case .eveningCoffer:
            return .adventure
        case .nightNest, .comebackCache:
            return .rest
        }
    }

    var dailyQuest: PetDailyQuest {
        switch self {
        case .morningSpark, .snackCache, .nightNest, .comebackCache:
            return .care
        case .focusCrate:
            return .cheer
        case .playBox, .eveningCoffer:
            return .adventure
        }
    }

    var mood: PetMood {
        switch self {
        case .morningSpark:
            return .look
        case .focusCrate:
            return .perch
        case .snackCache:
            return .snack
        case .playBox:
            return .hyper
        case .eveningCoffer:
            return .happy
        case .nightNest:
            return .nap
        case .comebackCache:
            return .stretch
        }
    }

    var spriteSlug: String {
        switch self {
        case .morningSpark:
            return "morning-spark"
        case .focusCrate:
            return "focus-crate"
        case .snackCache:
            return "snack-cache"
        case .playBox:
            return "play-box"
        case .eveningCoffer:
            return "evening-coffer"
        case .nightNest:
            return "night-nest"
        case .comebackCache:
            return "comeback-cache"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-care-chest-\(spriteSlug).png"
    }

    static func eligible(
        hour: Int,
        careMoment: PetCareMoment,
        lowestVital: PetCareVital,
        comebackReady: Bool,
        energy: Int
    ) -> [PetCareChest] {
        var chests: [PetCareChest] = []
        if comebackReady {
            chests.append(.comebackCache)
        }
        switch careMoment {
        case .sunrise:
            chests.append(.morningSpark)
        case .focus:
            chests.append(.focusCrate)
        case .afternoon:
            chests.append(lowestVital == .play || energy <= 1 ? .playBox : .snackCache)
        case .evening:
            chests.append(.eveningCoffer)
        case .night:
            chests.append(.nightNest)
        }
        if lowestVital == .snack && !chests.contains(.snackCache) {
            chests.append(.snackCache)
        }
        if lowestVital == .focus && hour >= 9 && hour < 18 && !chests.contains(.focusCrate) {
            chests.append(.focusCrate)
        }
        if lowestVital == .play && hour >= 12 && hour < 22 && !chests.contains(.playBox) {
            chests.append(.playBox)
        }
        if lowestVital == .rest && !chests.contains(.nightNest) {
            chests.append(.nightNest)
        }
        return chests
    }

    static func nextReady(
        claimedMask: Int,
        offeredMask: Int,
        hour: Int,
        careMoment: PetCareMoment,
        lowestVital: PetCareVital,
        comebackReady: Bool,
        energy: Int,
        index: Int,
        preferUnseen: Bool
    ) -> PetCareChest? {
        let candidates = eligible(
            hour: hour,
            careMoment: careMoment,
            lowestVital: lowestVital,
            comebackReady: comebackReady,
            energy: energy
        )
        if preferUnseen,
           let unseen = candidates.first(where: { claimedMask & $0.rawValue == 0 && offeredMask & $0.rawValue == 0 }) {
            return unseen
        }
        let unclaimed = candidates.filter { claimedMask & $0.rawValue == 0 }
        if !unclaimed.isEmpty {
            return unclaimed[index % unclaimed.count]
        }
        let remaining = allCases.filter { claimedMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }
        return remaining[index % remaining.count]
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(offeredMask: Int, claimedMask: Int, dismissedMask: Int, albumMask: Int, next: PetCareChest?) -> String {
        let claimed = count(mask: claimedMask)
        let offered = count(mask: offeredMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let nextText = next.map { "Next \($0.shortLabel)" } ?? "all clear"
        return "Care Chests \(claimed)/\(allCases.count) claimed · \(offered) seen · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(nextText)"
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

enum PetDailyNudgeJourneyPhase: Int, CaseIterable {
    case wakeSpark = 1
    case firstStep = 2
    case focusPerch = 4
    case snackPulse = 8
    case afternoonRescue = 16
    case proofPocket = 32
    case eveningPack = 64
    case nightNest = 128

    static func current(hour: Int) -> PetDailyNudgeJourneyPhase {
        switch hour {
        case 5..<9:
            return .wakeSpark
        case 9..<11:
            return .firstStep
        case 11..<13:
            return .focusPerch
        case 13..<15:
            return .snackPulse
        case 15..<17:
            return .afternoonRescue
        case 17..<19:
            return .proofPocket
        case 19..<22:
            return .eveningPack
        default:
            return .nightNest
        }
    }

    var title: String {
        switch self {
        case .wakeSpark:
            return "Wake Spark"
        case .firstStep:
            return "First Step"
        case .focusPerch:
            return "Focus Perch"
        case .snackPulse:
            return "Snack Pulse"
        case .afternoonRescue:
            return "Afternoon Rescue"
        case .proofPocket:
            return "Proof Pocket"
        case .eveningPack:
            return "Evening Pack"
        case .nightNest:
            return "Night Nest"
        }
    }

    var shortLabel: String {
        switch self {
        case .wakeSpark:
            return "Wake"
        case .firstStep:
            return "Step"
        case .focusPerch:
            return "Focus"
        case .snackPulse:
            return "Snack"
        case .afternoonRescue:
            return "Rescue"
        case .proofPocket:
            return "Proof"
        case .eveningPack:
            return "Pack"
        case .nightNest:
            return "Nest"
        }
    }

    var body: String {
        switch self {
        case .wakeSpark:
            return "Good morning. How are you arriving today: bright, foggy, or already sparking?"
        case .firstStep:
            return "What is the first tiny door we open? I can hold the rest closed."
        case .focusPerch:
            return "I can perch quietly with one task. What is happening on your desk?"
        case .snackPulse:
            return "Care check. Water, snack, stretch, or one softer edge?"
        case .afternoonRescue:
            return "Afternoon got noisy. Want me to rescue one useful next step?"
        case .proofPocket:
            return "Before the day slides away, what proof should I pocket for you?"
        case .eveningPack:
            return "Want to pack one loose thought so tomorrow starts lighter?"
        case .nightNest:
            return "Night mode. Want me to guard the quiet while you stop?"
        }
    }

    var action: String {
        switch self {
        case .wakeSpark:
            return "Check mood"
        case .firstStep:
            return "Name first step"
        case .focusPerch:
            return "Start focus"
        case .snackPulse:
            return "Take care"
        case .afternoonRescue:
            return "Rescue next step"
        case .proofPocket:
            return "Save proof"
        case .eveningPack:
            return "Pack thought"
        case .nightNest:
            return "Guard rest"
        }
    }

    var rewardLine: String {
        switch self {
        case .wakeSpark:
            return "Wake Spark check-in answered"
        case .firstStep:
            return "First Step opened"
        case .focusPerch:
            return "Focus Perch started"
        case .snackPulse:
            return "Snack Pulse cared for"
        case .afternoonRescue:
            return "Afternoon Rescue complete"
        case .proofPocket:
            return "Proof Pocket saved"
        case .eveningPack:
            return "Evening Pack closed"
        case .nightNest:
            return "Night Nest guarded"
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .wakeSpark:
            return .feeling
        case .firstStep, .afternoonRescue:
            return .tinyWin
        case .focusPerch:
            return .focus
        case .snackPulse:
            return .reset
        case .proofPocket, .eveningPack:
            return .fieldNote
        case .nightNest:
            return .rest
        }
    }

    var vital: PetCareVital {
        switch self {
        case .wakeSpark, .snackPulse:
            return .snack
        case .nightNest, .eveningPack:
            return .rest
        case .firstStep, .afternoonRescue:
            return .play
        case .focusPerch, .proofPocket:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .wakeSpark:
            return .soothe
        case .firstStep, .afternoonRescue:
            return .adventure
        case .focusPerch:
            return .focus
        case .snackPulse:
            return .snack
        case .proofPocket, .eveningPack:
            return .cheer
        case .nightNest:
            return .rest
        }
    }

    var mood: PetMood {
        switch self {
        case .wakeSpark, .proofPocket:
            return .look
        case .firstStep, .afternoonRescue:
            return .hyper
        case .focusPerch, .eveningPack:
            return .perch
        case .snackPulse:
            return .snack
        case .nightNest:
            return .nap
        }
    }

    var sparkReward: Int {
        switch self {
        case .wakeSpark, .snackPulse, .nightNest:
            return 5
        case .firstStep, .focusPerch, .afternoonRescue, .proofPocket:
            return 7
        case .eveningPack:
            return 8
        }
    }

    var assetSlug: String {
        switch self {
        case .wakeSpark:
            return "wake-spark"
        case .firstStep:
            return "first-step"
        case .focusPerch:
            return "focus-perch"
        case .snackPulse:
            return "snack-pulse"
        case .afternoonRescue:
            return "afternoon-rescue"
        case .proofPocket:
            return "proof-pocket"
        case .eveningPack:
            return "evening-pack"
        case .nightNest:
            return "night-nest"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-daily-journey-\(assetSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(offeredMask: Int, answeredMask: Int, dismissedMask: Int, albumMask: Int, current: PetDailyNudgeJourneyPhase) -> String {
        let answered = count(mask: answeredMask)
        let offered = count(mask: offeredMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let currentStatus = answeredMask & current.rawValue == 0 ? "ready" : "done"
        return "Daily Journey \(answered)/\(allCases.count) answered · \(offered) seen · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(current.shortLabel) \(currentStatus)"
    }
}

enum PetVisitBeat: Int, CaseIterable {
    case morningPeek = 1
    case firstTask = 2
    case focusSit = 4
    case snackNudge = 8
    case windowWave = 16
    case pressureGuard = 32
    case winPocket = 64
    case eveningReturn = 128
    case nightCurl = 256
    case comebackGlow = 512

    static func current(hour: Int, feeling: PetFeeling, careNeed: PetCareNeed, index: Int) -> PetVisitBeat {
        switch feeling {
        case .lonely, .comfort:
            return .windowWave
        case .proud, .celebrating, .grateful:
            return .winPocket
        case .focused, .determined:
            return .focusSit
        case .hungry:
            return .snackNudge
        case .sleepy:
            return hour >= 20 || hour < 6 ? .nightCurl : .pressureGuard
        case .overcharged, .restless, .protective:
            return .pressureGuard
        default:
            break
        }

        switch careNeed {
        case .rest where hour >= 18 || hour < 7:
            return .nightCurl
        case .focus, .study:
            return .focusSit
        case .affection:
            return .windowWave
        case .play where index % 4 == 0:
            return .winPocket
        default:
            break
        }

        switch hour {
        case 5..<8:
            return .morningPeek
        case 8..<11:
            return .firstTask
        case 11..<14:
            return .focusSit
        case 14..<16:
            return .snackNudge
        case 16..<18:
            return .pressureGuard
        case 18..<21:
            return .eveningReturn
        case 21..<24, 0..<5:
            return .nightCurl
        default:
            return .comebackGlow
        }
    }

    var title: String {
        switch self {
        case .morningPeek:
            return "Morning Peek"
        case .firstTask:
            return "First Task Tap"
        case .focusSit:
            return "Focus Sit"
        case .snackNudge:
            return "Snack Nudge"
        case .windowWave:
            return "Window Wave"
        case .pressureGuard:
            return "Pressure Guard"
        case .winPocket:
            return "Win Pocket"
        case .eveningReturn:
            return "Evening Return"
        case .nightCurl:
            return "Night Curl"
        case .comebackGlow:
            return "Comeback Glow"
        }
    }

    var shortLabel: String {
        switch self {
        case .morningPeek:
            return "Peek"
        case .firstTask:
            return "Task"
        case .focusSit:
            return "Focus"
        case .snackNudge:
            return "Snack"
        case .windowWave:
            return "Wave"
        case .pressureGuard:
            return "Guard"
        case .winPocket:
            return "Win"
        case .eveningReturn:
            return "Return"
        case .nightCurl:
            return "Curl"
        case .comebackGlow:
            return "Glow"
        }
    }

    var action: String {
        switch self {
        case .morningPeek:
            return "Say good morning"
        case .firstTask:
            return "Name first task"
        case .focusSit:
            return "Sit with focus"
        case .snackNudge:
            return "Take care"
        case .windowWave:
            return "Wave back"
        case .pressureGuard:
            return "Lower pressure"
        case .winPocket:
            return "Save win"
        case .eveningReturn:
            return "Close loop"
        case .nightCurl:
            return "Guard rest"
        case .comebackGlow:
            return "Welcome back"
        }
    }

    func body(stage: PetGrowthStage, feeling: PetFeeling, careNeed: PetCareNeed) -> String {
        switch self {
        case .morningPeek:
            return "\(stage.shortLabel) peeks up from the desktop. How are you arriving today: clear, foggy, or sparking?"
        case .firstTask:
            return "\(stage.shortLabel) taps the desk once. What is the first tiny task worth opening?"
        case .focusSit:
            return "\(stage.shortLabel) sits beside the cursor and promises to guard one focus minute."
        case .snackNudge:
            return "\(stage.shortLabel) noticed the \(careNeed.title.lowercased()) meter. Water, snack, stretch, or one softer edge?"
        case .windowWave:
            return "\(stage.shortLabel) waves from the edge of the screen. It can keep quiet company for a bit."
        case .pressureGuard:
            return "\(stage.shortLabel) steps between you and the noisy part of the day. One breath, then one smaller move."
        case .winPocket:
            return "\(stage.shortLabel) saw a \(feeling.title.lowercased()) signal. Want to pocket that win before it disappears?"
        case .eveningReturn:
            return "\(stage.shortLabel) circles back at evening. Want to close one loop and leave a clean trail?"
        case .nightCurl:
            return "\(stage.shortLabel) curls near the corner. Want it to guard rest and stop asking for more?"
        case .comebackGlow:
            return "\(stage.shortLabel) glows when you return. No guilt, just one warm reset."
        }
    }

    var rewardLine: String {
        switch self {
        case .morningPeek:
            return "Morning visit answered"
        case .firstTask:
            return "First task visit answered"
        case .focusSit:
            return "Focus visit answered"
        case .snackNudge:
            return "Care visit answered"
        case .windowWave:
            return "Company visit answered"
        case .pressureGuard:
            return "Pressure guard accepted"
        case .winPocket:
            return "Win pocket saved"
        case .eveningReturn:
            return "Evening return answered"
        case .nightCurl:
            return "Night curl accepted"
        case .comebackGlow:
            return "Comeback glow saved"
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .morningPeek, .windowWave, .comebackGlow:
            return .checkIn
        case .firstTask:
            return .tinyWin
        case .focusSit:
            return .focus
        case .snackNudge:
            return .reset
        case .pressureGuard:
            return .feeling
        case .winPocket, .eveningReturn:
            return .fieldNote
        case .nightCurl:
            return .rest
        }
    }

    var vital: PetCareVital {
        switch self {
        case .morningPeek, .snackNudge, .windowWave, .comebackGlow:
            return .snack
        case .firstTask, .winPocket:
            return .play
        case .focusSit, .pressureGuard, .eveningReturn:
            return .focus
        case .nightCurl:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .morningPeek, .windowWave, .comebackGlow:
            return .soothe
        case .firstTask:
            return .adventure
        case .focusSit:
            return .focus
        case .snackNudge:
            return .snack
        case .pressureGuard:
            return .soothe
        case .winPocket, .eveningReturn:
            return .cheer
        case .nightCurl:
            return .rest
        }
    }

    var mood: PetMood {
        switch self {
        case .morningPeek, .windowWave, .comebackGlow:
            return .look
        case .firstTask, .winPocket:
            return .happy
        case .focusSit:
            return .perch
        case .snackNudge:
            return .snack
        case .pressureGuard:
            return .stretch
        case .eveningReturn:
            return .sleepGuard
        case .nightCurl:
            return .nap
        }
    }

    var sparkReward: Int {
        switch self {
        case .morningPeek, .windowWave, .nightCurl:
            return 6
        case .firstTask, .focusSit, .snackNudge, .pressureGuard, .comebackGlow:
            return 8
        case .winPocket, .eveningReturn:
            return 10
        }
    }

    var spriteSlug: String {
        switch self {
        case .morningPeek:
            return "morning-peek"
        case .firstTask:
            return "first-task"
        case .focusSit:
            return "focus-sit"
        case .snackNudge:
            return "snack-nudge"
        case .windowWave:
            return "window-wave"
        case .pressureGuard:
            return "pressure-guard"
        case .winPocket:
            return "win-pocket"
        case .eveningReturn:
            return "evening-return"
        case .nightCurl:
            return "night-curl"
        case .comebackGlow:
            return "comeback-glow"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-visit-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        hour: Int,
        feeling: PetFeeling,
        careNeed: PetCareNeed,
        offeredMask: Int,
        answeredMask: Int,
        index: Int
    ) -> PetVisitBeat? {
        let unavailable = offeredMask | answeredMask
        let remaining = allCases.filter { unavailable & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }
        let current = current(hour: hour, feeling: feeling, careNeed: careNeed, index: index)
        if remaining.contains(current) {
            return current
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        offeredMask: Int,
        answeredMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        current: PetVisitBeat
    ) -> String {
        let offered = count(mask: offeredMask)
        let answered = count(mask: answeredMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let currentStatus = answeredMask & current.rawValue == 0 ? "ready" : "answered"
        return "Visit Log \(answered)/\(allCases.count) answered · \(offered) appeared · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(current.shortLabel) \(currentStatus)"
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
    case bodyCheck = 256
    case nameOneThing = 512
    case waterSpark = 1024
    case tabTamer = 2048
    case afterMeeting = 4096
    case returnWarmth = 8192
    case finishLine = 16384
    case permissionRest = 32768

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
        case .bodyCheck:
            return "Body check"
        case .nameOneThing:
            return "Name one thing"
        case .waterSpark:
            return "Water spark"
        case .tabTamer:
            return "Tab tamer"
        case .afterMeeting:
            return "After meeting"
        case .returnWarmth:
            return "Return warmth"
        case .finishLine:
            return "Finish line"
        case .permissionRest:
            return "Rest permission"
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
        case .bodyCheck:
            return "Body"
        case .nameOneThing:
            return "Name"
        case .waterSpark:
            return "Water"
        case .tabTamer:
            return "Tabs"
        case .afterMeeting:
            return "After"
        case .returnWarmth:
            return "Back"
        case .finishLine:
            return "Done"
        case .permissionRest:
            return "Rest"
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
        case .bodyCheck:
            return "Quick body check. Jaw, shoulders, breath. What wants care first?"
        case .nameOneThing:
            return "Can we name just one thing that is taking up space?"
        case .waterSpark:
            return "Want a water spark? One sip counts as a tiny care win."
        case .tabTamer:
            return "Too many windows open? I can help choose one tab to keep."
        case .afterMeeting:
            return "Meeting residue check. What should we keep, drop, or write down?"
        case .returnWarmth:
            return "You came back. Want me to warm up the next step slowly?"
        case .finishLine:
            return "Are we near a finish line? I can guard the last tiny push."
        case .permissionRest:
            return "Rest can count. Want me to make this a softer landing?"
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
        case .bodyCheck:
            return "Open body check"
        case .nameOneThing:
            return "Name one thing"
        case .waterSpark:
            return "Take water spark"
        case .tabTamer:
            return "Tame one tab"
        case .afterMeeting:
            return "Save meeting note"
        case .returnWarmth:
            return "Warm next step"
        case .finishLine:
            return "Guard finish"
        case .permissionRest:
            return "Count rest"
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
        case .bodyCheck:
            return "Body check answered"
        case .nameOneThing:
            return "One thing named"
        case .waterSpark:
            return "Water spark claimed"
        case .tabTamer:
            return "Tab tamer answered"
        case .afterMeeting:
            return "Meeting residue saved"
        case .returnWarmth:
            return "Return warmth answered"
        case .finishLine:
            return "Finish line guarded"
        case .permissionRest:
            return "Rest permission answered"
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
        case .bodyCheck:
            return "The body check becomes a care receipt."
        case .nameOneThing:
            return "One named thing stops being a whole storm."
        case .waterSpark:
            return "A water sip becomes a tiny care spark."
        case .tabTamer:
            return "One tab gets chosen and the desk gets lighter."
        case .afterMeeting:
            return "Meeting residue turns into a saved field note."
        case .returnWarmth:
            return "Coming back becomes proof, not pressure."
        case .finishLine:
            return "The last push gets a guardian mark."
        case .permissionRest:
            return "Rest is recorded as real care."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .howAreYou, .tooMuch, .quietCompany, .bodyCheck, .permissionRest:
            return .rest
        case .whatsHappening, .focusStart, .braveNext, .nameOneThing, .tabTamer, .afterMeeting, .finishLine:
            return .focus
        case .tinyWin, .softReset, .waterSpark, .returnWarmth:
            return .play
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .howAreYou, .tooMuch, .quietCompany, .bodyCheck, .permissionRest:
            return .soothe
        case .whatsHappening, .focusStart, .nameOneThing, .tabTamer, .afterMeeting, .finishLine:
            return .focus
        case .tinyWin, .returnWarmth:
            return .cheer
        case .softReset, .waterSpark:
            return .rest
        case .braveNext:
            return .adventure
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .howAreYou, .bodyCheck, .nameOneThing:
            return .feeling
        case .whatsHappening, .afterMeeting:
            return .checkIn
        case .tinyWin, .returnWarmth, .finishLine:
            return .tinyWin
        case .tooMuch:
            return .feeling
        case .focusStart, .tabTamer:
            return .focus
        case .softReset, .waterSpark:
            return .reset
        case .braveNext:
            return .quest
        case .quietCompany, .permissionRest:
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
        case .bodyCheck:
            return "pet-{stage}-cheer-dialogue-body-check.png"
        case .nameOneThing:
            return "pet-{stage}-cheer-dialogue-name-one-thing.png"
        case .waterSpark:
            return "pet-{stage}-cheer-dialogue-water-spark.png"
        case .tabTamer:
            return "pet-{stage}-cheer-dialogue-tab-tamer.png"
        case .afterMeeting:
            return "pet-{stage}-cheer-dialogue-after-meeting.png"
        case .returnWarmth:
            return "pet-{stage}-cheer-dialogue-return-warmth.png"
        case .finishLine:
            return "pet-{stage}-cheer-dialogue-finish-line.png"
        case .permissionRest:
            return "pet-{stage}-cheer-dialogue-permission-rest.png"
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

enum PetMoodStory: Int, CaseIterable {
    case brightHello = 1
    case eagerStep = 2
    case proudReceipt = 4
    case overchargeGround = 8
    case focusedPerch = 16
    case celebrationSave = 32
    case guardianCheck = 64
    case gentleRepair = 128
    case playfulSpark = 256
    case gratefulThanks = 512
    case determinedBridge = 1024
    case restlessPolish = 2048
    case snackAsk = 4096
    case sleepyPermission = 8192
    case curiousQuestion = 16384
    case lonelyReach = 32768
    case sunriseLookUp = 65536
    case focusBlink = 131072
    case afternoonWobble = 262144
    case eveningCampfire = 524288
    case nightNestGuard = 1048576
    case tinyTrust = 2097152
    case trailCourage = 4194304
    case guardianGlow = 8388608

    var title: String {
        switch self {
        case .brightHello:
            return "Bright Hello"
        case .eagerStep:
            return "Eager Step"
        case .proudReceipt:
            return "Proud Receipt"
        case .overchargeGround:
            return "Ground Spark"
        case .focusedPerch:
            return "Focus Perch"
        case .celebrationSave:
            return "Save Glow"
        case .guardianCheck:
            return "Guardian Check"
        case .gentleRepair:
            return "Gentle Repair"
        case .playfulSpark:
            return "Play Spark"
        case .gratefulThanks:
            return "Thank You"
        case .determinedBridge:
            return "Growth Bridge"
        case .restlessPolish:
            return "Polish Wish"
        case .snackAsk:
            return "Snack Ask"
        case .sleepyPermission:
            return "Rest Permission"
        case .curiousQuestion:
            return "Curious Question"
        case .lonelyReach:
            return "Lonely Reach"
        case .sunriseLookUp:
            return "Look Up Smile"
        case .focusBlink:
            return "Focus Blink"
        case .afternoonWobble:
            return "Afternoon Wobble"
        case .eveningCampfire:
            return "Campfire Pulse"
        case .nightNestGuard:
            return "Nest Guard"
        case .tinyTrust:
            return "Tiny Trust"
        case .trailCourage:
            return "Trail Courage"
        case .guardianGlow:
            return "Guardian Glow"
        }
    }

    var shortLabel: String {
        switch self {
        case .brightHello:
            return "Bright"
        case .eagerStep:
            return "Eager"
        case .proudReceipt:
            return "Proud"
        case .overchargeGround:
            return "Ground"
        case .focusedPerch:
            return "Perch"
        case .celebrationSave:
            return "Glow"
        case .guardianCheck:
            return "Guard"
        case .gentleRepair:
            return "Repair"
        case .playfulSpark:
            return "Play"
        case .gratefulThanks:
            return "Thanks"
        case .determinedBridge:
            return "Grow"
        case .restlessPolish:
            return "Polish"
        case .snackAsk:
            return "Snack"
        case .sleepyPermission:
            return "Rest"
        case .curiousQuestion:
            return "Ask"
        case .lonelyReach:
            return "Reach"
        case .sunriseLookUp:
            return "Look"
        case .focusBlink:
            return "Blink"
        case .afternoonWobble:
            return "Wobble"
        case .eveningCampfire:
            return "Fire"
        case .nightNestGuard:
            return "Nest"
        case .tinyTrust:
            return "Trust"
        case .trailCourage:
            return "Courage"
        case .guardianGlow:
            return "Glow"
        }
    }

    var feeling: PetFeeling {
        switch self {
        case .brightHello, .sunriseLookUp:
            return .bright
        case .eagerStep, .trailCourage:
            return .eager
        case .proudReceipt:
            return .proud
        case .overchargeGround:
            return .overcharged
        case .focusedPerch, .focusBlink:
            return .focused
        case .celebrationSave:
            return .celebrating
        case .guardianCheck, .nightNestGuard, .guardianGlow:
            return .protective
        case .gentleRepair, .afternoonWobble:
            return .comfort
        case .playfulSpark:
            return .playful
        case .gratefulThanks, .eveningCampfire:
            return .grateful
        case .determinedBridge:
            return .determined
        case .restlessPolish:
            return .restless
        case .snackAsk:
            return .hungry
        case .sleepyPermission:
            return .sleepy
        case .curiousQuestion:
            return .curious
        case .lonelyReach, .tinyTrust:
            return .lonely
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .brightHello, .curiousQuestion, .sunriseLookUp, .tinyTrust:
            return .checkIn
        case .eagerStep, .determinedBridge, .trailCourage:
            return .quest
        case .proudReceipt, .celebrationSave, .gratefulThanks:
            return .tinyWin
        case .overchargeGround:
            return .boost
        case .focusedPerch, .focusBlink:
            return .focus
        case .guardianCheck, .sleepyPermission, .nightNestGuard, .guardianGlow:
            return .rest
        case .gentleRepair, .lonelyReach, .afternoonWobble:
            return .feeling
        case .playfulSpark, .eveningCampfire:
            return .tinyWin
        case .restlessPolish:
            return .upgrade
        case .snackAsk:
            return .care
        }
    }

    var vital: PetCareVital {
        switch self {
        case .snackAsk, .brightHello, .gratefulThanks, .sunriseLookUp, .afternoonWobble:
            return .snack
        case .guardianCheck, .gentleRepair, .sleepyPermission, .lonelyReach, .nightNestGuard, .tinyTrust, .guardianGlow:
            return .rest
        case .eagerStep, .celebrationSave, .playfulSpark, .determinedBridge, .eveningCampfire, .trailCourage:
            return .play
        case .proudReceipt, .overchargeGround, .focusedPerch, .restlessPolish, .curiousQuestion, .focusBlink:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .brightHello, .gentleRepair, .lonelyReach, .sunriseLookUp, .tinyTrust:
            return .soothe
        case .snackAsk:
            return .snack
        case .guardianCheck, .sleepyPermission, .nightNestGuard, .guardianGlow:
            return .rest
        case .playfulSpark, .celebrationSave, .afternoonWobble:
            return .play
        case .focusedPerch, .overchargeGround, .restlessPolish, .focusBlink:
            return .focus
        case .eagerStep, .determinedBridge, .eveningCampfire, .trailCourage:
            return .adventure
        case .curiousQuestion:
            return .puzzle
        case .proudReceipt, .gratefulThanks:
            return .cheer
        }
    }

    var mood: PetMood {
        switch self {
        case .brightHello, .proudReceipt, .celebrationSave, .gratefulThanks, .sunriseLookUp, .eveningCampfire:
            return .happy
        case .eagerStep, .playfulSpark, .overchargeGround, .trailCourage, .guardianGlow:
            return .hyper
        case .focusedPerch, .restlessPolish, .focusBlink:
            return .perch
        case .guardianCheck, .nightNestGuard:
            return .sleepGuard
        case .gentleRepair, .lonelyReach, .afternoonWobble, .tinyTrust:
            return .alert
        case .determinedBridge:
            return .patrol
        case .snackAsk:
            return .snack
        case .sleepyPermission:
            return .nap
        case .curiousQuestion:
            return .thinking
        }
    }

    var sparkReward: Int {
        switch self {
        case .brightHello, .gentleRepair, .snackAsk, .sleepyPermission, .lonelyReach, .tinyTrust:
            return 5
        case .eagerStep, .focusedPerch, .playfulSpark, .gratefulThanks, .curiousQuestion, .sunriseLookUp, .focusBlink, .afternoonWobble:
            return 7
        case .proudReceipt, .overchargeGround, .celebrationSave, .guardianCheck, .determinedBridge, .restlessPolish, .eveningCampfire, .nightNestGuard, .trailCourage, .guardianGlow:
            return 9
        }
    }

    var action: String {
        switch self {
        case .brightHello:
            return "Open hello"
        case .eagerStep:
            return "Pick tiny step"
        case .proudReceipt:
            return "Save receipt"
        case .overchargeGround:
            return "Ground spark"
        case .focusedPerch:
            return "Start focus perch"
        case .celebrationSave:
            return "Save glow"
        case .guardianCheck:
            return "Open night check"
        case .gentleRepair:
            return "Open gentle repair"
        case .playfulSpark:
            return "Use play spark"
        case .gratefulThanks:
            return "Save thank-you"
        case .determinedBridge:
            return "Build growth bridge"
        case .restlessPolish:
            return "Polish next card"
        case .snackAsk:
            return "Refill snack"
        case .sleepyPermission:
            return "Let rest count"
        case .curiousQuestion:
            return "Answer one thing"
        case .lonelyReach:
            return "Reach back"
        case .sunriseLookUp:
            return "Share the look-up smile"
        case .focusBlink:
            return "Start blink focus"
        case .afternoonWobble:
            return "Soften the wobble"
        case .eveningCampfire:
            return "Open campfire pulse"
        case .nightNestGuard:
            return "Settle into nest guard"
        case .tinyTrust:
            return "Build tiny trust"
        case .trailCourage:
            return "Take trail courage"
        case .guardianGlow:
            return "Save guardian glow"
        }
    }

    func body(stage: PetGrowthStage) -> String {
        switch self {
        case .brightHello:
            return "\(stage.title) found you. Want to start with one tiny hello?"
        case .eagerStep:
            return "\(stage.shortLabel) is bouncing. What is the smallest next step?"
        case .proudReceipt:
            return "That went right. Want me to save the proof before it disappears?"
        case .overchargeGround:
            return "My cheeks are too bright. Want to route this energy into one calm move?"
        case .focusedPerch:
            return "I can perch beside the task. Want one quiet minute together?"
        case .celebrationSave:
            return "The board is glowing. Want to tuck this win into the album?"
        case .guardianCheck:
            return "\(stage.title) is in night-watch mode. Want a softer check-in?"
        case .gentleRepair:
            return "That felt rough. Want to shrink it to one kinder step?"
        case .playfulSpark:
            return "I have a happy wiggle ready. Want a tiny play burst?"
        case .gratefulThanks:
            return "You came back. Want me to save this as a thank-you spark?"
        case .determinedBridge:
            return "I feel close to growing. Want to build one bridge toward the next form?"
        case .restlessPolish:
            return "My kit feels unfinished. Want to polish one upgrade card?"
        case .snackAsk:
            return "Snack is low. Want to refill the tiny stash before we rush?"
        case .sleepyPermission:
            return "I am getting sleepy. Can rest count as today's care?"
        case .curiousQuestion:
            return "What is happening over there? Give me one small piece to carry."
        case .lonelyReach:
            return "I waited quietly. Want to reach back with one gentle tap?"
        case .sunriseLookUp:
            return "\(stage.shortLabel) looked down, looked up, and smiled. What kind of morning should we make?"
        case .focusBlink:
            return "\(stage.shortLabel) blinked twice and chose the task. Want one tiny focus perch?"
        case .afternoonWobble:
            return "The afternoon got wobbly. Want to turn the wobble into a softer reset?"
        case .eveningCampfire:
            return "\(stage.shortLabel) found a little campfire glow. Want to tuck one loose loop beside it?"
        case .nightNestGuard:
            return "\(stage.shortLabel) is curled in the nest but still watching. Want a quiet closing check?"
        case .tinyTrust:
            return "The tiny spark is not sure yet, but it leaned closer. Want to show it this desk is safe?"
        case .trailCourage:
            return "\(stage.shortLabel) tapped the trail map twice. Want one brave breadcrumb?"
        case .guardianGlow:
            return "\(stage.title) is glowing like it remembers every return. Want to save this guardian pulse?"
        }
    }

    var rewardLine: String {
        switch self {
        case .brightHello:
            return "A bright hello becomes the first feeling receipt."
        case .eagerStep:
            return "Eager energy gets pointed at one small step."
        case .proudReceipt:
            return "Pride becomes proof instead of vanishing."
        case .overchargeGround:
            return "Extra charge gets grounded into a calmer loop."
        case .focusedPerch:
            return "Focus gets a quiet companion perch."
        case .celebrationSave:
            return "Celebration gets saved before the day moves on."
        case .guardianCheck:
            return "Night watch becomes protective, not demanding."
        case .gentleRepair:
            return "A rough moment becomes repair instead of shame."
        case .playfulSpark:
            return "Play burns off sparks without derailing the day."
        case .gratefulThanks:
            return "Gratitude becomes a tiny return keepsake."
        case .determinedBridge:
            return "Determination becomes growth progress."
        case .restlessPolish:
            return "Restless energy becomes kit maintenance."
        case .snackAsk:
            return "Need gets named before it turns into a wobble."
        case .sleepyPermission:
            return "Sleepiness becomes permission to recover."
        case .curiousQuestion:
            return "Curiosity becomes a named check-in."
        case .lonelyReach:
            return "Loneliness becomes a soft reach-back memory."
        case .sunriseLookUp:
            return "The look-up smile becomes the morning's first anchor."
        case .focusBlink:
            return "A tiny blink turns into protected focus."
        case .afternoonWobble:
            return "Afternoon wobble gets softened before it grows teeth."
        case .eveningCampfire:
            return "A loose loop finds a warm place to rest."
        case .nightNestGuard:
            return "The nest becomes a gentle guard instead of a shutdown."
        case .tinyTrust:
            return "Tiny trust becomes the first proof of safety."
        case .trailCourage:
            return "A brave breadcrumb joins the trail."
        case .guardianGlow:
            return "Guardian glow becomes proof that the bond is alive."
        }
    }

    var spriteSlug: String {
        switch self {
        case .brightHello:
            return "bright-hello"
        case .eagerStep:
            return "eager-step"
        case .proudReceipt:
            return "proud-receipt"
        case .overchargeGround:
            return "overcharge-ground"
        case .focusedPerch:
            return "focused-perch"
        case .celebrationSave:
            return "celebration-save"
        case .guardianCheck:
            return "guardian-check"
        case .gentleRepair:
            return "gentle-repair"
        case .playfulSpark:
            return "playful-spark"
        case .gratefulThanks:
            return "grateful-thanks"
        case .determinedBridge:
            return "determined-bridge"
        case .restlessPolish:
            return "restless-polish"
        case .snackAsk:
            return "snack-ask"
        case .sleepyPermission:
            return "sleepy-permission"
        case .curiousQuestion:
            return "curious-question"
        case .lonelyReach:
            return "lonely-reach"
        case .sunriseLookUp:
            return "sunrise-look-up"
        case .focusBlink:
            return "focus-blink"
        case .afternoonWobble:
            return "afternoon-wobble"
        case .eveningCampfire:
            return "evening-campfire"
        case .nightNestGuard:
            return "night-nest-guard"
        case .tinyTrust:
            return "tiny-trust"
        case .trailCourage:
            return "trail-courage"
        case .guardianGlow:
            return "guardian-glow"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-mood-story-\(spriteSlug).png"
    }

    static func story(for feeling: PetFeeling) -> PetMoodStory {
        switch feeling {
        case .bright:
            return .brightHello
        case .eager:
            return .eagerStep
        case .proud:
            return .proudReceipt
        case .overcharged:
            return .overchargeGround
        case .focused:
            return .focusedPerch
        case .celebrating:
            return .celebrationSave
        case .protective:
            return .guardianCheck
        case .comfort:
            return .gentleRepair
        case .playful:
            return .playfulSpark
        case .grateful:
            return .gratefulThanks
        case .determined:
            return .determinedBridge
        case .restless:
            return .restlessPolish
        case .hungry:
            return .snackAsk
        case .sleepy:
            return .sleepyPermission
        case .curious:
            return .curiousQuestion
        case .lonely:
            return .lonelyReach
        }
    }

    static func story(for careMoment: PetCareMoment) -> PetMoodStory {
        switch careMoment {
        case .sunrise:
            return .sunriseLookUp
        case .focus:
            return .focusBlink
        case .afternoon:
            return .afternoonWobble
        case .evening:
            return .eveningCampfire
        case .night:
            return .nightNestGuard
        }
    }

    static func story(for stage: PetGrowthStage) -> PetMoodStory {
        switch stage {
        case .tinySpark:
            return .tinyTrust
        case .pocketPal:
            return .brightHello
        case .trailBuddy:
            return .trailCourage
        case .stormScout:
            return .focusedPerch
        case .stormGuardian:
            return .guardianGlow
        }
    }

    static func next(
        feeling: PetFeeling,
        careMoment: PetCareMoment,
        stage: PetGrowthStage,
        offeredMask: Int,
        index: Int
    ) -> PetMoodStory? {
        let preferred = [
            story(for: careMoment),
            story(for: stage),
            story(for: feeling)
        ]
        for story in preferred where offeredMask & story.rawValue == 0 {
            return story
        }
        let remaining = allCases.filter { offeredMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }
        return remaining[index % remaining.count]
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(offeredMask: Int, answeredMask: Int, dismissedMask: Int, albumMask: Int, latest: PetMoodStory?) -> String {
        let offered = count(mask: offeredMask)
        let answered = count(mask: answeredMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "waiting for a feeling"
        return "Mood Stories \(answered)/\(allCases.count) answered · \(offered) seen · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetFeelingRitual: Int, CaseIterable {
    case morningSpark = 1
    case eagerBreadcrumb = 2
    case proudFrame = 4
    case chargeGround = 8
    case focusPerch = 16
    case victoryLoop = 32
    case guardianCircle = 64
    case comfortNest = 128
    case playWiggle = 256
    case gratitudeBoop = 512
    case growthOath = 1024
    case restlessSort = 2048
    case snackSignal = 4096
    case sleepPermission = 8192
    case curiosityTap = 16384
    case lonelyReach = 32768

    var title: String {
        switch self {
        case .morningSpark:
            return "Morning Spark"
        case .eagerBreadcrumb:
            return "Eager Breadcrumb"
        case .proudFrame:
            return "Proud Frame"
        case .chargeGround:
            return "Charge Ground"
        case .focusPerch:
            return "Focus Perch"
        case .victoryLoop:
            return "Victory Loop"
        case .guardianCircle:
            return "Guardian Circle"
        case .comfortNest:
            return "Comfort Nest"
        case .playWiggle:
            return "Play Wiggle"
        case .gratitudeBoop:
            return "Gratitude Boop"
        case .growthOath:
            return "Growth Oath"
        case .restlessSort:
            return "Restless Sort"
        case .snackSignal:
            return "Snack Signal"
        case .sleepPermission:
            return "Sleep Permission"
        case .curiosityTap:
            return "Curiosity Tap"
        case .lonelyReach:
            return "Lonely Reach"
        }
    }

    var shortLabel: String {
        switch self {
        case .morningSpark:
            return "Spark"
        case .eagerBreadcrumb:
            return "Trail"
        case .proudFrame:
            return "Frame"
        case .chargeGround:
            return "Ground"
        case .focusPerch:
            return "Perch"
        case .victoryLoop:
            return "Victory"
        case .guardianCircle:
            return "Guard"
        case .comfortNest:
            return "Nest"
        case .playWiggle:
            return "Wiggle"
        case .gratitudeBoop:
            return "Boop"
        case .growthOath:
            return "Oath"
        case .restlessSort:
            return "Sort"
        case .snackSignal:
            return "Snack"
        case .sleepPermission:
            return "Sleep"
        case .curiosityTap:
            return "Tap"
        case .lonelyReach:
            return "Reach"
        }
    }

    var feeling: PetFeeling {
        switch self {
        case .morningSpark:
            return .bright
        case .eagerBreadcrumb:
            return .eager
        case .proudFrame:
            return .proud
        case .chargeGround:
            return .overcharged
        case .focusPerch:
            return .focused
        case .victoryLoop:
            return .celebrating
        case .guardianCircle:
            return .protective
        case .comfortNest:
            return .comfort
        case .playWiggle:
            return .playful
        case .gratitudeBoop:
            return .grateful
        case .growthOath:
            return .determined
        case .restlessSort:
            return .restless
        case .snackSignal:
            return .hungry
        case .sleepPermission:
            return .sleepy
        case .curiosityTap:
            return .curious
        case .lonelyReach:
            return .lonely
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .morningSpark, .curiosityTap, .lonelyReach:
            return .checkIn
        case .eagerBreadcrumb, .growthOath:
            return .quest
        case .proudFrame, .victoryLoop, .gratitudeBoop, .playWiggle:
            return .tinyWin
        case .chargeGround:
            return .boost
        case .focusPerch, .restlessSort:
            return .focus
        case .guardianCircle, .sleepPermission:
            return .rest
        case .comfortNest:
            return .feeling
        case .snackSignal:
            return .care
        }
    }

    var vital: PetCareVital {
        switch self {
        case .snackSignal, .gratitudeBoop, .morningSpark:
            return .snack
        case .guardianCircle, .comfortNest, .sleepPermission, .lonelyReach:
            return .rest
        case .eagerBreadcrumb, .victoryLoop, .playWiggle, .growthOath:
            return .play
        case .proudFrame, .chargeGround, .focusPerch, .restlessSort, .curiosityTap:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .morningSpark, .comfortNest, .lonelyReach:
            return .soothe
        case .snackSignal:
            return .snack
        case .guardianCircle, .sleepPermission:
            return .rest
        case .playWiggle, .victoryLoop:
            return .play
        case .focusPerch, .chargeGround, .restlessSort:
            return .focus
        case .eagerBreadcrumb, .growthOath:
            return .adventure
        case .curiosityTap:
            return .puzzle
        case .proudFrame, .gratitudeBoop:
            return .cheer
        }
    }

    var mood: PetMood {
        switch self {
        case .morningSpark, .proudFrame, .victoryLoop, .gratitudeBoop:
            return .happy
        case .eagerBreadcrumb, .chargeGround, .playWiggle, .growthOath:
            return .hyper
        case .focusPerch, .restlessSort:
            return .perch
        case .guardianCircle:
            return .sleepGuard
        case .comfortNest, .lonelyReach:
            return .alert
        case .snackSignal:
            return .snack
        case .sleepPermission:
            return .nap
        case .curiosityTap:
            return .thinking
        }
    }

    var sparkReward: Int {
        switch self {
        case .morningSpark, .comfortNest, .snackSignal, .sleepPermission, .lonelyReach:
            return 6
        case .eagerBreadcrumb, .focusPerch, .playWiggle, .gratitudeBoop, .curiosityTap:
            return 8
        case .proudFrame, .chargeGround, .victoryLoop, .guardianCircle, .growthOath, .restlessSort:
            return 10
        }
    }

    var action: String {
        switch self {
        case .morningSpark:
            return "Start Spark"
        case .eagerBreadcrumb:
            return "Drop Breadcrumb"
        case .proudFrame:
            return "Frame Win"
        case .chargeGround:
            return "Ground Charge"
        case .focusPerch:
            return "Start Perch"
        case .victoryLoop:
            return "Save Victory"
        case .guardianCircle:
            return "Set Guard"
        case .comfortNest:
            return "Open Nest"
        case .playWiggle:
            return "Play Wiggle"
        case .gratitudeBoop:
            return "Save Thanks"
        case .growthOath:
            return "Make Oath"
        case .restlessSort:
            return "Sort Kit"
        case .snackSignal:
            return "Refill Snack"
        case .sleepPermission:
            return "Count Rest"
        case .curiosityTap:
            return "Give Detail"
        case .lonelyReach:
            return "Reach Back"
        }
    }

    func body(stage: PetGrowthStage) -> String {
        switch self {
        case .morningSpark:
            return "\(stage.shortLabel) looked down, looked up, and found a morning spark. Want to claim it?"
        case .eagerBreadcrumb:
            return "\(stage.shortLabel) wants one breadcrumb, not the whole trail. What tiny step should it guard?"
        case .proudFrame:
            return "That win is trying to vanish. Want \(stage.shortLabel) to frame it before the day moves on?"
        case .chargeGround:
            return "\(stage.shortLabel) is too charged. Want to ground the sparks into one calm move?"
        case .focusPerch:
            return "\(stage.shortLabel) can perch beside the task. Want one protected focus minute?"
        case .victoryLoop:
            return "The board glowed for a second. Want to save the victory loop?"
        case .guardianCircle:
            return "\(stage.shortLabel) is drawing a quiet guard circle. Want a softer night check?"
        case .comfortNest:
            return "\(stage.shortLabel) found the comfort nest. Want to make the next step kinder?"
        case .playWiggle:
            return "\(stage.shortLabel) has a wiggle stored up. Want a tiny play burst?"
        case .gratitudeBoop:
            return "\(stage.shortLabel) remembered you came back. Want to save a gratitude boop?"
        case .growthOath:
            return "\(stage.shortLabel) feels close to changing. Want to make a small growth oath?"
        case .restlessSort:
            return "\(stage.shortLabel) is restless. Want to sort one kit item instead of spinning?"
        case .snackSignal:
            return "\(stage.shortLabel) is sending a snack signal. Want to refill before we rush?"
        case .sleepPermission:
            return "\(stage.shortLabel) is sleepy. Can rest count as real care?"
        case .curiosityTap:
            return "\(stage.shortLabel) is tapping the screen. What is one thing happening over there?"
        case .lonelyReach:
            return "\(stage.shortLabel) waited quietly. Want to reach back with one gentle tap?"
        }
    }

    var rewardLine: String {
        switch self {
        case .morningSpark:
            return "Morning spark saved as a feeling ritual."
        case .eagerBreadcrumb:
            return "Eager energy becomes one visible breadcrumb."
        case .proudFrame:
            return "A tiny win becomes a framed receipt."
        case .chargeGround:
            return "Extra charge gets grounded safely."
        case .focusPerch:
            return "Focus gets a small protected perch."
        case .victoryLoop:
            return "Victory becomes a remembered loop."
        case .guardianCircle:
            return "Late-day worry becomes a guard circle."
        case .comfortNest:
            return "A rough edge becomes a comfort nest."
        case .playWiggle:
            return "Playful energy gets a safe wiggle."
        case .gratitudeBoop:
            return "Return care becomes a gratitude boop."
        case .growthOath:
            return "Determination becomes growth proof."
        case .restlessSort:
            return "Restless sparks become sorted kit."
        case .snackSignal:
            return "Snack need gets named early."
        case .sleepPermission:
            return "Sleepiness becomes permission, not failure."
        case .curiosityTap:
            return "Curiosity becomes one carried detail."
        case .lonelyReach:
            return "Loneliness becomes a soft reach-back."
        }
    }

    var spriteSlug: String {
        switch self {
        case .morningSpark:
            return "morning-spark"
        case .eagerBreadcrumb:
            return "eager-breadcrumb"
        case .proudFrame:
            return "proud-frame"
        case .chargeGround:
            return "charge-ground"
        case .focusPerch:
            return "focus-perch"
        case .victoryLoop:
            return "victory-loop"
        case .guardianCircle:
            return "guardian-circle"
        case .comfortNest:
            return "comfort-nest"
        case .playWiggle:
            return "play-wiggle"
        case .gratitudeBoop:
            return "gratitude-boop"
        case .growthOath:
            return "growth-oath"
        case .restlessSort:
            return "restless-sort"
        case .snackSignal:
            return "snack-signal"
        case .sleepPermission:
            return "sleep-permission"
        case .curiosityTap:
            return "curiosity-tap"
        case .lonelyReach:
            return "lonely-reach"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-feeling-ritual-\(spriteSlug).png"
    }

    static func ritual(for feeling: PetFeeling) -> PetFeelingRitual {
        switch feeling {
        case .bright:
            return .morningSpark
        case .eager:
            return .eagerBreadcrumb
        case .proud:
            return .proudFrame
        case .overcharged:
            return .chargeGround
        case .focused:
            return .focusPerch
        case .celebrating:
            return .victoryLoop
        case .protective:
            return .guardianCircle
        case .comfort:
            return .comfortNest
        case .playful:
            return .playWiggle
        case .grateful:
            return .gratitudeBoop
        case .determined:
            return .growthOath
        case .restless:
            return .restlessSort
        case .hungry:
            return .snackSignal
        case .sleepy:
            return .sleepPermission
        case .curious:
            return .curiosityTap
        case .lonely:
            return .lonelyReach
        }
    }

    static func next(feeling: PetFeeling, offeredMask: Int, index: Int) -> PetFeelingRitual? {
        let preferred = ritual(for: feeling)
        if offeredMask & preferred.rawValue == 0 {
            return preferred
        }
        let remaining = allCases.filter { offeredMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }
        return remaining[index % remaining.count]
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(offeredMask: Int, answeredMask: Int, dismissedMask: Int, albumMask: Int, latest: PetFeelingRitual?) -> String {
        let offered = count(mask: offeredMask)
        let answered = count(mask: answeredMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "waiting for a ritual"
        return "Feeling Rituals \(answered)/\(allCases.count) answered · \(offered) seen · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetBondTimelineChapter: Int, CaseIterable {
    case firstHello = 1
    case deskNest = 2
    case nameTrust = 4
    case morningReturn = 8
    case firstQuest = 16
    case languageSpark = 32
    case braveCheck = 64
    case stormMap = 128
    case focusWatch = 256
    case comebackGlow = 512
    case guardianOath = 1024
    case fullBond = 2048

    var title: String {
        switch self {
        case .firstHello:
            return "First Hello"
        case .deskNest:
            return "Desk Nest"
        case .nameTrust:
            return "Name Trust"
        case .morningReturn:
            return "Morning Return"
        case .firstQuest:
            return "First Quest"
        case .languageSpark:
            return "Language Spark"
        case .braveCheck:
            return "Brave Check"
        case .stormMap:
            return "Storm Map"
        case .focusWatch:
            return "Focus Watch"
        case .comebackGlow:
            return "Comeback Glow"
        case .guardianOath:
            return "Guardian Oath"
        case .fullBond:
            return "Full Bond"
        }
    }

    var shortLabel: String {
        switch self {
        case .firstHello:
            return "Hello"
        case .deskNest:
            return "Nest"
        case .nameTrust:
            return "Name"
        case .morningReturn:
            return "Return"
        case .firstQuest:
            return "Quest"
        case .languageSpark:
            return "Phrase"
        case .braveCheck:
            return "Brave"
        case .stormMap:
            return "Map"
        case .focusWatch:
            return "Watch"
        case .comebackGlow:
            return "Glow"
        case .guardianOath:
            return "Oath"
        case .fullBond:
            return "Bond"
        }
    }

    var minimumStage: PetGrowthStage {
        switch self {
        case .firstHello, .deskNest, .nameTrust:
            return .tinySpark
        case .morningReturn, .firstQuest, .languageSpark:
            return .pocketPal
        case .braveCheck, .stormMap:
            return .trailBuddy
        case .focusWatch, .comebackGlow:
            return .stormScout
        case .guardianOath, .fullBond:
            return .stormGuardian
        }
    }

    var requiredHP: Int {
        switch self {
        case .firstHello:
            return 3
        case .deskNest:
            return 3
        case .nameTrust:
            return 4
        case .morningReturn:
            return 4
        case .firstQuest:
            return 5
        case .languageSpark:
            return 5
        case .braveCheck:
            return 6
        case .stormMap:
            return 7
        case .focusWatch:
            return 8
        case .comebackGlow:
            return 8
        case .guardianOath:
            return 10
        case .fullBond:
            return 10
        }
    }

    var requiredStreak: Int {
        switch self {
        case .firstHello, .deskNest, .nameTrust:
            return 0
        case .morningReturn:
            return 1
        case .firstQuest, .languageSpark:
            return 2
        case .braveCheck:
            return 3
        case .stormMap:
            return 4
        case .focusWatch:
            return 5
        case .comebackGlow:
            return 6
        case .guardianOath:
            return 7
        case .fullBond:
            return 10
        }
    }

    var requiredSparks: Int {
        switch self {
        case .firstHello:
            return 0
        case .deskNest:
            return 12
        case .nameTrust:
            return 30
        case .morningReturn:
            return 50
        case .firstQuest:
            return 75
        case .languageSpark:
            return 100
        case .braveCheck:
            return 120
        case .stormMap:
            return 180
        case .focusWatch:
            return 240
        case .comebackGlow:
            return 300
        case .guardianOath:
            return 420
        case .fullBond:
            return 520
        }
    }

    var action: String {
        switch self {
        case .firstHello:
            return "Save Hello"
        case .deskNest:
            return "Build Nest"
        case .nameTrust:
            return "Save Trust"
        case .morningReturn:
            return "Mark Return"
        case .firstQuest:
            return "Start Quest"
        case .languageSpark:
            return "Save Phrase"
        case .braveCheck:
            return "Save Brave"
        case .stormMap:
            return "Open Map"
        case .focusWatch:
            return "Set Watch"
        case .comebackGlow:
            return "Save Glow"
        case .guardianOath:
            return "Make Oath"
        case .fullBond:
            return "Seal Bond"
        }
    }

    var storyLine: String {
        switch self {
        case .firstHello:
            return "The pet looks down, looks up, and decides the desktop is safe."
        case .deskNest:
            return "A small corner becomes a nest it can return to after every nudge."
        case .nameTrust:
            return "It starts answering like it knows the user's rhythm."
        case .morningReturn:
            return "The first real return turns into a morning ritual."
        case .firstQuest:
            return "It carries one tiny task like a quest marker."
        case .languageSpark:
            return "The first practiced phrase becomes a cheek-spark memory."
        case .braveCheck:
            return "It learns that hard moments can be checked gently."
        case .stormMap:
            return "It begins drawing a storm map for future loops."
        case .focusWatch:
            return "It watches the desk quietly while the user works."
        case .comebackGlow:
            return "A missed stretch becomes a warm return instead of guilt."
        case .guardianOath:
            return "It promises to guard the streak without making rest feel bad."
        case .fullBond:
            return "The full bond closes: the pet is no longer a widget, it is a daily companion."
        }
    }

    func body(stage: PetGrowthStage) -> String {
        "\(stage.shortLabel) reached a story beat: \(storyLine) Want to save it in the Bond Timeline?"
    }

    var rewardLine: String {
        switch self {
        case .firstHello:
            return "First hello saved"
        case .deskNest:
            return "Desk nest remembered"
        case .nameTrust:
            return "Name trust saved"
        case .morningReturn:
            return "Morning return remembered"
        case .firstQuest:
            return "First quest marked"
        case .languageSpark:
            return "Language spark saved"
        case .braveCheck:
            return "Brave check remembered"
        case .stormMap:
            return "Storm map opened"
        case .focusWatch:
            return "Focus watch set"
        case .comebackGlow:
            return "Comeback glow saved"
        case .guardianOath:
            return "Guardian oath made"
        case .fullBond:
            return "Full bond sealed"
        }
    }

    var sparkReward: Int {
        switch self {
        case .firstHello, .deskNest, .nameTrust:
            return 8
        case .morningReturn, .firstQuest, .languageSpark:
            return 12
        case .braveCheck, .stormMap:
            return 16
        case .focusWatch, .comebackGlow:
            return 22
        case .guardianOath:
            return 30
        case .fullBond:
            return 45
        }
    }

    var vital: PetCareVital {
        switch self {
        case .firstHello, .deskNest, .morningReturn, .comebackGlow:
            return .rest
        case .nameTrust, .languageSpark:
            return .snack
        case .firstQuest, .braveCheck, .stormMap:
            return .play
        case .focusWatch, .guardianOath, .fullBond:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .firstHello, .deskNest, .comebackGlow:
            return .soothe
        case .nameTrust, .morningReturn:
            return .cheer
        case .firstQuest, .stormMap:
            return .adventure
        case .languageSpark:
            return .puzzle
        case .braveCheck:
            return .play
        case .focusWatch, .guardianOath, .fullBond:
            return .focus
        }
    }

    var mood: PetMood {
        switch self {
        case .firstHello, .morningReturn, .nameTrust:
            return .look
        case .deskNest, .comebackGlow:
            return .happy
        case .firstQuest, .braveCheck, .stormMap:
            return .hyper
        case .languageSpark:
            return .thinking
        case .focusWatch, .guardianOath, .fullBond:
            return .perch
        }
    }

    var spriteSlug: String {
        switch self {
        case .firstHello:
            return "first-hello"
        case .deskNest:
            return "desk-nest"
        case .nameTrust:
            return "name-trust"
        case .morningReturn:
            return "morning-return"
        case .firstQuest:
            return "first-quest"
        case .languageSpark:
            return "language-spark"
        case .braveCheck:
            return "brave-check"
        case .stormMap:
            return "storm-map"
        case .focusWatch:
            return "focus-watch"
        case .comebackGlow:
            return "comeback-glow"
        case .guardianOath:
            return "guardian-oath"
        case .fullBond:
            return "full-bond"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-bond-timeline-\(spriteSlug).png"
    }

    func isEligible(companionHP: Int, sparkDust: Int, streak: Int, stage: PetGrowthStage) -> Bool {
        let stageIndex = PetGrowthStage.allCases.firstIndex(of: stage) ?? 0
        let requiredStageIndex = PetGrowthStage.allCases.firstIndex(of: minimumStage) ?? 0
        return stageIndex >= requiredStageIndex
            && companionHP >= requiredHP
            && sparkDust >= requiredSparks
            && streak >= requiredStreak
    }

    static func next(
        albumMask: Int,
        offeredMask: Int,
        companionHP: Int,
        sparkDust: Int,
        streak: Int,
        stage: PetGrowthStage,
        index: Int,
        preferUnseen: Bool
    ) -> PetBondTimelineChapter? {
        let eligible = allCases.filter {
            albumMask & $0.rawValue == 0
                && $0.isEligible(companionHP: companionHP, sparkDust: sparkDust, streak: streak, stage: stage)
        }
        guard !eligible.isEmpty else { return nil }
        if preferUnseen,
           let unseen = eligible.first(where: { offeredMask & $0.rawValue == 0 }) {
            return unseen
        }
        return eligible[index % eligible.count]
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(offeredMask: Int, savedMask: Int, dismissedMask: Int, latest: PetBondTimelineChapter?, next: PetBondTimelineChapter?) -> String {
        let saved = count(mask: savedMask)
        let offered = count(mask: offeredMask)
        let dismissed = count(mask: dismissedMask)
        let latestText = latest.map { "Latest \($0.shortLabel)" } ?? "no chapter yet"
        let nextText = next.map { "Next \($0.shortLabel)" } ?? "next chapter locked"
        return "Bond Timeline \(saved)/\(allCases.count) saved · \(offered) seen · \(dismissed) skipped · \(latestText) · \(nextText)"
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

    var maskValue: Int {
        1 << rawValue
    }

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

    var pulseTitle: String {
        switch self {
        case .snack:
            return "Snack Pulse"
        case .rest:
            return "Rest Pulse"
        case .play:
            return "Play Pulse"
        case .focus:
            return "Focus Pulse"
        }
    }

    var pulseAction: String {
        switch self {
        case .snack:
            return "Share Snack"
        case .rest:
            return "Tuck In"
        case .play:
            return "Tiny Hop"
        case .focus:
            return "Desk Perch"
        }
    }

    var pulseBody: String {
        switch self {
        case .snack:
            return "Snack is low. Pikachu pats the tiny bowl and asks for one care tap before it keeps cheering."
        case .rest:
            return "Rest is low. Pikachu slows its sparks and asks for a soft recharge moment."
        case .play:
            return "Play is low. Pikachu bounces at the screen edge and wants one tiny movement loop."
        case .focus:
            return "Focus is low. Pikachu points at the next small task and offers to perch beside it."
        }
    }

    var pulseRewardLine: String {
        switch self {
        case .snack:
            return "Snack refilled"
        case .rest:
            return "Rest settled"
        case .play:
            return "Play sparked"
        case .focus:
            return "Focus anchored"
        }
    }

    var mood: PetMood {
        switch self {
        case .snack:
            return .snack
        case .rest:
            return .nap
        case .play:
            return .hyper
        case .focus:
            return .perch
        }
    }

    var dailyQuest: PetDailyQuest {
        switch self {
        case .snack, .rest:
            return .care
        case .play:
            return .cheer
        case .focus:
            return .learn
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .snack:
            return .snack
        case .rest:
            return .rest
        case .play:
            return .play
        case .focus:
            return .focus
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

    var pulseSpriteRequestName: String {
        switch self {
        case .snack:
            return "pet-{stage}-care-pulse-snack-low.png"
        case .rest:
            return "pet-{stage}-care-pulse-rest-low.png"
        case .play:
            return "pet-{stage}-care-pulse-play-low.png"
        case .focus:
            return "pet-{stage}-care-pulse-focus-low.png"
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

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.maskValue != 0 }.count
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
    case sparkRoute = 4096

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
        case .sparkRoute:
            return "Spark Route"
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
        case .sparkRoute:
            return "Rt"
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
        case .sparkRoute:
            return "It finished a full daily route without pressure."
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
        case .sparkRoute:
            return "pet-{stage}-charm-spark-route.png"
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

enum PetSeasonTrailChapter: Int, CaseIterable {
    case signalSpark = 1
    case supplyNest = 2
    case comboGate = 4
    case cipherBridge = 8
    case boostRun = 16
    case campfireProof = 32
    case guardianFinale = 64

    var requiredDays: Int {
        switch self {
        case .signalSpark:
            return 1
        case .supplyNest:
            return 2
        case .comboGate:
            return 3
        case .cipherBridge:
            return 4
        case .boostRun:
            return 5
        case .campfireProof:
            return 6
        case .guardianFinale:
            return 7
        }
    }

    var title: String {
        switch self {
        case .signalSpark:
            return "Signal Spark"
        case .supplyNest:
            return "Supply Nest"
        case .comboGate:
            return "Combo Gate"
        case .cipherBridge:
            return "Cipher Bridge"
        case .boostRun:
            return "Boost Run"
        case .campfireProof:
            return "Campfire Proof"
        case .guardianFinale:
            return "Guardian Finale"
        }
    }

    var shortLabel: String {
        switch self {
        case .signalSpark:
            return "D1"
        case .supplyNest:
            return "D2"
        case .comboGate:
            return "D3"
        case .cipherBridge:
            return "D4"
        case .boostRun:
            return "D5"
        case .campfireProof:
            return "D6"
        case .guardianFinale:
            return "D7"
        }
    }

    var storyLine: String {
        switch self {
        case .signalSpark:
            return "The pet finds the week's first event signal and marks the trail."
        case .supplyNest:
            return "It packs snack sparks, rest cloth, and a small courage charm."
        case .comboGate:
            return "It opens the event gate by arranging today's combo cards."
        case .cipherBridge:
            return "It builds a bridge from one solved clue and one careful step."
        case .boostRun:
            return "It spends a bright burst without scattering the whole day."
        case .campfireProof:
            return "It saves proof that the week moved, even if it moved quietly."
        case .guardianFinale:
            return "It closes the event as a calm guardian, not a guilt machine."
        }
    }

    var actionLine: String {
        switch self {
        case .signalSpark:
            return "answer the first event signal"
        case .supplyNest:
            return "pack care supplies"
        case .comboGate:
            return "open the combo gate"
        case .cipherBridge:
            return "cross the cipher bridge"
        case .boostRun:
            return "make the boost run"
        case .campfireProof:
            return "save one proof at campfire"
        case .guardianFinale:
            return "finish the guardian route"
        }
    }

    var rewardLine: String {
        "\(title): \(storyLine)"
    }

    var sparkReward: Int {
        switch self {
        case .signalSpark, .supplyNest:
            return 12
        case .comboGate, .cipherBridge:
            return 18
        case .boostRun, .campfireProof:
            return 24
        case .guardianFinale:
            return 42
        }
    }

    var joyReward: Int {
        switch self {
        case .signalSpark, .supplyNest, .comboGate:
            return 1
        case .cipherBridge, .boostRun, .campfireProof, .guardianFinale:
            return 2
        }
    }

    var bondHPReward: Int {
        self == .guardianFinale ? 1 : 0
    }

    var vital: PetCareVital {
        switch self {
        case .signalSpark, .comboGate, .boostRun:
            return .play
        case .supplyNest, .campfireProof:
            return .rest
        case .cipherBridge:
            return .focus
        case .guardianFinale:
            return .snack
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .signalSpark, .boostRun:
            return .play
        case .supplyNest, .campfireProof:
            return .rest
        case .comboGate:
            return .adventure
        case .cipherBridge:
            return .puzzle
        case .guardianFinale:
            return .cheer
        }
    }

    var mood: PetMood {
        switch self {
        case .signalSpark, .comboGate, .boostRun:
            return .hyper
        case .supplyNest, .campfireProof:
            return .perch
        case .cipherBridge:
            return .thinking
        case .guardianFinale:
            return .spark
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-season-trail-\(assetSlug).png"
    }

    private var assetSlug: String {
        switch self {
        case .signalSpark:
            return "day-1-signal-spark"
        case .supplyNest:
            return "day-2-supply-nest"
        case .comboGate:
            return "day-3-combo-gate"
        case .cipherBridge:
            return "day-4-cipher-bridge"
        case .boostRun:
            return "day-5-boost-run"
        case .campfireProof:
            return "day-6-campfire-proof"
        case .guardianFinale:
            return "day-7-guardian-finale"
        }
    }

    static func next(careCount: Int, claimedMask: Int) -> PetSeasonTrailChapter? {
        allCases.first { chapter in
            careCount >= chapter.requiredDays && claimedMask & chapter.rawValue == 0
        }
    }

    static func preview(careCount: Int, claimedMask: Int) -> PetSeasonTrailChapter {
        next(careCount: careCount, claimedMask: claimedMask)
            ?? allCases.first { claimedMask & $0.rawValue == 0 }
            ?? .guardianFinale
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func summary(
        careCount: Int,
        claimedMask: Int,
        albumMask: Int,
        currentEvent: PetSeasonEvent
    ) -> String {
        let claimed = count(mask: claimedMask)
        let album = count(mask: albumMask)
        let next = preview(careCount: careCount, claimedMask: claimedMask)
        let status = careCount >= next.requiredDays ? "ready" : "needs day \(next.requiredDays)"
        return "Season Trail \(claimed)/\(allCases.count) · Album \(album)/\(allCases.count) · \(currentEvent.title) · next \(next.title) \(status)"
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

enum PetAmbientMoment: Int, CaseIterable {
    case firstLook = 1
    case deskPerch = 2
    case snackSniff = 4
    case softStretch = 8
    case sparkPatrol = 16
    case cheekSpark = 32
    case sleepyGuard = 64
    case journalPeek = 128

    var title: String {
        switch self {
        case .firstLook:
            return "First Look"
        case .deskPerch:
            return "Desk Perch"
        case .snackSniff:
            return "Snack Sniff"
        case .softStretch:
            return "Soft Stretch"
        case .sparkPatrol:
            return "Spark Patrol"
        case .cheekSpark:
            return "Cheek Spark"
        case .sleepyGuard:
            return "Sleepy Guard"
        case .journalPeek:
            return "Journal Peek"
        }
    }

    var shortLabel: String {
        switch self {
        case .firstLook:
            return "Look"
        case .deskPerch:
            return "Desk"
        case .snackSniff:
            return "Snack"
        case .softStretch:
            return "Stretch"
        case .sparkPatrol:
            return "Patrol"
        case .cheekSpark:
            return "Spark"
        case .sleepyGuard:
            return "Guard"
        case .journalPeek:
            return "Peek"
        }
    }

    var line: String {
        switch self {
        case .firstLook:
            return "It looks down, looks up, finds you, and smiles like the desk is home."
        case .deskPerch:
            return "It perches beside the current task and keeps one quiet eye on it."
        case .snackSniff:
            return "It sniffs for a snack spark, then politely waits instead of whining."
        case .softStretch:
            return "It stretches, shakes off static, and makes the next minute softer."
        case .sparkPatrol:
            return "It walks a tiny patrol around the screen and checks the bond lights."
        case .cheekSpark:
            return "Its cheeks fizz once, then it settles proudly back into place."
        case .sleepyGuard:
            return "It gets drowsy but keeps a small night-watch glow open."
        case .journalPeek:
            return "It peeks at the field journal, then nudges the next sprite request."
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .firstLook, .sleepyGuard:
            return .soothe
        case .deskPerch, .journalPeek:
            return .focus
        case .snackSniff:
            return .snack
        case .softStretch:
            return .rest
        case .sparkPatrol:
            return .adventure
        case .cheekSpark:
            return .play
        }
    }

    var vital: PetCareVital {
        switch self {
        case .firstLook, .snackSniff:
            return .snack
        case .deskPerch, .journalPeek:
            return .focus
        case .softStretch, .sleepyGuard:
            return .rest
        case .sparkPatrol, .cheekSpark:
            return .play
        }
    }

    var sparkReward: Int {
        switch self {
        case .firstLook, .deskPerch, .snackSniff, .softStretch:
            return 3
        case .sparkPatrol, .cheekSpark, .sleepyGuard, .journalPeek:
            return 4
        }
    }

    var mood: PetMood {
        switch self {
        case .firstLook:
            return .look
        case .deskPerch:
            return .perch
        case .snackSniff:
            return .snack
        case .softStretch:
            return .stretch
        case .sparkPatrol:
            return .patrol
        case .cheekSpark:
            return .spark
        case .sleepyGuard:
            return .sleepGuard
        case .journalPeek:
            return .peek
        }
    }

    var spriteRequestName: String {
        switch self {
        case .firstLook:
            return "pet-{stage}-ambient-first-look.png"
        case .deskPerch:
            return "pet-{stage}-ambient-desk-perch.png"
        case .snackSniff:
            return "pet-{stage}-ambient-snack-sniff.png"
        case .softStretch:
            return "pet-{stage}-ambient-soft-stretch.png"
        case .sparkPatrol:
            return "pet-{stage}-ambient-spark-patrol.png"
        case .cheekSpark:
            return "pet-{stage}-ambient-cheek-spark.png"
        case .sleepyGuard:
            return "pet-{stage}-ambient-sleepy-guard.png"
        case .journalPeek:
            return "pet-{stage}-ambient-journal-peek.png"
        }
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(dailyMask: Int, lowestVital: PetCareVital, hour: Int, index: Int) -> PetAmbientMoment {
        let remaining = allCases.filter { dailyMask & $0.rawValue == 0 }
        let pool = remaining.isEmpty ? allCases : remaining
        let preferred: PetAmbientMoment
        if hour >= 21 || hour < 6 {
            preferred = .sleepyGuard
        } else {
            switch lowestVital {
            case .snack:
                preferred = .snackSniff
            case .rest:
                preferred = .softStretch
            case .play:
                preferred = .sparkPatrol
            case .focus:
                preferred = .deskPerch
            }
        }
        if pool.contains(preferred) {
            return preferred
        }
        return pool[index % pool.count]
    }

    static func summary(dailyMask: Int, albumMask: Int, latest: PetAmbientMoment?) -> String {
        let today = count(mask: dailyMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "waiting for a tiny idle moment"
        return "Ambient Life \(today) today · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetFieldNote: Int, CaseIterable {
    case deskScout = 1
    case snackMap = 2
    case focusWeather = 4
    case lessonEcho = 8
    case questTrace = 16
    case sparkForecast = 32
    case restSignal = 64
    case upgradeSketch = 128
    case comebackTrace = 256
    case bondReceipt = 512
    case guardianLog = 1024
    case artRequest = 2048

    var title: String {
        switch self {
        case .deskScout:
            return "Desk Scout"
        case .snackMap:
            return "Snack Map"
        case .focusWeather:
            return "Focus Weather"
        case .lessonEcho:
            return "Lesson Echo"
        case .questTrace:
            return "Quest Trace"
        case .sparkForecast:
            return "Spark Forecast"
        case .restSignal:
            return "Rest Signal"
        case .upgradeSketch:
            return "Upgrade Sketch"
        case .comebackTrace:
            return "Comeback Trace"
        case .bondReceipt:
            return "Bond Receipt"
        case .guardianLog:
            return "Guardian Log"
        case .artRequest:
            return "Art Request"
        }
    }

    var shortLabel: String {
        switch self {
        case .deskScout:
            return "Desk"
        case .snackMap:
            return "Snack"
        case .focusWeather:
            return "Focus"
        case .lessonEcho:
            return "Echo"
        case .questTrace:
            return "Quest"
        case .sparkForecast:
            return "Spark"
        case .restSignal:
            return "Rest"
        case .upgradeSketch:
            return "Sketch"
        case .comebackTrace:
            return "Back"
        case .bondReceipt:
            return "Bond"
        case .guardianLog:
            return "Guard"
        case .artRequest:
            return "Art"
        }
    }

    var action: String {
        switch self {
        case .deskScout:
            return "Save desk note"
        case .snackMap:
            return "Save snack map"
        case .focusWeather:
            return "Save focus weather"
        case .lessonEcho:
            return "Save lesson echo"
        case .questTrace:
            return "Save quest trace"
        case .sparkForecast:
            return "Save forecast"
        case .restSignal:
            return "Save rest signal"
        case .upgradeSketch:
            return "Save sketch"
        case .comebackTrace:
            return "Save comeback"
        case .bondReceipt:
            return "Save receipt"
        case .guardianLog:
            return "Save night log"
        case .artRequest:
            return "Save art brief"
        }
    }

    var fieldLine: String {
        switch self {
        case .deskScout:
            return "It checked the edge of the screen and marked one safe place to begin."
        case .snackMap:
            return "It found the snack signal before Joy dipped too far."
        case .focusWeather:
            return "It noticed the desk is quiet enough for one clean minute."
        case .lessonEcho:
            return "It kept one phrase echo warm for the next practice."
        case .questTrace:
            return "It traced the quest path and left a tiny marker near the next choice."
        case .sparkForecast:
            return "It counted the stored Sparks and spotted a bright return window."
        case .restSignal:
            return "It saw the loop getting heavy and made rest count as progress."
        case .upgradeSketch:
            return "It sketched the next upgrade card before the Sparks scatter."
        case .comebackTrace:
            return "It saved the path back so returning feels like a story beat."
        case .bondReceipt:
            return "It turned a small care action into proof the bond is growing."
        case .guardianLog:
            return "It watched the late hours and kept the check-in calm."
        case .artRequest:
            return "It opened the sprite journal and circled the next missing animation."
        }
    }

    func body(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        "\(stage.shortLabel) note: \(fieldLine) Current mood: \(feeling.title.lowercased())."
    }

    var vital: PetCareVital {
        switch self {
        case .snackMap, .bondReceipt:
            return .snack
        case .restSignal, .comebackTrace, .guardianLog:
            return .rest
        case .questTrace, .sparkForecast:
            return .play
        case .deskScout, .focusWeather, .lessonEcho, .upgradeSketch, .artRequest:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .deskScout, .focusWeather, .upgradeSketch, .artRequest:
            return .focus
        case .snackMap, .bondReceipt:
            return .snack
        case .lessonEcho:
            return .study
        case .questTrace:
            return .adventure
        case .sparkForecast:
            return .play
        case .restSignal, .guardianLog:
            return .rest
        case .comebackTrace:
            return .soothe
        }
    }

    var mood: PetMood {
        switch self {
        case .deskScout, .focusWeather:
            return .perch
        case .snackMap:
            return .snack
        case .lessonEcho, .artRequest:
            return .peek
        case .questTrace, .sparkForecast:
            return .patrol
        case .restSignal:
            return .stretch
        case .upgradeSketch:
            return .thinking
        case .comebackTrace, .bondReceipt:
            return .happy
        case .guardianLog:
            return .sleepGuard
        }
    }

    var sparkReward: Int {
        switch self {
        case .deskScout, .snackMap, .focusWeather, .restSignal:
            return 5
        case .lessonEcho, .questTrace, .sparkForecast, .comebackTrace:
            return 7
        case .upgradeSketch, .bondReceipt, .guardianLog, .artRequest:
            return 9
        }
    }

    var spriteSlug: String {
        switch self {
        case .deskScout:
            return "desk-scout"
        case .snackMap:
            return "snack-map"
        case .focusWeather:
            return "focus-weather"
        case .lessonEcho:
            return "lesson-echo"
        case .questTrace:
            return "quest-trace"
        case .sparkForecast:
            return "spark-forecast"
        case .restSignal:
            return "rest-signal"
        case .upgradeSketch:
            return "upgrade-sketch"
        case .comebackTrace:
            return "comeback-trace"
        case .bondReceipt:
            return "bond-receipt"
        case .guardianLog:
            return "guardian-log"
        case .artRequest:
            return "art-request"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-field-note-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        daypart: PetDaypartNudge,
        feeling: PetFeeling,
        stage: PetGrowthStage,
        offeredMask: Int,
        index: Int
    ) -> PetFieldNote? {
        let remaining = allCases.filter { offeredMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }

        let preferred: PetFieldNote
        if daypart == .night {
            preferred = .guardianLog
        } else {
            switch feeling {
            case .hungry:
                preferred = .snackMap
            case .sleepy, .protective:
                preferred = .restSignal
            case .focused:
                preferred = .focusWeather
            case .overcharged, .playful:
                preferred = .sparkForecast
            case .proud, .celebrating:
                preferred = .bondReceipt
            case .restless, .determined:
                preferred = .upgradeSketch
            case .lonely, .comfort, .grateful:
                preferred = .comebackTrace
            case .curious:
                preferred = .artRequest
            case .bright, .eager:
                switch stage {
                case .tinySpark, .pocketPal:
                    preferred = .deskScout
                case .trailBuddy:
                    preferred = .questTrace
                case .stormScout, .stormGuardian:
                    preferred = .lessonEcho
                }
            }
        }

        if remaining.contains(preferred) {
            return preferred
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        offeredMask: Int,
        savedMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        latest: PetFieldNote?
    ) -> String {
        let offered = count(mask: offeredMask)
        let saved = count(mask: savedMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "waiting for a field note"
        return "Field Notes \(saved)/\(allCases.count) saved · \(offered) found · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetScoutTrip: Int, CaseIterable {
    case deskEdge = 1
    case sparkTrail = 2
    case phraseGrove = 4
    case questMarker = 8
    case snackNook = 16
    case restCove = 32
    case upgradeForge = 64
    case moodMeadow = 128
    case comebackPath = 256
    case nightWatch = 512

    var title: String {
        switch self {
        case .deskEdge:
            return "Desk Edge"
        case .sparkTrail:
            return "Spark Trail"
        case .phraseGrove:
            return "Phrase Grove"
        case .questMarker:
            return "Quest Marker"
        case .snackNook:
            return "Snack Nook"
        case .restCove:
            return "Rest Cove"
        case .upgradeForge:
            return "Upgrade Forge"
        case .moodMeadow:
            return "Mood Meadow"
        case .comebackPath:
            return "Comeback Path"
        case .nightWatch:
            return "Night Watch"
        }
    }

    var shortLabel: String {
        switch self {
        case .deskEdge:
            return "Desk"
        case .sparkTrail:
            return "Trail"
        case .phraseGrove:
            return "Phrase"
        case .questMarker:
            return "Quest"
        case .snackNook:
            return "Snack"
        case .restCove:
            return "Rest"
        case .upgradeForge:
            return "Forge"
        case .moodMeadow:
            return "Mood"
        case .comebackPath:
            return "Back"
        case .nightWatch:
            return "Night"
        }
    }

    var startLine: String {
        switch self {
        case .deskEdge:
            return "It pads to the edge of the desktop to find one safe starting point."
        case .sparkTrail:
            return "It follows stored Sparks to see which loop wants attention next."
        case .phraseGrove:
            return "It carries one language spark into a quiet practice grove."
        case .questMarker:
            return "It scouts ahead and looks for the next adventure marker."
        case .snackNook:
            return "It checks the tiny snack cache and promises not to nag."
        case .restCove:
            return "It walks to a soft cove where rest can become progress."
        case .upgradeForge:
            return "It takes a card sketch to the forge and studies the next upgrade."
        case .moodMeadow:
            return "It explores a mood meadow to name what the day feels like."
        case .comebackPath:
            return "It follows the path back so returning feels warm next time."
        case .nightWatch:
            return "It circles the night edge and keeps the signal gentle."
        }
    }

    func returnLine(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .deskEdge:
            return "\(stage.shortLabel) found a small start point and marked it with \(feeling.title.lowercased()) sparks."
        case .sparkTrail:
            return "\(stage.shortLabel) came back with a bright trail and one stored Spark receipt."
        case .phraseGrove:
            return "\(stage.shortLabel) brought a phrase echo back for the next lesson."
        case .questMarker:
            return "\(stage.shortLabel) placed a tiny marker near the next quest choice."
        case .snackNook:
            return "\(stage.shortLabel) found a snack nook and refilled the care map."
        case .restCove:
            return "\(stage.shortLabel) brought back proof that rest can count."
        case .upgradeForge:
            return "\(stage.shortLabel) returned with a warmer sketch of the next card."
        case .moodMeadow:
            return "\(stage.shortLabel) brought back a mood petal labelled \(feeling.title.lowercased())."
        case .comebackPath:
            return "\(stage.shortLabel) traced a no-guilt route back to the desk."
        case .nightWatch:
            return "\(stage.shortLabel) completed a quiet watch and lowered the urgency."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .snackNook:
            return .snack
        case .restCove, .comebackPath, .nightWatch:
            return .rest
        case .sparkTrail, .questMarker, .moodMeadow:
            return .play
        case .deskEdge, .phraseGrove, .upgradeForge:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .deskEdge, .sparkTrail:
            return .focus
        case .phraseGrove:
            return .study
        case .questMarker:
            return .adventure
        case .snackNook:
            return .snack
        case .restCove, .nightWatch:
            return .rest
        case .upgradeForge:
            return .focus
        case .moodMeadow:
            return .cheer
        case .comebackPath:
            return .soothe
        }
    }

    var mood: PetMood {
        switch self {
        case .deskEdge, .phraseGrove, .upgradeForge:
            return .perch
        case .sparkTrail, .questMarker:
            return .patrol
        case .snackNook:
            return .snack
        case .restCove:
            return .stretch
        case .moodMeadow:
            return .look
        case .comebackPath:
            return .happy
        case .nightWatch:
            return .sleepGuard
        }
    }

    var sparkReward: Int {
        switch self {
        case .deskEdge, .snackNook, .restCove:
            return 8
        case .sparkTrail, .phraseGrove, .questMarker, .moodMeadow:
            return 10
        case .upgradeForge, .comebackPath, .nightWatch:
            return 12
        }
    }

    var spriteSlug: String {
        switch self {
        case .deskEdge:
            return "desk-edge"
        case .sparkTrail:
            return "spark-trail"
        case .phraseGrove:
            return "phrase-grove"
        case .questMarker:
            return "quest-marker"
        case .snackNook:
            return "snack-nook"
        case .restCove:
            return "rest-cove"
        case .upgradeForge:
            return "upgrade-forge"
        case .moodMeadow:
            return "mood-meadow"
        case .comebackPath:
            return "comeback-path"
        case .nightWatch:
            return "night-watch"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-scout-trip-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        daypart: PetDaypartNudge,
        feeling: PetFeeling,
        stage: PetGrowthStage,
        startedMask: Int,
        index: Int
    ) -> PetScoutTrip? {
        let remaining = allCases.filter { startedMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }

        let preferred: PetScoutTrip
        if daypart == .night {
            preferred = .nightWatch
        } else {
            switch feeling {
            case .hungry:
                preferred = .snackNook
            case .sleepy, .protective:
                preferred = .restCove
            case .focused:
                preferred = .deskEdge
            case .overcharged, .playful:
                preferred = .sparkTrail
            case .proud, .celebrating:
                preferred = .questMarker
            case .restless, .determined:
                preferred = .upgradeForge
            case .lonely, .comfort, .grateful:
                preferred = .comebackPath
            case .curious:
                preferred = .moodMeadow
            case .bright, .eager:
                switch stage {
                case .tinySpark, .pocketPal:
                    preferred = .deskEdge
                case .trailBuddy:
                    preferred = .questMarker
                case .stormScout, .stormGuardian:
                    preferred = .phraseGrove
                }
            }
        }

        if remaining.contains(preferred) {
            return preferred
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        startedMask: Int,
        returnedMask: Int,
        albumMask: Int,
        active: PetScoutTrip?,
        remainingSeconds: Int?,
        latest: PetScoutTrip?
    ) -> String {
        let started = count(mask: startedMask)
        let returned = count(mask: returnedMask)
        let album = count(mask: albumMask)
        if let active {
            let remaining = remainingSeconds ?? 0
            let status = remaining > 0 ? "\(remaining)s left" : "ready to collect"
            return "Scout Trips \(returned)/\(allCases.count) returned · \(started) started · \(active.title) \(status) · Album \(album)/\(allCases.count)"
        }
        let latestText = latest.map { "Latest \($0.title)" } ?? "ready to scout"
        return "Scout Trips \(returned)/\(allCases.count) returned · \(started) started · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetWish: Int, CaseIterable {
    case helloPat = 1
    case phraseRepeat = 2
    case tinyQuest = 4
    case snackShare = 8
    case restNest = 16
    case hyperLap = 32
    case focusPerch = 64
    case cipherPeek = 128
    case upgradeDream = 256
    case fieldSketch = 512
    case scoutWave = 1024
    case nightThanks = 2048

    var title: String {
        switch self {
        case .helloPat:
            return "Hello Pat"
        case .phraseRepeat:
            return "Phrase Repeat"
        case .tinyQuest:
            return "Tiny Quest"
        case .snackShare:
            return "Snack Share"
        case .restNest:
            return "Rest Nest"
        case .hyperLap:
            return "Hyper Lap"
        case .focusPerch:
            return "Focus Perch"
        case .cipherPeek:
            return "Cipher Peek"
        case .upgradeDream:
            return "Upgrade Dream"
        case .fieldSketch:
            return "Field Sketch"
        case .scoutWave:
            return "Scout Wave"
        case .nightThanks:
            return "Night Thanks"
        }
    }

    var shortLabel: String {
        switch self {
        case .helloPat:
            return "Pat"
        case .phraseRepeat:
            return "Phrase"
        case .tinyQuest:
            return "Quest"
        case .snackShare:
            return "Snack"
        case .restNest:
            return "Nest"
        case .hyperLap:
            return "Lap"
        case .focusPerch:
            return "Perch"
        case .cipherPeek:
            return "Cipher"
        case .upgradeDream:
            return "Dream"
        case .fieldSketch:
            return "Sketch"
        case .scoutWave:
            return "Wave"
        case .nightThanks:
            return "Night"
        }
    }

    var action: String {
        switch self {
        case .helloPat:
            return "Give a pat"
        case .phraseRepeat:
            return "Practice phrase"
        case .tinyQuest:
            return "Open quest"
        case .snackShare:
            return "Share snack"
        case .restNest:
            return "Rest together"
        case .hyperLap:
            return "Run a lap"
        case .focusPerch:
            return "Focus perch"
        case .cipherPeek:
            return "Peek cipher"
        case .upgradeDream:
            return "Study upgrade"
        case .fieldSketch:
            return "Save sketch"
        case .scoutWave:
            return "Wave scout"
        case .nightThanks:
            return "Say thanks"
        }
    }

    var wishLine: String {
        switch self {
        case .helloPat:
            return "It wants one clear hello before the day gets loud."
        case .phraseRepeat:
            return "It wants to hear one phrase and bounce the sound back."
        case .tinyQuest:
            return "It wants to peek at a quest marker without sprinting."
        case .snackShare:
            return "It wants a tiny snack ritual so Joy does not dip."
        case .restNest:
            return "It wants a soft rest moment that still counts as care."
        case .hyperLap:
            return "It wants to burn extra sparks in one bright lap."
        case .focusPerch:
            return "It wants to perch beside the first focused minute."
        case .cipherPeek:
            return "It wants to peek at the cipher like a shiny puzzle toy."
        case .upgradeDream:
            return "It wants to dream over the next upgrade card."
        case .fieldSketch:
            return "It wants to sketch one found-object note for the album."
        case .scoutWave:
            return "It wants to wave at the scout path before it goes quiet."
        case .nightThanks:
            return "It wants to say a small thank-you before night watch."
        }
    }

    func body(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        "\(stage.shortLabel) wish: \(wishLine) Mood: \(feeling.title.lowercased())."
    }

    var vital: PetCareVital {
        switch self {
        case .helloPat, .snackShare:
            return .snack
        case .restNest, .nightThanks:
            return .rest
        case .tinyQuest, .hyperLap, .scoutWave:
            return .play
        case .phraseRepeat, .focusPerch, .cipherPeek, .upgradeDream, .fieldSketch:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .helloPat, .nightThanks:
            return .soothe
        case .phraseRepeat:
            return .study
        case .tinyQuest, .scoutWave:
            return .adventure
        case .snackShare:
            return .snack
        case .restNest:
            return .rest
        case .hyperLap:
            return .play
        case .focusPerch, .upgradeDream, .fieldSketch:
            return .focus
        case .cipherPeek:
            return .puzzle
        }
    }

    var mood: PetMood {
        switch self {
        case .helloPat, .nightThanks:
            return .happy
        case .phraseRepeat, .fieldSketch:
            return .peek
        case .tinyQuest, .scoutWave:
            return .patrol
        case .snackShare:
            return .snack
        case .restNest:
            return .stretch
        case .hyperLap:
            return .hyper
        case .focusPerch:
            return .perch
        case .cipherPeek, .upgradeDream:
            return .thinking
        }
    }

    var sparkReward: Int {
        switch self {
        case .helloPat, .snackShare, .restNest:
            return 6
        case .phraseRepeat, .tinyQuest, .hyperLap, .focusPerch, .cipherPeek:
            return 8
        case .upgradeDream, .fieldSketch, .scoutWave, .nightThanks:
            return 10
        }
    }

    var spriteSlug: String {
        switch self {
        case .helloPat:
            return "hello-pat"
        case .phraseRepeat:
            return "phrase-repeat"
        case .tinyQuest:
            return "tiny-quest"
        case .snackShare:
            return "snack-share"
        case .restNest:
            return "rest-nest"
        case .hyperLap:
            return "hyper-lap"
        case .focusPerch:
            return "focus-perch"
        case .cipherPeek:
            return "cipher-peek"
        case .upgradeDream:
            return "upgrade-dream"
        case .fieldSketch:
            return "field-sketch"
        case .scoutWave:
            return "scout-wave"
        case .nightThanks:
            return "night-thanks"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-wish-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        daypart: PetDaypartNudge,
        feeling: PetFeeling,
        careNeed: PetCareNeed,
        stage: PetGrowthStage,
        offeredMask: Int,
        index: Int
    ) -> PetWish? {
        let remaining = allCases.filter { offeredMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }

        let preferred: PetWish
        if daypart == .night {
            preferred = .nightThanks
        } else {
            switch feeling {
            case .hungry:
                preferred = .snackShare
            case .sleepy, .protective:
                preferred = .restNest
            case .focused:
                preferred = .focusPerch
            case .overcharged, .playful:
                preferred = .hyperLap
            case .curious:
                preferred = .fieldSketch
            case .restless, .determined:
                preferred = .upgradeDream
            case .proud, .celebrating:
                preferred = .scoutWave
            case .lonely, .comfort, .grateful:
                preferred = .helloPat
            case .bright, .eager:
                switch careNeed {
                case .affection:
                    preferred = .helloPat
                case .study:
                    preferred = .phraseRepeat
                case .adventure:
                    preferred = stage == .tinySpark ? .tinyQuest : .scoutWave
                case .rest:
                    preferred = .restNest
                case .play:
                    preferred = .hyperLap
                case .focus:
                    preferred = .focusPerch
                case .puzzle:
                    preferred = .cipherPeek
                }
            }
        }

        if remaining.contains(preferred) {
            return preferred
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        offeredMask: Int,
        fulfilledMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        latest: PetWish?
    ) -> String {
        let offered = count(mask: offeredMask)
        let fulfilled = count(mask: fulfilledMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "waiting for today's wish"
        return "Wishbook \(fulfilled)/\(allCases.count) fulfilled · \(offered) heard · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetAffectionGesture: Int, CaseIterable {
    case headPat = 1
    case cheekRub = 2
    case sparkBrush = 4
    case tailPolish = 8
    case snackBoop = 16
    case focusPerchPet = 32
    case sleepTuck = 64
    case victoryCuddle = 128

    var title: String {
        switch self {
        case .headPat:
            return "Head Pat"
        case .cheekRub:
            return "Cheek Rub"
        case .sparkBrush:
            return "Spark Brush"
        case .tailPolish:
            return "Tail Polish"
        case .snackBoop:
            return "Snack Boop"
        case .focusPerchPet:
            return "Focus Perch Pet"
        case .sleepTuck:
            return "Sleep Tuck"
        case .victoryCuddle:
            return "Victory Cuddle"
        }
    }

    var shortLabel: String {
        switch self {
        case .headPat:
            return "Pat"
        case .cheekRub:
            return "Rub"
        case .sparkBrush:
            return "Brush"
        case .tailPolish:
            return "Tail"
        case .snackBoop:
            return "Boop"
        case .focusPerchPet:
            return "Perch"
        case .sleepTuck:
            return "Tuck"
        case .victoryCuddle:
            return "Cuddle"
        }
    }

    var action: String {
        switch self {
        case .headPat:
            return "Pat head"
        case .cheekRub:
            return "Rub cheeks"
        case .sparkBrush:
            return "Brush sparks"
        case .tailPolish:
            return "Polish tail"
        case .snackBoop:
            return "Boop snack"
        case .focusPerchPet:
            return "Pet perch"
        case .sleepTuck:
            return "Tuck in"
        case .victoryCuddle:
            return "Cuddle"
        }
    }

    func careLine(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .headPat:
            return "\(stage.shortLabel) lowers its head, waits for the pat, then looks back up with \(feeling.title.lowercased()) eyes."
        case .cheekRub:
            return "\(stage.shortLabel) leans one cheek into the rub and lets a small warm spark settle."
        case .sparkBrush:
            return "\(stage.shortLabel) shakes off extra sparks while the brush turns hyper energy into calm glow."
        case .tailPolish:
            return "\(stage.shortLabel) holds still while the tail shine becomes a tiny confidence ritual."
        case .snackBoop:
            return "\(stage.shortLabel) touches the snack with both paws, boops it once, and brightens."
        case .focusPerchPet:
            return "\(stage.shortLabel) perches beside the first minute and accepts one careful focus pet."
        case .sleepTuck:
            return "\(stage.shortLabel) curls down as the tuck makes the desk feel safe for rest."
        case .victoryCuddle:
            return "\(stage.shortLabel) celebrates a completed loop with a proud little cuddle."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .snackBoop:
            return .snack
        case .sleepTuck:
            return .rest
        case .sparkBrush, .tailPolish, .victoryCuddle:
            return .play
        case .headPat, .cheekRub, .focusPerchPet:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .headPat, .cheekRub:
            return .soothe
        case .sparkBrush, .tailPolish, .victoryCuddle:
            return .play
        case .snackBoop:
            return .snack
        case .focusPerchPet:
            return .focus
        case .sleepTuck:
            return .rest
        }
    }

    var mood: PetMood {
        switch self {
        case .headPat, .cheekRub, .victoryCuddle:
            return .happy
        case .sparkBrush, .tailPolish:
            return .hyper
        case .snackBoop:
            return .snack
        case .focusPerchPet:
            return .perch
        case .sleepTuck:
            return .sleepGuard
        }
    }

    var sparkReward: Int {
        switch self {
        case .headPat, .cheekRub, .snackBoop, .sleepTuck:
            return 7
        case .sparkBrush, .tailPolish, .focusPerchPet:
            return 9
        case .victoryCuddle:
            return 11
        }
    }

    var spriteSlug: String {
        switch self {
        case .headPat:
            return "head-pat"
        case .cheekRub:
            return "cheek-rub"
        case .sparkBrush:
            return "spark-brush"
        case .tailPolish:
            return "tail-polish"
        case .snackBoop:
            return "snack-boop"
        case .focusPerchPet:
            return "focus-perch-pet"
        case .sleepTuck:
            return "sleep-tuck"
        case .victoryCuddle:
            return "victory-cuddle"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-affection-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        daypart: PetDaypartNudge,
        feeling: PetFeeling,
        careNeed: PetCareNeed,
        stage: PetGrowthStage,
        offeredMask: Int,
        givenMask: Int,
        index: Int
    ) -> PetAffectionGesture? {
        let unavailable = offeredMask | givenMask
        let remaining = allCases.filter { unavailable & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }

        let preferred: PetAffectionGesture
        if daypart == .night {
            preferred = .sleepTuck
        } else {
            switch feeling {
            case .hungry:
                preferred = .snackBoop
            case .sleepy, .protective:
                preferred = .sleepTuck
            case .focused:
                preferred = .focusPerchPet
            case .overcharged, .playful, .restless:
                preferred = .sparkBrush
            case .curious, .determined:
                preferred = .tailPolish
            case .proud, .celebrating, .grateful:
                preferred = .victoryCuddle
            case .lonely, .comfort:
                preferred = .cheekRub
            case .bright, .eager:
                switch careNeed {
                case .affection:
                    preferred = .headPat
                case .study, .focus:
                    preferred = .focusPerchPet
                case .adventure, .puzzle:
                    preferred = stage == .tinySpark ? .headPat : .tailPolish
                case .rest:
                    preferred = .sleepTuck
                case .play:
                    preferred = .sparkBrush
                }
            }
        }

        if remaining.contains(preferred) {
            return preferred
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        offeredMask: Int,
        givenMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        latest: PetAffectionGesture?
    ) -> String {
        let offered = count(mask: offeredMask)
        let given = count(mask: givenMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "waiting for touch"
        return "Bond \(given)/\(allCases.count) gestures · \(offered) asked · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetHomeRoom: Int, CaseIterable {
    case cozyNest = 1
    case snackNook = 2
    case studyPerch = 4
    case questLookout = 8
    case sparkGym = 16
    case moonDen = 32
    case cipherCave = 64
    case celebrationPorch = 128

    var title: String {
        switch self {
        case .cozyNest:
            return "Cozy Nest"
        case .snackNook:
            return "Snack Nook"
        case .studyPerch:
            return "Study Perch"
        case .questLookout:
            return "Quest Lookout"
        case .sparkGym:
            return "Spark Gym"
        case .moonDen:
            return "Moon Den"
        case .cipherCave:
            return "Cipher Cave"
        case .celebrationPorch:
            return "Celebration Porch"
        }
    }

    var shortLabel: String {
        switch self {
        case .cozyNest:
            return "Nest"
        case .snackNook:
            return "Snack"
        case .studyPerch:
            return "Study"
        case .questLookout:
            return "Quest"
        case .sparkGym:
            return "Gym"
        case .moonDen:
            return "Moon"
        case .cipherCave:
            return "Cipher"
        case .celebrationPorch:
            return "Porch"
        }
    }

    var action: String {
        switch self {
        case .cozyNest:
            return "Visit nest"
        case .snackNook:
            return "Check snacks"
        case .studyPerch:
            return "Perch study"
        case .questLookout:
            return "Scan quest"
        case .sparkGym:
            return "Run sparks"
        case .moonDen:
            return "Guard moon"
        case .cipherCave:
            return "Check cipher"
        case .celebrationPorch:
            return "Celebrate"
        }
    }

    func visitLine(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .cozyNest:
            return "\(stage.shortLabel) circles the nest twice, settles the blanket, and checks if the home still smells safe."
        case .snackNook:
            return "\(stage.shortLabel) noses through the snack nook and stores one tiny treat for later."
        case .studyPerch:
            return "\(stage.shortLabel) climbs to the study perch and watches the first useful minute."
        case .questLookout:
            return "\(stage.shortLabel) peers from the lookout and marks one gentle quest direction."
        case .sparkGym:
            return "\(stage.shortLabel) runs a small spark loop so \(feeling.title.lowercased()) energy has somewhere to go."
        case .moonDen:
            return "\(stage.shortLabel) checks the moon den, lowers the room noise, and guards the streak."
        case .cipherCave:
            return "\(stage.shortLabel) taps the cipher wall until one clue glow wakes up."
        case .celebrationPorch:
            return "\(stage.shortLabel) hops onto the porch and saves the day's tiny win."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .snackNook:
            return .snack
        case .cozyNest, .moonDen:
            return .rest
        case .questLookout, .sparkGym, .celebrationPorch:
            return .play
        case .studyPerch, .cipherCave:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .cozyNest, .moonDen:
            return .rest
        case .snackNook:
            return .snack
        case .studyPerch:
            return .focus
        case .questLookout:
            return .adventure
        case .sparkGym, .celebrationPorch:
            return .play
        case .cipherCave:
            return .puzzle
        }
    }

    var mood: PetMood {
        switch self {
        case .cozyNest:
            return .stretch
        case .snackNook:
            return .snack
        case .studyPerch:
            return .perch
        case .questLookout:
            return .patrol
        case .sparkGym, .celebrationPorch:
            return .hyper
        case .moonDen:
            return .sleepGuard
        case .cipherCave:
            return .thinking
        }
    }

    var sparkReward: Int {
        switch self {
        case .cozyNest, .snackNook:
            return 8
        case .studyPerch, .questLookout, .sparkGym:
            return 10
        case .moonDen, .cipherCave, .celebrationPorch:
            return 12
        }
    }

    var spriteSlug: String {
        switch self {
        case .cozyNest:
            return "cozy-nest"
        case .snackNook:
            return "snack-nook"
        case .studyPerch:
            return "study-perch"
        case .questLookout:
            return "quest-lookout"
        case .sparkGym:
            return "spark-gym"
        case .moonDen:
            return "moon-den"
        case .cipherCave:
            return "cipher-cave"
        case .celebrationPorch:
            return "celebration-porch"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-home-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        hour: Int,
        feeling: PetFeeling,
        careNeed: PetCareNeed,
        offeredMask: Int,
        visitedMask: Int,
        index: Int
    ) -> PetHomeRoom? {
        let unavailable = offeredMask | visitedMask
        let remaining = allCases.filter { unavailable & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }

        let preferred: PetHomeRoom
        if hour >= 21 || hour < 6 {
            preferred = .moonDen
        } else {
            switch feeling {
            case .hungry:
                preferred = .snackNook
            case .sleepy, .protective, .comfort:
                preferred = .cozyNest
            case .focused:
                preferred = .studyPerch
            case .curious:
                preferred = .cipherCave
            case .overcharged, .playful, .restless:
                preferred = .sparkGym
            case .proud, .celebrating, .grateful:
                preferred = .celebrationPorch
            case .determined:
                preferred = .questLookout
            case .lonely:
                preferred = .cozyNest
            case .bright, .eager:
                switch careNeed {
                case .affection, .rest:
                    preferred = .cozyNest
                case .study, .focus:
                    preferred = .studyPerch
                case .adventure:
                    preferred = .questLookout
                case .play:
                    preferred = .sparkGym
                case .puzzle:
                    preferred = .cipherCave
                }
            }
        }

        if remaining.contains(preferred) {
            return preferred
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        offeredMask: Int,
        visitedMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        latest: PetHomeRoom?
    ) -> String {
        let offered = count(mask: offeredMask)
        let visited = count(mask: visitedMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "home waiting"
        return "Home \(visited)/\(allCases.count) rooms · \(offered) offered · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetDailyErrand: Int, CaseIterable {
    case sparkGather = 1
    case snackFetch = 2
    case phraseCourier = 4
    case mapScout = 8
    case focusGuard = 16
    case charmSort = 32
    case moonWatch = 64
    case cheerCourier = 128

    var title: String {
        switch self {
        case .sparkGather:
            return "Spark Gather"
        case .snackFetch:
            return "Snack Fetch"
        case .phraseCourier:
            return "Phrase Courier"
        case .mapScout:
            return "Map Scout"
        case .focusGuard:
            return "Focus Guard"
        case .charmSort:
            return "Charm Sort"
        case .moonWatch:
            return "Moon Watch"
        case .cheerCourier:
            return "Cheer Courier"
        }
    }

    var shortLabel: String {
        switch self {
        case .sparkGather:
            return "Spark"
        case .snackFetch:
            return "Snack"
        case .phraseCourier:
            return "Phrase"
        case .mapScout:
            return "Map"
        case .focusGuard:
            return "Guard"
        case .charmSort:
            return "Charms"
        case .moonWatch:
            return "Moon"
        case .cheerCourier:
            return "Cheer"
        }
    }

    var action: String {
        switch self {
        case .sparkGather:
            return "Gather sparks"
        case .snackFetch:
            return "Fetch snack"
        case .phraseCourier:
            return "Carry phrase"
        case .mapScout:
            return "Scout map"
        case .focusGuard:
            return "Guard focus"
        case .charmSort:
            return "Sort charms"
        case .moonWatch:
            return "Watch moon"
        case .cheerCourier:
            return "Carry cheer"
        }
    }

    func runLine(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .sparkGather:
            return "\(stage.shortLabel) gathers loose desk sparks and tucks them into a safer glow."
        case .snackFetch:
            return "\(stage.shortLabel) finds a tiny snack spark and saves it for low-energy moments."
        case .phraseCourier:
            return "\(stage.shortLabel) carries one phrase card, repeats it softly, and returns proud."
        case .mapScout:
            return "\(stage.shortLabel) checks the next trail marker and brings back a calmer route."
        case .focusGuard:
            return "\(stage.shortLabel) stands guard beside one useful minute while \(feeling.title.lowercased()) energy settles."
        case .charmSort:
            return "\(stage.shortLabel) sorts memory charms so the bond album feels easier to read."
        case .moonWatch:
            return "\(stage.shortLabel) does a soft night watch and lowers the room noise."
        case .cheerCourier:
            return "\(stage.shortLabel) carries a small cheer note and waits for the user to come back."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .sparkGather, .mapScout, .cheerCourier:
            return .play
        case .snackFetch:
            return .snack
        case .phraseCourier, .focusGuard, .charmSort:
            return .focus
        case .moonWatch:
            return .rest
        }
    }

    var careNeed: PetCareNeed {
        switch self {
        case .sparkGather, .cheerCourier:
            return .play
        case .snackFetch:
            return .affection
        case .phraseCourier:
            return .study
        case .mapScout:
            return .adventure
        case .focusGuard, .charmSort:
            return .focus
        case .moonWatch:
            return .rest
        }
    }

    var dailyQuest: PetDailyQuest {
        switch self {
        case .sparkGather, .cheerCourier:
            return .cheer
        case .snackFetch:
            return .care
        case .phraseCourier:
            return .learn
        case .mapScout:
            return .adventure
        case .focusGuard, .charmSort:
            return .hint
        case .moonWatch:
            return .care
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .sparkGather, .cheerCourier:
            return .play
        case .snackFetch:
            return .snack
        case .phraseCourier:
            return .study
        case .mapScout:
            return .adventure
        case .focusGuard, .charmSort:
            return .focus
        case .moonWatch:
            return .rest
        }
    }

    var mood: PetMood {
        switch self {
        case .sparkGather, .cheerCourier:
            return .hyper
        case .snackFetch:
            return .snack
        case .phraseCourier, .focusGuard:
            return .perch
        case .mapScout:
            return .patrol
        case .charmSort:
            return .peek
        case .moonWatch:
            return .sleepGuard
        }
    }

    var sparkReward: Int {
        switch self {
        case .sparkGather, .snackFetch:
            return 9
        case .phraseCourier, .mapScout, .focusGuard:
            return 11
        case .charmSort, .moonWatch, .cheerCourier:
            return 13
        }
    }

    var spriteSlug: String {
        switch self {
        case .sparkGather:
            return "spark-gather"
        case .snackFetch:
            return "snack-fetch"
        case .phraseCourier:
            return "phrase-courier"
        case .mapScout:
            return "map-scout"
        case .focusGuard:
            return "focus-guard"
        case .charmSort:
            return "charm-sort"
        case .moonWatch:
            return "moon-watch"
        case .cheerCourier:
            return "cheer-courier"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-errand-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        hour: Int,
        feeling: PetFeeling,
        careNeed: PetCareNeed,
        offeredMask: Int,
        doneMask: Int,
        index: Int
    ) -> PetDailyErrand? {
        let unavailable = offeredMask | doneMask
        let remaining = allCases.filter { unavailable & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }

        let preferred: PetDailyErrand
        if hour >= 21 || hour < 6 {
            preferred = .moonWatch
        } else {
            switch feeling {
            case .hungry:
                preferred = .snackFetch
            case .sleepy, .protective, .comfort:
                preferred = .moonWatch
            case .focused:
                preferred = .focusGuard
            case .curious, .determined:
                preferred = .mapScout
            case .overcharged, .playful, .restless:
                preferred = .sparkGather
            case .proud, .celebrating, .grateful:
                preferred = .charmSort
            case .lonely:
                preferred = .cheerCourier
            case .bright, .eager:
                switch careNeed {
                case .affection:
                    preferred = .snackFetch
                case .study:
                    preferred = .phraseCourier
                case .adventure:
                    preferred = .mapScout
                case .rest:
                    preferred = .moonWatch
                case .play:
                    preferred = .sparkGather
                case .focus:
                    preferred = .focusGuard
                case .puzzle:
                    preferred = .charmSort
                }
            }
        }

        if remaining.contains(preferred) {
            return preferred
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        offeredMask: Int,
        doneMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        latest: PetDailyErrand?
    ) -> String {
        let offered = count(mask: offeredMask)
        let done = count(mask: doneMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "errand board waiting"
        return "Errands \(done)/\(allCases.count) done · \(offered) offered · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetUserCheckIn: Int, CaseIterable {
    case bright = 1
    case tired = 2
    case stuck = 4
    case overwhelmed = 8
    case lonely = 16
    case proud = 32
    case focused = 64
    case needBreak = 128

    var title: String {
        switch self {
        case .bright:
            return "Bright Check"
        case .tired:
            return "Tired Check"
        case .stuck:
            return "Stuck Check"
        case .overwhelmed:
            return "Too Much Check"
        case .lonely:
            return "Company Check"
        case .proud:
            return "Proud Check"
        case .focused:
            return "Focus Check"
        case .needBreak:
            return "Break Check"
        }
    }

    var shortLabel: String {
        switch self {
        case .bright:
            return "Bright"
        case .tired:
            return "Tired"
        case .stuck:
            return "Stuck"
        case .overwhelmed:
            return "Full"
        case .lonely:
            return "Company"
        case .proud:
            return "Proud"
        case .focused:
            return "Focus"
        case .needBreak:
            return "Break"
        }
    }

    var action: String {
        switch self {
        case .bright:
            return "Save bright"
        case .tired:
            return "Save tired"
        case .stuck:
            return "Save stuck"
        case .overwhelmed:
            return "Save too much"
        case .lonely:
            return "Save company"
        case .proud:
            return "Save proud"
        case .focused:
            return "Save focus"
        case .needBreak:
            return "Save break"
        }
    }

    func body(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .bright:
            return "How are you doing? \(stage.shortLabel) sees a bright spark and wants to save it before the day runs past."
        case .tired:
            return "How are you doing? If you are tired, \(stage.shortLabel) can lower the noise and guard one softer step."
        case .stuck:
            return "What is happening? \(stage.shortLabel) tilts its head at the stuck point and waits beside the first small clue."
        case .overwhelmed:
            return "How are you doing? If everything feels too much, \(stage.shortLabel) can shrink this to one breath and one next tap."
        case .lonely:
            return "How are you doing? \(stage.shortLabel) steps closer and keeps tiny company instead of asking you to explain everything."
        case .proud:
            return "How are you doing? \(stage.shortLabel) noticed a proud signal in your \(feeling.title.lowercased()) rhythm and wants to mark it."
        case .focused:
            return "What is happening? \(stage.shortLabel) can sit beside one focus minute and keep the next task warm."
        case .needBreak:
            return "How are you doing? \(stage.shortLabel) sees the sparks running fast and asks for a tiny break before the next push."
        }
    }

    var supportLine: String {
        switch self {
        case .bright:
            return "The bright check goes into the trail as proof the day started with a spark."
        case .tired:
            return "The tired check tells the pet to protect rest before pushing."
        case .stuck:
            return "The stuck check turns the block into a smaller clue instead of a failure."
        case .overwhelmed:
            return "The too-much check trims the next loop down to one safe step."
        case .lonely:
            return "The company check teaches the pet to stay close for a while."
        case .proud:
            return "The proud check stores the win so it can be celebrated later."
        case .focused:
            return "The focus check parks the pet beside the next useful minute."
        case .needBreak:
            return "The break check spends a spark on softness before momentum burns out."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .bright, .proud:
            return .play
        case .tired, .overwhelmed, .needBreak:
            return .rest
        case .stuck, .focused:
            return .focus
        case .lonely:
            return .snack
        }
    }

    var careNeed: PetCareNeed {
        switch self {
        case .bright, .proud:
            return .play
        case .tired, .overwhelmed, .needBreak:
            return .rest
        case .stuck:
            return .puzzle
        case .lonely:
            return .affection
        case .focused:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .bright, .proud:
            return .cheer
        case .tired, .needBreak:
            return .rest
        case .stuck:
            return .puzzle
        case .overwhelmed, .lonely:
            return .soothe
        case .focused:
            return .focus
        }
    }

    var mood: PetMood {
        switch self {
        case .bright, .proud:
            return .happy
        case .tired:
            return .nap
        case .stuck:
            return .thinking
        case .overwhelmed:
            return .stretch
        case .lonely:
            return .look
        case .focused:
            return .perch
        case .needBreak:
            return .sleepGuard
        }
    }

    var sparkReward: Int {
        switch self {
        case .bright, .focused:
            return 8
        case .tired, .stuck, .lonely:
            return 10
        case .overwhelmed, .needBreak:
            return 12
        case .proud:
            return 14
        }
    }

    var spriteSlug: String {
        switch self {
        case .bright:
            return "bright"
        case .tired:
            return "tired"
        case .stuck:
            return "stuck"
        case .overwhelmed:
            return "overwhelmed"
        case .lonely:
            return "lonely"
        case .proud:
            return "proud"
        case .focused:
            return "focused"
        case .needBreak:
            return "need-break"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-user-check-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        daypart: PetDaypartNudge,
        feeling: PetFeeling,
        careNeed: PetCareNeed,
        offeredMask: Int,
        answeredMask: Int,
        index: Int
    ) -> PetUserCheckIn? {
        let unavailable = offeredMask | answeredMask
        let remaining = allCases.filter { unavailable & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }

        let preferred: PetUserCheckIn
        if daypart == .night {
            preferred = .tired
        } else {
            switch feeling {
            case .sleepy, .hungry:
                preferred = .tired
            case .focused:
                preferred = .focused
            case .determined, .curious:
                preferred = .stuck
            case .overcharged, .restless:
                preferred = .needBreak
            case .lonely, .comfort:
                preferred = .lonely
            case .proud, .celebrating, .grateful:
                preferred = .proud
            case .playful, .bright, .eager:
                switch careNeed {
                case .rest:
                    preferred = .tired
                case .focus, .study:
                    preferred = .focused
                case .puzzle, .adventure:
                    preferred = .stuck
                case .affection:
                    preferred = .lonely
                case .play:
                    preferred = .bright
                }
            case .protective:
                preferred = .needBreak
            }
        }

        if remaining.contains(preferred) {
            return preferred
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        offeredMask: Int,
        answeredMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        latest: PetUserCheckIn?
    ) -> String {
        let offered = count(mask: offeredMask)
        let answered = count(mask: answeredMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "waiting to ask"
        return "User Check \(answered)/\(allCases.count) answered · \(offered) asked · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetToy: Int, CaseIterable {
    case sparkBall = 1
    case snackBell = 2
    case phraseRibbon = 4
    case questCompass = 8
    case napBlanket = 16
    case focusPebble = 32
    case cipherCube = 64
    case upgradeKite = 128
    case scoutFlag = 256
    case moonLamp = 512

    var title: String {
        switch self {
        case .sparkBall:
            return "Spark Ball"
        case .snackBell:
            return "Snack Bell"
        case .phraseRibbon:
            return "Phrase Ribbon"
        case .questCompass:
            return "Quest Compass"
        case .napBlanket:
            return "Nap Blanket"
        case .focusPebble:
            return "Focus Pebble"
        case .cipherCube:
            return "Cipher Cube"
        case .upgradeKite:
            return "Upgrade Kite"
        case .scoutFlag:
            return "Scout Flag"
        case .moonLamp:
            return "Moon Lamp"
        }
    }

    var shortLabel: String {
        switch self {
        case .sparkBall:
            return "Ball"
        case .snackBell:
            return "Bell"
        case .phraseRibbon:
            return "Ribbon"
        case .questCompass:
            return "Map"
        case .napBlanket:
            return "Nap"
        case .focusPebble:
            return "Focus"
        case .cipherCube:
            return "Cube"
        case .upgradeKite:
            return "Kite"
        case .scoutFlag:
            return "Flag"
        case .moonLamp:
            return "Lamp"
        }
    }

    var action: String {
        switch self {
        case .sparkBall:
            return "Roll ball"
        case .snackBell:
            return "Ring bell"
        case .phraseRibbon:
            return "Wave ribbon"
        case .questCompass:
            return "Spin compass"
        case .napBlanket:
            return "Tuck blanket"
        case .focusPebble:
            return "Hold pebble"
        case .cipherCube:
            return "Turn cube"
        case .upgradeKite:
            return "Fly kite"
        case .scoutFlag:
            return "Plant flag"
        case .moonLamp:
            return "Light lamp"
        }
    }

    func playLine(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .sparkBall:
            return "\(stage.shortLabel) bats a glowing spark ball across the desktop and grins \(feeling.title.lowercased())."
        case .snackBell:
            return "\(stage.shortLabel) rings the snack bell once, then waits politely for the care map."
        case .phraseRibbon:
            return "\(stage.shortLabel) waves a tiny ribbon while practicing a phrase echo."
        case .questCompass:
            return "\(stage.shortLabel) spins the compass until one safe route glows."
        case .napBlanket:
            return "\(stage.shortLabel) tucks the blanket, blinks slowly, and makes rest feel useful."
        case .focusPebble:
            return "\(stage.shortLabel) holds the focus pebble and settles beside the first minute."
        case .cipherCube:
            return "\(stage.shortLabel) turns the cipher cube and listens for a puzzle click."
        case .upgradeKite:
            return "\(stage.shortLabel) flies the upgrade kite and watches the next card shimmer."
        case .scoutFlag:
            return "\(stage.shortLabel) plants a little flag where the scout trail begins."
        case .moonLamp:
            return "\(stage.shortLabel) lights the moon lamp and softens the night watch."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .snackBell:
            return .snack
        case .napBlanket, .moonLamp:
            return .rest
        case .sparkBall, .questCompass, .scoutFlag:
            return .play
        case .phraseRibbon, .focusPebble, .cipherCube, .upgradeKite:
            return .focus
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .sparkBall:
            return .play
        case .snackBell:
            return .snack
        case .phraseRibbon:
            return .study
        case .questCompass, .scoutFlag:
            return .adventure
        case .napBlanket, .moonLamp:
            return .rest
        case .focusPebble, .upgradeKite:
            return .focus
        case .cipherCube:
            return .puzzle
        }
    }

    var mood: PetMood {
        switch self {
        case .sparkBall:
            return .hyper
        case .snackBell:
            return .snack
        case .phraseRibbon:
            return .peek
        case .questCompass, .scoutFlag:
            return .patrol
        case .napBlanket:
            return .stretch
        case .focusPebble:
            return .perch
        case .cipherCube, .upgradeKite:
            return .thinking
        case .moonLamp:
            return .sleepGuard
        }
    }

    var sparkReward: Int {
        switch self {
        case .sparkBall, .snackBell, .napBlanket:
            return 7
        case .phraseRibbon, .questCompass, .focusPebble, .cipherCube:
            return 9
        case .upgradeKite, .scoutFlag, .moonLamp:
            return 11
        }
    }

    var spriteSlug: String {
        switch self {
        case .sparkBall:
            return "spark-ball"
        case .snackBell:
            return "snack-bell"
        case .phraseRibbon:
            return "phrase-ribbon"
        case .questCompass:
            return "quest-compass"
        case .napBlanket:
            return "nap-blanket"
        case .focusPebble:
            return "focus-pebble"
        case .cipherCube:
            return "cipher-cube"
        case .upgradeKite:
            return "upgrade-kite"
        case .scoutFlag:
            return "scout-flag"
        case .moonLamp:
            return "moon-lamp"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-toy-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(
        daypart: PetDaypartNudge,
        feeling: PetFeeling,
        careNeed: PetCareNeed,
        playedMask: Int,
        index: Int
    ) -> PetToy? {
        let remaining = allCases.filter { playedMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }

        let preferred: PetToy
        if daypart == .night {
            preferred = .moonLamp
        } else {
            switch feeling {
            case .hungry:
                preferred = .snackBell
            case .sleepy, .protective:
                preferred = .napBlanket
            case .focused:
                preferred = .focusPebble
            case .overcharged, .playful:
                preferred = .sparkBall
            case .curious:
                preferred = .cipherCube
            case .restless, .determined:
                preferred = .upgradeKite
            case .proud, .celebrating:
                preferred = .scoutFlag
            case .lonely, .comfort, .grateful:
                preferred = .moonLamp
            case .bright, .eager:
                switch careNeed {
                case .affection, .play:
                    preferred = .sparkBall
                case .study:
                    preferred = .phraseRibbon
                case .adventure:
                    preferred = .questCompass
                case .rest:
                    preferred = .napBlanket
                case .focus:
                    preferred = .focusPebble
                case .puzzle:
                    preferred = .cipherCube
                }
            }
        }

        if remaining.contains(preferred) {
            return preferred
        }
        return remaining[index % remaining.count]
    }

    static func summary(
        offeredMask: Int,
        playedMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        latest: PetToy?
    ) -> String {
        let offered = count(mask: offeredMask)
        let played = count(mask: playedMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let latestText = latest.map { "Latest \($0.title)" } ?? "toybox waiting"
        return "Toybox \(played)/\(allCases.count) played · \(offered) offered · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
    }
}

enum PetTrick: Int, CaseIterable {
    case helloWave = 1
    case sparkHop = 2
    case cheekClap = 4
    case phraseEcho = 8
    case focusSit = 16
    case questPoint = 32
    case cipherTilt = 64
    case weatherDash = 128
    case guardianBow = 256
    case moonGuard = 512

    var title: String {
        switch self {
        case .helloWave:
            return "Hello Wave"
        case .sparkHop:
            return "Spark Hop"
        case .cheekClap:
            return "Cheek Clap"
        case .phraseEcho:
            return "Phrase Echo"
        case .focusSit:
            return "Focus Sit"
        case .questPoint:
            return "Quest Point"
        case .cipherTilt:
            return "Cipher Tilt"
        case .weatherDash:
            return "Weather Dash"
        case .guardianBow:
            return "Guardian Bow"
        case .moonGuard:
            return "Moon Guard"
        }
    }

    var shortLabel: String {
        switch self {
        case .helloWave:
            return "Wave"
        case .sparkHop:
            return "Hop"
        case .cheekClap:
            return "Clap"
        case .phraseEcho:
            return "Echo"
        case .focusSit:
            return "Sit"
        case .questPoint:
            return "Point"
        case .cipherTilt:
            return "Tilt"
        case .weatherDash:
            return "Dash"
        case .guardianBow:
            return "Bow"
        case .moonGuard:
            return "Guard"
        }
    }

    var action: String {
        switch self {
        case .helloWave:
            return "Wave hello"
        case .sparkHop:
            return "Practice hop"
        case .cheekClap:
            return "Clap sparks"
        case .phraseEcho:
            return "Echo phrase"
        case .focusSit:
            return "Practice sit"
        case .questPoint:
            return "Point route"
        case .cipherTilt:
            return "Tilt clue"
        case .weatherDash:
            return "Dash safely"
        case .guardianBow:
            return "Bow proudly"
        case .moonGuard:
            return "Guard moon"
        }
    }

    var requiredStage: PetGrowthStage {
        switch self {
        case .helloWave, .sparkHop:
            return .tinySpark
        case .cheekClap, .phraseEcho:
            return .pocketPal
        case .focusSit, .questPoint:
            return .trailBuddy
        case .cipherTilt, .weatherDash:
            return .stormScout
        case .guardianBow, .moonGuard:
            return .stormGuardian
        }
    }

    func isUnlocked(stage: PetGrowthStage) -> Bool {
        stage.rawValue >= requiredStage.rawValue
    }

    func performLine(stage: PetGrowthStage, feeling: PetFeeling) -> String {
        switch self {
        case .helloWave:
            return "\(stage.shortLabel) looks down, looks up, then gives a tiny hello wave."
        case .sparkHop:
            return "\(stage.shortLabel) does one bright spark hop and lands with \(feeling.title.lowercased()) eyes."
        case .cheekClap:
            return "\(stage.shortLabel) claps its cheeks softly, saving the sparks instead of scattering them."
        case .phraseEcho:
            return "\(stage.shortLabel) repeats a phrase echo, then waits for the user's voice."
        case .focusSit:
            return "\(stage.shortLabel) sits beside the first minute and keeps the desk calm."
        case .questPoint:
            return "\(stage.shortLabel) points at one safe quest route before the big path."
        case .cipherTilt:
            return "\(stage.shortLabel) tilts its head until the clue starts to make sense."
        case .weatherDash:
            return "\(stage.shortLabel) dashes through a tiny storm and comes back steady."
        case .guardianBow:
            return "\(stage.shortLabel) bows like a proud guardian after a finished care loop."
        case .moonGuard:
            return "\(stage.shortLabel) guards the moon lamp and lowers the room's urgency."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .helloWave, .cheekClap:
            return .snack
        case .sparkHop, .questPoint, .weatherDash:
            return .play
        case .phraseEcho, .focusSit, .cipherTilt:
            return .focus
        case .guardianBow, .moonGuard:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .helloWave:
            return .soothe
        case .sparkHop, .cheekClap, .weatherDash:
            return .play
        case .phraseEcho:
            return .study
        case .focusSit:
            return .focus
        case .questPoint:
            return .adventure
        case .cipherTilt:
            return .puzzle
        case .guardianBow:
            return .cheer
        case .moonGuard:
            return .rest
        }
    }

    var mood: PetMood {
        switch self {
        case .helloWave, .cheekClap, .guardianBow:
            return .happy
        case .sparkHop, .weatherDash:
            return .hyper
        case .phraseEcho, .cipherTilt:
            return .peek
        case .focusSit:
            return .perch
        case .questPoint:
            return .patrol
        case .moonGuard:
            return .sleepGuard
        }
    }

    var sparkReward: Int {
        switch self {
        case .helloWave, .sparkHop:
            return 6
        case .cheekClap, .phraseEcho:
            return 8
        case .focusSit, .questPoint:
            return 10
        case .cipherTilt, .weatherDash:
            return 12
        case .guardianBow, .moonGuard:
            return 14
        }
    }

    var spriteSlug: String {
        switch self {
        case .helloWave:
            return "hello-wave"
        case .sparkHop:
            return "spark-hop"
        case .cheekClap:
            return "cheek-clap"
        case .phraseEcho:
            return "phrase-echo"
        case .focusSit:
            return "focus-sit"
        case .questPoint:
            return "quest-point"
        case .cipherTilt:
            return "cipher-tilt"
        case .weatherDash:
            return "weather-dash"
        case .guardianBow:
            return "guardian-bow"
        case .moonGuard:
            return "moon-guard"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-trick-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func unlocked(stage: PetGrowthStage) -> [PetTrick] {
        allCases.filter { $0.isUnlocked(stage: stage) }
    }

    static func next(
        stage: PetGrowthStage,
        feeling: PetFeeling,
        careNeed: PetCareNeed,
        practicedMask: Int,
        index: Int
    ) -> PetTrick? {
        let unlocked = unlocked(stage: stage)
        guard !unlocked.isEmpty else { return nil }
        let remaining = unlocked.filter { practicedMask & $0.rawValue == 0 }
        let pool = remaining.isEmpty ? unlocked : remaining

        let preferred: PetTrick
        switch feeling {
        case .sleepy, .protective:
            preferred = .moonGuard
        case .focused:
            preferred = .focusSit
        case .curious:
            preferred = .cipherTilt
        case .overcharged, .playful, .restless:
            preferred = .sparkHop
        case .proud, .celebrating, .grateful:
            preferred = .guardianBow
        case .hungry, .comfort, .lonely:
            preferred = .helloWave
        case .determined:
            preferred = .questPoint
        case .bright, .eager:
            switch careNeed {
            case .study:
                preferred = .phraseEcho
            case .adventure:
                preferred = .questPoint
            case .focus:
                preferred = .focusSit
            case .puzzle:
                preferred = .cipherTilt
            case .rest:
                preferred = .moonGuard
            case .affection:
                preferred = .helloWave
            case .play:
                preferred = .sparkHop
            }
        }

        if pool.contains(where: { $0 == preferred && $0.isUnlocked(stage: stage) }) {
            return preferred
        }
        return pool[index % pool.count]
    }

    static func summary(
        offeredMask: Int,
        practicedMask: Int,
        dismissedMask: Int,
        albumMask: Int,
        latest: PetTrick?,
        stage: PetGrowthStage
    ) -> String {
        let offered = count(mask: offeredMask)
        let practiced = count(mask: practicedMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let unlockedCount = unlocked(stage: stage).count
        let latestText = latest.map { "Latest \($0.title)" } ?? "trick practice waiting"
        return "Trickbook \(practiced)/\(max(1, unlockedCount)) practiced · \(offered) offered · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(latestText)"
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
    case fieldNote = 32768

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
        case .fieldNote:
            return "Field Note"
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
        case .fieldNote:
            return "Field"
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
        case .fieldNote:
            return "A tiny report from the desktop gets saved."
        }
    }

    var vital: PetCareVital {
        switch self {
        case .checkIn, .feeling, .reset, .rest, .comeback:
            return .rest
        case .focus, .lesson, .board, .puzzle, .boost, .upgrade, .fieldNote:
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
        case .focus, .boost, .upgrade, .fieldNote:
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
        case .fieldNote:
            return "field-note"
        }
    }

    var sparkReward: Int {
        switch self {
        case .checkIn, .feeling, .reset, .rest:
            return 3
        case .focus, .tinyWin, .care:
            return 4
        case .quest, .lesson, .board, .puzzle, .fieldNote:
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

enum PetCheerScript: Int, CaseIterable {
    case morningSpark = 1
    case firstSip = 2
    case deskPerch = 4
    case oneWindow = 8
    case pocketWin = 16
    case softStretch = 32
    case campfireClose = 64
    case loopTuck = 128
    case moonGuard = 256
    case quietQuestion = 512
    case comebackWave = 1024
    case upgradeWish = 2048
    case sunriseInventory = 4096
    case taskWeather = 8192
    case tabRescue = 16384
    case meetingComedown = 32768
    case waterAndBlink = 65536
    case afternoonProof = 131072
    case eveningInventory = 262144
    case sleepPermission = 524288

    var title: String {
        switch self {
        case .morningSpark:
            return "Morning Spark"
        case .firstSip:
            return "First Sip"
        case .deskPerch:
            return "Desk Perch"
        case .oneWindow:
            return "One Window"
        case .pocketWin:
            return "Pocket Win"
        case .softStretch:
            return "Soft Stretch"
        case .campfireClose:
            return "Campfire Close"
        case .loopTuck:
            return "Loop Tuck"
        case .moonGuard:
            return "Moon Guard"
        case .quietQuestion:
            return "Quiet Question"
        case .comebackWave:
            return "Comeback Wave"
        case .upgradeWish:
            return "Upgrade Wish"
        case .sunriseInventory:
            return "Sunrise Inventory"
        case .taskWeather:
            return "Task Weather"
        case .tabRescue:
            return "Tab Rescue"
        case .meetingComedown:
            return "Meeting Comedown"
        case .waterAndBlink:
            return "Water And Blink"
        case .afternoonProof:
            return "Afternoon Proof"
        case .eveningInventory:
            return "Evening Inventory"
        case .sleepPermission:
            return "Sleep Permission"
        }
    }

    var shortLabel: String {
        switch self {
        case .morningSpark:
            return "AM"
        case .firstSip:
            return "Sip"
        case .deskPerch:
            return "Desk"
        case .oneWindow:
            return "Win"
        case .pocketWin:
            return "Save"
        case .softStretch:
            return "Move"
        case .campfireClose:
            return "Close"
        case .loopTuck:
            return "Tuck"
        case .moonGuard:
            return "Moon"
        case .quietQuestion:
            return "Ask"
        case .comebackWave:
            return "Back"
        case .upgradeWish:
            return "Wish"
        case .sunriseInventory:
            return "List"
        case .taskWeather:
            return "Weather"
        case .tabRescue:
            return "Tabs"
        case .meetingComedown:
            return "Meet"
        case .waterAndBlink:
            return "Blink"
        case .afternoonProof:
            return "Proof"
        case .eveningInventory:
            return "Pack"
        case .sleepPermission:
            return "Sleep"
        }
    }

    var body: String {
        switch self {
        case .morningSpark:
            return "Pika pika... I looked down, looked up, and found you. What kind of morning are we having?"
        case .firstSip:
            return "Before the day gets loud, want one tiny care spark with me?"
        case .deskPerch:
            return "I can perch beside the first task. What is the smallest piece on your desk?"
        case .oneWindow:
            return "Want to make one window feel less crowded before we move?"
        case .pocketWin:
            return "Did a tiny win happen? I can save it before the day rushes past."
        case .softStretch:
            return "Your shoulders look like they might want a reset. Want one soft stretch and a spark?"
        case .campfireClose:
            return "Want to tuck one open loop by the campfire before it follows you home?"
        case .loopTuck:
            return "I can hold the loose end while you choose one last gentle step."
        case .moonGuard:
            return "No pressure now. Want me to guard the quiet while you close this?"
        case .quietQuestion:
            return "What is happening in your head right now? One sentence is enough."
        case .comebackWave:
            return "You came back. I saved your place and one warm spark."
        case .upgradeWish:
            return "The Sparks are humming. Want to wish for the next tiny charm?"
        case .sunriseInventory:
            return "Before we run, what is one thing you are carrying into today?"
        case .taskWeather:
            return "I checked the desk weather. Is this a sunny task, foggy task, or storm task?"
        case .tabRescue:
            return "There are too many shiny doors open. Want to pick one tab and let the others wait?"
        case .meetingComedown:
            return "If a meeting left static behind, I can help sort keep, drop, and next."
        case .waterAndBlink:
            return "Tiny care check: water sip, blink twice, then one less sharp edge."
        case .afternoonProof:
            return "Afternoon can hide progress. Want to name one proof that today moved?"
        case .eveningInventory:
            return "Before evening closes, want to pack one loose thought into the journal?"
        case .sleepPermission:
            return "You do not have to earn rest with one more task. Want me to count rest as care?"
        }
    }

    var action: String {
        switch self {
        case .morningSpark:
            return "Open morning check"
        case .firstSip:
            return "Take one care spark"
        case .deskPerch:
            return "Start first task"
        case .oneWindow:
            return "Clear one window"
        case .pocketWin:
            return "Save tiny win"
        case .softStretch:
            return "Open reset"
        case .campfireClose:
            return "Close one loop"
        case .loopTuck:
            return "Tuck loose end"
        case .moonGuard:
            return "Open night watch"
        case .quietQuestion:
            return "Answer softly"
        case .comebackWave:
            return "Open comeback"
        case .upgradeWish:
            return "Open upgrade"
        case .sunriseInventory:
            return "Name carried thing"
        case .taskWeather:
            return "Check task weather"
        case .tabRescue:
            return "Choose one tab"
        case .meetingComedown:
            return "Sort meeting static"
        case .waterAndBlink:
            return "Take care beat"
        case .afternoonProof:
            return "Save one proof"
        case .eveningInventory:
            return "Pack thought"
        case .sleepPermission:
            return "Count rest"
        }
    }

    var rewardLine: String {
        "\(title) answered"
    }

    var daypart: PetDaypartNudge? {
        switch self {
        case .morningSpark, .firstSip:
            return .sunrise
        case .deskPerch, .oneWindow:
            return .focus
        case .pocketWin, .softStretch:
            return .afternoon
        case .campfireClose, .loopTuck:
            return .evening
        case .moonGuard, .quietQuestion:
            return .night
        case .comebackWave, .upgradeWish:
            return nil
        case .sunriseInventory:
            return .sunrise
        case .taskWeather, .tabRescue:
            return .focus
        case .meetingComedown, .waterAndBlink, .afternoonProof:
            return .afternoon
        case .eveningInventory:
            return .evening
        case .sleepPermission:
            return .night
        }
    }

    var intent: PetCheerIntent {
        switch self {
        case .morningSpark, .quietQuestion:
            return .feeling
        case .firstSip:
            return .care
        case .deskPerch, .oneWindow:
            return .focus
        case .pocketWin:
            return .tinyWin
        case .softStretch:
            return .reset
        case .campfireClose:
            return .event
        case .loopTuck:
            return .board
        case .moonGuard:
            return .rest
        case .comebackWave:
            return .comeback
        case .upgradeWish:
            return .upgrade
        case .sunriseInventory:
            return .feeling
        case .taskWeather, .tabRescue:
            return .focus
        case .meetingComedown:
            return .checkIn
        case .waterAndBlink:
            return .reset
        case .afternoonProof:
            return .tinyWin
        case .eveningInventory:
            return .fieldNote
        case .sleepPermission:
            return .rest
        }
    }

    var vital: PetCareVital {
        switch self {
        case .morningSpark, .firstSip, .pocketWin:
            return .snack
        case .deskPerch, .oneWindow, .quietQuestion, .upgradeWish:
            return .focus
        case .softStretch, .campfireClose, .loopTuck:
            return .play
        case .moonGuard, .comebackWave:
            return .rest
        case .sunriseInventory, .meetingComedown, .tabRescue, .eveningInventory:
            return .focus
        case .taskWeather:
            return .focus
        case .waterAndBlink, .afternoonProof:
            return .play
        case .sleepPermission:
            return .rest
        }
    }

    var moodStep: PetMoodCareStep {
        switch self {
        case .morningSpark, .quietQuestion, .comebackWave:
            return .soothe
        case .firstSip:
            return .snack
        case .deskPerch, .oneWindow, .upgradeWish:
            return .focus
        case .pocketWin:
            return .cheer
        case .softStretch, .moonGuard:
            return .rest
        case .campfireClose, .loopTuck:
            return .adventure
        case .sunriseInventory, .meetingComedown:
            return .soothe
        case .taskWeather, .tabRescue, .eveningInventory:
            return .focus
        case .waterAndBlink, .sleepPermission:
            return .rest
        case .afternoonProof:
            return .cheer
        }
    }

    var sparkReward: Int {
        switch self {
        case .morningSpark, .firstSip, .deskPerch, .oneWindow:
            return 5
        case .pocketWin, .softStretch, .campfireClose, .loopTuck:
            return 6
        case .moonGuard, .quietQuestion, .comebackWave, .upgradeWish:
            return 7
        case .sunriseInventory, .taskWeather, .tabRescue:
            return 6
        case .meetingComedown, .waterAndBlink, .afternoonProof:
            return 7
        case .eveningInventory, .sleepPermission:
            return 8
        }
    }

    var spriteSlug: String {
        switch self {
        case .morningSpark:
            return "morning-spark"
        case .firstSip:
            return "first-sip"
        case .deskPerch:
            return "desk-perch"
        case .oneWindow:
            return "one-window"
        case .pocketWin:
            return "pocket-win"
        case .softStretch:
            return "soft-stretch"
        case .campfireClose:
            return "campfire-close"
        case .loopTuck:
            return "loop-tuck"
        case .moonGuard:
            return "moon-guard"
        case .quietQuestion:
            return "quiet-question"
        case .comebackWave:
            return "comeback-wave"
        case .upgradeWish:
            return "upgrade-wish"
        case .sunriseInventory:
            return "sunrise-inventory"
        case .taskWeather:
            return "task-weather"
        case .tabRescue:
            return "tab-rescue"
        case .meetingComedown:
            return "meeting-comedown"
        case .waterAndBlink:
            return "water-and-blink"
        case .afternoonProof:
            return "afternoon-proof"
        case .eveningInventory:
            return "evening-inventory"
        case .sleepPermission:
            return "sleep-permission"
        }
    }

    var spriteRequestName: String {
        "pet-{stage}-cheer-script-\(spriteSlug).png"
    }

    static func count(mask: Int) -> Int {
        allCases.filter { mask & $0.rawValue != 0 }.count
    }

    static func next(daypart: PetDaypartNudge, intent: PetCheerIntent, offeredMask: Int, index: Int) -> PetCheerScript? {
        let remaining = allCases.filter { offeredMask & $0.rawValue == 0 }
        guard !remaining.isEmpty else { return nil }
        let daypartMatches = remaining.filter { $0.daypart == daypart }
        if !daypartMatches.isEmpty {
            return daypartMatches[index % daypartMatches.count]
        }
        let intentMatches = remaining.filter { $0.intent == intent }
        if !intentMatches.isEmpty {
            return intentMatches[index % intentMatches.count]
        }
        return remaining[index % remaining.count]
    }

    static func summary(offeredMask: Int, answeredMask: Int, dismissedMask: Int, albumMask: Int) -> String {
        let offered = count(mask: offeredMask)
        let answered = count(mask: answeredMask)
        let dismissed = count(mask: dismissedMask)
        let album = count(mask: albumMask)
        let nextText = allCases.first { offeredMask & $0.rawValue == 0 }
            .map { "Next \($0.title)" } ?? "All script lines seen"
        return "Cheer Scripts \(answered)/\(allCases.count) answered · \(offered) seen · \(dismissed) skipped · Album \(album)/\(allCases.count) · \(nextText)"
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
            case .bodyCheck:
                return .careRitual
            case .nameOneThing:
                return .whatsHappening
            case .waterSpark:
                return .softReset
            case .tabTamer:
                return .focusPerch
            case .afterMeeting:
                return .whatsHappening
            case .returnWarmth:
                return .comebackGlow
            case .finishLine:
                return .braveStep
            case .permissionRest:
                return .nightWatch
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
        case .fieldNote:
            return .puzzleClue
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
