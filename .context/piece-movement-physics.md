# Piece Movement & Rotation Physics Parameters

## Overview

This file catalogues every numeric parameter that controls how pieces move, fall, and rotate in the three playable modes — `gameA` (singleplayer "normal"), `gameB` (singleplayer "stack"), and `gameBmulti` (two-player stack and invade). The relevant code lives in `main.lua` (global tunables), `gameA.lua`, `gameB.lua`, and `gameBmulti.lua` (per-mode tunables and per-frame input handling).

All three game modes read the same `debug_params` table (defined in `main.lua:601–610` / `618–627`, edited live via the F12 panel in `gameBdebug.lua`); see `debug-params.md` for the schema and defaults.

All input is uniformly per-frame `applyForce` while a key is held — there is no edge-triggered movement. The physics world steps at `world:update(dt, 8, 3)` each frame.

---

## Parameter Reference

### `meter`

- **Set at:** `main.lua` line 170 (assigned as a `_load` local in each game file at `gameA.lua:23`, `gameB.lua:14`, `gameBmulti.lua:68`)
- **Current value:** `30` (all modes)
- **What it controls:** In LÖVE 0.7.2 the world-bounds form of `love.physics.newWorld(x1, y1, x2, y2, gx, gy, sleep)` implicitly set a pixels-per-meter ratio based on the bound dimensions. The `meter` variable was the intended MTP ratio. In LÖVE 0.8.0+ and 11.5, the world-bounds form was removed — `newWorld(gx, gy, sleep)` has no bounds and MTP is fixed at the engine default (30). The variable is now dead code: stored but never read.
- **Higher values:** N/A (dead code; changing it has no effect on physics)

### Gravity (world Y)

- **Set at:** `gameA.lua:24`, `gameB.lua:15`, `gameBmulti.lua:69`
- **Current value:** `500` (all modes — passed as the `gy` argument to `love.physics.newWorld(0, 500, true)`)
- **What it controls:** The downward gravitational acceleration applied to every dynamic body in the world. Under LÖVE 11.5 with the default MTP=30, this is 500 m/s² — approximately 51× Earth gravity. In LÖVE 0.7.2 the world bounds made the unit ambiguous (px/s²); the same value was presumably intended as pixel-based gravity. Under the new SI-unit interpretation it is extremely large.
- **Higher values:** Pieces fall faster, slam into the ground harder, bounce more violently on landing.
- **Lower values:** Gentle floaty fall; pieces settle softly on the stack.

### `difficulty_speed`

- **Set at:** `gameA.lua:7`, `gameB.lua:6`, `gameBmulti.lua:31` (initial value)
- **Ramp:** `gameA.lua:1042` — `difficulty_speed = 100 + levelscore * 7` (increments every 10 lines cleared). gameB and gameBmulti do not have this ramp; they remain at the initial 100.
- **Current value:** 100 initially (all modes); ramps up in gameA.
- **What it controls:** The initial downward velocity assigned to a fresh piece via `setLinearVelocity(0, difficulty_speed)` at `gameA.lua:71`, `gameB.lua:63`, `gameBmulti.lua:569, 594`. Also used as the soft-drop velocity cap (`if y > difficulty_speed` / `difficulty_speed * 5`) and the threshold at which the air brake engages.
- **Higher values:** Faster gravity at piece spawn, faster idle fall speed, higher soft-drop cap.
- **Lower values:** Slower spawn speed, pieces idle-fall slower, larger window for lateral positioning.

### Lateral `applyForce`

- **Set at:**
  - `gameA.lua:339, 343` — `applyForce(±debug_params.lateral_force, 0)`
  - `gameB.lua:261, 265` — `applyForce(±debug_params.lateral_force, 0)`
  - `gameBmulti.lua:374, 378` (P1) and `410, 414` (P2) — `applyForce(±debug_params.lateral_force, 0)`
- **What it controls:** The horizontal force applied every frame the left or right key is held. Applied at the body's world center (`getWorldCenter()`) so it produces no torque by itself.
- **Higher magnitude:** Snappier lateral acceleration, responsive movement, can "kick" pieces laterally through gaps.
- **Lower magnitude:** Sluggish lateral response, "ice-like" feel where pieces drift slowly, harder to make quick adjustments.

### Rotation `applyTorque` and angular-velocity cap

- **Set at:**
  - `gameA.lua:327-335` — torque `±debug_params.rotation_torque`, angular cap `getAngularVelocity() < debug_params.angular_cap` / `> -debug_params.angular_cap`
  - `gameB.lua:249-257` — torque `±debug_params.rotation_torque`, angular cap `getAngularVelocity() < debug_params.angular_cap` / `> -debug_params.angular_cap`
  - `gameBmulti.lua:362-369` (P1) and `398-405` (P2) — torque `±debug_params.rotation_torque`, angular cap `getAngularVelocity() < debug_params.angular_cap` / `> -debug_params.angular_cap`
