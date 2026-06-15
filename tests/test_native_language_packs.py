from __future__ import annotations

import json
from pathlib import Path


LANGUAGE_PACKS = Path(
    "macos/PocketDMCompanion/Sources/PocketDMCompanion/Resources/language-packs.json"
)
LANGUAGE_COACH_SWIFT = Path(
    "macos/PocketDMCompanion/Sources/PocketDMCompanion/LanguageCoach.swift"
)
MAIN_SWIFT = Path("macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift")


def test_native_language_packs_are_demo_comprehensive() -> None:
    packs = json.loads(LANGUAGE_PACKS.read_text())

    assert {pack["id"] for pack in packs} >= {"spanish", "mandarin"}
    for pack in packs:
        assert len(pack["words"]) >= 100
        assert len(pack["sentences"]) >= 100


def test_native_language_pack_phrases_stay_language_only() -> None:
    packs = json.loads(LANGUAGE_PACKS.read_text())

    for pack in packs:
        cards = pack["words"] + pack["sentences"]
        for card in cards:
            target = card["target"].casefold()
            assert "pika" not in target


def test_native_learn_mode_keeps_audio_language_only() -> None:
    coach_source = LANGUAGE_COACH_SWIFT.read_text()
    main_source = MAIN_SWIFT.read_text()

    assert "speaker.speak(currentCard.target" in coach_source
    assert "speaker.speak(\"Pika" not in coach_source
    open_learning_block = main_source[
        main_source.index("func openLearning()"):
        main_source.index("func openJournal()")
    ]
    assert "speakPika" not in open_learning_block
    assert "Lesson ready. Press Hear for clean phrase audio." in open_learning_block
