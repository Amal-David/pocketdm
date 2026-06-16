from __future__ import annotations

import array
import io
import math
import sys
import wave
from pathlib import Path

from app import pika_tts_server


ROOT = Path(__file__).resolve().parents[1]


def test_forced_pika_voice_bypasses_recent_reply_effect() -> None:
    source = (
        ROOT
        / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"
    ).read_text()

    assert "guard force || !recentlyPlayedMascotSound(at: now) else { return }" in source


def test_app_packager_includes_swiftpm_voice_resources() -> None:
    script = (ROOT / "macos/PocketDMCompanion/scripts/package_app.sh").read_text()

    assert 'resource_bundle_name="PocketDMCompanion_PocketDMCompanion.bundle"' in script
    assert 'cp -R "$resource_bundle" "$bundle/Contents/Resources/$resource_bundle_name"' in script


def test_signature_pika_voice_waveform_is_not_silent() -> None:
    audio = pika_tts_server.GeneratedChirpVoice().synthesize("Pikaa Pikaa!")

    with wave.open(io.BytesIO(audio), "rb") as wav:
        assert wav.getnchannels() == 1
        assert wav.getframerate() == pika_tts_server.DEFAULT_SAMPLE_RATE
        duration = wav.getnframes() / wav.getframerate()
        frames = wav.readframes(wav.getnframes())
        samples = array.array("h")
        samples.frombytes(frames)
        if sys.byteorder != "little":
            samples.byteswap()

    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
    assert 0.3 <= duration <= 2.0
    assert rms > 500


def test_native_companion_accepts_realtime_stt_url() -> None:
    source = (
        ROOT
        / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"
    ).read_text()
    launch_script = (ROOT / "macos/PocketDMCompanion/scripts/launch_app.sh").read_text()

    assert "--realtime-stt-url" in source
    assert "POCKETDM_REALTIME_STT_URL" in source
    assert "URLSession.shared.webSocketTask" in source
    assert "RealtimeVADStreamingSession" in source
    assert '"partial"' in source
    assert '"final"' in source
    assert "--realtime-stt-url" in launch_script
    assert "POCKETDM_REALTIME_STT_URL" in launch_script


def test_native_realtime_stt_streams_live_mic_into_vad_websocket() -> None:
    # Realtime STT no longer records a whole turn to a WAV and replays it. It now
    # streams the mic LIVE: an AVAudioEngine tap -> AVAudioConverter (16 kHz mono Int16)
    # -> raw PCM frames pushed into an open VAD-gated WebSocket. Record-then-replay must
    # be gone so the server's Silero VAD, not a client buffer, drives turn-taking.
    source = (
        ROOT
        / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"
    ).read_text()
    session = source[
        source.index("final class RealtimeVADStreamingSession"):
        source.index("@MainActor\nfinal class PetSoundPlayer")
    ]

    # Opens the VAD turn loop on the server.
    assert '#"{"type":"start","sample_rate":16000,"vad":true}"#' in session
    # Live capture + 16 kHz mono Int16 conversion.
    assert "audioEngine.inputNode" in session
    assert "installTap(onBus: 0" in session
    assert "AVAudioConverter(from: inputFormat, to: targetFormat)" in session
    assert "commonFormat: .pcmFormatInt16" in session
    assert "sampleRate: 16_000" in session
    # PCM frames pushed straight into the socket as they arrive.
    assert "outBuffer.int16ChannelData" in session
    assert "socket.send(.data(data))" in session
    # The record-then-replay realtime path is removed.
    assert "transcribeRealtimeRecording" not in source
    assert '#"{"type":"start","format":"wav","sample_rate":16000}"#' not in source


