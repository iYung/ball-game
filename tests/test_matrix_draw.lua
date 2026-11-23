-- test_matrix_draw.lua
-- Covers four previously-uncovered draw paths in lua/game/scenes/matrix_scene.lua:
--   1. _draw_status_banner  (lines 1664–1675)
--   2. Ghost preview in draw_grid  (lines 848–883)
--   3. -col / -row affordance strips in draw_grid  (lines 803–814, 829–840)
--   4. _timeline_element_click tl: and slot: branches  (lines 1649–1662)

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

-- ── 4. _timeline_element_click ────────────────────────────────────────────────

-- Seed _tl_top so _timeline_layout() returns a table instead of nil
do
    local scene = new_scene()
    scene._tl_top = 500   -- any numeric value lets _timeline_layout proceed

    -- tl:inc branch
    local ok, err = pcall(function()
        scene:_timeline_element_click({ id = "tl:inc", kind = "tl", enabled = true }, 1)
    end)
    assert(ok, "_timeline_element_click tl:inc threw: " .. tostring(err))
    print("PASS: _timeline_element_click tl:inc")

    -- tl:scroll_right branch
    ok, err = pcall(function()
        scene:_timeline_element_click({ id = "tl:scroll_right", kind = "tl", enabled = true }, 1)
    end)
    assert(ok, "_timeline_element_click tl:scroll_right threw: " .. tostring(err))
    print("PASS: _timeline_element_click tl:scroll_right")

    -- tl:dec branch
    ok, err = pcall(function()
        scene:_timeline_element_click({ id = "tl:dec", kind = "tl", enabled = true }, 1)
    end)
    assert(ok, "_timeline_element_click tl:dec threw: " .. tostring(err))
    print("PASS: _timeline_element_click tl:dec")

    -- tl:scroll_left branch
    ok, err = pcall(function()
        scene:_timeline_element_click({ id = "tl:scroll_left", kind = "tl", enabled = true }, 1)
    end)
    assert(ok, "_timeline_element_click tl:scroll_left threw: " .. tostring(err))
    print("PASS: _timeline_element_click tl:scroll_left")

    -- slot branch — requires a pusher on the grid first (slot "A" = pusher 1)
    -- Place a pusher so the timeline has a row for pusher A
    scene:_place_tile_at(1, 1, { kind = "pusher", id = 1 })
    ok, err = pcall(function()
        scene:_timeline_element_click({ id = "slot:A:1", kind = "slot", enabled = true }, 1)
    end)
    assert(ok, "_timeline_element_click slot:A:1 threw: " .. tostring(err))
    print("PASS: _timeline_element_click slot:A:1")

    -- tl:scroll_up branch
    ok, err = pcall(function()
        scene:_timeline_element_click({ id = "tl:scroll_up", kind = "tl", enabled = true }, 1)
    end)
    assert(ok, "_timeline_element_click tl:scroll_up threw: " .. tostring(err))
    print("PASS: _timeline_element_click tl:scroll_up")

    -- tl:scroll_down branch
    ok, err = pcall(function()
        scene:_timeline_element_click({ id = "tl:scroll_down", kind = "tl", enabled = true }, 1)
    end)
    assert(ok, "_timeline_element_click tl:scroll_down threw: " .. tostring(err))
    print("PASS: _timeline_element_click tl:scroll_down")

    -- disabled element — should return early without error
    ok, err = pcall(function()
        scene:_timeline_element_click({ id = "tl:inc", kind = "tl", enabled = false }, 1)
    end)
    assert(ok, "_timeline_element_click disabled threw: " .. tostring(err))
    print("PASS: _timeline_element_click disabled (no-op)")
end

print("ALL TESTS PASSED")
