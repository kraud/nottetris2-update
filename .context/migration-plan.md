# Migration Specification: LÖVE 0.7.2 to LÖVE 11.5

This document serves as the roadmap and validation criteria for upgrading the Not Tetris 2 source code. Agents must execute tasks sequentially, verifying each phase before moving to the next.

---

## Phase 1: Engine Boot & Framework Integrity (`[PHASE-1]`)

**Objective:** Eliminate initial runtime errors, update the engine initialization flags, and get the window to open to the main menu state.

### `[PHASE-1-CONF]` Configuration Migration

- **Target File:** `conf.lua`
- **Action:** Rewrite the `love.conf` configuration hook. LÖVE 11.x moves window configurations from `t.screen` to `t.window`.
- **Code Modification:**

```lua
-- Old Paradigm (0.7.2)
t.screen.width = 1024
t.screen.height = 576

-- New Paradigm (11.5)
t.window = {
    width = 1024,
    height = 576,
    resizable = false
}
t.version = "11.5"
```

### `[PHASE-1-COLOR]` Color Normalization Wrapper

- **Target File:** `main.lua`
- **Action:** Injection of a global compatibility wrapper. LÖVE 0.7.2 uses 0-255 integer arrays for RGBA, whereas LÖVE 11.x requires normalized 0.0-1.0 floating-point scales.
- **Code Injection (at the top of `love.load`):**

```lua
local oldSetColor = love.graphics.setColor
love.graphics.setColor = function(r, g, b, a)
    if type(r) == "table" then
        oldSetColor(r[1]/255, r[2]/255, r[3]/255, (r[4] or 255)/255)
    else
        oldSetColor(r/255, g/255, b/255, (a or 255)/255)
    end
end
```

### `[PHASE-1-KEYS]` Keyboard Constant Audit

- **Target Files:** `main.lua`, `menu.lua`, `options.lua`
- **Action:** Audit all string lookups for keypresses. Ensure keypad entries and special characters conform to modern LÖVE rules (e.g., `return` instead of old OS-specific variations).

---

## Phase 2: Graphic & Asset Rendering (`[PHASE-2]`)

**Objective:** Restore visual assets, textures, and UI rendering alignments.

### `[PHASE-2-DRAW]` Deprecation of `drawq`

- **Target Files:** `game.lua`, `menu.lua`, `intro.lua`
- **Action:** Update texture sheet rendering. LÖVE 11.x deprecated `love.graphics.drawq` and merged Quad handling natively into `love.graphics.draw`.
- **Code Modification:**

```lua
-- Scan and replace all:
love.graphics.drawq(image, quad, x, y, ...)
-- Change to:
love.graphics.draw(image, quad, x, y, ...)
```

### `[PHASE-2-SCISSOR]` Scissor Coordinate Adjustments

- **Target File:** `game.lua`
- **Action:** Check any bounding boxes handling screen space restrictions. Ensure `love.graphics.setScissor()` matches pixel scaling rules under Retina/High-DPI configurations if running on modern Mac hardware.

---

## Phase 3: Physics & Box2D Refactor (`[PHASE-3]`)

**Objective:** Overhaul the physics engine structure to match the modern Box2D architecture wrapper. **This is the highest-risk phase.**

### `[PHASE-3-FIXTURE]` Separation of Shapes and Bodies

- **Target File:** `physics.lua` (and piece generation functions inside `game.lua`)
- **Action:** Decouple Body generation from Shape generation. In 0.7.2, Shapes took the Body object as an instantiation argument. In 11.5, Shapes are abstract entities bound to Bodies explicitly via Fixtures.
- **Structural Blueprint:**

```lua
-- Old Architecture (0.7.2)
local body = love.physics.newBody(world, x, y, "dynamic")
local shape = love.physics.newRectangleShape(body, 0, 0, width, height)

-- New Architecture (11.5)
local body = love.physics.newBody(world, x, y, "dynamic")
local shape = love.physics.newRectangleShape(0, 0, width, height)
local fixture = love.physics.newFixture(body, shape)
```

### `[PHASE-3-CALLBACKS]` Collision Callback Migration

- **Target File:** `physics.lua`
- **Action:** Refactor the world contact listener hook. The signatures for collision updates changed entirely from passing Shapes to passing a unified Contact object.
- **Interface Remap:**

```lua
-- Change world callbacks initialization to:
world:setCallbacks(beginContact, endContact, preSolve, postSolve)

-- Callback implementation structure:
function beginContact(a, b, coll)
    -- 'a' and 'b' are now Fixtures. To mimic old logic behavior:
    local shapeA = a:getShape()
    local shapeB = b:getShape()
    -- Execute legacy collision logic using extracted references...
end
```

### `[PHASE-3-QUERY]` Bounding Box Queries

- **Target File:** `physics.lua`
- **Action:** Adjust the line scanning logic method. The old `world:queryBoundingBox` API parameters have been updated to evaluate coordinates differently. Update the scanning coordinates to execute via the modern spatial query signature.

---

## Verification Checklist for Agents

| Section Identifier | Status (Pending/Done) | Validation Rule |
|---|---|---|
| `[PHASE-1-CONF]` | | Execution of LÖVE directory opens application shell without crashing. |
| `[PHASE-1-COLOR]` | | Main Menu screen loads and text labels display legible coloring schemes. |
| `[PHASE-1-KEYS]` | | Keyboard navigation inputs accurately shift focus across menu indexes. |
| `[PHASE-2-DRAW]` | | Sprite boundaries, background grids, and game blocks render without missing textures. |
| `[PHASE-3-FIXTURE]` | | Pieces react to forces and land dynamically inside the structural grid matrix. |
| `[PHASE-3-CALLBACKS]` | | Collision signals fire correctly, creating sound alerts and line-fill checks. |
