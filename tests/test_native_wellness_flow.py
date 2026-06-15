from __future__ import annotations

import re
from pathlib import Path


MAIN_SWIFT = Path("macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift")


def _source() -> str:
    return MAIN_SWIFT.read_text()


def _block(source: str, start: str, end: str) -> str:
    match = re.search(rf"{re.escape(start)}.*?{re.escape(end)}", source, re.DOTALL)
    assert match is not None, f"Could not find Swift block from {start!r} to {end!r}"
    return match.group(0)


def test_daily_wellness_actions_stay_ordered_one_at_a_time() -> None:
    source = _source()
    enum_block = _block(source, "enum DailyWellnessAction", "struct MorningWeatherReport")
    cases = re.findall(r"case (\w+) = (\d+)", enum_block)

    assert cases == [
        ("water", "1"),
        ("stand", "2"),
        ("walk", "4"),
        ("affirm", "8"),
    ]

    selector = _block(
        source,
        "private var nextIncompleteDailyWellnessAction",
        "private var dailyEmotionWheelFeeling",
    )
    assert "DailyWellnessAction.allCases.first" in selector
    assert "dailyWellnessMask & $0.rawValue == 0" in selector


def test_water_completion_says_it_drinks_water_and_awards_health_once() -> None:
    source = _source()
    enum_block = _block(source, "enum DailyWellnessAction", "struct MorningWeatherReport")
    completion = _block(source, "func completeDailyWellness", "func spinEmotionWheel")

    assert 'return "I drank water."' in enum_block
    assert "guard let expected = nextIncompleteDailyWellnessAction" in completion
    assert "guard expected == action" in completion
    assert completion.index("guard expected == action") < completion.rindex(
        "companionHP = min(10, companionHP + 1)"
    )
    assert 'var body = "\\(action.spokenLine) Health +1."' in completion
    assert "awardCompanionHealth(action == .walk ? 50 : 40)" in completion


def test_affirmation_button_counts_wellness_affirm_only_when_it_is_next() -> None:
    source = _source()
    affirmation = _block(source, "func playAffirmation", "func completeDailyWellness")

    assert "dailyAffirmationMask |= affirmation.rawValue" in affirmation
    assert "if nextIncompleteDailyWellnessAction == .affirm" in affirmation
    assert "dailyWellnessMask |= DailyWellnessAction.affirm.rawValue" in affirmation
    assert "companionHP = min(10, companionHP + 1)" in affirmation
    assert "awardCompanionHealth(50)" in affirmation


def test_wellness_cheer_accepts_only_the_active_daily_action() -> None:
    source = _source()
    accept = _block(source, "func acceptCheerBubble", "func dismissCheerBubble")
    prompt = _block(source, "private func showWellnessBreakIfReady", "private func showCheerIfReady")

    assert "let wellnessAction = DailyWellnessAction(rawValue: cheerWellnessActionRaw)" in accept
    assert "completeDailyWellness(action)" in accept
    assert "Desk break logged: water, stand, and walk watch accepted" not in accept
    assert "guard let action = nextIncompleteDailyWellnessAction else { return false }" in prompt
    assert "cheerWellnessActionRaw = action.rawValue" in prompt


def test_chat_and_voice_wellness_phrases_complete_native_wellness_actions_first() -> None:
    source = _source()
    ask = _block(source, "func ask(", "func acceptCheerBubble")
    classifier = _block(source, "private func wellnessAction", "private func isHintPrompt")

    assert "if let action = wellnessAction(from: prompt)" in ask
    assert "completeDailyWellness(action, recordUserMessage: false)" in ask
    assert ask.index("wellnessAction(from: prompt)") < ask.index("handlesCare(prompt)")
    assert ask.index("completeDailyWellness(action, recordUserMessage: false)") < ask.index("client.assistantReply")
    for phrase in [
        "i drank water",
        "drink water",
        "stood up",
        "stand up",
        "i walked",
        "short walk",
        "affirm me",
        "daily affirmation",
    ]:
        assert phrase in classifier


