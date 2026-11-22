## Wall-Blocked Status Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — add `blocked` to STATUS_COLORS and STATUS_LABELS; change lines 574 and 621 to set `self.status = "blocked"` instead of `"fail"`
- [x] Task B — `tests/test_pusher_scene.lua` — update or add UI specs so the wall/pusher-blocked path expects `"blocked"` status, not `"fail"`
