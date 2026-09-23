# Not Tetris 2 — Browser Hosting Plan

## Context

Not Tetris 2 is a single-codebase LÖVE 11.5 desktop game with three modes (single-player gameA, single-player gameB, local two-player gameBmulti). The goal is to ship a **browser-playable, online version of the `gameBmulti` mode**, hosted for free-tier playtesting with friends. The intended end state is: one friend clicks "Create Room," gets a 4-character code, shares it out-of-band; the other friend clicks "Join Room," enters the code, and both play a real `gameBmulti` match, **each on their own computer, each using the single-player controls** (arrows + Z/X — the layout they have muscle memory for from `gameB`).

Note on controls: desktop `gameBmulti` shares one keyboard between two players, so it uses different keys per side — P1 = A/D/S + G/H, P2 = arrows + keypad 1/2 (`gameBmulti.lua:361-418`). The `leftp2`/`rightp2`/… bindings in `controls.lua` are not read by `gameBmulti` at all. In the browser build every player has their own keyboard, so both use the single-player layout instead; the desktop multiplayer keys are not used.

**This project lives in its own repository**, separate from the desktop LÖVE codebase. The Lua source is copied in, not modified in-place. This keeps the desktop game fully isolated and avoids any risk of breaking it.

Four user decisions frame the rest of the plan and are recorded up front so no later step has to revisit them:

1. **Runtime path** — use **`love.js`** (the Emscripten port of LÖVE, `Davidobot/love.js` fork) to run the Lua game inside the browser, plus a **Node WebSocket relay** that owns the multiplayer physics state. The Lua source is preserved end to end; no hand-port to JS/Canvas.
2. **Authoritative server (thin client).** The **relay server** runs the physics simulation for both fields using `planck.js` (a JavaScript Box2D port). Each browser tab sends key state and receives authoritative body snapshots. **Clients never simulate** — the entire input→force→physics→game-logic pipeline lives on the relay. The client is a pure renderer: it reads key state, sends it to the server, renders the bodies the server returns, and plays sounds on server events. This eliminates client/server drift and the Box2D-determinism rabbit hole. planck.js is a different implementation from LÖVE's bundled Box2D, so feel is expected to be *close*, not identical — see the unit-scaling rules in Phase 2 and the tuning note in Assumptions.
3. **Same controls for both players.** Each client reads its own keyboard through the existing `controls.lua` actions — `controls.isDown("left" | "right" | "down" | "rotateleft" | "rotateright")` — which already map to arrows, Z/Y/W (rotate left) and X (rotate right), exactly as single-player `gameB` does (`gameB.lua:248-269`). Every client sends the same logical action names. The **relay maps slot 1 → P1 field** and **slot 2 → P2 field** internally. Torque signs follow `gameB`: `rotateright` (X) → **+torque**, `rotateleft` (Z/Y/W) → **−torque**. No P2-specific bindings exist anywhere in the browser build.
4. **Create/Join room flow.** No manual P1/P2 selector. One player creates a room (server generates the code, creator is P1); the other joins with the code (joiner is P2). Slot assignment is implicit in create-vs-join order.

