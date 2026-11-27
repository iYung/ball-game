-- Regressions found while verifying the two-source feature: source tags on idle
-- previews, operand badges in the game and the recap, the default source 1 of the
-- editor, and the pusher selection after Reset.

local runner             = require("lua/headless/runner")
local Grid               = require("lua/game/grid")
local Matrix             = require("lua/game/matrix_math")
local UI                 = require("lua/core/ui")
local DefParser          = require("lua/game/def_parser")
local MatrixScene        = require("lua/game/scenes/matrix_scene")
local EditorScene        = require("lua/game/scenes/editor_scene")
local SolutionRecapScene = require("lua/game/scenes/solution_recap_scene")

local CS = MatrixScene.GEOM.CELL_SIZE
local cell = SolutionRecapScene.cell_top_left

local function new_scene(def)
    local ctx = runner.setup(function(_, sm) return MatrixScene.new_from_def(def, sm) end)
    return ctx.sm.current
end

-- Everything one draw prints and fills, in drawing order.
local function capture(scene)
    local g = love.graphics
    local rect, printf = g.rectangle, g.printf
    local ops = {}
    g.rectangle = function(mode, x, y, w, h)
        if mode == "fill" then ops[#ops + 1] = { x = x, y = y, w = w, h = h } end
    end
    g.printf = function(s, x, y, w) ops[#ops + 1] = { s = s, x = x, y = y, w = w } end
    local ok, err = pcall(scene.draw, scene)
    g.rectangle, g.printf = rect, printf
    assert(ok, tostring(err))
    return ops
end

local function find(ops, pred)
    local found = {}
    for i, o in ipairs(ops) do
        if pred(o) then found[#found + 1] = { i = i, o = o } end
    end
    return found
end

-- Whether an operand badge is filled in the corner of cell (x, y).
local function badge(ops, x, y)
    local sx, sy = cell(x, y)
    return #find(ops, function(o)
        return not o.s and o.x == sx + 2 and o.y == sy + 2 and o.w == 14 and o.h == 14
    end) > 0
end

local function one(v) return { rows = 1, cols = 1, values = { { v } } } end

-- ── Source tags ─────────────────────────────────────────────────────────────
do
    local def = {
        name = "tags", grid_w = 10, grid_h = 10,
        source = { x = 2, y = 3 }, input = { rows = 2, cols = 2, values = { { 11, 12 }, { 13, 14 } } },
        source2 = { x = 6, y = 3 }, input2 = one(21),
        sink = { x = 10, y = 10 }, target = one(1),
        locked = { { kind = "pusher", id = 1, x = 1, y = 3 } },
    }
    local scene = new_scene(def)
    local ops = capture(scene)
    for n, case in ipairs({ { at = def.source, value = "11" }, { at = def.source2, value = "21" } }) do
        local sx, sy = cell(case.at.x, case.at.y)
        local fills = find(ops, function(o)
            return not o.s and o.x == sx and o.y == sy and o.w == CS and o.h == CS
        end)
        local value = find(ops, function(o) return o.s == case.value end)[1].o
        local tags = find(ops, function(o)
            return o.s == "SRC " .. n and o.x >= sx and o.x + o.w <= sx + CS
                and o.y >= sy and o.y < sy + CS / 2
        end)
        local tag = assert(tags[#tags], "source " .. n .. " has a tag in its first cell")
        assert(tag.i > fills[#fills].i, "tag " .. n .. " is drawn over the preview")
        assert(tag.o.y + 13 <= value.y, "tag " .. n .. " stays above the value")
    end

    scene:start_run()
    for n = 1, 2 do
        local count = #find(capture(scene), function(o) return o.s == "SRC " .. n end)
        assert(count == 1, "during a run only the source tile is labelled, got " .. count)
    end

    def.source2, def.input2 = nil, nil
    ops = capture(new_scene(def))
    assert(#find(ops, function(o) return o.s == "SRC" end) == 1, "single source: tile label only")
    assert(#find(ops, function(o) return o.s == "SRC 1" end) == 0, "single source: no tag")
    print("PASS: idle previews of two sources are tagged")
end

-- ── Badges while sliding: game ──────────────────────────────────────────────
do
    -- A 1x2 matrix slides right from x 3..4 to 4..5: (4,3) stays under it, (5,3)
    -- is where it is headed.
    local scene = new_scene({
        name = "badge", grid_w = 10, grid_h = 10,
        source = { x = 2, y = 3 }, input = { rows = 1, cols = 2, values = { { 1, 2 } } },
        sink = { x = 10, y = 10 }, target = one(1),
        locked = {
            { kind = "pusher", id = 1, x = 1, y = 3 },
            { kind = "op", op = "matrix_add", x = 4, y = 3, params = { facing = "bottom" } },
            { kind = "op", op = "matrix_add", x = 5, y = 3, params = { facing = "top" } },
        },
    })
    require("lua/game/timeline").set(scene.timeline, 1, 1, 1, "right")
    scene:start_run()
    scene:do_step()
    scene:do_step()
    assert(scene.running, tostring(scene.status))
    for _, t in ipairs({ 0, 0.5 }) do
        scene.anim_t = t
        local ops = capture(scene)
        assert(badge(ops, 4, 3), "a cell that stays covered keeps its badge at " .. t)
        assert(not badge(ops, 5, 3), "no badge ahead of the matrix at " .. t)
    end
    scene.anim_t = 1
    local ops = capture(scene)
    assert(badge(ops, 4, 3) and badge(ops, 5, 3), "badges once the matrix has arrived")
    print("PASS: game badges follow the drawn matrix")
end

-- ── Badges: recap ───────────────────────────────────────────────────────────
do
    local grid = Grid.new(10, 10)
    grid:put(3, 3, { kind = "op", op = "matrix_add", params = { facing = "right" } })
    local ax, ay = cell(2, 3)
    local bx, by = cell(3, 3)
    local frames = { { from_x = ax, from_y = ay, to_x = bx, to_y = by,
                       matrix = Matrix.new(1, 1, { { 5 } }) } }
    local stats = { ticks = 1, pieces = 1, puzzle_name = "badge", puzzle_index = 1 }
    local ctx = runner.setup(function(_, sm)
        return SolutionRecapScene.new(stats, { grid = grid }, frames, 1, sm)
    end)
    local recap = ctx.sm.current
    for _, t in ipairs({ 0, 0.5 }) do
        recap._anim_t = t
        assert(not badge(capture(recap), 3, 3), "no badge before arrival at " .. t)
    end
    recap._anim_t = 1
    local ops = capture(recap)
    assert(badge(ops, 3, 3) and not badge(ops, 4, 3), "only the covered input is badged")
    local value = find(ops, function(o) return o.s == "5" end)[1]
    local letters = find(ops, function(o) return o.s == "L" and o.w == 14 end)
    assert(#letters == 1 and letters[1].i > value.i, "the L badge is drawn over the matrix")
    print("PASS: recap badges covered input cells")
end

-- ── Editor: source 1 left out ───────────────────────────────────────────────
do
    local function new_editor()
        local editor = EditorScene.new({ switch = function() end })
        editor:on_enter()
        return editor
    end
    local function click(editor, id)
        local x, y = UI.centre(assert(UI.find(editor:ui_elements(), id), id).rect)
        editor:mouse_pressed(x, y, 1)
    end
    local function place(editor, name, x, y)
        click(editor, "editor:pal:" .. name)
        click(editor, "cell:" .. x .. "," .. y)
    end
    local function copy(editor)
        click(editor, "editor:copy")
        local text = love.system.getClipboardText()
        local def = assert(DefParser.parse(text))
        local built = editor:_build_def()
        assert(built.source.x == def.source.x and built.source.y == def.source.y,
            "Test and Copy agree on source 1")
        return def, text
    end
    local function expect_source(def, x, y, label)
        assert(def.source.x == x and def.source.y == y,
            label .. ": source at " .. def.source.x .. "," .. def.source.y)
    end

    local editor = new_editor()
    expect_source(copy(editor), 1, 1, "empty board")
    place(editor, "gap", 1, 1)
    expect_source(copy(editor), 1, 1, "single source output is unchanged")

    editor = new_editor()
    place(editor, "source2", 2, 1)
    local def, text = copy(editor)
    expect_source(def, 4, 1, "clear of source 2")
    love.system.setClipboardText(text)
    click(editor, "editor:paste")
    assert(editor:ui_tile(2, 1).index == 2 and editor:ui_tile(4, 1).index == 1, "both sources pasted")
    assert(select(2, copy(editor)) == text, "copy, paste, copy is stable")

    editor = new_editor()
    place(editor, "source2", 5, 5)
    expect_source(copy(editor), 1, 1, "(1,1) is kept when free")

    -- Source 1 as 4x4: the default sink's cell is avoided.
    editor = new_editor()
    for _ = 1, 2 do
        click(editor, "editor:input_rows_inc")
        click(editor, "editor:input_cols_inc")
    end
    place(editor, "source2", 1, 1)
    for y = 1, 6 do
        for x = 1, 10 do
            if x > 2 or y > 2 then place(editor, "gap", x, y) end
        end
    end
    for y = 7, 10 do
        for x = 1, 6 do place(editor, "gap", x, y) end
    end
    local boxed = copy(editor)
    expect_source(boxed, 3, 1, "no free spot: first one beside source 2")
    place(editor, "erase", 1, 3)
    place(editor, "sink", 1, 3)
    expect_source(copy(editor), 7, 7, "with a placed sink (10,10) is free")
    print("PASS: default source 1 avoids source 2")
end

-- ── Reset with a held pusher ────────────────────────────────────────────────
do
    local scene = new_scene({
        name = "held", grid_w = 10, grid_h = 10,
        source = { x = 5, y = 5 }, input = one(1), sink = { x = 10, y = 10 }, target = one(1),
    })
    scene:_place_tile_at(2, 2, { kind = "pusher" })
    scene.palette:select({ kind = "drag" })
    local x, y = cell(2, 2)
    scene:mouse_pressed(x + 5, y + 5, 1)
    assert(scene._drag_tile and scene.sel_pusher == nil, "the pusher is held")
    scene:key_pressed("r")                 -- sets a status, so Reset is enabled
    scene:key_pressed("backspace")
    assert(scene:ui_tile(2, 2).kind == "pusher", "the pusher is back")
    assert(scene.sel_pusher == 1, "and selected again")
    print("PASS: Reset resyncs the pusher selection")
end

print("ALL VERIFICATION FIX TESTS PASSED")
