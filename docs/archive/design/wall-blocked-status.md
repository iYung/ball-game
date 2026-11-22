## Goal

Fix the wrong error message shown when a matrix is pushed into a wall. Currently both wall collisions and sink mismatches show `"FAIL — matrix mismatch"`. Wall collisions should show a distinct message.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — STATUS_COLORS, STATUS_LABELS, `do_step`

## What changes

Add a new `"blocked"` status to `STATUS_COLORS` and `STATUS_LABELS`:

```lua
STATUS_COLORS = {
    ...
    blocked = {0.9, 0.2, 0.2, 1},   -- same red as fail
}

STATUS_LABELS = {
    ...
    blocked = "FAIL — can't push matrix into a wall",
}
```

In `do_step`, line 621, change:
```lua
self.status = "fail"
```
to:
```lua
self.status = "blocked"
```

The `"fail"` status (line 674) is kept exclusively for the sink-mismatch case.

## What stays the same

- `"fail"` status still fires when the matrix reaches the sink with wrong values.
- `"fail"` at line 574 (`_process_footprint` — matrix too large after an op tile) stays as-is; that is a separate edge case the user did not flag.
- All other statuses (`stuck`, `timeout`, `win`, `no_pusher`, `running`) are untouched.

## Open questions

None — the mapping is unambiguous from the two call sites.
