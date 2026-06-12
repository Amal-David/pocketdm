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
}

enum PetFeeling {
    case bright
    case eager
    case proud
    case hungry
    case sleepy
    case curious
    case lonely

    init(happiness: Int, energy: Int, comboComplete: Bool, sparkDust: Int, streak: Int) {
        if energy == 0 {
            self = .sleepy
        } else if happiness <= 1 {
            self = .lonely
        } else if energy <= 1 {
            self = .hungry
        } else if comboComplete {
            self = .proud
        } else if streak == 0 || sparkDust < 20 {
            self = .curious
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
}

enum PetComboAction: Int, CaseIterable {
    case pet = 1
    case hint = 2
    case learn = 4
    case hyper = 8
    case upgrade = 16
    case open = 32

    static func dailyCombo(for dateKey: String) -> [PetComboAction] {
        let seed = dateKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let decks: [[PetComboAction]] = [
            [.pet, .hint, .learn],
            [.pet, .hyper, .open],
            [.learn, .hint, .upgrade],
            [.pet, .learn, .hyper],
            [.hint, .open, .upgrade],
            [.pet, .open, .learn]
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
        }
    }
}

enum PetUpgradeKind: CaseIterable {
    case snack
    case lesson
    case quest
    case nest
    case cheer

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

enum PetLoreCodex {
    static func line(
        stage: PetGrowthStage,
        feeling: PetFeeling,
        snackLevel: Int,
        lessonLevel: Int,
        questLevel: Int,
        nestLevel: Int,
        cheerLevel: Int
    ) -> String {
        let strongestUpgrade = [
            ("snack", snackLevel),
            ("lesson", lessonLevel),
            ("quest", questLevel),
            ("nest", nestLevel),
            ("cheer", cheerLevel)
        ].max { $0.1 < $1.1 }

        if let strongestUpgrade, strongestUpgrade.1 > 0 {
            return "\(stage.loreLine) Favorite charm: \(strongestUpgrade.0)."
        }
        return "\(stage.loreLine) \(feeling.helperLine)"
    }
}

enum PetNudgeLibrary {
    static func cheerLine(
        feeling: PetFeeling,
        stage: PetGrowthStage,
        combo: [PetComboAction],
        comboMask: Int,
        energy: Int,
        sparkDust: Int,
        index: Int
    ) -> String {
        if energy == 0 {
            return "I am sleepy, but I saved your quest. Come back after a recharge?"
        }
        if sparkDust >= 80 {
            return "You have \(sparkDust) Sparks. Want to upgrade my little kit?"
        }
        if let nextAction = combo.first(where: { comboMask & $0.rawValue == 0 }) {
            return "How are you doing? Today's tiny combo wants you to \(nextAction.nudgeText)."
        }

        let fallback = [
            "\(stage.title) check-in: want one brave click?",
            "I kept watch. Want a 60-second quest?",
            "\(feeling.title) mood today. Need a hint or a phrase?",
            "Tiny check-in: breathe, stretch, then one spark?",
            "Your pocket buddy is awake. What is happening?"
        ]
        return fallback[index % fallback.count]
    }
}
