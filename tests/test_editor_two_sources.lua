-- The editor's second source, input selector, two-cell tiles, allowlist and the
-- Copy / Paste / Test handling of all of them.
require("lua/headless/stubs")
local EditorScene = require("lua/game/scenes/editor_scene")
local DefParser   = require("lua/game/def_parser")
local Ops         = require("lua/game/ops")
local UI          = require("lua/core/ui")
local UIRunner    = require("lua/headless/ui_runner")

local function new_editor()
    local sm = {}
    function sm:switch(scene) self.current = scene end
    local editor = EditorScene.new(sm)
    editor:on_enter()
    return editor, sm
end

local function element(editor, id)
    local e = UI.find(editor:ui_elements(), id)
    assert(e, "no element " .. id)
    return e
end

local function click(editor, id, button)
    local x, y = UI.centre(element(editor, id).rect)
    editor:mouse_pressed(x, y, button or 1)
    editor:draw()
    UIRunner.check_invariants(editor:ui_elements())
end

local function times(editor, id, n)
    for _ = 1, n do click(editor, id) end
end

local function tool(editor, name) click(editor, "editor:pal:" .. name) end
local function cell(editor, x, y, button) click(editor, "cell:" .. x .. "," .. y, button) end
local function place(editor, name, x, y) tool(editor, name); cell(editor, x, y) end

local function hover(editor, id)
    editor:mouse_moved(UI.centre(element(editor, id).rect))
end

local function copy(editor)
    love.system.setClipboardText("")
    click(editor, "editor:copy")
    local text = love.system.getClipboardText()
    local def, err = DefParser.parse(text)
    assert(def, "copied text does not parse: " .. tostring(err) .. "\n" .. text)
    return def, text
end

local function paste(editor, text)
    love.system.setClipboardText(text)
    click(editor, "editor:paste")
end

local function definition(extra)
    return 'return { name="Pasted", grid_w=10, grid_h=10, sink={x=10,y=10},'
        .. ' input={rows=1,cols=1,values={{1}}}, target={rows=1,cols=1,values={{2}}}, '
        .. (extra or "source={x=2,y=2}") .. ' }'
end

local function is_empty(editor, x, y)
    return editor:ui_tile(x, y) == nil
end

local function facing_at(editor, x, y)
    local t = editor:ui_tile(x, y)
    return t and t.facing
end

local function same_list(a, b)
    if a == nil or b == nil then return a == b end
    return #a == #b and table.concat(a, ",") == table.concat(b, ",")
end

-- ── Layout ──────────────────────────────────────────────────────────────────
do
    local editor = new_editor()
    local x = function(id) return element(editor, id).rect.x end
    assert(x("editor:pal:source") < x("editor:pal:source2")
        and x("editor:pal:source2") < x("editor:pal:sink"), "SRC2 follows SRC")
    assert(x("editor:pal:flip_v") < x("editor:pal:matrix_add")
        and x("editor:pal:matrix_add") < x("editor:pal:matrix_mul"), "M+ and Mx follow FLv")
    assert(x("editor:pal:matrix_add") - x("editor:pal:flip_v") == 48, "no separator before M+")
    assert(element(editor, "editor:pal:source2").label == "SRC2", "SRC2 label")
    assert(x("editor:back") == 1028, "Back at the right end")
    local paste_r = element(editor, "editor:paste").rect
    assert(paste_r.x + paste_r.w == 1270, "Paste ends 10px from the right edge")
    local one, two = element(editor, "editor:input_sel:1"), element(editor, "editor:input_sel:2")
    assert(one.label == "#1" and two.label == "#2", "selector labels")
    assert(one.selected and not two.selected, "input 1 selected at first")
    assert(one.rect.y + one.rect.h <= element(editor, "editor:input_rows_dec").rect.y,
        "selectors sit above the spinner row")
    local count = 0
    for _, e in ipairs(editor:ui_elements()) do
        if e.id:find("^editor:allow_matrix:") then count = count + 1 end
    end
    assert(count == 2, "two matrix toggles")
    -- Tallest matrices still show every toggle.
    times(editor, "editor:input_rows_inc", 2)
    times(editor, "editor:target_rows_inc", 2)
    element(editor, "editor:allow_matrix:matrix_mul")
    print("PASS: layout of the new buttons")
end

