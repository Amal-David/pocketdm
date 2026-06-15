# Pika Sound Sources

## Product Rule

Do not bundle ripped or unofficial Pokémon/Pikachu voice clips. The desktop pet
can show "Pika pika" in text, but the audio layer should use original generated
chirps, CC0 game SFX, or a properly licensed/consented voice recipe.

The product should not chase exact anime/game audio. Pikachu's official voice
is a performed character voice, and many searchable "Pikachu sound effect"
downloads are ripped media or unclear reuploads. Treat those as reference only,
not bundle candidates.

## Active Pika Voice Effects

The native app now uses original generated WAV effects for mascot speech cues.
These are synthesized locally, not copied from official character audio and not
system TTS.

Imported files:

- `pika-voice-reply.wav`
- `pika-voice-question.wav`
- `pika-voice-excited.wav`
- `pika-voice-electric.wav`
- `pika-voice-soft.wav`

Current use:

- reply: short "pika" voice cue
- question/error: rising "pika" cue
- happy/reward: bright doubled cue
- hyper/electric: bright cue with synthetic sparkle
- nap/rest: softer lower cue

## Bundled CC0 Assets

Source: Kenney, "63 Digital sound effects (lasers, phasers, space etc.)" on
OpenGameArt:
https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc

License: CC0. Credit to `Kenney.nl` is appreciated by the author but not
mandatory.

Imported files:

- `pepSound1.mp3` -> `pika-cc0-pep-1.mp3`
- `pepSound2.mp3` -> `pika-cc0-pep-2.mp3`
- `powerUp2.mp3` -> `pika-cc0-power-up.mp3`
- `zap1.mp3` -> `pika-cc0-zap.mp3`

Current use:

- `pika-cc0-pep-1.mp3`: message-send accent.
- `pika-cc0-pep-2.mp3`: open and pet-touch accent.
- `pika-cc0-power-up.mp3`: fallback for minimize/close transitions.
- `pika-cc0-zap.mp3`: fallback electric accent for hyper/spark reactions.

The primary Pika reply, question, happy, hyper, and rest sounds still use
original generated WAVs. CC0 assets are supporting interface/electric texture,
not the mascot's voice identity.

Additional researched sources:

- Best immediate bundle path:
  keep the five generated `pika-voice-*.wav` files as the mascot voice, then
  layer CC0 Kenney/OpenGameArt effects for UI, zaps, rewards, and motion.
  This avoids a public-repo dependency on unofficial Pikachu clips.
- Kenney UI Audio:
  https://kenney.nl/assets/ui-audio
  License: Creative Commons CC0. Good fit for button clicks, toggles, switch
  states, message-send, compact expand, mute/unmute, and close affordances.
- Kenney Digital Audio:
  https://kenney.nl/assets/digital-audio
  License: Creative Commons CC0. Good fit for laser, zap, and sparkle accents
  that should read as electric energy rather than speech.
- Kenney Sci-fi Sounds:
  https://kenney.nl/assets/sci-fi-sounds
  License: Creative Commons CC0. Good fit for hover, wake, notification, and
  tiny robotic companion cues.
- Kenney Interface Sounds:
  https://kenney.nl/assets/interface-sounds
  License: Creative Commons CC0. Larger 100-file interface pack; useful if the
  current UI needs more variation than UI Audio.
- OpenGameArt 512 Sound Effects, 8-bit style:
  https://opengameart.org/content/512-sound-effects-8-bit-style
  License: CC0. Useful for hackathon-safe retro effects, but stylistically more
  arcade than plush desktop pet.
- SubspaceAudio 1000 Retro Sound Effects:
  https://subspaceaudio.itch.io/1000-retro-sound-effects
  License: CC BY 4.0. Good fallback if we need more variety, but it is paid and
  needs attribution, so CC0 Kenney/OpenGameArt remains simpler for the demo.
- Mixkit Free Game Sound Effects:
  https://mixkit.co/free-sound-effects/game/
  License: Mixkit Sound Effects Free License. Useful for quick prototype sounds,
  but not open-source/CC0; use only after checking the exact license terms for
  the bundled use case.
