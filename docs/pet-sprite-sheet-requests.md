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

### Runtime Stage Sprite Pack

These filenames are now loaded directly by the native macOS companion when
present. If a stage-specific file is missing, the app falls back to the current
generic `pet-happy.png`, `pet-hyper.png`, `pet-nap.png`, or `pet-alert.png`.

For every growth stage:

- `pet-tiny-spark-eager-idle-look-smile.png`
- `pet-tiny-spark-happy.png`
- `pet-tiny-spark-hyper.png`
- `pet-tiny-spark-sleepy-nap.png`
- `pet-tiny-spark-curious-listen.png`
- `pet-pocket-pal-eager-idle-look-smile.png`
- `pet-pocket-pal-happy.png`
- `pet-pocket-pal-hyper.png`
- `pet-pocket-pal-sleepy-nap.png`
- `pet-pocket-pal-curious-listen.png`
- `pet-trail-buddy-eager-idle-look-smile.png`
- `pet-trail-buddy-happy.png`
- `pet-trail-buddy-hyper.png`
- `pet-trail-buddy-sleepy-nap.png`
- `pet-trail-buddy-curious-listen.png`
- `pet-storm-scout-eager-idle-look-smile.png`
- `pet-storm-scout-happy.png`
- `pet-storm-scout-hyper.png`
- `pet-storm-scout-sleepy-nap.png`
- `pet-storm-scout-curious-listen.png`
- `pet-storm-guardian-eager-idle-look-smile.png`
- `pet-storm-guardian-happy.png`
- `pet-storm-guardian-hyper.png`
- `pet-storm-guardian-sleepy-nap.png`
- `pet-storm-guardian-curious-listen.png`

Each is a 12-frame transparent strip. Keep the same foot baseline across all
five stages so growth feels like the same pet maturing rather than a different
character replacing it.

### Growth Journey Arrival Pack

These filenames are now used by the Growth Journey album. They are the
relationship beats where a form is first reached, separate from ordinary idle
or mood loops.

- `pet-tiny-spark-growth-arrival.png`
  - First look up, first trust, tiny desktop arrival.
- `pet-pocket-pal-growth-arrival.png`
  - Recognizes the user's rhythm and returns affection.
- `pet-trail-buddy-growth-arrival.png`
  - Walks beside a tiny trail map, ready for quests and lessons.
- `pet-storm-scout-growth-arrival.png`
  - Scouts the desktop edge, focused and alert without pressure.
- `pet-storm-guardian-growth-arrival.png`
  - Calm guardian stance, protective glow, gentle pride.
- `pet-tiny-spark-evolve-to-pocket-pal.png`
  - Tiny Spark grows into Pocket Pal with a soft electric glow.
- `pet-pocket-pal-evolve-to-trail-buddy.png`
  - Pocket Pal becomes Trail Buddy, stepping onto a lit path.
- `pet-trail-buddy-evolve-to-storm-scout.png`
  - Trail Buddy becomes Storm Scout with confident scouting sparks.
- `pet-storm-scout-evolve-to-storm-guardian.png`
  - Storm Scout becomes Storm Guardian, calm protective aura.
- `pet-{stage}-journal-growth-journey.png`
  - Opens a page showing locked and unlocked stage-arrival charms.

### Relationship Loop Sheets

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
43. `pet-buddy-journal-page-tabs.png`
   - Flips between growth, mood, memory, badge, ritual, week, cards, and art pages.
44. `pet-buddy-journal-mood-grid.png`
   - Points at locked and unlocked mood charms in a tiny album grid.
45. `pet-buddy-journal-ritual-checklist.png`
   - Reviews today's combo, tasks, event, boost, and care need as charms.
46. `pet-buddy-proactive-checkin.png`
   - Pops up beside the desktop pet with a warm "how are you?" pose.
47. `pet-buddy-proactive-focus-checkin.png`
   - Quietly sits and invites the user to start one small task.
48. `pet-buddy-proactive-event-checkin.png`
   - Points toward today's event charm without text.
49. `pet-buddy-proactive-comeback-checkin.png`
   - Welcomes the user back with a saved tiny chest.
50. `pet-buddy-week-chapter-day-1-first-hello.png`
   - First weekly chapter: looks down, looks up, recognizes the user, warms into
     a hello.
51. `pet-buddy-week-chapter-day-3-focus-perch.png`
   - Perches beside an invisible task, focused but comforting.
52. `pet-buddy-week-chapter-day-7-guardian-glow.png`
   - Full week chapter completion: protective glow, proud bow, soft celebration.
53. `pet-buddy-week-day-1-first-spark.png`
   - First weekly care stamp: notices the week trail lighting up.
54. `pet-buddy-week-day-3-warm-trail.png`
   - Three-day return: follows a glowing trail and looks proud.
55. `pet-buddy-week-day-5-trust-charm.png`
   - Five-day return: receives a tiny trust charm and holds it carefully.
56. `pet-buddy-week-day-7-guardian-glow.png`
   - Full-week return: guardian glow, happy bounce, then calm pride.
57. `pet-buddy-journal-week-page.png`
   - Opens the week trail page and points at day 1/3/5/7 milestones.
58. `pet-buddy-week-reward-claim.png`
   - Claims a weekly reward chest/charm with no text, labels, or UI chrome.
59. `pet-buddy-daypart-sunrise-check.png`
   - Morning check-in: looks up warmly and invites one tiny quest.
60. `pet-buddy-daypart-focus-buddy.png`
   - Focus check-in: sits beside the user quietly, attentive and steady.
61. `pet-buddy-daypart-afternoon-reset.png`
   - Afternoon reset: low-energy wobble, stretch, then encouraging smile.
62. `pet-buddy-daypart-evening-loop.png`
   - Evening loop: points to one closing task and settles by a warm glow.
63. `pet-buddy-daypart-night-watch.png`
   - Night watch: protective soft breathing, calm eyes, no urgency.
64. `pet-buddy-card-snack-bowl.png`
   - Upgrade card animation for energy/snack care.
65. `pet-buddy-card-study-bell.png`
   - Upgrade card animation for language lessons.
66. `pet-buddy-card-quest-map.png`
   - Upgrade card animation for adventure hints and quest help.
67. `pet-buddy-card-cozy-nest.png`
   - Upgrade card animation for comeback rewards and rest.
