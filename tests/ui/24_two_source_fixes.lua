-- Through real input: a palette drag never turns a two-cell tile (a click does,
-- the dragged eraser removes it), and an editor board with only SRC2 survives
-- Copy and Paste and can be Tested.

local function from_def(def)
    return function(sm)
        return require("lua/game/scenes/matrix_scene").new_from_def(def, sm)
    end
end

local def = {
    name = "Drop Table", grid_w = 10, grid_h = 10,
    source = { x = 2, y = 2 }, input = { rows = 1, cols = 1, values = { { 1 } } },
    sink = { x = 10, y = 10 }, target = { rows = 1, cols = 1, values = { { 1 } } },
    ops = { "transpose", "matrix_add", "matrix_mul" },
}

local function pal(id) return { id = "palette:" .. id } end
local function drop(id, x, y) return { drag = { from = pal(id), to = { cell = { x, y } } } } end
local function tile(x, y, facing)
    return { assert_tile = { x = x, y = y, kind = "op", op = "matrix_add", facing = facing } }
end

local drops = {
    { click_button = pal("matrix_add") },
    { click_cell = { 5, 5 } },
    tile(5, 5, "right"),
}
for _, id in ipairs({ "transpose", "pusher", "matrix_add", "matrix_mul" }) do
    for x = 5, 6 do
        drops[#drops + 1] = drop(id, x, 5)
        drops[#drops + 1] = tile(5, 5, "right")
        drops[#drops + 1] = tile(6, 5, "right")
    end
end
for _, step in ipairs({
    { click_cell = { 6, 5 } },
    tile(5, 5, "bottom"),
    drop("erase", 5, 6),
    { assert_tile = { x = 5, y = 5 } },
    { assert_tile = { x = 5, y = 6 } },
}) do
    drops[#drops + 1] = step
end

return {
    {
        name = "a palette drag leaves a two-cell tile alone",
        make_scene = from_def(def),
        steps = drops,
    },
    {
        name = "editor Copy and Paste keep a lone SRC2",
        given = { solved = {} },
        steps = {
            { click_button = "Editor" },
            { click_button = { id = "editor:pal:source2" } },
            { click_cell = { 2, 1 } },
            { click_button = { id = "editor:copy" } },
            { click_button = { id = "editor:pal:erase" } },
            { click_cell = { 2, 1 } },
            { click_button = { id = "editor:paste" } },
            { assert_tile = { x = 2, y = 1, kind = "source", index = 2 } },
            { assert_tile = { x = 4, y = 1, kind = "source", index = 1 } },
            { click_button = { id = "editor:test" } },
            { assert_matrices = {
                { x = 4, y = 1, values = { { 1, 0 }, { 0, 1 } } },
                { x = 2, y = 1, values = { { 1, 0 }, { 0, 1 } } },
            } },
        },
    },
}