def test_demo_stack_launches_native_app_with_all_voice_models() -> None:
    script = (ROOT / "macos/PocketDMCompanion/scripts/pika_demo_stack.sh").read_text()

    assert "launch_companion()" in script
    assert "POCKETDM_ASSISTANT_LLAMA_MODEL" in script
    assert 'export POCKETDM_LLAMA_SERVER_URL="${POCKETDM_LLAMA_SERVER_URL:-${POCKETDM_ASSISTANT_LLAMA_URL:-http://127.0.0.1:8081}}"' in script
    assert 'export POCKETDM_ASSISTANT_LLAMA_URL="$POCKETDM_LLAMA_SERVER_URL"' in script
    assert 'export POCKETDM_ASSISTANT_LLAMA_MODEL="$POCKETDM_LLAMA_SERVER_MODEL"' in script
    assert "--pika-stt-url" in script
    assert 'POCKETDM_NEMOTRON_ASR_BACKEND=auto' in script
    assert 'POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND=pika-stt' in script
    assert 'POCKETDM_REALTIME_STT_URL:-http://127.0.0.1:7863/ws/transcribe' in script
    assert "--realtime-stt-url" in script
    assert "Nemotron ASR bridge" in script


def test_native_send_and_reply_sounds_are_mapped_to_resources() -> None:
    source = (
        ROOT
        / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"
    ).read_text()

    assert 'case .reply:\n            return ["chirp-reply", "pika-voice-reply"]' in source
    assert 'case .send:\n            return ["chirp-send", "pika-cc0-pep-1"]' in source


def test_native_voice_panel_surfaces_live_local_model_stack() -> None:
    source = (
        ROOT
        / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"
    ).read_text()

    assert "struct RuntimeStackStatus" in source
    assert "@Published var runtimeStackStatus" in source
    assert "func runtimeStackStatus() async -> RuntimeStackStatus" in source
    assert "llamaModelLabel(environment:" in source
    assert "modelsEndpoint(from:" in source
    assert "POCKETDM_ASSISTANT_LLAMA_MODEL" in source
    assert "POCKETDM_LLAMA_SERVER_MODEL" in source
    assert "POCKETDM_PIKA_STT_URL" in source
    assert "POCKETDM_REALTIME_STT_URL" in source
    assert "POCKETDM_PIKA_TTS_URL" in source
    assert 'Label(showingRuntimeStack ? "Hide stack" : "Stack details"' in source
    assert 'Text("Live local stack")' in source
    assert "runtimeStackPanel" in source
    assert "MiniCPM5" in source
    assert "Nemotron" in source
    assert "VoxCPM" in source


def test_native_voice_flow_has_opt_in_hands_free_conversation_loop() -> None:
    source = (
        ROOT
        / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"
    ).read_text()

    assert "@Published var handsFreeConversationEnabled" in source
    assert "func toggleHandsFreeConversation()" in source
    # Turn-taking is now server-VAD-driven: hands-free re-arms listening and the
    # WebSocket stays open for the next utterance; the old local energy-meter
    # auto-send loop is gone.
    assert "scheduleVoiceAutoSendIfNeeded" not in source
    assert "scheduleHandsFreeRestart(after:" in source
    assert "Realtime listening. Speak naturally; I send after a pause." in source
    assert "currentMeterPower" not in source
    assert "quietFor >= 1.25" not in source
    assert "elapsed >= 10.0" not in source
    assert "stopVoiceConversation(sendTranscript: true)" in source
    assert "toggleHandsFreeFromExpanded()" in source
    assert "func toggleHandsFreeFromExpanded()" in source
    assert "toggleRealtimeVoiceFromExpanded()" in source
    assert "toggleSingleTurnVoiceFromExpanded()" in source
    assert 'Image(systemName: model.handsFreeConversationEnabled ? "waveform.circle.fill" : "waveform.circle")' in source
    assert 'Image(systemName: model.isVoiceListening && !model.handsFreeConversationEnabled ? "stop.fill" : "mic.fill")' in source
    assert 'keyboardShortcut("l", modifiers: [.command, .option])' in source


def test_realtime_path_streams_live_instead_of_metered_recording() -> None:
    # Pause detection no longer relies on AVAudioRecorder dB metering. The realtime
    # path streams the live mic into the server's Silero VAD, and the non-realtime
    # fallback just records-and-POSTs (no metering needed). All metering APIs are gone.
    source = (
        ROOT
        / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"
    ).read_text()

    assert "isMeteringEnabled" not in source
    assert "updateMeters()" not in source
    assert "averagePower(forChannel: 0)" not in source
    # The realtime turn detector is the live VAD streaming session.
    assert "func startRealtimeStreaming(" in source
    assert "RealtimeVADStreamingSession(" in source
