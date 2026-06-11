# PocketDM Submission Readiness

## Verified First Cut

- Custom Gradio app launches with `uv run python app.py`.
- `/health` returns `{"status":"ok"}` on port 7860.
- The app plays a complete scripted adventure through the frozen engine state contract.
- Ember is persistent across the viewport, uses `app/static/dragon-sprites.png`, flaps continuously, speaks through browser speech synthesis, and fires on notable replies.
- Unit/integration tests pass locally: `39 passed, 1 skipped`.

## Honest Gaps Before Final Submission

- WP-3 teacher pipeline is still validating data quality; the active smoke probe must pass filters before scaling.
- The fine-tuned Qwen3.5 student model and GGUF export are not complete yet.
- The live app currently uses a scripted backend, not the trained llama.cpp runtime.
- Kokoro voice blending and sequential TTS are still pending.
- Demo video, social post, model repo, dataset repo, and trace publication are still TODO.
- README frontmatter tag strings should be verified against the registration app before final submission.

## Judge-Framing Notes

- Lead with Thousand Token Wood delight: a tiny offline DM plus a desktop-pet dragon.
- Show the app first, not the training pipeline.
- Be explicit that the engine owns state and validates every model turn.
- Use the cost log and smoke reports as receipts for the Modal/OpenAI/Codex story.
