# PocketDM Pet Sprite Sheet Request List

## Required Format

Use this for every sheet so extraction stays clean:

- PNG with transparent background.
- 12 frames per animation, horizontal strip preferred.
- 2 x 6 contact-sheet-style layouts are accepted for first-pass concept demos;
  the native macOS loader can slice them, but horizontal strips are still the
  preferred final animation format.
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

### Batch 14: User Check-in States

- `pet-buddy-user-check-bright.png`
- `pet-buddy-user-check-tired.png`
- `pet-buddy-user-check-stuck.png`
- `pet-buddy-user-check-overwhelmed.png`
- `pet-buddy-user-check-lonely.png`
- `pet-buddy-user-check-proud.png`
- `pet-buddy-user-check-focused.png`
- `pet-buddy-user-check-need-break.png`
- `pet-buddy-journal-user-checkins.png`

### Batch 15: Stage Life Scenes

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

### Batch 19: Ambient Desktop Life

- `pet-{stage}-ambient-first-look.png`
- `pet-{stage}-ambient-desk-perch.png`
- `pet-{stage}-ambient-snack-sniff.png`
- `pet-{stage}-ambient-soft-stretch.png`
- `pet-{stage}-ambient-spark-patrol.png`
- `pet-{stage}-ambient-cheek-spark.png`
- `pet-{stage}-ambient-sleepy-guard.png`
- `pet-{stage}-ambient-journal-peek.png`
- `pet-{stage}-journal-ambient-life.png`

### Batch 20: Daily Spark Route

Generate these as route/progression sheets for each growth stage:

- `pet-{stage}-route-wake-spark.png`
  - Looks down, looks up, finds the user, and starts the daily path.
- `pet-{stage}-route-care-tap.png`
  - Receives one care tap and turns it into a visible bond receipt.
- `pet-{stage}-route-snack-stash.png`
  - Checks a tiny snack stash and relaxes when it is full.
- `pet-{stage}-route-focus-perch.png`
  - Perches beside a task like a calm desk companion.
- `pet-{stage}-route-lesson-spark.png`
  - Repeats one language phrase and saves the sound as a spark.
- `pet-{stage}-route-quest-trail.png`
  - Points toward a small adventure breadcrumb.
- `pet-{stage}-route-cipher-pulse.png`
  - Solves or protects one secret daily word.
- `pet-{stage}-route-upgrade-polish.png`
  - Polishes one kit/card upgrade and looks proud of maintenance.
- `pet-{stage}-route-cheer-call.png`
  - Pops into a proactive check-in and waits warmly for an answer.
- `pet-{stage}-route-boost-rush.png`
  - Claims a controlled spark boost without looking frantic.
- `pet-{stage}-route-ambient-patrol.png`
  - Makes one tiny desk patrol, turning idle animation into story progress.
- `pet-{stage}-route-bedtime-nest.png`
  - Curls into a quiet close-of-day nest moment.
- `pet-{stage}-charm-spark-route.png`
  - One collectible charm for completing the whole daily Spark Route.
- `pet-{stage}-journal-spark-route.png`
  - Journal view showing today's route, completed beats, and next step.

### Batch 21: Mood Story Check-ins

Generate these as proactive emotional check-in sheets for each growth stage:

- `pet-{stage}-mood-story-bright-hello.png`
  - Finds the user, lights up, and offers one tiny hello.
- `pet-{stage}-mood-story-eager-step.png`
  - Bouncy eager stance asking for the smallest next step.
- `pet-{stage}-mood-story-proud-receipt.png`
  - Saves a completed action as visible proof before it disappears.
- `pet-{stage}-mood-story-overcharge-ground.png`
  - Grounds cheek sparks into a controlled calm move.
- `pet-{stage}-mood-story-focused-perch.png`
  - Quiet desk-perch focus companion for one minute.
- `pet-{stage}-mood-story-celebration-save.png`
  - Tucks a glowing win into the album with a happy hop.
- `pet-{stage}-mood-story-guardian-check.png`
  - Late-night protective check-in, calm and non-demanding.
- `pet-{stage}-mood-story-gentle-repair.png`
  - Soft repair after a rough moment or failed attempt.
- `pet-{stage}-mood-story-playful-spark.png`
  - Tiny play burst that releases energy safely.
- `pet-{stage}-mood-story-grateful-thanks.png`
  - Thank-you sparkle after the user comes back.
- `pet-{stage}-mood-story-determined-bridge.png`
  - Builds a bridge toward the next growth form.
- `pet-{stage}-mood-story-restless-polish.png`
  - Turns restless energy into upgrade-card polishing.
- `pet-{stage}-mood-story-snack-ask.png`
  - Names snack need gently before it becomes a wobble.
- `pet-{stage}-mood-story-sleepy-permission.png`
  - Asks for permission to let rest count as care.
- `pet-{stage}-mood-story-curious-question.png`
  - Asks "what is happening?" and carries one small answer.
- `pet-{stage}-mood-story-lonely-reach.png`
  - Reaches back softly after waiting, without guilt.
- `pet-{stage}-mood-story-sunrise-look-up.png`
  - Looks down, looks up, recognizes the user, and smiles into the morning.
- `pet-{stage}-mood-story-focus-blink.png`
  - Blinks twice, chooses the task, and settles into a focus perch.
- `pet-{stage}-mood-story-afternoon-wobble.png`
  - Shows a soft low-energy wobble that can be turned into a reset.
- `pet-{stage}-mood-story-evening-campfire.png`
  - Holds a warm campfire glow for tucking one loose loop.
- `pet-{stage}-mood-story-night-nest-guard.png`
  - Curls into a nest while still keeping a protective watch.
- `pet-{stage}-mood-story-tiny-trust.png`
  - Tiny form leans closer, unsure but starting to trust the desktop.
- `pet-{stage}-mood-story-trail-courage.png`
  - Trail form taps the map and offers one brave breadcrumb.
- `pet-{stage}-mood-story-guardian-glow.png`
  - Final guardian form glows with remembered returns and calm confidence.
- `pet-{stage}-journal-mood-stories.png`
  - Journal view of answered, skipped, and album-saved mood stories.

### Batch 22: Field Note Reports

Generate these as tiny desktop-report sheets for each growth stage:

- `pet-{stage}-field-note-desk-scout.png`
  - Scouts the screen edge, marks one safe start point, then looks back.
- `pet-{stage}-field-note-snack-map.png`
  - Finds a snack signal, points to it gently, and saves the map.
- `pet-{stage}-field-note-focus-weather.png`
  - Checks the desk "weather" and settles into one clean focus minute.
- `pet-{stage}-field-note-lesson-echo.png`
  - Holds a glowing phrase echo and offers it back for practice.
- `pet-{stage}-field-note-quest-trace.png`
  - Traces the adventure path and leaves a small next-choice marker.
- `pet-{stage}-field-note-spark-forecast.png`
  - Counts Sparks, forecasts a bright return window, and bounces once.
- `pet-{stage}-field-note-rest-signal.png`
  - Lowers the loop pressure and shows rest counting as progress.
- `pet-{stage}-field-note-upgrade-sketch.png`
  - Sketches the next upgrade card with a focused little pose.
- `pet-{stage}-field-note-comeback-trace.png`
  - Saves the path back after time away, warm rather than guilty.
- `pet-{stage}-field-note-bond-receipt.png`
  - Turns a tiny care action into visible bond proof.
- `pet-{stage}-field-note-guardian-log.png`
  - Quiet late-hour watch log, calm glow, no urgency.
- `pet-{stage}-field-note-art-request.png`
  - Opens the sprite journal and circles the next missing animation.
- `pet-{stage}-journal-field-notes.png`
  - Journal view showing found, saved, skipped, and album field notes.

### Batch 23: Home Rooms

Generate these as habitat sheets for each growth stage. These make the pet feel
like it has a home, not only a floating chat surface.

- `pet-{stage}-home-cozy-nest.png`
  - Circles a small nest, settles the blanket, then checks that the desk feels
    safe.
- `pet-{stage}-home-snack-nook.png`
  - Noses through a tiny snack nook and saves one treat for later.
- `pet-{stage}-home-study-perch.png`
  - Climbs to a study perch and sits beside one focused minute.
- `pet-{stage}-home-quest-lookout.png`
  - Peers from a lookout and marks one gentle quest direction.
- `pet-{stage}-home-spark-gym.png`
  - Runs a contained spark loop so high energy has somewhere safe to go.
- `pet-{stage}-home-moon-den.png`
  - Checks the moon den, lowers the room noise, and guards the streak.
- `pet-{stage}-home-cipher-cave.png`
  - Taps a cipher wall until one clue glow wakes up.
- `pet-{stage}-home-celebration-porch.png`
  - Hops onto a tiny porch and saves the day's win without text.
