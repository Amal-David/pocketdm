# Lessons

## 2026-06-10 — Don't trust a PRD's model pick; verify against the current landscape
The PRD specified Gemma-3-270M as the student model. User rejected it as unworkable.
Also: "Qwen 4" doesn't exist (newest small gen = Qwen3.5), and Gemma 4's smallest model
is 5.1B *total* params — naming generations from memory is hazardous.
**Rule:** before any training spend, (1) re-verify the model landscape with fresh research,
(2) confirm the size/quality tradeoff with the user, (3) check prize/size caps against
*total* params, not marketing "effective" params.

## 2026-06-10 — Licenses propagate through outputs, not just weights
Llama-3.3's license forces models trained on its *outputs* to carry "Llama" in the name.
**Rule:** check the teacher's license before generating synthetic data, not after.

## 2026-06-10 — codex exec inherits the shell's cwd as its sandbox root
A `cd` into a subdirectory in a prior command silently scoped a later `codex exec`
workspace-write sandbox to that subdir (it reported the whole repo as read-only).
**Rule:** always pass `-C <repo-root>` explicitly to `codex exec`; verify the
`workdir:` line in its output header before trusting a run.

## 2026-06-11 — When the user says "speed" on Gemma 4, check MTP first
The "not too quantized" path improved quality knobs but missed the user's screenshot:
Gemma 4 MTP/speculative decoding is the speed lever. The working local path needs
native recent llama.cpp `llama-server`/`llama-cli` support with `--spec-type draft-mtp`;
`llama-cpp-python` alone cannot load the Gemma4Assistant drafter because it needs
`ctx_other` shared with the target context.
**Rule:** for Gemma 4 latency work, prioritize MTP server/CLI proof, tune
`--spec-draft-n-max` on the actual hardware, and keep the Python binding as the
fallback quality/smoke path.

## 2026-06-12 — Browser TTS must have a single audio owner
User reported overlapping sound after clicking answer choices. The frontend was
starting async narration audio while Ember's browser speech could also speak, and
old `/api/tts` responses could still start after the next turn began.
**Rule:** when a new turn/action starts, abort pending TTS, stop any current
narration, cancel browser speech, and make turn-result assistant text silent
unless the user explicitly asks Ember to speak.

## 2026-06-12 — The dragon visual must be cinematic, not cute mascot art
User rejected the green cute sprite and clarified the target is a How to Train
Your Dragon-like 3D companion feel: sleek, dark, expressive, pet-like, and
always-on above the screen.
**Rule:** keep Ember original, but steer the artifact toward glossy black
cinematic dragon traits, expressive eyes, wing silhouette, and desktop-pet
behavior; do not ship a generic cartoon dragon or a chat widget with a mascot.

## 2026-06-12 — Use anime-mascot energy without shipping protected characters
User suggested a top anime pet direction such as Pikachu because the shape reads
faster than the custom dragon attempts.
**Rule:** do not use official character sprites, names, or catchphrases in the
public hackathon artifact. Build an original electric familiar with yellow
mascot readability, cheek sparks, and short custom chirps like "zip-zip" instead.

## 2026-06-12 — Sprite sheets should become pet states, not decoration
User provided 3D mood sheets and wanted the whole app to pick up that livelier
desktop-pet feeling.
**Rule:** when good reference sheets arrive, extract a consistent frame format
and wire the app around visible states like happy, nap, hyper, and alert; don't
leave the asset as a static mascot beside a normal chat UI.

## 2026-06-12 — Native pet polish beats branded action names
User cared about the macOS overlay itself, not the browser, and called out the
sprite extraction border plus marketing-heavy labels like Spark.
**Rule:** verify the actual desktop overlay, regenerate masks when source-sheet
halos appear, and prefer literal state labels such as Happy, Nap, and Hyper.

## 2026-06-12 — Minimized native pets still need core utility
User wanted the minimized macOS companion to remain a real chat surface, not a
tiny decorative pill.
**Rule:** collapsed native overlays should keep the animated pet, response
preview, direct input, send control, mute toggle, and expand control; avoid
marketing-heavy visible labels and remove source-sheet halo pixels before
shipping screenshots.

## 2026-06-12 — Default desktop-pet mode must be pet-first, not chat-first
User corrected the minimized state again: the default surface should show only
the animated pet, and clicking the pet should expand the chat/care interface.
**Rule:** for the native companion, make the character the primary affordance:
pet-only default, click-to-expand chat, visible close in expanded mode, and a
small daily care loop with Bond HP/Joy rather than a generic compact chat strip.

## 2026-06-12 — Low-alpha dark pixels still read as a border
User pointed at a black contour around the minimized 3D pet even after the
SwiftUI border was gone. The line came from semi-transparent dark pixels baked
into the extracted sprite edge.
**Rule:** when extracting 3D mascot sheets, pixel-check the alpha fringe on a
white background, remove dark/gray low-alpha halo pixels, and regenerate native
plus web strips from the original sheets instead of trying to hide the issue in
layout code.

