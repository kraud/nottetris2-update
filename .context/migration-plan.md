# Migration Specification: LÖVE 0.7.2 to LÖVE 11.5

This document serves as the roadmap and validation criteria for upgrading the
Not Tetris 2 source code. Agents must execute tasks sequentially, verifying
each phase before moving to the next. Do not begin a phase until all checklist
items for the preceding phase are marked Done.

---

## Phase 1: Engine Boot & Framework Integrity (`[PHASE-1]`)

**Objective:** Eliminate initial runtime errors, update the engine
initialization flags, and get the window to open to the main menu state.

### `[PHASE-1-CONF]` Configuration Migration

- **Target File:** `conf.lua`
- **Action:** Rewrite the `love.conf` configuration hook. LÖVE 11.x moves
  window configuration from `t.screen` to `t.window`.

```lua
-- Old (0.7.2)
t.screen.width  = 800
t.screen.height = 720

-- New (11.5)
t.window = {
    width     = 800,
    height    = 720,
    resizable = false,
}
t.version = "11.5"
```

### `[PHASE-1-COLOR]` Color Normalization Wrapper

- **Target File:** `compat.lua` (already implemented)
- **Action:** Already injected — monkey-patches `love.graphics.setColor` /
  `getColor` to translate 0–255 integer ranges to 0.0–1.0 floats. No further
  action needed unless new 0–255 call sites are discovered outside the shim's
  reach.
- **Verification:** Confirm `require("compat")` appears at the top of
  `main.lua` before any graphics calls.

### `[PHASE-1-KEYS]` Keyboard Constant Audit

- **Target Files:** `main.lua`, `menu.lua`, `controls.lua`
- **Action:** Audit all string key lookups. Ensure keypad entries and special
  characters conform to modern LÖVE constants (e.g., `"return"` instead of
  OS-specific variants). Key mappings live in `controls.lua`; handling logic
  is in `menu.lua` and `main.lua`.
- **Note:** `compat.lua` already maps `"kpenter"` → `"return"` inside
  `love.keyboard.isDown`. Verify no raw `"kpenter"` strings remain outside
  that shim.

### `[PHASE-1-SETMODE]` Window Mode Initialization

- **Target File:** `main.lua`
- **Action:** Replace the deprecated `love.graphics.setMode()` with
  `love.window.setMode()`.

```lua
-- Old (0.7.2)
love.graphics.setMode(160*scale, 144*scale, false, vsync, 0)

-- New (11.5)
love.window.setMode(160*scale, 144*scale, { vsync = vsync })
```

---

## Phase 2: Graphic & Asset Rendering (`[PHASE-2]`)

**Objective:** Restore visual assets, textures, and UI rendering.

### `[PHASE-2-DRAW]` Deprecation of `drawq`

- **Target Files:** `gameA.lua`, `gameB.lua`, `gameBmulti.lua`, `menu.lua`,
  `failed.lua`, `rocket.lua`
- **Action:** `compat.lua` already aliases `love.graphics.drawq` to
  `love.graphics.draw`. Verify all `drawq` calls resolve through the shim.
  Replace any that do not:

```lua
-- Old
love.graphics.drawq(image, quad, x, y, ...)
-- New
love.graphics.draw(image, quad, x, y, ...)
```

### `[PHASE-2-SCISSOR]` Scissor Coordinate Adjustments

- **Target Files:** `gameA.lua`, `gameB.lua`, `gameBmulti.lua`, `failed.lua`
- **Action:** Audit all `love.graphics.setScissor()` calls. Coordinates must
  be in logical pixels, not physical pixels — do not multiply by the DPI
  scale factor manually. LÖVE 11.x handles DPI scaling internally.

### `[PHASE-2-IMAGEFONT]` ImageFont Migration