- `pet-{stage}-journal-home-rooms.png`
  - Journal view showing visited, offered, skipped, and album-saved rooms.

### Batch 24: Wishbook

Generate these as daily desire sheets for each growth stage. Each wish should
look like the pet gently asking for something small and emotionally readable.

- `pet-{stage}-wish-hello-pat.png`
  - Asks for one clear hello before the day gets loud.
- `pet-{stage}-wish-phrase-repeat.png`
  - Holds one phrase card and waits to repeat it back.
- `pet-{stage}-wish-tiny-quest.png`
  - Peeks at a quest marker without rushing the user.
- `pet-{stage}-wish-snack-share.png`
  - Offers or asks for a tiny snack ritual.
- `pet-{stage}-wish-rest-nest.png`
  - Makes rest visibly count as care.
- `pet-{stage}-wish-hyper-lap.png`
  - Burns extra sparks in one bright lap, then settles.
- `pet-{stage}-wish-focus-perch.png`
  - Perches beside the first focused minute.
- `pet-{stage}-wish-cipher-peek.png`
  - Peeks at the daily cipher like a shiny puzzle toy.
- `pet-{stage}-wish-upgrade-dream.png`
  - Dreams over the next upgrade card or charm.
- `pet-{stage}-wish-field-sketch.png`
  - Sketches one found-object note for the album.
- `pet-{stage}-wish-scout-wave.png`
  - Waves at the scout path before it goes quiet.
- `pet-{stage}-wish-night-thanks.png`
  - Gives a small thank-you before night watch.
- `pet-{stage}-journal-wishbook.png`
  - Journal view showing fulfilled, offered, skipped, and album-saved wishes.

### Batch 25: Toybox

Generate these as object-play sheets for each growth stage. The object should be
visible and reusable as a prop across the animation.

- `pet-{stage}-toy-spark-ball.png`
  - Bats a glowing spark ball across the desktop and returns to idle.
- `pet-{stage}-toy-snack-bell.png`
  - Rings a snack bell once, then waits politely.
- `pet-{stage}-toy-phrase-ribbon.png`
  - Waves a phrase ribbon while practicing a language echo.
- `pet-{stage}-toy-quest-compass.png`
  - Spins a compass until one safe route glows.
- `pet-{stage}-toy-nap-blanket.png`
  - Tucks a blanket and makes rest feel useful.
- `pet-{stage}-toy-focus-pebble.png`
  - Holds a focus pebble and settles beside one task.
- `pet-{stage}-toy-cipher-cube.png`
  - Turns a cipher cube and reacts to a puzzle click.
- `pet-{stage}-toy-upgrade-kite.png`
  - Flies a tiny upgrade kite and watches the next card shimmer.
- `pet-{stage}-toy-scout-flag.png`
  - Plants a little flag where the scout trail begins.
- `pet-{stage}-toy-moon-lamp.png`
  - Lights a moon lamp and softens the night watch.
- `pet-{stage}-journal-toybox.png`
  - Journal view showing played, offered, skipped, and album-saved toys.

### Batch 26: Trickbook

Generate these as growth-locked trick sheets. Tiny forms should look simple and
vulnerable; guardian forms should look calmer and more capable.

- `pet-{stage}-trick-hello-wave.png`
  - Looks down, looks up, then gives a tiny hello wave.
- `pet-{stage}-trick-spark-hop.png`
  - Does one bright spark hop and lands cleanly.
- `pet-{stage}-trick-cheek-clap.png`
  - Claps cheek sparks softly, saving the charge instead of scattering it.
- `pet-{stage}-trick-phrase-echo.png`
  - Repeats a phrase echo and waits for the user's voice.
- `pet-{stage}-trick-focus-sit.png`
  - Sits beside the first minute and keeps the desk calm.
- `pet-{stage}-trick-quest-point.png`
  - Points at one safe quest route.
- `pet-{stage}-trick-cipher-tilt.png`
  - Tilts its head until a clue begins to make sense.
- `pet-{stage}-trick-weather-dash.png`
  - Dashes through a tiny storm and returns steady.
- `pet-{stage}-trick-guardian-bow.png`
  - Bows proudly after a finished care loop.
- `pet-{stage}-trick-moon-guard.png`
  - Guards a moon lamp and lowers the room's urgency.
- `pet-{stage}-journal-trickbook.png`
  - Journal view showing practiced, offered, skipped, and locked tricks.

### Batch 27: Errand Board

Generate these as short task-board sheets for each growth stage. These are the
clean pet-care version of viral daily task mechanics.

- `pet-{stage}-errand-spark-gather.png`
  - Gathers loose desk sparks and tucks them into a safer glow.
- `pet-{stage}-errand-snack-fetch.png`
  - Finds a snack spark and saves it for low-energy moments.
- `pet-{stage}-errand-phrase-courier.png`
  - Carries one phrase card, repeats it softly, and returns proud.
- `pet-{stage}-errand-map-scout.png`
  - Checks the next trail marker and brings back a calmer route.
- `pet-{stage}-errand-focus-guard.png`
  - Stands guard beside one useful minute.
- `pet-{stage}-errand-charm-sort.png`
  - Sorts memory charms so the bond album feels easier to read.
- `pet-{stage}-errand-moon-watch.png`
  - Does a soft night watch and lowers the room noise.
- `pet-{stage}-errand-cheer-courier.png`
  - Carries a small cheer note and waits for the user to come back.
- `pet-{stage}-journal-errand-board.png`
  - Journal view showing done, offered, skipped, and album-saved errands.

### Batch 28: Daypart Proactive Cheer Flow

Generate these as the first "pet talks throughout the day" pack for each growth
stage. These should be warm, readable check-in poses with no text baked into the
art:

- `pet-{stage}-cheer-daypart-sunrise-enter.png`
  - Pet appears gently, looks down, looks up, and offers the morning check-in.
- `pet-{stage}-cheer-daypart-focus-enter.png`
  - Pet sits beside an invisible task and invites the first minute.
- `pet-{stage}-cheer-daypart-afternoon-enter.png`
  - Pet shows a soft energy dip, stretches, then asks for a reset.
- `pet-{stage}-cheer-daypart-evening-enter.png`
  - Pet holds a warm loop-closing glow for the evening.
- `pet-{stage}-cheer-daypart-night-enter.png`
  - Pet lowers into quiet night-watch posture.
- `pet-{stage}-cheer-bubble-wait.png`
  - Pet waits beside a speech bubble, attentive and alive.
- `pet-{stage}-cheer-bubble-answer.png`
  - Pet receives the user's answer and stores it as a tiny memory spark.
- `pet-{stage}-cheer-bubble-dismiss.png`
  - Pet accepts dismissal kindly, waves once, and returns to idle.
- `pet-{stage}-journal-cheer-rhythm.png`
  - Journal view showing sunrise, focus, afternoon, evening, and night check-ins.

### Batch 29: Emotion Recovery Mini-Arcs

Generate these as cause-care-resolution strips for each growth stage. Each sheet
should visibly start in the feeling, receive a care cue, then settle:

- `pet-{stage}-emotion-recovery-bright.png`
  - Bright return, spark stored, steady happy idle.
- `pet-{stage}-emotion-recovery-tired.png`
  - Tired wobble, rest cue, calmer eyes.
- `pet-{stage}-emotion-recovery-stuck.png`
  - Confused block, one clue, small forward point.
- `pet-{stage}-emotion-recovery-overwhelmed.png`
  - Big swirl shrinks into one safe step.
- `pet-{stage}-emotion-recovery-lonely.png`
  - Pet waits, user returns, pet sits closer.
- `pet-{stage}-emotion-recovery-proud.png`
  - Small win becomes a saved spark charm.
- `pet-{stage}-emotion-recovery-focused.png`
  - Pet chooses a focus perch and guards the first minute.
- `pet-{stage}-emotion-recovery-need-break.png`
  - Fast sparks slow into a soft reset.
- `pet-{stage}-journal-emotion-recovery.png`
  - Journal view showing recovered feelings and locked feelings.

### Batch 30: Growth Identity Closeups

Generate these as identity-defining sheets for each growth stage. They are not
generic moods; they sell the "small to big" relationship:

- `pet-tiny-spark-first-trust.png`
  - Tiny Spark looks down, looks up, notices the user, and smiles carefully.
- `pet-pocket-pal-recognizes-user.png`
  - Pocket Pal reacts faster because it knows the user's rhythm.
- `pet-trail-buddy-walks-beside.png`
  - Trail Buddy walks beside a tiny map and points to a safe step.
- `pet-storm-scout-proactive-patrol.png`
  - Storm Scout checks the screen edge before being asked.
- `pet-storm-guardian-calm-oath.png`
  - Storm Guardian holds a calm protective glow without pressure.
- `pet-tiny-spark-evolve-glow.png`
  - Early growth glow, still small and vulnerable.