## 2026-06-12 — Language packs must be real packs, not demo cards
User corrected the language coach scope after the first Spanish/Mandarin demo
used only a few cards.
**Rule:** language-learning packs should ship as explicit word and sentence
sections with at least 100 entries each per language, and the native lesson
store should count the whole pack rather than hard-code the first three cards.

## 2026-06-12 — Native overlay controls cannot share the drag surface
User reported that the native companion minimize button still did not work
reliably.
**Rule:** keep draggable title/handle regions separate from close, minimize,
mute, send, and other controls. A `DragGesture` on the same SwiftUI row as
buttons can swallow tiny pointer movements and make the buttons feel dead.

## 2026-06-12 — Rebuild pet sprites from source sheets, not damaged strips
User showed the black contour still visible after previous alpha cleanup. The
remaining line was baked into the generated source-sheet contour, not SwiftUI.
**Rule:** keep a repeatable source-sheet rebuild script, segment from the
high-resolution generated sheets, and verify on a white background. Do not keep
patching already-extracted strips when the contour is part of the pixels.

## 2026-06-12 — Desktop pets need loops, not just moods
User asked for a real pet system with lore, daily care, growth, proactive cheer,
and hamster-style engagement mechanics.
**Rule:** treat the native companion as the product surface: pet-only default,
click-to-expand utility, gentle check-ins, visible rewards, energy/progression,
and explicit sprite requests for every new behavior before polishing copy.

## 2026-06-12 — Competitive scans should become systems, not moodboards
User asked to read the Build Small submissions and derive inspiration from them.
**Rule:** translate inspiration into product mechanics immediately: ritual copy,
visible state receipts, short feedback loops, sound hooks, and a sprite matrix
that maps growth stage plus feeling plus action into concrete assets.

## 2026-06-12 — Transparent pet art cannot use black shadows on light desktops
Visual verification showed the minimized pet still had a dark contour even after
sprite cleanup because the SwiftUI image had a black shadow.
**Rule:** for transparent desktop-pet sprites, avoid black silhouette shadows in
pet-only mode; use no shadow or a non-dark glow only after checking on a white
desktop.

## 2026-06-12 — Pet catchphrases need text and audio together
User explicitly wanted the companion/model to say "pika pika" in text and in
voice.
**Rule:** mascot catchphrases should appear in the visible response text and
trigger a native voice or sound reaction on meaningful pet events, with mute
still respected. Apply the same wrapper to fallback UI text so demo paths do
not drift from the native companion.

## 2026-06-12 — Absence should create a comeback, not punishment
User wants a proper pet with growth, emotions, nudges, and long-running loops.
**Rule:** when modeling time away, use gentle mood softening plus comeback
rewards, time-of-day greetings, and visible evolution progress; do not make the
pet feel needy, punitive, or like a generic streak counter.

## 2026-06-12 — A pet needs wants and memories, not only counters
The broader goal is a proper desktop pet, and counters alone still feel like a
gamified dashboard.
**Rule:** give the companion rotating care needs and persistent bond memories so
the user can understand what the pet wants today, what it remembers, and why new
sprites represent relationship moments rather than decoration.

## 2026-06-12 — Viral loops need a pet-safe translation
The hamster-style loop is useful because of daily events, upgrade cards,
collection goals, and short returns, not because of crypto framing.
**Rule:** convert retention mechanics into pet care: short daily events,
seasonal badges, gentle rewards, and visible state receipts that explain why the
pet is growing or changing.

## 2026-06-12 — Emotions need state, not only labels
User wants a proper pet that changes across the day and grows from small to big.
**Rule:** every visible emotion should eventually be backed by persistent state,
rewards, sprite requests, and daily discovery/revisit loops, not just a word in
the status panel.

## 2026-06-13 — Pet progress needs an album surface
As care loops accumulate, the tiny status stack becomes too dense to explain the
pet fantasy.
**Rule:** move relationship progress into inspectable album/journal surfaces
with clear progress groups and next asset requests, while keeping the default
desktop state pet-only.

## 2026-06-13 — Journal pages beat one giant journal summary
After the first journal view existed, the next step was making each relationship
layer inspectable on its own.
**Rule:** split dense pet progress into small pages for growth, moods, memories,
badges, daily rituals, and art requests so users can understand one loop at a
time.

## 2026-06-13 — Proactive pet bubbles need intent and reward
User wants the pet to proactively ask how the user is doing throughout the day,
not just sit as a chat widget.
**Rule:** check-in bubbles should carry a clear context, question, action, and
reward receipt so accepting the bubble feels like answering a companion rather
than clicking a notification.

## 2026-06-13 — Character voice must be text and sound
User expects the pet/model personality to show up both in the written response
and the spoken cue.
**Rule:** every assistant-facing reply path should keep the "Pika pika!" text
prefix and trigger an audible original pika-like cue, with duplicate-prefix
guards for both spaced and hyphenated variants.

