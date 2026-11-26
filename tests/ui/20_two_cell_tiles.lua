-- Two-cell tiles in the puzzle scene through real input: placing by click and
-- drag, turning (tile, button, T), invalid spots, Mv, erasing, locked and fixed
-- tiles, the full palette, and a merge won with a player-placed turned tile.

local function from_def(def)
    return function(sm)
        return require("lua/game/scenes/matrix_scene").new_from_def(def, sm)
    end
end

local A = { { 1, 2 }, { 3, 4 } }
local B = { { 10, 20 }, { 30, 40 } }
local SUM = { { 11, 22 }, { 33, 44 } }

local def = {
    name = "Turn Table", grid_w = 10, grid_h = 10,
    source  = { x = 2, y = 3 }, input  = { rows = 2, cols = 2, values = A },
    source2 = { x = 6, y = 3 }, input2 = { rows = 2, cols = 2, values = B },
    sink    = { x = 6, y = 5 },
    target  = { rows = 2, cols = 2, values = SUM },
    ops     = { "matrix_add", "matrix_mul" },
    locked  = { { kind = "op", op = "matrix_add", x = 9, y = 9, params = { facing = "left" } } },
    fixed_ops = { { op = "matrix_mul", params = { facing = "bottom" } } },
}

local all_def = {
    name = "Everything", grid_w = 10, grid_h = 10,
    source = { x = 1, y = 1 }, input = { rows = 1, cols = 1, values = { { 1 } } },
    sink = { x = 10, y = 10 }, target = { rows = 1, cols = 1, values = { { 1 } } },
    ops = { "scalar_mul", "edge_scale", "scalar_add", "edge_add", "scalar_sub", "edge_sub",
            "transpose", "rotate_90", "flip_h", "flip_v", "matrix_add", "matrix_mul" },
}

local function pick(id) return { click_button = { id = "palette:" .. id } } end
local function click(x, y, part) return { click_cell = { x, y, part = part } } end
local function erase(x, y) return { right_click_cell = { x, y } } end
local function tool(id, text) return { assert_button = { id = "palette:" .. id, label = text } } end
local function labelled(text) return { assert_button = { label = text } } end
local function tile(x, y, op, facing)
    return { assert_tile = { x = x, y = y, kind = "op", op = op, facing = facing } }
end
local function empty(x, y) return { assert_tile = { x = x, y = y } } end
local function drag(from, x, y) return { drag = { from = from, to = { cell = { x, y } } } } end
local function pal(id) return { id = "palette:" .. id } end
local function at(x, y) return { cell = { x, y } } end