- `pet-pocket-pal-evolve-glow.png`
  - Recognition turns into a warmer body language.
- `pet-trail-buddy-evolve-glow.png`
  - Trail map and steady stance mark the next form.
- `pet-storm-scout-evolve-glow.png`
  - Scout sparks become a guardian aura.
- `pet-{stage}-journal-growth-identity.png`
  - Journal view explaining the current stage identity.

### Batch 31: Retention Economy Receipts

Generate these as reward receipts for the non-crypto economy. They should feel
like care proof, not casino or finance art:

- `pet-{stage}-receipt-sparks-earned.png`
  - Pet gathers Sparks and tucks them into a safe pouch.
- `pet-{stage}-receipt-joy-earned.png`
  - Pet glows warmly after a care action.
- `pet-{stage}-receipt-bond-hp-earned.png`
  - Pet stores a heart/spark receipt for daily care.
- `pet-{stage}-receipt-energy-refill.png`
  - Energy refills visibly and calmly.
- `pet-{stage}-receipt-vital-refill.png`
  - Snack, rest, play, or focus vital glows back up.
- `pet-{stage}-receipt-combo-complete.png`
  - Daily combo clicks into place and pet celebrates.
- `pet-{stage}-receipt-cipher-solved.png`
  - Cipher clue unlocks, pet stores the solved word.
- `pet-{stage}-receipt-upgrade-bought.png`
  - Upgrade card glows and becomes part of the pet's kit.
- `pet-{stage}-journal-reward-receipts.png`
  - Journal view showing why today's rewards happened.

### Batch 32: Desktop Shell Interactions

Generate these as small overlay-specific animations. These make the pet feel
native on the desktop rather than pasted on top:

- `pet-{stage}-shell-hover-controls.png`
  - Pet notices hover and subtly acknowledges the hidden controls.
- `pet-{stage}-shell-expand.png`
  - Pet opens into chat mode with a quick friendly motion.
- `pet-{stage}-shell-minimize.png`
  - Pet tucks the panel away and returns to pet-only mode.
- `pet-{stage}-shell-close-goodnight.png`
  - Pet gives a short close/goodnight gesture.
- `pet-{stage}-shell-drag-handle.png`
  - Pet braces lightly as the overlay is dragged.
- `pet-{stage}-shell-mute.png`
  - Pet reacts to mute kindly without looking rejected.
- `pet-{stage}-shell-unmute.png`
  - Pet perks up when sound returns.
- `pet-{stage}-shell-message-enter.png`
  - Pet reacts the moment the user sends a message.
- `pet-{stage}-shell-message-reply.png`
  - Pet reacts as the answer arrives.

### Batch 33: Pika Voice Mouth And Sound Cues

Generate these as short mouth/body timing sheets for crisp original "Pikaa"
audio. They should sync to the generated signature clips, not long English TTS:

- `pet-{stage}-voice-pikaa-pikaa.png`
  - Two clear syllable bounces, mouth opens and closes cleanly.
- `pet-{stage}-voice-pikaa-question.png`
  - Curious rising phrase with head tilt.
- `pet-{stage}-voice-pikaa-excited.png`
  - Bright success phrase with contained cheek sparks.
- `pet-{stage}-voice-pikaa-sleepy.png`
  - Slow sleepy phrase with soft eyelids.
- `pet-{stage}-voice-pika-alert.png`
  - Short alert chirp without panic.
- `pet-{stage}-voice-pika-empathy.png`
  - Softer empathy phrase for check-ins.
- `pet-{stage}-voice-pika-reward.png`
  - Reward chirp with small spark receipt.
- `pet-{stage}-journal-voice-cues.png`
  - Journal view showing voice cue variants.

### Batch 34: First Minute Demo Path

Generate these if the only goal is to make the hackathon demo feel coherent in
the first minute:

- `pet-buddy-demo-launch-idle.png`
  - Pet-only launch: looks down, looks up, smiles at the user.
- `pet-buddy-demo-hover-controls.png`
  - Hover-only settings and close controls appear while pet reacts subtly.
- `pet-buddy-demo-proactive-bubble.png`
  - "How are you doing?" bubble pose with no text in art.
- `pet-buddy-demo-answer-reward.png`
  - User answers, pet stores a memory spark.
- `pet-buddy-demo-pet-care.png`
  - Daily care gives Joy, HP, and a warm receipt.
- `pet-buddy-demo-pikaa-voice.png`
  - Crisp `Pikaa Pikaa` body and mouth timing.
- `pet-buddy-demo-next-loop.png`
  - Pet points to the next loop: learn, hint, route, or care.
- `pet-buddy-demo-minimize-return.png`
  - Pet returns to desktop-only mode and keeps watching gently.

### Batch 35: Expanded Cheer Dialogue And Script Pack

Generate these for each growth stage to match the expanded proactive text deck.
These are the "talks to the user throughout the day" assets:

- `pet-{stage}-cheer-dialogue-body-check.png`
  - Pet gently scans jaw, shoulders, and breath, then offers care.
- `pet-{stage}-cheer-dialogue-name-one-thing.png`
  - Pet catches one large messy thought and turns it into one named spark.
- `pet-{stage}-cheer-dialogue-water-spark.png`
  - Pet offers a tiny water/care spark and brightens after the sip.
- `pet-{stage}-cheer-dialogue-tab-tamer.png`
  - Pet looks at too many invisible tabs and helps choose one.
- `pet-{stage}-cheer-dialogue-after-meeting.png`
  - Pet shakes off meeting static and sorts keep/drop/next into tiny piles.
- `pet-{stage}-cheer-dialogue-return-warmth.png`
  - Pet welcomes the user back and warms up the next step slowly.
- `pet-{stage}-cheer-dialogue-finish-line.png`
  - Pet guards a final tiny push near the finish line.
- `pet-{stage}-cheer-dialogue-permission-rest.png`
  - Pet makes rest visibly count as care, with soft protective posture.
- `pet-{stage}-cheer-script-sunrise-inventory.png`
  - Morning inventory: pet asks what the user is carrying into the day.
- `pet-{stage}-cheer-script-task-weather.png`
  - Pet checks whether the task is sunny, foggy, or stormy.
- `pet-{stage}-cheer-script-tab-rescue.png`
  - Pet chooses one tab/door and lets the others wait.
- `pet-{stage}-cheer-script-meeting-comedown.png`
  - Pet sorts meeting residue into keep, drop, and next.
- `pet-{stage}-cheer-script-water-and-blink.png`
  - Pet leads water sip, two blinks, and a softer next edge.
- `pet-{stage}-cheer-script-afternoon-proof.png`
  - Pet saves one proof that the afternoon moved.
- `pet-{stage}-cheer-script-evening-inventory.png`
  - Pet packs one loose thought into the journal before evening closes.
- `pet-{stage}-cheer-script-sleep-permission.png`
  - Pet explicitly gives permission for rest to count as care.

### Batch 36: Emotion Arc Triptychs

Generate these for each growth stage. Each arc is a three-part mini animation:
trigger, care, resolve. These are the deeper pet-emotion flows behind the
Mood journal and proactive care loop.

- `pet-{stage}-emotion-arc-first-trust-trigger.png`
  - Pet looks down, looks up, and notices the user.
- `pet-{stage}-emotion-arc-first-trust-care.png`
  - Pet accepts one gentle daily care touch.
- `pet-{stage}-emotion-arc-first-trust-resolve.png`
  - Pet settles into a reliable warm hello.
- `pet-{stage}-emotion-arc-brave-start-trigger.png`
  - Pet hesitates at the edge of a task.
- `pet-{stage}-emotion-arc-brave-start-care.png`
  - Pet receives one named next action.
- `pet-{stage}-emotion-arc-brave-start-resolve.png`
  - Pet makes the first-step courage pose.
- `pet-{stage}-emotion-arc-proud-glow-trigger.png`
  - Pet holds a completed spark close to its chest.
- `pet-{stage}-emotion-arc-proud-glow-care.png`
  - Pet lets the user pause on the completed work.
- `pet-{stage}-emotion-arc-proud-glow-resolve.png`
  - Pet shows a saved proof-of-progress glow.
- `pet-{stage}-emotion-arc-overcharge-ground-trigger.png`
  - Pet crackles with too much energy.
- `pet-{stage}-emotion-arc-overcharge-ground-care.png`
  - Pet grounds the sparks through breath, water, or focus.
- `pet-{stage}-emotion-arc-overcharge-ground-resolve.png`
  - Pet contains the charge cleanly.
- `pet-{stage}-emotion-arc-focus-perch-trigger.png`
  - Pet climbs into a quiet work perch.
- `pet-{stage}-emotion-arc-focus-perch-care.png`
  - Pet watches one active task without interrupting.