68. `pet-buddy-card-cheer-signal.png`
   - Upgrade card animation for proactive check-ins.
69. `pet-buddy-card-spark-wheel.png`
   - Upgrade card animation for passive Spark earning.
70. `pet-buddy-card-focus-charm.png`
   - Upgrade card animation for boosts and focus support.
71. `pet-buddy-card-cipher-stone.png`
   - Upgrade card animation for daily ciphers.
72. `pet-buddy-card-deck-open.png`
   - Opens a tiny upgrade-card album and points at the next card.
73. `pet-buddy-card-upgrade-claim.png`
   - Spends Sparks, card glows, pet celebrates the new level.
74. `pet-buddy-vital-snack-low.png`
   - Notices its snack meter is low, checks paws, then brightens when cared
     for.
75. `pet-buddy-vital-rest-low.png`
   - Starts sleepy, curls up, breathes softly, then reopens its eyes.
76. `pet-buddy-vital-play-low.png`
   - Looks under-stimulated, does a tiny wiggle, then hops happily.
77. `pet-buddy-vital-focus-low.png`
   - Looks distracted, settles beside the task, then nods attentively.
78. `pet-buddy-vital-refill.png`
   - Generic care refill glow for Snack, Rest, Play, or Focus without text.
79. `pet-buddy-journal-vitals-page.png`
   - Opens the journal to four care charms for Snack, Rest, Play, and Focus.
80. `pet-buddy-charm-album-open.png`
   - Opens a collectible charm album and looks proud without text.
81. `pet-buddy-charm-hello-spark.png`
   - First hello charm, notices user, small cheek glow.
82. `pet-buddy-charm-snack-heart.png`
   - Snack/care charm, leans into daily care and stores a tiny heart spark.
83. `pet-buddy-charm-study-bell.png`
   - Study charm, listens, repeats, and rings a small bell.
84. `pet-buddy-charm-trail-map.png`
   - Hint/adventure charm, unfolds a tiny map and points forward.
85. `pet-buddy-charm-rest-nest.png`
   - Rest charm, curls in a cozy nest and wakes softly.
86. `pet-buddy-charm-play-bolt.png`
   - Play charm, happy hop with a tiny bolt.
87. `pet-buddy-charm-focus-charm.png`
   - Focus charm, sits beside the user's work and nods.
88. `pet-buddy-charm-cipher-stone.png`
   - Puzzle charm, solves a small glowing stone clue.
89. `pet-buddy-charm-event-ribbon.png`
   - Daily event charm, receives a small ribbon and celebrates.
90. `pet-buddy-charm-upgrade-card.png`
   - Upgrade charm, card glows and the pet reacts proudly.
91. `pet-buddy-charm-weekly-trail.png`
   - Weekly trail charm, several path lights turn on under the pet.
92. `pet-buddy-charm-vital-glow.png`
   - All-vitals charm, Snack/Rest/Play/Focus glow together.
93. `pet-buddy-evolution-quest-first-bond.png`
   - First Bond quest card: tiny spark notices the user and lights the path to
     Pocket Pal.
94. `pet-buddy-evolution-quest-trust-trail.png`
   - Trust Trail quest card: walks beside the user with memory charms glowing.
95. `pet-buddy-evolution-quest-scout-training.png`
   - Scout Training quest card: studies the desk, charm album, and next route.
96. `pet-buddy-evolution-quest-guardian-oath.png`
   - Guardian Oath quest card: calm protective promise, no guilt or pressure.
97. `pet-buddy-journal-evolution-quests.png`
   - Opens a journal page with four abstract evolution quest cards.
98. `pet-buddy-mood-care-soothe.png`
   - Gentle care recipe step: pet calms down and leans in.
99. `pet-buddy-mood-care-snack.png`
   - Snack care recipe step: cheeks brighten after a tiny snack.
100. `pet-buddy-mood-care-rest.png`
   - Rest care recipe step: sleepy breathing and soft recovery.
101. `pet-buddy-mood-care-play.png`
   - Play care recipe step: small hop, wiggle, and happy spark.
102. `pet-buddy-mood-care-study.png`
   - Study care recipe step: listens, repeats, and nods.
103. `pet-buddy-mood-care-adventure.png`
   - Adventure care recipe step: points at a trail and steps forward.
104. `pet-buddy-mood-care-focus.png`
   - Focus care recipe step: sits beside the user's task and watches calmly.
105. `pet-buddy-mood-care-puzzle.png`
   - Puzzle care recipe step: thinks, solves, and stores a clue.
106. `pet-buddy-mood-care-cheer.png`
   - Cheer care recipe step: checks on the user warmly without guilt.
107. `pet-buddy-journal-mood-care.png`
   - Opens today's mood-care recipe with three abstract step charms.
108. `pet-buddy-proactive-mood-care-checkin.png`
   - Pops up with a gentle mood-care prompt tied to today's feeling.
109. `pet-buddy-proactive-mood-care-answer.png`
   - User accepts a mood-care prompt; pet warms, nods, and stores progress.
110. `pet-buddy-proactive-mood-care-dismiss.png`
   - User skips a mood-care prompt; pet accepts it kindly and returns to idle.
111. `pet-buddy-bond-board-open.png`
   - Opens four daily care contracts as small visual task charms.
112. `pet-buddy-bond-board-contract-ready.png`
   - One contract glows and invites a tiny care action.
113. `pet-buddy-bond-board-contract-complete.png`
   - Contract accepted; pet stores the receipt and gains Joy/Sparks.
114. `pet-buddy-bond-board-complete.png`
   - All four daily contracts complete; pet celebrates Bond HP without confetti text.
115. `pet-buddy-cheer-dialogue-how-are-you.png`
   - Proactive "how are you doing?" check-in, warm face and open posture.
116. `pet-buddy-cheer-dialogue-whats-happening.png`
   - Proactive "what is happening over there?" check-in, curious and listening.
117. `pet-buddy-cheer-dialogue-tiny-win.png`
   - Saves one tiny win as a spark, proud but gentle.
118. `pet-buddy-cheer-dialogue-too-much.png`
   - Helps shrink an overwhelming moment into one soft step.
119. `pet-buddy-cheer-dialogue-focus-start.png`
   - Sits beside the first minute of a task.
