# Win → Continue Button

## Goal

Remove the automatic transition from the puzzle win state to `SolutionRecapScene`.
Instead require an explicit player action — clicking a **Continue** button or pressing **Enter** — before the transition fires.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — the transition logic and UI
- `tests/test_solution_recap.lua` — unit test that expects auto-transition after 0.8 s
- `tests/ui/01_solve_puzzle_1.lua` — UI spec that relies on auto-transition to reach SOLVED!

## What changes

### `matrix_scene.lua`

1. **Remove the `_win_timer` auto-transition** from `update()` (lines 740–760).  
   The block that increments `self._win_timer` and switches to `SolutionRecapScene` after 0.8 s is deleted entirely. The win state now just stays on-screen until the player acts.

2. **Add a `cmd:continue` button** to `CMD_BUTTONS`.  
   It sits alongside Run/Reset/Menu in the bottom-right bar.  
   - `_cmd_enabled("continue")` returns true only when `self.status == "win"`.  
   - `_cmd_activate("continue")` builds the stats/board tables and switches to `SolutionRecapScene` (identical logic to what used to live in `update()`).  
   - Run stays in the list but remains disabled on win; Continue appears active only on win.  
   - The button is styled green (same palette as "Run") to signal a positive forward action.

3. **Wire Enter key to continue when win**.  
   In `key_pressed`, if `key == "return"` and `self.status == "win"`, call `_cmd_activate("continue")`.

4. **`_win_timer` field removed** — `load_puzzle` and `do_reset` no longer zero it, `MatrixScene.new` no longer sets it.

### `tests/test_solution_recap.lua`

The test at line 86 (`"win transitions to SolutionRecapScene"`) currently drives the transition by calling `ctx.sm:update(1.0)`. With the timer gone that call does nothing. Update the test to call `scene:_cmd_activate("continue")` directly after `scene.status == "win"` and before checking the new scene — the expectation that the new scene is a `SolutionRecapScene` stays identical.

### `tests/ui/01_solve_puzzle_1.lua`

The existing spec has:
```lua
{ wait_until = { text = "SOLVED!", max_frames = 3000 } },
```
This relied on the auto-transition. The old expectation is no longer correct now that the transition is intentionally gated. Update the spec to:
```lua
{ wait_until = { status = "win", max_frames = 3000 } },
{ click_button = "Continue" },
{ assert_text = "SOLVED!" },
```
(or use `press = "return"` in place of `click_button`)

> **Why this test change is justified:** The spec was asserting a side-effect of the old auto-timer, not the puzzle-solve mechanic itself. The updated spec still covers the full flow from puzzle completion to recap; it just now also covers the new required step.

## What stays the same

- All recap scene behavior (Replay / Next puzzle / Menu buttons, animation).
- Run, Reset, Menu buttons and all their logic.
- The "WIN!" status banner in the grid panel.
- All other statuses (fail, stuck, timeout, blocked, no_pusher) are unaffected.

## Open questions

None. The change is self-contained and the user confirmed the direction.
