# PocketDM Submission Readiness

## Verified First Cut

- Custom Gradio app launches with `uv run python app.py`.
- `/health` returns `{"status":"ok"}` on port 7860.
- The app plays a complete scripted adventure through the frozen engine state contract.
- Ember is persistent across the viewport, uses `app/static/dragon-sprites.png`, flaps continuously, gives state-aware hints, speaks through browser speech synthesis, and fires on notable replies.
- Narration has selectable `Auto`, `Dungeon`, `Wood`, `Starship`, and `Lore Narrator` modes; `app/voices/lore_narrator.npy` smoke-synthesizes locally at 24 kHz.
- The app can switch to an optional llama.cpp backend when `POCKETDM_GGUF` points at a GGUF model; without that artifact, it honestly reports the current `Scripted` backend.
- Unit/integration tests pass locally: `57 passed`.
- WP-3 50-adventure acceptance smoke passed turn-level filters: 632 clean turns, 2 bridge fallbacks, all turn gates >=99.1%.
- WP-4/WP-5 command surfaces exist for Modal fine-tuning, GGUF export, local smoke inference, automated eval, Modal judge scoring, and report generation.
- WP-4 0.8B LoRA smoke training ran end to end on Modal: 20 steps, 978 train rows, 20 eval rows, train_loss=1.555, eval_loss=1.284, merged model saved in the `pocketdm-models` volume.
- WP-4 smoke GGUF export ran end to end: Q4_K_M artifact SHA256 `02f57aca6929095f80b359d63760cbcd7e4d16ad4ce8d83b4af2d2c5c0355dc8`; local `train/smoke_infer.py --turns 3` loads it through llama.cpp and emits valid turn JSON.
- The app can run with the smoke GGUF enabled: `POCKETDM_GGUF=models/0p8b-smoke-lora-20/merged.Q4_K_M.gguf uv run python app.py`, `/api/start` returned valid llama.cpp-backed turns with `used_bridge=false`, and `agent-browser` captured proof-badge/UI screenshots at `/tmp/pocketdm-gguf-started-proof3.png` and `/tmp/pocketdm-mobile-idle-fixed2.png`.
- A local offline smoke test proves the scripted play loop, Ember assistant, and dragon sprite asset do not open outbound sockets.

## Honest Gaps Before Final Submission

- WP-3 teacher pipeline still needs the full generation run: >=5k filtered turns and 100 held-out eval seeds.
- The final fine-tuned Qwen3.5 student model and GGUF export are not complete yet.
- The live app defaults to a scripted backend unless `POCKETDM_GGUF` points at a GGUF; the current 0.8B GGUF is a plumbing smoke artifact, not the final submission model.
- Kokoro sequential TTS works locally when model files and dependencies are present, but live Space timing and full runtime no-network proof are still pending.
- Base-vs-finetuned eval and LLM judge scores are not complete yet; `eval/report.py` now keeps the ship gate failed unless judge scores are supplied.
- Demo video, social post, model repo, dataset repo, and trace publication are still TODO.
- README frontmatter tag strings should be verified against the registration app before final submission.

## Judge-Framing Notes

- Lead with Thousand Token Wood delight: a tiny offline DM plus a desktop-pet dragon.
- Show the app first, not the training pipeline.
- Be explicit that the engine owns state and validates every model turn.
- Use the cost log and smoke reports as receipts for the Modal/OpenAI/Codex story.
