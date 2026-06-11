# PocketDM Demo Shot List

Target length: 90-120 seconds.

## Sequence

1. Cold open: start a cursed dungeon adventure and show Ember flapping on top of
   the screen.
2. Make one choice that changes state: HP, inventory, or location must visibly
   update.
3. Ask Ember for `status`, then `hint`; show that it references HP, inventory,
   and the current choices.
4. Switch to Lore Narrator voice and play one narration line.
5. Show the proof badge and backend state. If the trained GGUF is ready, switch
   to `Backend: llama.cpp`; otherwise keep `Scripted` visible and label the clip
   as a checkpoint.
6. Cut to terminal receipts:
   - `uv run pytest -q`
   - full filter report
   - GGUF SHA/size once available
   - eval report ship gate once available
7. Finish with a 3-genre montage: dungeon, wood, starship.
8. Last frame: Space URL, model repo, dataset/traces repo, field notes URL, and
   social post URL.

## Required Proof Beats

- Show a complete ending.
- Show the app is not stock Gradio.
- Show a local asset path or network-off run for the offline claim.
- Show the model/backend receipt when the GGUF exists.
- Show the dragon doing something useful, not just cute.
