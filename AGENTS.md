# AGENTS.md

## Project
Not Tetris 2 is a LÖVE 11.5 physics-based parody of Tetris (originally built for LÖVE 0.7.2). The 0.7.2 → 11.5 migration is complete. See `.context/codebase-context.md` for the full file map and per-module responsibilities.

## Context files
| File | Covers |
|---|---|
| `codebase-context.md` | Project overview, file structure map, and per-file logic roles (load-bearing — read first). |
| `migration-plan.md` | LÖVE 0.7.2 → 11.5 migration phases (engine boot, graphics, Box2D refactor) and the verification checklist; phases 1–3 are marked Done. |
| `physics-refactor-guide.md` | Cheatsheet for the Box2D shape/fixture migration: bodies, fixtures, sensors, user data, collision filtering, callback signatures. |
| `piece-movement-physics.md` | Catalogue of every physics parameter that affects piece feel in `gameA`, `gameB`, `gameBmulti`, plus a diagnosis of the per-mode feel inconsistency. |
| `debug-params.md` | Schema and defaults for the `debug_params` runtime tuning surface used by all three game modes; edited live via the F12 panel. |
| `agent-env.md` | How to run the game from source on macOS and read debug output during the test loop. |

## Running the game
Run from the repo root with the system LÖVE 11.5 binary:

```bash
/Applications/love.app/Contents/MacOS/love .
```

## Testing policy
Do not playtest the game yourself. The agent's job is to confirm the game boots up to the title screen / active gamestate; substantive gameplay testing is the developer's responsibility.

## Code style
- Prioritise clarity. When logic is non-obvious, add a comment explaining *why* the code exists, not what it does.
- Debug, diagnostic, or temporary code must carry a visible comment explaining its presence and intended removal.
- This codebase is an extension of work by another developer. Preserve the original intent comments. When you change the behaviour a comment describes, update that comment in the same edit so the original goal is not lost.
