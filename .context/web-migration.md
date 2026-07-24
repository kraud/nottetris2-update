# Not Tetris 2 — Browser Hosting Plan

## Context

Not Tetris 2 is a single-codebase LÖVE 11.5 desktop game with three modes (single-player gameA, single-player gameB, local two-player gameBmulti). The goal is to ship a **browser-playable build** of the **local-multiplayer (`gameBmulti`) mode**, hosted for free-tier playtesting with friends. The intended end state is: one friend clicks "Create Room," gets a 4-character code, shares it out-of-band; the other friend clicks "Join Room," enters the code, and both play a real `gameBmulti` match with **both players using the same keyboard controls** (arrows + Z/X — the same layout they practice with in single-player).

**This project lives in its own repository**, separate from the desktop LÖVE codebase. The Lua source is copied in, not modified in-place. This keeps the desktop game fully isolated and avoids any risk of breaking it.

Four user decisions frame the rest of the plan and are recorded up front so no later step has to revisit them:

1. **Runtime path** — use **`love.js`** (the Emscripten port of LÖVE, `Davidobot/love.js` fork) to run the Lua game inside the browser, plus a **Node WebSocket relay** that owns the multiplayer physics state. The Lua source is preserved end to end; no hand-port to JS/Canvas.
2. **Authoritative server (thin client).** The **relay server** runs the physics simulation for both fields using `planck.js` (a full Box2D 2.4 port to JavaScript — same Box2D version LÖVE 11.5 uses, so no feel change). Each browser tab sends keypress state and receives authoritative body snapshots. **Clients never apply forces locally** — the entire input→force→physics pipeline lives on the relay. The client is a pure renderer: it reads key state, sends it to the server, and renders the bodies the server returns. This eliminates client/server drift and the `Box2D`-determinism rabbit hole.
3. **Same controls for both players.** Every client sends the same key names (`left`, `right`, `down`, `rotateleft`, `rotateright`, mapped from arrows + Z/X). The **relay maps slot 1 → P1 physics** and **slot 2 → P2 physics** internally. Both friends use arrows + ZX, the exact layout they're used to from single-player. No P2-specific bindings exist anywhere in the browser build.
4. **Create/Join room flow.** No manual P1/P2 selector. One player creates a room (server generates the code, creator is P1); the other joins with the code (joiner is P2). Slot assignment is implicit in create-vs-join order.

