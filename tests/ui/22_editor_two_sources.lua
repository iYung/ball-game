-- Editor, through real input: build a two-source puzzle with a turned two-cell
-- tile, Copy, erase, Paste, then Test it, run to a merge and return with Menu.

local steps = { { click_button = "Editor" } }

local function add(...)
    for _, s in ipairs({ ... }) do steps[#steps + 1] = s end
end

local function pick(id) return { click_button = { id = "editor:pal:" .. id } } end
local function press_button(id) return { click_button = { id = "editor:" .. id } } end
local function tool(id, text) return { assert_button = { id = "editor:pal:" .. id, label = text } } end
local function click(x, y) return { click_cell = { x, y } } end
local function erase(x, y) return { right_click_cell = { x, y } } end
local function empty(x, y) return { assert_tile = { x = x, y = y } } end
local function source(x, y, index)
    return { assert_tile = { x = x, y = y, kind = "source", index = index } }
end
local function tile(x, y, op, facing)
    return { assert_tile = { x = x, y = y, kind = "op", op = op, facing = facing } }
end

-- Two 1x1 inputs (2 and 1) and a 1x1 target of 3.
add(press_button("input_rows_dec"),
    press_button("input_cols_dec"),
    press_button("input_cell:1,1"),
    press_button("input_sel:2"),
    { assert_button = { id = "editor:input_sel:2", selected = true } },
    { assert_text = "INPUT 2" },
    press_button("input_rows_dec"),
    press_button("input_cols_dec"),
    press_button("target_rows_dec"),
    press_button("target_cols_dec"),
    press_button("target_cell:1,1"),
    press_button("target_cell:1,1"))

add(pick("source"), click(3, 5),
    { assert_text = "SRC" }, { assert_no_text = "SRC 1" },
    pick("source2"), click(3, 6),
    { assert_text = "SRC 1" }, { assert_text = "SRC 2" },
    source(3, 5, 1), source(3, 6, 2),
    pick("sink"), click(7, 5))

-- The M+ tool turned downwards by its button; a second tile turned on the board.
add(pick("matrix_add"), tool("matrix_add", "M+>"),
    pick("matrix_add"), tool("matrix_add", "M+v"),
    click(5, 5),
    tile(5, 5, "matrix_add", "bottom"), tile(5, 6, "matrix_add", "bottom"),
    pick("matrix_mul"), { press = "t" }, tool("matrix_mul", "Mxv"),
    click(9, 2), tile(9, 3, "matrix_mul", "bottom"),
    click(9, 3), tile(8, 2, "matrix_mul", "left"), empty(9, 3),
    { hover_button = { id = "cell:8,2" } },
    { press = "t" }, tile(9, 1, "matrix_mul", "top"), empty(8, 2),
    press_button("allow_matrix:matrix_add"),
    { assert_button = { id = "editor:allow_matrix:matrix_add", selected = true } })

local function board()
    add(source(3, 5, 1), source(3, 6, 2),
        { assert_tile = { x = 7, y = 5, kind = "sink" } },
        tile(5, 5, "matrix_add", "bottom"), tile(5, 6, "matrix_add", "bottom"),
        tile(9, 2, "matrix_mul", "top"), tile(9, 1, "matrix_mul", "top"))
end

-- Copy, erase everything (from either cell of the tiles), then Paste it back.
add(press_button("copy"), { assert_text = "Copied!" },
    erase(5, 6), empty(5, 5), empty(5, 6),
    pick("erase"), click(9, 1), empty(9, 1), empty(9, 2),
    erase(3, 6), empty(3, 6), source(3, 5), { assert_no_text = "SRC 1" },
    erase(3, 5), empty(3, 5),
    erase(7, 5),
    press_button("paste"))
board()
add({ assert_text = "SRC 2" }, tool("matrix_add", "M+>"))

-- Test: two pushers bring both matrices onto the tile, which merges them.
add(press_button("test"),
    { assert_button = { id = "palette:matrix_add", visible = true } },
    { assert_button = { id = "palette:matrix_mul", visible = false } })
board()
add({ click_button = { id = "palette:pusher" } },
    click(2, 5), click(2, 6),
    { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
    { drag = { from = { id = "chip:right" }, to = { slot = { 1, 2 } } } },
    { click_button = { id = "psel:B" } },
    { drag = { from = { id = "chip:right" }, to = { slot = { 2, 1 } } } },
    { drag = { from = { id = "chip:right" }, to = { slot = { 2, 2 } } } },
    { assert_matrices = { { x = 3, y = 5, values = { { 2 } } }, { x = 3, y = 6, values = { { 1 } } } } },
    { click_button = "Run" },
    -- Only the sum is left; the repeating commands carry it on to the sink.
    { wait_until = { matrices = { { values = { { 3 } } } }, max_frames = 120 } },
    { wait_until = { text = "WIN!", max_frames = 600 } },
    { click_button = { id = "cmd:menu" } },
    { assert_text = "PUZZLE EDITOR" })
board()

return {
    {
        name = "build, copy, erase, paste and test a two-source puzzle",
        given = { solved = {} },
        steps = steps,
    },
}
