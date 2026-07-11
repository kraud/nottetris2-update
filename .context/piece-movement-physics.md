# Piece Movement & Rotation Physics Parameters

## Overview

This file catalogues every numeric parameter that controls how pieces move, fall, and rotate in the three playable modes — `gameA` (singleplayer "normal"), `gameB` (singleplayer "stack"), and `gameBmulti` (two-player stack and invade). The relevant code lives in `main.lua` (global tunables), `gameA.lua`, `gameB.lua`, and `gameBmulti.lua` (per-mode tunables and per-frame input handling).

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
  - `gameA.lua:341, 345` — `applyForce(±2000, 0)`
  - `gameB.lua:261, 265` — `applyForce(±2000, 0)`
  - `gameBmulti.lua:374, 378` (P1) and `410, 414` (P2) — `applyForce(±70, 0)`
- **What it controls:** The horizontal force applied every frame the left or right key is held. Applied at the body's world center (`getWorldCenter()`) so it produces no torque by itself.
- **Higher magnitude:** Snappier lateral acceleration, responsive movement, can "kick" pieces laterally through gaps.
- **Lower magnitude:** Sluggish lateral response, "ice-like" feel where pieces drift slowly, harder to make quick adjustments.

### Rotation `applyTorque` and angular-velocity cap

- **Set at:**
  - `gameA.lua:329-336` — torque ±10000, angular cap `getAngularVelocity() < 21` / `> -21`
  - `gameB.lua:249-256` — torque ±5000, angular cap `< 12` / `> -12`
  - `gameBmulti.lua:362-369, 398-405` — torque ±70, angular cap `< 3` / `> -3`
- **What it controls:** Torque is applied every frame the rotation key is held. The angular-velocity cap is a guard — when the current angular velocity is already at or past the cap, no additional torque is applied (the piece keeps spinning at the capped speed). This means the cap is the maximum steady-state rotation speed.
- **Higher torque:** Faster spin-up, rotation feels snappy.
- **Higher cap:** Higher maximum rotation speed, piece can spin faster before the guard stops adding torque.
- **Note:** In gameA the cap check is strict inequality (`< 21` / `> -21`), so the effective cap is just under 21 rad/s (~3.3 rotations/s). gameB uses `< 12` / `> -12` (~1.9 rot/s). gameBmulti uses `< 3` / `> -3` (~0.48 rot/s).

### Soft-drop `applyForce`

- **Set at:**
  - `gameA.lua:355` — `applyForce(0, 2000)`, hard-capped at y=500 in `gameA.lua:351-352`
  - `gameB.lua:275` — `applyForce(0, 2000)`, hard-capped at `difficulty_speed * 5` (`gameB.lua:271-272`)
  - `gameBmulti.lua:387` (P1) and `423` (P2) — `applyForce(0, 20)`, hard-capped at `difficulty_speed * 5` (`gameBmulti.lua:383-384, 419-420`)
- **What it controls:** Extra downward force applied every frame while the down key is held, making the piece fall faster than its natural gravity.
- **Higher magnitude:** Stronger pull, faster floor slam.
- **Lower magnitude:** Slow descent even when holding down.

### Air-brake `setLinearVelocity(x, y - 2000 * dt)`

- **Set at:** `gameA.lua:359`, `gameB.lua:279`, `gameBmulti.lua:391` (P1) and `427` (P2)
- **What it controls:** Applied each frame when the down key is NOT held. If the piece's current downward velocity exceeds `difficulty_speed`, it subtracts `2000 * dt` from the Y velocity, effectively braking the free-fall back toward the `difficulty_speed` threshold.
- **Higher coefficient (2000):** Stronger brake — piece returns to idle speed faster after a soft-drop release or gravity surge.
- **Lower coefficient:** Piece takes longer to slow down, free-falls further before the brake catches up.

### `setLinearDamping(0.5)`