local specs = {}
local function spec(name, d, steps)
    specs[#specs + 1] = { name = name, make_scene = from_def(d), steps = steps }
end

spec("place by click and drag, turn from either cell and any third", def, {
    pick("matrix_add"),
    labelled("M+>"),
    click(4, 7),
    tile(4, 7, "matrix_add", "right"),
    tile(5, 7, "matrix_add", "right"),
    click(5, 7, "left"),
    tile(4, 8, "matrix_add", "bottom"),
    empty(5, 7),
    click(4, 7, "right"),
    tile(3, 7, "matrix_add", "left"),
    click(3, 7),
    tile(4, 6, "matrix_add", "top"),
    pick("matrix_mul"),                          -- another tool turns it too
    click(4, 6, "left"),
    tile(5, 7, "matrix_add", "right"),
    drag(pal("matrix_mul"), 7, 7),
    tile(8, 7, "matrix_mul", "right"),
    labelled("Mx>"),                             -- the drag did not turn the tool
    -- Invalid spots: partner off the grid, partner or anchor occupied.
    click(10, 1),
    empty(10, 1),
    drag(pal("matrix_mul"), 6, 7),
    empty(6, 7),
    tile(7, 7, "matrix_mul", "right"),
    pick("pusher"),
    click(2, 9),
    pick("matrix_add"),
    click(1, 9),
    empty(1, 9),
    click(2, 9),
    { assert_tile = { x = 2, y = 9, kind = "pusher" } },
    -- Erase from either cell, by right-click and with the eraser.
    erase(5, 7),
    empty(4, 7),
    empty(5, 7),
    pick("erase"),
    click(8, 7),
    empty(7, 7),
    empty(8, 7),
})

spec("turn the tool with its button and with T", def, {
    pick("matrix_add"),
    labelled("M+>"),
    pick("matrix_add"),
    labelled("M+v"),
    -- Dragging from the selected button places without turning it.
    drag(pal("matrix_add"), 4, 7),
    tile(4, 8, "matrix_add", "bottom"),
    labelled("M+v"),
    -- Leaving the button and coming back is a drag, not a click.
    { mouse_down = pal("matrix_add") },
    { hover_button = at(1, 1) },
    { mouse_up = pal("matrix_add") },
    labelled("M+v"),
    { press = "t" },                             -- pointer on the button: the tool
    labelled("M+<"),
    { hover_button = at(4, 8) },
    { press = "t" },                             -- pointer on a tile: the tile
    tile(3, 7, "matrix_add", "left"),
    labelled("M+<"),
    { hover_button = at(1, 1) },
    { press = "t" },
    labelled("M+^"),
    tile(3, 7, "matrix_add", "left"),
    -- T while holding a palette drag turns the tool being dragged.
    { mouse_down = pal("matrix_mul") },
    { press = "t" },
    labelled("Mxv"),
    { hover_button = at(7, 7) },
    { assert_text = "L Mx" },
    { assert_text = "R Mx" },
    { mouse_up = at(7, 7) },
    tile(7, 8, "matrix_mul", "bottom"),
    { assert_no_text = "R Mx" },
})

spec("Mv keeps the grabbed cell under the cursor and cancels cleanly", def, {
    pick("matrix_add"),
    click(3, 7),
    pick("drag"),
    drag(at(4, 7), 7, 8),                        -- held by the right operand
    tile(6, 8, "matrix_add", "right"),
    tile(7, 8, "matrix_add", "right"),
    empty(3, 7),
    empty(4, 7),
    drag(at(7, 8), 1, 7),                        -- anchor off the grid
    tile(6, 8, "matrix_add", "right"),
    drag(at(7, 8), 7, 3),                        -- onto a source
    tile(6, 8, "matrix_add", "right"),
    { mouse_down = at(7, 8) },
    { press = "t" },
    { assert_text = "R M+" },
    { right_click_cell = { 2, 8 } },             -- cancel: position and facing
    { mouse_up = at(2, 8) },
    tile(6, 8, "matrix_add", "right"),
    tile(7, 8, "matrix_add", "right"),
    empty(2, 8),
    { mouse_down = at(7, 8) },
    { press = "t" },
    { mouse_up = { id = "cmd:menu" } },          -- released off the grid
    tile(7, 8, "matrix_add", "right"),
    { mouse_down = at(6, 8) },
    { press = "t" },
    { mouse_up = at(3, 6) },                     -- turned in hand, then dropped
    tile(3, 6, "matrix_add", "bottom"),
    tile(3, 7, "matrix_add", "bottom"),
    empty(6, 8),
})

spec("locked and fixed tiles", def, {
    tile(8, 9, "matrix_add", "left"),
    pick("matrix_mul"),
    click(8, 9),
    erase(8, 9),
    tile(9, 9, "matrix_add", "left"),
    { hover_button = at(8, 9) },
    { press = "t" },                             -- locked: T goes to the tool
    tile(8, 9, "matrix_add", "left"),
    labelled("Mxv"),
    pick("erase"),
    click(9, 9),
    pick("drag"),
    drag(at(9, 9), 3, 8),
    tile(9, 9, "matrix_add", "left"),
    empty(3, 8),
    pick("fixed:matrix_mul"),
    tool("fixed:matrix_mul", "Mxv!"),
    pick("fixed:matrix_mul"),
    { press = "t" },
    tool("fixed:matrix_mul", "Mxv!"),
    click(4, 7),
    tile(4, 8, "matrix_mul", "bottom"),
    click(4, 8),
    { hover_button = at(4, 7) },
    { press = "t" },
    tile(4, 8, "matrix_mul", "bottom"),
    pick("drag"),
    { mouse_down = at(4, 8) },
    { press = "t" },
    { mouse_up = at(2, 8) },
    tile(2, 7, "matrix_mul", "bottom"),
    tile(2, 8, "matrix_mul", "bottom"),
    erase(2, 8),
    empty(2, 7),
})

spec("all twelve ops fit without scrolling", all_def, {
    { assert_button = { id = "palette:scroll_down", visible = false } },
    { assert_button = { id = "palette:scroll_up", visible = false } },
    pick("flip_v"),
    pick("matrix_add"),
    labelled("M+>"),
    pick("matrix_mul"),
    labelled("Mx>"),
    pick("drag"),
    pick("erase"),
    { assert_button = { id = "palette:erase", selected = true } },
})

spec("merge with a player-placed turned tile", def, {
    pick("matrix_add"),
    pick("matrix_add"),
    pick("matrix_add"),
    labelled("M+<"),
    click(5, 3),
    tile(4, 3, "matrix_add", "left"),
    pick("pusher"),
    click(1, 3),
    click(8, 3),
    click(5, 2),
    { drag = { from = { id = "chip:right" }, to = { slot = { 1, 1 } } } },
    { click_button = { id = "psel:B" } },
    { drag = { from = { id = "chip:left" }, to = { slot = { 2, 1 } } } },
    { click_button = { id = "psel:C" } },
    { drag = { from = { id = "chip:down" }, to = { slot = { 3, 2 } } } },
    { click_button = { id = "psel:A" } },
    { drag = { from = { id = "chip:stop" }, to = { slot = { 1, 2 } } } },
    { click_button = { id = "psel:B" } },
    { drag = { from = { id = "chip:stop" }, to = { slot = { 2, 2 } } } },
    { click_button = "Run" },
    -- The result takes the left operand's place: source 2's side of the tile.
    { wait_until = { matrices = { { values = SUM } }, max_frames = 60 } },
    { wait_until = { text = "WIN!", max_frames = 600 } },
    { wait = 30 },
    { assert_matrices = { { x = 5, y = 4, values = SUM } } },
    { click_button = "Continue" },
    { assert_text = "SOLVED!" },
})

return specs