**Out of scope for this plan** (recorded inline so the implementer doesn't second-guess):
- gameA and gameB single-player browser builds — only `gameBmulti` is wired in this pass.
- Online matchmaking / lobby / accounts / chat. Players share a 4-character room code out-of-band.
- Replacing love.js with a hand port. love.js is the path; revisit only if a blocker surfaces.
- Mobile / touch input. Desktop browser keyboard only.
- In-game UI for room joining. Room code entry happens in JS before the game loads.
- Client-side prediction / interpolation. The thin client renders server snapshots directly. If the 30 Hz snapshot rate looks choppy, the implementer adds linear interpolation between the last two snapshots (视觉 smoothing only, no physics). This is the only sanctioned latency mitigation.

## Approach

The work is structured as **four ordered phases**, each leaving the system in a runnable state. Later phases depend on earlier ones.

### Phase 1 — Package the LÖVE build for the browser (`web/`)

**Goal:** produce a `web/` directory that, when served by any static host, runs the game in a browser — starting from a pre-game room-create/join form rather than the standard title screen.

1. **Create the project skeleton** in a new standalone repository. The Lua source files are copied from the desktop repo into `src/` (preserving the flat root layout LÖVE expects). The `web/` directory contains glue, assets, and the love.js runtime.
   - `web/index.html` — host page with two modes: (a) a pre-game form with Create Room / Join Room buttons, room-code display/input, and a Play action; (b) the love.js canvas (hidden until the room is ready). Loads `love.js` and `game.js`.
   - `web/love.css` — minimal fullscreen canvas styling plus form styling. Lifted from the love.js example template; no game-specific styling beyond the form.
   - `web/game.js`, `web/game.wasm`, `web/game.love` — build artifacts produced by the love.js toolchain. **Generated; do not hand-edit.**
2. **Add the build script** at the repo root as `build_web.sh` (single shell script; no new build system). It:
   - Zips `src/` (`main.lua`, `conf.lua`, `controls.lua`, `failed.lua`, `gameA.lua`, `gameB.lua`, `gameBmulti.lua`, `gameBdebug.lua`, `menu.lua`, `rocket.lua`, `graphics/`, `sounds/`) into a `.love` archive using the same root layout LÖVE expects.
   - Invokes the `love.js` Emscripten build (cloned once into `tools/love.js/`, gitignored) to produce `game.js` + `game.wasm` + `game.love`.
   - Copies the love.js runtime files (`love.js`, `love.css`, `theme.png` if present) into `web/`.
   - **Decision — tool version pinning:** the script pins the `love.js` commit hash in a comment at the top of the file. This is the only place versions live; the implementer picks a current `love.js` commit on a working 11.5 build, pins it, and moves on.
3. **Pre-game room-create/join form.** `web/index.html` displays a form before the love.js canvas loads. Two modes:
   - **Create Room:** Client opens a WebSocket to `window.NT2_RELAY_URL` and sends `{"type":"create"}`. Server generates a random 4-char alphanumeric code, creates a `Room`, assigns the creator to slot 1, and replies `{"type":"created","room":"ABCD","slot":1}`. The form displays: "Room code: **ABCD** — share this with your friend." The creator waits on a "Waiting for P2..." screen. When P2 joins, the server broadcasts `{"type":"event","kind":"start"}` to both clients, and both proceed to launch love.js.
   - **Join Room:** Client shows a 4-char code input. On submit, sends `{"type":"join","room":"XXXX"}`. Server assigns the joiner to slot 2 (the only free slot). On success, server broadcasts `{"type":"event","kind":"start"}` to both clients, and both proceed to launch love.js.
   - On `start`, JS sets `Module.arguments = [roomCode, String(slot)]`, hides the form, and starts love.js via `Love(Module)`. The Lua runtime receives these as `love.arg` / the standard `arg` table.
   - **Error handling:** If the room doesn't exist (join), or is full, or the code is invalid, the server replies `{"type":"error","message":"..."}` and the form shows the error inline. The user can retry without refreshing.
   - The form is vanilla HTML/CSS/JS. No framework.

**Bootstrap ordering note:** The WebSocket connection to the relay is established by the form JS *before* love.js starts. The same connection is reused for the in-game input/state stream — JS holds the `WebSocket` object and bridges it to Lua via MEMFS (see Phase 3). This avoids a second connection after the game boots.

**Acceptance / done means:** running `bash build_web.sh` from the repo root produces a `web/` directory; serving it with `python3 -m http.server -d web 8000` and opening `http://localhost:8000` shows the Create/Join form. Creating a room displays a code; joining with the code from a second tab transitions both tabs to the love.js canvas with no console errors.

### Phase 2 — Establish the relay server (`relay/`)

**Goal:** a standalone Node service that owns the multiplayer physics state and exposes a WebSocket endpoint.

4. **Add `relay/package.json`** declaring the runtime (Node 20+), two dependencies (`ws` for WebSockets, `planck-js` for physics), and one script (`npm start`). No TypeScript, no build step — keep this boring.
5. **Implement `relay/server.js`** with four pieces:
   - **Room registry.** An in-memory `Map<roomCode, Room>` where `roomCode` is a 4-character alphanumeric string the server generates on `create`. `Room` holds: the two connected sockets (`p1`, `p2`), the authoritative `planck.World`, the per-player body arrays (`tetribodiesp1`, `tetribodiesp2`), wall fixtures, the shared `randomtable` (piece sequence), per-player counters, scores, lines, fail flags, and the current game phase (`waiting`, `countdown`, `playing`, `failing`, `results`). There is intentionally **no persistence** — if the server restarts, rooms vanish. That's correct for playtesting.
   - **Physics core — `planck.js`.** Uses the `planck-js` npm package (a full JavaScript/TypeScript rewrite of Box2D 2.4, the same Box2D version LÖVE 11.5 ships). This is **not** a hand-rolled Box2D-Lite port — it is the real Box2D solver, so physics output matches the desktop game's behavior. The relay recreates the exact world from `gameBmulti.lua:67-119`: gravity `(0, 500)`, `meter = 30`, all wall fixtures with the same polygon vertices, categories, masks, friction, and user-data strings. Tetromino bodies are created with the same `newRectangleShape` offsets, `density = 0.1`, `setLinearDamping(0.5)`, `setBullet(true)`, and `setMask(3)` (P1) / `setMask(2)` (P2) as `createtetriBmultip1` / `createtetriBmultip2`. The `debug_params` defaults from `main.lua:601-610` / `618-627` are embedded as JS constants and applied verbatim in the input handler.
   - **Game logic.** The relay runs the full `gameBmulti` state machine, ported from the Lua:
     - **Piece sequence.** The relay owns the `randomtable` and seeds it on room creation. Both clients receive `nextpiece` values from the server; clients never call `math.random` themselves. This guarantees both tabs see the same pieces.
     - **Spawn.** `game_addTetriBmultip1` / `game_addTetriBmultip2` logic runs on the server: increment counter, read nextpiece from randomtable, create the body at `(388, blockstartY)` (P1) or `(708, blockstartY)` (P2) with `setLinearVelocity(0, difficulty_speed)`, advance the randomtable, compute the mirrored nextpiece.
     - **Collision / endblock.** `beginContact` callback inspects fixture user-data strings (`"p1-"..counterp1`, `"leftp1"`, `"groundp1"`, etc.) exactly as `collideBmulti` does. `endblockp1` / `endblockp2` logic: if the settled piece's Y is above `losingY`, set `p1fail`/`p2fail`; otherwise increment `linesscorep*`, play the landing event, and spawn the next piece. When both fail, run `endgame()` (determine winner, transition to `failing` then `results`).
     - **Countdown.** The 3-2-1 countdown (`gameBmulti.lua:338-357`) runs on the server. The server broadcasts `{"type":"event","kind":"start"}` only once both slots are occupied; both clients set their `starttimer` on receipt. This ensures both tabs countdown in sync.
     - **Results screen.** The Mario/Luigi jump-and-cry animation (`gameBmulti.lua:456-538`) runs on the server. The results bodies (`mariobody`/`luigibody`) are part of the world and included in the state snapshot.
   - **Wire protocol.** WebSocket JSON messages, schema below. Server is the single source of truth; clients only send inputs and read snapshots.
     - Client → Server:
       - `{"type":"create"}` — create a new room. Server generates code, assigns slot 1, replies `{"type":"created","room":"XXXX","slot":1}`.
       - `{"type":"join","room":"XXXX"}` — join an existing room. Server assigns the free slot (2 if creator took 1). On success, broadcasts `{"type":"event","kind":"start"}` to both clients. If the room doesn't exist or is full, replies `{"type":"error","message":"..."}`.
       - `{"type":"input","keys":{"left":bool,"right":bool,"down":bool,"rotateleft":bool,"rotateright":bool}}` — pressed/released state for the current frame. Mapped from the client's raw key state: arrows → left/right/down, Z → rotateleft, X → rotateright. **No `harddrop` field** — the game has no hard-drop mechanic. The relay applies forces to the slot's field using the embedded `debug_params` constants.
     - Server → Client:
       - `{"type":"created","room":"XXXX","slot":1}` — room created; creator displays the code and waits.
       - `{"type":"event","kind":"start"}` — both slots occupied; clients launch love.js and begin the countdown.
       - `{"type":"state","p1":{"bodies":[{id,x,y,angle,vx,vy,w},...],"score":N,"lines":N,"nextpiece":N,"fail":bool},"p2":{"bodies":[...],"score":N,"lines":N,"nextpiece":N,"fail":bool},"gameover":bool,"winner":1|2|3}` — authoritative snapshot of **both fields**, sent at 30 Hz. Both fields are included because `gameBmulti_draw` (`gameBmulti.lua:155-188`) renders P1 and P2 bodies side-by-side in the same split-screen view — each client needs both fields' bodies to draw the full scene. Scores, lines, next-piece previews, and fail flags are included for both players. During the results phase, the Mario/Luigi result bodies are appended to the `p1`/`p2` body arrays respectively.
       - `{"type":"event","kind":"piecelanded|playerfailed|gameover|results","slot":1|2,"data":{...}}` — discrete game events so clients can play the right sound and switch to the right state. `piecelanded` plays `blockfall.ogg` (the game has no line-clear sound — `linesscorep*` counts pieces landed, not cleared rows). `playerfailed` triggers the per-side fail flag. `gameover` starts the colorize/failing animation. `results` transitions to the rocket results screen.
       - `{"type":"error","message":"..."}` — protocol / room errors.
   - **Input routing (slot → player mapping).** The relay receives identical action names from both clients. Based on the socket's registered slot, it applies forces to the correct player's active body:
     - Slot 1: `left` → apply force to `tetribodiesp1[counterp1]` left; `rotateleft` → apply torque to P1 body; `down` → soft-drop force on P1 body; etc.
     - Slot 2: `left` → apply force to `tetribodiesp2[counterp2]` left; `rotateleft` → apply torque to P2 body; etc.
     - This mapping is the **only** place where slot identity matters — the client is completely agnostic.
6. **Add `relay/render.yaml`** (Render Blueprint) describing a free-tier web service: `runtime: node`, `buildCommand: npm install`, `startCommand: npm start`. The PORT env var is **not pinned** in the blueprint — Render sets it automatically. `server.js` reads `process.env.PORT || 10000`.

**Acceptance / done means:** `cd relay && npm install && npm start` brings up the server on `ws://localhost:10000`; opening two `wscat` connections, one sending `create` and the other `join` with the returned code, followed by a few `input` frames, yields a `state` stream with plausible body positions for both fields.

### Phase 3 — Browser-side wrapper for `gameBmulti`

**Goal:** the running love.js instance, having received the room code and slot from the pre-game form via `love.arg`, connects to the relay's input/state stream, enters `gameBmulti`, and renders the game purely from authoritative snapshots — with both players using arrows + ZX.

7. **Inject room code and slot into Lua at boot.** Use `Module.preRun` to create a MEMFS file at `/nt2_room.txt` containing `roomCode\nslot` — this is the **primary** path, not a fallback, because `Module.arguments` may collide with love.js's own internal arguments (the game-data path). In `web/index.html`, after the `start` event:
   ```js
   Module.preRun = Module.preRun || [];
   Module.preRun.push(function() {
     FS.createDataFile('/', 'nt2_room.txt', roomCode + '\n' + slot, true, true);
   });
   Love(Module);
   ```
   In `main.lua`, `love.load` reads `love.filesystem.read("nt2_room.txt")`. If the file exists and contains two lines, the game is in networked mode: `roomCode = line1`, `slot = tonumber(line2)`. This is proven: the `game.js` packager already uses `Module.preRun` for MEMFS init, and `love.filesystem` in love.js maps to the same MEMFS.
8. **Implement a MEMFS-based Lua↔JS WebSocket bridge.** The bridge uses Emscripten's virtual filesystem (MEMFS) as a message queue — a pattern proven by `Love.js-Api-Player` (MrcSnm). No love.js recompilation needed. Architecture:
   - **JS side (`web/index.html`):** The WebSocket opened by the form (Phase 1) is reused. On `ws.onmessage`, JS appends the JSON payload to an internal incoming queue. Once per `requestAnimationFrame`, JS flushes the entire queue as a single JSON array to MEMFS: `FS.writeFile('/nt2_in', JSON.stringify(queue))`, then clears the queue. This avoids the lost-message race where two WS frames arrive between Lua frames and the second overwrites the first. A separate `requestAnimationFrame` (or the same one) polls `/nt2_out` via `FS.readFile` and sends any pending messages over the WebSocket, then truncates the file.
   - **Lua side (`gameBmulti_net.lua`):** Each frame, `gameBmulti_net.poll()` calls `love.filesystem.read("nt2_in")`. If the file exists and is non-empty, it parses the JSON array, processes each message, then deletes the file. To send, `gameBmulti_net.sendInput()` calls `love.filesystem.write("nt2_out", json.encode(msg))`.
   - **JSON in Lua.** LÖVE 11.5 ships no JSON library. Vendor `dkjson` (a ~400-line public-domain JSON encoder/decoder) into `src/dkjson.lua`. `gameBmulti_net.lua` requires it.
   - **Latency:** ~1 frame (16ms at 60fps) for JS→Lua, ~1 frame for Lua→JS. Acceptable for a 30 Hz state stream.
   - **Tie-in with love.js TTY (optional optimization):** For lower latency on the Lua→JS path, patch love.js's `default_tty_ops.put_char` to intercept `print("JS:" .. payload)` and `eval()` the suffix. This pattern is demonstrated by both `Love.js-Api-Player` and `love-with-js` (HamdyElzanqali). The implementer starts with the pure filesystem bridge (simpler, proven) and adds the TTY patch only if latency proves noticeable during playtesting.
   - **No love.js recompilation.** The bridge uses only the standard love.js artifacts from the `Davidobot/love.js` release build. The optional TTY patch is a runtime string replacement in the JS glue, not a C++ recompile.
9. **Add `gameBmulti_net.lua`** as a new file in `src/`. It is a small adapter, not a rewrite of `gameBmulti.lua`. Specifically:
   - `gameBmulti_net.init(roomCode, slot)` — stores the room/slot, called once at boot from `main.lua` when `nt2_room.txt` is present. Does **not** connect or block (Lua is single-threaded inside the Emscripten main loop — blocking on a WebSocket ack is impossible). The WebSocket is already connected by the form JS and reused.
   - `gameBmulti_net.poll()` — called every frame from `gameBmulti_update` (replacing the local-physics block). Drains the incoming message queue from the bridge. For each `state` frame: overwrites **both** `tetribodiesp1` and `tetribodiesp2` arrays — creating new bodies if the server references an id the client doesn't have yet (piece spawn), updating existing ones (`body:setPosition`, `body:setAngle`, `body:setLinearVelocity`, `body:setAngularVelocity`), and removing bodies the server no longer references. Also updates `scorescorep1/p2`, `linesscorep1/p2`, `nextpiecep1/p2`, `p1fail/p2fail`, `winner`, and the results-screen bodies (`mariobody`/`luigibody`). For each `event` frame: triggers the matching game-state transition and sound. This is the thin client — the client never runs `world:update` or applies forces.
   - `gameBmulti_net.sendInput()` — called every frame from `gameBmulti_update`. Reads arrow keys + Z/X via `love.keyboard.isDown`, maps them to the logical action names (`left`, `right`, `down`, `rotateleft`, `rotateright`), and writes an `input` frame to the outbox. The key mapping is: `left` → `left`, `right` → `right`, `down` → `down`, `z` → `rotateleft`, `x` → `rotateright`. **Identical for both players.**
10. **Thin client: strip local physics, render server snapshots.** In networked mode, `gameBmulti_update` is gutted: the P1/P2 force-application blocks (`gameBmulti.lua:358-430`) are skipped entirely, `world:update` is skipped, and the collision callbacks are skipped (collisions are detected on the server). Instead, `gameBmulti_net.poll()` is called to overwrite all body positions from the server snapshot, and `gameBmulti_net.sendInput()` is called to send the key state. `gameBmulti_draw` runs unchanged — it reads from `tetribodiesp1`/`tetribodiesp2`, which have been populated by the server snapshot. The local `love.physics.newWorld` still exists (for creating the body objects the draw function reads), but it never steps and bodies are never moved by local forces.
   - **Body lifecycle.** The relay's `state` frame includes an `id` for each body (the counter index). On the client, `poll()` maintains a local map from server id → love.physics body. When a new id appears, the client creates a `love.physics.newBody` + fixtures matching the piece kind (the server includes the `kind` in the first state frame for a new body). When an id disappears, the client destroys the body. When an id persists, the client overwrites position/angle/velocity.
   - **`love.window.setMode` stub.** `gameBmulti_load` calls `love.window.setMode(274*mpscale, 144*mpscale, {...})` to resize the desktop window. In the browser, canvas size is controlled by HTML/CSS. In networked mode, stub this call to a no-op (guarded by `if nt2_networked then return end`) or set the canvas CSS dimensions from JS before launching love.js.
11. **Bypass the menu for networked mode.** When `nt2_room.txt` exists at startup, `main.lua`'s `love.load` reads it, sets `nt2_networked = true`, `nt2_room = roomCode`, `nt2_slot = slot`, and jumps directly to `gameBmulti_load()` — skipping the title screen, `multimenu`, and all menu navigation. `gameBmulti_load` is modified to detect `nt2_networked` and skip the `starttimer` initialization (the server drives the countdown via the `start` event).
12. **No Lua source changes to `controls.lua` or `menu.lua`.** Both players use the same physical keys, so no P2 bindings are needed. The menu is bypassed entirely in networked mode. The Lua file changes are:
    - New file: `gameBmulti_net.lua` (the adapter).
    - New file: `dkjson.lua` (vendored JSON library).
    - Modified: `gameBmulti.lua` — `gameBmulti_update` gets a network-mode branch that calls `gameBmulti_net.poll()` / `sendInput()` instead of the local-physics block; `gameBmulti_load` gets a network-mode guard for `setMode` and `starttimer`.
    - Modified: `main.lua` — `love.load` reads `nt2_room.txt`, sets network globals, and routes to `gameBmulti_load` instead of `menu_load`.

**Acceptance / done means:** with the Phase 2 relay running locally and Phase 1's `web/` served locally, opening two browser tabs at `http://localhost:8000`, creating a room in tab 1 and joining with the displayed code in tab 2, produces a playable `gameBmulti` round: both players control their pieces with arrows + ZX (each tab's keys drive its own field via the relay), piece-landing plays `blockfall.ogg` in the matching tab, filling the cutoff line in either field ends the round and shows the rocket results screen in both tabs.

