-- Editor resize strips: geometry never collides or blocks a value cell's click points,
-- and strips are offered only when the resized tile fits.
local runner      = require("lua/headless/runner")
local UI          = require("lua/core/ui")
local UIRunner    = require("lua/headless/ui_runner")
local OpTiles     = require("lua/game/op_tiles")
local EditorScene = require("lua/game/scenes/editor_scene")

local CS = 63

local function new_editor()
    local ctx = runner.setup(function(_, sm) return EditorScene.new(sm) end)
    runner.tick(ctx.input, ctx.sm, 1)
    return ctx.sm.current
end

local function strips(scene)
    local out = {}
    for _, e in ipairs(scene:ui_elements()) do
        if e.kind == "resize" then out[#out+1] = e end
    end
    return out
end

local function place(scene, x, y, tile)
    if not scene:_area_free(x, y, tile.width, tile.height) then return false end
    scene._grid:set_multi_2d(x, y, tile, tile.width, tile.height)
    return true
end

-- Strips are apart from each other and from the -, centre and + points of every tile cell
local function check_geometry(scene, label)
    local list = strips(scene)
    for i = 1, #list do
        for j = i + 1, #list do
            assert(not UI.overlaps(list[i].rect, list[j].rect),
                label .. ": " .. list[i].id .. " overlaps " .. list[j].id)
        end
    end
    local err = UIRunner.check_invariants(scene:ui_elements())
    assert(not err, label .. ": " .. tostring(err))

    for cy = 1, 10 do
        for cx = 1, 10 do
            if scene._grid.cells[cy][cx] then
                local cell = UI.find(scene:ui_elements(), "cell:" .. cx .. "," .. cy).rect
                for _, rel in ipairs({ CS / 6, CS / 2, 5 * CS / 6 }) do
                    -- exact and rounded to whole pixels, as the UI runner clicks
                    for _, px in ipairs({ cell.x + rel, math.floor(cell.x + rel + 0.5) }) do
                        for _, py in ipairs({ cell.y + CS / 2, math.floor(cell.y + CS / 2 + 0.5) }) do
                            local e = UI.element_at(list, px, py)
                            assert(not e, label .. ": " .. (e and e.id or "") ..
                                " covers a click point of cell " .. cx .. "," .. cy)
                        end
                    end
                end
            end
        end
    end
    return #list
end

local RESIZABLE = {
    "add_matrix", "sub_matrix", "mul_matrix", "set_row", "set_col", "scale_row", "scale_col",
}

-- Dense random layouts of resizable tiles in random sizes (fixed seed generator)
do
    local seed = 12345
    local function rand(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return math.floor(seed / 65536) % n + 1
    end

    local scene, seen = new_editor(), 0
    for layout = 1, 150 do
        scene:_load_def({ input  = { rows = 1, cols = 1, values = { {0} } },
                          target = { rows = 1, cols = 1, values = { {0} } },
                          source = { x = 99, y = 99 }, sink = { x = 99, y = 99 } })
        for _ = 1, 60 do
            local tile = OpTiles.new_tile(RESIZABLE[rand(#RESIZABLE)], rand(4))
            for _ = 1, rand(7) - 1 do
                local actions = OpTiles.resize_actions(tile)
                if #actions > 0 then OpTiles.resize(tile, actions[rand(#actions)]) end
            end
            place(scene, rand(10), rand(10), tile)
        end
        seen = seen + check_geometry(scene, "layout " .. layout)
    end
    assert(seen > 1000, "layouts produce strips: " .. seen)
    print("PASS: strip geometry over random layouts")
end

-- Diagonal neighbours: one tile's grow_row next to another tile's grow_col
do
    local s = new_editor()
    assert(place(s, 3, 4, OpTiles.new_tile("add_matrix", 2)))
    local above = OpTiles.new_tile("add_matrix", 2)
    OpTiles.resize(above, "grow_col")
    assert(place(s, 4, 3, above))
    assert(UI.find(s:ui_elements(), "resize:3,4:grow_col"), "left tile grows right")
    assert(UI.find(s:ui_elements(), "resize:4,3:grow_row"), "upper tile grows down")
    check_geometry(s, "diagonal")
    print("PASS: diagonal neighbours")
end

-- A strip's left click applies its action and re-places the whole footprint
do
    local s = new_editor()
    assert(place(s, 2, 2, OpTiles.new_tile("add_matrix", 2)))
    local function press(id)
        local x, y = UI.centre(UI.find(s:ui_elements(), id).rect)
        s:mouse_pressed(x, y, 1)
    end
    press("resize:2,2:grow_col")
    press("resize:2,2:grow_row")
    for y = 2, 3 do
        for x = 2, 3 do
            local ax, ay = s._grid:get_anchor(x, y)
            assert(s._grid.cells[y][x] and ax == 2 and ay == 2, "cell " .. x .. "," .. y .. " covered")
        end
    end
    press("resize:2,2:shrink_col")
    assert(s._grid.cells[2][3] == nil and s._grid.cells[3][3] == nil, "old refs cleared")
    -- a middle click on a strip does nothing
    local x, y = UI.centre(UI.find(s:ui_elements(), "resize:2,2:shrink_row").rect)
    s:mouse_pressed(x, y, 3)
    assert(s._grid:get(2, 3), "tile unchanged")
    print("PASS: strip click re-places the tile")
end

-- Imported width/height that differ from the footprint: no strip may overwrite a
-- neighbour or leave the grid
do
    local s = new_editor()
    s:_load_def({
        input  = { rows = 1, cols = 1, values = { {0} } },
        target = { rows = 1, cols = 1, values = { {0} } },
        locked = {
            -- one cell, but four rows: shrinking would cover (1,2), which is taken
            { kind = "op", op = "scale_row", x = 1, y = 1, height = 1 },
            { kind = "op", op = "transpose", x = 1, y = 2 },
            -- the same at the bottom edge: shrinking would leave the grid
            { kind = "op", op = "scale_row", x = 5, y = 10, height = 1 },
            -- free below: shrinking is offered and gives the derived footprint
            { kind = "op", op = "scale_row", x = 8, y = 1, height = 1 },
        },
    })
    local els = s:ui_elements()
    assert(not UI.find(els, "resize:1,1:shrink_row"), "blocked by a tile")
    assert(not UI.find(els, "resize:5,10:shrink_row"), "blocked by the edge")
    local strip = assert(UI.find(els, "resize:8,1:shrink_row"), "free: offered")
    local x, y = UI.centre(strip.rect)
    s:mouse_pressed(x, y, 1)
    assert(s._grid:get(8, 3) and s._grid:get(8, 4) == nil, "three rows after shrink")
    print("PASS: mismatched imported footprints")
end
