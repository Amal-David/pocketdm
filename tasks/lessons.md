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

## 2026-06-15 — Parallel agents should review broadly, but edits need ownership
User corrected that the hackathon sprint was not using enough subagents.
**Rule:** when the user asks for heavy parallelization, launch multiple bounded
review/research/test agents with distinct questions, but keep source edits
serialized or split by disjoint file ownership so parallelism does not create
merge noise in shared SwiftUI surfaces.

## 2026-06-15 — llama.cpp is the brain contract, not the whole voice stack
User reminded that llama.cpp support is a hackathon requirement while the app is
also using Nemotron ASR and VoxCPM TTS sidecars.
**Rule:** prove the companion brain through a GGUF llama.cpp/OpenAI-compatible
server and benchmark it before switching models. Keep ASR/STT and TTS on the
native runtimes that actually support those checkpoints, with clear fallback
labels instead of pretending every model belongs in llama.cpp.

## 2026-06-15 — Demo pet UI must ask one tiny thing at a time
User said the expanded companion had too much information and random "tt" sounds.
**Rule:** keep the default pet experience to one visible prompt, one primary
action, one reward receipt, and quiet routine send/reply ticks. Put dense
systems in Journal/docs, and keep deterministic basics like time/date before
adventure or LLM routing.

## 2026-06-14 — Reply effects must not cancel mascot voice
User saw "Pika pika!" text but heard no matching audio after an assistant reply.
**Rule:** if a response path plays a short UI effect before speech, the forced
voice path must bypass recent-sound suppression and still attempt the TTS
sidecar before falling back to bundled chirps.

## 2026-06-14 — Talk flow needs microphone and speech permission checks
User reported that Talk now was not usable.
**Rule:** native voice capture should request microphone access explicitly before
speech recognition, surface denial/restriction as visible status text, and only
start transcription after both permission layers are available.

## 2026-06-14 — Low vitals should ask for care
User wants a proper pet, not just counters.
**Rule:** when Snack, Rest, Play, or Focus drops low, surface it as a proactive
care pulse with offered, answered, skipped, reward, mood animation, journal
proof, and exact sprite filenames.

## 2026-06-14 — Pika voice should be original, not generic TTS or ripped clips
User corrected that written Pika text should not just use generic TTS and asked
for free/open sound effects.
**Rule:** keep mascot voice as original local chirps or a consented voice
recipe, layer CC0 electric/UI sounds for interaction polish, and do not bundle
official-character clips or unclear mirror downloads.

## 2026-06-14 — Proactive cheer needs its own rhythm
User wants the companion to talk throughout the day with "how are you doing?"
and "what is happening?" moments, not only respond to clicks or show counters.
**Rule:** model lightweight day-rhythm pings separately from vitals, quests, and
upgrade boards, with offered, answered, skipped, album, reward, mood, and exact
sprite filenames.

## 2026-06-14 — Codex commits should identify Codex locally
User corrected that pushes/commits from this repo should say Codex when Codex is
doing the work.
**Rule:** keep repo-local Git author and committer metadata set to
`Codex <codex@local>` before creating commits from this checkout; remember that
GitHub's "pushed by" label still comes from the authenticated remote account.

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

## 2026-06-13 — Proactive conversations need memories
The pet should feel like it remembers small check-ins, not like it emits
throwaway notifications.
**Rule:** answered proactive bubbles should unlock named Cheer Memories with
daily progress, permanent album progress, care effects, and exact sprite
filenames so "how are you doing?" becomes relationship history.

## 2026-06-13 — Growth must affect actual runtime art
Stage names and scale changes are not enough for a proper digital pet.
**Rule:** the native sprite renderer should prefer stage-specific sheets for
Tiny Spark, Pocket Pal, Trail Buddy, Storm Scout, and Storm Guardian, then fall
back to generic sheets until generated art arrives.

## 2026-06-13 — Evolution needs arrival memories
A proper pet should remember becoming bigger, not silently cross a threshold.
**Rule:** stage changes should unlock persistent Growth Journey entries with
arrival lore, rewards, care effects, and exact arrival/transition sprite
filenames.

## 2026-06-13 — Model voice must say the catchphrase
User clarified again that the model should say "pika pika" in text and in
voice.
**Rule:** every assistant/model feedback path should visibly keep the guarded
"Pika pika!" prefix and force the native spoken catchphrase on direct reply or
quiz feedback moments so debounce never makes the character voice disappear.

