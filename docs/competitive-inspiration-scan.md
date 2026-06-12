# PocketDM Competitive Inspiration Scan

## Why This Scan Matters

The strongest Build Small submissions are not trying to be general chatbots.
They are narrow rituals with a memorable surface: a tutor that draws, a forest
that turns worries into paths, a tiny reading companion, an ADHD-friendly boost,
or a story world with concrete state. PocketDM should lean into that same
clarity: a tiny offline adventure engine whose desktop pet makes the experience
feel alive and worth returning to.

Sources sampled:

- Build Small Hackathon article feed: https://huggingface.co/organizations/build-small-hackathon/activity/articles
- Compliment Forest: https://huggingface.co/blog/build-small-hackathon/compliment-forest
- Sema reading companion: https://huggingface.co/blog/build-small-hackathon/otienojturingcom
- Tutori whiteboard tutor: https://huggingface.co/blog/build-small-hackathon/tutori
- NeuroBait ADHD boost: https://huggingface.co/blog/build-small-hackathon/neurobait-adhd
- Kintsugi Garden: https://huggingface.co/blog/build-small-hackathon/kintsugi-garden
- Mind of Tashi: https://huggingface.co/blog/build-small-hackathon/mind-of-tashi-field-notes
- Dempster Court: https://huggingface.co/blog/build-small-hackathon/dempster-court
- Lolaby: https://huggingface.co/blog/build-small-hackathon/lolaby-blog
- PawMap: https://huggingface.co/blog/build-small-hackathon/pawmap
- Hamster-style loop references: https://www.withtap.com/blog/how-to-tap-into-hamster-kombat-daily-combo-cards, https://www.binance.com/en/square/post/13528182500593, https://web3.gate.com/en/crypto-wiki/article/daily-hamster-kombat-combo-card-guide-note-i-noticed-you-provided-russian-text-to-be-translated-while-the-initial-instructions-mentioned-chinese-economic-commentary-i-provided-the-direct-translation-as-requested-please-let-me-know-if-you-need-any-adjustme

## What Other Submissions Teach Us

### Emotional Rituals Beat Generic Utility

Compliment Forest and Kintsugi Garden frame the model as a gentle ritual. The
user gives it an anxious or broken input, and the app returns a path, clearing,
or repaired object. PocketDM can borrow the ritual shape without becoming a
wellness app:

- Daily petting is not a button; it is a bond ritual.
- A failed quest is not just a failure; it gives the pet a reason to comfort,
  encourage, and ask the user to try a smaller step.
- "Joy", "Bond HP", and "Sparks" should always be attached to tiny moments of
  care, not abstract counters.

### Companions Need One Job They Do Beautifully

Sema is memorable because "reading companion for my brother" is emotionally and
functionally clear. PocketDM's companion should be described just as simply:

"A tiny desktop adventure buddy that cheers you on, gives hints, and grows when
you care for it."

That promise should govern the native app:

- Pet-only mode is the default surface.
- Clicking the pet opens chat, care, language practice, and adventure help.
- The pet should occasionally check in with a short, dismissible nudge.

### Tutors Need Feedback, Not Lectures

Tutori's hook is that it teaches by talking and drawing at the same time. For
PocketDM language mode, the equivalent is:

- Hear the phrase.
- Hear it slow.
- See pinyin or romanization.
- Answer one quick quiz.
- Earn a visible reward for the pet.

This keeps learning as a toy-like loop inside the companion instead of a
separate course product.

### ADHD-Friendly Products Need Short Loops

NeuroBait points toward short, low-friction activation. For PocketDM, that means
the companion should not wait for the user to open the browser:

- Give a one-line check-in bubble while minimized.
- Offer a 60-second quest, hint, or phrase.
- Reward the first action quickly.
- Let the user dismiss without shame or friction.

### Story Worlds Need State Receipts

Mind of Tashi, Dempster Court, DOD, and the wood-sim style submissions show that
small models can feel bigger when they have state, constraints, and lore. This
is directly aligned with PocketDM's deterministic game engine:

- The model writes the magical prose.
- The engine owns HP, location, inventory, endings, and validation.
- The desktop pet surfaces the state as emotional feedback.

## Hamster-Style Loop, Translated Safely

Do not copy the crypto/financial premise. Copy the retention mechanics and make
them wholesome:

- Tap/action economy: petting and quick lessons earn "Sparks".
- Energy cap: active rewards spend energy, which recharges over time.
- Passive progress: the pet keeps a tiny reserve while the user is away.
- Daily combo: each day offers one tiny combo such as Pet + Hint + Phrase.
- Upgrade cards: unlock lore badges, pet tricks, and companion behaviors.
- Streaks: daily care grows Bond HP and keeps Joy high.
- Puzzle/cipher: adventure riddles or language mini-ciphers replace crypto
  reward puzzles.
- Community/social: defer for now; the desktop companion should win locally
  before asking for social virality.

## What PocketDM Should Build Next

### Product Loop

1. Pet-only companion floats on desktop.
2. It occasionally shows a gentle check-in bubble.
3. User clicks pet, pets it, asks for a hint, or practices a phrase.
4. Action gives Sparks, Joy, and maybe Bond HP.
5. Growth stage changes from Tiny Spark to Trail Buddy to Storm Buddy.
6. New sprites unlock more expressive behaviors.

### Demo Loop

1. Show the pet alone on desktop.
2. Wait for or trigger a check-in bubble.
3. Click pet to expand.
4. Pet once: HP/Joy/Sparks change.
5. Ask for a hint tied to the adventure.
6. Do a Spanish or Mandarin phrase.
7. Minimize back to pet-only mode.

### Positioning

The pitch should be:

"PocketDM is a tiny offline adventure game with a living desktop buddy. The
model writes the magic; the engine keeps the rules; the pet keeps you coming
back."

## Implementation Notes

The current native companion already has:

- Pet-only default.
- Click-to-expand overlay.
- Mood sprites.
- Chat through `/api/assistant`.
- Spanish and Mandarin learning packs.
- Original chirps.
- Bond HP, Joy, and streak counters.

The new layer should add:

- Sparks and energy.
- Proactive cheer bubbles.
- Growth stages.
- Daily combo tracking.
- Passive sparks while away.
- Upgrade cards or unlocks once more sprites exist.
- A richer sprite request queue for the user to generate.

## Current Native Checkpoint

The native macOS companion now has the first version of the loop:

- Pet-only default with click-to-expand.
- Proactive check-in bubbles while minimized.
- Sparks earned from petting, asking, language practice, and combo completion.
- Energy that recharges over time.
- Passive Sparks collected after time away.
- A daily combo: Pet + Hint + Learn.
- A rotating Upgrade button that spends Sparks on Snack Bowl, Study Bell, and
  Quest Map levels.
- Growth stages computed from Bond HP and Sparks.

This is not the full final pet fantasy yet. It is the backbone that lets the
next sprite sheets matter: new art can now map to real emotions, upgrades,
growth, learning, and comeback moments.