- `pet-{stage}-emotion-arc-focus-perch-resolve.png`
  - Pet becomes calm company for focused work.
- `pet-{stage}-emotion-arc-celebration-share-trigger.png`
  - Pet notices a win that might get rushed past.
- `pet-{stage}-emotion-arc-celebration-share-care.png`
  - Pet invites a small shared cheer.
- `pet-{stage}-emotion-arc-celebration-share-resolve.png`
  - Pet stores the win as a warm memory.
- `pet-{stage}-emotion-arc-night-guardian-trigger.png`
  - Pet lowers its posture for late-night quiet.
- `pet-{stage}-emotion-arc-night-guardian-care.png`
  - Pet closes one loose thread and guards rest.
- `pet-{stage}-emotion-arc-night-guardian-resolve.png`
  - Pet gives explicit permission to stop.
- `pet-{stage}-emotion-arc-gentle-repair-trigger.png`
  - Pet sees a rough moment or failed attempt.
- `pet-{stage}-emotion-arc-gentle-repair-care.png`
  - Pet soothes first and shrinks the next step.
- `pet-{stage}-emotion-arc-gentle-repair-resolve.png`
  - Pet offers a kinder retry.
- `pet-{stage}-emotion-arc-playful-sprint-trigger.png`
  - Pet fidgets with playful motion.
- `pet-{stage}-emotion-arc-playful-sprint-care.png`
  - Pet spends one small burst of energy.
- `pet-{stage}-emotion-arc-playful-sprint-resolve.png`
  - Pet returns with playful momentum.
- `pet-{stage}-emotion-arc-grateful-keepsake-trigger.png`
  - Pet remembers repeated care from the user.
- `pet-{stage}-emotion-arc-grateful-keepsake-care.png`
  - Pet turns the care streak into a charm moment.
- `pet-{stage}-emotion-arc-grateful-keepsake-resolve.png`
  - Pet saves a grateful keepsake.
- `pet-{stage}-emotion-arc-grow-ready-trigger.png`
  - Pet stands taller because the bond is changing.
- `pet-{stage}-emotion-arc-grow-ready-care.png`
  - Pet previews the next form through a growth quest.
- `pet-{stage}-emotion-arc-grow-ready-resolve.png`
  - Pet settles into evolution readiness.
- `pet-{stage}-emotion-arc-restless-redirect-trigger.png`
  - Restless sparks circle around the pet.
- `pet-{stage}-emotion-arc-restless-redirect-care.png`
  - Pet converts the fidget energy into one upgrade choice.
- `pet-{stage}-emotion-arc-restless-redirect-resolve.png`
  - Pet shows the chosen upgrade route.
- `pet-{stage}-emotion-arc-snack-rescue-trigger.png`
  - Pet wobbles gently from low energy.
- `pet-{stage}-emotion-arc-snack-rescue-care.png`
  - Pet receives a small snack/refill cue.
- `pet-{stage}-emotion-arc-snack-rescue-resolve.png`
  - Pet slows down with refilled care.
- `pet-{stage}-emotion-arc-sleep-nest-trigger.png`
  - Pet becomes visibly tired.
- `pet-{stage}-emotion-arc-sleep-nest-care.png`
  - Pet curls into a protected nap nest.
- `pet-{stage}-emotion-arc-sleep-nest-resolve.png`
  - Pet marks rest as progress.
- `pet-{stage}-emotion-arc-curious-trail-trigger.png`
  - Pet notices a clue or question.
- `pet-{stage}-emotion-arc-curious-trail-care.png`
  - Pet follows one hint or tiny puzzle.
- `pet-{stage}-emotion-arc-curious-trail-resolve.png`
  - Pet saves a visible clue trail.
- `pet-{stage}-emotion-arc-lonely-comeback-trigger.png`
  - Pet waits without guilt while the user is away.
- `pet-{stage}-emotion-arc-lonely-comeback-care.png`
  - Pet brightens when the user returns.
- `pet-{stage}-emotion-arc-lonely-comeback-resolve.png`
  - Pet stores a warm comeback memory.

### Batch 37: Daily Nudge Journey

Generate these for each growth stage. This is the always-on "cheer the user"
route that runs across the day while the pet is minimized. Each sheet should be
a 12-frame transparent strip with no text, no border, and no background.

- `pet-{stage}-daily-journey-wake-spark.png`
  - Morning arrival: pet looks down, looks up, checks whether the user is bright, foggy, or sparking.
- `pet-{stage}-daily-journey-first-step.png`
  - First task door: pet closes extra doors/tabs and points to one tiny first step.
- `pet-{stage}-daily-journey-focus-perch.png`
  - Work perch: pet sits quietly beside one active task without distracting motion.
- `pet-{stage}-daily-journey-snack-pulse.png`
  - Care pulse: pet offers water/snack/stretch with a small refill glow.
- `pet-{stage}-daily-journey-afternoon-rescue.png`
  - Afternoon rescue: pet pulls one useful next step out of noisy scattered sparks.
- `pet-{stage}-daily-journey-proof-pocket.png`
  - Proof pocket: pet catches one proof of progress and tucks it into a tiny journal pocket.
- `pet-{stage}-daily-journey-evening-pack.png`
  - Evening pack: pet bundles one loose thought so tomorrow starts lighter.
- `pet-{stage}-daily-journey-night-nest.png`
  - Night nest: pet guards quiet rest, dims sparks, and gives permission to stop.

### Batch 38: Spark Exchange Board

Generate these for each growth stage. This is the Hamster-style retention board
translated into pet-care language: no crypto, no casino feeling, no text in the
image. Each sheet should be a 12-frame transparent strip with a clean alpha edge,
soft 3D mascot lighting, and a readable action loop.

- `pet-{stage}-exchange-care-tap.png`
  - Pet receives one tiny care tap, lights a Bond HP spark, and looks safely recognized.
- `pet-{stage}-exchange-combo-cards.png`
  - Pet flips three abstract combo cards into place and celebrates only when all align.
- `pet-{stage}-exchange-task-board.png`
  - Pet studies a small daily board of charms, picks one task, and marks it complete.
- `pet-{stage}-exchange-cipher-key.png`
  - Pet decodes a glowing key/cipher stone, thinking pose into "aha" sparkle.
- `pet-{stage}-exchange-spark-boost.png`
  - Pet charges a controlled boost, releases a short burst, then settles calmly.
- `pet-{stage}-exchange-upgrade-card.png`
  - Pet polishes an upgrade card/charm and watches the loop become stronger.
- `pet-{stage}-exchange-passive-scout.png`
  - Pet goes into quiet scout mode, steps away, returns with a small Spark pouch.
- `pet-{stage}-exchange-cheer-reply.png`
  - Pet opens a tiny check-in bubble, receives the user's reply, and stores a warm memory.

### Batch 39: Season Trail Weekly Event Arc

Generate these for each growth stage. This is the longer event arc that gives the
pet a weekly reason to return: one chapter unlocks per care day, then daily event
play advances the current chapter. No text, no UI chrome, no crypto/money motifs.
Use warm adventure/care imagery with clean transparent alpha.

- `pet-{stage}-season-trail-day-1-signal-spark.png`
  - Pet finds the week's first event signal, looks down, looks up, and marks the route.
- `pet-{stage}-season-trail-day-2-supply-nest.png`
  - Pet packs snack sparks, a rest cloth, and a small courage charm into a tiny nest pouch.
- `pet-{stage}-season-trail-day-3-combo-gate.png`
  - Pet arranges three abstract combo cards until a gentle event gate opens.
- `pet-{stage}-season-trail-day-4-cipher-bridge.png`
  - Pet solves a glowing clue and builds a small safe bridge across the event trail.
- `pet-{stage}-season-trail-day-5-boost-run.png`
  - Pet uses one controlled bright burst to cross the hardest part of the route.
- `pet-{stage}-season-trail-day-6-campfire-proof.png`
  - Pet sits by a small campfire and saves one proof that the week moved forward.
- `pet-{stage}-season-trail-day-7-guardian-finale.png`
  - Pet completes the event as a calm guardian, protective and proud without pressure.
- `pet-{stage}-journal-season-trail.png`
  - Journal view showing the seven event chapters as visual charms, with completed chapters glowing.

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

Cheer scriptbook moments:

- `pet-{stage}-cheer-script-morning-spark.png`
  - Looks down, looks up, recognizes the user, and asks what kind of morning
    this is.
- `pet-{stage}-cheer-script-first-sip.png`
  - Offers one tiny care spark before the day gets loud.
- `pet-{stage}-cheer-script-desk-perch.png`
  - Perches beside the first task and points to the smallest desk piece.
- `pet-{stage}-cheer-script-one-window.png`
  - Helps make one crowded window feel simpler.
- `pet-{stage}-cheer-script-pocket-win.png`
  - Saves a tiny win as a glowing pocket spark.
