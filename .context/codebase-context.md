# Codebase Context: Not Tetris 2

## Project Overview

Not Tetris 2 is a physics-based parody of classic Tetris. Instead of snapping neatly to a grid, the tetromino pieces are subject to rigid-body physics, mass, gravity, torque, and rotational momentum. They bounce, slide, and tilt dynamically.

- **Core Mechanic:** Lines are cleared not by filling a perfect row of grid squares, but by filling a horizontal plane across the screen with a required threshold of solid mass percentage (calculated via a scanning laser layer).
- **Target Engine:** Originally built for LÖVE 0.7.2.
- **Primary Dependencies:** LÖVE built-in modules (`love.physics` via Box2D, `love.graphics`, `love.audio`).

## File Structure & Directory Map

```
nottetris2/
├── main.lua          # Main engine lifecycle hooks (load, update, draw)
├── compat.lua        # LÖVE 0.7.2 -> 11.5 compatibility layer
├── conf.lua          # Window configurations, dimensions, and flags
├── game.lua          # Core gameplay state, game loop, and mechanics
├── menu.lua          # Main menu, options layout, and UI state
├── intro.lua         # Opening splash screen animation/logic
├── options.lua       # Keybindings, audio toggles, screen scaling
└── physics.lua       # World creation, collision layers, and mass scanning
```

## File Profiles & Logic Roles

### `main.lua`

The foundational root file required by the LÖVE engine.

- **Role:** Manages global game states (`"intro"`, `"menu"`, `"game"`, `"options"`) and routes LÖVE's top-level callbacks (`love.update`, `love.draw`, `love.keypressed`, `love.keyreleased`) to the active state module.
- **Refactoring Note:** Contains early global asset loading logic.

### `conf.lua`

The configuration file processed before the engine fully initializes.

- **Role:** Sets game window title, width (1024), height (576), fullscreen rules, and engine module toggles.
- **Refactoring Note:** 0.7.2 format handles flags inside a `t.screen` table block which is deprecated in modern LÖVE (shifted to `t.window`).

### `game.lua`

The largest and most critical file containing the core Tetris simulator.

- **Role:**
  - Controls spawning pieces, player input tracking (moving, rotating).
  - Handles the logic for active piece locking, score counting, game over states, and multiplayer tracking.
  - Draws the matrix frame, backgrounds, incoming piece HUDs, and textual updates.
- **Refactoring Note:** Features extensive calls to deprecated 0.7.2 drawing features (`love.graphics.drawq`) and contains the critical hooks that coordinate active block movement with the physics world.

### `physics.lua`

The mathematics and collision backbone of the game.

- **Role:**
  - Generates the `love.physics` world, boundaries, floor, and converts geometric shapes into physical colliders.
  - Implements the unique line-clearing logic: It scans vertical slices across horizontal planes using specialized sensors or bounding checks to see if mass distribution meets the elimination threshold, then modifies/splits falling shapes dynamically.
- **Refactoring Note:** This is the highest-risk file for your agents. It relies completely on the old 0.7.2 paradigm where shapes were directly bound to bodies upon creation. It must be rewritten to handle the modern Body -> Fixture -> Shape lifecycle architecture.

### `menu.lua` & `options.lua`

The user interface and preference handlers.

- **Role:**
  - `menu.lua` processes selection changes, scrolling effects, and state routing using keyboard navigation.
  - `options.lua` controls volume settings, key configurations, and reads/writes persistent preferences.
- **Refactoring Note:** Relies heavily on old 0-255 RGB scaling arrays for text styling, which must be scaled down to modern 0.0-1.0 float ranges.

### `intro.lua`

The boot visualization.

- **Role:** Plays a short text animation sequencing the "Stabyourself" studio logo prior to pushing the state engine to the main menu screen.
