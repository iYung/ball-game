## No-pusher screen tint Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — reset draw color to white at the end of `MatrixScene:draw()`.
- [x] Task B — `tests/test_draw_color_reset.lua` — assert the draw ends white with and without a pusher placed (fails without the fix: leaks 0.45,0.45,0.6,1).
