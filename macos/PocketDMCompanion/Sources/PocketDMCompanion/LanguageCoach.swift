import AVFoundation
import Foundation

struct LanguagePack: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let nativeTitle: String
    let subtitle: String
    let languageCode: String
    let words: [LanguageCard]
    let sentences: [LanguageCard]

    var allCards: [LanguageCard] {
        words + sentences
    }

    static func load() -> [LanguagePack] {
        guard
            let url = Bundle.module.url(forResource: "language-packs", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let packs = try? JSONDecoder().decode([LanguagePack].self, from: data),
            !packs.isEmpty
        else {
            return fallback
        }
        return packs
    }

    private static let fallback: [LanguagePack] = [
        LanguagePack(
            id: "spanish",
            title: "Spanish",
            nativeTitle: "Espanol",
            subtitle: "Travel basics",
            languageCode: "es-ES",
            words: [
                LanguageCard(
                    id: "spanish-hello",
                    kind: .word,
                    english: "Hello",
                    target: "Hola",
                    romanization: "OH-lah",
                    pronunciationTip: "Open with a round OH, then finish softly on lah.",
                    distractors: ["Goodbye", "Please", "Water"]
                )
            ],
            sentences: [
                LanguageCard(
                    id: "spanish-sentence-hello",
                    kind: .sentence,
                    english: "I speak Spanish",
                    target: "Yo hablo español",
                    romanization: "yoh AH-bloh es-pah-NYOL",
                    pronunciationTip: "Keep three even beats and stress NYOL at the end.",
                    distractors: ["I need water", "You buy bread", "We read a book"]
                )
            ]
        )
    ]
}

enum LanguageCardKind: String, Codable, Hashable {
    case word
    case sentence

    var label: String {
        switch self {
        case .word:
            return "Word"
        case .sentence:
            return "Sentence"
        }
    }
}

struct LanguageCard: Codable, Hashable, Identifiable {
    let id: String
    let kind: LanguageCardKind
    let english: String
    let target: String
    let romanization: String
    let pronunciationTip: String
    let distractors: [String]
}

enum LessonStep: String, Codable {
    case teach
    case meaningQuiz
    case phraseQuiz
    case repeatPrompt
    case complete
}

enum LearningMode: String, Codable {
    case chat
    case lesson
    case journal
}

struct LanguagePracticeReward {
    let correct: Bool
    let dailyBond: Bool
    let message: String
}

@MainActor
final class LanguageCoachStore: ObservableObject {
    private static let selectedPackKey = "PocketDMCompanion.language.selectedPack"
    private static let currentStreakKey = "PocketDMCompanion.language.currentStreak"
    private static let lastPracticeDayKey = "PocketDMCompanion.language.lastPracticeDay"
    private static let completedCardsKey = "PocketDMCompanion.language.completedCards"
    private static let reviewLevelsKey = "PocketDMCompanion.language.reviewLevels"
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func pikaFeedback(_ message: String) -> String {
        let normalized = message.lowercased().filter(\.isLetter)
        if normalized.contains("pikapika") {
            return message
        }
        return "Pika pika! \(message)"
    }

    let packs: [LanguagePack]

    @Published var selectedPackID: String {
        didSet {
            persistSelectedPack()
        }
    }
    @Published private(set) var step: LessonStep = .teach
    @Published private(set) var currentCardIndex = 0
    @Published private(set) var currentStreak: Int
    @Published private(set) var lastPracticeDay: String
    @Published private(set) var completedCardIDs: Set<String>
    @Published private(set) var reviewLevels: [String: Int]
    @Published private(set) var feedback = "Pika pika! Pick a pack, listen, then quiz."

    private let defaults: UserDefaults
    private let speaker = LanguageSpeechSynthesizer()

    init(defaults: UserDefaults = .standard, packs: [LanguagePack] = LanguagePack.load()) {
        self.defaults = defaults
        self.packs = packs
        let savedPack = defaults.string(forKey: Self.selectedPackKey)
        selectedPackID = savedPack ?? packs.first?.id ?? "spanish"
        currentStreak = defaults.object(forKey: Self.currentStreakKey) as? Int ?? 0
        lastPracticeDay = defaults.string(forKey: Self.lastPracticeDayKey) ?? ""
        completedCardIDs = Set(defaults.array(forKey: Self.completedCardsKey) as? [String] ?? [])
        reviewLevels = defaults.dictionary(forKey: Self.reviewLevelsKey) as? [String: Int] ?? [:]
        feedback = Self.pikaFeedback("Learn \(selectedPack.title) with Pikachu.")
    }

    var selectedPack: LanguagePack {
        packs.first { $0.id == selectedPackID } ?? packs[0]
    }

    var lessonCards: [LanguageCard] {
        selectedPack.allCards
    }

    var currentCard: LanguageCard {
        let cards = lessonCards
        return cards[min(currentCardIndex, max(cards.count - 1, 0))]
    }

    var progressLine: String {
        let learned = lessonCards.filter { completedCardIDs.contains($0.id) }.count
        return "\(selectedPack.nativeTitle) · \(learned)/\(lessonCards.count) · \(currentCard.kind.label) · Streak \(currentStreak)"
    }

