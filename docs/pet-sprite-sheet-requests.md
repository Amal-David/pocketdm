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
13. `pet-buddy-say-pika-pika.png`
   - Small mouth flaps, cheek twinkle, happy syllable bounce for the spoken
     "pika pika" reaction.
14. `pet-buddy-spark-boost.png`
   - Fast wind-up, electric burst, then settles proudly.
15. `pet-buddy-daily-cipher.png`
   - Thinking pose, clue discovery, little solved-celebration.
16. `pet-buddy-comeback-chest.png`
   - Opens a small saved chest after the user returns, relieved and happy.
17. `pet-buddy-evolve-preview.png`
   - Looks at a growing glow, then points at the next form.
18. `pet-buddy-mood-repair.png`
   - Starts lonely/gentle, receives care, warms back into a smile.
19. `pet-buddy-need-affection.png`
   - Looks at the user, steps closer, asks for a pet without text.
20. `pet-buddy-need-study.png`
   - Listens, repeats, points proudly after a phrase.
21. `pet-buddy-need-adventure.png`
   - Looks toward the quest, points at a trail, ready stance.
22. `pet-buddy-need-rest.png`
   - Sleepy blink, curls up, soft wake loop.
23. `pet-buddy-need-play.png`
   - Hyper hop, cheek sparks, happy shake-off.
24. `pet-buddy-need-focus.png`
   - Sits beside an invisible task, attentive eyes, quiet nod.
25. `pet-buddy-need-puzzle.png`
   - Thinking tilt, clue discovery, solved sparkle.
26. `pet-buddy-memory-unlock.png`
   - Finds a tiny glowing memory charm, reacts emotionally, stores it.
27. `pet-buddy-event-spark-picnic.png`
   - Gathers snack sparks, sets a tiny picnic blanket, celebrates.
28. `pet-buddy-event-study-parade.png`
   - Marches proudly with phrase cards, listens, repeats.
29. `pet-buddy-event-sky-sprint.png`
   - Fast happy sprint loop with electric afterglow.
30. `pet-buddy-event-riddle-trail.png`
   - Follows clue crumbs, thinks, solves, stores note.
31. `pet-buddy-event-cozy-campfire.png`
   - Adds embers, warms hands/cheeks, settles peacefully.
32. `pet-buddy-event-rescue-walk.png`
   - Searches, finds lost sparks, guides them home.
33. `pet-buddy-badge-unlock.png`
   - Receives a tiny badge charm and reacts with visible pride.
34. `pet-buddy-mood-discovery.png`
   - Notices a new feeling, looks surprised, then proudly stores it.
35. `pet-buddy-mood-album-proud.png`
   - Opens a tiny charm album and points at a newly discovered mood.
36. `pet-buddy-emotion-shift.png`
   - Smoothly changes from neutral into happy, focused, sleepy, or playful.
37. `pet-buddy-daily-mood-complete.png`
   - Celebrates several emotions discovered in one day without confetti text.
38. `pet-buddy-journal-open.png`
   - Opens a tiny field journal/charm album and looks proud.
39. `pet-buddy-journal-growth-map.png`
   - Points at a growth path from tiny to guardian form.
40. `pet-buddy-journal-memory-page.png`
   - Carefully turns to a remembered care moment.
41. `pet-buddy-journal-badge-page.png`
   - Shows a badge page with pride and a small sparkle.
42. `pet-buddy-next-sprite-request.png`
   - Holds up a small blank art card, asking for the next animation sheet.

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
- `overcharged`
  - Spark boost ready, jittery cheek sparks, wants to move.
- `focused`
  - Minimized watch mode, quiet breathing, eyes tracking the desktop.
- `celebrating`
  - Full daily board complete, bouncing victory.
- `protective`
  - Late-night guardian stance, calm and reassuring.
- `gentle`
  - Comfort mode after low joy or missed care.
- `playful`
  - Wants movement, quick wiggle, cheek spark hop.