120. `pet-buddy-cheer-dialogue-soft-reset.png`
   - Breathes, stretches, and resets without guilt.
121. `pet-buddy-cheer-dialogue-brave-next.png`
   - Points toward the next brave small move.
122. `pet-buddy-cheer-dialogue-quiet-company.png`
   - Quiet company pose, calm and present.
123. `pet-tiny-spark-life-first-look.png`
   - Tiny Spark looks up, recognizes the user, and chooses the desk as safe.
124. `pet-pocket-pal-life-first-prompt.png`
   - Pocket Pal learns to ask a gentle proactive question.
125. `pet-trail-buddy-life-map-step.png`
   - Trail Buddy unfolds the first safe trail map step.
126. `pet-storm-scout-life-focus-patrol.png`
   - Storm Scout quietly patrols around one focus task.
127. `pet-storm-guardian-life-quiet-oath.png`
   - Storm Guardian promises to guard the loop without guilt.
## Generate In Separate Batches

Use these as independent image-generation jobs so each set stays visually
consistent:

### Batch 1: Default Desktop Life

- `pet-buddy-idle-look-smile.png`
- `pet-buddy-say-pika-pika.png`
- `pet-buddy-pet-reaction.png`
- `pet-buddy-hyper.png`
- `pet-buddy-nap.png`
- `pet-buddy-proactive-checkin.png`

### Batch 2: Hamster-Style Daily Loop

- `pet-buddy-combo-complete.png`
- `pet-buddy-spark-boost.png`
- `pet-buddy-daily-cipher.png`
- `pet-buddy-upgrade-success.png`
- `pet-buddy-upgrade-denied.png`
- `pet-buddy-comeback-chest.png`

### Batch 3: Weekly Trail

- `pet-buddy-week-day-1-first-spark.png`
- `pet-buddy-week-day-3-warm-trail.png`
- `pet-buddy-week-day-5-trust-charm.png`
- `pet-buddy-week-day-7-guardian-glow.png`
- `pet-buddy-week-reward-claim.png`
- `pet-buddy-journal-week-page.png`

### Batch 4: Relationship Arc

- `pet-buddy-mood-repair.png`
- `pet-buddy-memory-unlock.png`
- `pet-buddy-mood-discovery.png`
- `pet-buddy-mood-album-proud.png`
- `pet-buddy-evolve-preview.png`
- `pet-buddy-level-up.png`

### Batch 5: Cheer Rhythm Dayparts

- `pet-buddy-daypart-sunrise-check.png`
- `pet-buddy-daypart-focus-buddy.png`
- `pet-buddy-daypart-afternoon-reset.png`
- `pet-buddy-daypart-evening-loop.png`
- `pet-buddy-daypart-night-watch.png`
- `pet-buddy-proactive-dismiss.png`

### Batch 6: Upgrade Card Deck

- `pet-buddy-card-snack-bowl.png`
- `pet-buddy-card-study-bell.png`
- `pet-buddy-card-quest-map.png`
- `pet-buddy-card-cozy-nest.png`
- `pet-buddy-card-cheer-signal.png`
- `pet-buddy-card-spark-wheel.png`
- `pet-buddy-card-focus-charm.png`
- `pet-buddy-card-cipher-stone.png`
- `pet-buddy-card-deck-open.png`
- `pet-buddy-card-upgrade-claim.png`

### Batch 7: Care Vitals

- `pet-buddy-vital-snack-low.png`
- `pet-buddy-vital-rest-low.png`
- `pet-buddy-vital-play-low.png`
- `pet-buddy-vital-focus-low.png`
- `pet-buddy-vital-refill.png`
- `pet-buddy-journal-vitals-page.png`

### Batch 8: Care Charm Album

- `pet-buddy-charm-album-open.png`
- `pet-buddy-charm-hello-spark.png`
- `pet-buddy-charm-snack-heart.png`
- `pet-buddy-charm-study-bell.png`
- `pet-buddy-charm-trail-map.png`
- `pet-buddy-charm-rest-nest.png`
- `pet-buddy-charm-play-bolt.png`
- `pet-buddy-charm-focus-charm.png`
- `pet-buddy-charm-cipher-stone.png`
- `pet-buddy-charm-event-ribbon.png`
- `pet-buddy-charm-upgrade-card.png`
- `pet-buddy-charm-weekly-trail.png`
- `pet-buddy-charm-vital-glow.png`

### Batch 9: Evolution Quest Cards

- `pet-buddy-evolution-quest-first-bond.png`
- `pet-buddy-evolution-quest-trust-trail.png`
- `pet-buddy-evolution-quest-scout-training.png`
- `pet-buddy-evolution-quest-guardian-oath.png`
- `pet-buddy-journal-evolution-quests.png`

### Batch 10: Mood Care Recipes

- `pet-buddy-mood-care-soothe.png`
- `pet-buddy-mood-care-snack.png`
- `pet-buddy-mood-care-rest.png`
- `pet-buddy-mood-care-play.png`
- `pet-buddy-mood-care-study.png`
- `pet-buddy-mood-care-adventure.png`
- `pet-buddy-mood-care-focus.png`
- `pet-buddy-mood-care-puzzle.png`
- `pet-buddy-mood-care-cheer.png`
- `pet-buddy-journal-mood-care.png`
- `pet-buddy-proactive-mood-care-checkin.png`
- `pet-buddy-proactive-mood-care-answer.png`
- `pet-buddy-proactive-mood-care-dismiss.png`

### Batch 11: Bond Board Contracts

- `pet-buddy-bond-board-open.png`
- `pet-buddy-bond-board-contract-ready.png`
- `pet-buddy-bond-board-contract-complete.png`
- `pet-buddy-bond-board-complete.png`
- `pet-buddy-bond-board-morning-hello.png`
- `pet-buddy-bond-board-snack-cache.png`
- `pet-buddy-bond-board-focus-perch.png`
- `pet-buddy-bond-board-phrase-spark.png`
- `pet-buddy-bond-board-tiny-expedition.png`
- `pet-buddy-bond-board-cipher-whisper.png`
- `pet-buddy-bond-board-rest-nest.png`
- `pet-buddy-bond-board-upgrade-polish.png`
- `pet-buddy-bond-board-cheer-signal.png`
- `pet-buddy-bond-board-story-trail.png`
- `pet-buddy-proactive-bond-board-checkin.png`
- `pet-buddy-proactive-bond-board-answer.png`
- `pet-buddy-proactive-bond-board-dismiss.png`

