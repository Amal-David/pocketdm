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


def test_native_launch_defaults_to_pet_only_minimized() -> None:
    source = _source()
    model_init = _block(
        source,
        "init(client: PocketDMClient, launcher: GameLauncher, initialCharacter: CompanionCharacter)",
        "func refreshHealth() async",
    )
    controller_init = _block(
        source,
        "init(client: PocketDMClient, launcher: GameLauncher, character: CompanionCharacter, repoRoot: URL)",
        "func show()",
    )
    app_launch = _block(
        source,
        "func applicationDidFinishLaunching",
        "func applicationWillTerminate",
    )
    show = _block(source, "func show() {", "func showExpanded()")

    assert "@Published var minimized = true" in source
    assert "UserDefaults.standard.set(true, forKey: Self.petOnlyKey)" in model_init
    assert "setMinimized(model.minimized)" in controller_init
    assert controller_init.index("restoreFrame()") < controller_init.index(
        "setMinimized(model.minimized)"
    )
    assert "overlayController?.show()" in app_launch
    assert "showExpanded()" not in app_launch
    assert "model.setMinimized" not in show


def test_status_menu_exposes_lifecycle_actions_with_expected_labels() -> None:
    source = _source()
    menu = _block(source, "private func rebuildStatusMenu()", "@objc private func showPanelFromMenu")

    assert 'NSMenuItem(title: "Open Chat", action: #selector(showPanelFromMenu), keyEquivalent: "o")' in menu
    assert "show.target = self" in menu
    assert 'NSMenuItem(title: "Hide to Pet", action: #selector(showPetOnlyFromMenu), keyEquivalent: "m")' in menu
    assert "petOnly.target = self" in menu
    assert 'NSMenuItem(title: "Delete Pet Data...", action: #selector(resetPetDataFromMenu), keyEquivalent: "")' in menu
    assert "reset.target = self" in menu
    assert 'NSMenuItem(title: "Quit Pika", action: #selector(closeFromMenu), keyEquivalent: "q")' in menu
    assert "close.target = self" in menu


def test_status_menu_actions_drive_open_hide_quit_and_delete_paths() -> None:
    source = _source()
    open_action = _block(source, "@objc private func showPanelFromMenu()", "@objc private func showPetOnlyFromMenu")
    hide_action = _block(source, "@objc private func showPetOnlyFromMenu()", "@objc private func toggleSoundFromMenu")
    quit_action = _block(source, "@objc private func closeFromMenu()", "@objc private func resetPetDataFromMenu")
    delete_action = _block(source, "@objc private func resetPetDataFromMenu()", "private static func resetCompanionDefaults")
    reset_defaults = _block(source, "private static func resetCompanionDefaults()", "struct CompanionArguments")

    assert "overlayController?.showExpanded()" in open_action
    assert "rebuildStatusMenu()" in open_action
    assert "overlayController?.showPetOnly()" in hide_action
    assert "rebuildStatusMenu()" in hide_action
    assert "overlayController?.prepareClose()" in quit_action
    assert "NSApplication.shared.terminate(nil)" in quit_action
    assert quit_action.index("overlayController?.prepareClose()") < quit_action.index(
        "NSApplication.shared.terminate(nil)"
    )
    assert 'alert.addButton(withTitle: "Delete")' in delete_action
    assert 'alert.addButton(withTitle: "Cancel")' in delete_action
    assert "Self.resetCompanionDefaults()" in delete_action
    assert "overlayController?.prepareClose()" in delete_action
    assert "NSApplication.shared.terminate(nil)" in delete_action
    assert 'key.hasPrefix("PocketDMCompanion.")' in reset_defaults
    assert "defaults.removeObject(forKey: key)" in reset_defaults