**Out of scope for this plan** (recorded inline so the implementer doesn't second-guess):
- gameA and gameB single-player browser builds — only `gameBmulti` is wired in this pass.
- **"Invade" mode (`gameno == 2`).** Only "stack" (`gameno == 1`, the default) is supported. Invade changes collision masks on landing (`gameBmulti.lua:748-751`, `772-775`) and lets pieces cross the centre; adding it later means adding a `mode` field to `create` and porting those two blocks.
- **Music selection.** The client plays the default `musicno = 1` (A-type). Music is purely client-side and can be made selectable later without touching the relay.
- Online matchmaking / lobby / accounts / chat. Players share a 4-character room code out-of-band.
- Replacing love.js with a hand port. love.js is the path; revisit only if a blocker surfaces.
- Mobile / touch input. Desktop browser keyboard only.
- In-game UI for room joining. Room code entry happens in JS before the game loads.
- Client-side prediction. The thin client renders server snapshots directly. If the 30 Hz snapshot rate looks choppy, the implementer adds linear interpolation between the last two snapshots (visual smoothing only, no physics). This is the only sanctioned smoothing — note it does **not** reduce input latency (see Assumptions → latency).

## Approach

The work is structured as **four ordered phases**, each leaving the system in a runnable state. Later phases depend on earlier ones.

### Phase 1 — Package the LÖVE build for the browser (`web/`)

**Goal:** produce a `web/` directory that, when served by any static host, runs the game in a browser — starting from a pre-game room-create/join form rather than the standard title screen.

1. **Create the project skeleton** in a new standalone repository. The Lua source files are copied from the desktop repo into `src/` (preserving the flat root layout LÖVE expects). The `web/` directory contains the host page plus the love.js build output.
   - `web/index.html` — host page with two modes: (a) a pre-game form with Create Room / Join Room buttons, room-code display/input; (b) the love.js canvas (hidden until the match is made). Hand-written; replaces the `index.html` love.js generates.
   - `web/love.js`, `web/love.wasm`, `web/game.js`, `web/game.data`, `web/theme/` — build artifacts produced by the love.js packager (`game.js` is the Emscripten file-packager loader, `game.data` is the packed game). **Generated; do not hand-edit.**
2. **Add the build script** at the repo root as `build_web.sh` (single shell script; no new build system). It:
   - Zips `src/` (`main.lua`, `conf.lua`, `controls.lua`, `failed.lua`, `gameA.lua`, `gameB.lua`, `gameBmulti.lua`, `gameBmulti_net.lua`, `gameBdebug.lua`, `menu.lua`, `rocket.lua`, `dkjson.lua`, `graphics/`, `sounds/`) into `build/game.love` with files at the archive root.
   - Runs the love.js packager from npm: `npx love.js@<pinned-version> -c -t "Not Tetris 2" build/game.love build/web-out`. `Davidobot/love.js` ships a **prebuilt** runtime in its npm package — there is no clone-and-Emscripten-compile step.
   - Copies everything from `build/web-out/` **except** its `index.html` into `web/`.
   - **Decision — compatibility mode (`-c`).** The default (threaded) build needs `SharedArrayBuffer`, which requires `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` headers. `python3 -m http.server` does not send them. Compatibility mode runs single-threaded on the main thread, needs no special headers, and also makes the MEMFS bridge (Phase 3) race-free because JS and Lua never run concurrently.
   - **Decision — tool version pinning:** the script pins the love.js npm version in one variable at the top of the file. This is the only place versions live. **Verify first:** the Davidobot fork has historically tracked LÖVE **11.4.x**, not 11.5. The 11.4 → 11.5 differences are bugfixes and this game should run on either, but confirm the version you pin and note it in the script comment.
3. **Pre-game room-create/join form.** `web/index.html` displays a form before the love.js canvas loads. Two modes:
   - **Create Room:** Client opens a WebSocket to `NT2_RELAY_URL` and sends `{"type":"create"}`. Server generates a random 4-char alphanumeric code, creates a `Room`, assigns the creator to slot 1, and replies `{"type":"created","room":"ABCD","slot":1}`. The form displays: "Room code: **ABCD** — share this with your friend," then "Waiting for P2...".
   - **Join Room:** Client shows a 4-char code input. On submit, opens the WebSocket and sends `{"type":"join","room":"XXXX"}`. Server assigns the joiner to slot 2.
   - When both slots are filled, the server sends `{"type":"matched","room":"XXXX","slot":1|2}` to each client. On `matched`, JS writes the room/slot file (see Phase 3 step 7), hides the form, and starts love.js via `Love(Module)`. **`matched` only launches love.js — it does not start the countdown.** love.js takes several seconds to download and boot, and that time differs per machine; the countdown is started later by the `ready` handshake (Phase 2).
   - The Create/Join button click is also the user gesture that unlocks browser audio, so love.js sound works once the game starts.
   - **Error handling:** If the room doesn't exist (join), or is full, or the code is invalid, the server replies `{"type":"error","message":"..."}` and the form shows the error inline. The user can retry without refreshing.
   - The form is vanilla HTML/CSS/JS. No framework.
4. **Relay URL.** One constant block at the top of `web/index.html`:
   ```js
   const NT2_RELAY_URL = location.hostname === "localhost" || location.hostname === "127.0.0.1"
     ? "ws://localhost:10000"
     : "wss://not-tetris-2-relay.onrender.com";
   ```
   This is the only place the relay hostname lives. It is not a secret.

**Bootstrap ordering note:** The WebSocket connection to the relay is established by the form JS *before* love.js starts. The same connection is reused for the in-game input/state stream — JS holds the `WebSocket` object and bridges it to Lua via MEMFS (see Phase 3). This avoids a second connection after the game boots. Messages that arrive between `matched` and Lua's first poll are queued by JS (Phase 3 step 8), so nothing is lost during boot.

**Acceptance / done means:** running `bash build_web.sh` from the repo root produces the `web/` directory; serving it with `python3 -m http.server -d web 8000` and opening `http://localhost:8000` shows the Create/Join form. Creating a room displays a code; joining with the code from a second browser window transitions both windows to the love.js canvas with no console errors. **First smoke check inside love.js:** confirm Lua's `io.open` can read a file JS wrote to MEMFS (the bridge in Phase 3 depends on it).

### Phase 2 — Establish the relay server (`relay/`)

**Goal:** a standalone Node service that owns the multiplayer physics and game state and exposes a WebSocket endpoint.

5. **Add `relay/package.json`** declaring the runtime (Node 20+), two dependencies (`ws` for WebSockets, `planck` for physics — the package was formerly published as `planck-js`; pin whichever is current), and one script (`npm start`). No TypeScript, no build step — keep this boring.
6. **Implement `relay/server.js`** with these pieces:
   - **Room registry.** An in-memory `Map<roomCode, Room>` where `roomCode` is a 4-character alphanumeric string the server generates on `create`. `Room` holds: the two sockets (`p1`, `p2`), each slot's `ready` flag and latest input (+ timestamp), the `planck.World`, the per-player body maps, wall fixtures, the shared `randomtable` (piece sequence), `counterp1`/`counterp2`, scores, lines, fail flags, `p1wins`/`p2wins` (persist across rematches), `winner`, and the current phase (`waiting`, `loading`, `countdown`, `playing`, `failing`, `failed`, `results`). There is intentionally **no persistence** — if the server restarts, rooms vanish. That's correct for playtesting.
   - **Room lifecycle.** When either socket closes, the server sends `{"type":"event","kind":"opponent_left"}` to the other client and deletes the room. Rooms still in `waiting` are deleted after 10 minutes. The server loop only ticks rooms whose phase is `countdown` or later.
   - **Physics core — `planck.js`.** Recreate the world from `gameBmulti.lua:67-119`. **Unit scaling is mandatory.** LÖVE converts every pixel quantity to metres by dividing by the meter (default 30; the game's `meter = 30` global is never passed to `setMeter`, it just matches the default) before handing it to Box2D. planck.js does no scaling. Without it, Box2D's 2-units-per-step translation cap limits speed to ~120 px/s at 60 Hz, and every slop/tolerance is off by 30×. The relay therefore defines `M = 30` and converts at the boundary:
     - positions, shape vertices, rectangle offsets/sizes: `px / M`
     - linear velocity: `px/s / M`; gravity `(0, 500 / M)`
     - forces: `F / M`; torque: `T / (M * M)`
     - angles and angular velocity: unscaled
     - density: unscaled (`0.1`, the `density` global from `main.lua:168`) — LÖVE passes density straight through, so mass comes out in the same units as desktop
     - snapshots multiply positions/velocities back by `M` so the client keeps working in desktop pixel coordinates.
   - **Collision filtering translation.** LÖVE's `setCategory(n)` and `setMask(n)` take bit *indexes* (1-16); planck takes raw bitfields. Category `n` → `filterCategoryBits = 1 << (n-1)`; `setMask(a, b)` → `filterMaskBits = 0xFFFF & ~(1<<(a-1)) & ~(1<<(b-1))`. Fixtures that never call `setCategory` are category 1; fixtures that never call `setMask` collide with everything. Concretely: `rightp1` is category 2, `leftp2` is category 3, P1 pieces mask out 3, P2 pieces mask out 2, everything else is default.
   - **Bodies.** Three wall fixtures per side on one static body per side (left wall, right wall, ground), with the same polygon vertices, friction `0.0001` on the side walls, and the user-data strings (`leftp1`, `rightp1`, `groundp1`, …). Tetromino bodies use the same `newRectangleShape` offsets as `createtetriBmultip1`/`p2`, `density = 0.1`, `setLinearDamping(0.5)`, `setBullet(true)`, user data `"p1-"..id` / `"p2-"..id`, and the masks above. Sleeping allowed (desktop `newWorld(0, 500, true)`).
   - **Fixed timestep.** Desktop calls `world:update(dt, 8, 3)` with a variable `dt`. The relay steps at a fixed `1/60` s with 8 velocity / 3 position iterations, and uses the same `1/60` as `dt` in the air-brake formula.
   - **Tuning constants.** The `debug_params` values are embedded as JS constants and applied verbatim in the input handler. **Copy them from the `options.txt` of the machine you playtest desktop on** (the `debug_<key>=` lines), because that is the feel you're used to. The code defaults (`main.lua:601-610` / `618-627`) are `difficulty_speed=100, lateral_force=400, rotation_torque=3400, angular_cap=12, soft_drop_force=1500, soft_drop_cap_mul=4, air_brake_coeff=2000`.
   - **Game logic.** The relay runs the full `gameBmulti` state machine, ported from the Lua:
     - **Handshake + countdown.** After `matched`, the room is in `loading`. Each client sends `{"type":"ready"}` once `gameBmulti_load` has finished. When both are ready, the server enters `countdown`, broadcasts `{"type":"event","kind":"countdown"}`, and after 3 s calls `startgame()` and enters `playing`. Clients set `starttimer` on receipt of `countdown` and draw the 3-2-1 + beeps locally from that (`gameBmulti.lua:141-152`, `338-357`); the server does not send per-second ticks. The ±RTT/2 skew between the two clients' countdowns is acceptable.
     - **Piece sequence.** The relay owns `randomtable` and seeds `randomtable[1]` when entering `countdown`. Clients never call `math.random` for pieces. P1's next piece is the mirrored value (2↔3, 5↔7) as in `startgame` / `game_addTetriBmultip1`; P2's is unmirrored.
     - **Spawn.** `game_addTetriBmultip1` / `p2` logic: increment counter, create the body at `(388, blockstartY=-64)` (P1) or `(708, -64)` (P2) with linear velocity `(0, difficulty_speed)`, extend `randomtable` if needed, compute the next piece.
     - **Collision / endblock.** planck's `begin-contact` handler inspects fixture user data exactly as `collideBmulti` does and only sets `endblock1` / `endblock2` flags — **the world is locked inside contact callbacks**, so, as on desktop, the actual `endblockp1`/`p2` work runs after `world.step()` returns. Port `collideBmulti` **faithfully, including the original typo** on `gameBmulti.lua:730` (`b == "p1-"..counterp1 and b ~= …` — the second `b` should be `a`). In stack mode the centre walls keep P1 and P2 pieces apart, so the typo is effectively unreachable; fix it only if invade mode is added. `endblockp*`: if the settled piece's Y is above `losingY = 0`, set `p*fail` and emit `playerfailed`; otherwise increment `linesscorep*`, set `scorescorep* = lines * 100`, emit `piecelanded`, and spawn the next piece.
     - **Game over requires both players to fail.** `endgame()` runs only when the second player tops out (`gameBmulti.lua:759`, `782`); until then the surviving player keeps playing alone. `endgame()` picks the winner by score (1, 2, or 3 = draw), updates `p1wins`/`p2wins` (mod 100), enters `failing`, and emits `gameover`.
     - **Failing → failed → results.** After `colorizeduration = 3` s in `failing`, the server destroys both ground fixtures, enters `failed`, and emits `clearing`. In `failed` it waits until every piece's Y is ≥ **648** (desktop checks `162 * mpscale`, `gameBmulti.lua:445` — a display-scale-dependent threshold in physics coordinates; 648 is its value at `mpscale = 4`), then builds the results floor and the winner's Mario (`388, 320`, 64×108, mask 3) or Luigi (`704, 320`, 64×124, mask 2) body as in `gameBmulti.lua:463-494`, enters `results`, and emits `results`.
     - **Results phase.** The server applies the jump impulse every 2 s and resets `jumpframe` on contact with `resultsfloor`, as in `gameBmulti.lua:497-511` / `738-743`. The **winner's** `left`/`right` input pushes their character (`±30` force at `worldCenter.y - 8`, `gameBmulti.lua:519-537`); the loser's input is ignored. The `cryframe` toggle is purely visual and stays client-side.
     - **Rematch.** In `results`, a client may send `{"type":"rematch"}`. When both have, the server rebuilds the world (keeping `p1wins`/`p2wins`), enters `countdown`, and broadcasts `countdown`.
   - **Input handling.** The relay stores each slot's latest `input` frame with a receive timestamp. Each tick, inputs older than **250 ms** are treated as all-false — this stops a held key from sticking if a tab is hidden, loses focus, or stalls. Clients also send an all-false frame on `blur`/`visibilitychange` (Phase 3). In `playing`, slot 1's input drives `tetribodiesp1[counterp1]` and slot 2's drives `tetribodiesp2[counterp2]` with the exact force/torque/soft-drop/air-brake logic from `gameBmulti.lua:360-430`, skipped for a slot whose `p*fail` is set. This mapping is the **only** place slot identity matters for input.
   - **Wire protocol.** WebSocket JSON messages. Server is the single source of truth; clients only send inputs/intent and read snapshots/events.
     - Client → Server:
       - `{"type":"create"}` — create a room. Reply: `created`.
       - `{"type":"join","room":"XXXX"}` — join a room. Reply: `matched` to both, or `error`.
       - `{"type":"ready"}` — Lua has finished `gameBmulti_load`; sent once per boot.
       - `{"type":"input","keys":{"left":bool,"right":bool,"down":bool,"rotateleft":bool,"rotateright":bool}}` — current key state, sent every client frame. **No `harddrop` field** — the game has no hard-drop mechanic.
       - `{"type":"rematch"}` — sent from the results screen (Return key).
     - Server → Client:
       - `{"type":"created","room":"XXXX","slot":1}`
       - `{"type":"matched","room":"XXXX","slot":1|2}` — both slots filled; clients launch love.js.
       - `{"type":"state","phase":"...","p1":{"bodies":[{"id":N,"kind":K,"x":…,"y":…,"angle":…}],"score":N,"lines":N,"nextpiece":N|null,"fail":bool},"p2":{…},"winner":1|2|3|null,"p1wins":N,"p2wins":N,"mario":{"x","y","angle"}|null,"luigi":{…}|null,"jumpframe":bool}` — authoritative snapshot of **both fields**, sent at 30 Hz from `countdown` onward. Both fields are included because `gameBmulti_draw` (`gameBmulti.lua:127-316`) renders P1 and P2 side by side. **`kind` is always included** (it's one small integer) so the client can build a piece's image the first time it sees an id without depending on having seen any earlier frame. Mario/Luigi are **separate fields**, not entries in the body arrays — the draw loop indexes `tetriimagesp*[i]` / `tetrikindp*[i]` by body id and would crash on them. Velocities are omitted: the client doesn't simulate, and interpolation (if added) only needs positions.
       - `{"type":"event","kind":"countdown"}` — start the local 3-2-1 and set `starttimer`.
       - `{"type":"event","kind":"piecelanded","slot":1|2}` — play `blockfall.ogg`. Both clients play it for both fields, matching desktop, where one window shows both fields. (The game has no line-clear sound; `linesscorep*` counts pieces landed.)
       - `{"type":"event","kind":"playerfailed","slot":1|2}`
       - `{"type":"event","kind":"gameover","winner":1|2|3}` — client stops music, plays `gameover1`, sets `colorizetimer`, enters `failingBmulti`.
       - `{"type":"event","kind":"clearing"}` — client plays `gameover2`, enters `failedBmulti` (the ground is gone; pieces fall out in the snapshots).
       - `{"type":"event","kind":"results"}` — client plays `musicresults`, enters `gameBmulti_results`.
       - `{"type":"event","kind":"opponent_left"}` — client shows "Opponent disconnected" and returns to the form (page reload is fine).
       - `{"type":"error","message":"..."}` — protocol / room errors.
7. **Add `relay/render.yaml`** (Render Blueprint) describing a free-tier web service: `runtime: node`, `buildCommand: npm install`, `startCommand: npm start`, and a `region` close to the players (latency matters — see Assumptions). The PORT env var is **not pinned** in the blueprint — Render sets it automatically. `server.js` reads `process.env.PORT || 10000`.

**Acceptance / done means:** `cd relay && npm install && npm start` brings up the server on `ws://localhost:10000`; opening two `wscat` connections, one sending `create` and the other `join` with the returned code, both sending `ready`, followed by a few `input` frames, yields a `countdown` event and then a `state` stream where pieces fall at roughly `difficulty_speed` px/s and move sideways under `left`/`right` input (a quick check that unit scaling is right).

### Phase 3 — Browser-side wrapper for `gameBmulti`

**Goal:** the running love.js instance, having received the room code and slot from the pre-game form, enters `gameBmulti` and renders the game purely from authoritative snapshots — with each player using arrows + Z/X on their own machine.

8. **Inject room code and slot into Lua at boot.** On `matched`, JS registers a `Module.preRun` hook that writes `/nt2_room.txt` (`roomCode\nslot`) to the Emscripten FS, then calls `Love(Module)`:
   ```js
   Module.preRun = Module.preRun || [];
   Module.preRun.push(function() {
     FS.writeFile('/nt2_room.txt', roomCode + '\n' + slot);
   });
   Love(Module);
   ```
   `Module.arguments` is **not** used — love.js already uses it for the game-data path.
   In `main.lua`, `love.load` reads the file with **plain Lua `io.open("/nt2_room.txt")`**, not `love.filesystem.read`. `love.filesystem` goes through PhysFS, which only sees the mounted game archive and the save directory (under `/home/web_user/love/...`), not the MEMFS root; Lua's `io` library uses C stdio, which Emscripten maps straight onto MEMFS at any absolute path. If the file exists and has two lines, the game is in networked mode.
9. **Implement a MEMFS-based Lua↔JS bridge.** Emscripten's in-memory filesystem is used as a pair of message queues (the general pattern is used by `Love.js-Api-Player`, MrcSnm). No love.js recompilation needed. Both directions use **newline-delimited JSON (one message per line) and append-then-consume**, so no message is ever overwritten:
   - **Inbound (`/nt2_in`).** On `ws.onmessage`, JS **appends** the raw JSON plus `\n` to `/nt2_in` (read-concat-write or `FS.open(path, 'a')`). Each frame, Lua opens `/nt2_in`, reads all lines, closes it, and deletes it with `os.remove`. JS recreates it on the next message. Messages that arrive before Lua boots simply accumulate in the file.
   - **Outbound (`/nt2_out`).** Lua **appends** one line per message with `io.open("/nt2_out", "a")`. A JS `requestAnimationFrame` loop reads `/nt2_out` if it exists, deletes it, and sends each line over the WebSocket.
   - **Why this is race-free:** in compatibility mode (`-c`, Phase 1) love.js runs Lua on the main JS thread, so a JS callback and a Lua frame never run at the same time; each append or read-and-delete finishes without interruption.
   - **Snapshot coalescing:** if several `state` messages are in one read, Lua applies only the last one; all `event` messages are processed in order.
   - **Save directory is not used** for the bridge. love.js may sync the save directory to IndexedDB, and writing there 60 times a second would be wasteful.
   - **JSON in Lua.** LÖVE 11.x ships no JSON library. Vendor `dkjson` (a single-file, MIT-licensed pure-Lua JSON encoder/decoder) into `src/dkjson.lua`. `gameBmulti_net.lua` requires it.
   - **Focus handling (JS side):** on `window.blur` and `document.visibilitychange → hidden`, JS sends an all-false `input` frame directly over the WebSocket, because a hidden tab stops running Lua frames.
   - **Latency:** ~1 frame (16 ms) per direction on top of network RTT.
   - **Optional optimization:** for lower Lua→JS latency, patch love.js's `default_tty_ops.put_char` to intercept `print("JS:" .. payload)` (demonstrated by `Love.js-Api-Player` and `love-with-js`, HamdyElzanqali). Start with the filesystem bridge; add this only if latency proves noticeable during playtesting. It is a runtime string replacement in the JS glue, not a C++ recompile.
10. **Add `gameBmulti_net.lua`** as a new file in `src/`. It is a small adapter, not a rewrite of `gameBmulti.lua`:
    - `gameBmulti_net.init(roomCode, slot)` — stores room/slot. Does **not** connect or block (the WebSocket is owned by JS).
    - `gameBmulti_net.sendReady()` — appends `{"type":"ready"}` to the outbox; called once at the end of `gameBmulti_load` in networked mode.
    - `gameBmulti_net.poll()` — called every frame. Drains `/nt2_in`, then:
      - For the latest `state` frame, it syncs `tetribodiesp1`/`p2` by id. A new id gets a **proxy body** (a plain table with `getX`/`getY`/`getAngle` methods) plus `tetriimagesp*[id] = newPaddedImage("graphics/pieces/"..kind..".png", mpscale)` and `tetrikindp*[id] = kind`. An existing id gets its x/y/angle overwritten. An id that disappears is removed. It also updates `scorescorep*`, `linesscorep*`, `nextpiecep*`, `p*fail`, `winner`, `p1wins`/`p2wins`, `jumpframe`, and `mariobody`/`luigibody` (also proxies). **No `love.physics` world or bodies are created on the client** — `gameBmulti_draw` only calls `getX`/`getY`/`getAngle`, so proxies are enough, and there is nothing that could step or be destroyed by accident.
      - For each `event`, it applies the matching state transition and sound (see the protocol list in Phase 2).
    - `gameBmulti_net.sendInput()` — called every frame. Reads `controls.isDown("left")`, `"right"`, `"down"`, `"rotateleft"`, `"rotateright"` (arrows, Z/Y/W, X — the single-player bindings from `controls.lua`) and appends an `input` frame to the outbox. **Identical for both players.**
11. **Thin client: replace every branch of `gameBmulti_update` in networked mode.** Every branch of the desktop update contains game logic, not just the force block, so in networked mode `gameBmulti_update` becomes:
    - keep: next-piece preview rotation (`nextpiecerot`, lines 319-323) and `newtime = love.timer.getTime()` (the draw uses it);
    - keep: the countdown beeps (lines 345-357) driven by the local `starttimer`, **but not** the `startgame()` call at line 343 — on reaching 3 s the client only starts `music[musicno]` and sets `gamestarted = true`; pieces arrive via snapshots;
    - skip: `world:update`, the `endblock1`/`endblock2` checks, the force blocks (358-430), the `failingBmulti` fixture destruction (431-441), the `failedBmulti` clear check and Mario/Luigi body creation (442-496), and the results jump/force logic (497-537) — all of it happens on the server;
    - keep client-side: the `cryframe` 0.4 s toggle (lines 513-517), which is purely visual;
    - call `gameBmulti_net.poll()` then `gameBmulti_net.sendInput()`.
    State transitions (`failingBmulti`, `failedBmulti`, `gameBmulti_results`) are set by `poll()` from server events. `gameBmulti_draw` runs unchanged.
12. **Networked `gameBmulti_load`.** In networked mode:
    - fix `mpscale = 4` (canvas 1096×576) and `fullscreen = false` instead of deriving them from desktop size and `options.txt`; `physicsmpscale = 1`. `love.window.setMode` works in love.js (it resizes the canvas), so it stays; CSS can scale the canvas down if the browser window is small;
    - skip `love.physics.newWorld`, the wall bodies, `world:setCallbacks`, and `randomtable[1] = math.random(7)`;
    - do not set `starttimer` (set on the `countdown` event); set `gamestarted = false` and initialise `starttimer` to a far-future value so the draw's countdown comparisons are false until the event arrives;
    - call `gameBmulti_net.sendReady()` at the end.
13. **Bypass the menu and lock the exits.** When `/nt2_room.txt` exists, `main.lua`'s `love.load` runs its normal initialisation (sounds, images, `loadoptions`, globals such as `musicno`, `gameno`, `p1wins`), then sets `nt2_networked = true`, `nt2_room`, `nt2_slot`, and calls `gameBmulti_load()` instead of starting the logo/title flow. In `love.keypressed`:
    - the `gameBmulti` branches (`main.lua:1247-1269`) ignore **Escape** in networked mode (desktop returns to `multimenu`, which would strand the player); the `blockmove`/`blockturn` sounds on left/right/rotate keypresses stay as-is — they already use the single-player `controls.check` actions and play for the local player;
    - the `gameBmulti_results` branch (`main.lua:1271-1281`) sends `rematch` on **Return** instead of going to `multimenu`, and ignores Escape.
14. **No changes to `controls.lua` or `menu.lua`.** The Lua file changes are:
    - New file: `gameBmulti_net.lua` (the adapter).
    - New file: `dkjson.lua` (vendored JSON library).
    - Modified: `gameBmulti.lua` — networked branches in `gameBmulti_load` and `gameBmulti_update` as described in steps 11-12.
    - Modified: `main.lua` — `love.load` reads `/nt2_room.txt` and routes to `gameBmulti_load`; `love.keypressed` Escape/Return handling in networked mode.

**Acceptance / done means:** with the Phase 2 relay running locally and Phase 1's `web/` served locally, open `http://localhost:8000` in **two separate browser windows placed side by side** (not two tabs — background tabs pause `requestAnimationFrame`, which drives love.js, and only the focused window gets keys). Create a room in window 1 and join with the code in window 2. Expected: both show a synchronised 3-2-1 countdown, then a playable `gameBmulti` round. Clicking into a window and using arrows + Z/X drives that window's field; `blockfall.ogg` plays on each landing; when **both** fields have topped out, the colourize/fall-out sequence and the results screen play in both windows; Return in both windows starts a rematch; closing one window shows "Opponent disconnected" in the other.

### Phase 4 — Free-tier hosting wiring

**Goal:** the public URL works without the developer running anything.

15. **Host the static `web/` build on Cloudflare Pages** (free tier; unlimited bandwidth, no cold starts). Either commit the generated `web/` files (simplest; the prebuilt love.js runtime is a few MB), or set the Pages build command to `bash build_web.sh` — the Pages build image has Node and `zip`, which is all the script needs now that love.js comes from npm. Set the output directory to `web/`. No custom headers are required because of compatibility mode.
16. **Host the relay on Render Free** using `relay/render.yaml`. Note in a README that the **free instance spins down after 15 minutes without inbound traffic**; the first match after idle waits up to about a minute for a cold start. This is acceptable for playtesting and is called out so users don't blame the game.
17. **Relay URL** is already switched on hostname (Phase 1 step 4); set the production value to the Render URL once the service exists.

**Acceptance / done means:** from a coffee-shop laptop, two friends open `https://<pages-subdomain>.pages.dev`, one creates a room, shares the 4-character code, the other joins, and both play a full `gameBmulti` match to the results screen, both using arrows + Z/X, then play a rematch.

## Critical files & anchors

- `web/index.html` — host page: pre-game Create/Join form, `NT2_RELAY_URL` switch, relay WebSocket (reused in-game), `matched` → `preRun` + `Love(Module)` boot, MEMFS bridge (JS side), blur/visibility all-false input. Hand-written.
- `web/love.js`, `web/love.wasm`, `web/game.js`, `web/game.data`, `web/theme/` — produced by `build_web.sh` via the pinned love.js npm package (`-c`). **No hand edits.**
- `build_web.sh` — zips `src/` into `game.love`, runs `npx love.js@<pin> -c`, copies output into `web/`.
- `relay/server.js` — WebSocket server, room registry and lifecycle, `planck.js` world with pixel↔metre scaling and filter-bit translation, full `gameBmulti` state machine (ready handshake, countdown, spawn, collision/endblock, both-fail game over, failing/failed/results, rematch), protocol, slot→player input routing with stale-input timeout. Tuning constants copied from the playtesting machine's `options.txt`.
- `relay/render.yaml` — Render Blueprint declaring the free-tier web service and region.
- `src/gameBmulti_net.lua` — browser-side adapter: `io`-based MEMFS bridge, proxy-body sync by id, event → state/sound transitions, `sendInput` via `controls.isDown`, `sendReady`.
- `src/dkjson.lua` — vendored JSON library.
- `src/gameBmulti.lua` — networked branches in `gameBmulti_load` (fixed `mpscale`, no world, `sendReady`) and `gameBmulti_update` (thin client, steps 11-12).
- `src/main.lua` — `love.load` reads `/nt2_room.txt` and routes to `gameBmulti_load`; `love.keypressed` ignores Escape and maps Return → rematch in networked mode.
- `src/controls.lua` — **no changes.** The existing single-player actions are the browser controls.
- `src/menu.lua` — **no changes.** The menu is bypassed in networked mode.

## Verification

End-to-end check the new build (not just the existing suite):

1. **Build the web bundle.**
   ```bash
   cd <repo-root>
   bash build_web.sh
   ```
   Expected: `web/index.html`, `web/love.js`, `web/love.wasm`, `web/game.js`, `web/game.data` exist; no errors. `python3 -m http.server -d web 8000` and opening `http://localhost:8000` shows the Create/Join form.
2. **Boot the relay locally.**
   ```bash
   cd relay
   npm install
   npm start
   ```
   Expected: log line `relay listening on <PORT>`. The server stays up between test runs.
3. **Two-window local smoke test.** Open `http://localhost:8000` in **two browser windows side by side**. Window 1: "Create Room," note the code. Window 2: "Join Room," enter the code. Expected: both windows boot love.js, show the countdown within a fraction of a second of each other, then enter `gameBmulti`. Arrows + Z/X in the focused window drive that window's field. Landings play `blockfall.ogg`. One player topping out does **not** end the round; when both have, the colourize → fall-out → results sequence runs in both windows. Return in both starts a rematch with the win counters kept. Closing a window shows "Opponent disconnected" in the other.
4. **Feel check against desktop.** Play the same field on desktop `gameB` and in the browser build back to back: fall speed, sideways push, rotation speed, soft drop. If it feels off, check the unit scaling first, then adjust the relay's tuning constants.
5. **Free-tier smoke test.** Push to the repo. Wait for the Cloudflare Pages deploy and the Render deploy. Repeat step 3 from two different networks (e.g. phone hotspot + home wifi). Expected: same behaviour, with the **first match after Render idle waiting up to a minute** while the free instance cold-starts; later matches start straight away.

## Assumptions & contingencies

- **planck.js is close to, not identical to, LÖVE's Box2D.** Earlier drafts claimed both are Box2D 2.4; recheck that — as far as known, LÖVE 11.x bundles Box2D **2.3.x** (the 2.4.1 upgrade landed in LÖVE 12), and planck.js is an independent JavaScript rewrite. For this game's physics (dynamic polygons against static walls, no joints) the solver behaviour should be very similar **provided the unit scaling in Phase 2 is applied**; unscaled pixel units are by far the most likely source of a "feels wrong" bug. Budget a tuning pass (Verification step 4).
- **love.js is `Davidobot/love.js`**, used via its npm package in compatibility mode. It provides the Emscripten FS (MEMFS), `Module.preRun`, and the `Love(Module)` boot API. Its LÖVE version (historically 11.4.x) must be confirmed when pinning. The TannerRogalsky fork is unmaintained and unsupported.
- **Lua's `io`/`os` libraries work against MEMFS in love.js.** LÖVE opens the standard Lua libraries, and Emscripten routes C stdio to its virtual FS. This is the basis of the room-file and bridge design; verify it as the first smoke check in Phase 1. **Fallback:** write the files into the save directory (`love.filesystem.getSaveDirectory()`, created with `FS.mkdirTree` in `preRun`) and read with `love.filesystem`.
- **Input latency is the main feel risk.** With no client prediction, your own piece reacts one full network round trip (plus ~2 bridge frames and up to 33 ms of snapshot interval) after a key press. For nudging physics pieces this may feel sluggish at 100+ ms RTT. Mitigations, in order: pick a Render region close to both players; raise the snapshot rate to 60 Hz; add the TTY bridge patch. Client-side prediction of the local player's piece is the real fix and is explicitly out of scope for this pass.
- **The relay can run `planck.js` at 60 Hz on Render Free.** 512 MB RAM, shared CPU. Landed pieces are never removed in B mode, so body count grows through a match (typically a few dozen per side), plus 3 wall fixtures per side — still tiny. **If lag surfaces**, reduce the snapshot rate from 30 to 20 Hz first (physics stays at 60).
- **Two players = two browser windows or two machines.** Tabs don't work (see Phase 3 acceptance). Two laptops is the canonical test.
- **Tuning constants are fixed per deploy.** The relay embeds the values from the playtesting machine's `options.txt`. Desktop F12 panel changes do not propagate to the browser build in this pass. **Fallback:** lift them into a per-room mutable dict exposed via a server-side admin socket; out of scope here.
- **The room code is the only auth.** Anyone who guesses a 4-character code (36^4 ≈ 1.7 M) while a room is still waiting can join it. For playtesting with friends this is fine. **Fallback:** a 5-character code or a single-shot invite token; not blocking.
- **The desktop LÖVE codebase is unaffected.** This project lives in its own repository. The Lua source is copied in, not linked or modified in-place.
- **Slot assignment is implicit.** Create Room → P1; Join Room → P2. No manual P1/P2 selector. The only thing players coordinate is the room code.
