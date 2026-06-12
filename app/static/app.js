const state = {
  sessionId: null,
  lastTurn: null,
  voiceEnabled: true,
  narrationAudio: null,
  narrationAbortController: null,
  narrationObjectUrl: null,
  narrationRequestId: 0,
  typewriterFrame: null,
  isBusy: false,
  isTyping: false,
  audioUnlocked: false,
  currentVoice: "auto",
};

const els = {
  genre: document.querySelector("#genre"),
  voice: document.querySelector("#voice"),
  premise: document.querySelector("#premise"),
  newAdventure: document.querySelector("#new-adventure"),
  narration: document.querySelector("#narration"),
  choices: document.querySelector("#choices"),
  sceneLabel: document.querySelector("#scene-label"),
  hp: document.querySelector("#hp"),
  turnCount: document.querySelector("#turn-count"),
  location: document.querySelector("#location"),
  inventory: document.querySelector("#inventory"),
  voiceState: document.querySelector("#voice-state"),
  backendState: document.querySelector("#backend-state"),
  proofBackend: document.querySelector("#proof-backend"),
  proofModel: document.querySelector("#proof-model"),
  proofVoice: document.querySelector("#proof-voice"),
  proofNetwork: document.querySelector("#proof-network"),
  diceRoll: document.querySelector("#dice-roll"),
  freeformForm: document.querySelector("#freeform-form"),
  freeformInput: document.querySelector("#freeform-input"),
  freeformButton: document.querySelector("#freeform-form button"),
  dragonForm: document.querySelector("#dragon-form"),
  dragonInput: document.querySelector("#dragon-input"),
  dragonSpeech: document.querySelector("#dragon-speech"),
  dragonAvatar: document.querySelector("#dragon-avatar"),
  voiceToggle: document.querySelector("#voice-toggle"),
};

els.newAdventure.addEventListener("click", startAdventure);
els.freeformForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const action = els.freeformInput.value.trim();
  if (action) choose(action);
  els.freeformInput.value = "";
});
els.dragonForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = els.dragonInput.value.trim();
  if (message) await askDragon(message);
  els.dragonInput.value = "";
});
els.dragonAvatar.addEventListener("click", () => askDragon("hint"));
els.location.addEventListener("click", () => askDragon("status"));
els.voiceToggle.addEventListener("click", () => {
  state.voiceEnabled = !state.voiceEnabled;
  els.voiceToggle.setAttribute("aria-pressed", String(state.voiceEnabled));
  els.voiceToggle.textContent = state.voiceEnabled ? "Voice" : "Muted";
  if (!state.voiceEnabled) {
    stopAllAudio();
    els.proofVoice.textContent = `${voiceLabel(state.currentVoice)} muted`;
  }
});

async function startAdventure() {
  state.audioUnlocked = true;
  stopAllAudio();
  setBusy(true);
  try {
    const payload = await postJSON("/api/start", {
      genre: els.genre.value,
      voice: els.voice.value,
      premise: els.premise.value,
    });
    state.sessionId = payload.session_id;
    renderTurn(payload.turn, payload.state);
    dragonSay(payload.assistant, { fire: true, speak: false });
    focusAdventureOnSmallScreens();
  } catch (error) {
    dragonSay(`I lost the trail: ${error.message}`, { fire: true });
  } finally {
    setBusy(false);
  }
}

async function choose(action) {
  if (!state.sessionId || !state.lastTurn || state.lastTurn.is_ending) return;
  stopAllAudio();
  setBusy(true);
  try {
    const payload = await postJSON("/api/choose", {
      session_id: state.sessionId,
      action,
    });
    renderTurn(payload.turn, payload.state);
    dragonSay(payload.assistant, { fire: payload.turn.is_ending, speak: false });
  } catch (error) {
    dragonSay(`That turn fizzled: ${error.message}`, { fire: true });
  } finally {
    setBusy(false);
  }
}

