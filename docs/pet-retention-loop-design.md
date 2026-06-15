# Pika Pet Retention Loop Design

## Goal

Make the desktop companion feel like a living pet that grows through repeated
care, not a chat widget with a mascot. The product loop should be readable in
the first minute and still have enough daily depth for a hackathon demo:

1. The pet idles on the desktop.
2. It proactively checks in with a short bubble.
3. The user answers, pets, learns, asks for a hint, or runs one tiny loop.
4. The pet earns Joy, Bond HP, Sparks, vitals, memories, and visible growth.
5. New emotions, poses, rooms, toys, tricks, and stages unlock over time.

## Hamster-Style Mechanics, Translated Safely

The viral Telegram loop to borrow is not the crypto premise. The useful pieces
are retention mechanics:

- Tap action: one small action gives immediate currency.
- Idle income: the game keeps progress while the user is away.
- Energy cap: active rewards are limited and recharge over time.
- Daily combo: a rotating set of actions creates a daily objective.
- Daily cipher: a small puzzle gives a recurring return hook.
- Upgrade cards: currency buys visible behavior improvements.
- Time windows: returning at morning, focus, afternoon, evening, and night
  feels meaningful.
- Comeback reward: returning after absence is rewarded without guilt.
- Collection album: finished actions become receipts, not invisible counters.

PocketDM translation:

| Viral mechanic | Pet version |
| --- | --- |
| Tap for coins | Pet/care for Sparks and Joy |
| Profit per hour | Passive Sparks while away |
| Daily combo | Daily Spark Route and combo deck |
| Daily cipher | Tiny cipher or language clue |
| Upgrade cards | Snack Bowl, Study Bell, Quest Map, Cheer Signal, Spark Wheel |
| Energy boosts | Spark Boost and care vitals |
| Return windows | Daypart check-ins |
| Card collection | Charms, memories, home rooms, toys, tricks, field notes |

## Current Runtime Contract

The current native app already has these systems in code:

- Growth stages: `Tiny Spark`, `Pocket Pal`, `Trail Buddy`, `Storm Scout`,
  `Storm Guardian`.
- Core counters: Bond HP, Joy, Sparks, energy, snack/rest/play/focus vitals.
- Daily systems: combo, quest deck, bond board, spark route, cipher, booster.
- Relationship systems: cheer bubbles, user check-ins, daypart nudges,
  field notes, affection gestures, wishes, toys, tricks, home rooms.
- Albums: growth journey, mood stories, emotion episodes, charms, memories,
  route, care windows, rooms, errands, wishes, toys, tricks.

Primary files:

- `/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/Sources/PocketDMCompanion/PetLoopModels.swift`
- `/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift`
- `/Users/amal/listenowl/experiments/build-small/docs/pet-sprite-sheet-requests.md`

## Proactive Cheer Cadence

The pet should not wait passively for the user. It should be active but not
annoying:

- First minimized launch: check-in can appear quickly.
- New daypart: check-in may appear even if the normal cooldown has not elapsed.
- Generic cheer cooldown: 45 minutes by default.
- Cheer Signal upgrades reduce cooldown by 6 minutes per level.
- Minimum cooldown: 8 minutes.
- Runtime scan interval: 5 minutes.
- Bubble must be dismissible without shame.
- Answering a bubble gives Joy, Sparks, vitals, and a memory receipt.

This turns "throughout the day" into five meaningful touchpoints:

- Sunrise: "How are you doing this morning?"
- Focus: "What is happening over there?"
- Afternoon: "Need a boost, stretch, or softer step?"
- Evening: "Want to close one loop?"
- Night: "Want a soft check-in?"

## Growth Arc

Each stage needs a different emotional role and animation language.

| Stage | Role | Visual motion |
| --- | --- | --- |
| Tiny Spark | vulnerable new arrival | looks down, looks up, small trust smile |
| Pocket Pal | recognizes the user | quicker reaction, tiny affection hops |
| Trail Buddy | joins quests and lessons | points, follows, carries small props |
| Storm Scout | proactive helper | patrols, scouts, watches focus tasks |
| Storm Guardian | calm daily-loop guardian | slower confidence, protective glow |

Growth should come from both HP and care receipts:

- HP proves daily relationship.
- Sparks prove loop participation.
- Stage arrivals should be visible album scenes.
- Evolution should not feel like replacing the pet; it should feel like the
  same character becoming more capable.

## Emotion Model

The pet should not only be happy/nap/hyper. It needs cause, care, and recovery:

- bright: user returns or completes something.
- eager: wants a tiny next step.
- proud: saves a receipt.
- overcharged: needs focus or grounding.
- focused: sits with a task.
- celebratory: stores a win.
- guarded: late-night protective mode.
- gentle: repair after a rough moment.
- playful: needs movement.
- grateful: user came back.
- determined: approaching growth.
- restless: wants an upgrade or task.
- snacky: energy is low.
- sleepy: needs rest.
- curious: asks what is happening.
- lonely: waited and needs reconnection.

Each emotion needs:

- idle pose,
- proactive bubble pose,
- care-action pose,
- resolution pose,
- album receipt pose.

## Main Daily Loops

### Loop 1: Living Desktop

- Idle animation.
- Hover-only controls.
- Periodic ambient moment.
- Proactive bubble.
- Click opens expanded panel.

### Loop 2: Daily Care

- Pet once.
- Joy +1, Bond HP +1 once per day.
- Vitals refill.
- Daily charm or memory may unlock.

### Loop 3: Daily Spark Route

- Rotating route steps: wake, care, snack, focus, lesson, quest, cipher,
  upgrade, cheer, boost, ambient patrol, bedtime nest.
- Completing route steps gives Sparks and album receipts.

### Loop 4: Combo And Cipher

- Three-action daily combo.
- Tiny cipher/puzzle.
- Completion gives visible "combo complete" animation and reward.

### Loop 5: Cheer Throughout The Day

- Pet asks how the user is doing.
- User can answer or dismiss.
- Answers unlock check-in memories and emotional states.

### Loop 6: Habitat And Desire

- Home rooms make the pet feel grounded.
- Wishes make the pet feel like it wants things.
- Toys make play readable.
- Tricks make growth visible.
- Errands make idle time feel alive.

## Sprite Generation Priority

Generate in this order if the goal is a better demo fast:

1. Stage Runtime Matrix
   - Five stages x idle, happy, hyper, nap, curious/listen.
2. Daypart Cheer Pack
   - Sunrise, focus, afternoon, evening, night, answer, dismiss.
3. Emotion Recovery Pack
   - bright, tired/sleepy, stuck/curious, overwhelmed, lonely, proud, focused,
     need-break.
4. Growth Arrival Pack
   - one arrival scene per stage plus four evolution transitions.
5. Spark Route Pack
   - wake, care, focus, lesson, quest, cipher, cheer, boost, bedtime.
6. Habitat Pack
   - home rooms, wishes, toys, tricks, errands.
7. Album Receipts Pack
   - charms, memories, mood album, route album, growth map, art request.

## Acceptance Criteria

- Minimized mode shows only the animated pet until hover or bubble.
- A proactive bubble appears quickly on first demo launch.
- New daypart check-ins can appear even if the normal cooldown has not elapsed.
- User can answer/dismiss without opening the browser.
- Answering a bubble visibly changes Joy/Sparks/vitals/memory state.
- The journal can explain why a reward happened.
- Stage-specific sprites load when files exist and fall back safely when absent.
- The sprite request list contains exact filenames for every loop that code can
  reference.