## 2026-06-13 — Daily care needs a weekly arc
User wants a proper pet loop inspired by viral Telegram retention mechanics,
not isolated one-off buttons.
**Rule:** daily care should feed a visible weekly trail with milestone rewards,
journal receipts, and matching sprite requests so returning over several days
feels like relationship progress.

## 2026-06-13 — Proactive cheer needs a daily rhythm
User wants the pet to check in throughout the day, not just fire a generic
chat bubble on a timer.
**Rule:** proactive nudges should be tracked by daypart with answered and
dismissed state, rewards, journal receipts, and separate sprite requests for
morning, focus, afternoon, evening, and night.

## 2026-06-13 — Upgrade cards need a visible deck
Hamster-style upgrades should not be hidden behind one purchase button.
**Rule:** every upgrade card needs visible level, next cost, behavior effect,
and a matching sprite request so the progression loop feels collectible and
legible.

## 2026-06-13 — Pet needs should drift and refill
User wants the companion to feel like a real desktop pet, not a static helper
with rewards only.
**Rule:** core care needs should have persistent vitals that gently decay with
time and refill through obvious actions, such as petting for Snack, Nap for
Rest, Hyper for Play, and Learn/Hint/Boost for Focus.

## 2026-06-13 — Pika voice must cover model replies
User clarified that the model itself should say "pika pika" in text and voice.
**Rule:** assistant replies, lesson feedback, and pet actions should use a
single guarded catchphrase wrapper and trigger the native pika-like voice cue
when sound is enabled. Real model or coach replies should visibly start with
"Pika pika!" and the spoken preview should say the same catchphrase before the
concise response, not only play a generic chirp.

## 2026-06-13 — Pet loops need keepsakes, not only payouts
The broader pet fantasy needs visible proof of shared moments, similar to how
viral daily games make collections and albums feel worth returning to.
**Rule:** important actions should unlock collectible care charms with journal
receipts and sprite requests, so petting, studying, adventuring, resting,
playing, focusing, solving, events, upgrades, and weekly care become album
progress rather than transient text.

## 2026-06-13 — Growth needs quests, not only thresholds
User wants the pet to grow from small to big like a proper companion with a life
arc.
**Rule:** evolution should be represented as staged quest cards with lore,
progress, rewards, and sprite requests so Tiny Spark, Pocket Pal, Trail Buddy,
Storm Scout, and Storm Guardian feel like earned relationship chapters.

## 2026-06-13 — Emotions need care recipes
User wants the pet to go through real emotions, not just display mood names.
**Rule:** each meaningful feeling should map to care actions that help it
recover, express, or complete a daily arc; the app should track recipe progress,
reward completion, and request matching mood-care sprite sheets.

## 2026-06-13 — Proactive bubbles should help the current emotion
User wants the pet to proactively cheer and ask how the user is doing
throughout the day.
**Rule:** minimized check-ins should sometimes ask for the next mood-care step
and accepting the bubble should mark real recipe progress, so proactive text
feels like companion care instead of a generic notification.

## 2026-06-13 — Proactive voice needs the catchphrase too
User clarified that the model should say "pika pika" in text and in voice.
**Rule:** minimized check-ins and assistant reply moments should visibly keep
the guarded "Pika pika!" prefix and force a short native voice cue when the
pet initiates a new check-in.

## 2026-06-13 — Hamster-style loops need care meaning
User wants the viral Telegram-style loop, but as a proper desktop pet with
emotion, growth, and lore.
**Rule:** daily board mechanics should become care contracts with visible
receipts, vitals, mood-care progress, proactive prompts, and sprite requests,
not abstract coin tapping or finance-style progression.

## 2026-06-13 — Proactive cheer needs real conversation beats
User wants the pet to ask how the user is doing and what is happening
throughout the day, not only show task notifications.
**Rule:** proactive check-ins should include a rotating dialogue deck with
answer/skip state, warm receipts, care impact, and matching sprite requests,
while avoiding guilt when the user dismisses them.

## 2026-06-13 — Growth needs life scenes, not just stage names
User wants the pet to grow from small to big like a proper companion.
**Rule:** every growth stage should expose small playable life scenes with lore,
care effects, stage-specific sprite requests, and journal receipts so Tiny
Spark, Pocket Pal, Trail Buddy, Storm Scout, and Storm Guardian feel behaviorally
different.

## 2026-06-13 — Weekly loops should become story chapters
The Hamster-style retention loop is useful only if it feels like relationship
progress instead of abstract streak pressure.
**Rule:** week-long care should unlock named story chapters, persistent album
receipts, vitals, mood-care effects, and sprite filenames, while the high-value
weekly payouts remain secondary to the pet bond.

## 2026-06-13 — Proactive bubbles need purpose types
The user wants the pet to proactively ask how the user is doing throughout the
day, not merely surface generic notifications.
**Rule:** every proactive bubble should carry a visible intent type such as
Feeling, Focus, Tiny Win, Reset, Quest, Lesson, Rest, Comeback, Board, Puzzle,
Boost, Upgrade, Event, or Care, and that type should have answer/skip state,
care effects, and a matching sprite request.
