-- UI specs for the editor's Erase tool and for tools and Paste never covering a tile.
local function open_editor()
    return { press = "e" }
end

local function tool(name)
    return { click_button = { id = "editor:pal:" .. name } }
end

local function cell(x, y)
    return { click_button = { id = "cell:" .. x .. "," .. y } }
end

return {
    {
        name = "editor: Erase button removes a tile, including from a non-anchor source cell",
        steps = {
            open_editor(),
            { assert_button = { id = "editor:pal:erase", label = "Erase", selected = false } },
            tool("source"), cell(3, 2),
            tool("transpose"), cell(6, 6),
            tool("erase"),
            { assert_button = { id = "editor:pal:erase", selected = true } },
            cell(4, 3),
            { assert_tile = { 3, 2 } },
            { assert_tile = { 4, 3 } },
            cell(6, 6),
            { assert_tile = { 6, 6 } },
        },
    },
    {
        name = "editor: the sink tool never replaces an occupied cell",
        steps = {
            open_editor(),
            tool("source"), cell(3, 2),
            tool("transpose"), cell(6, 6),
            tool("sink"), cell(9, 9),
            cell(4, 3),
            { assert_tile = { 4, 3, kind = "source" } },
            { assert_tile = { 9, 9, kind = "sink" } },
            cell(6, 6),
            { assert_tile = { 6, 6, kind = "op", op = "transpose" } },
            { assert_tile = { 9, 9, kind = "sink" } },
            cell(8, 8),
            { assert_tile = { 8, 8, kind = "sink" } },
            { assert_tile = { 9, 9 } },
        },
    },
    {
        name = "editor: Copy then Paste keeps tiles on the default source and sink cells",
        steps = {
            open_editor(),
            tool("transpose"), cell(1, 1),
            tool("flip_h"), cell(10, 10),
            { click_button = { id = "editor:copy" } },
            tool("erase"), cell(1, 1), cell(10, 10),
            { click_button = { id = "editor:paste" } },
            { assert_tile = { 1, 1, kind = "op", op = "transpose" } },
            { assert_tile = { 10, 10, kind = "op", op = "flip_h" } },
        },
    },
}
