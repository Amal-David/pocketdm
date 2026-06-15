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
    assert 'cp -R "$resource_bundle" "$bundle/$resource_bundle_name"' in script


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
    assert "RealtimeSTTFrame" in source
    assert '"partial"' in source
    assert '"final"' in source
    assert "--realtime-stt-url" in launch_script
    assert "POCKETDM_REALTIME_STT_URL" in launch_script


def test_native_realtime_stt_uses_chunked_websocket_protocol() -> None:
    source = (
        ROOT
        / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"
    ).read_text()
    realtime = source[
        source.index("private static func transcribeRealtimeRecording"):
        source.index("private static func transcribeEndpoint")
    ]

    assert '#"{"type":"start","format":"wav","sample_rate":16000}"#' in realtime
    assert "let chunkSize = 64 * 1024" in realtime
    assert "while offset < audio.count" in realtime
    assert "try await socket.send(.data(Data(audio[offset..<end])))" in realtime
    assert '#"{"type":"end"}"#' in realtime


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
    assert "scheduleVoiceAutoSendIfNeeded()" in source
    assert "scheduleHandsFreeRestart(after:" in source
    assert "Realtime listening. Speak naturally; I send after a pause." in source
    assert "currentMeterPower()" in source
    assert "quietFor >= 1.25" in source
    assert "elapsed >= 10.0" in source
    assert '"I hear you..."' in source
    assert "stopVoiceConversation(sendTranscript: true)" in source
    assert "toggleHandsFreeFromExpanded()" in source
    assert "func toggleHandsFreeFromExpanded()" in source
    assert "toggleRealtimeVoiceFromExpanded()" in source
    assert "toggleSingleTurnVoiceFromExpanded()" in source
    assert 'Image(systemName: model.handsFreeConversationEnabled ? "waveform.circle.fill" : "waveform.circle")' in source
    assert 'Image(systemName: model.isVoiceListening && !model.handsFreeConversationEnabled ? "stop.fill" : "mic.fill")' in source
    assert 'keyboardShortcut("l", modifiers: [.command, .option])' in source


def test_local_stt_recorder_enables_metering_for_pause_detection() -> None:
    source = (
        ROOT
        / "macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift"
    ).read_text()

    assert "recorder.isMeteringEnabled = true" in source
    assert "localRecorder.updateMeters()" in source
    assert "localRecorder.averagePower(forChannel: 0)" in source
