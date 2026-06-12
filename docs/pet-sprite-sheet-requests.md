# PocketDM Pet Sprite Sheet Request List

## Required Format

Use this for every sheet so extraction stays clean:

- PNG with transparent background.
- 12 frames per animation, horizontal strip preferred.
- 512 x 512 pixels per frame, so a horizontal strip is 6144 x 512.
- Same camera, same character scale, same ground position, same lighting.
- No labels, no title text, no grid, no border, no sticker outline, no drop
  shadow, no gray background, no white background.
- Keep the pet fully inside each frame with at least 24 px breathing room.
- If a full sheet is hard, separate 512 x 512 transparent PNG frames are okay.
- File naming: `pet-{stage}-{action}.png`, for example
  `pet-baby-idle-look-smile.png`.

## Top Priority For The Next Demo

Generate these first. They unlock the most visible upgrade with the least code:

1. `pet-baby-idle-look-smile.png`
   - Looking down, looking up, noticing the user, smiling.
2. `pet-buddy-idle-look-smile.png`
   - Same as baby, but current medium-size form.
3. `pet-buddy-hyper.png`
   - Excited hops, cheek sparks, little electric wiggles.
4. `pet-buddy-pet-reaction.png`
   - Leans into petting, happy face, tiny heart/spark.
5. `pet-buddy-cheer-bubble.png`
   - Points or waves as if saying "come back".
6. `pet-buddy-learn.png`
   - Listening, repeating, proud quiz reaction.
7. `pet-buddy-level-up.png`
   - Glow, jump, celebratory flourish.
8. `pet-buddy-nap.png`
   - Soft sleep loop, breathing, tiny dream mark.
9. `pet-buddy-combo-complete.png`
   - Proud bounce, cheek glow, tiny reward sparkle.
10. `pet-buddy-comeback.png`
   - Notices the user after being away, looks relieved, waves gently.
11. `pet-buddy-upgrade-success.png`
   - Finds a little charm/card, celebrates, then returns to idle.
12. `pet-buddy-upgrade-denied.png`
   - Checks empty paws, encouraging shrug, no shame.

## Growth Stages

Each stage should share the same personality but visibly grow:

- Baby / Tiny Spark
  - Smaller body, rounder, extra curious, bigger eyes.
- Pocket Pal
  - Still small, but clearly recognizes the user and reacts faster.
- Trail Buddy
  - Current readable mascot size, energetic and expressive.
- Storm Scout
  - Taller, quicker movements, more confident poses.
- Storm Guardian
  - Heroic but still cute, stronger electric effects, protective stance.

For each stage, request these sheets:

- Idle look-down/look-up/smile.
- Happy.
- Hyper.
- Nap.
- Sad.
- Alert/scared.
- Curious.
- Proud.
- Confused.
- Hungry.
- Tired.
- Affection/petting.

## Stage And Feeling Matrix

This is the comprehensive next-generation request set. Generate it over time,
not all at once. Each row should be one 12-frame horizontal strip per stage.

Stages:

- `tiny-spark`
- `pocket-pal`
- `trail-buddy`
- `storm-scout`
- `storm-guardian`

Feelings:

- `bright`
  - Fresh idle, curious blink, gentle smile.
- `eager`
  - Hyperactive default: looking down, looking up, noticing user, smiling.
- `proud`
  - Combo complete, tiny chest-out victory, cheek glow.
- `snacky`
  - Low energy, hungry, hopeful look toward snack bowl.
- `sleepy`
  - Nap, slow breathing, soft wake-up.
- `curious`
  - Head tilt, listening, question mark energy without literal text.
- `lonely`
  - Soft sad posture, then warms up when user pets it.

Minimum matrix:

- `pet-{stage}-eager-idle-look-smile.png`
- `pet-{stage}-proud-combo-complete.png`
- `pet-{stage}-snacky-low-energy.png`
- `pet-{stage}-sleepy-nap.png`
- `pet-{stage}-curious-listen.png`
- `pet-{stage}-lonely-comeback.png`

Full matrix:

- one strip for every stage x feeling pair above.
- keep every strip transparent, same camera, same scale anchor, same foot
  baseline, and no sticker outline.

## Core Actions

These are the actual product loops:

- Pet reaction.
- Tap/collect spark.
- Eat snack.
- Study/learn.
- Quiz correct.
- Quiz wrong.
- Cheer/nudge.
- Wave.
- Dance.
- Jump.
- Run left.
- Run right.
- Hide/peek.
- Quest ready.
- Hint discovered.
- Level up.
- Evolve.
- Gift open.
- Comeback after absence.
- Low energy.
- Energy refilled.

## Hamster-Style Game Loop Sheets

These are for the progression layer:

- Work/earn sparks.
- Passive sparks collect.
- Upgrade card bought.
- Upgrade card denied because not enough sparks.
- Daily combo solved.
- Daily combo almost solved.
- Streak maintained.
- Streak broken but recoverable.
- Chest open.
- Rare reward.
- Bond HP increase.
- Joy refill.
- Cheer Signal activated.
- Cozy Nest comeback reward.
- Quest Map points to adventure.
- Study Bell lesson reward.
- Snack Bowl energy refill.

## Submission-Inspired Experience Sheets

These come from the Build Small competitive scan and make PocketDM feel more
like a living ritual:

- Field-note idle.
  - Pet studies the user's current quest like a tiny notebook companion.
- Repair/comfort moment.
  - Gentle reaction after a wrong answer or failed quest.
- Tiny tutor moment.
  - Pet listens, repeats, and nods through a language phrase.
- Local-helper moment.
  - Pet points to the next practical action, not a generic chat answer.
- Audio reaction pose.
  - Pet leans in before a chirp, TTS phrase, or message reply sound.

## Language Coach Sheets

Spanish and Mandarin lessons need teaching-specific reactions:

- Listen closely.
- Speak/repeat.
- Slow pronunciation.
- Correct answer celebration.
- Wrong answer encouragement.
- Pinyin/romanization thinking pose.
- Streak bonus.
- Lesson complete.

## UI Effects As Separate Transparent Sheets

These can be reused over any pet stage:

- Spark burst.
- Heart burst.
- Coin/spark dust pickup.
- XP bar glow.
- Level-up aura.
- Speech bubble tail.
- Small attention ping.
- Soft sleep particles.
- Correct quiz flash.
- Wrong quiz wobble.

## Generation Prompt Template

Use this structure when generating:

> Create a 12-frame transparent PNG sprite sheet for an original cute yellow
> electric desktop pet, 3D plush toy style, soft studio lighting, high
> resolution, smooth rounded body, black ear tips, red cheek sparks, expressive
> eyes, no text, no labels, no background, no outline, no shadow, consistent
> scale and camera. Animation: [ACTION]. Output frames in one horizontal strip,
> 512 x 512 px per frame, transparent alpha.

Replace `[ACTION]` with one of the action names above.

## Extraction Warnings

Do not send sheets with:

- Black contour lines.
- Gray sticker backing.
- Text headers.
- Grid lines.
- Cropped ears/tail.
- Strong baked shadows.
- Different character size per frame.
- Mixed camera angles in the same action sheet.

Those artifacts are exactly what caused the minimized dark outline problem.