def test_emotion_wheel_persists_one_daily_selected_feeling() -> None:
    source = _source()
    spin = _block(source, "func spinEmotionWheel", "private func finishMorningWeatherAffirmation")
    persist = _block(source, "private func persistCare", "private func handlesCare")
    reset = _block(source, "private func syncDailyCombo", "private func recordRecoveryScene")

    assert "dailyEmotionWheelDate = today" in spin
    assert "dailyEmotionWheelRaw = next.rawValue" in spin
    assert "PetFeeling.allCases.randomElement()" in spin
    assert 'recordEmotionScene(feeling: next, trigger: "emotion wheel")' in spin
    assert "UserDefaults.standard.set(dailyEmotionWheelDate" in persist
    assert "UserDefaults.standard.set(dailyEmotionWheelRaw" in persist
    assert "if dailyEmotionWheelDate != today" in reset
    assert "dailyEmotionWheelRaw = 0" in reset


def test_expanded_chat_defaults_to_pet_first_chat_with_tools_gated() -> None:
    source = _source()
    expanded = _block(source, "private var expandedBody", "private var expandedPetStage")
    chat_panel = _block(source, "private var expandedChatPanel", "private var expandedPetStage")
    pet_stage = _block(source, "private var expandedPetStage", "private var careStatusPanel")
    daily_nudge = _block(source, "private var dailyCareNudge", "private var legacyHealthBar")
    quick_actions = _block(source, "private var expandedQuickActions", "private var modeControls")
    input_row = _block(source, "private func inputRow", "private var soundButton")

    assert "careStatusPanel" not in expanded
    assert "expandedChatPanel" in expanded
    assert "expandedPetStage" in chat_panel
    assert "gameHealthBar" in pet_stage
    assert "dailyCareNudge" in pet_stage
    assert chat_panel.index("expandedPetStage") < chat_panel.index(
        "chatTranscript(isCompact: false)"
    )
    assert "chatTranscript(isCompact: false)" in chat_panel
    assert "companionHealthHUD" not in chat_panel
    assert "inputRow(isCompact: false)" in chat_panel
    assert "expandedQuickActions" in chat_panel
    assert "if showingDemoTools" in chat_panel
    assert "dailyCarePromptPanel" in chat_panel
    assert "voiceConversationPanel" in chat_panel
    assert "gameActionPanel" in chat_panel
    assert "frame(minWidth: 500, maxWidth: .infinity" in expanded
    assert "model.completeDailyWellness(action)" in daily_nudge
    assert "model.spinEmotionWheel()" in daily_nudge
    assert "model.healthValueLine" in source
    assert "if !model.isVoiceListening" not in quick_actions
    assert 'Image(systemName: "book.fill")' in quick_actions
    assert 'Image(systemName: showingDemoTools ? "chevron.up" : "slider.horizontal.3")' in quick_actions
    assert "model.openLearning()" in quick_actions
    assert "toggleRealtimeVoiceFromExpanded()" in input_row
    assert "toggleSingleTurnVoiceFromExpanded()" in input_row
    assert 'Image(systemName: model.handsFreeConversationEnabled ? "waveform.circle.fill" : "waveform.circle")' in input_row
    assert 'Image(systemName: model.isVoiceListening && !model.handsFreeConversationEnabled ? "stop.fill" : "mic.fill")' in input_row


def test_expanded_chat_keeps_routine_details_out_of_default_path() -> None:
    source = _source()
    chat_panel = _block(source, "private var expandedChatPanel", "private var expandedPetStage")
    voice_panel = _block(source, "private var voiceConversationPanel", "private var runtimeStackPanel")

    assert chat_panel.index("if showingDemoTools") < chat_panel.index("voiceConversationPanel")
    assert chat_panel.index("if showingDemoTools") < chat_panel.index("gameActionPanel")
    assert 'Text(model.isVoiceListening ? "Listening" : "Voice")' in voice_panel
    assert 'Label(showingDailyDetails ? "Less" : "Routine"' in voice_panel
    assert "if showingDailyDetails" in voice_panel
    assert 'Text("\\(affirmation.title): \\(affirmation.line)")' in voice_panel
    assert "beginVoiceFromExpanded(mode: .dailyCheckIn)" in voice_panel
    assert "toggleHandsFreeFromExpanded()" in voice_panel