- **Set at:**
  - `gameA.lua:126, 640, 1223` — `setLinearDamping(0.5)`
  - `gameB.lua:155` — `setLinearDamping(0.5)`
  - `gameBmulti.lua:474, 482, 653, 714` — `setLinearDamping(0.5)` (including on Mario/Luigi result-screen bodies)
- **What it controls:** Box2D linear damping coefficient per body. Applies a velocity-dependent drag force opposing motion. All modes use the same value.
- **Higher values:** Terminal lateral velocity reached faster, more "syrupy" feel; pieces stop quickly when no lateral force is applied.
- **Lower values:** Pieces slide forever when pushed (ice-like), harder to place precisely.

### `setInertia(blockrot)` with `blockrot = 10`

- **Set at:** `main.lua:172` (`blockrot = 10`); consumed in `gameA.lua:125, 566, 620`, `gameBmulti.lua:652, 713`. gameB does NOT call `setInertia` — it relies on Box2D's auto-computed inertia from mass and shape distribution.
- **Current value:** `10`
- **What it controls:** Overrides the body's moment of inertia, which determines how resistant the body is to angular acceleration from applied torque. The auto-computed inertia for a typical tetromino shape and default density is much lower.
- **Higher values:** Harder to spin (heavier-feeling rotation), piece resists rotation from gravity/lateral forces.
- **Lower values:** Easier to spin, piece may tumble on its own from gravity and collisions.

### `setBullet(true)`

- **Set at:** `gameA.lua:127, 641`, `gameB.lua:156`, `gameBmulti.lua:654, 715`
- **What it controls:** Enables continuous collision detection (CCD) for the body — prevents fast-moving pieces from tunneling through thin walls or the ground. Not a feel parameter but important for correctness.
- **Note:** Uniformly `true` in all modes; no tuning needed.

### Fixture density

- **Set at:**
  - `gameA.lua:130, 579, 634` — `love.physics.newFixture(body, shape)` without explicit density argument → Box2D default `1.0`
  - `gameB.lua:83, 94, 105, 116, 127, 138, 149` — `love.physics.newFixture(body, shape, density)` with `density = 0.1` (the `density` global from `main.lua:167`)
  - `gameBmulti.lua:657, 718` — `love.physics.newFixture(body, shape)` without density argument → Box2D default `1.0`
- **What it controls:** Together with the shape area, density determines each fixture's mass contribution. The body's total mass is the sum of fixture masses. Higher mass means the same applied force produces less acceleration (F = ma).
- **Higher values:** Heavier piece — same lateral/down forces produce less acceleration, more "weighty" feel.
- **Lower values:** Lighter piece — same forces produce more acceleration, snappier movement.
- **Key insight:** gameB's explicit `density = 0.1` (10× lower than the other two modes) means its pieces have ~10× less mass for the same shape. Combined with the same lateral forces (±2000), this explains why gameB pieces accelerate much faster than gameA pieces despite identical input magnitudes.

### `world:update(dt, 8, 3)`

- **Set at:** `gameA.lua:366`, `gameB.lua:284`, `gameBmulti.lua:328`
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

| Parameter | gameA | gameB | gameBmulti (P1/P2) | 0.7.2 intent (inferred) |
|---|---|---|---|---|
| `meter` | 30 | 30 | 30 | world-bounds MTP ratio |
| Gravity Y | 500 | 500 | 500 | "500 px/s²" |
| `difficulty_speed` (initial) | 100 | 100 | 100 | px/s fall speed |
| `difficulty_speed` (ramp) | 100 + levelscore * 7 | 100 (no ramp) | 100 (no ramp) | ramp for progressive difficulty |
| Lateral `applyForce` | ±2000 | ±2000 | ±70 | pixel-force per frame |
| Rotation torque | ±10000 | ±5000 | ±70 | pixel-torque per frame |
| Rotation angular cap | `< 21` / `> -21` | `< 12` / `> -12` | `< 3` / `> -3` | max rotation speed |
| Soft-drop force | +2000 | +2000 | +20 | pixel-force per frame |
| Soft-drop cap | 500 | `difficulty_speed * 5` | `difficulty_speed * 5` | terminal pixel-velocity |
| Air-brake coefficient | 2000 | 2000 | 2000 | pixel-velocity reduction |
| `setLinearDamping` | 0.5 | 0.5 | 0.5 | Box2D drag coefficient |
| `setInertia(blockrot)` | `blockrot`=10 | *(not set)* | `blockrot`=10 | moment of inertia (kg·m²) |
| `setBullet` | true | true | true | CCD toggle |
| Fixture density | default 1.0 | 0.1 | default 1.0 | mass per unit area |
| `world:update` iterations | (8, 3) | (8, 3) | (8, 3) | solver accuracy |
| Wall friction | 0.00001 | 0.00001 | 0.0001 | Coulomb friction |
| `nextpiecerotspeed` | 1 | 1 | 1 | preview spin (cosmetic) |