def test_close_paths_prepare_pet_before_terminating() -> None:
    source = _source()
    controller_close = _block(source, "func prepareClose() {\n        model.prepareClose()", "var soundEnabled")
    model_close = _block(source, "func prepareClose() {\n        lastRequest = \"Close\"", "var careLine")
    view_close = _block(source, "private func closeCompanion()", "private var dragGesture")

    assert "model.prepareClose()" in controller_close
    assert 'lastRequest = "Close"' in model_close
    assert 'message = pikaText("Curling up. See you next check-in.")' in model_close
    assert "play(.close)" in model_close
    assert "setMood(.nap)" in model_close
    assert "model.prepareClose()" in view_close
    assert "NSApplication.shared.terminate(nil)" in view_close
    assert view_close.index("model.prepareClose()") < view_close.index(
        "NSApplication.shared.terminate(nil)"
    )


def test_pet_only_and_expanded_transitions_are_wired() -> None:
    source = _source()
    controller = _block(source, "final class DragonOverlayController", "private extension NSRect")
    model_transition = _block(source, "func setMinimized(_ value: Bool)", "func refreshMorningWeatherIfNeeded")
    view_body = _block(source, "var body: some View", "private var petOnlyBody")
    pet_only = _block(source, "private var petOnlyBody", "private var petControlsVisible")
    expanded_header = _block(source, "private func headerBar(isCompact: Bool)", "private var characterSettingsPanel")

    assert "func showExpanded()" in controller
    assert "model.setMinimized(false)" in controller
    assert "setMinimized(false, animated: false)" in controller
    assert "func showPetOnly()" in controller
    assert "model.setMinimized(true)" in controller
    assert "setMinimized(true, animated: false)" in controller
    assert "UserDefaults.standard.set(value, forKey: Self.petOnlyKey)" in model_transition
    assert "play(value ? .minimize : .open)" in model_transition
    assert "if model.minimized" in view_body
    assert "petOnlyBody" in view_body
    assert "expandedBody" in view_body
    assert ".animation(.spring(response: 0.26, dampingFraction: 0.78), value: model.minimized)" in view_body
    assert ".onChange(of: model.minimized)" in view_body
    assert "onSizeChange(minimized)" in view_body
    assert "model.setMinimized(false)" in pet_only
    assert "model.setMinimized(true)" in expanded_header


def test_mini_mode_and_evolve_are_wired() -> None:
    source = _source()
    controller = _block(source, "final class DragonOverlayController", "private extension NSRect")
    view_body = _block(source, "var body: some View", "private var petOnlyBody")
    settings = _block(source, "private var petOnlySettingsPanel", "private var expandedBody")

    # Mini is a sub-state of the minimized pet, added alongside the existing flag.
    assert "@Published var minimized = true" in source  # unchanged
    assert "@Published var miniMode" in source
    assert "func setMiniMode(_ value: Bool)" in source
    assert "func triggerEvolve()" in source
    assert 'UserDefaults.standard.set(value, forKey: Self.miniModeKey)' in source

    # Controller has a tiny window footprint and stays mini-aware on resize.
    assert "miniSize = NSSize" in controller
    assert "model.miniMode" in controller

    # The view nests a tiny pet, double-click restores it, and the size change is
    # pushed to the controller. Existing minimized wiring is preserved.
    assert "if model.minimized" in view_body
    assert "miniPetBody" in view_body
    assert ".onChange(of: model.miniMode)" in view_body
    assert "onSizeChange(model.minimized)" in view_body
    assert "EvolveGlow(trigger: model.evolvePulse)" in view_body
    assert ".onTapGesture(count: 2)" in source
    assert "model.setMiniMode(false)" in source  # double-click restore
    assert "model.setMiniMode(true)" in settings  # "Tiny" control

    # The evolve flash view exists.
    assert "struct EvolveGlow: View" in source

    # Mini is reachable from the menu bar (discoverable), not just the buried gear.
    menu = _block(source, "private func rebuildStatusMenu()", "@objc private func showPanelFromMenu")
    assert "#selector(toggleMiniFromMenu)" in menu
    assert '"Shrink to Tiny"' in menu
    assert "func toggleMini()" in controller
    assert "@objc private func toggleMiniFromMenu()" in source
