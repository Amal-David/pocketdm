const state = {
  sessionId: null,
  lastTurn: null,
  voiceEnabled: true,
  narrationAudio: null,
  typewriterFrame: null,
  isBusy: false,
  isTyping: false,
};

const els = {
  genre: document.querySelector("#genre"),
  premise: document.querySelector("#premise"),
  newAdventure: document.querySelector("#new-adventure"),
  narration: document.querySelector("#narration"),
  choices: document.querySelector("#choices"),
  sceneLabel: document.querySelector("#scene-label"),
  hp: document.querySelector("#hp"),
  turnCount: document.querySelector("#turn-count"),
  location: document.querySelector("#location"),
  inventory: document.querySelector("#inventory"),
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
els.voiceToggle.addEventListener("click", () => {
  state.voiceEnabled = !state.voiceEnabled;
  els.voiceToggle.setAttribute("aria-pressed", String(state.voiceEnabled));
  if (!state.voiceEnabled && state.narrationAudio) {
    state.narrationAudio.pause();
  }
});

async function startAdventure() {
  setBusy(true);
  try {
    const payload = await postJSON("/api/start", {
      genre: els.genre.value,
      premise: els.premise.value,
    });
    state.sessionId = payload.session_id;
    renderTurn(payload.turn, payload.state);
    dragonSay(payload.assistant, { fire: true });
  } catch (error) {
    dragonSay(`I lost the trail: ${error.message}`, { fire: true });
  } finally {
    setBusy(false);
  }
}

async function choose(action) {
  if (!state.sessionId || !state.lastTurn || state.lastTurn.is_ending) return;
  setBusy(true);
  try {
    const payload = await postJSON("/api/choose", {
      session_id: state.sessionId,
      action,
    });
    renderTurn(payload.turn, payload.state);
    dragonSay(payload.assistant, { fire: payload.turn.is_ending });
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
  els.sceneLabel.textContent = turn.is_ending
    ? `Ending: ${turn.ending_type || "complete"}`
    : `Turn ${gameState.turn_count} · ${gameState.location}`;
  typeText(els.narration, turn.narration);
  renderChoices(turn);
  els.hp.textContent = `${gameState.hp}/10`;
  els.turnCount.textContent = String(gameState.turn_count);
  els.location.textContent = gameState.location;
  els.inventory.textContent = gameState.inventory.length ? gameState.inventory.join(", ") : "-";
  playNarration(turn.narration);
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
  speak(text);
}

function speak(text) {
  if (!("speechSynthesis" in window)) return;
  window.speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.rate = 0.95;
  utterance.pitch = 1.12;
  window.speechSynthesis.speak(utterance);
}

async function playNarration(text) {
  if (!state.voiceEnabled || !state.sessionId) return;
  try {
    const response = await fetch("/api/tts", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ session_id: state.sessionId, text }),
    });
    if (!response.ok) return;
    const blob = await response.blob();
    if (state.narrationAudio) state.narrationAudio.pause();
    state.narrationAudio = new Audio(URL.createObjectURL(blob));
    await state.narrationAudio.play();
  } catch (_error) {
    // Voice is a progressive enhancement; text-first play must never block.
  }
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
