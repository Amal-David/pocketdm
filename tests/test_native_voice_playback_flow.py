from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_SWIFT = ROOT / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"


def _source() -> str:
    return MAIN_SWIFT.read_text()


def _block(source: str, start: str, end: str) -> str:
    start_index = source.index(start)
    end_index = source.index(end, start_index)
    return source[start_index:end_index]


def test_mute_suppresses_playback_through_sound_enabled_guards() -> None:
    source = _source()
    model_wrappers = _block(source, "private func play(_ sound: PetSound)", "enum PetSound")
    sound_player = _block(source, "final class PetSoundPlayer", "struct DragonOverlayView")

    assert "soundPlayer.play(sound, enabled: soundEnabled)" in model_wrappers
    assert "soundPlayer.speakPika(character: companionCharacter, enabled: soundEnabled, force: force)" in model_wrappers
    assert "soundPlayer.speakPikaLine(text, character: companionCharacter, enabled: soundEnabled, force: force)" in model_wrappers
    assert "guard enabled, let player = soundInstance(for: sound) else { return }" in sound_player
    assert "guard enabled else {\n            onVoiceStatus?(\"Muted; text only.\")\n            return\n        }" in sound_player


def test_send_and_reply_sounds_are_mapped_to_resources() -> None:
    source = _source()
    pet_sound = _block(source, "enum PetSound", "@MainActor\nfinal class VoiceConversationTranscriber")

    mappings = dict(
        re.findall(
            r"case \.(reply|send):\n\s+return \[(.*?)\]",
            pet_sound,
        )
    )

    assert mappings["reply"] == '"chirp-reply", "pika-voice-reply"'
    assert mappings["send"] == '"chirp-send", "pika-cc0-pep-1"'


def test_pika_tts_url_status_and_bundled_fallback_exist() -> None:
    source = _source()
    status = _block(source, "private func pikaVoiceStatusLine", "private func pikaText")
    sound_player = _block(source, "final class PetSoundPlayer", "struct DragonOverlayView")
    external_tts = _block(source, "private func playExternalVoice", "private func speechParts")

    assert "POCKETDM_PIKA_TTS_URL" in status
    assert "Pika sidecar voice queued." in status
    assert "Bundled Pika chirp queued." in status
    assert "Muted; text only." in status
    assert "if let endpoint = Self.externalPikaTTSURL" in sound_player
    assert '"Generating Pika voice..."' in sound_player
    assert "let didPlay = await self.playExternalVoice" in sound_player
    assert "if !didPlay" in sound_player
    assert '"Pika voice fallback: bundled chirp."' in sound_player
    assert "self.play(sound, enabled: enabled)" in sound_player
    assert "HTTPURLResponse)?.statusCode == 200" in external_tts
    assert '"Pika voice sidecar returned no playable audio."' in external_tts
    # Sentence-streaming playback: speak per sentence for low time-to-first-audio.
    assert "Self.streamingSentences(from: line)" in external_tts
    assert "synthesizeSentence" in external_tts


def test_turn_taking_is_server_vad_driven_not_energy_metered() -> None:
    # The energy-meter turn detector (averagePower > -38 dB + 1.25 s quiet + 10 s
    # timeout) is REPLACED by server-side Silero VAD: the turn ends when the server
    # emits `final`, which calls finishVoiceConversation. Intent preserved: a turn must
    # still finalize on a pause — but the decision now lives in the VAD pipeline, not a
    # local dB meter, so these brittle/buggy local heuristics must be gone.
    source = _source()

    # Energy-meter machinery is fully removed.
    assert "currentMeterPower" not in source
    assert "scheduleVoiceAutoSendIfNeeded" not in source
    assert "$0 > -38" not in source
    assert "quietFor >= 1.25" not in source
    assert "elapsed >= 10.0" not in source
    assert ".averagePower(forChannel: 0)" not in source

    # The realtime turn now finalizes on the server's `final` frame.
    session = _block(source, "final class RealtimeVADStreamingSession", "@MainActor\nfinal class PetSoundPlayer")
    assert 'socket.send(.string(#"{"type":"start","sample_rate":16000,"vad":true}"#))' in session
    assert 'case "final":' in session
    assert "Task { @MainActor in onFinal(text) }" in session

    # The model finalizes the turn via the existing finishVoiceConversation on `final`.
    start_conv = _block(source, "func startVoiceConversation", "func stopVoiceConversation")
    assert "self?.finishVoiceConversation(transcript)" in start_conv


def test_learning_tts_keeps_language_target_speech_unprefixed_when_visible() -> None:
    source = _source()
    open_learning = _block(source, "func openLearning()", "func openJournal()")
    language_panel = _block(source, "struct LanguageCoachPanel", "struct AnimatedPetSprite")
    sound_row = _block(language_panel, "private var soundRow", "private func prompt")

    assert "message = \"Lesson mode opened." in open_learning
    assert "pikaText(" not in open_learning
    assert "speakPika" not in open_learning
    assert '"Lesson ready. Press Hear for clean phrase audio."' in open_learning
    assert "coach.speakCurrent()" in sound_row
    assert "coach.speakCurrent(slow: true)" in sound_row
    assert "pikaText" not in sound_row
    assert "speakPika" not in sound_row
