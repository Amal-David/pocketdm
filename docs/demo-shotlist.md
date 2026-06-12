# PocketDM Demo Shot List

Target length: 90-120 seconds.

## Sequence

1. Cold open: show the native desktop companion in pet-only mode, with Pikachu
   floating above the normal Mac desktop.
2. Make one choice that changes state: HP, inventory, or location must visibly
   update.
3. Click Pikachu to expand the native panel, then ask for `status` or `hint`;
   show that the response references HP, inventory, and the current choices.
4. Tap `Pet` so the Bond HP/Joy reward is visible, then open `Learn`, play one
   Spanish phrase and one Mandarin phrase with TTS, and answer a quiz.
5. Switch to Lore Narrator voice in the web fallback and play one narration line.
6. Show the proof badge and backend state. If the trained GGUF is ready, switch
   to `Backend: llama.cpp`; otherwise keep `Scripted` visible and label the clip
   as a checkpoint.
7. Cut to terminal receipts:
   - `uv run pytest -q`
   - Spanish/Mandarin language-pack count: 100 words + 100 sentences each
   - full filter report
   - GGUF SHA/size once available
   - eval report ship gate once available
8. Finish with a 3-genre montage: dungeon, wood, starship.
9. Last frame: Space URL, model repo, dataset/traces repo, field notes URL, and
   social post URL.

## Required Proof Beats

- Show a complete ending.
- Show the app is not stock Gradio.
- Show a local asset path or network-off run for the offline claim.
- Show the model/backend receipt when the GGUF exists.
- Show Pikachu doing something useful, not just cute: hint, daily care, and a
  language-practice reward.
