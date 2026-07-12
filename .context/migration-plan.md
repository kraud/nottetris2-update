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
- **Status:** Done
- **Action:** `conf.lua` already uses `t.window.*` and `t.version = "11.5"` (lines 5–10); no further action required.
- **Validation:** Window opens at 800×720.


### `[PHASE-1-COLOR]` Color Normalization Wrapper

- **Target File:** `compat.lua`
- **Status:** Done
- **Action:** `compat.lua` is `require`d at the top of `main.lua` (line 1); monkey-patches `love.graphics.setColor` / `getColor` to translate 0–255 integer ranges to 0.0–1.0 floats. No 0–255 color errors in logs.
- **Validation:** `require("compat")` is the first line of `main.lua`; no 0–255 color errors in logs.

### `[PHASE-1-KEYS]` Keyboard Constant Audit

- **Target Files:** `main.lua`, `menu.lua`, `controls.lua`
- **Status:** Done
- **Action:** `compat.lua:42–46` translates `kpenter` to `return` inside `love.keyboard.isDown`. `controls.lua:8` is the only string-key lookup naming `kpenter`; it is funnelled through `love.keyboard.isDown` so the shim catches it. No raw `"kpenter"` lookups remain outside the shim.
- **Validation:** `grep -n 'kpenter' controls.lua main.lua gameA.lua gameB.lua gameBmulti.lua` returns only `controls.lua:8` and `compat.lua:43,50`.

### `[PHASE-1-SETMODE]` Window Mode Initialization

- **Target File:** `main.lua`
- **Status:** Done
- **Action:** `main.lua:29, 32, 607, 609, 682, 1109, 1119, 1137` all call `love.window.setMode`. No `love.graphics.setMode` calls remain.
- **Validation:** `grep -n 'love.graphics.setMode' main.lua` returns no hits; `love.window.setMode` is used instead.

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
- **Action:** `love.graphics.newImageFont` is still present in LÖVE 11.5.
  `main.lua:460–485`'s `newPaddedImageFont` helper pads the source ImageData
  to power-of-two dimensions and calls `love.graphics.newImageFont(padded, glyphs, 1)`
  directly. The `+1` extraspacing restores the inter-glyph advance that the 0.7.2
  font format provided. No migration was needed — only the power-of-two padding
  workaround.

---

## Phase 3: Physics & Box2D Refactor (`[PHASE-3]`)

**Objective:** Overhaul the physics engine structure to match the modern Box2D
wrapper. **This is the highest-risk phase. Do not begin until Phase 1 and
Phase 2 checklists are fully green.**

### `[PHASE-3-FIXTURE-CREATE]` Separation of Shapes and Bodies (Modern Pattern)

- **Target Files:** `gameA.lua`, `gameB.lua`, `gameBmulti.lua`
- **Status:** Done
- **Action:** All three game modules build bodies, shapes, and fixtures through the modern API (gameA:36–133, gameB:29–161, gameBmulti:81–116, 449–470, 595–709). Body types are passed as strings (`"static"` / `"dynamic"`). User-data, friction, restitution, density, category, and mask are set on the fixture. Mass data is recomputed with `body:resetMassData()`.
- **Validation:** Bodies built via `newBody(..., "static" / "dynamic")`, shapes standalone, fixtures via `newFixture(body, shape)`.

### `[PHASE-3-CALLBACKS]` Collision Callback Migration

- **Target Files:** `gameA.lua`, `gameB.lua`, `gameBmulti.lua`
- **Status:** Done
- **Action:** `world:setCallbacks(beginContactA)` (gameA:55), `world:setCallbacks(collideB)` (gameB:49), and `world:setCallbacks(beginContactBmulti)` (gameBmulti:117) pass only the begin-contact slot; the remaining three slots default to `nil` and LÖVE 11.5 skips the call when a slot is nil. The callback bodies read `fixture:getUserData()` on both arguments and compare against the user-data the fixtures were tagged with at construction time.
- **Validation:** `beginContactA` / `collideB` / `beginContactBmulti` read `fixture:getUserData()` on both arguments; line-clear sound fires on contact.

### `[PHASE-3-DESTROY]` Destroy Lifecycle (`release()` → `destroy()`)

