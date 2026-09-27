---
name: music-classroom-mini-game
description: Design, build, and verify classroom-ready music mini-games from a concrete music-learning objective. Use for junior-high or general music lessons when the game must embody real musical structure, run reliably as a single offline HTML file, support touch/projector use, and provide pedagogically meaningful feedback rather than decorative gamification.
---

# Music Classroom Mini-Game Skill

## 1. Mission

Turn a **specific music-learning objective** into a **short, playable classroom interaction** in which the student's action is direct evidence of listening, rhythm, structural understanding, coordination, or creative decision-making.

The game is not a decorative quiz layered on top of music. The interaction itself must represent the musical idea being taught.

This skill was abstracted from two successful classroom patterns:

- **Compare → Create → Re-listen → Explain**: a rhythm-composition game in which legal rhythmic cells are data, students alter beat-level structure, hear the result, compare it with a model, and receive rule-based musical analysis.
- **Track → Hit/Hold → Judge → Replay**: a performance-listening game in which score/audio events are converted to timed data, visual objects are synchronized to audio, distinct gestures map to distinct musical roles, and timing/continuity receive immediate feedback.

The skill must generalize beyond those two games.

---

## 2. Non-negotiable principles

1. **Pedagogy before mechanics.** Define what the student should hear/do/understand before choosing a game type.
2. **Musical truth before UI.** Build a verified music-data model before drawing notes, blocks, lanes, meters, or choices.
3. **One main learning variable per mini-game.** Do not mix rhythm, form, timbre, dynamics, history, and technique unless the lesson explicitly needs an integrated challenge.
4. **Student action must reveal learning.** A click that merely advances a slide is not a game action.
5. **Feedback must explain music, not only score behavior.** “Correct” is insufficient when the lesson target is conceptual.
6. **Real work excerpts stay connected to the original work.** If a simplified/synthesized model is used, state that it is a teaching model and provide a re-listen step when source audio is available.
7. **Offline-first by default.** A classroom game should not fail because Wi-Fi, CDN, fonts, analytics, or APIs are unavailable.
8. **Touch-first interaction.** Pointer events, large targets, no hover-only controls, no right-click dependency.
9. **Audio synchronization uses audio time as the master clock.** Do not drive a rhythm game from animation timing alone.
10. **Ship only after run-time verification.** Static code inspection is not enough.

---

## 3. Input brief

Before building, resolve these fields from the user's request and supplied materials. Do not ask for fields that can be safely inferred from the lesson context or source files.

```yaml
lesson:
  grade: "e.g. 初一 / 初三"
  work_or_topic: "piece, song, rhythm concept, orchestration topic..."
  class_minutes: 45
  game_minutes: 3-8
learning:
  target: "single observable musical objective"
  evidence: "what the student must do to prove it"
source:
  score_or_event_data: "optional"
  audio: "optional"
  excerpt: "bars/time range if relevant"
classroom:
  devices: "teacher computer/projector, student phone, touch screen..."
  orientation: "landscape preferred / portrait allowed"
  network: "assume unavailable unless stated"
output:
  format: "single offline HTML by default"
  language: "Chinese by default for Chinese lesson"
constraints:
  copyright_or_source_limits: "if any"
  visual_style: "optional"
```

### Rewrite the target as an observable objective

Bad: “让学生感受节奏。”

Good: “学生能在两次聆听后指出三拍子第一拍的重心，并听辨拍内细分改变后步伐感的变化。”

Bad: “认识《革命练习曲》。”

Good: “学生能通过左手连续轨迹与右手触击，体验第9—14小节两手在速度、运动方向和节奏角色上的差异。”

---

## 4. Game-router: choose mechanics from evidence

Choose the **smallest mechanic that produces the required learning evidence**.