- `pet-{stage}-cheer-script-soft-stretch.png`
  - Leads a soft stretch/reset without guilt.
- `pet-{stage}-cheer-script-campfire-close.png`
  - Tucks one open loop beside a small campfire glow.
- `pet-{stage}-cheer-script-loop-tuck.png`
  - Holds one loose end while the user chooses a gentle final step.
- `pet-{stage}-cheer-script-moon-guard.png`
  - Guards quiet night work with a calm, low-pressure stance.
- `pet-{stage}-cheer-script-quiet-question.png`
  - Listens to one sentence about what is happening in the user's head.
- `pet-{stage}-cheer-script-comeback-wave.png`
  - Welcomes the user back and shows the saved place marker.
- `pet-{stage}-cheer-script-upgrade-wish.png`
  - Looks at humming Sparks and wishes toward the next tiny charm.
- `pet-{stage}-journal-cheer-scriptbook.png`
  - Opens a page of seen, skipped, answered, and saved proactive script lines.

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

Ambient desktop life:

- `pet-{stage}-ambient-first-look.png`
  - Looks down, looks up, recognizes the user, and smiles as if the desk is
    home.
- `pet-{stage}-ambient-desk-perch.png`
  - Perches beside the current task and watches quietly.
- `pet-{stage}-ambient-snack-sniff.png`
  - Sniffs for a snack spark, waits politely, and returns to idle.
- `pet-{stage}-ambient-soft-stretch.png`
  - Stretches, shakes off static, and settles into a softer posture.
- `pet-{stage}-ambient-spark-patrol.png`
  - Walks a tiny patrol around the screen and checks bond lights.
- `pet-{stage}-ambient-cheek-spark.png`
  - Cheeks fizz once, pet looks proud, then calms back down.
- `pet-{stage}-ambient-sleepy-guard.png`
  - Drowsy guard pose with a small night-watch glow.
- `pet-{stage}-ambient-journal-peek.png`
  - Peeks at the field journal and nudges the next art request.
- `pet-{stage}-journal-ambient-life.png`
  - Opens the ambient-life album showing seen today and permanent idle moments.

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
- Daily Spark Route opened.
- Daily Spark Route step ready.
- Daily Spark Route step completed.
- Daily Spark Route album updated.
- Daily Spark Route complete.
- Spark Route charm unlocked.
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
- Cheer script appeared.
- Cheer script answered.
- Cheer script dismissed.
- Cheer scriptbook album updated.
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
- Care window opened.
- Care window already claimed.
- Care window album updated.
- All five care windows completed.
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

Care Window sheets, one per growth stage:

- `pet-{stage}-care-window-sunrise-greeting.png`
  - The pet looks down, looks up, recognizes the user, and smiles.
- `pet-{stage}-care-window-focus-perch.png`
  - The pet perches beside the current task with attentive, calm eyes.
- `pet-{stage}-care-window-afternoon-reset.png`
  - The pet shakes off low-energy wobble and offers a tiny spark refill.
- `pet-{stage}-care-window-evening-loop.png`
  - The pet marks one unfinished loop with a warm campfire-like glow.
- `pet-{stage}-care-window-night-nest.png`
  - The pet curls into a sleepy nest and guards the streak quietly.

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

## Scout Trip Sheets

These support the two-step send/return desktop expedition loop. Each action
needs a 12-frame transparent strip for every growth stage:

- `pet-{stage}-scout-trip-desk-edge.png`
  - Pet pads to the edge of the desktop and looks for a safe starting point.
- `pet-{stage}-scout-trip-spark-trail.png`
  - Pet follows tiny electric spark receipts across the desk.
- `pet-{stage}-scout-trip-phrase-grove.png`
  - Pet carries a language spark and listens for a phrase echo.
- `pet-{stage}-scout-trip-quest-marker.png`
  - Pet places a tiny marker beside the next adventure route.
- `pet-{stage}-scout-trip-snack-nook.png`
  - Pet discovers a small snack cache and checks it proudly.
- `pet-{stage}-scout-trip-rest-cove.png`
  - Pet finds a soft resting cove and curls there briefly.
- `pet-{stage}-scout-trip-upgrade-forge.png`
  - Pet studies a small upgrade-card sketch with bright focus.
- `pet-{stage}-scout-trip-mood-meadow.png`
  - Pet brings back a floating mood petal or glow.
- `pet-{stage}-scout-trip-comeback-path.png`
  - Pet traces a warm return path back to the user.
- `pet-{stage}-scout-trip-night-watch.png`
  - Pet does a gentle night patrol with soft cheek sparks.
- `pet-{stage}-journal-scout-trips.png`
  - Pet presents a tiny scout album with found-object badges.

## Bond Gesture Sheets

These support direct affection rituals: small touch/care moments the pet asks
for proactively, rewards with Joy/Sparks, and saves in the Bond album. Generate
one 12-frame transparent strip per gesture and growth stage:

- `pet-{stage}-affection-head-pat.png`
  - Pet lowers its head, looks up after the pat, and smiles at the user.
- `pet-{stage}-affection-cheek-rub.png`
  - Pet leans one cheek into the rub; cheek sparks settle into a warm glow.
- `pet-{stage}-affection-spark-brush.png`
  - Pet is hyperactive, then a tiny brush turns scattered sparks into calm.
- `pet-{stage}-affection-tail-polish.png`
  - Pet holds still while the tail shine becomes a confidence ritual.
- `pet-{stage}-affection-snack-boop.png`
  - Pet touches a tiny snack with both paws, boops it once, and brightens.
- `pet-{stage}-affection-focus-perch-pet.png`
  - Pet perches beside an invisible task and accepts one careful focus pet.
- `pet-{stage}-affection-sleep-tuck.png`
  - Pet curls down while the user tucks it into a safe sleepy pose.
- `pet-{stage}-affection-victory-cuddle.png`
  - Pet celebrates a completed loop with a proud, compact cuddle.
- `pet-{stage}-journal-affection.png`
  - Pet opens a Bond gesture album with given and locked care moments.

## Home Room Sheets

These support the pet's persistent habitat: rooms it can visit directly or ask
for proactively while minimized. Each room should feel like a place the pet
lives in, not a menu background. Generate one 12-frame transparent strip per
room and growth stage:

- `pet-{stage}-home-cozy-nest.png`
  - Pet circles the blanket, settles the nest, and looks safe.
- `pet-{stage}-home-snack-nook.png`
  - Pet checks a tiny snack nook and stores one treat for later.
- `pet-{stage}-home-study-perch.png`
  - Pet climbs to a study perch and watches the user's first useful minute.
- `pet-{stage}-home-quest-lookout.png`
  - Pet peers from a small lookout and marks one gentle quest direction.
- `pet-{stage}-home-spark-gym.png`
  - Pet runs a compact spark loop so hyper energy has somewhere to go.
- `pet-{stage}-home-moon-den.png`
  - Pet lowers the room noise, guards the streak, and settles into night watch.
- `pet-{stage}-home-cipher-cave.png`
  - Pet taps a tiny cipher wall until one clue glow wakes up.
- `pet-{stage}-home-celebration-porch.png`
  - Pet hops onto a porch and saves the day's tiny win.
- `pet-{stage}-journal-home-rooms.png`
  - Pet opens a home album with visited and locked rooms.

## Errand Board Sheets

These support quick daily errands inspired by viral task-board loops, translated
into pet care. Each errand should look like the pet briefly leaves, performs a
tiny useful act, and returns with a care receipt. Generate one 12-frame
transparent strip per errand and growth stage:

- `pet-{stage}-errand-spark-gather.png`
  - Pet gathers loose desk sparks, stuffs them into a safe glow pouch, and
    returns proud.
- `pet-{stage}-errand-snack-fetch.png`
  - Pet finds a tiny snack spark, carries it carefully, and saves it for a
    low-energy moment.
- `pet-{stage}-errand-phrase-courier.png`
  - Pet carries one language phrase card, repeats it softly, and trots back.
- `pet-{stage}-errand-map-scout.png`
  - Pet checks a miniature trail map, marks one route, and points forward.
- `pet-{stage}-errand-focus-guard.png`
  - Pet guards an invisible one-minute focus bubble with attentive eyes.
- `pet-{stage}-errand-charm-sort.png`
  - Pet sorts tiny memory charms into a neat album row.
- `pet-{stage}-errand-moon-watch.png`
  - Pet does a soft night patrol, lowers the room noise, and settles calmly.
- `pet-{stage}-errand-cheer-courier.png`
  - Pet carries a little cheer note, waits by the screen edge, and waves.
- `pet-{stage}-journal-errand-board.png`
  - Pet opens an Errand Board album with done, skipped, and locked errands.

## User Check-in Sheets

