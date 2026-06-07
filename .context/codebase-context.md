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
- **Refactoring Note:** Uses deprecated `love.graphics.setMode()` (0.7.2) instead of `love.window.setMode()` (11.x). Font loading relies on `love.graphics.newImageFont` with 0-255 color arrays.

### `compat.lua`

LÖVE version compatibility shim (40 lines). Required at the top of `main.lua`.

- **Role:** Monkey-patches `love.graphics.setColor` / `getColor` to translate 0-255 to 0.0-1.0 float ranges; aliases `love.graphics.drawq` to `love.graphics.draw`; mocks `love.graphics.getMode` to call `love.window.getMode`; translates legacy key constants (e.g., `kpenter` -> `return`) in `love.keyboard.isDown`.

### `conf.lua`

Engine configuration processed before initialization (9 lines).

- **Role:** Sets window title, author, identity, width (800), height (720), FSAA, and vsync.
- **Refactoring Note:** 0.7.2 format — window flags live in `t.screen` (must be moved to `t.window` for LÖVE 11.x).

### `controls.lua`

Keybinding definitions (40 lines).

- **Role:** Defines `controls.settings` table with key mappings for player 1 (arrow keys, Y/Z/W/X for rotation) and player 2 (J, K, etc.). Supports multiple keys per action.

### `failed.lua`

Game over state handler (102 lines).

- **Role:** Renders the failure screen overlay, plays game over audio, clears piece bodies/shapes from the physics world.

### `gameA.lua`

Game mode A — "Classic" with cutoff line (1210 lines).

- **Role:** Spawns pieces, manages physics world, handles input (move, rotate, hard drop), implements cutoff line line-clearing logic, tracks score/level/lines, manages piece preview HUD, draws game frame and backgrounds.
- **Refactoring Note:** Physics (world, bodies, shapes, fixtures) is defined inline — no separate `physics.lua`. Uses deprecated 0.7.2 patterns: shapes bound directly to bodies in constructor, `love.graphics.drawq`. Line clearing uses mass-density scanning across horizontal planes.

### `gameB.lua`

Game mode B — "Stack" singleplayer (378 lines).

- **Role:** Same core loop as gameA but with goal-based play (clear 40 lines at increasing speed). Smaller file — shares drawing/update structure but simplified.
- **Refactoring Note:** Uses modern fixture-based physics already (wall fixtures with `love.physics.newFixture`). Still relies on `drawq` and 0.7.2 color conventions.

### `gameBmulti.lua`

Game mode B — two-player versus (794 lines).

- **Role:** Splits screen horizontally for two simultaneous players. Tracks wins, manages shared physics worlds, renders Mario vs Luigi character sprites based on clearing advantage.
- **Refactoring Note:** Uses dynamic scaling (`mpscale`) to fit dual boards. Relies on same deprecated rendering calls as other game modes.

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