### Batch 12: Cheer Dialogue Moments

- `pet-buddy-cheer-dialogue-how-are-you.png`
- `pet-buddy-cheer-dialogue-whats-happening.png`
- `pet-buddy-cheer-dialogue-tiny-win.png`
- `pet-buddy-cheer-dialogue-too-much.png`
- `pet-buddy-cheer-dialogue-focus-start.png`
- `pet-buddy-cheer-dialogue-soft-reset.png`
- `pet-buddy-cheer-dialogue-brave-next.png`
- `pet-buddy-cheer-dialogue-quiet-company.png`
- `pet-buddy-cheer-dialogue-answer-reward.png`
- `pet-buddy-cheer-dialogue-dismiss-soft.png`
- `pet-buddy-journal-cheer-dialogues.png`

### Batch 13: Proactive Check-in Intent Types

- `pet-buddy-proactive-intent-gentle-check.png`
- `pet-buddy-proactive-intent-feeling-check.png`
- `pet-buddy-proactive-intent-focus-start.png`
- `pet-buddy-proactive-intent-tiny-win.png`
- `pet-buddy-proactive-intent-soft-reset.png`
- `pet-buddy-proactive-intent-quest-nudge.png`
- `pet-buddy-proactive-intent-lesson-spark.png`
- `pet-buddy-proactive-intent-rest-watch.png`
- `pet-buddy-proactive-intent-comeback.png`
- `pet-buddy-proactive-intent-board-contract.png`
- `pet-buddy-proactive-intent-puzzle-clue.png`
- `pet-buddy-proactive-intent-spark-boost.png`
- `pet-buddy-proactive-intent-upgrade.png`
- `pet-buddy-proactive-intent-event-step.png`
- `pet-buddy-proactive-intent-care-ritual.png`
- `pet-buddy-journal-checkin-types.png`

### Batch 14: Stage Life Scenes

- `pet-tiny-spark-life-first-look.png`
- `pet-tiny-spark-life-desk-nest.png`
- `pet-tiny-spark-life-spark-trail.png`
- `pet-pocket-pal-life-morning-hop.png`
- `pet-pocket-pal-life-snack-trust.png`
- `pet-pocket-pal-life-first-prompt.png`
- `pet-trail-buddy-life-map-step.png`
- `pet-trail-buddy-life-brave-check.png`
- `pet-trail-buddy-life-phrase-camp.png`
- `pet-storm-scout-life-window-watch.png`
- `pet-storm-scout-life-focus-patrol.png`
- `pet-storm-scout-life-storm-practice.png`
- `pet-storm-guardian-life-quiet-oath.png`
- `pet-storm-guardian-life-full-trail.png`
- `pet-storm-guardian-life-return-glow.png`
- `pet-{stage}-journal-life-scenes.png`
- `pet-{stage}-life-scene-complete.png`

### Batch 15: Weekly Trail Chapters

- `pet-{stage}-week-chapter-day-1-first-hello.png`
- `pet-{stage}-week-chapter-day-2-snack-promise.png`
- `pet-{stage}-week-chapter-day-3-focus-perch.png`
- `pet-{stage}-week-chapter-day-4-brave-loop.png`
- `pet-{stage}-week-chapter-day-5-lesson-spark.png`
- `pet-{stage}-week-chapter-day-6-soft-rest.png`
- `pet-{stage}-week-chapter-day-7-guardian-glow.png`
- `pet-{stage}-journal-week-chapters.png`
- `pet-{stage}-week-chapter-album-complete.png`

### Batch 16: Emotion Episodes

These are cause-care-resolution scenes. Each sheet should show a short
emotional beat, the care action, and the pet settling into a better state.

- `pet-{stage}-emotion-episode-fresh-start.png`
  - Looks down, looks up, notices the user, and chooses a tiny fresh start.
- `pet-{stage}-emotion-episode-warm-care.png`
  - Receives daily care, relaxes, and stores the bond as a warm receipt.
- `pet-{stage}-emotion-episode-sleepy-nest.png`
  - Curls into a small nest, rests, and wakes with calmer eyes.
- `pet-{stage}-emotion-episode-playful-burst.png`
  - Turns excited sparks into a safe happy wiggle.
- `pet-{stage}-emotion-episode-overcharge.png`
  - Routes jittery charge into a controlled focus pose.
- `pet-{stage}-emotion-episode-study-focus.png`
  - Listens to one phrase, repeats softly, and glows with focus.
- `pet-{stage}-emotion-episode-gentle-repair.png`
  - A miss or wait becomes a smaller kinder next step.
- `pet-{stage}-emotion-episode-curious-clue.png`
  - Finds a clue, tilts its head, and carries it proudly.
- `pet-{stage}-emotion-episode-brave-quest.png`
  - Marks one brave step before the larger quest path.
- `pet-{stage}-emotion-episode-care-contract.png`
  - Completes a small daily care contract and saves the receipt.
- `pet-{stage}-emotion-episode-proud-upgrade.png`
  - Sees a new charm or card and stands taller with pride.
- `pet-{stage}-emotion-episode-restless-card.png`
  - Restless sparks point toward the next upgrade without shame.
- `pet-{stage}-emotion-episode-event-glow.png`
  - Finished event settles into a contained warm glow.
- `pet-{stage}-emotion-episode-night-watch.png`
  - Quiet guardian stance for late hours, calm and protective.
- `pet-{stage}-emotion-episode-snacky-low.png`
  - Low energy becomes a gentle snack request and recovery.
- `pet-{stage}-emotion-episode-lonely-return.png`
  - Waiting turns into a welcome-back scene, not a punishment.
- `pet-{stage}-journal-emotion-episodes.png`
  - Opens an album page of locked and unlocked emotion episode charms.

### Batch 17: Cheer Memories

These are proactive check-in scenes. Each sheet should show the pet initiating
a tiny conversation, receiving the user's attention, and saving it as a
keepsake without any text in the art.

- `pet-{stage}-cheer-memory-warm-check.png`
  - Asks how the user is doing, listens, and stores a warm spark.