These support the pet asking the user "How are you doing?" and remembering the
answer as an emotional care receipt. Each state needs a 12-frame transparent
strip per growth stage, with the pet reacting to the user's state rather than
performing generic happiness:

- `pet-{stage}-user-check-bright.png`
  - Pet catches a bright spark, smiles at the user, and stores it carefully.
- `pet-{stage}-user-check-tired.png`
  - Pet lowers the noise, softens its posture, and guards a tiny rest moment.
- `pet-{stage}-user-check-stuck.png`
  - Pet tilts its head, studies a small invisible block, and points to one clue.
- `pet-{stage}-user-check-overwhelmed.png`
  - Pet shrinks a big swirl into one small safe step with calm eyes.
- `pet-{stage}-user-check-lonely.png`
  - Pet steps closer, sits beside the user, and keeps quiet company.
- `pet-{stage}-user-check-proud.png`
  - Pet notices a small win, holds it like a spark charm, and celebrates gently.
- `pet-{stage}-user-check-focused.png`
  - Pet perches beside an invisible task and watches the first useful minute.
- `pet-{stage}-user-check-need-break.png`
  - Pet sees fast sparks, invites a tiny pause, then settles into a calmer loop.
- `pet-{stage}-journal-user-checkins.png`
  - Pet opens a user check-in album with answered and locked emotional states.

## Wishbook Sheets

These support the daily "Pikachu wants something" loop. Each wish should look
like a small desire being expressed, not a generic button state:

- `pet-{stage}-wish-hello-pat.png`
  - Pet leans in, asks for a clear hello, and brightens after attention.
- `pet-{stage}-wish-phrase-repeat.png`
  - Pet listens to one phrase, repeats it, and nods proudly.
- `pet-{stage}-wish-tiny-quest.png`
  - Pet peeks toward a quest marker with cautious curiosity.
- `pet-{stage}-wish-snack-share.png`
  - Pet holds or discovers a tiny snack spark.
- `pet-{stage}-wish-rest-nest.png`
  - Pet settles into a soft nest and makes rest feel earned.
- `pet-{stage}-wish-hyper-lap.png`
  - Pet runs one excited little lap with cheek sparks.
- `pet-{stage}-wish-focus-perch.png`
  - Pet perches beside an invisible task and watches calmly.
- `pet-{stage}-wish-cipher-peek.png`
  - Pet studies a small puzzle/cipher glint with a thinking face.
- `pet-{stage}-wish-upgrade-dream.png`
  - Pet dreams over a small upgrade card or charm shape.
- `pet-{stage}-wish-field-sketch.png`
  - Pet sketches a found-object field note for the album.
- `pet-{stage}-wish-scout-wave.png`
  - Pet waves at the scout path before or after an expedition.
- `pet-{stage}-wish-night-thanks.png`
  - Pet gives a soft night thank-you before guarding the desk.
- `pet-{stage}-journal-wishbook.png`
  - Pet presents a tiny wish album with fulfilled-wish stickers.

## Toybox Sheets

These support object play: the pet asks for or uses a tiny toy, earns care
progress, and saves the object in the Toybox album. Each toy needs a 12-frame
transparent strip for every growth stage:

- `pet-{stage}-toy-spark-ball.png`
  - Pet bats or rolls a glowing ball with happy cheek sparks.
- `pet-{stage}-toy-snack-bell.png`
  - Pet rings a tiny bell, waits politely, and brightens after care.
- `pet-{stage}-toy-phrase-ribbon.png`
  - Pet waves a ribbon while listening and repeating a short phrase.
- `pet-{stage}-toy-quest-compass.png`
  - Pet spins a small compass until one safe quest route glows.
- `pet-{stage}-toy-nap-blanket.png`
  - Pet tucks a little blanket, settles, then peeks back up.
- `pet-{stage}-toy-focus-pebble.png`
  - Pet holds a focus pebble and sits beside the user's first minute.
- `pet-{stage}-toy-cipher-cube.png`
  - Pet turns a small puzzle cube, tilts its head, then finds the click.
- `pet-{stage}-toy-upgrade-kite.png`
  - Pet flies a tiny upgrade kite and watches a card shimmer.
- `pet-{stage}-toy-scout-flag.png`
  - Pet plants a little flag where a scout trail begins.
- `pet-{stage}-toy-moon-lamp.png`
  - Pet lights a soft lamp for night watch without adding a dark outline.
- `pet-{stage}-journal-toybox.png`
  - Pet opens a tiny Toybox album with played and locked objects.

## Trickbook Sheets

These support growth-locked trick practice. Each trick needs a 12-frame
transparent strip for the stages where that trick is unlocked:

- `pet-{stage}-trick-hello-wave.png`
  - Tiny Spark and later: looks down, looks up, notices the user, then waves.
- `pet-{stage}-trick-spark-hop.png`
  - Tiny Spark and later: one safe bright hop with a clean landing.
- `pet-{stage}-trick-cheek-clap.png`
  - Pocket Pal and later: soft cheek clap that stores sparks instead of
    scattering them.
- `pet-{stage}-trick-phrase-echo.png`
  - Pocket Pal and later: listens, repeats a phrase shape, and waits proudly.
- `pet-{stage}-trick-focus-sit.png`
  - Trail Buddy and later: sits beside an invisible first-minute task.
- `pet-{stage}-trick-quest-point.png`
  - Trail Buddy and later: points toward one safe route before the full quest.
- `pet-{stage}-trick-cipher-tilt.png`
  - Storm Scout and later: head tilt, clue click, small solved sparkle.
- `pet-{stage}-trick-weather-dash.png`
  - Storm Scout and later: tiny storm dash, quick recovery, steady return.
- `pet-{stage}-trick-guardian-bow.png`
  - Storm Guardian: proud bow after a completed care loop.
- `pet-{stage}-trick-moon-guard.png`
  - Storm Guardian: quiet moon-lamp guard, no dark outline or heavy shadow.
- `pet-{stage}-journal-trickbook.png`
  - Pet opens a Trickbook album with practiced and locked tricks.

### Batch 40: Feeling Rituals

Purpose: give each emotional state a small care ritual so proactive bubbles
feel like a living pet asking for a specific kind of help, not a generic
notification.

Generate one transparent 12-frame horizontal strip for every growth stage:

- `pet-tiny-spark-feeling-ritual-morning-spark.png`
- `pet-tiny-spark-feeling-ritual-eager-breadcrumb.png`
- `pet-tiny-spark-feeling-ritual-proud-frame.png`
- `pet-tiny-spark-feeling-ritual-charge-ground.png`
- `pet-tiny-spark-feeling-ritual-focus-perch.png`
- `pet-tiny-spark-feeling-ritual-victory-loop.png`
- `pet-tiny-spark-feeling-ritual-guardian-circle.png`
- `pet-tiny-spark-feeling-ritual-comfort-nest.png`
- `pet-tiny-spark-feeling-ritual-play-wiggle.png`
- `pet-tiny-spark-feeling-ritual-gratitude-boop.png`
- `pet-tiny-spark-feeling-ritual-growth-oath.png`
- `pet-tiny-spark-feeling-ritual-restless-sort.png`
- `pet-tiny-spark-feeling-ritual-snack-signal.png`
- `pet-tiny-spark-feeling-ritual-sleep-permission.png`
- `pet-tiny-spark-feeling-ritual-curiosity-tap.png`
- `pet-tiny-spark-feeling-ritual-lonely-reach.png`

- `pet-pocket-pal-feeling-ritual-morning-spark.png`
- `pet-pocket-pal-feeling-ritual-eager-breadcrumb.png`
- `pet-pocket-pal-feeling-ritual-proud-frame.png`
- `pet-pocket-pal-feeling-ritual-charge-ground.png`
- `pet-pocket-pal-feeling-ritual-focus-perch.png`
- `pet-pocket-pal-feeling-ritual-victory-loop.png`
- `pet-pocket-pal-feeling-ritual-guardian-circle.png`
- `pet-pocket-pal-feeling-ritual-comfort-nest.png`
- `pet-pocket-pal-feeling-ritual-play-wiggle.png`
- `pet-pocket-pal-feeling-ritual-gratitude-boop.png`
- `pet-pocket-pal-feeling-ritual-growth-oath.png`
- `pet-pocket-pal-feeling-ritual-restless-sort.png`
- `pet-pocket-pal-feeling-ritual-snack-signal.png`
- `pet-pocket-pal-feeling-ritual-sleep-permission.png`
- `pet-pocket-pal-feeling-ritual-curiosity-tap.png`
- `pet-pocket-pal-feeling-ritual-lonely-reach.png`