    var packLine: String {
        "\(selectedPack.title) · \(selectedPack.subtitle)"
    }

    var stepTitle: String {
        switch step {
        case .teach:
            return "Listen"
        case .meaningQuiz:
            return "Pick the meaning"
        case .phraseQuiz:
            return "Pick the phrase"
        case .repeatPrompt:
            return "Repeat after Pikachu"
        case .complete:
            return "Lesson complete"
        }
    }

    var meaningChoices: [String] {
        rotate([currentCard.english] + Array(currentCard.distractors.prefix(2)), by: currentCardIndex)
    }

    var phraseChoices: [String] {
        let alternatives = selectedPack.allCards
            .filter { $0.id != currentCard.id }
            .map(\.target)
        return rotate([currentCard.target] + Array(alternatives.prefix(2)), by: currentCardIndex + 1)
    }

    func selectPack(_ pack: LanguagePack) {
        selectedPackID = pack.id
        currentCardIndex = 0
        step = .teach
        feedback = Self.pikaFeedback("\(pack.title) pack ready. Listen first, then slow it down before the quiz.")
        persistSelectedPack()
    }

    func startQuiz() {
        step = .meaningQuiz
        feedback = Self.pikaFeedback("Quiz time. What does \(currentCard.target) mean?")
    }

    func speakCurrent(slow: Bool = false) {
        feedback = Self.pikaFeedback(slow ? "Slow listen: \(currentCard.romanization)" : "Listen: \(currentCard.romanization)")
        speaker.speak(currentCard.target, languageCode: selectedPack.languageCode, slow: slow)
    }

    func submitMeaning(_ answer: String) -> LanguagePracticeReward {
        guard answer == currentCard.english else {
            markMiss("Almost. \(currentCard.target) means \(currentCard.english). Listen again, then retry the meaning.")
            return LanguagePracticeReward(correct: false, dailyBond: false, message: feedback)
        }
        markCorrect()
        step = .phraseQuiz
        feedback = Self.pikaFeedback("Correct. Meaning locked. Now pick the phrase you heard.")
        return LanguagePracticeReward(correct: true, dailyBond: false, message: feedback)
    }

    func submitPhrase(_ answer: String) -> LanguagePracticeReward {
        guard answer == currentCard.target else {
            markMiss("Close. The phrase is \(currentCard.target). Replay it once and watch the syllables.")
            return LanguagePracticeReward(correct: false, dailyBond: false, message: feedback)
        }
        markCorrect()
        step = .repeatPrompt
        feedback = Self.pikaFeedback("Nice. Phrase matched. Say it out loud: \(currentCard.romanization).")
        speakCurrent(slow: true)
        return LanguagePracticeReward(correct: true, dailyBond: false, message: feedback)
    }

    func finishRepeat() -> LanguagePracticeReward {
        completedCardIDs.insert(currentCard.id)
        reviewLevels[currentCard.id, default: 0] += 1
        let today = Self.dayFormatter.string(from: Date())
        let earnedDailyBond = lastPracticeDay != today
        lastPracticeDay = today
        persistProgress()

        if currentCardIndex + 1 >= lessonCards.count {
            step = .complete
            feedback = Self.pikaFeedback("\(selectedPack.title) spark complete. Come back tomorrow to keep the streak warm.")
        } else {
            currentCardIndex += 1
            step = .teach
            feedback = Self.pikaFeedback("Next card unlocked. Listen first, then quiz again.")
        }

        return LanguagePracticeReward(
            correct: true,
            dailyBond: earnedDailyBond,
            message: Self.pikaFeedback(earnedDailyBond ? "Daily language spark earned: +1 Bond HP and Joy +1." : "Practice logged. Joy +1.")
        )
    }

    func restartLesson() {
        currentCardIndex = 0
        step = .teach
        feedback = Self.pikaFeedback("Fresh run started. Listen first, slow it down, then quiz.")
    }

    private func markCorrect() {
        currentStreak += 1
        reviewLevels[currentCard.id, default: 0] += 1
        persistProgress()
    }

    private func markMiss(_ message: String) {
        currentStreak = 0
        feedback = Self.pikaFeedback(message)
        persistProgress()
    }

    private func rotate(_ values: [String], by amount: Int) -> [String] {
        guard !values.isEmpty else { return values }
        let offset = amount % values.count
        return Array(values[offset...]) + Array(values[..<offset])
    }

    private func persistSelectedPack() {
        defaults.set(selectedPackID, forKey: Self.selectedPackKey)
    }

    private func persistProgress() {
        defaults.set(currentStreak, forKey: Self.currentStreakKey)
        defaults.set(lastPracticeDay, forKey: Self.lastPracticeDayKey)
        defaults.set(Array(completedCardIDs).sorted(), forKey: Self.completedCardsKey)
        defaults.set(reviewLevels, forKey: Self.reviewLevelsKey)
    }
}

@MainActor
final class LanguageSpeechSynthesizer {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, languageCode: String, slow: Bool) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = slow ? 0.32 : 0.46
        utterance.pitchMultiplier = 1.04
        utterance.volume = 0.92
        synthesizer.speak(utterance)
    }
}