-- ── Input selector and sources ──────────────────────────────────────────────
do
    local editor = new_editor()
    local drawn = {}
    local printf = love.graphics.printf
    love.graphics.printf = function(text, ...) drawn[tostring(text)] = true; return printf(text, ...) end

    place(editor, "source", 1, 1)
    assert(drawn["SRC"] and drawn["INPUT 1"], "one source is drawn SRC")
    assert(editor:ui_tile(1, 1).index == nil, "no index with one source")
    assert(copy(editor).source2 == nil and copy(editor).input2 == nil, "single-source copy")

    place(editor, "source2", 6, 1)
    drawn = {}
    editor:draw()
    assert(drawn["SRC 1"] and drawn["SRC 2"], "two sources are numbered")
    assert(editor:ui_tile(2, 2).index == 1 and editor:ui_tile(7, 2).index == 2, "indices")
    love.graphics.printf = printf

    -- Selector: spinners and cells act on input 2 only.
    click(editor, "editor:input_sel:2")
    assert(element(editor, "editor:input_sel:2").selected, "input 2 selected")
    click(editor, "editor:input_cols_inc")
    cell(editor, 9, 9)  -- the selected tool stays source2: moves it
    place(editor, "source2", 6, 1)
    click(editor, "editor:input_cell:1,3")
    local def = copy(editor)
    assert(def.input.cols == 2 and def.input2.cols == 3, "only input 2 resized")
    assert(def.input2.values[1][3] == 1 and def.input.values[1][2] == 0, "only input 2 edited")
    assert(editor:ui_tile(8, 2).index == 2, "source 2 refitted")
    click(editor, "editor:input_rows_dec")
    assert(is_empty(editor, 6, 2), "refit shrinks the footprint")
    assert(editor:ui_tile(2, 2).index == 1, "source 1 untouched")
    click(editor, "editor:input_sel:1")
    assert(not UI.find(editor:ui_elements(), "editor:input_cell:1,3"), "input 1 has two columns")

    -- A resize that no longer fits, or overlaps, removes only that source.
    place(editor, "gap", 3, 1)
    click(editor, "editor:input_cols_inc")
    assert(is_empty(editor, 1, 1) and is_empty(editor, 2, 2), "overlapping source removed")
    assert(editor:ui_tile(6, 1).index == 2, "source 2 keeps its number on its own")
    assert(copy(editor).source2, "source 2 stays")
    place(editor, "source2", 9, 5)
    assert(copy(editor).source2 == nil, "off the grid: source 2 is removed and not placed")
    place(editor, "source2", 8, 5)
    click(editor, "editor:input_sel:2")
    click(editor, "editor:input_cols_inc")
    def = copy(editor)
    assert(def.source2 == nil and def.input2 == nil, "a source that no longer fits is removed")
    times(editor, "editor:input_cols_dec", 3)   -- no source left to refit

    -- Placing over something fails; erase works from any cell of either source.
    place(editor, "source", 5, 5)
    place(editor, "source2", 6, 5)
    assert(copy(editor).source2 == nil, "overlapping source 1 is refused")
    place(editor, "source2", 1, 8)
    cell(editor, 7, 6, 2)
    assert(is_empty(editor, 5, 5), "right-click erases source 1 from any cell")
    place(editor, "erase", 1, 8)
    assert(is_empty(editor, 1, 8) and copy(editor).source2 == nil, "eraser removes source 2")
    print("PASS: input selector and two sources")
end