- **Target File:** `main.lua`
- **Action:** `love.graphics.newImageFont` is removed in LÖVE 11.x.
  Replace with `love.graphics.newFont` using a BMFont-format `.fnt` file,
  or convert the existing image glyph sheet to a bitmap font using a tool
  such as [bmfont](https://www.angelcode.com/products/bmfont/) or
  [Shoebox](https://renderhjs.net/shoebox/).

  If the glyph image is simple and the font is only used for score/UI
  rendering, an acceptable fallback is to replace it with a TTF loaded via
  `love.graphics.newFont("font.ttf", size)` and adjust any layout that
  depended on the image font's exact glyph widths.

  Do not leave `newImageFont` calls in place — they will throw a nil error
  at startup in 11.x.

---

## Phase 3: Physics & Box2D Refactor (`[PHASE-3]`)

**Objective:** Overhaul the physics engine structure to match the modern Box2D
wrapper. **This is the highest-risk phase. Do not begin until Phase 1 and
Phase 2 checklists are fully green.**

### `[PHASE-3-FIXTURE]` Separation of Shapes and Bodies

- **Target Files:** `gameA.lua` (migration required; `gameB.lua` and
  `gameBmulti.lua` are already on the modern pattern)
- **Action:** In 0.7.2, shape constructors took the body as their first
  argument and attached implicitly. In 11.5, shapes are standalone and must
  be bound to a body via an explicit `Fixture`.

```lua
-- Old (0.7.2) — body passed into shape constructor; implicit attachment
local body  = love.physics.newBody(world, x, y, 10)      -- 4th arg is numeric mass
local shape = love.physics.newRectangleShape(body, 0, 0, width, height)
-- Static body pattern: mass = 0
local sbody  = love.physics.newBody(world, x, y, 0)
local sshape = love.physics.newRectangleShape(sbody, 0, 0, width, height)

-- New (11.5) — shape is standalone; fixture binds it to body
local body    = love.physics.newBody(world, x, y, "dynamic")
local shape   = love.physics.newRectangleShape(0, 0, width, height)
local fixture = love.physics.newFixture(body, shape)
fixture:setDensity(1.0)
body:resetMassData()   -- recalculates mass from density × shape area

-- Static equivalent
local sbody    = love.physics.newBody(world, x, y, "static")
local sshape   = love.physics.newRectangleShape(0, 0, width, height)
local sfixture = love.physics.newFixture(sbody, sshape)
```

  Additionally, the following properties move from the shape to the fixture
  and must be re-applied after fixture creation if the old code set them:

  | Property          | Old call site  | New call site    |
  |-------------------|----------------|------------------|
  | Density           | (was mass arg) | `fixture:`       |
  | Friction          | `shape:`       | `fixture:`       |
  | Restitution       | `shape:`       | `fixture:`       |
  | Sensor flag       | `shape:`       | `fixture:`       |
  | User data         | `shape:`       | `fixture:`       |
  | Category/mask     | `shape:`       | `fixture:`       |

### `[PHASE-3-CALLBACKS]` Collision Callback Migration

- **Target Files:** `gameA.lua`, `gameB.lua`, `gameBmulti.lua`
- **Action:** The world callback API changed both in registration and in
  callback signatures. Callbacks now receive `Fixture` objects and a `Contact`
  object, not raw shapes.

```lua
-- Registration (all four slots must be provided; pass nil for unused)
world:setCallbacks(beginContact, endContact, preSolve, postSolve)

-- beginContact / endContact
function beginContact(fixtureA, fixtureB, contact)
    local shapeA = fixtureA:getShape()
    local shapeB = fixtureB:getShape()
    local dataA  = fixtureA:getUserData()   -- userData is on the fixture now
    local dataB  = fixtureB:getUserData()
end

-- preSolve (called every tick the shapes overlap, before resolution)
function preSolve(fixtureA, fixtureB, contact)
end

-- postSolve — NOTE: impulse data is now exposed as extra arguments
-- If the old resultCallback read impulse values for sound effects,
-- update the reads to use the new parameters.
function postSolve(fixtureA, fixtureB, contact, normalImpulse, tangentImpulse)
    -- normalImpulse and tangentImpulse are per-contact-point values
    -- Use normalImpulse to gate impact sound volume, etc.
end
```

  **Callback name mapping:**

  | Old (0.7.x)        | New (11.x)     |
  |--------------------|----------------|
  | `addCallback`      | `beginContact` |
  | `removeCallback`   | `endContact`   |
  | `persistCallback`  | `preSolve`     |
  | `resultCallback`   | `postSolve`    |

### `[PHASE-3-QUERY]` Bounding Box Queries

- **Target File:** `gameA.lua`
- **Action:** `world:queryBoundingBox(x1, y1, x2, y2, callback)` exists in
  both versions but the callback contract changed. In 11.5 the callback
  **must return `true`** to continue iteration; returning nothing or `false`
  stops the query early. The old API did not require a return value.

  Audit every `queryBoundingBox` callback in `gameA.lua`'s line-scanning
  logic and add `return true` at the end of each callback body unless an
  early-exit condition was intentional.

```lua
-- Old — no return value required
local function scanCallback(shape)
    table.insert(found, shape)
end

-- New — must return true to continue; omitting stops iteration prematurely
local function scanCallback(fixture)
    table.insert(found, fixture)
    return true
end
```

---

## Verification Checklist for Agents

Phases must be completed in order. Do not mark a Phase 3 item Done if any
Phase 1 or Phase 2 item is still Pending.

| Section Identifier      | Depends On   | Status          | Validation Rule |
|-------------------------|--------------|-----------------|-----------------|
| `[PHASE-1-CONF]`        | —            | Pending / Done  | LÖVE window opens at 800×720 without crashing. |
| `[PHASE-1-COLOR]`       | PHASE-1-CONF | Pending / Done  | `compat.lua` is required before any graphics call; no 0–255 color errors in logs. |
| `[PHASE-1-KEYS]`        | PHASE-1-CONF | Pending / Done  | Keyboard navigation works in menus and controls screen. |
| `[PHASE-1-SETMODE]`     | PHASE-1-CONF | Pending / Done  | No deprecated API errors on window init. |
| `[PHASE-2-DRAW]`        | PHASE-1-*    | Pending / Done  | All textures render correctly across game modes and menus. |
| `[PHASE-2-SCISSOR]`     | PHASE-2-DRAW | Pending / Done  | Scissor bounds match screen under scale/fullscreen. |
| `[PHASE-2-IMAGEFONT]`   | PHASE-2-DRAW | Pending / Done  | Font glyphs render without nil errors or color distortion. |
| `[PHASE-3-FIXTURE-A]`   | PHASE-2-*    | Pending / Done  | `gameA.lua` pieces and walls react to forces correctly. |
| `[PHASE-3-FIXTURE-B]`   | PHASE-2-*    | Pending / Done  | `gameB.lua` / `gameBmulti.lua` fixtures remain functional. |
| `[PHASE-3-CALLBACKS]`   | PHASE-3-FIXTURE-* | Pending / Done | Collision signals fire correctly; sounds and line checks trigger. |
| `[PHASE-3-QUERY]`       | PHASE-3-CALLBACKS | Pending / Done | Line-clear mass scanning returns correct results; no early-exit truncation. |
