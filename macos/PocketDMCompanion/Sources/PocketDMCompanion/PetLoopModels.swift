import Foundation
import SwiftUI

enum PetGrowthStage: CaseIterable {
    case tinySpark
    case pocketPal
    case trailBuddy
    case stormScout
    case stormGuardian

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

        var bubbleText: String {
            "\(title): \(body)"
        }
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
                rewardLine: "Comeback answered"
            )
        }
        if energy == 0 {
            return PetCheerPrompt(
                title: "Soft recharge",
                body: "I am sleepy, but I saved your quest.",
                action: "Open a gentle check-in",
                rewardLine: "Quiet check-in answered"
            )
        }
        if index % 3 == 1 {
            return PetCheerPrompt(
                title: "\(careNeed.title) check",
                body: "How are you doing? Want to \(careNeed.actionLine)?",
                action: "Open the care ritual",
                rewardLine: "\(careNeed.title) check-in answered"
            )
        }
        if eventProgress < seasonEvent.requiredSteps {
            return PetCheerPrompt(
                title: seasonEvent.title,
                body: "Want to \(seasonEvent.actionLine)?",
                action: "Open today's event",
                rewardLine: "\(seasonEvent.title) check-in answered"
            )
        }
        if index % 5 == 0 {
            return PetCheerPrompt(
                title: careMoment.title,
                body: careMoment.nudgeLine,
                action: "Open the time-of-day check-in",
                rewardLine: "\(careMoment.title) check-in answered"
            )
        }
        if boosterReady {
            return PetCheerPrompt(
                title: "Boost ready",
                body: "Want a quick burst before the next quest?",
                action: "Open Spark Boost",
                rewardLine: "Boost check-in answered"
            )
        }
        if !cipherSolved {
            return PetCheerPrompt(
                title: "Tiny cipher",
                body: "\(cipher.clue). I can solve it with you.",
                action: "Open today's cipher",
                rewardLine: "Cipher check-in answered"
            )
        }
        if sparkDust >= 80 {
            return PetCheerPrompt(
                title: "Kit upgrade",
                body: "\(sparkDust) Sparks are glowing. Want an upgrade?",
                action: "Open upgrade",
                rewardLine: "Upgrade check-in answered"
            )
        }
        if let nextQuest {
            return PetCheerPrompt(
                title: "Daily board",
                body: "How are you doing? Want to \(nextQuest.nudgeText)?",
                action: "Open today's board",
                rewardLine: "\(nextQuest.title) check-in answered"
            )
        }
        if let nextAction = combo.first(where: { comboMask & $0.rawValue == 0 }) {
            return PetCheerPrompt(
                title: "Tiny combo",
                body: "How are you doing? Want to \(nextAction.nudgeText)?",
                action: "Open the combo step",
                rewardLine: "\(nextAction.label) combo check-in answered"
            )
        }

        let fallback = [
            PetCheerPrompt(title: stage.title, body: "Want one brave click?", action: "Open a tiny quest", rewardLine: "Tiny quest check-in answered"),
            PetCheerPrompt(title: "I kept watch", body: "Want a 60-second quest?", action: "Open a short quest", rewardLine: "Watch check-in answered"),
            PetCheerPrompt(title: "\(feeling.title) mood", body: "Need a hint or a phrase?", action: "Open a mood check-in", rewardLine: "\(feeling.title) check-in answered"),
            PetCheerPrompt(title: "Tiny reset", body: "Breathe, stretch, then one spark?", action: "Open a reset", rewardLine: "Reset check-in answered"),
            PetCheerPrompt(title: "Pika check", body: "What is happening over there?", action: "Open chat", rewardLine: "Chat check-in answered"),
            PetCheerPrompt(title: "I found a task", body: "Want me to sit with you while you start?", action: "Open focus mode", rewardLine: "Focus check-in answered"),
            PetCheerPrompt(title: "Warm bond", body: "No big quest needed. One tap is enough.", action: "Open a gentle check-in", rewardLine: "Bond check-in answered")
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