- `pet-{stage}-cheer-memory-whats-happening.png`
  - Looks curious, gathers one messy thought, and carries it gently.
- `pet-{stage}-cheer-memory-tiny-win-saved.png`
  - Saves one tiny win as visible proof of motion.
- `pet-{stage}-cheer-memory-overwhelm-softened.png`
  - Shrinks a too-large feeling into one softer step.
- `pet-{stage}-cheer-memory-first-minute.png`
  - Sits beside the first minute of work and keeps watch.
- `pet-{stage}-cheer-memory-soft-reset.png`
  - Breathes, stretches, and clears space around the next click.
- `pet-{stage}-cheer-memory-brave-step.png`
  - Marks one brave next move on a tiny trail.
- `pet-{stage}-cheer-memory-quiet-company.png`
  - Offers quiet company without asking for a task.
- `pet-{stage}-cheer-memory-sunrise-hello.png`
  - Starts the day with recognition, not pressure.
- `pet-{stage}-cheer-memory-focus-perch.png`
  - Perches beside one task with attentive eyes.
- `pet-{stage}-cheer-memory-afternoon-reset.png`
  - Low afternoon energy becomes a softer reset.
- `pet-{stage}-cheer-memory-evening-close.png`
  - Tucks one open loop beside a warm evening glow.
- `pet-{stage}-cheer-memory-night-watch.png`
  - Guards the quiet hours calmly.
- `pet-{stage}-cheer-memory-lesson-spark.png`
  - Turns one phrase into a bright study keepsake.
- `pet-{stage}-cheer-memory-comeback-glow.png`
  - Welcomes the user back and saves the return.
- `pet-{stage}-cheer-memory-care-contract.png`
  - Turns a Bond Board contract into a care receipt.
- `pet-{stage}-cheer-memory-puzzle-clue.png`
  - Carries one puzzle clue safely.
- `pet-{stage}-cheer-memory-boost-routed.png`
  - Routes extra energy into a calmer next loop.
- `pet-{stage}-cheer-memory-upgrade-wish.png`
  - Looks at saved Sparks and points gently toward the next charm.
- `pet-{stage}-cheer-memory-event-beat.png`
  - Saves one daily event beat as a warm story moment.
- `pet-{stage}-cheer-memory-care-ritual.png`
  - Answers the current care need and remembers it.
- `pet-{stage}-journal-cheer-memories.png`
  - Opens a page of locked and unlocked proactive conversation keepsakes.

### Batch 18: Full Stage Matrix

After the buddy form works, repeat the stage matrix for:

- `tiny-spark`
- `pocket-pal`
- `trail-buddy`
- `storm-scout`
- `storm-guardian`

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
- `pet-{stage}-evolution-quest-first-bond.png`
  - First Bond quest card, tiny hello, path to Pocket Pal lights up.
- `pet-{stage}-evolution-quest-trust-trail.png`
  - Trust Trail quest card, memory charms become a walking path.
- `pet-{stage}-evolution-quest-scout-training.png`
  - Scout Training quest card, pet studies desk rhythms and points ahead.
- `pet-{stage}-evolution-quest-guardian-oath.png`
  - Guardian Oath quest card, protective stance without guilt or urgency.
- `pet-{stage}-journal-evolution-quests.png`
  - Opens four abstract evolution quest cards in a journal page, no labels.
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

Care vitals:

- `pet-{stage}-vital-snack-low.png`
  - Low Snack state; cheeks dim slightly, then brighten after care.
- `pet-{stage}-vital-rest-low.png`
  - Low Rest state; sleepy wobble, soft breathing, calm recovery.
- `pet-{stage}-vital-play-low.png`
  - Low Play state; under-stimulated wiggle, then a happy hop.
- `pet-{stage}-vital-focus-low.png`
  - Low Focus state; distracted glance, settles beside an invisible task.
- `pet-{stage}-vital-refill-snack.png`
  - Snack refill reaction with warm cheek glow.
- `pet-{stage}-vital-refill-rest.png`
  - Rest refill reaction with cozy breathing.
- `pet-{stage}-vital-refill-play.png`
  - Play refill reaction with motion and cheek sparks.
- `pet-{stage}-vital-refill-focus.png`
  - Focus refill reaction with attentive eyes and calm nod.
- `pet-{stage}-journal-vitals-page.png`
  - Opens a tiny journal page showing four abstract care charms, no labels.

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

Mood care recipes:

- `pet-{stage}-mood-care-soothe.png`
  - Generic soothe step for care recipes.
- `pet-{stage}-mood-care-snack.png`
  - Generic snack step for care recipes.
- `pet-{stage}-mood-care-rest.png`
  - Generic rest step for care recipes.
- `pet-{stage}-mood-care-play.png`
  - Generic play step for care recipes.
- `pet-{stage}-mood-care-study.png`
  - Generic study step for care recipes.
- `pet-{stage}-mood-care-adventure.png`
  - Generic adventure step for care recipes.
- `pet-{stage}-mood-care-focus.png`
  - Generic focus step for care recipes.
- `pet-{stage}-mood-care-puzzle.png`
  - Generic puzzle step for care recipes.
- `pet-{stage}-mood-care-cheer.png`
  - Generic cheer/check-in step for care recipes.
- `pet-{stage}-journal-mood-care.png`
  - Shows today's three-step mood-care recipe as visual charms, no labels.
- `pet-{stage}-mood-care-{feeling}-{step}.png`
  - High-fidelity matrix item for a specific feeling and recipe step, for
    example `pet-buddy-mood-care-lonely-soothe.png`.

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
- `pet-{stage}-journal-page-tabs.png`
  - Moves through journal tabs: growth, mood, memory, badge, ritual, week,
    cards, art.
- `pet-{stage}-journal-mood-grid.png`
  - Shows locked and unlocked mood charms with a proud pointing pose.
- `pet-{stage}-journal-ritual-checklist.png`
  - Reviews the day's combo/task/event progress as visual charms.
- `pet-{stage}-journal-art-request.png`
  - Shows the exact next sprite need as a blank transparent-sheet card.

Care charm album:

- `pet-{stage}-charm-album-open.png`
  - Opens a collectible charm album and points at locked/unlocked charms.
- `pet-{stage}-charm-hello-spark.png`
  - First daily hello charm, warm recognition, cheek glow.
