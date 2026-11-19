## Goal

Prevent the player from starting a run (via `[R]` Run or `[Spc]` Step) unless at least one pusher tile is placed on the grid. Without a pusher, the matrix has no way to move, so running immediately ends in a "stuck" result — this is confusing and unhelpful.

## Affected files

- `game/scenes/matrix_scene.lua` — the only file that handles `key_pressed` and `start_run`/`do_step` entry points

## What changes

- In `key_pressed`, before calling `start_run()` (the `r` branch) or `do_step()` (the `space` branch), check whether `_pusher_list()` returns at least one entry.
- If no pusher is present, block the action and set `self.status = "no_pusher"` so the HUD can display a brief message.
- In `draw_palette` (or wherever the status banner is rendered), render a readable hint for `"no_pusher"` — e.g. `"Place a pusher first"`.
- The check applies equally to `[R]` and `[Spc]`.

## What stays the same

- Puzzle-locked pushers (pre-placed by puzzle definitions) already count — `_pusher_list()` returns all pushers regardless of `locked`.
- `do_reset()` clears `self.status`, so the message disappears on reset.
- No change to `start_run`, `do_step`, the simulation, or any other game logic.

## Open questions

None — the behaviour is clear and self-contained.