async function askDragon(message) {
  if (!state.sessionId) {
    dragonSay("Start a tale first, then I can hover with useful opinions.", { fire: true });
    return;
  }
  try {
    const payload = await postJSON("/api/assistant", {
      session_id: state.sessionId,
      message,
    });
    dragonSay(payload.reply, { fire: /fire|flame|scorch|victory/i.test(payload.reply) });
  } catch (error) {
    dragonSay(`My tiny scroll jammed: ${error.message}`, { fire: true });
  }
}

function renderTurn(turn, gameState) {
  state.lastTurn = turn;
  state.currentVoice = gameState.voice;
  els.sceneLabel.textContent = turn.is_ending
    ? `Ending: ${turn.ending_type || "complete"}`
    : `Turn ${gameState.turn_count} · ${gameState.location}`;
  rollDice();
  typeText(els.narration, turn.narration);
  renderChoices(turn);
  renderHp(gameState.hp);
  els.turnCount.textContent = String(gameState.turn_count);
  els.location.textContent = gameState.location;
  els.inventory.textContent = gameState.inventory.length ? gameState.inventory.join(", ") : "-";
  els.voiceState.textContent = voiceLabel(gameState.voice);
  els.backendState.textContent = gameState.backend === "llama.cpp" ? "llama.cpp" : "Scripted";
  renderRuntimeProof(gameState);
  playNarration(turn.narration);
}

function renderRuntimeProof(gameState) {
  const isLlama = gameState.backend === "llama.cpp";
  els.proofBackend.textContent = isLlama ? "llama.cpp active" : "Scripted demo";
  els.proofModel.textContent = gameState.model || (isLlama ? "2B Q4 GGUF" : "Validated engine");
  els.proofVoice.textContent = `${voiceLabel(gameState.voice)} voice`;
  els.proofNetwork.textContent = formatTurnSpeed(gameState);
}

function focusAdventureOnSmallScreens() {
  if (!window.matchMedia("(max-width: 760px)").matches) return;
  requestAnimationFrame(() => {
    document.querySelector(".scroll")?.scrollIntoView({
      block: "start",
      behavior: "smooth",
    });
  });
}

function voiceLabel(voice) {
  return {
    dungeon: "Dungeon",
    wood: "Wood",
    starship: "Starship",
    lore: "Lore Narrator",
  }[voice] || "Auto";
}

function formatTurnSpeed(gameState) {
  if (gameState.backend !== "llama.cpp") return "Scripted: no model speed";
  const rate = Number(gameState.last_turn_tokens_per_second || 0);
  const seconds = Number(gameState.last_turn_seconds || 0);
  if (!rate || !seconds) return "No external inference";
  return `${rate.toFixed(1)} est tok/s · ${seconds.toFixed(2)}s`;
}

function renderHp(hp) {
  const label = document.createElement("span");
  label.className = "hp-label";
  label.textContent = `${hp}/10`;
  const hearts = document.createElement("span");
  hearts.className = "heart-row";
  for (let index = 1; index <= 10; index += 1) {
    const heart = document.createElement("span");
    heart.className = index <= hp ? "heart" : "heart is-empty";
    heart.textContent = "♥";
    hearts.append(heart);
  }
  els.hp.replaceChildren(label, hearts);
}

function rollDice() {
  els.diceRoll.classList.remove("is-rolling");
  void els.diceRoll.offsetWidth;
  els.diceRoll.classList.add("is-rolling");
}

function renderChoices(turn) {
  els.choices.replaceChildren();
  turn.choices.forEach((choice) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = choice;
    button.addEventListener("click", () => choose(choice));
    els.choices.append(button);
  });
  updateControls();
}

function typeText(target, text) {
  if (state.typewriterFrame) {
    cancelAnimationFrame(state.typewriterFrame);
    state.typewriterFrame = null;
  }

  target.textContent = "";
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    target.textContent = text;
    state.isTyping = false;
    updateControls();
    return;
  }

  state.isTyping = true;
  updateControls();
  const chars = Array.from(text);
  let index = 0;
  const step = () => {
    target.textContent = chars.slice(0, index).join("");
    index += 4;
    if (index <= chars.length + 1) {
      state.typewriterFrame = requestAnimationFrame(step);
      return;
    }
    state.typewriterFrame = null;
    state.isTyping = false;
    updateControls();
  };
  step();
}