## 2026-06-14 — Pet-only chrome must be sprite-triggered
User corrected that the settings gear and close X should not appear just
because the pointer is inside the transparent minimized overlay panel.
**Rule:** minimized chrome should be revealed by hovering the visible pet
sprite, while blank transparent panel space stays visually inert; once revealed,
controls can remain hittable long enough to click them.

## 2026-06-13 — Recovery loops must welcome, not punish
The user wants Hamster-style retention loops, but the pet fantasy should not
turn missed days into guilt.
**Rule:** missed-day mechanics should use shields, soft returns, comeback
albums, care effects, and concrete sprite requests so returning feels like
repairing a relationship rather than losing a counter.

## 2026-06-13 — Proactive text needs a scriptbook
The user wants the pet to proactively ask how the user is doing throughout the
day with many small text moments.
**Rule:** proactive copy should live in a rotating, persistent scriptbook with
daypart/intent targeting, accepted/skipped state, care rewards, journal
receipts, and exact sprite requests, not as loose one-off bubble strings.

## 2026-06-13 — Idle animation needs state
A proper desktop pet should feel alive even between clicks.
**Rule:** ambient idle behaviors should be timed, care-aware, persisted in a
daily/permanent album, and tied to exact sprite requests so animation loops
express relationship state rather than decorative motion.

## 2026-06-13 — Catchphrase is part of the model contract
User clarified that the model should also say "pika pika" in text and in
voice.
**Rule:** direct assistant/model responses should go through the shared
catchphrase text wrapper and forced speech preview; do not rely on a quiet
chirp or debounced sound when the user is expecting the character to speak.

## 2026-06-13 — Viral loops need a visible daily path
The user wants the Telegram hamster-style loop, but for a proper desktop pet
with care, lore, growth, and proactive cheer.
**Rule:** recurring mechanics should assemble into a named daily route with
step receipts, album progress, care-vital effects, mood-care effects, and exact
sprite filenames; avoid leaving combo, cipher, boost, upgrade, and check-in
actions as disconnected buttons.

## 2026-06-13 — Generated pet sheets need real alpha
User reported that the generated pet character still showed its sheet
background.
**Rule:** generated external sprite sheets must be treated as opaque contact
sheets unless proven otherwise. Clean edge-connected sheet backgrounds into
real RGBA alpha at asset-prep time, and keep a runtime loader cleanup path for
new `output/sprite-sheets/pet-*.png` files so cream or grid backgrounds never
show up behind the desktop pet.

## 2026-06-13 — Cheer must speak from the pet's mood
The user wants proactive "how are you doing?" bubbles to feel like a real pet,
not generic scheduled text.
**Rule:** proactive check-ins should include mood-specific story prompts tied to
the current feeling and growth stage, and those prompts need answered/skipped
state, permanent album proof, care-vital effects, mood-care effects, and exact
sprite filenames.

## 2026-06-13 — Task boards should become pet errands
The broader goal is hamster-style retention translated into a proper desktop
pet.
**Rule:** task-board mechanics should be small in-world errands the pet can ask
for, do, skip, remember, and show in a journal album. Each errand needs care
effects, proactive bubble wiring, a direct native button, and exact sprite
filenames so it feels like relationship activity rather than checklist UI.

## 2026-06-13 — Lesson audio needs the catchphrase too
The user clarified again that the model should say "pika pika" in text and in
voice, not only in static labels.
**Rule:** native assistant replies and language-coach playback should both speak
the catchphrase before their content while preserving the target-language voice
for Spanish and Mandarin phrases.

## 2026-06-13 — Pet lore needs found objects, not only tasks
The user wants a proper pet with lots of lore, emotions, spritesheets, and
hamster-style return loops.
**Rule:** add collectible "the pet found this for you" moments, such as field
notes, that are selected from mood/daypart/growth state, reward care progress,
and request exact sprite sheets so daily return loops feel like shared story.

## 2026-06-13 — Return loops need a wait state
The user wants viral pet loops that feel alive, not just another instant reward
button.
**Rule:** expedition mechanics should have a start state, visible return timer,
collect action, proactive return bubble, rewards, album progress, and exact
sprite requests so the user feels Pikachu actually went somewhere and came
back.

## 2026-06-13 — A pet needs wants, not only tasks
The user keeps pushing the companion toward a proper pet with emotions, lore,
growth, and proactive care.
**Rule:** add loops where the pet expresses small desires in its own voice,
tracks whether the user answered, rewards care, and records the moment in an
album with exact sprite requests. Desire makes the companion feel alive.

## 2026-06-13 — Catchphrase cannot be only a chirp
The user clarified that the model should say "pika pika" in text and in voice.
**Rule:** assistant replies, pet rewards, and proactive bubbles should share one
guarded text prefix and one spoken preview path so the user sees and hears the
same character beat without duplicate catchphrases.

