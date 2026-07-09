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
├── compat.lua         # LÖVE 0.7.2 -> 11.5 compatibility shim (colors, drawq, keys)
├── conf.lua           # Window configuration (800x720) and engine flags
├── controls.lua       # Keybinding configuration (player 1 & 2)
├── failed.lua         # Game over / failure screen
├── gameA.lua          # Game mode A — classic Tetris with cutoff line
├── gameB.lua          # Game mode B — "stack" singleplayer
├── gameBmulti.lua     # Game mode B — two-player versus
├── menu.lua           # Logo splash, credits, title screen, menus, options, high scores
├── rocket.lua         # Rocket minigame / results screen
├── graphics/          # Textures, sprites, and UI assets
│   ├── pieces/        # 7 tetromino piece textures
│   └── versus/        # Mario & Luigi multiplayer character sprites
├── sounds/            # 21 OGG audio files (music, SFX, voice)
├── .context/          # Project documentation
├── README.md
└── LICENSE.txt
```

## File Profiles & Logic Roles

### `main.lua`

The foundational root file required by the LÖVE engine (1205 lines).

- **Role:** Applies the `compat` shim, requires all game modules, handles `love.load` asset initialization (images, sounds, fonts, configuration), routes top-level callbacks (`love.update`, `love.draw`, `love.keypressed`, `love.keyreleased`) to the active gamestate module, and manages global settings (scale, fullscreen, volume, physics constants).
- **Refactoring Note:** Migrated to LÖVE 11.5. Uses `love.window.setMode` (lines 29, 32, 607, 609, 682, 1109, 1119, 1137) and `love.textinput` (line 785). The `compat` shim is `require`d at the top (line 1). Font loading calls `love.graphics.newImageFont`, which is still present in LÖVE 11.5, via the local helper `newPaddedImageFont` (lines 449–465); the helper pads the source ImageData to a power-of-two before calling the constructor. Game state routing and asset initialization are unchanged.

### `compat.lua`

LÖVE version compatibility shim (40 lines). Required at the top of `main.lua`.

- **Role:** Monkey-patches `love.graphics.setColor` / `getColor` to translate 0-255 to 0.0-1.0 float ranges; aliases `love.graphics.drawq` to `love.graphics.draw`; mocks `love.graphics.getMode` to call `love.window.getMode`; translates legacy key constants (e.g., `kpenter` -> `return`) in `love.keyboard.isDown`.
- **Refactoring Note:** setColor/setBackgroundColor/getColor wrapped; drawq aliased to draw; getMode/getModes routed to `love.window` equivalents; kpenter mapped to return. The shim is intentionally minimal: the only legacy key constant translated is `kpenter` (line 43). The string keys `"kp1"`, `"kp2"`, `"left"`, `"right"`, `"up"`, `"down"`, `"return"`, `"escape"`, and the letter keys used in `controls.lua` and `gameBmulti.lua` (lines 348, 353, 359, 363, 369, 384, 389, 395, 399, 405, 507, 511, 516, 520) are unchanged in LÖVE 11.5 and do not need translation.

### `conf.lua`

Engine configuration processed before initialization (9 lines).

- **Role:** Sets window title, author, identity, width (800), height (720), FSAA, and vsync.
- **Refactoring Note:** Migrated. `t.window.{width,height,msaa,vsync}` and `t.version = "11.5"` are set (lines 5–10); no further action required.

### `controls.lua`

Keybinding definitions (40 lines).

- **Role:** Defines `controls.settings` table with key mappings for player 1 (arrow keys, Y/Z/W/X for rotation) and player 2 (J, K, etc.). Supports multiple keys per action.

### `failed.lua`

Game over state handler (102 lines).

- **Role:** Renders the failure screen overlay, plays game over audio, clears piece bodies/shapes from the physics world.

### `gameA.lua`

Game mode A — "Classic" with cutoff line (1210 lines).

- **Role:** Spawns pieces, manages physics world, handles input (move, rotate, hard drop), implements cutoff line line-clearing logic, tracks score/level/lines, manages piece preview HUD, draws game frame and backgrounds.
- **Refactoring Note:** Physics is built with the modern Box2D pattern: standalone `Shape`s bound to `Body`s through `Fixture`s (creation paths at lines 36–53, 81–133; refinement paths at 494, 574, 629, 827, 838). Contact callback `beginContactA` (line 1177) reads `fixture:getUserData()` on both arguments. Destroy lifecycle uses `:destroy()` on bodies and fixtures (lines 502, 513, 557, 1197) — the earlier `:release()` leak is fixed. `getintersectX` (line 396) correctly reads the 3rd return of `Fixture:rayCast` (fraction) rather than the 1st return (surface-normal x). `setScissor` is called with logical pixels only.

### `gameB.lua`

Game mode B — "Stack" singleplayer (378 lines).

- **Role:** Same core loop as gameA but with goal-based play (clear 40 lines at increasing speed). Smaller file — shares drawing/update structure but simplified.
- **Refactoring Note:** Physics uses the modern fixture-based pattern: bodies created with string types (lines 29–49), standalone shapes bound via `love.physics.newFixture`. Wall removal at line 340 destroys `wallfixtures[2]` (the earlier `:release()` on the bare shape is fixed). Collision callback `collideB` (line 319) reads `fixture:getUserData()` correctly. Wall fixture user-data uses bare strings (`"left"`, `"right"`, `"ground"`, `"ceiling"` at lines 36, 40, 44, 47); piece user-data uses bare integer `uniqueid` (line 159).
### `gameBmulti.lua`

Game mode B — two-player versus (794 lines).

- **Role:** Splits screen horizontally for two simultaneous players. Tracks wins, manages shared physics worlds, renders Mario vs Luigi character sprites based on clearing advantage.
- **Refactoring Note:** Fully migrated to modern fixture-based physics. Destroy lifecycle is correct: lines 423–424 call `:destroy()` on bodies. Wall fixture user-data uses bare strings (`"leftp1"`, `"rightp1"`, `"groundp1"`, `"leftp2"`, `"rightp2"`, `"groundp2"`). `setCategory` / `setMask` segregate players' physics (lines 92, 105, 459, 467, 646, 707, 739, 763).
### `menu.lua`

Menu system, logo splash, and options screen (287 lines).

- **Role:** Manages the full pre-game UI flow: logo splash animation (`"logo"` state) -> credits scroll (`"credits"`) -> title screen (`"title"`) -> game mode/music selection (`"menu"`, `"multimenu"`) -> options screen (volume, color/hue, scale, fullscreen toggle) -> high score display and name entry. Draws all menu graphics and handles keyboard navigation.
- **Refactoring Note:** Options screen is embedded directly inside `menu.lua` — there is no separate `options.lua`. Relies on 0-255 RGB arrays for text styling.

### `rocket.lua`

Rocket minigame / results screen (166 lines).

- **Role:** Displays animated rocket launch based on player performance after a game ends. Shows score thresholds for bronze/silver/gold rockets. Handles rocket image swapping and audio transitions.

### `graphics/`

Contains 37 PNG assets: menu backgrounds and buttons, game backgrounds (single/multi/cutoff), game over and pause overlays, tetromino piece textures (`pieces/1.png` through `7.png`), Mario vs Luigi versus sprites (`versus/`), rocket images, particle effects (fire, smoke), and UI elements (rainbow, volume slider).

### `sounds/`

Contains 21 OGG audio files: 3 music themes (A/B/C), title music, high score music, rocket music, results music, options music, boot sound, block sounds (fall, turn, move), line clear, 4-line clear, game over (1 & 2), pause, high score beep, and new level.