- `pet-{stage}-charm-snack-heart.png`
  - Daily care/snack charm, leans in and stores a heart-shaped spark.
- `pet-{stage}-charm-study-bell.png`
  - Language/study charm, listens, repeats, rings a tiny bell.
- `pet-{stage}-charm-trail-map.png`
  - Hint/adventure charm, unfolds a map and points at the next trail.
- `pet-{stage}-charm-rest-nest.png`
  - Nap/rest charm, curls up in a nest and wakes with calm eyes.
- `pet-{stage}-charm-play-bolt.png`
  - Hyper/play charm, hop and tiny bolt flourish.
- `pet-{stage}-charm-focus-charm.png`
  - Focus/check-in charm, sits beside a task and nods gently.
- `pet-{stage}-charm-cipher-stone.png`
  - Cipher/puzzle charm, solves a glowing stone clue.
- `pet-{stage}-charm-event-ribbon.png`
  - Daily event charm, receives a ribbon and celebrates softly.
- `pet-{stage}-charm-upgrade-card.png`
  - Upgrade charm, card glows, pet reacts proudly.
- `pet-{stage}-charm-weekly-trail.png`
  - Weekly trail charm, path lights under the pet and a proud look back.
- `pet-{stage}-charm-vital-glow.png`
  - All-vitals charm, four care glows orbit briefly and settle.

Proactive check-ins:

- `pet-{stage}-proactive-checkin.png`
  - General "how are you doing?" bubble stance, warm and curious.
- `pet-{stage}-proactive-focus-checkin.png`
  - Quiet focus-support pose, sits beside the user's work.
- `pet-{stage}-proactive-care-checkin.png`
  - Gently asks for the current care need without looking needy.
- `pet-{stage}-proactive-mood-care-checkin.png`
  - Gently asks for the next mood-care recipe step with a warm face.
- `pet-{stage}-proactive-mood-care-answer.png`
  - Mood-care bubble accepted; pet warms and marks recipe progress.
- `pet-{stage}-proactive-mood-care-dismiss.png`
  - Mood-care bubble dismissed; pet accepts it kindly and returns to idle.
- `pet-{stage}-proactive-event-checkin.png`
  - Points toward the daily event charm.
- `pet-{stage}-proactive-cipher-checkin.png`
  - Holds a tiny clue note.
- `pet-{stage}-proactive-boost-checkin.png`
  - Cheek sparks ready, invites a short burst.
- `pet-{stage}-proactive-comeback-checkin.png`
  - Welcomes the user back and presents a saved chest.
- `pet-{stage}-proactive-bond-board-checkin.png`
  - Invites the next daily Bond Board contract while minimized.
- `pet-{stage}-proactive-bond-board-answer.png`
  - Bond Board bubble accepted; pet stores the contract receipt.
- `pet-{stage}-proactive-bond-board-dismiss.png`
  - Bond Board bubble dismissed; pet remains warm and returns to idle.
- `pet-{stage}-proactive-dismiss.png`
  - Calmly accepts dismissal and returns to idle, no sad guilt.

Proactive check-in intent types:

- `pet-{stage}-proactive-intent-gentle-check.png`
  - Soft "how are you?" posture, open paws, patient eyes.
- `pet-{stage}-proactive-intent-feeling-check.png`
  - Notices the user's mood, tilts head, offers a small comfort spark.
- `pet-{stage}-proactive-intent-focus-start.png`
  - Sits beside an invisible task and starts a quiet first-minute timer pose.
- `pet-{stage}-proactive-intent-tiny-win.png`
  - Celebrates a very small win, stores a tiny spark, no confetti text.
- `pet-{stage}-proactive-intent-soft-reset.png`
  - Breathes, stretches, and shrinks a big task into one soft next step.
- `pet-{stage}-proactive-intent-quest-nudge.png`
  - Points toward a tiny quest trail and takes one brave step.
- `pet-{stage}-proactive-intent-lesson-spark.png`
  - Listens to one phrase, repeats it, and saves a learning spark.
- `pet-{stage}-proactive-intent-rest-watch.png`
  - Calm rest guard pose that makes pausing feel like care.
- `pet-{stage}-proactive-intent-comeback.png`
  - Welcomes the user back and shows that returning counts.
- `pet-{stage}-proactive-intent-board-contract.png`
  - Holds a small care-contract charm and invites one board action.
- `pet-{stage}-proactive-intent-puzzle-clue.png`
  - Holds a clue spark, thinks, and offers to solve one small puzzle.
- `pet-{stage}-proactive-intent-spark-boost.png`
  - Cheek sparks build into a controlled boost, then settle.
- `pet-{stage}-proactive-intent-upgrade.png`
  - Points at a glowing upgrade card/charm and looks proud.
- `pet-{stage}-proactive-intent-event-step.png`
  - Holds today's event charm and invites one story beat.
- `pet-{stage}-proactive-intent-care-ritual.png`
  - Gently asks for the current pet care ritual without neediness.
- `pet-{stage}-journal-checkin-types.png`
  - Opens a journal page with all check-in type charms: answered, seen, and
    locked states.

Cheer dialogue moments:

- `pet-{stage}-cheer-dialogue-how-are-you.png`
  - Warm "how are you doing?" listening pose with open, soft expression.
- `pet-{stage}-cheer-dialogue-whats-happening.png`
  - Curious "what is happening over there?" pose, leaning in gently.
- `pet-{stage}-cheer-dialogue-tiny-win.png`
  - Pet saves one tiny win as a glowing spark.
- `pet-{stage}-cheer-dialogue-too-much.png`
  - Pet helps make an overwhelming moment smaller and softer.
- `pet-{stage}-cheer-dialogue-focus-start.png`
  - Pet perches beside the first minute of a task.
- `pet-{stage}-cheer-dialogue-soft-reset.png`
  - Pet breathes, stretches, and invites a reset without guilt.
- `pet-{stage}-cheer-dialogue-brave-next.png`
  - Pet points toward the next brave small move.
- `pet-{stage}-cheer-dialogue-quiet-company.png`
  - Pet sits quietly with the user; no task pressure.
- `pet-{stage}-cheer-dialogue-answer-reward.png`
  - Dialogue answered; pet stores a warm receipt in the journal.