## 2026-06-13 — Growth must change available behavior
The user wants the pet to grow from small to big with many emotions, flows, and
spritesheets.
**Rule:** new relationship loops should include growth-locked behavior whenever
possible, so later stages unlock new actions, proactive prompts, album progress,
and sprite filenames instead of only scaling the same idle pet.

## 2026-06-13 — Character skins need separate controls and voices
The user wants to showcase Pika and the original golden 3D mascot as
interchangeable modes, and noted the new batch is 2x6 rather than a single
horizontal strip.
**Rule:** support both launch-time and in-app character switching, keep each
skin's catchphrase and voice profile distinct, and make the sprite loader accept
first-pass 2x6 sheets while still documenting horizontal strips as the final
preferred format.

## 2026-06-13 — Return loops need multiple daily moments
The user wants the companion to feel like a real pet, not a one-button reward
counter, and referenced hamster-style viral retention loops.
**Rule:** daily return mechanics should include multiple time-based care
windows, each with state, rewards, vitals, proactive-bubble completion, album
proof, and exact sprite filenames, so returning later in the day feels like
relationship care.

## 2026-06-13 — Proactive mood should reflect context
The user wants cheer bubbles to feel like a living pet with emotions, growth,
and day rhythm, not a generic notification feed.
**Rule:** proactive mood prompts should choose from current feeling, current
care window, and growth stage, then persist answered/skipped state and request
exact sprite sheets for those emotional beats.

## 2026-06-13 — Demo skins must switch from the pet surface
The user wants to showcase Pika and the original golden 3D mascot as two launch
or slash-command modes, but also needs a visible gear on the desktop pet itself.
**Rule:** keep character switching available at launch, through slash commands,
and through a native gear control in minimized and expanded states. Give each
skin a distinct visible catchphrase and local voice profile, and keep Pika's
voice original and pika-like rather than using sampled official character audio.

## 2026-06-13 — Affection needs its own remembered loop
The user keeps pushing for a proper digital pet, not a utility mascot.
**Rule:** touch/care should have named gestures, proactive asks, daily
answered/skipped state, album progress, care-vital effects, rewards, and exact
sprite filenames. A pet should remember being cared for.

## 2026-06-13 — A proper pet needs a home
The user wants the companion to feel like a living pet with lore, growth, and
return loops.
**Rule:** add habitat rooms as remembered places with direct actions,
proactive asks, daily visited/skipped state, album progress, rewards, care
effects, and exact sprite filenames. The pet should appear to live somewhere.

## 2026-06-13 — Cheer should remember the user too
The user wants proactive "how are you doing?" moments, not just pet-state
notifications.
**Rule:** user check-ins should have named emotional states, direct and
proactive entry points, daily answered/skipped state, album proof, rewards,
care-vital effects, visible feedback, and exact sprite filenames.

## 2026-06-13 — Demo focus beats skin breadth
The user reversed the earlier Goldy showcase direction because the golden
mascot does not look good enough. They also flagged that hover-only exit
controls, tiny paragraphs, and Learn-mode "Pika pika" prefixes make the product
hard to use.
**Rule:** prioritize the strongest Pikachu surface for the hackathon demo,
pause weaker character skins, keep close/show controls always reachable from
both the pet and menu bar, make the main overlay a readable game HUD, and keep
language-learning feedback free of pet catchphrases.

## 2026-06-13 — Voice-first must stay original
The user wants a better Pikachu-like voice and a daily voice conversation loop,
but requested sourcing from YouTube would create a copied-character demo risk.
**Rule:** build the voice-first workflow around native or local STT, the
existing assistant endpoint, and a swappable local TTS server. Use original or
consented reference audio only; never depend on ripped official character audio
for the product path.

## 2026-06-14 — Pet chrome should be hover-only
The user wants the settings gear and close X to appear only when hovering over
the pet, not as always-visible desktop chrome.
**Rule:** keep destructive or configuration controls hidden by default on the
always-on pet surface, reveal them from the pet hover stage, and leave menu-bar
fallback actions available for accessibility and recovery.

## 2026-06-14 — Pika text should not use generic TTS
User clarified that visible "Pika pika" text should not be read by a generic
system TTS voice.
**Rule:** mascot reactions should use short original or properly licensed
Pika-like sound effects, while sentence-level TTS stays reserved for language
lessons, pronunciation help, and explicit narrated content.