- **What it controls:** Torque is applied every frame the rotation key is held. The angular-velocity cap is a guard — when the current angular velocity is already at or past the cap, no additional torque is applied (the piece keeps spinning at the capped speed). This means the cap is the maximum steady-state rotation speed.
- **Higher torque:** Faster spin-up, rotation feels snappy.
- **Higher cap:** Higher maximum rotation speed, piece can spin faster before the guard stops adding torque.
- **Note:** All three modes now use `debug_params.angular_cap` (default 12) for the angular velocity guard. The cap check is strict inequality (`< angular_cap` / `> -angular_cap`), so the effective cap is just under `angular_cap` rad/s.

### Soft-drop `applyForce`

- **Set at:**
  - `gameA.lua:353` — `applyForce(0, debug_params.soft_drop_force)`, hard-capped at `debug_params.difficulty_speed * debug_params.soft_drop_cap_mul` (`gameA.lua:349-350`)
  - `gameB.lua:275` — `applyForce(0, debug_params.soft_drop_force)`, hard-capped at `difficulty_speed * debug_params.soft_drop_cap_mul` (`gameB.lua:271-272`)
  - `gameBmulti.lua:387` (P1) and `423` (P2) — `applyForce(0, debug_params.soft_drop_force)`, hard-capped at `difficulty_speed * debug_params.soft_drop_cap_mul` (`gameBmulti.lua:383-384, 419-420`)
- **What it controls:** Extra downward force applied every frame while the down key is held, making the piece fall faster than its natural gravity.
- **Higher magnitude:** Stronger pull, faster floor slam.
- **Lower magnitude:** Slow descent even when holding down.

### Air-brake `setLinearVelocity(x, y - 2000 * dt)`

- **Set at:** `gameA.lua:357`, `gameB.lua:279`, `gameBmulti.lua:391` (P1) and `427` (P2)
- **What it controls:** Applied each frame when the down key is NOT held. If the piece's current downward velocity exceeds `difficulty_speed`, it subtracts `debug_params.air_brake_coeff * dt` from the Y velocity, effectively braking the free-fall back toward the `difficulty_speed` threshold.
- **Higher coefficient:** Stronger brake — piece returns to idle speed faster after a soft-drop release or gravity surge.
- **Lower coefficient:** Piece takes longer to slow down, free-falls further before the brake catches up.

### `setLinearDamping(0.5)`

- **Set at:**
  - `gameA.lua:125, 636, 1219` — `setLinearDamping(0.5)`
  - `gameB.lua:155` — `setLinearDamping(0.5)`
  - `gameBmulti.lua:474, 482, 652, 712` — `setLinearDamping(0.5)` (including on Mario/Luigi result-screen bodies)
- **What it controls:** Box2D linear damping coefficient per body. Applies a velocity-dependent drag force opposing motion. All modes use the same value.
- **Higher values:** Terminal lateral velocity reached faster, more "syrupy" feel; pieces stop quickly when no lateral force is applied.
- **Lower values:** Pieces slide forever when pushed (ice-like), harder to place precisely.

### `setBullet(true)`

- **Set at:** `gameA.lua:126, 637`, `gameB.lua:156`, `gameBmulti.lua:653, 713`
- **What it controls:** Enables continuous collision detection (CCD) for the body — prevents fast-moving pieces from tunneling through thin walls or the ground. Not a feel parameter but important for correctness.
- **Note:** Uniformly `true` in all modes; no tuning needed.

### Fixture density

- **Set at:**
  - `gameA.lua:129, 576–577, 630–631` — `love.physics.newFixture(body, shape, density)` with `density = 0.1`
  - `gameB.lua:83–152` — all `love.physics.newFixture(body, shape, density)` with `density = 0.1`
  - `gameBmulti.lua:656, 716` — `love.physics.newFixture(body, shape, density)` with `density = 0.1`
- **What it controls:** Together with the shape area, density determines each fixture's mass contribution. The body's total mass is the sum of fixture masses. Higher mass means the same applied force produces less acceleration (F = ma).
- **Higher values:** Heavier piece — same lateral/down forces produce less acceleration, more "weighty" feel.
- **Lower values:** Lighter piece — same forces produce more acceleration, snappier movement.
- **Key insight:** All three modes now use the same `density = 0.1` global, so cross-mode mass differences are eliminated. The 30× force-unit scaling analysis in the "What This File Does NOT Propose to Do" section remains as historical context.

### `world:update(dt, 8, 3)`

- **Set at:** `gameA.lua:364`, `gameB.lua:284`, `gameBmulti.lua:328`
- **What it controls:** Steps the Box2D physics simulation each frame. Velocity iteration count = 8, position iteration count = 3. Higher iterations produce more accurate constraint solving (fewer missed collisions, better joint behavior) at a CPU cost.
- **Note:** Uniform across all modes; not a feel parameter per se.

### Wall friction (`setFriction`)

- **Set at:**
  - `gameA.lua:40, 45` — `setFriction(0.00001)` on left and right wall fixtures
  - `gameB.lua:37, 41` — `setFriction(0.00001)` on left and right wall fixtures
  - `gameBmulti.lua:89, 94, 107, 113` — `setFriction(0.0001)` on all wall fixtures (P1 left/right, P2 left/right)