- `grateful`
  - Warm care-streak reaction, soft proud smile.
- `determined`
  - Ready-to-grow stance, focused eyes, gathered sparks.
- `restless`
  - Too many Sparks saved, asks for an upgrade.
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
- `pet-{stage}-overcharged-spark-boost-ready.png`
- `pet-{stage}-focused-watch-mode.png`
- `pet-{stage}-celebrating-board-complete.png`
- `pet-{stage}-protective-night-watch.png`
- `pet-{stage}-gentle-comfort.png`
- `pet-{stage}-playful-wiggle.png`
- `pet-{stage}-grateful-care-streak.png`
- `pet-{stage}-determined-grow-ready.png`
- `pet-{stage}-restless-upgrade-ready.png`
- `pet-{stage}-snacky-low-energy.png`
- `pet-{stage}-sleepy-nap.png`
- `pet-{stage}-curious-listen.png`
- `pet-{stage}-lonely-comeback.png`
- `pet-{stage}-say-pika-pika.png`

Full matrix:

- one strip for every stage x feeling pair above.
- keep every strip transparent, same camera, same scale anchor, same foot
  baseline, and no sticker outline.

## Lifecycle Pack

These are the sheets that make the pet feel alive across a real day, not just
while the panel is open.

Time-of-day nudges:

- `pet-{stage}-sunrise-checkin.png`
  - Wakes up, notices the user, offers a small morning quest.
- `pet-{stage}-focus-window.png`
  - Sits still, attentive, ready to help the user start one task.
- `pet-{stage}-afternoon-wobble.png`
  - Low-energy wobble, then asks whether the user wants a softer task.
- `pet-{stage}-evening-campfire.png`
  - Cozy closing-loop animation, warm and calm.
- `pet-{stage}-night-watch.png`
  - Protective quiet guard pose with slow breathing.

Comeback and absence:

- `pet-{stage}-waiting-softly.png`
  - Looks around occasionally while the user is away.
- `pet-{stage}-lonely-wait.png`
  - Gentle low-joy state, not dramatic, no shame.
- `pet-{stage}-welcome-back.png`
  - Perks up when the user returns.
- `pet-{stage}-pocket-chest-open.png`
  - Small 4+ hour comeback reward.
- `pet-{stage}-moon-chest-open.png`
  - Medium 12+ hour comeback reward.
- `pet-{stage}-storm-chest-open.png`
  - Large 24+ hour comeback reward.
- `pet-{stage}-mood-repair.png`
  - Joy recovers after a pet/check-in.

Evolution and growth:

- `pet-{stage}-evolution-progress.png`
  - Looks at a glowing progress mark for the next stage.
- `pet-{stage}-ready-to-evolve.png`
  - Excited, electricity gathers, body glows.
- `pet-{stage}-evolve-to-{next-stage}.png`
  - Transition from current stage into next stage.
- `pet-{stage}-new-stage-idle.png`
  - First calm idle loop after growth.

Care needs:

- `pet-{stage}-need-affection.png`
  - Wants petting, leans in, receives care.
- `pet-{stage}-need-study.png`
  - Wants a language phrase, listens, repeats.
- `pet-{stage}-need-adventure.png`
  - Wants quest progress, points, marches in place.
- `pet-{stage}-need-rest.png`
  - Wants rest, yawns, curls up, soft breathing.
- `pet-{stage}-need-play.png`
  - Wants hyper play, wiggles, hops, cheek sparks.
- `pet-{stage}-need-focus.png`
  - Wants a focus check-in, sits still, watches the screen.
- `pet-{stage}-need-puzzle.png`
  - Wants a cipher, thinks, discovers a small clue.

Bond memories:

- `pet-{stage}-memory-first-care.png`
  - Learns the user's hand is safe.
- `pet-{stage}-memory-first-hint.png`
  - Learns how to point at a trail.
- `pet-{stage}-memory-first-lesson.png`
  - Learns the user's study voice.
- `pet-{stage}-memory-first-quest.png`
  - Learns where adventures begin.