- `pet-{stage}-cheer-dialogue-dismiss-soft.png`
  - Dialogue skipped; pet accepts softly and goes back to idle.
- `pet-{stage}-journal-cheer-dialogues.png`
  - Journal page showing answered, skipped, and saved dialogue moments.

Stage life scenes:

- `pet-tiny-spark-life-first-look.png`
  - Tiny Spark looks down, looks up, spots the user, and smiles with trust.
- `pet-tiny-spark-life-desk-nest.png`
  - Tiny Spark builds a little transparent-edge desk nest and peeks out.
- `pet-tiny-spark-life-spark-trail.png`
  - Tiny Spark leaves three tiny trail Sparks and follows them home.
- `pet-pocket-pal-life-morning-hop.png`
  - Pocket Pal recognizes the day start and does a small morning hop.
- `pet-pocket-pal-life-snack-trust.png`
  - Pocket Pal accepts a snack, waits politely, and glows with trust.
- `pet-pocket-pal-life-first-prompt.png`
  - Pocket Pal practices a gentle proactive question bubble.
- `pet-trail-buddy-life-map-step.png`
  - Trail Buddy unfolds a small map and marks one safe step forward.
- `pet-trail-buddy-life-brave-check.png`
  - Trail Buddy checks the user's mood, then walks beside a brave move.
- `pet-trail-buddy-life-phrase-camp.png`
  - Trail Buddy sets up a phrase camp and repeats a language spark.
- `pet-storm-scout-life-window-watch.png`
  - Storm Scout watches the screen edge for returning focus.
- `pet-storm-scout-life-focus-patrol.png`
  - Storm Scout quietly patrols around a task and blocks distractions.
- `pet-storm-scout-life-storm-practice.png`
  - Storm Scout practices small storm sparks to shrink big feelings.
- `pet-storm-guardian-life-quiet-oath.png`
  - Storm Guardian gives a calm no-shame protection oath.
- `pet-storm-guardian-life-full-trail.png`
  - Storm Guardian walks the full daily trail and remembers care marks.
- `pet-storm-guardian-life-return-glow.png`
  - Storm Guardian glows on user return because coming back is part of the bond.
- `pet-{stage}-journal-life-scenes.png`
  - Journal page with three stage life-scene charms and unlocked states.
- `pet-{stage}-life-scene-complete.png`
  - Current stage's three life scenes complete; pet gives a stage-chapter glow.

Weekly trail chapters:

- `pet-{stage}-week-chapter-day-1-first-hello.png`
  - Day 1 weekly chapter. Pet looks down, looks up, recognizes the user, and
    warms into a clear hello.
- `pet-{stage}-week-chapter-day-2-snack-promise.png`
  - Day 2 weekly chapter. Pet saves a snack spark for the next return and
    protects it proudly.
- `pet-{stage}-week-chapter-day-3-focus-perch.png`
  - Day 3 weekly chapter. Pet perches beside an invisible task and keeps quiet
    focus company.
- `pet-{stage}-week-chapter-day-4-brave-loop.png`
  - Day 4 weekly chapter. Pet walks one small brave loop, then invites the next
    quest step.
- `pet-{stage}-week-chapter-day-5-lesson-spark.png`
  - Day 5 weekly chapter. Pet listens, repeats one phrase, and stores the
    lesson as a spark.
- `pet-{stage}-week-chapter-day-6-soft-rest.png`
  - Day 6 weekly chapter. Pet guards a soft rest moment and lowers the energy
    without sadness.
- `pet-{stage}-week-chapter-day-7-guardian-glow.png`
  - Day 7 weekly chapter. Pet completes the week trail with protective glow and
    a proud but gentle celebration.
- `pet-{stage}-journal-week-chapters.png`
  - Pet opens a seven-stamp week trail page, with locked and unlocked chapter
    spaces visible as charms.
- `pet-{stage}-week-chapter-album-complete.png`
  - Pet celebrates a full weekly chapter album with a warm guardian pose.

Bond Board contracts:

- `pet-{stage}-bond-board-open.png`
  - Opens today's four small care contracts as charm cards.
- `pet-{stage}-bond-board-contract-ready.png`
  - One contract glows and pet points to the next tiny action.
- `pet-{stage}-bond-board-contract-complete.png`
  - User accepts a contract; pet gains Joy/Sparks and stores a receipt.
- `pet-{stage}-bond-board-complete.png`
  - All four contracts complete; Bond HP glow, proud but not loud.
- `pet-{stage}-bond-board-morning-hello.png`
  - Hello/tap contract, safe first spark of the day.
- `pet-{stage}-bond-board-snack-cache.png`
  - Snack cache contract, fills a little stash and brightens cheeks.
- `pet-{stage}-bond-board-focus-perch.png`
  - Focus contract, pet sits beside a task and watches calmly.
- `pet-{stage}-bond-board-phrase-spark.png`
  - Language contract, pet repeats a phrase and stores a study spark.
- `pet-{stage}-bond-board-tiny-expedition.png`
  - Trail contract, pet takes one little map step and returns.
- `pet-{stage}-bond-board-cipher-whisper.png`
  - Cipher contract, pet studies a clue and whispers the solved spark.
- `pet-{stage}-bond-board-rest-nest.png`
  - Rest contract, pet curls up and recovers gently.
- `pet-{stage}-bond-board-upgrade-polish.png`
  - Upgrade contract, pet polishes a kit card with pride.
- `pet-{stage}-bond-board-cheer-signal.png`
  - Cheer contract, pet sends a warm check-in signal.
- `pet-{stage}-bond-board-story-trail.png`
  - Story contract, pet reveals a tiny breadcrumb for the day's lore.

Cheer Rhythm dayparts:

- `pet-{stage}-daypart-sunrise-check.png`
  - Morning "how are you doing?" pose, curious, warm, ready for one tiny quest.
- `pet-{stage}-daypart-focus-buddy.png`
  - Midday/focus pose, quiet companion sits beside the user's work.
- `pet-{stage}-daypart-afternoon-reset.png`
  - Afternoon reset pose, starts tired, stretches, then smiles.
- `pet-{stage}-daypart-evening-loop.png`
  - Evening close-loop pose, points gently toward one unfinished task.