- **What it controls:** Coulomb friction coefficient between the piece and wall surfaces. Near-zero values ensure pieces slide along walls without sticking or bouncing.
- **Higher values:** Pieces may stick to walls when pressed against them, or bounce on collision.
- **Lower values:** Pieces slide freely along walls.
- **Note:** gameBmulti uses 0.0001 (10× higher than gameA/gameB's 0.00001). The difference is negligible at these extremely low values — both are effectively frictionless.

### `nextpiecerotspeed = 1` rad/s

- **Set at:** `main.lua:163`
- **What it controls:** Rotation speed of the next-piece preview in the HUD. Unrelated to gameplay physics.
- **Note:** A cosmetic parameter; included for completeness.

---

## Per-Mode State Table

| Parameter | gameA | gameB | gameBmulti (P1/P2) |
|---|---|---|---|
| `meter` | 30 (dead) | 30 (dead) | 30 (dead) |
| Gravity Y | 500 | 500 | 500 |
| `difficulty_speed` (initial) | `debug_params.difficulty_speed` (100) | `debug_params.difficulty_speed` (100) | `debug_params.difficulty_speed` (100) |
| `difficulty_speed` (ramp) | `debug_params.difficulty_speed + levelscore * 7` | (no ramp) | (no ramp) |
| Lateral `applyForce` | `±debug_params.lateral_force` (2000) | `±debug_params.lateral_force` (2000) | `±debug_params.lateral_force` (2000) |
| Rotation torque | `±debug_params.rotation_torque` (5000) | `±debug_params.rotation_torque` (5000) | `±debug_params.rotation_torque` (5000) |
| Rotation angular cap | `±debug_params.angular_cap` (12) | `±debug_params.angular_cap` (12) | `±debug_params.angular_cap` (12) |
| Soft-drop force | `+debug_params.soft_drop_force` (2000) | `+debug_params.soft_drop_force` (2000) | `+debug_params.soft_drop_force` (2000) |
| Soft-drop cap | `difficulty_speed * soft_drop_cap_mul` (500) | `difficulty_speed * soft_drop_cap_mul` (500) | `difficulty_speed * soft_drop_cap_mul` (500) |
| Air-brake coefficient | `debug_params.air_brake_coeff` (2000) | `debug_params.air_brake_coeff` (2000) | `debug_params.air_brake_coeff` (2000) |
| `setLinearDamping` | 0.5 | 0.5 | 0.5 |
| `setInertia` | not called | not called | not called |
| `setBullet` | true | true | true |
| Fixture density | `density` (0.1) | `density` (0.1) | `density` (0.1) |
| `world:update` iterations | (8, 3) | (8, 3) | (8, 3) |
| Wall friction | 0.00001 | 0.00001 | 0.0001 |
| `nextpiecerotspeed` | 1 | 1 | 1 |

---

## Post-Fix State

The three modes now share the same input source (`debug_params`) and the same fixture density (`0.1`). Cross-mode feel differences are now driven by:

1. **`difficulty_speed` ramp (gameA only):** gameA increments `difficulty_speed` by `levelscore * 7` every 10 lines cleared (line 1038). gameB and gameBmulti stay at the initial value. This makes gameA pieces progressively faster as the player advances.

2. **Per-mode wall-friction constant:** gameBmulti uses `0.0001` vs gameA/gameB's `0.00001`. Both are effectively frictionless at these values — the difference is negligible.

3. **Multiplayer field width:** gameBmulti's playfield columns are 320 px each (vs gameA's ~328 px single field), and all rendering uses `mpscale` rather than `scale`. This affects perceived travel distances but not the underlying physics.

The legacy 30× force-unit scaling analysis remains in the "What This File Does NOT Propose to Do" section as historical context but is no longer the active diagnosis — the proposal that addressed it has been implemented.

---

## Status

All four steps of the proposal documented in the original version of this file have been implemented in the `001-fix-games-physics-density.md` change set.

- gameA, gameB, and gameBmulti all read identical `debug_params` keys for lateral force, rotation torque, angular cap, soft-drop force, soft-drop cap multiplier, and air-brake coefficient.
- All fixture creation passes `density = 0.1` (the `density` global from `main.lua:168`).
- The dead `setInertia(blockrot)` calls in gameA and gameBmulti have been removed.
- `meter = 30` remains as dead code in all three mode loads.

The per-mode parameter table above reflects the current code. The runtime tuning surface is documented in `debug-params.md`.

---

## What This File Does NOT Propose to Do

The proposal section was implemented in the `001-fix-games-physics-density.md` change set. Values in code were modified to match the user's tuning intent. The parameter reference and per-mode state table above reflect the current code. The runtime tuning surface is documented in `debug-params.md`.

The legacy 30× force-unit scaling analysis remains in this section as historical context — it explains *why* the original values felt inconsistent, but the active diagnosis has been resolved by the implementation.
