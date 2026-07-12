# Runtime Tunables: `debug_params`

## What it is

`debug_params` is a Lua table set as a global in `main.lua:601–610` (when
options.txt exists, the keys are read from there; line 580–582 parses
`debug_<key>=<value>` lines) and at `main.lua:618–627` (default values when no
options.txt exists). It is the central tuning surface for all three game modes.

## Where it is edited

The F12 key in the title screen opens `gameBdebug.lua`'s panel (the right-hand
sliding overlay). Each key is shown with a text field; click to focus, type a
new value, press Return. The `step` field controls how much the +/- buttons
bump a value (default 100). Values are written to `options.txt` via the same
`saveoptions()` path as scale/volume/hue/fullscreen.

## Schema

| Key                  | Default | Read in                                                                  |
|----------------------|---------|--------------------------------------------------------------------------|
| `difficulty_speed`   | 100     | `gameA.lua:7, 1038` (initial + per-level ramp), `gameB.lua:6`, `gameBmulti.lua:31` |
| `lateral_force`      | 2000    | `gameA.lua:339, 343`; `gameB.lua:261, 265`; `gameBmulti.lua:374, 378, 410, 414` |
| `rotation_torque`    | 5000    | `gameA.lua:328, 333`; `gameB.lua:250, 255`; `gameBmulti.lua:363, 368, 399, 404` |
| `angular_cap`        | 12      | `gameA.lua:327, 332`; `gameB.lua:249, 254`; `gameBmulti.lua:362, 367, 398, 403` |
| `soft_drop_force`    | 2000    | `gameA.lua:353`; `gameB.lua:275`; `gameBmulti.lua:387, 423`               |
| `soft_drop_cap_mul`  | 5       | `gameA.lua:349, 350`; `gameB.lua:271, 272`; `gameBmulti.lua:383, 384, 419, 420` |
| `air_brake_coeff`    | 2000    | `gameA.lua:357`; `gameB.lua:279`; `gameBmulti.lua:391, 427`               |
| `step`               | 100     | `gameBdebug.lua` panel UI only (the increment of the +/- buttons)         |

## How persistence works

When `options.txt` is present, `main.lua:580–582` parses each line that starts
with `debug_` and writes `key=tonumber(value)` into the `debug_params` table.
On save, `main.lua:642–646` iterates `pairs(debug_params)` and writes one
`debug_<key>=<value>` line per key.

## Adding a new tunable

1. Add the key to BOTH default tables in `main.lua` (lines 601–610 and 618–627).
2. Add a label/value row in `gameBdebug.lua`'s panel (the `panel_rows` table
   and the matching `gameBdebug_draw_panel` / `gameBdebug_handle_mouse` /
   `gameBdebug_handle_keypressed` sites).
3. Read it in the game mode(s) that should use it.
4. If a default value is meaningful to gameplay, mention it in
   `piece-movement-physics.md`.