## 2026-06-14 — Pika sounds need a clean license path
User asked to find free/open-source sound effects because text Pika should not
be treated as normal TTS.
**Rule:** do not bundle official or ripped character audio; use synthesized
original mascot cues as the primary voice and only add external SFX after
verifying CC0 or compatible attribution terms per individual asset.

## 2026-06-14 — Emotions need rituals, not just labels
User reiterated that the companion is not close to a real pet experience and
needs many emotions, flows, lore beats, and sprite sheets.
**Rule:** every major feeling should have a named care ritual with proactive
bubble copy, rewards, care-vital effects, mood animation, journal progress, and
exact sprite-sheet filenames so the emotion becomes an interaction loop.

## 2026-06-14 — Return rewards should read as care
User wants Hamster-style retention mechanics, but the desktop companion still
needs to feel like a pet.
**Rule:** daily chests, comeback rewards, and timed claims should be framed as
pet-care moments with daypart eligibility, proactive asks, visible journal
proof, care-vital effects, and exact transparent sprite-sheet filenames.

## 2026-06-14 — Growth needs permanent story proof
User keeps emphasizing that the companion should grow from small to big like a
proper pet, not only unlock more buttons.
**Rule:** growth systems should include permanent relationship chapters with
eligibility gates, proactive save prompts, journal proof, care effects, and
exact sprite filenames so HP, Sparks, and streaks become visible lore.

## 2026-06-14 — Open sounds are interaction texture, not identity
User asked again to find free/open sound effects because Pika text should not
be spoken as generic TTS.
**Rule:** keep the mascot voice as original or properly licensed short chirps,
then use CC0/open sound packs for button, send, wake, zap, reward, and motion
accents. Do not let downloaded SFX replace the character's owned voice style.

## 2026-06-14 — Proactive visits need album proof
User wants the pet to come in throughout the day and ask how the user is doing,
not wait like a chat widget.
**Rule:** time-of-day pet appearances should be modeled as named visits with
offered/answered/skipped state, care-vital effects, rewards, journal progress,
and exact sprite filenames so proactive attention becomes relationship history.

## 2026-06-14 — Passive loops need visible care rituals
User wants Hamster-style game loops, but the pet should still feel alive.
**Rule:** passive Spark earning should have a visible start/wait/claim ritual,
active run state, return reward, album proof, and exact sprite filenames instead
of only invisible background accrual.

## 2026-06-14 — Daily boards must surface as pet prompts
User wants Telegram/Hamster-style daily loops, but they should not hide inside a
static journal or button list.
**Rule:** each daily route/board mechanic needs a direct next-loop entry,
proactive offered/skipped state, accept handling, route album proof, and exact
sprite filenames so the pet appears throughout the day with a concrete next
care action.

## 2026-06-14 — Desktop assistant must not collapse into adventure hints
User showed that asking "what is the time now" returned the silver-acorn hint,
and they also could not hear the Pika voice.
**Rule:** route typed and spoken desktop requests through a local assistant
intent layer before game-hint logic, expose safe basics like time/date/runtime
status, keep weather check-ins on the same `/api/assistant` path, and make the
native UI show whether Pika voice is muted, sidecar-backed, or using bundled
chirps.

## 2026-06-14 — Local LLM plus STT plus TTS is the core workflow
User corrected that the pet should still be orchestrated by the local LLM with
speech-to-text and text-to-speech, not hardcoded copy plus disconnected sounds.
**Rule:** every voice-first product loop should be modeled as STT transcript,
local assistant context/tool facts, assistant text, then Pika TTS or bundled
chirp playback with visible recovery states.

## 2026-06-15 — Launch should be pet-only
User corrected that server/app startup should show only the desktop Pikachu,
not the whole expanded chat and status panel.
**Rule:** native companion launch must default to the pet-only overlay; panels,
settings, close controls, and chat surfaces should appear only after explicit
hover/click/menu actions.

## 2026-06-15 — Wellness should feel like pet care
User asked for two-hour stand, water, and walk reminders as part of the same
desktop pet experience.
**Rule:** wellness nudges should be proactive pet bubbles with voice, mood,
care-vital rewards, and honest desk-time wording instead of separate timer UI
or fake sensor claims.

## 2026-06-15 — Learn mode should not speak Pika first
User corrected that lesson interactions should not say "Pika pika" before a
target phrase such as "Hola."
**Rule:** language-learning mode should use clean phrase TTS and lesson-copy
feedback only; keep Pika chirps and catchphrases out of lesson playback.

## 2026-06-15 — Codex commits need Codex identity
User corrected that commits made from the Codex app or local Codex server should
not show their personal Git author name.
**Rule:** keep both repo-local and global Git identity set to `Codex
<codex@local>` before committing from this workspace; existing historical commits
remain unchanged unless explicitly amended.