- OpenGameArt 100 plus game sound effects:
  https://opengameart.org/content/100-plus-game-sound-effects-wavoggm4a
  License: CC-BY 3.0. Usable with attribution, but not bundled yet because CC0
  packs are simpler for a polished submission.
- Freesound:
  https://freesound.org/help/faq/
  Useful for research, but every individual file must be checked. Prefer CC0 or
  CC-BY with attribution. Avoid CC-BY-NC and retired Sampling+ assets for this
  product path.
- OpenGameArt:
  https://opengameart.org/
  Good source for free game assets, but licenses vary by asset. Verify the
  license on each sound page before bundling.

## Current Shortlist

Research pass: 2026-06-14.

Use these in this order:

1. Original local Pika voice cues:
   `pika-voice-reply.wav`, `pika-voice-question.wav`,
   `pika-voice-excited.wav`, `pika-voice-electric.wav`,
   `pika-voice-soft.wav`.
   These own the mascot identity and should play for text replies, mood
   changes, petting, and rewards.
2. Local Pika sidecar in `--backend stub` mode:
   use `voice: "pika-signature"` to render short syllables such as
   `Pikaa pikaa!`, `Pikaa? Pikaa.`, and `Pikaa! Pikaaa!`.
   This is the safest path for crisper, intent-mapped voice because it is
   generated locally and does not clone an official performance.
3. Kenney/OpenGameArt CC0 digital sounds:
   use for send, open, close, minimize, sparkle, zap, reward, and hover
   accents. These should texture the UI but not replace the mascot voice.
4. Freesound CC0 or CC-BY individual files:
   use only after checking the exact sound page and preserving attribution when
   needed. Do not use CC-BY-NC for the hackathon product.
5. Mixkit prototype effects:
   acceptable for private prototypes after checking the Mixkit license, but not
   preferred for the open-source/hackathon bundle because it is not CC0.

## 2026-06-14 Source Decisions

- Kenney UI Audio
  - URL: https://kenney.nl/assets/ui-audio
  - License shown on source page: Creative Commons CC0.
  - Use for: send, hover, expand, collapse, mute, close, and settings clicks.
- Kenney Digital Audio
  - URL: https://kenney.nl/assets/digital-audio
  - License shown on source page: Creative Commons CC0.
  - Use for: electric zaps, short power accents, hyper-state sparks.
- Kenney Interface Sounds
  - URL: https://kenney.nl/assets/interface-sounds
  - License shown on source page: Creative Commons CC0.
  - Use for: larger UI variation if the companion starts feeling repetitive.
- OpenGameArt Kenney 63 Digital Sound Effects
  - URL: https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc
  - License shown on source page: CC0.
  - Use for: already bundled zap, pep, and power-up fallback effects.
- OpenGameArt 512 Sound Effects, 8-bit style
  - URL: https://opengameart.org/content/512-sound-effects-8-bit-style
  - License shown on source page: CC0.
  - Use for: optional retro fallback only; this is less plush and more arcade.
- Freesound
  - URL: https://freesound.org/help/faq/
  - License varies per sound. Only CC0 or CC-BY sounds should be considered,
    and CC-BY assets need attribution in app docs. Do not use CC-BY-NC.

Decision: do not bundle any searchable "Pikachu sound effect" clips unless the
file comes with explicit redistribution rights from a legitimate source. Random
clip mirrors and video rips are not acceptable for the hackathon build.

## Candidate Sources For Later

- OpenGameArt Library of Game Sounds: useful for CC0/CC-BY UI, creature, and
  electric packs. Verify each individual asset license before bundling.
- Freesound: useful search pool, but licenses vary between CC0, CC-BY, and
  CC-BY-NC. Avoid CC-BY-NC for this app; prefer CC0 or CC-BY with attribution.

## Implementation Rule

Pika text can display "Pika pika" freely as product copy, but sound should be
short and intentional:

- Character voice: original synthesized/recorded mascot chirps or a properly
  licensed/consented voice recipe.
- UI motion: CC0 blips, zaps, power-ups, and soft clicks.
- Language lessons: macOS TTS or the explicit language TTS stack, because that
  surface needs clear pronunciation.
- Never use ripped anime/game voice clips, even if a file is easy to find.
