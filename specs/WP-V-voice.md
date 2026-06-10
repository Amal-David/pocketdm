# WP-V — "Lore Narrator" custom-blended Kokoro voice (woman, dark-fantasy game-lore style)

Target: a 4th selectable narrator voice that sounds like a dark-fantasy game intro narrator — measured pacing, gravitas, slight breathiness, light reverb. Built ONLY by blending Kokoro's own Apache-2.0 voice packs (no training, no external audio — hard legal line; see PRD Amendment 5).

## Deliverables

1. `app/voices/build_lore_voice.py` (CLI, runs locally on CPU):
   - Download `hexgrad/Kokoro-82M` voice tensors: `bf_emma`, `af_heart`, `af_bella`, `af_nicole` (each is a `(510, 1, 256)` style tensor `.pt`).
   - `--audition` mode: generate WAVs for a grid of blends × speeds into `app/voices/auditions/`:
     - blends: `{emma: e, heart: h, nicole: n}` for (e,h,n) in [(0.45,0.35,0.20), (0.55,0.30,0.15), (0.40,0.30,0.30), (0.50,0.50,0.00), (0.35,0.45,0.20) with af_bella swapped for af_heart in two variants]
     - speeds: 0.78, 0.85
     - fixed audition script: "Long ago, in the Whispering Wood, a door was carved that should never have been opened. You stand before it now, torch guttering, as the runes begin to glow."
     - filenames encode the recipe: `lore_e45_h35_n20_s078.wav`.
   - `--build w_emma,w_heart,w_nicole,speed` mode: save the winning blend as `app/voices/lore_narrator.pt` (torch tensor) AND as numpy in `app/voices/lore_narrator.npy`.
   - Reverb is NOT baked into the voice tensor — it's applied at synthesis time (next item).
2. `app/tts.py` — kokoro-onnx wrapper used by the Space:
   - Loads `kokoro-v1.0.onnx` + `voices-v1.0.bin` (kokoro-onnx release assets); custom voice loads from `lore_narrator.npy` and is passed as a raw style array.
   - `synthesize(text, voice_id, speed) -> (sample_rate, np.ndarray)`; voice table: `dungeon` → `am_onyx` (or best graded gravelly male), `wood` → `af_heart`, `starship` → `af_sky` or another clipped female, `lore` → custom array at speed 0.8 **+ pedalboard post-chain (Reverb room_size≈0.35, wet≈0.25, low-pass at ~9kHz)** applied only for `lore`.
   - Pure-CPU, strictly synchronous function (the server decides scheduling); no network at synthesis time (models must already be on disk; a separate `download()` helper fetches at build/startup).
3. `tests/test_voice.py` — blend math unit test (weighted sum shape/dtype preserved, weights normalized), voice table completeness, and a smoke synth test marked `@pytest.mark.slow` (skipped when model files absent).
4. Dependency group `tts`: `kokoro-onnx`, `soundfile`, `pedalboard`, `numpy`, `torch` (torch only needed by the build script for `.pt` loading — keep it in a separate `voicebuild` group so the Space image stays torch-free).

## Acceptance
- `uv run python app/voices/build_lore_voice.py --audition` produces the WAV grid locally.
- After `--build`, `app/tts.py` renders the audition script with the lore voice + reverb to a WAV.
- README copy describes the voice as "custom-blended from Kokoro voice packs" (never "fine-tuned", never referencing a game/actor).