## 2026-06-15 — Voice-first means a real local STT sidecar
User wants the Pika companion to support an end-to-end spoken loop, not just
buttons or Apple Speech fallback.
**Rule:** launch native voice mode with `POCKETDM_PIKA_STT_URL` pointing at the
local faster-whisper sidecar, keep isolated voice venv requirements synced on
startup, and route transcripts through `/api/assistant` before Pika TTS playback.

## 2026-06-15 — The native pet UI must be readable at a glance
User corrected that the expanded companion was failing accessibility because it
used too many tiny paragraphs and status strings.
**Rule:** the desktop overlay should feel like a game HUD: large chat text,
large voice controls, a few high-signal mission cards, and hidden detail in
journal views instead of dense always-visible microcopy.

## 2026-06-15 — Learn mode should not autoplay on navigation
User disliked the experience where clicking into learning produced mascot noise
and immediately played the phrase.
**Rule:** opening Learn or switching Spanish/Mandarin packs should update the
card quietly; phrase audio should play only from explicit lesson controls such
as `Hear`, `Slow`, or the repeat-after step.

## 2026-06-15 — Menu bar must be a reliable escape hatch
User needs a dependable way to see that the companion is live and close or
delete/reset it even when hover controls are hidden.
**Rule:** the menu-bar Pika item should expose short actions for Open Chat, Hide
to Pet, sound toggle, confirmed Delete Pet Data, and Quit Pika.

## 2026-06-15 — Pet-only launch needs a quiet grace period
User expects startup to show only the animated Pikachu, not immediate proactive
text bubbles.
**Rule:** suppress wellness and cheer bubbles briefly after native launch so the
first impression is pet-only; proactive care can resume after the user has had a
clean moment with the character.

## 2026-06-15 — Codex-authored commits must use the Codex identity
User corrected that commits made from the Codex app/server were showing their
personal Git author.
**Rule:** keep both global and repo-local Git identity set to
`Codex <codex@local>` before making Codex-authored commits; existing commits
need explicit amend/rewrite if their historical author must change.

## 2026-06-15 — Parallel work should run in waves
User corrected that the hackathon push was not using enough subagents or
parallelism.
**Rule:** when the user asks for a swarm, immediately launch the maximum useful
bounded wave the platform allows, keep write ownership disjoint, close completed
agents, and refill slots with the next independent lane instead of pretending a
literal unbounded number of agents can run at once.

## 2026-06-15 — Expanded pet UI must stay small and permission-safe
User corrected that the expanded Pikachu overlay was too large, too dense, and
blocking the macOS microphone permission button.
**Rule:** default expanded chat should show only pet, transcript, input, a game
style health bar, and one wellness prompt; routine/details belong behind a
reveal, and first-time voice capture should collapse before macOS permission
prompts appear.

## 2026-06-15 — Voice controls must not duplicate or clip
User corrected that the expanded overlay showed two `Send voice` buttons and
cropped the chat response text.
**Rule:** while recording, render exactly one send/stop voice control in the
active listening panel; quick actions should hide their voice button, and chat
text should truncate cleanly instead of using forced vertical sizing that clips
inside the bubble.

## 2026-06-15 — Voice controls should be icon-first, not a form
User corrected that `Send voice` copy made the pet feel like a form instead of
a desktop companion.
**Rule:** keep typed chat as the primary composer with normal Enter submit,
put realtime voice and one-turn STT behind icon-only controls, center the pet,
and show a 3000-point game health bar above the pet that decays over time and
recovers when the user completes check-ins or care actions.

## 2026-06-15 — Pika voice must prove the whole chain
User corrected that hearing only `Pika Pika` is not enough; the product must
show where STT, LLM, and TTS succeed or fail.
**Rule:** every voice/debug pass needs a visible chat transcript, transcript
status while listening/transcribing/thinking/speaking, and an explicit backend
test that sends text to `/api/assistant`, generates Pika TTS audio, and uploads
that audio through the STT/ASR endpoints before claiming the flow works.

## 2026-06-15 — Nemotron ASR should be local-first
User corrected that Nemotron ASR should not be framed as requiring an NVIDIA API
key when the hackathon goal is to run the pulled local model.
**Rule:** treat `nvidia/nemotron-speech-streaming-en-0.6b` as a local
NeMo/Nemotron ASR backend first, hosted NIM as optional, and faster-whisper as a
visible fallback; expose latency metrics (`audio_ms`, `asr_request_ms`, `rtfx`,
fallback status) before calling the path realtime.
