# Codebase Context: Not Tetris 2

## Project Overview

Not Tetris 2 is a physics-based parody of classic Tetris. Instead of snapping neatly to a grid, the tetromino pieces are subject to rigid-body physics, mass, gravity, torque, and rotational momentum. They bounce, slide, and tilt dynamically.

- **Core Mechanic:** Lines are cleared not by filling a perfect row of grid squares, but by filling a horizontal plane across the screen with a required threshold of solid mass percentage (calculated via a scanning laser layer).
- **Target Engine:** Originally built for LÖVE 0.7.2; being upgraded to LÖVE 11.5.
- **Primary Dependencies:** LÖVE built-in modules (`love.physics` via Box2D, `love.graphics`, `love.audio`).

## File Structure & Directory Map

```
nottetris2/
├── main.lua           # Engine lifecycle, asset loading, global state routing
├── conf.lua           # Window configuration (800x720) and engine flags
├── controls.lua       # Keybinding configuration (player 1 & 2)
├── failed.lua         # Game over / failure screen
├── gameA.lua          # Game mode A — classic Tetris with cutoff line
├── gameB.lua          # Game mode B — "stack" singleplayer
├── gameBdebug.lua     # F12 debug panel — runtime tuning of `debug_params`
├── gameBmulti.lua     # Game mode B — two-player versus
├── menu.lua           # Logo splash, credits, title screen, menus, options, high scores
├── rocket.lua         # Rocket minigame / results screen
├── graphics/          # Textures, sprites, and UI assets
│   ├── pieces/        # 7 tetromino piece textures (1.png–7.png)
│   ├── versus/        # Mario, Luigi, and number-1/2/3 sprites for multiplayer results
│   └── (menu, game, font, rocket, etc. assets)
├── sounds/            # 21 OGG audio files (music, SFX, voice)
├── .context/          # Project documentation
├── README.md
└── LICENSE.txt
```

## File Profiles & Logic Roles

### `main.lua`

The foundational root file required by the LÖVE engine (1316 lines).

- **Role:** Requires all game modules at load time, handles `love.load` asset initialization (images, sounds, fonts, configuration), routes top-level callbacks (`love.update`, `love.draw`, `love.keypressed`, `love.keyreleased`) to the active gamestate module, and manages global settings (scale, fullscreen, volume, physics constants).
- **Refactoring Note:** Migrated to LÖVE 11.5. Uses `love.window.setMode` (lines 29, 32, 607, 609, 682, 1109, 1119, 1137) and `love.textinput` (line 785). Font loading calls `love.graphics.newImageFont`, which is still present in LÖVE 11.5, via the local helper `newPaddedImageFont` (lines 449–465); the helper pads the source ImageData to a power-of-two before calling the constructor. Game state routing and asset initialization are unchanged.
- **Global physics constants:** `density = 0.1` (line 168) is the fixture density applied to all tetromino fixtures in every mode. `blockrot = 10` (line 173) and `blockmass = 5` (line 172) are still defined but currently unused since the recent `setInertia` cleanup. `meter = 30` is still assigned by each game mode's `_load` but is dead code (see `piece-movement-physics.md`).

### `compat.lua` (removed)

The LÖVE 0.7.2 compatibility shim was removed during the post-migration cleanup. All color normalization (0–255 to 0.0–1.0 floats) is handled inline at every `setColor`/`setBackgroundColor` callsite; the `kpenter→return` key alias is handled locally in `controls.check` (controls.lua:23).

### `conf.lua`

Engine configuration processed before initialization (11 lines).

- **Role:** Sets window title, author, identity, width (800), height (720), FSAA, and vsync.
- **Refactoring Note:** Migrated. `t.window.{width,height,msaa,vsync}` and `t.version = "11.5"` are set (lines 5–10); no further action required.

### `controls.lua`

Keybinding definitions (40 lines).

- **Role:** Defines `controls.settings` table with key mappings for player 1 (arrows; Y/Z/W and X for rotation) and player 2 (J/K/M and O/P). Supports multiple keys per action.

### `failed.lua`

Game over state handler (104 lines).

- **Role:** Renders the failure screen overlay, plays game over audio, clears piece bodies/shapes from the physics world.

### `gameA.lua`

Game mode A — "Classic" with cutoff line (1248 lines).

- **Role:** Spawns pieces, manages physics world, handles input (move, rotate, hard drop), implements cutoff line line-clearing logic, tracks score/level/lines, manages piece preview HUD, draws game frame and backgrounds.
- **Refactoring Note:** Physics is built with the modern Box2D pattern: standalone `Shape`s bound to `Body`s through `Fixture`s (creation paths at lines 36–53, 81–133; refinement paths at 494, 574, 629, 827, 838). Contact callback `beginContactA` (line 1177) reads `fixture:getUserData()` on both arguments. Destroy lifecycle uses `:destroy()` on bodies and fixtures (lines 502, 513, 557, 1197) — the earlier `:release()` leak is fixed. `getintersectX` (line 396) correctly reads the 3rd return of `Fixture:rayCast` (fraction) rather than the 1st return (surface-normal x). `setScissor` is called with logical pixels only.