---

## Why the Three Modes Feel Inconsistent

### 1. `meter` is dead code

All three game files assign `meter = 30` before calling `love.physics.newWorld`, but LÖVE 0.8.0 and later removed the world-bounds form of `newWorld`. The MTP ratio is now a fixed engine default (30 in LÖVE 11.5). The `meter` variable is read by nothing and is purely a leftover from the 0.7.2 migration. It has no effect on any mode's feel.

### 2. The same number means a different thing in 0.7.2 vs 11.5

In LÖVE 0.7.2 the world-bounds form of `newWorld` implicitly defined pixels-per-meter from the field dimensions. A 32-pixel body corresponded to ~1.07 m (at MTP=30). Forces and torques were interpreted in pixel-units: a force of "2000" meant "2000 pixel-units/s²".

In LÖVE 11.5 the world has no implicit MTP. LÖVE's wrapper applies a fixed MTP=30 conversion to *position* coordinates passed to `newBody` and shape constructors (so positions match), but **forces and torques pass through unconverted**. A value of `2000` passed to `applyForce` is now interpreted as 2000 Newtons (N) — a real SI force. Since 1 N = 1 kg·m/s², and the pixel-to-meter ratio is 30:1, the effective force in pixel-units/s² is 2000 × 30 = 60,000 — roughly 30× larger than the developer's original intent.

This means every `applyForce`, `applyTorque`, and gravity value is effectively 30× too large in the new engine *unless* the developer has manually retuned them to compensate. gameA is closest to correct because that mode has been retuned. The other modes have not.

### 3. The three modes were independently tuned, not normalized

- **gameA** has been retuned by the developer to feel approximately correct. Its per-frame forces (±2000 lateral, +2000 soft-drop, ±10000 torque) and angular cap (21) reflect tuned values that happen to work despite the unit mismatch. The lack of explicit fixture density (default 1.0) means piece mass is determined by the auto-computed area × 1.0, which is roughly 10× heavier than gameB's pieces.

- **gameB** was left at the original pixel-tuned magnitudes. Under the new unit interpretation the forces are effectively 30× too large. This is partially masked by gameB's explicit low fixture density (`0.1` vs the default `1.0`), which scales the body's mass down 10×, so the effective acceleration is ~3× higher than gameA's rather than 30× higher. The angular cap is 12 rad/s (~1.9 rotations/s) vs gameA's 21 — still slower despite the torque being half. Combined, this makes gameB feel "way too fast" in translation but not dramatically faster in rotation.