def test_expanded_chat_uses_persisted_scrollable_transcript() -> None:
    source = _source()
    declarations = _block(source, "final class DragonOverlayModel", "private let client")
    ask = _block(source, "func ask(", "func acceptCheerBubble")
    transcript = _block(source, "private func chatTranscript", "private var dailyCarePromptPanel")

    assert "struct CompanionChatMessage" in source
    assert 'private static let chatMessagesKey = "PocketDMCompanion.chatMessages"' in declarations
    assert "@Published var chatMessages = DragonOverlayModel.loadChatMessages()" in declarations
    assert "private static func loadChatMessages()" in declarations
    assert "private func appendChatMessage" in source
    assert "private func updateChatMessage" in source
    assert "private func persistChatMessages" in source
    assert "appendChatMessage(.user, requestText)" in ask
    assert "let assistantMessageID = appendChatMessage(.assistant, message)" in ask
    assert "updateChatMessage(id: assistantMessageID, text: message)" in ask
    assert "ScrollViewReader" in transcript
    assert "ScrollView(.vertical, showsIndicators: true)" in transcript
    assert "ForEach(model.chatMessages)" in transcript
    assert "scrollToLatestChatMessage" in transcript
    assert "model.lastRequest" not in transcript


def test_voice_start_stays_expanded_without_collapsing() -> None:
    source = _source()
    helper = _block(source, "private func beginVoiceFromExpanded", "private func toggleSingleTurnVoiceFromExpanded")

    # Clicking the mic from the expanded panel must NOT collapse it to pet-only.
    assert "model.startVoiceConversation(mode: mode)" in helper
    assert "model.toggleHandsFreeConversation()" in helper
    assert "model.setMinimized(true)" not in helper
    assert "DispatchQueue.main.asyncAfter" not in helper


def test_companion_health_uses_3000_point_decay_loop() -> None:
    source = _source()
    declarations = _block(source, "final class DragonOverlayModel", "private let client")
    health = _block(source, "private func startHealthLoop", "private func startCheerLoop")
    ask = _block(source, "func ask(", "func acceptCheerBubble")

    assert 'private static let companionHealthKey = "PocketDMCompanion.companionHealth"' in declarations
    assert "private static let maxCompanionHealth = 3000" in declarations
    assert "private static let healthDecayAmount = 5" in declarations
    assert "private static let healthDecaySeconds: UInt64 = 5" in declarations
    assert "startHealthLoop()" in source
    assert "try? await Task.sleep(nanoseconds: Self.healthDecaySeconds * 1_000_000_000)" in health
    assert "companionHealth - Self.healthDecayAmount" in health
    assert "min(Self.maxCompanionHealth, max(0, companionHealth + amount))" in health
    assert "awardCompanionHealth(30)" in ask


def test_learning_and_journal_controls_use_flexible_layouts() -> None:
    source = _source()
    journal = _block(source, "struct PetJournalPanel", "private var pageContent")
    language = _block(source, "private var packPicker", "private var lessonCard")

    assert "LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)" in journal
    assert "LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]" in language
    assert ".frame(width: 210, height: 58)" not in language


def test_native_overlay_caps_expanded_panel_to_visible_screen() -> None:
    source = _source()
    controller = _block(source, "final class DragonOverlayController", "final class FloatingDragonPanel")

    assert "private static let expandedSize = NSSize(width: 620, height: 620)" in controller
    assert "private static let expandedMinimumSize = NSSize(width: 520, height: 430)" in controller
    assert "private static let expandedMinimumSize" in controller
    assert "fittedSize(" in controller
    assert "visibleFrame.width - 16" in controller
    assert "visibleFrame.height - 48" in controller


def test_pet_hover_settings_stay_stable_while_panel_is_open() -> None:
    source = _source()
    pet_only = _block(source, "private var petOnlyBody", "private var petControlsVisible")
    visibility = _block(source, "private var petControlsVisible", "private var petHoverControls")

    assert "showingSettings = false" not in pet_only
    assert "petHovering || petControlsHovering || showingSettings" in visibility


def test_pet_only_mode_has_room_for_large_sprite_and_expands_on_tap() -> None:
    source = _source()
    controller = _block(source, "final class DragonOverlayController", "private let panel")
    pet_only = _block(source, "private var petOnlyBody", "private var petControlsVisible")
    sprite_button = pet_only.split("} label: {", maxsplit=1)[0]

    assert "private static let minimizedSize = NSSize(width: 216, height: 224)" in controller
    assert "frame(width: 204, height: 204)" in pet_only
    assert "frame(width: 216, height: 224)" in pet_only
    assert "petHovering ? 190 : 182" in pet_only
    assert "model.setMinimized(false)" in sprite_button
    assert "model.acceptCheerBubble()" not in sprite_button