- `pet-trail-buddy-feeling-ritual-morning-spark.png`
- `pet-trail-buddy-feeling-ritual-eager-breadcrumb.png`
- `pet-trail-buddy-feeling-ritual-proud-frame.png`
- `pet-trail-buddy-feeling-ritual-charge-ground.png`
- `pet-trail-buddy-feeling-ritual-focus-perch.png`
- `pet-trail-buddy-feeling-ritual-victory-loop.png`
- `pet-trail-buddy-feeling-ritual-guardian-circle.png`
- `pet-trail-buddy-feeling-ritual-comfort-nest.png`
- `pet-trail-buddy-feeling-ritual-play-wiggle.png`
- `pet-trail-buddy-feeling-ritual-gratitude-boop.png`
- `pet-trail-buddy-feeling-ritual-growth-oath.png`
- `pet-trail-buddy-feeling-ritual-restless-sort.png`
- `pet-trail-buddy-feeling-ritual-snack-signal.png`
- `pet-trail-buddy-feeling-ritual-sleep-permission.png`
- `pet-trail-buddy-feeling-ritual-curiosity-tap.png`
- `pet-trail-buddy-feeling-ritual-lonely-reach.png`

- `pet-storm-scout-feeling-ritual-morning-spark.png`
- `pet-storm-scout-feeling-ritual-eager-breadcrumb.png`
- `pet-storm-scout-feeling-ritual-proud-frame.png`
- `pet-storm-scout-feeling-ritual-charge-ground.png`
- `pet-storm-scout-feeling-ritual-focus-perch.png`
- `pet-storm-scout-feeling-ritual-victory-loop.png`
- `pet-storm-scout-feeling-ritual-guardian-circle.png`
- `pet-storm-scout-feeling-ritual-comfort-nest.png`
- `pet-storm-scout-feeling-ritual-play-wiggle.png`
- `pet-storm-scout-feeling-ritual-gratitude-boop.png`
- `pet-storm-scout-feeling-ritual-growth-oath.png`
- `pet-storm-scout-feeling-ritual-restless-sort.png`
- `pet-storm-scout-feeling-ritual-snack-signal.png`
- `pet-storm-scout-feeling-ritual-sleep-permission.png`
- `pet-storm-scout-feeling-ritual-curiosity-tap.png`
- `pet-storm-scout-feeling-ritual-lonely-reach.png`

- `pet-storm-guardian-feeling-ritual-morning-spark.png`
- `pet-storm-guardian-feeling-ritual-eager-breadcrumb.png`
- `pet-storm-guardian-feeling-ritual-proud-frame.png`
- `pet-storm-guardian-feeling-ritual-charge-ground.png`
- `pet-storm-guardian-feeling-ritual-focus-perch.png`
- `pet-storm-guardian-feeling-ritual-victory-loop.png`
- `pet-storm-guardian-feeling-ritual-guardian-circle.png`
- `pet-storm-guardian-feeling-ritual-comfort-nest.png`
- `pet-storm-guardian-feeling-ritual-play-wiggle.png`
- `pet-storm-guardian-feeling-ritual-gratitude-boop.png`
- `pet-storm-guardian-feeling-ritual-growth-oath.png`
- `pet-storm-guardian-feeling-ritual-restless-sort.png`
- `pet-storm-guardian-feeling-ritual-snack-signal.png`
- `pet-storm-guardian-feeling-ritual-sleep-permission.png`
- `pet-storm-guardian-feeling-ritual-curiosity-tap.png`
- `pet-storm-guardian-feeling-ritual-lonely-reach.png`

Animation notes:

- Morning Spark: looks down, looks up, finds the user, then smiles.
- Eager Breadcrumb: bounces, drops one tiny glowing breadcrumb, then waits.
- Proud Frame: holds up a small win frame and beams.
- Charge Ground: cheek sparks start bright, then settle into a calm pulse.
- Focus Perch: hops into a seated focus perch and blinks slowly.
- Victory Loop: tiny celebration loop, then saves the glow into the album.
- Guardian Circle: draws a protective circle and settles into watch mode.
- Comfort Nest: pulls a small nest/blanket close and breathes calmly.
- Play Wiggle: happy wiggle with a clean return to idle.
- Gratitude Boop: tiny grateful boop toward the screen.
- Growth Oath: stands taller and makes a small oath spark.
- Restless Sort: sorts little kit pieces instead of spinning.
- Snack Signal: notices low energy and points to a tiny snack stash.
- Sleep Permission: curls down, opens one eye, then accepts rest.
- Curiosity Tap: taps the screen gently and tilts head.
- Lonely Reach: waits quietly, then leans closer for a soft reach-back.

Add one album sheet:

- `pet-{stage}-journal-feeling-rituals.png`
  - Pet opens a Feeling Rituals album with ritual stamps arranged by mood.

### Batch 41: Daily Care Chests

Purpose: add Hamster-style daily return rewards without breaking the pet
fantasy. Each chest is a care moment the pet found, guarded, or saved for the
user. These should feel like relationship rewards, not casino boxes.

Generate one transparent 12-frame horizontal strip for every growth stage:

- `pet-tiny-spark-care-chest-morning-spark.png`
- `pet-tiny-spark-care-chest-focus-crate.png`
- `pet-tiny-spark-care-chest-snack-cache.png`
- `pet-tiny-spark-care-chest-play-box.png`
- `pet-tiny-spark-care-chest-evening-coffer.png`
- `pet-tiny-spark-care-chest-night-nest.png`
- `pet-tiny-spark-care-chest-comeback-cache.png`

- `pet-pocket-pal-care-chest-morning-spark.png`
- `pet-pocket-pal-care-chest-focus-crate.png`
- `pet-pocket-pal-care-chest-snack-cache.png`
- `pet-pocket-pal-care-chest-play-box.png`
- `pet-pocket-pal-care-chest-evening-coffer.png`
- `pet-pocket-pal-care-chest-night-nest.png`
- `pet-pocket-pal-care-chest-comeback-cache.png`

- `pet-trail-buddy-care-chest-morning-spark.png`
- `pet-trail-buddy-care-chest-focus-crate.png`
- `pet-trail-buddy-care-chest-snack-cache.png`
- `pet-trail-buddy-care-chest-play-box.png`
- `pet-trail-buddy-care-chest-evening-coffer.png`
- `pet-trail-buddy-care-chest-night-nest.png`
- `pet-trail-buddy-care-chest-comeback-cache.png`

- `pet-storm-scout-care-chest-morning-spark.png`
- `pet-storm-scout-care-chest-focus-crate.png`
- `pet-storm-scout-care-chest-snack-cache.png`
- `pet-storm-scout-care-chest-play-box.png`
- `pet-storm-scout-care-chest-evening-coffer.png`
- `pet-storm-scout-care-chest-night-nest.png`
- `pet-storm-scout-care-chest-comeback-cache.png`

- `pet-storm-guardian-care-chest-morning-spark.png`
- `pet-storm-guardian-care-chest-focus-crate.png`
- `pet-storm-guardian-care-chest-snack-cache.png`
- `pet-storm-guardian-care-chest-play-box.png`
- `pet-storm-guardian-care-chest-evening-coffer.png`
- `pet-storm-guardian-care-chest-night-nest.png`
- `pet-storm-guardian-care-chest-comeback-cache.png`

Action notes:

- Morning Spark Chest: pet looks down, looks up, smiles, then nudges open a
  tiny warm spark chest.
- Focus Crate: pet perches beside a small work crate, taps it, and sits alert.
- Snack Cache: pet shares a cheek-warming snack cache, happy but not frantic.
- Play Box: pet opens a play box and does one hyper hop loop.
- Evening Coffer: pet closes a small glowing coffer like saving the day's loop.
- Night Nest Chest: pet tucks a small chest into a soft nest and settles down.
- Comeback Cache: pet gently pushes forward a saved return cache with a warm
  welcome-back expression.

- `pet-{stage}-journal-care-chests.png`
  - Pet opens a Care Chests album with claimed and locked chest stamps.

### Batch 42: Bond Timeline Chapters

Purpose: make growth feel like a real relationship over time. These are
permanent story beats unlocked by HP, Sparks, streaks, and growth stage, not
daily reward boxes.

Generate one transparent 12-frame horizontal strip for the named minimum stage
of each chapter:

- `pet-tiny-spark-bond-timeline-first-hello.png`
  - Tiny Spark looks down, looks up, and smiles at the user for the first time.
- `pet-tiny-spark-bond-timeline-desk-nest.png`
  - Tiny Spark builds a tiny desk nest and settles safely.
- `pet-tiny-spark-bond-timeline-name-trust.png`
  - Tiny Spark perks up as if recognizing its name and the user's rhythm.
- `pet-pocket-pal-bond-timeline-morning-return.png`
  - Pocket Pal greets the user's return with a warm morning bounce.
- `pet-pocket-pal-bond-timeline-first-quest.png`
  - Pocket Pal carries a tiny quest marker like a shared adventure.