- **gameBmulti** uses a completely different magnitude regime: ±70 for both lateral forces and rotation torque (vs ±2000 and ±10000 in gameA). This is ~30× lower than gameA, matching the MTP ratio. However, the soft-drop force is 20 (100× lower than gameA's 2000), and the angular cap is 3 rad/s (~0.48 rotations/s) — 7× lower than gameA's cap. The very low angular cap is what makes rotation feel "incredibly slow." The fixture density is the default 1.0 (same as gameA). The per-frame forces at ±70 are consistent with having been pre-divided by MTP=30, but the caps were set without a reference baseline, resulting in an asymmetric feel: lateral movement is passable, rotation is painfully slow, and the soft-drop barely accelerates the piece.

---

## Proposal to Fix (Concrete Patch Sketch)

> **This is a documentation-only deliverable. No values in code are modified by this plan. The numbers below are a sketch for a future implementation pass.**

The consistent fix across all three modes is to account for the LÖVE 0.7.2 → 11.5 force-unit mismatch. The engine's MTP=30 means every force/torque/gravity value that was tuned in pixel-units must be divided by 30 to produce the same effective acceleration under new SI-unit interpretation.

### Step 1: Normalize gravity (all modes)

Reduce `world:newWorld(0, 500, true)` → `world:newWorld(0, 16.7, true)`.

`500 / 30 ≈ 16.7` — this maps the original "500 px/s²" onto the new SI units as "16.7 m/s²" (~1.7× Earth gravity). This is the single change that brings the code back in line with the developer's original tuning intent.

### Step 2: gameA — minimal changes (already closest)

- **Gravity:** 16.7 (from Step 1)
- **Lateral force:** Keep ±2000 (already retuned)
- **Soft-drop force:** Keep +2000 (already retuned)
- **Rotation torque:** Keep ±10000 (already retuned)
- **Angular cap:** Optionally raise from 21 to ~28 rad/s if the user confirms rotation still feels "a little bit too slow"
- **Fixture density:** Keep default 1.0

### Step 3: gameB — scale forces down, fix density

- **Gravity:** 16.7 (from Step 1)
- **Lateral force:** Scale from ±2000 → ±67 (`2000 / 30 ≈ 67`) to match gameA's effective acceleration
- **Soft-drop force:** Scale from 2000 → 67 (`2000 / 30 ≈ 67`)
- **Soft-drop cap:** Lower from `difficulty_speed * 5` (= 500) to `difficulty_speed` (= 100) for parity with the release-mode brake
- **Rotation torque:** Scale from 5000 → ~330 (`5000 / 30 ≈ 167`; or `10000 / 30 ≈ 333` to match gameA's scaled torque)
- **Angular cap:** Raise from 12 to 21 to match gameA's max
- **Fixture density:** Change from 0.1 → 1.0 to match gameA and normalize mass
- **Air-brake coefficient:** Keep 2000 (same across all modes)

### Step 4: gameBmulti — scale forces up, raise caps

- **Gravity:** 16.7 (from Step 1)
- **Lateral force:** Scale from ±70 → ±2100 (`70 × 30`) to match gameA's effective acceleration
- **Soft-drop force:** Scale from 20 → 600 (`20 × 30`)
- **Soft-drop cap:** Keep at `difficulty_speed * 5` (= 500)
- **Rotation torque:** Scale from ±70 → ±2100 (`70 × 30`)
- **Angular cap:** Raise from 3 to 21 to match gameA
- **Fixture density:** Keep default 1.0
- **Air-brake coefficient:** Keep 2000

### Expected feel target

All three modes should the same baseline feel as gameA (the closest-to-correct reference). After applying these numeric changes, each mode's pieces should respond to left/right input, soft-drop, and rotation with the same acceleration and speed caps. Fine-tuning may still be needed because:

- The multiplayer field is wider (P1 playfield ~352 px in gameBmulti vs ~328 in gameA), so pieces travel a longer distance edge-to-edge
- gameB's lack of `setInertia` means rotation inertia is auto-computed differently than gameA/gameBmulti's fixed `blockrot=10`
- gameB and gameBmulti lack the `difficulty_speed` ramp that gameA has, so they won't progressively speed up

---

## What This File Does NOT Propose to Do

This is a **documentation-only deliverable**. No values in any code file are modified by the plan that produces this file. The parameter reference, diagnosis, and per-mode state table are grounded in the code as it exists today; the proposal section provides a numeric sketch for a future implementer. Deleting the dead `meter` variable, normalizing fixture densities, removing the `density` global from `main.lua`, or any other code changes are explicitly out of scope for this document.