- **Target Files:** `gameA.lua`, `gameB.lua`, `gameBmulti.lua`
- **Status:** Done
- **Action:** `:release()` replaced with `:destroy()` on all bodies and fixtures (gameA.lua:502, 513, 557, 1197; gameB.lua:340 targets `wallfixtures[2]`). `gameA.lua:672` left as `:release()` — standalone shapes not bound to a fixture. `gameBmulti.lua:436–437` was already correct.
- **Validation:** `grep -nE ':release\(\)' gameA.lua gameB.lua gameBmulti.lua` returns only `gameA.lua:672` (standalone shape hit) — no body/fixture release calls remain.

### `[PHASE-3-RAYCAST]` Fixture:rayCast Return Value Fix

- **Target File:** `gameA.lua`
- **Status:** Done
- **Action:** `gameA.lua:396–406 getintersectX` rewritten to read the 3rd return value (`fraction`) from `Fixture:rayCast` instead of the 1st return (surface-normal x). Left/right intersection points are now computed correctly as `start + (end - start) * fraction`.
- **Validation:** `getintersectX` reads the 3rd return of `Fixture:rayCast`; line-density scan produces the correct split-Y for a fully populated row.
---

## Verification Checklist for Agents
Phase 1 through Phase 3 are complete. All 11 checklist items are marked Done.

| Section Identifier             | Depends On                | Status | Validation Rule |
|--------------------------------|---------------------------|--------|-----------------|
| `[PHASE-1-CONF]`               | —                         | Done   | Window opens at 800×720. |
| `[PHASE-1-COLOR]`              | PHASE-1-CONF              | Done   | `require("compat")` is the first line of `main.lua`; no 0–255 color errors in logs. |
| `[PHASE-1-KEYS]`               | PHASE-1-CONF              | Done   | `grep -n 'kpenter' controls.lua main.lua gameA.lua gameB.lua gameBmulti.lua` returns only `controls.lua:8` and `compat.lua:43,50`. |
| `[PHASE-1-SETMODE]`            | PHASE-1-CONF              | Done   | `grep -n 'love.graphics.setMode' main.lua` returns no hits; `love.window.setMode` is used instead. |
| `[PHASE-2-DRAW]`               | PHASE-1-*                 | Done   | `compat.lua:20` aliases `drawq`; `grep -n 'drawq' gameA.lua gameB.lua gameBmulti.lua menu.lua failed.lua rocket.lua` returns hits that all resolve through the shim. |
| `[PHASE-2-SCISSOR]`            | PHASE-2-DRAW              | Done   | All `setScissor` arguments are derived from `scale`, `fullscreenoffsetX/Y` only. |
| `[PHASE-2-IMAGEFONT]`          | PHASE-2-DRAW              | Done   | `love.graphics.newImageFont` exists in LÖVE 11.5; `newPaddedImageFont` runs at startup and `tetrisfont` / `whitefont` are non-nil. |
| `[PHASE-3-FIXTURE-CREATE]`     | PHASE-2-*                 | Done   | Bodies built via `newBody(..., "static" / "dynamic")`, shapes standalone, fixtures via `newFixture(body, shape)`. |
| `[PHASE-3-CALLBACKS]`          | PHASE-3-FIXTURE-CREATE    | Done   | `beginContactA` / `collideB` / `beginContactBmulti` read `fixture:getUserData()` on both arguments; line-clear sound fires on contact. |
| `[PHASE-3-DESTROY]`            | PHASE-3-FIXTURE-CREATE    | Done   | `grep -nE 'release\(\)' gameA.lua gameB.lua gameBmulti.lua` returns zero hits on body/fixture (only the standalone-shape hit at `gameA.lua:672` may remain); bodies / fixtures are removed from the Box2D world when a line is cut or a player fails. `gameBmulti.lua:436–437` are the current destroy lines for the ground wall fixtures. |
| `[PHASE-3-RAYCAST]`            | PHASE-3-CALLBACKS         | Done   | `getintersectX` reads the 3rd return of `Fixture:rayCast`; line-density scan produces the correct split-Y for a fully populated row. |
| `[POST-MIGRATION-PHYSICS-DENSITY]` | — | Done | All three game modes read `debug_params`; fixtures use `density = 0.1`; `setInertia` is gone. See `piece-movement-physics.md` and `gameBdebug.lua` for the current state. |