- `pet-pocket-pal-bond-timeline-language-spark.png`
  - Pocket Pal practices a phrase with cheek-spark concentration.
- `pet-trail-buddy-bond-timeline-brave-check.png`
  - Trail Buddy sits beside a hard moment and offers a gentle brave check.
- `pet-trail-buddy-bond-timeline-storm-map.png`
  - Trail Buddy unfurls a small glowing storm map for future loops.
- `pet-storm-scout-bond-timeline-focus-watch.png`
  - Storm Scout quietly watches the desk during a protected focus moment.
- `pet-storm-scout-bond-timeline-comeback-glow.png`
  - Storm Scout welcomes the user back with a soft no-guilt glow.
- `pet-storm-guardian-bond-timeline-guardian-oath.png`
  - Storm Guardian makes a calm oath to guard the streak gently.
- `pet-storm-guardian-bond-timeline-full-bond.png`
  - Storm Guardian seals the full bond as a daily companion, proud and warm.

- `pet-{stage}-journal-bond-timeline.png`
  - Pet opens a Bond Timeline album with saved, eligible, and locked story
    stamps.

### Batch 43: Visit Log

Purpose: make the desktop pet feel like it returns throughout the day on its
own. These are proactive appearances, not chat replies. The pet notices time,
care state, and user mood, then offers a small interaction.

Generate one transparent 12-frame horizontal strip for each growth stage:

- `pet-{stage}-visit-morning-peek.png`
  - Pet peeks up from the lower screen edge, looks down, looks up, and smiles.
- `pet-{stage}-visit-first-task.png`
  - Pet taps the desk once and points gently toward one first task.
- `pet-{stage}-visit-focus-sit.png`
  - Pet sits beside the cursor in a quiet focus-guard pose.
- `pet-{stage}-visit-snack-nudge.png`
  - Pet nudges a tiny water/snack cue without looking pushy.
- `pet-{stage}-visit-window-wave.png`
  - Pet waves from the edge of the screen for quiet company.
- `pet-{stage}-visit-pressure-guard.png`
  - Pet steps protectively between the user and a noisy task cloud.
- `pet-{stage}-visit-win-pocket.png`
  - Pet pockets a small glowing proof/win and celebrates softly.
- `pet-{stage}-visit-evening-return.png`
  - Pet circles back in evening light to close one loop.
- `pet-{stage}-visit-night-curl.png`
  - Pet curls in a corner and guards rest with sleepy sparks.
- `pet-{stage}-visit-comeback-glow.png`
  - Pet glows warmly when the user returns, with no guilt or alarm.

- `pet-{stage}-journal-visit-log.png`
  - Pet opens a Visit Log album showing appeared, answered, skipped, and locked
    visit stamps.

### Batch 44: Spark Wheel Cycles

Purpose: make passive Spark earning visible, game-like, and pet-centered. Each
loop should show the pet winding a tiny wheel, waiting with energy stored, then
returning with a Spark pouch.

Generate one transparent 12-frame horizontal strip for each growth stage:

- `pet-{stage}-spark-wheel-first-wind.png`
- `pet-{stage}-spark-wheel-morning-charge.png`
- `pet-{stage}-spark-wheel-focus-spin.png`
- `pet-{stage}-spark-wheel-cheer-loop.png`
- `pet-{stage}-spark-wheel-quest-coil.png`
- `pet-{stage}-spark-wheel-night-drift.png`
- `pet-{stage}-journal-spark-wheel.png`

### Batch 45: Proactive Spark Route

Purpose: turn the Hamster-style daily board into a pet-care circuit that can
proactively visit the user throughout the day. These are route prompts and route
receipts, not generic chat bubbles.

Generate one transparent 12-frame horizontal strip for each growth stage:

- `pet-{stage}-route-proactive-enter.png`
  - Pet arrives with today's route board and points to the next care step.
- `pet-{stage}-route-wake-spark.png`
  - Pet looks down, looks up, and turns first attention into the day's anchor.
- `pet-{stage}-route-care-tap.png`
  - Pet leans into one visible care tap and stores a bond receipt.
- `pet-{stage}-route-snack-stash.png`
  - Pet checks a tiny stash and looks relieved that basic care exists.
- `pet-{stage}-route-focus-perch.png`
  - Pet perches beside one task and makes the desk feel calmer.
- `pet-{stage}-route-lesson-spark.png`
  - Pet repeats one phrase, glows, and saves it as shared practice.
- `pet-{stage}-route-quest-trail.png`
  - Pet opens a tiny trail marker and points to one adventure step.
- `pet-{stage}-route-cipher-pulse.png`
  - Pet taps a glowing secret and reacts when the puzzle clicks.
- `pet-{stage}-route-upgrade-polish.png`
  - Pet polishes one kit card so upgrades feel maintained.
- `pet-{stage}-route-cheer-call.png`
  - Pet asks how the user is doing and saves the answer warmly.
- `pet-{stage}-route-boost-rush.png`
  - Pet does one controlled burst and settles proudly.
- `pet-{stage}-route-ambient-patrol.png`
  - Pet walks the desktop edge and turns idle time into story value.
- `pet-{stage}-route-bedtime-nest.png`
  - Pet closes the route with a soft nest/rest cue.
- `pet-{stage}-journal-spark-route.png`
  - Pet opens a route album showing done, offered, skipped, locked, and saved
    route stamps.

### Batch 46: Care Pulse Needs

Purpose: make low Snack, Rest, Play, and Focus feel like real pet needs. These
are proactive care requests that appear when a vital is low, plus receipts for
answering or skipping.

Generate one transparent 12-frame horizontal strip for each growth stage:

- `pet-{stage}-care-pulse-snack-low.png`
  - Pet notices the snack bowl is low, looks down, looks up, and asks gently.
- `pet-{stage}-care-pulse-rest-low.png`
  - Pet slows its sparks, curls toward a tiny nest, then asks for rest.
- `pet-{stage}-care-pulse-play-low.png`
  - Pet wiggles at the desktop edge, asks for one tiny movement loop, then hops.
- `pet-{stage}-care-pulse-focus-low.png`
  - Pet points to the first small task and perches beside the cursor.
- `pet-{stage}-care-pulse-answer.png`
  - Pet receives care, brightens, and saves a warm care receipt.
- `pet-{stage}-care-pulse-dismiss.png`
  - Pet accepts a skip without guilt, lowers urgency, and waits quietly.
- `pet-{stage}-journal-care-pulse.png`
  - Pet opens an album showing answered, offered, skipped, and locked care
    pulses.

### Batch 47: Cheer Ping Day Rhythm

Purpose: make the companion proactively talk throughout the day with short,
useful, pet-like check-ins. These are lightweight "how are you doing / what is
happening / one tiny next step" moments, separate from care vitals and heavier
quest boards.

Generate one transparent 12-frame horizontal strip for each growth stage:

- `pet-{stage}-cheer-ping-wake-spark.png`
  - Pet looks down, looks up, smiles at the user, and asks how the day is
    starting.
- `pet-{stage}-cheer-ping-first-step.png`
  - Pet taps the desk and points to one tiny first step.
- `pet-{stage}-cheer-ping-water-snack.png`
  - Pet nudges a small water/snack/care signal without guilt.
- `pet-{stage}-cheer-ping-focus-perch.png`
  - Pet perches beside the cursor and guards one useful minute.
- `pet-{stage}-cheer-ping-tiny-win.png`
  - Pet sees a tiny win, pockets a glowing proof, and celebrates softly.
- `pet-{stage}-cheer-ping-stretch-reset.png`
  - Pet stretches, shakes off excess sparks, and turns noise into one reset.
- `pet-{stage}-cheer-ping-evening-wrap.png`
  - Pet returns in evening mode and helps close one loose loop.
- `pet-{stage}-cheer-ping-night-nest.png`
  - Pet curls into a night nest and makes rest feel like valid progress.
- `pet-{stage}-journal-cheer-ping.png`
  - Pet opens a Cheer Ping album showing answered, offered, skipped, and locked
    day-rhythm stamps.

## Character Skin Modes

For the hackathon demo, the native companion is Pikachu-only again. The golden
mascot mode is paused because the asset quality is not strong enough.

- `--character pika`
  - Uses the Pika-facing text prefix and a cute, higher-pitched local female
    voice profile for non-lesson pet moments.
- `--character golden`
  - Deferred. The launch script now rejects this mode so the demo cannot drift
    into the weaker skin by accident.

The minimized pet keeps settings and close controls hidden until hover, while
the macOS menu bar shows a live Pika item with Show, Pet Only, Mute, and Close commands.
Pika uses original local speech settings, not official sampled or cloned
character audio.

Future skins should keep the same filename/action vocabulary so the app can
switch characters without rewriting the game logic, but new skins should only
ship once their sprite quality matches the Pikachu surface.

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
