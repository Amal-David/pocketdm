# PocketDM Submission Copy Kit

## One-Line Pitch

PocketDM is a tiny offline Dungeon Master with a native desktop companion that
reacts, helps, chirps, teaches quick language lessons, and rewards daily care.

## Short Description

PocketDM turns a small local model into a playable adventure game by splitting
the work cleanly: the model writes vivid prose and choices, while a deterministic
engine owns state, HP, inventory, validation, retries, and endings. The demo also
ships a native macOS companion that floats above the desktop. Pikachu starts as
a pet-only overlay, opens into chat and care controls on click, gives contextual
hints, plays original chirps, tracks Bond HP/Joy, and teaches beginner Spanish
and Mandarin with 100 words plus 100 sentences per language using local macOS
TTS.

## Consumer Explanation

Imagine a tiny adventure game that comes with a pet on your desktop. You play a
short quest, and the pet watches along, reacts to what happens, gives you hints,
and gets happier when you check in each day. It can also teach a few Spanish or
Mandarin phrases, say them out loud slowly, and quiz you. The technical trick is
that the AI only writes the magical parts; the game engine keeps the rules fair.

## Judge Framing

The product story is not "we made a model pretend to be a whole game." The story
is "we made a small model useful by giving it a narrow creative job and putting
strict software around it." The companion makes that visible: it is the playful
interface for hints, care, language practice, and proof that this can be more
than a chatbot in a browser.

Be honest in the final submission:

- The playable app works today with the scripted checkpoint backend.
- The native macOS companion is the demo front door.
- The language packs are comprehensive enough for a hackathon demo: 100 words
  and 100 sentences for Spanish, and the same for Mandarin.
- The final fine-tuned GGUF and judge/eval gates remain the highest-risk work.
- If the final GGUF is not green by recording time, show `Scripted` clearly and
  call it a playable checkpoint rather than a final model claim.

## Demo Voiceover Script

Target length: 90-120 seconds.

> This is PocketDM: a tiny offline Dungeon Master with a desktop companion.
>
> The first thing you see is not a chat window. It is the companion, living on
> top of the Mac. When I click it, it opens into the game helper: Bond HP, Joy,
> quick actions, and an Ask Pikachu field.
>
> The adventure itself is strict underneath. The model gets to write the scene
> and choices, but the engine owns HP, inventory, location, endings, and JSON
> validation. That keeps the tiny model from breaking the game.
>
> I can ask for a hint, and the companion answers using the current adventure
> state. I can pet it once per day to earn Bond HP. It chirps, reacts, and goes
> back to pet-only mode when I minimize it.
>
> I also added a language coach. Spanish and Mandarin each ship with 100 words
> and 100 sentences. The companion speaks phrases with local macOS voices, slows
> them down, gives pronunciation tips, and quizzes me.
>
> The local runtime path is built for llama.cpp and GGUF. The final model/eval
> gate is still the hard part, so this clip is honest about the backend state:
> scripted checkpoint when the final model is not ready, llama.cpp when it is.
>
> The model writes the magic. The engine keeps the rules. The companion keeps
> you coming back.

## Social Post Draft

Built PocketDM for Build Small: a tiny offline Dungeon Master with a native
desktop pet. The model writes the adventure flavor, the engine keeps state and
validation strict, and Pikachu floats above the Mac to give hints, chirp, earn
Bond HP, and teach Spanish/Mandarin with local TTS.

The fun part: the demo does not start as another chat box. It starts as a living
desktop companion.

## README Submission Blurb

PocketDM is a custom Gradio adventure game plus a native macOS companion. The
model writes compact story turns, while the deterministic engine owns state,
validation, HP, inventory, endings, and fallback repair. The companion floats
above the desktop as a pet-only Pikachu by default, expands into chat and care
controls, plays original chirps, tracks Bond HP/Joy, and includes a local
Spanish/Mandarin language coach with 100 words and 100 sentences per language.

## Final Form Checklist

- Record the native companion as the first visual.
- Show the browser/web UI only after the desktop pet hook is clear.
- Use a white or light desktop moment to prove the sprite has no dark outline.
- Include sound, then mute, so controls feel intentional.
- Show one hint/status answer tied to adventure state.
- Show one Pet reward and one Learn reward.
- Show Spanish TTS and Mandarin pinyin/TTS.
- Show backend state honestly.
- Show test and pack-count receipts.
- End with URLs for Space, model, dataset/traces, field notes, and social post.
