-- test_matrix_draw.lua
-- Covers four previously-uncovered draw paths in lua/game/scenes/matrix_scene.lua:
--   1. _draw_status_banner  (lines 1664–1675)
--   2. Ghost preview in draw_grid  (lines 848–883)
--   3. -col / -row affordance strips in draw_grid  (lines 803–814, 829–840)
--   4. _bar_click psel/chip/tl/slot branches (the bottom bar; replaces the old _timeline_element_click)

local runner = require("lua/headless/runner")

local function new_scene()
    local ctx = runner.setup(function() return require("lua/game/scenes/matrix_scene").new(1) end)
    return ctx.sm.current
end

-- ── 1. _draw_status_banner ────────────────────────────────────────────────────

do
    local scene = new_scene()
    scene.status = "win"
    local ok, err = pcall(function() scene:draw() end)
    assert(ok, "_draw_status_banner (win) threw: " .. tostring(err))
    print("PASS: _draw_status_banner with status=win")
end

do
    local scene = new_scene()
    scene.status = "fail"
    local ok, err = pcall(function() scene:draw() end)
    assert(ok, "_draw_status_banner (fail) threw: " .. tostring(err))
    print("PASS: _draw_status_banner with status=fail")
end

-- ── 2. Ghost preview (valid placement) ───────────────────────────────────────

do
    local scene = new_scene()
    scene._drag_tile  = { kind = "pusher", id = 1, width = 1, height = 1 }
    scene._drag_ghost = { cx = 5, cy = 1 }
    local ok, err = pcall(function() scene:draw_grid() end)
    assert(ok, "draw_grid ghost-valid threw: " .. tostring(err))
    print("PASS: draw_grid ghost preview (valid position)")
end

-- Ghost preview (invalid / occupied position)
do
    local scene = new_scene()
    -- Place a tile at (5,1) so the ghost lands on an occupied cell
    scene:_place_tile_at(5, 1, { kind = "op", op = "add_matrix" })
    scene._drag_tile  = { kind = "pusher", id = 1, width = 1, height = 1 }
    scene._drag_ghost = { cx = 5, cy = 1 }
    local ok, err = pcall(function() scene:draw_grid() end)
    assert(ok, "draw_grid ghost-invalid threw: " .. tostring(err))
    print("PASS: draw_grid ghost preview (invalid / occupied position)")
end

-- ── 3. -col / -row affordance strips ─────────────────────────────────────────

do
    local scene = new_scene()
    -- add_matrix starts 1×1; grow_col → 2×1; grow_row → 2×2
    scene:_place_tile_at(5, 1, { kind = "op", op = "add_matrix" })
    scene:_resize_tile(5, 1, "grow_col")   -- tile_cols = 2
    scene:_resize_tile(5, 1, "grow_row")   -- tile_rows = 2

    local ok, err = pcall(function() scene:draw_grid() end)
    assert(ok, "draw_grid with 2×2 tile threw: " .. tostring(err))

    -- Verify expand_rects contains both shrink_col and shrink_row entries
    local has_shrink_col, has_shrink_row = false, false
    for _, r in ipairs(scene._expand_rects or {}) do
        if r.action == "shrink_col" then has_shrink_col = true end
        if r.action == "shrink_row" then has_shrink_row = true end
    end
    assert(has_shrink_col, "_expand_rects missing shrink_col entry")
    assert(has_shrink_row, "_expand_rects missing shrink_row entry")
    print("PASS: draw_grid -col and -row affordance strips (2×2 tile)")
end

-- ── 4. _bar_click ─────────────────────────────────────────────────────────────
-- Rewritten: the old test called _timeline_element_click with tl:inc/dec/scroll_up/down and
-- slot:A:n, which no longer exist (length +/-, per-pusher rows, slot cycling were removed).
do
    local Timeline = require("lua/game/timeline")
    local scene = new_scene()
    scene:draw()
    local function bar(id, btn, enabled)
        return scene:_bar_click({ id = id, enabled = enabled ~= false }, btn or 1)
    end
    scene:_place_tile_at(1, 1, { kind = "pusher", id = 1 })
    scene:_place_tile_at(2, 1, { kind = "pusher", id = 2 })

    assert(bar("psel:B") and scene.sel_pusher == 2, "psel:B selects pusher 2")
    assert(bar("chip:up") and scene.armed_chip == "up", "chip arms")
    assert(bar("slot:1:3") and Timeline.get(scene.timeline, 1, 3).cmd == "up", "armed chip written to slot")
    assert(Timeline.get(scene.timeline, 1, 3).pusher == 2, "stamped with the selected pusher")
    assert(bar("slot:1:3", 2) and Timeline.get(scene.timeline, 1, 3) == nil, "right-click clears")
    bar("tl:scroll_right")
    assert(scene.timeline_scroll == 5, "scroll_right pages forward")
    bar("tl:scroll_left")
    assert(scene.timeline_scroll == 0, "scroll_left pages back")

    -- disabled elements are swallowed without effect
    bar("psel:A", 1, false); assert(scene.sel_pusher == 2, "disabled psel ignored")
    bar("chip:down", 1, false); assert(scene.armed_chip == "up", "disabled chip ignored")
    bar("tl:scroll_right", 1, false); assert(scene.timeline_scroll == 0, "disabled scroll ignored")
    assert(bar("slot:2:2", 1, false) and Timeline.get(scene.timeline, 2, 2) == nil, "disabled slot ignored")

    -- an unarmed chip / no pusher writes nothing
    scene.armed_chip = nil
    bar("slot:2:2"); assert(Timeline.get(scene.timeline, 2, 2) == nil, "no armed chip: nothing written")

    -- ids that are not bar elements are not handled
    assert(bar("cell:1,1") == false, "non-bar id returns false")
    print("PASS: _bar_click branches")
end

print("ALL TESTS PASSED")