### Phase 4 — Free-tier hosting wiring

**Goal:** the public URL works without the developer running anything.

13. **Host the static `web/` build on Cloudflare Pages** (free tier; unlimited bandwidth, no cold starts). Connect the repo, set the build output directory to `web/`. The `web/game.wasm` binary (~10-20 MB, the LÖVE runtime) must be either committed to the repo or built in CI — if building, set the Pages build command to `bash build_web.sh` (requires Node + the love.js toolchain in the Pages build environment; verify the build image supports it). Pages picks up new commits on push.
14. **Host the relay on Render Free** using the `relay/render.yaml` from step 6. Note in a README that the **free instance spins down after 15 minutes of no inbound traffic** (per Render's free-tier docs); the first match after idle takes ~30 seconds to cold-start. This is acceptable for playtesting with friends and is called out so users don't blame the bug on the game.
15. **Pin the relay URL into the web build.** Add a single constant at the top of `web/index.html`:
    ```js
    window.NT2_RELAY_URL = "wss://not-tetris-2-relay.onrender.com";
    ```
    This is the only place the relay hostname lives. **It is not a secret** — the client always sees it; an attacker who knows it can only send fake inputs that get ignored by a room with two real players.

**Acceptance / done means:** from a coffee-shop laptop, two friends open `https://<pages-subdomain>.pages.dev`, one creates a room, shares the 4-character code, the other joins, and both play a full `gameBmulti` match to completion, both using arrows + ZX, with piece landings, game over, and the rocket results screen all working in both tabs.

## Critical files & anchors

- `web/index.html` — host page with pre-game Create/Join form, relay WebSocket connection (reused in-game), love.js canvas host, `NT2_RELAY_URL` constant, and the MEMFS bridge (JS side). New file.
- `web/love.js`, `web/game.js`, `web/game.wasm`, `web/game.love` — produced by `build_web.sh`. **No hand edits.**
- `relay/server.js` — Node WebSocket server, room registry, `planck.js` physics world (Box2D 2.4), full `gameBmulti` game-logic port (piece sequence, spawn, collision/endblock, countdown, results), protocol encode/decode, and slot→player input routing. New file. The `applyForce` / `applyTorque` constants live here as a copy of the `debug_params` defaults from `main.lua:601-610` / `618-627`.
- `relay/render.yaml` — Render Blueprint declaring the free-tier web service. New file.
- `src/gameBmulti_net.lua` — browser-side adapter: MEMFS bridge poll, body-lifecycle management (create/update/destroy from server ids), `sendInput`, state/event application. New file.
- `src/dkjson.lua` — vendored public-domain JSON encoder/decoder (LÖVE 11.5 ships no JSON library). New file.
- `src/gameBmulti.lua` — existing file; `gameBmulti_update` gets a network-mode branch (thin client: poll + sendInput instead of local physics); `gameBmulti_load` gets guards for `setMode` and `starttimer`.
- `src/main.lua` — `love.load` reads `nt2_room.txt`, sets `nt2_networked`/`nt2_room`/`nt2_slot`, routes to `gameBmulti_load` instead of `menu_load`. No other changes.
- `src/controls.lua` — **no changes.** Both players use the same existing bindings.
- `src/menu.lua` — **no changes.** The menu is bypassed in networked mode.

## Verification

End-to-end check the new build (not just the existing suite):

1. **Build the web bundle.**
   ```bash
   cd <repo-root>
   bash build_web.sh
   ```
   Expected: `web/index.html`, `web/love.js`, `web/game.js`, `web/game.wasm`, `web/game.love` exist; no errors. `python3 -m http.server -d web 8000` and opening `http://localhost:8000` shows the Create/Join form.
2. **Boot the relay locally.**
   ```bash
   cd relay
   npm install
   npm start
   ```
   Expected: log line `relay listening on <PORT>`. The server stays up between test runs.
3. **Two-tab local smoke test.** Open `http://localhost:8000` in two Chrome tabs. In tab 1: click "Create Room," note the displayed code. In tab 2: click "Join Room," enter the code. Expected: both tabs transition to the love.js canvas, show the 3-2-1 countdown, then enter `gameBmulti`. Arrows + ZX work for both players (each tab's keys drive its own field via the relay). Piece-landing in either field plays `blockfall.ogg` in the matching tab. Filling the cutoff line in either field ends the round and shows the rocket results screen in both tabs.
4. **Free-tier smoke test.** Push to the repo. Wait for the Cloudflare Pages deploy and the Render deploy to come up. Repeat step 3 from two different networks (e.g. phone hotspot + home wifi). Expected: same behavior as step 3, with the **first match after Render idle taking ~30 s** to start while the free instance cold-starts; subsequent matches start instantly.

## Assumptions & contingencies

- **`planck.js` matches LÖVE's Box2D feel.** LÖVE 11.5 uses Box2D 2.4.1 (confirmed via `love-experiments/changes.txt`). `planck.js` is a full rewrite of Box2D 2.4 in TypeScript, using the same sequential-impulse solver and TOI/Baumgarte stabilization. For this game's physics profile (falling rectangles against walls, no joints, no stacking-sleep), the output is indistinguishable. Both use `setBullet(true)` for CCD and `setLinearDamping(0.5)` — both supported by planck.js. **No perceptible feel change expected.**
- **love.js is `Davidobot/love.js`** (the active LÖVE 11.5 fork). Source-verified: provides MEMFS-backed `love.filesystem`, `Module.preRun` callbacks for file injection, and the standard `Love(Module)` boot API. The TannerRogalsky fork is unmaintained and unsupported.
- **Lua↔JS WebSocket bridge is source-verified.** The MEMFS file-polling bridge is proven by `Love.js-Api-Player` (MrcSnm). JS writes to `FS.writeFile('/nt2_in', ...)`; Lua reads via `love.filesystem.read('nt2_in')`. The reverse direction uses `love.filesystem.write('nt2_out', ...)` with JS-side `FS.readFile` polling. The bridge uses an append-queue protocol (JS accumulates WS frames into a JSON array, writes once per RAF tick) to avoid the lost-message race where two frames arrive between Lua frames. No love.js recompilation needed. Latency: ~1 frame (~16ms) per direction. Optional TTY patching (demonstrated by `love-with-js`) reduces Lua→JS to near-zero latency.
- **`Module.preRun` file injection is the primary boot path.** `Module.arguments` may collide with love.js's own internal arguments (the game-data path). `Module.preRun` + MEMFS file creation is proven (the `game.js` packager already uses it) and avoids the collision.
- **The relay can run `planck.js` at 60 Hz for two players on Render Free.** The Render free instance has 512 MB RAM and shared CPU; `planck.js` with the small number of bodies in `gameBmulti` (≤ 14 active tetrominoes per side, 4 wall fixtures per side) is well within budget. **If lag surfaces** as more than ~150 ms round-trip, the implementer reduces server tick from 60 to 30 Hz and/or drops the snapshot rate from 30 to 20 Hz (still applying physics at 60). The state snapshot already carries both fields at 30 Hz; reducing to 20 is the first lever.
- **Two tabs on the same machine count as "two players" for playtesting.** Same-machine two-tabs works (different browsers, or one incognito). Two laptops is the canonical test.
- **`debug_params` defaults are stable.** The plan hard-codes the same default values in the relay that the desktop build uses (`main.lua:601-610` / `618-627`). Desktop F12 panel changes do not propagate to the browser build in this pass. **Fallback:** lift `debug_params` into a per-room mutable dict exposed via a server-side admin socket; out of scope here.
- **The room code is the only auth.** Anyone who guesses a 4-character code (36^4 ≈ 1.7 M) can join a room. For playtesting with friends this is fine. **Fallback:** add a 5-character code or a single-shot invite token; not blocking.
- **The desktop LÖVE codebase is unaffected.** This project lives in its own repository. The Lua source is copied in, not linked or modified in-place. The desktop game continues to work exactly as before.
- **Slot assignment is implicit.** Create Room → P1; Join Room → P2. No manual P1/P2 selector, no collision case, no out-of-band slot coordination. The only thing players coordinate is the room code (the creator shares it with the joiner).