### `gameB.lua`

Game mode B — "Stack" singleplayer (352 lines).

- **Role:** Same core loop as gameA but with goal-based play (clear 40 lines at increasing speed). Smaller file — shares drawing/update structure but simplified.
- **Refactoring Note:** Physics uses the modern fixture-based pattern: bodies created with string types (lines 29–49), standalone shapes bound via `love.physics.newFixture`. Wall removal at line 340 destroys `wallfixtures[2]` (the earlier `:release()` on the bare shape is fixed). Collision callback `collideB` (line 319) reads `fixture:getUserData()` correctly. Wall fixture user-data uses bare strings (`"left"`, `"right"`, `"ground"`, `"ceiling"` at lines 36, 40, 44, 47); piece user-data uses bare integer `uniqueid` (line 159).
### `gameBdebug.lua`

Debug panel / tuning surface (526 lines).

- **Role:** Renders an on-screen panel bound to the F12 key in the title screen state. Lets the developer tune `debug_params` (lateral_force, rotation_torque, air_brake_coeff, soft_drop_force, soft_drop_cap_mul, angular_cap, difficulty_speed) at runtime with mouse and text input. Spawns a single-piece physics world with the same construction pattern as gameA/gameB (lines 94–185) and renders the right-hand panel UI (lines 188–259, 381–418).
- **Entry point:** Entered from the title screen via the F12 key (handled in `menu.lua`). Exits back to the title screen on Escape.
- **Persistence:** Tuned values are saved to `options.txt` via the same `saveoptions()` path used for scale/volume/hue/fullscreen — see `main.lua:642–646` for the `debug_*=` line format.
- **Refactoring Note:** Same fixture-based physics as gameA. Does not have a `setCallbacks` registration; piece-on-ground contact is polled via `tetribodies[1]:getY()` (line 339) rather than a Box2D callback.

### `gameBmulti.lua`

Game mode B — two-player versus (820 lines).

- **Role:** Splits screen horizontally for two simultaneous players. Tracks wins, manages shared physics worlds, renders Mario vs Luigi character sprites based on clearing advantage.
- **Refactoring Note:** Fully migrated to modern fixture-based physics. Destroy lifecycle is correct: lines 436–437 call `:destroy()` on the two ground wall fixtures. Wall fixture user-data uses bare strings (`"leftp1"`, `"rightp1"`, `"groundp1"`, `"leftp2"`, `"rightp2"`, `"groundp2"`). `setCategory` / `setMask` segregate players' physics — `setCategory(2)` at line 94 (P1 right wall), `setCategory(3)` at line 107 (P2 left wall); `setMask` on piece fixtures at lines 658, 718; `setMask` on endgame Mario/Luigi bodies at lines 472, 480 (the `resultsfloor` body at line 463 carries `setUserData` only — no `setMask`, so it collides with whatever is on stage); _Note: an earlier draft of this doc listed a `setMask` at line 466 for `resultsfloor`; that line is actually `setUserData("resultsfloor")` — corrected against the source._; `setMask` post-endblock toggles at lines 750, 774.
- **Tuning surface:** Reads `debug_params` (defined as a Lua global in `main.lua:601–610` / `618–627`) for all input forces, torques, velocity caps, and air-brake. The same table is read by gameA and gameB; the F12 panel in `gameBdebug.lua` is the editor. See `debug-params.md` for the schema.
- **Per-player field layout:** The playfield is a 320-pixel-wide column at x=196–516 (P1) and x=516–836 (P2), with the shared divider wall at x=516. All rendering uses `mpscale` (calculated at `gameBmulti_load:11–16`) instead of the single-player `scale`, so window-mode and fullscreen-mode sizes differ from gameA/gameB.
### `menu.lua`

Menu system, logo splash, and options screen (290 lines).

- **Role:** Manages the full pre-game UI flow: logo splash animation (`"logo"` state) -> credits scroll (`"credits"`) -> title screen (`"title"`) -> game mode/music selection (`"menu"`, `"multimenu"`) -> options screen (volume, color/hue, scale, fullscreen toggle) -> high score display and name entry. Draws all menu graphics and handles keyboard navigation.
- **Refactoring Note:** Options screen is embedded directly inside `menu.lua` — there is no separate `options.lua`. Relies on 0-255 RGB arrays for text styling.

### `rocket.lua`

Rocket minigame / results screen (165 lines).

- **Role:** Displays animated rocket launch based on player performance after a game ends. Shows score thresholds for bronze/silver/gold rockets. Handles rocket image swapping and audio transitions.

### `graphics/`

Contains 37 PNG assets: menu backgrounds and buttons, game backgrounds (single/multi/cutoff), game over and pause overlays, tetromino piece textures (`pieces/1.png` through `7.png`), Mario vs Luigi versus sprites (`versus/`), rocket images, particle effects (fire, smoke), and UI elements (rainbow, volume slider).

### `sounds/`

Contains 21 OGG audio files: 3 music themes (A/B/C), title music, high score music, rocket music, results music, options music, boot sound, block sounds (fall, turn, move), line clear, 4-line clear, game over (1 & 2), pause, high score beep, and new level.