- `pet-{stage}-memory-first-upgrade.png`
  - Discovers its kit can grow.
- `pet-{stage}-memory-first-comeback.png`
  - Relieved return after absence.
- `pet-{stage}-memory-first-cipher.png`
  - Keeps a tiny secret note.
- `pet-{stage}-memory-first-boost.png`
  - Learns to burst into motion.
- `pet-{stage}-memory-first-board.png`
  - Celebrates a full daily board.
- `pet-{stage}-memory-first-evolution.png`
  - Realizes care changed its form.

Mood album:

- `pet-{stage}-mood-discovery.png`
  - First time a feeling appears; surprise, recognition, proud little storage.
- `pet-{stage}-mood-album-open.png`
  - Opens a tiny charm/field-note album and points at discovered moods.
- `pet-{stage}-emotion-shift.png`
  - Transitions between neutral, eager, focused, sleepy, playful, and proud.
- `pet-{stage}-daily-mood-complete.png`
  - Celebrates discovering several moods in one day.
- `pet-{stage}-mood-revisit.png`
  - Recognizes a familiar feeling and gives a small "I remember this" reaction.

Journal / album view:

- `pet-{stage}-journal-open.png`
  - Opens the pet journal and invites the user to inspect progress.
- `pet-{stage}-journal-growth-map.png`
  - Points from current stage toward next growth form.
- `pet-{stage}-journal-memory-page.png`
  - Shows one unlocked memory charm with a tender reaction.
- `pet-{stage}-journal-badge-page.png`
  - Shows event badge progress without text or UI labels.
- `pet-{stage}-journal-ritual-page.png`
  - Shows today's combo, task board, event, and care need as visual charms.
- `pet-{stage}-journal-next-sprite.png`
  - Presents the next needed sprite sheet as a blank art card.

Daily events and badges:

- `pet-{stage}-event-spark-picnic.png`
  - Short collecting loop for snack sparks.
- `pet-{stage}-event-study-parade.png`
  - Phrase-card parade, proud learning rhythm.
- `pet-{stage}-event-sky-sprint.png`
  - Energy-burn sprint and happy cooldown.
- `pet-{stage}-event-riddle-trail.png`
  - Clue trail, tiny solve, saved note.
- `pet-{stage}-event-cozy-campfire.png`
  - Gentle evening close-loop with warm ember.
- `pet-{stage}-event-rescue-walk.png`
  - Searches for lost sparks, finds them, escorts them home.
- `pet-{stage}-badge-picnic.png`
- `pet-{stage}-badge-study.png`
- `pet-{stage}-badge-sprint.png`
- `pet-{stage}-badge-riddle.png`
- `pet-{stage}-badge-campfire.png`
- `pet-{stage}-badge-rescue.png`
- `pet-{stage}-badge-album-complete.png`
  - Reaction after all six event badges are collected.

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
- Spark Wheel passive-income upgrade.
- Focus Charm boost upgrade.
- Cipher Stone daily-puzzle upgrade.
- Daily task board complete.
- Daily task board almost complete.
- Daily cipher clue found.
- Daily cipher solved.
- Daily boost ready.
- Daily boost claimed.
- Pika pika voice reaction.
- Evolution progress updated.
- Ready to evolve.
- Evolution complete.
- Mood decay after long absence.
- Mood repaired by care.
- Time-of-day nudge: sunrise.
- Time-of-day nudge: focus.
- Time-of-day nudge: afternoon.
- Time-of-day nudge: evening.
- Time-of-day nudge: night.
- Daily care need satisfied.
- Bond memory unlocked.
- Story chapter advanced.
- Mood discovered.
- Mood album updated.
- Daily mood set advanced.
- Journal opened.
- Journal growth page viewed.
- Journal memory page viewed.
- Journal badge page viewed.
- Journal next-sprite request.
- Daily event step.
- Daily event complete.
- Event badge unlocked.
- Event badge polished/repeated.
- Badge album complete.

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