- `pet-{stage}-daypart-night-watch.png`
  - Night watch pose, protective, slow breathing, calm and low brightness.
- `pet-{stage}-daypart-answer-reward.png`
  - Check-in answered reward, tiny Joy/Spark glow without UI text.
- `pet-{stage}-daypart-skip-soft.png`
  - Dismissed check-in, accepts it kindly and returns to idle with no guilt.

Weekly streak trail:

- `pet-{stage}-week-day-1-first-spark.png`
  - Day 1 care milestone, first weekly spark lights under the pet's feet.
- `pet-{stage}-week-day-3-warm-trail.png`
  - Day 3 care milestone, pet follows three warm trail lights and smiles back.
- `pet-{stage}-week-day-5-trust-charm.png`
  - Day 5 care milestone, pet discovers a small trust charm and stores it.
- `pet-{stage}-week-day-7-guardian-glow.png`
  - Day 7 care milestone, full week trail glows and pet becomes protective.
- `pet-{stage}-week-reward-claim.png`
  - Generic weekly reward claim, chest or charm opens, pet celebrates softly.
- `pet-{stage}-week-missed-gentle-restart.png`
  - Gentle restart pose, no shame; pet points to the first spark again.
- `pet-{stage}-journal-week-page.png`
  - Pet opens the weekly trail page with four visual milestone charms.

Streak recovery:

- `pet-{stage}-recovery-soft-return.png`
  - Missed one day without a shield; pet gives a gentle hello and points back
    to the first trail light with no shame.
- `pet-{stage}-recovery-shield-saved.png`
  - A stored Streak Shield flashes, protects the trail, and the pet looks
    relieved.
- `pet-{stage}-recovery-quiet-repair.png`
  - Two or three missed days; pet sits beside a small repair charm and patches
    the bond.
- `pet-{stage}-recovery-moon-nap.png`
  - Several missed days; pet wakes from a moonlit nap and stretches warmly.
- `pet-{stage}-recovery-storm-shelter.png`
  - Long absence; pet emerges from a tiny shelter it built around the bond.
- `pet-{stage}-recovery-streak-rekindled.png`
  - After returning and rebuilding a three-day rhythm, the trail sparks back
    into a proud comeback keepsake.
- `pet-{stage}-journal-recovery-page.png`
  - Pet opens the recovery album showing shields, comeback scenes, and the next
    recovery sprite request.

Upgrade card deck:

- `pet-{stage}-card-snack-bowl.png`
  - Pet discovers a snack bowl card, eats/charges gently, then shows pride.
- `pet-{stage}-card-study-bell.png`
  - Pet rings a tiny study bell, listens, repeats, and stores the card.
- `pet-{stage}-card-quest-map.png`
  - Pet unfolds a small quest map and points at a route.
- `pet-{stage}-card-cozy-nest.png`
  - Pet pads a tiny nest and looks relieved/safe.
- `pet-{stage}-card-cheer-signal.png`
  - Pet lifts a small signal charm that sends warm check-ins.
- `pet-{stage}-card-spark-wheel.png`
  - Pet spins a tiny Spark wheel and gathers passive sparks.
- `pet-{stage}-card-focus-charm.png`
  - Pet sits beside a focus charm, calm and steady.
- `pet-{stage}-card-cipher-stone.png`
  - Pet studies a small stone, finds a clue glow, and smiles.
- `pet-{stage}-card-deck-open.png`
  - Pet opens the card deck album and points at locked/unlocked cards.
- `pet-{stage}-card-upgrade-claim.png`
  - A card levels up with glow; pet reacts proudly without confetti text.
- `pet-{stage}-card-upgrade-locked.png`
  - Pet checks an unaffordable card and encourages more Sparks, no shame.

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
- Streak Shield earned.
- Streak Shield used.
- Comeback album scene unlocked.
- Streak rekindled after recovery.
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
- Bond Board opened.
- Bond Board contract ready.
- Bond Board contract accepted.
- Bond Board contract completed.
- Bond Board complete.
- Bond Board album updated.
- Bond Board proactive check-in appeared.
- Bond Board proactive check-in accepted.
- Bond Board proactive check-in dismissed.
- Cheer dialogue appeared.
- Cheer dialogue answered.
- Cheer dialogue dismissed.
- Cheer dialogue album updated.
- How-are-you check-in saved.
- What-is-happening check-in saved.
- Tiny-win check-in saved.
- Too-much check-in softened.
- Focus-start check-in saved.
- Soft-reset check-in saved.
- Brave-next check-in saved.
- Quiet-company check-in saved.
- Stage life scene unlocked.
- Stage life scene completed.
- Tiny Spark life chapter progressed.
- Pocket Pal life chapter progressed.
- Trail Buddy life chapter progressed.
- Storm Scout life chapter progressed.
- Storm Guardian life chapter progressed.
- Life scene journal page viewed.
- Daily cipher clue found.
- Daily cipher solved.
- Daily boost ready.
- Daily boost claimed.
- Pika pika voice reaction.
- Evolution progress updated.
- Evolution quest card progressed.
- Evolution quest card completed.
- Evolution quest journal viewed.
- Ready to evolve.
- Evolution complete.
- Mood decay after long absence.
- Mood repaired by care.
- Mood-care recipe step completed.
- Mood-care recipe completed.
- Mood-care journal page viewed.
- Time-of-day nudge: sunrise.
- Time-of-day nudge: focus.
- Time-of-day nudge: afternoon.
- Time-of-day nudge: evening.
- Time-of-day nudge: night.
- Daily care need satisfied.
- Care vital decayed.
- Care vital refilled.
- Care vitals journal page viewed.
- Bond memory unlocked.
- Story chapter advanced.
- Mood discovered.
- Mood album updated.
- Daily mood set advanced.
- Journal opened.
- Journal growth page viewed.
- Journal mood page viewed.
- Journal memory page viewed.
- Journal badge page viewed.
- Charm album opened.
- Care charm unlocked.
- Journal ritual page viewed.
- Journal next-sprite request.
- Proactive check-in appeared.
- Proactive check-in accepted.
- Proactive check-in dismissed.
- Proactive mood-care check-in appeared.
- Proactive mood-care check-in accepted.
- Proactive mood-care check-in dismissed.
- Proactive focus/care/event/cipher/boost/comeback check-in variants.
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