function dragonSay(text, options = {}) {
  els.dragonSpeech.textContent = text;
  if (options.fire) {
    els.dragonAvatar.classList.remove("is-fire");
    void els.dragonAvatar.offsetWidth;
    els.dragonAvatar.classList.add("is-fire");
  }
  if (options.speak === false) return;
  speak(text);
}

function speak(text) {
  if (!state.voiceEnabled) return;
  if (!("speechSynthesis" in window)) return;
  stopNarration();
  window.speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.rate = 0.95;
  utterance.pitch = 1.12;
  window.speechSynthesis.speak(utterance);
}

async function playNarration(text) {
  if (!state.voiceEnabled || !state.sessionId) return;
  stopNarration();
  if ("speechSynthesis" in window) window.speechSynthesis.cancel();

  const requestId = state.narrationRequestId + 1;
  state.narrationRequestId = requestId;
  const sessionId = state.sessionId;
  const voice = state.currentVoice;
  const controller = new AbortController();
  state.narrationAbortController = controller;

  try {
    const response = await fetch("/api/tts", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ session_id: state.sessionId, text }),
      signal: controller.signal,
    });
    if (!isCurrentNarration(requestId, sessionId)) return;

    if (response.status === 204) {
      els.proofVoice.textContent = `${voiceLabel(voice)} TTS unavailable`;
      return;
    }
    if (!response.ok) {
      els.proofVoice.textContent = `${voiceLabel(voice)} voice pending`;
      return;
    }
    const blob = await response.blob();
    if (!isCurrentNarration(requestId, sessionId)) return;

    const objectUrl = URL.createObjectURL(blob);
    const audio = new Audio(objectUrl);
    state.narrationObjectUrl = objectUrl;
    state.narrationAudio = audio;
    audio.addEventListener(
      "ended",
      () => {
        if (state.narrationAudio !== audio) return;
        clearNarrationAudio();
      },
      { once: true },
    );
    await state.narrationAudio.play();
    if (isCurrentNarration(requestId, sessionId)) {
      els.proofVoice.textContent = `${voiceLabel(voice)} voice on`;
    }
  } catch (_error) {
    if (controller.signal.aborted) return;
    els.proofVoice.textContent = state.audioUnlocked
      ? `${voiceLabel(voice)} click to unmute`
      : `${voiceLabel(voice)} voice gated`;
  } finally {
    if (state.narrationAbortController === controller) {
      state.narrationAbortController = null;
    }
  }
}

function stopAllAudio() {
  stopNarration();
  if ("speechSynthesis" in window) window.speechSynthesis.cancel();
}

function stopNarration() {
  state.narrationRequestId += 1;
  if (state.narrationAbortController) {
    state.narrationAbortController.abort();
    state.narrationAbortController = null;
  }
  clearNarrationAudio();
}

function clearNarrationAudio() {
  if (state.narrationAudio) {
    state.narrationAudio.pause();
    state.narrationAudio.removeAttribute("src");
    state.narrationAudio.load();
    state.narrationAudio = null;
  }
  if (state.narrationObjectUrl) {
    URL.revokeObjectURL(state.narrationObjectUrl);
    state.narrationObjectUrl = null;
  }
}

function isCurrentNarration(requestId, sessionId) {
  return requestId === state.narrationRequestId && sessionId === state.sessionId;
}

async function postJSON(url, payload) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }
  return response.json();
}

function setBusy(isBusy) {
  state.isBusy = isBusy;
  updateControls();
}

function updateControls() {
  const turnEnded = Boolean(state.lastTurn && state.lastTurn.is_ending);
  const turnLocked = state.isBusy || state.isTyping || turnEnded;
  els.newAdventure.disabled = state.isBusy;
  els.freeformInput.disabled = turnLocked;
  els.freeformButton.disabled = turnLocked;
  [...els.choices.querySelectorAll("button")].forEach((button) => {
    button.disabled = turnLocked;
  });
}
