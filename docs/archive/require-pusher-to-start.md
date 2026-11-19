## Require Pusher To Start Checklist

- [x] Task A — `game/hud.lua` — Add `no_pusher` entry to `STATUS_COLORS` and `STATUS_LABELS` so the HUD banner displays "Place a pusher first" in orange when that status is set
- [x] Task B — `game/scenes/matrix_scene.lua` — In `key_pressed`, before the `start_run()` call in the `r` branch and the `do_step()` call in the `space` branch, check `#self:_pusher_list() == 0`; if so, set `self.status = "no_pusher"` and return without running
