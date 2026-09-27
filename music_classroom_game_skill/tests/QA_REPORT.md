# QA Report — music-classroom-mini-game

## What was tested

The Skill was validated in three layers:

1. **Source-pattern smoke test** on the two classroom games from which the Skill was abstracted.
2. **Generation test**: a new game, `G3_小切分侦探_单文件网页版.html`, was created using the Skill workflow rather than copying either source game.
3. **Runtime + visual QA** in headless Chromium at desktop and mobile viewports.

> Note: this execution environment blocks browser navigation to `file://` and localhost URLs. The validator therefore injects the complete self-contained HTML into a real Chromium page with `page.set_content()`. JavaScript, Web Audio, layout, interactions, state changes, and network requests are still executed/observed in Chromium. The deliverable itself remains a standalone HTML file.

## G1 source smoke test

- 6 beat-cells in reference A and 6 in reference B loaded.
- 3 editable student beat slots loaded.
- 9 legal rhythm choices loaded.
- Normalized onset values passed legality check.
- “随机生成合法C版” changed the student pattern.
- Clicking reference playback moved the Web Audio context to `running`.
- No uncaught browser errors.
- No external network requests.

**Result: PASS**

## G2 source smoke test

- 6 left-hand guide groups loaded.
- 17 right-hand timed events loaded.
- Excerpt duration read as `10.160431s`.
- Logical canvas size: `1280×720`.
- Mode switch to left-hand practice worked.
- Start button set the game to running, hid the start overlay, and started audio.
- Restart reset `started=false`, score/combo/hits/misses to zero, and restored the start overlay.
- No uncaught browser errors.
- No external network requests.

**Result: PASS**

## G3 generation test

### Musical rule self-test

- Every rhythm cell onset lies inside one beat.
- 100 generated questions were sampled; every question contained exactly one syncopated beat and the stored answer pointed to it.
- Round count = 6.

**Result: PASS**

### Interaction test

- Play button started Web Audio (`running`).
- Correct answer awarded 100 points and enabled “下一题”.
- Six consecutive correct rounds reached the result screen with 600 points.
- Wrong-answer path revealed both the correct beat and the selected wrong beat.
- Restart/new-round flow worked.

**Result: PASS**

### Responsive / offline test

- Desktop viewport: `1280×720`; horizontal overflow = 0 px.
- Mobile viewport: `390×844`; horizontal overflow = 0 px.
- Minimum visible button height on mobile = 52 px.
- No uncaught browser errors.
- No external network requests.
- Visual screenshots were inspected: controls, text, answer grid, rhythm reveal, and feedback were readable with no clipping or overlap.

**Result: PASS**

## Final gate

**READY** — The Skill is operational, its two source patterns were reproduced correctly at the architectural level, and a third independent game type was generated and run successfully.