| Learning evidence | Default archetype | Core interaction | Typical feedback |
|---|---|---|---|
| Compare two musical treatments | Compare–Create–Explain | A/B audition → C manipulation → A/B/C compare | musical-feature explanation |
| Create a legal rhythm/melody/form | Constraint Composer | choose/drag legal cells | rule validity + musical consequence |
| Identify a heard feature | Listen–Discriminate | play → choose location/category | correct reveal + why |
| Follow a temporal/pitch contour | Track–Hit–Hold | falling/approaching objects, tap/hold/slide | timing + continuity |
| Separate musical roles/voices | Multi-role Performance | different gestures/colors/lanes | role-specific accuracy |
| Recognize formal order | Sequence–Arrange | drag/reorder sections/cards | structural explanation |
| Match motif/phrase | Pair/Match | listen → pair or sort | motif-feature explanation |
| Reproduce a short pattern | Call–Response | hear → tap/enter | onset/interval/rhythm comparison |

### Routing rules

- If the learning evidence is **explanation/contrast**, prefer Compare–Create–Explain over a score-chasing game.
- If the learning evidence is **timing, continuity, hand/voice differentiation**, prefer Track–Hit–Hold.
- If the student only needs to **identify one feature**, do not build a complex canvas game; a fast Listen–Discriminate game is better.
- If the task is **creative**, encode constraints so students cannot accidentally create musically invalid answers unless “error diagnosis” is the objective.
- Use scoring only when repeated performance is pedagogically useful. Concept-comparison games may not need points.

---

## 5. Build the musical truth model first

### 5.1 Rhythm model

Represent a beat-cell by normalized onset positions within one beat.

```js
const RHYTHM = {
  quarter: {name:'一拍', on:[0], beats:1, density:1},
  eighths: {name:'二八', on:[0,.5], beats:1, density:2},
  four16:  {name:'四十六', on:[0,.25,.5,.75], beats:1, density:4},
  eSS:     {name:'前八后十六', on:[0,.5,.75], beats:1, density:3},
  SSe:     {name:'前十六后八', on:[0,.25,.5], beats:1, density:3},
  triplet: {name:'三连音', on:[0,1/3,2/3], beats:1, density:3},
  sync:    {name:'小切分', on:[0,.25,.75], beats:1, density:3}
};
```

For a fixed meter, enforce duration mathematically. Example for 3/4: three one-beat cells must sum to exactly 3 beats. Never rely on visual appearance alone.

### 5.2 Timed score/event model

For work-excerpt interaction, use explicit event data:

```js
const DATA = {
  duration: 10.2,
  left_guides: [
    {bar: 9, points:[{t:0.05,pitch:36},{t:0.79,pitch:63},{t:1.43,pitch:43}]}
  ],
  right_events: [
    {bar:10,t:2.56,pitches:[72,84],pitch_center:78}
  ]
};
```

Required properties as relevant:

- `t`: onset time in seconds relative to game excerpt
- `duration`: note/event duration when needed
- `pitch` or `pitch_center`: MIDI-like or normalized pitch
- `bar`: measure number
- `hand`, `voice`, `instrument`, `section`: role identity
- `source_event`: optional traceability back to extracted source

### 5.3 Musical claims

Every explanatory sentence must be one of:

- directly supported by the score/audio/material supplied by the user;
- a clearly labeled teaching simplification;
- a general music-theory explanation that does not falsely claim a work-specific fact.

Do not invent “typical rhythm”, orchestration, bar numbers, formal sections, or expressive intent when the source does not support them.

---

## 6. Map music to interaction

Write an **interaction mapping table** before coding.

Example:

| Musical object | Screen object | Student action | Meaning of success |
|---|---|---|---|
| left-hand continuous line | connected blue blocks | press first block + hold/slide | follows contour without breaking |
| right-hand attack | orange block | single tap near hit line | hears/anticipates attack timing |
| beat cell | rhythm card | choose for beat slot | creates legal one-beat content |
| syncopated beat | hidden heard pattern | choose beat 1–4 | detects metric displacement |

Rules:

- Do not assign two unrelated gestures to the same musical role.
- Distinct musical roles may use distinct gesture/color/side **only if that distinction supports the lesson objective**.
- Target sizes should be forgiving enough for classroom touch use.
- Avoid pixel-perfect tapping as the learning objective unless motor precision itself is being taught.

---

## 7. Feedback architecture

Use up to three layers.

### Layer A — immediate operational feedback

Examples: `PERFECT`, `GOOD`, `MISS`, selected slot, correct/incorrect flash.

### Layer B — musical feedback

Explain the variable the learner changed/heard:

- metric weight
- beat subdivision/density
- syncopation/displacement
- contour
- register
- role/voice
- texture
- timbre
- dynamics
- phrase/form

### Layer C — re-listen/transfer

Return to the original work or compare a model with the original. Ask the student to listen for the same feature again.

**Do not call deterministic rule text “AI” unless the user explicitly wants that classroom label.** If displayed as “AI点评”, the implementation may still be offline rules, but the footer should state that clearly.

---

## 8. Technical implementation patterns

### 8.1 Default deliverable

Unless the user asks otherwise, deliver **one self-contained `.html` file** that can be opened by double-click.

- Inline CSS and JavaScript.
- Embed small required audio/image assets as `data:` URIs when licensing/source permits.
- Prefer Web Audio synthesis for metronome/rhythm-model sounds.
- No CDN, Google Fonts, analytics, external APIs, or network fetches.
- Include `<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">`.

### 8.2 Audio

Browser audio must start from a user gesture.

For generated rhythm sounds:

```js
let audioCtx;
function ensureAudio(){
  if(!audioCtx) audioCtx = new (window.AudioContext||window.webkitAudioContext)();
  if(audioCtx.state==='suspended') audioCtx.resume();
}
```

For excerpt-synchronized games, use `<audio>.currentTime` as time source:

```js
function gameTime(){
  return audio.currentTime - PRE_ROLL;
}
```

Do not use `setInterval` as the authoritative music clock.

### 8.3 Animation loop

Use `requestAnimationFrame` for visuals and process hit/miss state from the audio time.

### 8.4 Pointer input

Use Pointer Events so mouse and touch share the same code.

```js
canvas.addEventListener('pointerdown', onDown);
canvas.addEventListener('pointermove', onMove);
canvas.addEventListener('pointerup', onUp);
canvas.style.touchAction = 'none';
```

Convert client coordinates into the game's logical coordinate system when a fixed canvas is scaled.

### 8.5 Two responsive strategies

**DOM/responsive layout** — preferred for compare, creation, sorting, quizzes.

**Fixed logical stage + CSS scale** — preferred for timing/canvas games:

```js
function fitFrame(){
  const s=Math.min(innerWidth/1280,innerHeight/720);
  frame.style.transform=`scale(${s})`;
}
```

Never distort the x/y ratio independently.

### 8.6 Timing judgment

Use tolerance windows appropriate to age, device latency, and game purpose. A reasonable starting structure is:

```js
if (diff < perfectWindow) PERFECT;
else if (diff < goodWindow) GOOD;
else MISS;
```

Do not blindly reuse fixed values from another piece. Tune using the excerpt tempo and real device tests.

### 8.7 State reset

Every restart/mode change must reset:

- audio position and pause state
- score/combo/hits/misses
- handled-event sets
- active holds/pointers
- animation frame
- result overlay
- temporary feedback

A “restart” that leaves stale handled events is a failed build.

---

## 9. Required workflow

### Step 1 — Define the learning contract

Write internally:

- **Target:** what musical idea?
- **Evidence:** what student action proves learning?
- **Transfer:** what should they hear differently when returning to the work?

If these three lines are unclear, do not code yet.

### Step 2 — Choose the archetype

Use the router in §4. Prefer the simplest viable mechanic.

### Step 3 — Build/verify source data

For rhythm: verify beat sums.

For score/audio: verify bar numbers, event times, pitch/voice assignments, excerpt duration, and audio alignment.

For work-specific interpretation: separate source fact from pedagogical inference.

### Step 4 — Draft a 60-second classroom loop

The game must be explainable in one short instruction and should reach the core interaction quickly.

A good loop often looks like:

`listen → act → immediate feedback → musical explanation/reveal → replay/next`

or

`model A → model B → student C → compare → explain → return to original`

### Step 5 — Implement offline-first HTML

Use semantic labels, large controls, clear state, and touch-safe input.

### Step 6 — Add musical feedback

Feedback must mention the actual target feature. Avoid generic praise text.

### Step 7 — Add classroom controls

At minimum when relevant:

- start/play
- replay
- restart
- mode selector
- next round
- result summary

The teacher must be able to recover from accidental taps without reloading the page.

### Step 8 — Static validation

Check:

- no external dependencies
- all referenced DOM IDs exist
- all buttons/functions resolve
- no illegal rhythm-duration combinations
- source event IDs/times are internally consistent
- no missing asset URI
- viewport present

### Step 9 — Real browser run

Open in Chromium/WebKit-compatible browser and perform the main path.

Required run-time checks:

1. page loads with zero uncaught console errors;
2. first user gesture unlocks/starts audio;
3. every visible primary button responds;
4. restart clears state;
5. touch-sized controls remain usable at mobile width;
6. no unwanted horizontal overflow;
7. game reaches a feedback/result state;
8. no network requests are required;
9. music rule self-tests pass;
10. if timing game: at least one success and one miss path are tested.

### Step 10 — Ship with a concise QA note

Report what was actually tested. Do not say “tested” when only source code was inspected.

---

## 10. Acceptance gate

A generated game is **READY** only if all critical gates pass.

### A. Musical correctness — critical

- [ ] target feature is accurate
- [ ] beat/meter math is valid
- [ ] event timing/order is valid
- [ ] work-specific claims are source-grounded
- [ ] simplified model is labeled as such

### B. Pedagogical alignment — critical

- [ ] core action demonstrates the learning target
- [ ] feedback names the musical consequence
- [ ] game can be explained in under ~30 seconds
- [ ] a replay/re-listen/transfer path exists when appropriate

### C. Runtime — critical

- [ ] no uncaught JS errors
- [ ] start/restart works
- [ ] audio works after user gesture
- [ ] no network dependency
- [ ] main interaction reaches completion

### D. Classroom usability

- [ ] large touch targets
- [ ] readable on projector
- [ ] usable on phone/tablet width
- [ ] clear current state
- [ ] no accidental page scrolling during gesture-heavy play

### E. Game quality

- [ ] challenge is not dominated by UI dexterity unrelated to music
- [ ] scoring, if present, supports retry rather than distracting from listening
- [ ] visual distinctions correspond to musical distinctions
- [ ] replay time is short enough for class use

If any critical item fails, revise and rerun.

---

## 11. Failure patterns to reject

Reject or rebuild when any of these appear:

- “音乐游戏” is just multiple-choice trivia about composer dates.
- beautiful animation but no measurable musical action.
- impossible/incorrect rhythm values accepted by the composer.
- falling blocks not synchronized to actual audio.
- scoring depends on `performance.now()` while audio drifts separately.
- mouse-only event handling.
- external assets required despite an offline deliverable.
- tiny buttons or hover-only instructions.
- “AI点评” is generic praise unrelated to student choices.
- source excerpt is simplified but presented as exact notation/performance.
- restart retains previous hits or score.
- auto-play is assumed without a user gesture.

---

## 12. Output contract for an agent using this skill

For each build, produce these internal artifacts in order:

1. `learning_contract` — target/evidence/transfer
2. `game_route` — selected archetype and why
3. `music_truth_model` — rhythm cells or timed events + validation
4. `interaction_mapping`
5. playable single-file HTML
6. browser QA result

User-facing delivery should normally include only:

- the finished HTML link/file;
- one sentence explaining the classroom use;
- a short QA statement.

Do not burden the teacher with implementation details unless requested.

---

## 13. Minimal reusable data contracts

### Constraint composer

```js
const GAME = {
  meter: {beats:3, unit:4},
  beatSeconds:.72,
  cells: RHYTHM,
  referenceA:['quarter','quarter','quarter'],
  referenceB:['eSS','eighths','eighths'],
  student:['quarter','eighths','eighths']
};
```

Validation:

```js
function validateBar(cells){
  return cells.reduce((n,key)=>n+GAME.cells[key].beats,0)===GAME.meter.beats;
}
```

### Timed interaction

```js
const GAME = {
  duration: 10.2,
  travel: 2.2,
  preRoll: 1.5,
  roles: {
    left: {gesture:'hold-slide', events:[]},
    right:{gesture:'tap', events:[]}
  }
};
```

Each event must be handled exactly once by `hit`, `miss`, or intentional ignore logic.

---

## 14. Final design heuristic

When uncertain, ask one internal question:

> **If I remove the points, colors, and animation, does the student's required action still embody the musical concept?**

If the answer is no, redesign the game.