-- ── Two-cell tiles ──────────────────────────────────────────────────────────
do
    local editor = new_editor()
    local function label(op) return element(editor, "editor:pal:" .. op).label end
    assert(label("matrix_add") == "M+>" and label("matrix_mul") == "Mx>", "tools start right")
    tool(editor, "matrix_add")
    assert(label("matrix_add") == "M+>", "the first click only selects")
    tool(editor, "matrix_add")
    assert(label("matrix_add") == "M+v" and label("matrix_mul") == "Mx>", "second click turns")
    tool(editor, "matrix_mul")
    tool(editor, "matrix_add")
    assert(label("matrix_add") == "M+v", "selecting again keeps the facing")

    cell(editor, 4, 4)
    assert(facing_at(editor, 4, 4) == "bottom" and facing_at(editor, 4, 5) == "bottom", "placed")
    cell(editor, 4, 5)
    assert(facing_at(editor, 3, 4) == "left" and is_empty(editor, 4, 5), "either cell turns it")
    tool(editor, "source")
    cell(editor, 4, 4)
    assert(facing_at(editor, 4, 3) == "top", "any other tool turns it")
    editor._sel = nil
    cell(editor, 4, 4)
    assert(facing_at(editor, 5, 4) == "right", "no tool turns it")

    -- Invalid spots place nothing and overwrite nothing.
    place(editor, "matrix_add", 5, 10)   -- partner off the grid (facing bottom)
    assert(is_empty(editor, 5, 10), "off-grid partner")
    cell(editor, 5, 3)                   -- partner occupied
    assert(is_empty(editor, 5, 3), "occupied partner")
    place(editor, "pusher", 5, 4)        -- a click on the tile only turns it
    assert(facing_at(editor, 4, 5) == "bottom" and is_empty(editor, 5, 4),
        "nothing is placed on a tile")

    -- T: the tile under the cursor first, then the selected matrix tool.
    tool(editor, "matrix_mul")
    hover(editor, "cell:4,5")
    editor:key_pressed("t")
    assert(facing_at(editor, 3, 4) == "left" and label("matrix_mul") == "Mx>", "T turns the tile")
    place(editor, "gap", 4, 5)
    place(editor, "gap", 4, 3)
    place(editor, "gap", 5, 4)
    tool(editor, "matrix_mul")
    hover(editor, "cell:4,4")
    editor:key_pressed("t")
    assert(facing_at(editor, 4, 4) == "left" and label("matrix_mul") == "Mx>",
        "a tile that cannot turn still takes the key")
    hover(editor, "cell:8,8")
    editor:key_pressed("t")
    assert(label("matrix_mul") == "Mxv", "T over an empty cell turns the tool")
    hover(editor, "editor:pal:sink")
    editor:key_pressed("t")
    assert(label("matrix_mul") == "Mx<", "T off the grid turns the tool")
    editor:mouse_moved(5, 5)
    editor:key_pressed("t")
    assert(label("matrix_mul") == "Mx^", "T over nothing turns the tool")
    place(editor, "transpose", 8, 8)
    editor:key_pressed("t")
    assert(editor:ui_tile(8, 8).op == "transpose" and label("matrix_mul") == "Mx^",
        "a classic tool and tile ignore T")
    editor._sel = nil
    editor:key_pressed("t")

    -- The name field takes the key.
    tool(editor, "matrix_mul")
    hover(editor, "cell:4,4")
    click(editor, "editor:name")
    editor:mouse_moved(UI.centre(element(editor, "cell:4,4").rect))
    editor:key_pressed("t")
    editor:text_input("t")
    assert(facing_at(editor, 4, 4) == "left" and label("matrix_mul") == "Mx^", "T ignored")
    editor:draw()
    assert(element(editor, "editor:name").label == "Untitledt", "T types into the name")
    editor:key_pressed("return")

    -- Erasing either cell removes both.
    cell(editor, 3, 4, 2)
    assert(is_empty(editor, 4, 4) and is_empty(editor, 3, 4), "right-click removes both")
    cell(editor, 8, 5)                   -- facing top
    assert(facing_at(editor, 8, 4) == "top", "placed upwards")
    place(editor, "erase", 8, 5)
    assert(is_empty(editor, 8, 4) and is_empty(editor, 8, 5), "eraser on the anchor")
    place(editor, "matrix_mul", 8, 5)
    place(editor, "erase", 8, 4)
    assert(is_empty(editor, 8, 4) and is_empty(editor, 8, 5), "eraser on the partner")

    paste(editor, definition())
    assert(label("matrix_add") == "M+>" and label("matrix_mul") == "Mx>", "loading resets tools")
    print("PASS: two-cell tiles")
end

-- ── Allowlist ───────────────────────────────────────────────────────────────
do
    local editor, sm = new_editor()
    local function toggle(op)
        click(editor, (Ops.is_two_cell(op) and "editor:allow_matrix:" or "editor:allow:") .. op)
    end
    local function expect(list, why)
        local ops = copy(editor).ops
        assert(same_list(ops, list), why .. ": " .. table.concat(ops or { "nil" }, ","))
        click(editor, "editor:test")
        assert(same_list(sm.current._custom_puzzle.ops, list), why .. " (Test)")
    end
    expect(nil, "nothing toggled")
    toggle("matrix_mul")
    assert(element(editor, "editor:allow_matrix:matrix_mul").selected, "toggle highlights")
    expect({ "matrix_mul" }, "one matrix op")
    toggle("matrix_add")
    toggle("flip_v")
    expect({ "flip_v", "matrix_add", "matrix_mul" }, "classic first, in order")
    toggle("flip_v")
    for _, op in ipairs(Ops.ORDER) do toggle(op) end
    local all = {}
    for _, op in ipairs(Ops.ORDER) do all[#all + 1] = op end
    all[#all + 1], all[#all + 2] = "matrix_add", "matrix_mul"
    expect(all, "all twelve are written out")
    toggle("matrix_add")
    toggle("matrix_mul")
    expect(nil, "exactly the ten classic ops")
    toggle("flip_v")
    assert(#copy(editor).ops == 9, "a classic subset is written out")

    paste(editor, definition('source={x=2,y=2}, ops={}'))
    expect({}, "an empty list is preserved")
    toggle("matrix_add")
    expect({ "matrix_add" }, "a matrix toggle replaces the empty list")
    toggle("matrix_add")
    expect(nil, "toggling back off")
    print("PASS: ops omission rules")
end

-- ── Round trip ──────────────────────────────────────────────────────────────
do
    local editor, sm = new_editor()
    place(editor, "source", 1, 1)
    place(editor, "source2", 7, 1)
    click(editor, "editor:input_sel:2")
    click(editor, "editor:input_rows_inc")
    click(editor, "editor:input_cell:3,2")
    tool(editor, "matrix_add"); tool(editor, "matrix_add"); tool(editor, "matrix_add")
    cell(editor, 5, 7)                       -- left
    place(editor, "matrix_mul", 8, 8)        -- right
    click(editor, "editor:allow_matrix:matrix_mul")
    local def, text = copy(editor)
    assert(def.source2.x == 7 and def.input2.rows == 3 and def.input2.values[3][2] == 1,
        "second source copied:\n" .. text)
    assert(text:find('op="matrix_add", x=5, y=7, params={facing="left"}', 1, true),
        "facing copied:\n" .. text)

    local again = new_editor()
    click(again, "editor:input_sel:2")
    paste(again, text)
    assert(again._paste_error == nil, tostring(again._paste_error))
    assert(element(again, "editor:input_sel:1").selected, "pasting selects input 1")
    local _, text2 = copy(again)
    assert(text2 == text, "round trip changes the text:\n" .. text2)
    assert(facing_at(again, 4, 7) == "left" and facing_at(again, 9, 8) == "right", "tiles back")
    assert(again:ui_tile(1, 1).index == 1 and again:ui_tile(8, 3).index == 2, "sources back")

    click(editor, "editor:test")
    local built = sm.current._custom_puzzle
    assert(built.source2.x == 7 and built.input2.rows == 3, "Test gets the second source")
    built.input2.values[1][1] = 9
    assert(copy(editor).input2.values[1][1] == 1, "Test gets a copy")
    local scene = sm.current
    scene:on_enter()
    assert(scene:ui_tile(4, 7).facing == "left" and scene:ui_tile(7, 1).index == 2,
        "the puzzle scene loads it")

    -- A paste without source2 drops the second input again.
    click(again, "editor:input_sel:2")
    paste(again, definition())
    assert(element(again, "editor:input_sel:1").selected, "selection reset")
    assert(copy(again).source2 == nil, "second source dropped")
    click(again, "editor:input_sel:2")
    assert(element(again, "editor:input_cell:2,2").label == "1", "input 2 back to identity")
    assert(not UI.find(again:ui_elements(), "editor:input_cell:3,1"), "input 2 back to 2x2")

    -- A missing facing becomes right; matrix ops are accepted in fixed_ops.
    paste(again, definition('source={x=2,y=2}, locked={{kind="op",op="matrix_mul",x=4,y=4}},'
        .. ' fixed_ops={{op="matrix_add",params={facing="top"}},"matrix_mul"}'))
    assert(again._paste_error == nil, tostring(again._paste_error))
    assert(facing_at(again, 5, 4) == "right", "default facing")
    local fixed = copy(again)
    assert(fixed.locked[1].params.facing == "right", "default facing written")
    assert(fixed.fixed_ops[1].params.facing == "top" and fixed.fixed_ops[2] == "matrix_mul",
        "fixed_ops preserved")
    print("PASS: copy, paste, copy and Test")
end

-- ── Rejections ──────────────────────────────────────────────────────────────
do
    local TOGETHER = "source2 and input2 come together"
    local function second(input2, source2)
        return "source={x=2,y=2}, source2=" .. (source2 or "{x=6,y=2}") .. ", input2=" .. input2
    end
    local OK = "{rows=1,cols=1,values={{1}}}"
    local cases = {
        { "source={x=2,y=2}, source2={x=6,y=2}", TOGETHER },
        { "source={x=2,y=2}, input2=" .. OK,     TOGETHER },
        { second("7"),                                        "Invalid input2" },
        { second("{cols=1,values={{1}}}"),                    "Invalid input2" },
        { second("{rows=0,cols=1,values={{1}}}"),             "Invalid input2" },
        { second("{rows=1,cols=5,values={{1}}}"),             "Invalid input2" },
        { second("{rows=1.5,cols=1,values={{1}}}"),           "Invalid input2" },
        { second('{rows="1",cols=1,values={{1}}}'),           "Invalid input2" },
        { second("{rows=1,cols=1}"),                          "Invalid input2" },
        { second("{rows=1,cols=1,values={1}}"),               "Invalid input2" },
        { second('{rows=1,cols=1,values={{"a"}}}'),           "Invalid input2" },
        { second(OK, "3"),                                    "Invalid source2" },
        { second(OK, "{x=3}"),                                "Invalid source2" },
        { second(OK, "{x=3,y=2.5}"),                          "Invalid source2" },
        { 'locked={{kind="op",op="matrix_add",x=4,y=4,params={facing="up"}}}',
            "Invalid facing: up" },
        { 'fixed_ops={{op="matrix_mul",params={facing="down"}}}', "Invalid facing: down" },
    }
    local editor = new_editor()
    place(editor, "source", 1, 1)
    place(editor, "source2", 6, 1)
    place(editor, "matrix_add", 4, 5)
    click(editor, "editor:input_sel:2")
    local _, before = copy(editor)
    for _, case in ipairs(cases) do
        paste(editor, definition(case[1]))
        assert(editor._paste_error == case[2],
            case[1] .. ": expected '" .. case[2] .. "', got " .. tostring(editor._paste_error))
        assert(element(editor, "editor:input_sel:2").selected, case[1] .. " moved the selector")
        local _, after = copy(editor)
        assert(after == before, case[1] .. " changed the editor:\n" .. after)
    end
    print("PASS: bad definitions rejected")
end

-- ── Skipped tiles ───────────────────────────────────────────────────────────
do
    local editor = new_editor()
    paste(editor, definition(
        'source={x=2,y=2}, source2={x=5,y=5}, input2={rows=2,cols=2,values={{1}}},'
        .. ' gaps={{x=7,y=7},{x=8,y=8}}, locked={'
        .. '{kind="op",op="matrix_add",x=5,y=5},'                             -- kept
        .. '{kind="op",op="matrix_mul",x=6,y=4,params={facing="bottom"}},'    -- overlaps it
        .. '{kind="op",op="matrix_mul",x=10,y=1},'                            -- leaves the grid
        .. '{kind="op",op="transpose",x=6,y=5},'                              -- on its partner
        .. '{kind="op",op="matrix_mul",x=7,y=7,params={facing="top"}} }'))    -- kept, over a gap
    assert(editor._paste_error == nil, tostring(editor._paste_error))
    assert(editor:ui_tile(6, 5).op == "matrix_add", "the first tile wins")
    assert(is_empty(editor, 6, 4) and is_empty(editor, 10, 1), "skipped whole")
    assert(editor:ui_tile(7, 6).op == "matrix_mul", "locked tiles go before gaps")
    assert(editor:ui_tile(7, 7).kind == "op", "the gap under it is skipped")
    local def = copy(editor)
    assert(#def.locked == 2, "two tiles kept")
    assert(def.source2 == nil and def.input2 == nil, "an overlapping source 2 is skipped")
    assert(editor:ui_tile(2, 2).index == nil, "one source")
    click(editor, "editor:input_sel:2")
    assert(element(editor, "editor:input_cell:2,2").label == "0", "short values are filled")

    paste(editor, definition('source={x=2,y=2}, source2={x=2,y=2}, input2={rows=1,cols=1,values={}}'))
    assert(copy(editor).source2 == nil, "source 2 over source 1 is skipped")
    paste(editor, definition('source={x=2,y=2}, source2={x=11,y=3}, input2={rows=1,cols=1,values={}}'))
    assert(copy(editor).source2 == nil, "source 2 off the grid is skipped")
    print("PASS: tiles and sources that do not fit are skipped")
end
