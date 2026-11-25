-- lua/game/op_tiles.lua
-- Op tile logic and drawing for on-tile editing: symbols, default params, param limits,
-- click handling, cell content, and the editor's tile model (footprint, construction,
-- import and resize). Stateless: callers pass the matrix limits, cell size, fonts and
-- editability.

local OpTiles = {}

OpTiles.SYMBOLS = {
    transpose  = "T",
    scale_row  = "xRn",
    swap_rows  = "<>R",
    negate     = "-I",
    scalar_mul = "xk",
    add_matrix = "+M",
    sub_matrix = "-M",
    mul_matrix = "xM",
    set_row    = "=R",
    add_rows   = "+R",
    scale_col  = "xCn",
    swap_cols  = "<>C",
    add_cols   = "+C",
    set_col    = "=C",
    rotate_90  = "R90",
    flip_h     = "FLh",
    flip_v     = "FLv",
    abs        = "|x|",
}

local DEFAULT_PARAMS = {
    scale_row  = {row=1,   scalar=2},
    swap_rows  = {row_a=1, row_b=2},
    scalar_mul = {scalar=2},
    set_row    = {row=1},
    add_rows   = {src=1,   dst=2, scalar=1},
    scale_col  = {col=1,   scalar=2},
    swap_cols  = {col_a=1, col_b=2},
    add_cols   = {src=1,   dst=2, scalar=1},
}

local VALUE_MIN, VALUE_MAX = -9, 9
local SWAP_MAX = 4   -- swap indices are 1..4 whatever the matrix size

-- Ops that expose editable params. `limit` names the field of `limits` that bounds an
-- index param; params without one are scalars.
local PARAM_SPECS = {
    scale_row  = { {key="row",    label="row", limit="rows"},
                   {key="scalar", label="x"} },
    swap_rows  = { {key="row_a",  label="r1",  limit="rows"},
                   {key="row_b",  label="r2",  limit="rows"} },
    scalar_mul = { {key="scalar", label="x"} },
    set_row    = { {key="row",    label="row", limit="set_row"} },
    add_rows   = { {key="src",    label="sr",  limit="rows"},
                   {key="dst",    label="dr",  limit="rows"},
                   {key="scalar", label="x"} },
    scale_col  = { {key="col",    label="col", limit="cols"},
                   {key="scalar", label="x"} },
    swap_cols  = { {key="col_a",  label="c1",  limit="cols"},
                   {key="col_b",  label="c2",  limit="cols"} },
    add_cols   = { {key="src",    label="sc",  limit="cols"},
                   {key="dst",    label="dc",  limit="cols"},
                   {key="scalar", label="x"} },
    set_col    = { {key="col",    label="col", limit="cols"} },
}

local MATRIX_OPS = { add_matrix=true, sub_matrix=true, mul_matrix=true }

-- ── Params ─────────────────────────────────────────────────────────────────

function OpTiles.default_params(op)
    local params = {}
    for k, v in pairs(DEFAULT_PARAMS[op] or {}) do params[k] = v end
    return params
end

-- limits = { rows = n, cols = m, set_row = k }
function OpTiles.param_defs(op, limits)
    local specs = PARAM_SPECS[op]
    if not specs then return nil end
    local defs = {}
    for i, s in ipairs(specs) do
        defs[i] = {
            key   = s.key,
            label = s.label,
            min   = s.limit and 1 or VALUE_MIN,
            max   = s.limit and limits[s.limit] or VALUE_MAX,
        }
    end
    return defs
end

-- ── Clicks ─────────────────────────────────────────────────────────────────

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function click_delta(rel_x, cell_size)
    if rel_x < cell_size / 3 then return -1 end
    if rel_x >= cell_size * 2 / 3 then return 1 end
    return 0
end

local function click_value(tile, row, col, delta)
    tile.values = tile.values or {}
    tile.values[row] = tile.values[row] or {}
    if delta ~= 0 then
        tile.values[row][col] = clamp((tile.values[row][col] or 0) + delta, VALUE_MIN, VALUE_MAX)
    end
end

local function click_param(params, def, delta, fallback)
    if delta ~= 0 then
        params[def.key] = clamp((params[def.key] or fallback) + delta, def.min, def.max)
    end
end

-- A band of scale_row / scale_col: select it first, then edit the scalar.
local function click_band(params, key, band, delta)
    if band ~= params[key] then
        params[key] = band
    elseif delta ~= 0 then
        params.scalar = clamp((params.scalar or 2) + delta, VALUE_MIN, VALUE_MAX)
    end
end

local function click_swap(params, key, other_key, delta)
    if delta == 0 then return end
    local new_val = clamp((params[key] or 1) + delta, 1, SWAP_MAX)
    if new_val ~= params[other_key] then params[key] = new_val end
end

-- Applies a left click on the tile cell at 0-based offset (dc, dr) from the anchor, rel_x
-- pixels from that cell's left edge. Returns true when the cell is a param or value cell.
-- Ignores tile.locked / tile.fixed: the caller decides editability.
function OpTiles.click(tile, dc, dr, rel_x, cell_size, limits)
    local op = tile.op
    local delta = click_delta(rel_x, cell_size)

    if MATRIX_OPS[op] then
        click_value(tile, dr + 1, dc + 1, delta)
        return true
    end

    if op == "set_row" and dc > 0 then
        click_value(tile, 1, dc, delta)
        return true
    end
    if op == "set_col" and dr > 0 then
        click_value(tile, dr, 1, delta)
        return true
    end

    local defs = OpTiles.param_defs(op, limits)
    if not defs then
        return dc >= 1
    end
    tile.params = tile.params or {}
    local params = tile.params

    if op == "set_row" or op == "set_col" then
        click_param(params, defs[1], delta, 1)
    elseif op == "scale_row" then
        click_band(params, "row", dr + 1, delta)
    elseif op == "scale_col" then
        click_band(params, "col", dc + 1, delta)
    elseif op == "swap_rows" then
        if dr == 0 then click_swap(params, "row_a", "row_b", delta)
        else click_swap(params, "row_b", "row_a", delta) end
    elseif op == "swap_cols" then
        if dc == 0 then click_swap(params, "col_a", "col_b", delta)
        else click_swap(params, "col_b", "col_a", delta) end
    else
        -- scalar_mul, add_rows, add_cols: the anchor is the symbol cell.
        if dc < 1 then return false end
        if defs[dc] then click_param(params, defs[dc], delta, 0) end
    end
    return true
end

-- ── Drawing ────────────────────────────────────────────────────────────────

local function value_color(editable)
    if editable then love.graphics.setColor(0.95, 0.85, 0.5, 1)
    else love.graphics.setColor(0.65, 0.65, 0.4, 1) end
end

local function band_color(editable)
    if editable then love.graphics.setColor(1.0, 0.85, 0.4, 1)
    else love.graphics.setColor(0.65, 0.65, 0.4, 1) end
end

local function draw_marks(sx, sy, cs, fonts)
    love.graphics.setFont(fonts.ui)
    love.graphics.printf("-", sx, sy + cs - 18, cs / 3, "center")
    love.graphics.printf("+", sx + cs * 2 / 3, sy + cs - 18, cs / 3, "center")
end

-- A small label on top, the number in the middle, -/+ marks at the bottom.
local function draw_labelled(label, val, sx, sy, cs, fonts, editable)
    love.graphics.setColor(0.65, 0.5, 0.15, 1)
    love.graphics.setFont(fonts.ui)
    love.graphics.printf(label, sx, sy + 5, cs, "center")

    value_color(editable)
    love.graphics.setFont(fonts.cell)
    love.graphics.printf(tostring(val), sx, sy + cs / 2 - 10, cs, "center")

    if editable then
        love.graphics.setColor(0.50, 0.38, 0.14, 1)
        draw_marks(sx, sy, cs, fonts)
    end
end

local function draw_param(tile, index, sx, sy, cs, fonts, editable)
    local spec = (PARAM_SPECS[tile.op] or {})[index]
    if not spec then return end
    draw_labelled(spec.label, (tile.params or {})[spec.key] or 0, sx, sy, cs, fonts, editable)
end

local function draw_value(tile, row, col, label, sx, sy, cs, fonts, editable)
    local v = tile.values and tile.values[row] and tile.values[row][col] or 0
    draw_labelled(label, v, sx, sy, cs, fonts, editable)
end

-- prefix is "R" (scale_row) or "C" (scale_col); they place the label and scalar differently.
local function draw_band(tile, band, prefix, sx, sy, cs, fonts, editable)
    local params = tile.params or {}
    local is_row = prefix == "R"
    local selected = band == params[is_row and "row" or "col"]

    if not selected then
        love.graphics.setColor(0.55, 0.40, 0.12, 1)
        love.graphics.setFont(fonts.ui)
        love.graphics.printf(prefix .. band, sx, sy + cs / 2 - 7, cs, "center")
        return
    end

    love.graphics.setColor(0.35, 0.22, 0.04, 1)
    love.graphics.rectangle("fill", sx, sy, cs, cs)
    band_color(editable)
    love.graphics.setFont(fonts.ui)
    love.graphics.print(prefix .. band, sx + 4, is_row and (sy + cs / 2 - 7) or (sy + 5))
    love.graphics.setFont(fonts.cell)
    love.graphics.printf("×" .. (params.scalar or 2), sx, sy + cs / 2 - 9, cs,
        is_row and "right" or "center")
    if editable then
        love.graphics.setColor(0.63, 0.50, 0.19, 1)
        draw_marks(sx, sy, cs, fonts)
    end
end

local function draw_swap(label, sx, sy, cs, fonts, editable)
    value_color(editable)
    love.graphics.setFont(fonts.cell)
    love.graphics.printf(label, sx, sy + cs / 2 - 9, cs, "center")
    if editable then
        love.graphics.setColor(0.50, 0.38, 0.14, 1)
        draw_marks(sx, sy, cs, fonts)
    end
end

-- Draws the content of one tile cell (no tile background or border). (sx, sy) is the cell's
-- top-left; fonts = { cell = <font>, ui = <font> }.
function OpTiles.draw_cell(tile, dc, dr, sx, sy, cell_size, fonts, editable)
    local op, cs = tile.op, cell_size
    local anchor = dc == 0 and dr == 0
    local params = tile.params or {}

    if MATRIX_OPS[op] then
        if anchor then   -- small op symbol top-left
            love.graphics.setColor(0.56, 0.44, 0.21, 1)
            love.graphics.setFont(fonts.ui)
            love.graphics.print(OpTiles.SYMBOLS[op], sx + 2, sy + 2)
        end
        draw_value(tile, dr + 1, dc + 1, (dc + 1) .. "," .. (dr + 1), sx, sy, cs, fonts, editable)
    elseif op == "scale_row" then
        draw_band(tile, dr + 1, "R", sx, sy, cs, fonts, editable)
    elseif op == "scale_col" then
        draw_band(tile, dc + 1, "C", sx, sy, cs, fonts, editable)
    elseif op == "swap_rows" then
        local n = (dr == 0) and (params.row_a or 1) or (params.row_b or 2)
        draw_swap("R" .. n, sx, sy, cs, fonts, editable)
    elseif op == "swap_cols" then
        local n = (dc == 0) and (params.col_a or 1) or (params.col_b or 2)
        draw_swap("C" .. n, sx, sy, cs, fonts, editable)
    elseif op == "set_row" then
        if anchor then draw_param(tile, 1, sx, sy, cs, fonts, editable)
        else draw_value(tile, 1, dc, "c" .. dc, sx, sy, cs, fonts, editable) end
    elseif op == "set_col" then
        if anchor then draw_param(tile, 1, sx, sy, cs, fonts, editable)
        else draw_value(tile, dr, 1, "r" .. dr, sx, sy, cs, fonts, editable) end
    elseif anchor then
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.setFont(fonts.cell)
        love.graphics.printf(OpTiles.SYMBOLS[op] or "?", sx, sy + cs / 2 - 8, cs, "center")
    else
        draw_param(tile, dc, sx, sy, cs, fonts, editable)
    end
end

-- The swap mark between the two cells of a swap tile; (sx, sy) is the anchor's top-left.
-- Call after the cells.
function OpTiles.draw_overlay(tile, sx, sy, cell_size, fonts)
    local mark, x, y, align
    if tile.op == "swap_rows" then
        mark, x, y, align = "⇅", sx, sy + cell_size - 8, "center"
    elseif tile.op == "swap_cols" then
        mark, x, y, align = "⇄", sx + cell_size - 8, sy, "left"
    else
        return
    end
    love.graphics.setColor(0.9, 0.7, 0.3, 1)
    love.graphics.setFont(fonts.ui)
    love.graphics.printf(mark, x, y, cell_size, align)
end

-- ── Tile model (puzzle editor) ─────────────────────────────────────────────
-- MatrixScene keeps its own tile construction, footprint and resize rules.

local SIZE_MAX = 4

-- Footprint of an op tile on the grid, as w (cols), h (rows).
function OpTiles.footprint(op, tile_rows, tile_cols)
    if MATRIX_OPS[op] then return tile_cols or 1, tile_rows or 1 end
    if op == "scale_row" then return 1, tile_rows or 4 end
    if op == "scale_col" then return tile_cols or 4, 1 end
    if op == "set_row"   then return 1 + (tile_cols or 1), 1 end
    if op == "set_col"   then return 1, 1 + (tile_rows or 1) end
    if op == "scalar_mul" or op == "swap_cols" then return 2, 1 end
    if op == "swap_rows" then return 1, 2 end
    if op == "add_rows" or op == "add_cols" then return 4, 1 end
    return 1, 1
end

-- Size of the value block of an op as rows, cols; nil for ops without values.
local function value_size(op, tile_rows, tile_cols)
    if MATRIX_OPS[op] then return tile_rows, tile_cols end
    if op == "set_row" then return 1, tile_cols end
    if op == "set_col" then return tile_rows, 1 end
    return nil
end

local function default_value(op)
    return op == "mul_matrix" and 1 or 0
end

local function filled_values(rows, cols, fill)
    local values = {}
    for r = 1, rows do
        values[r] = {}
        for c = 1, cols do values[r][c] = fill end
    end
    return values
end

local function deep_copy(v)
    if type(v) ~= "table" then return v end
    local copy = {}
    for k, item in pairs(v) do copy[k] = deep_copy(item) end
    return copy
end

local function with_footprint(tile)
    tile.width, tile.height = OpTiles.footprint(tile.op, tile.tile_rows, tile.tile_cols)
    return tile
end

-- A freshly placed editor tile with the game's default params and values.
-- input_rows sets the starting size of set_col.
function OpTiles.new_tile(op, input_rows)
    local tile = { kind="op", op=op, locked=true, params=OpTiles.default_params(op) }

    if MATRIX_OPS[op] then tile.tile_rows, tile.tile_cols = 1, 1
    elseif op == "scale_row" then tile.tile_rows = 4
    elseif op == "scale_col" then tile.tile_cols = 4
    elseif op == "set_row" then tile.tile_cols = 1
    elseif op == "set_col" then
        tile.tile_rows  = input_rows
        tile.params.col = 1
    end

    local rows, cols = value_size(op, tile.tile_rows, tile.tile_cols)
    if rows then tile.values = filled_values(rows, cols, default_value(op)) end
    return with_footprint(tile)
end

-- The same shape for an imported kind="op" def entry. Missing fields are filled with what
-- the game does at runtime (not new-tile defaults); given fields are kept as they are.
function OpTiles.tile_from_def(entry)
    local op = entry.op
    local tile = {
        kind="op", op=op, locked=true,
        params    = deep_copy(entry.params) or {},
        values    = deep_copy(entry.values),
        tile_rows = entry.tile_rows,
        tile_cols = entry.tile_cols,
    }

    if MATRIX_OPS[op] then
        tile.tile_rows = tile.tile_rows or 1
        tile.tile_cols = tile.tile_cols or 1
    elseif op == "scale_row" then tile.tile_rows = tile.tile_rows or 4
    elseif op == "scale_col" then tile.tile_cols = tile.tile_cols or 4
    elseif op == "set_row"   then tile.tile_cols = tile.tile_cols or 1
    elseif op == "set_col"   then tile.tile_rows = tile.tile_rows or 1
    end

    -- Index params start at 1, except the second index of a pair; scalars are 1.
    for _, spec in ipairs(PARAM_SPECS[op] or {}) do
        local second = spec.key == "row_b" or spec.key == "col_b" or spec.key == "dst"
        tile.params[spec.key] = tile.params[spec.key] or (second and 2 or 1)
    end

    local rows, cols = value_size(op, tile.tile_rows, tile.tile_cols)
    if rows then
        tile.values = tile.values or {}
        for r = 1, rows do
            tile.values[r] = tile.values[r] or {}
            for c = 1, cols do tile.values[r][c] = tile.values[r][c] or 0 end
        end
    end

    tile.width, tile.height = OpTiles.footprint(op, tile.tile_rows, tile.tile_cols)
    tile.width  = entry.width  or tile.width
    tile.height = entry.height or tile.height
    return tile
end

local RESIZE = {
    grow_col   = { dim="cols", delta= 1 },
    shrink_col = { dim="cols", delta=-1 },
    grow_row   = { dim="rows", delta= 1 },
    shrink_row = { dim="rows", delta=-1 },
}

-- Current tile size as rows, cols (1 for a dimension the tile does not state).
local function tile_size(tile)
    local rows = tile.tile_rows or (tile.op == "scale_row" and 4) or 1
    local cols = tile.tile_cols or (tile.op == "scale_col" and 4) or 1
    return rows, cols
end

-- The resize actions the tile's size allows, in a fixed order. Ignores tile.locked;
-- whether the grid has room is the caller's check.
function OpTiles.resize_actions(tile)
    local op = tile.op
    local rows, cols = tile_size(tile)
    local actions = {}
    if MATRIX_OPS[op] or op == "scale_col" or op == "set_row" then
        if cols < SIZE_MAX then actions[#actions+1] = "grow_col" end
        if cols > 1        then actions[#actions+1] = "shrink_col" end
    end
    if MATRIX_OPS[op] or op == "scale_row" or op == "set_col" then
        if rows < SIZE_MAX then actions[#actions+1] = "grow_row" end
        if rows > 1        then actions[#actions+1] = "shrink_row" end
    end
    return actions
end

-- Brings tile.values from old_rows x old_cols to rows x cols: new cells get the default
-- value (replacing stale entries) and anything beyond the new size is removed.
local function resize_values(tile, old_rows, old_cols, rows, cols)
    local old = tile.values or {}
    local values = {}
    for r = 1, rows do
        values[r] = {}
        for c = 1, cols do
            if r > old_rows or c > old_cols then
                values[r][c] = default_value(tile.op)
            else
                values[r][c] = old[r] and old[r][c]
            end
        end
    end
    tile.values = values
end

-- Applies one resize action to the tile (size, footprint, values, selected band).
-- Returns false, changing nothing, if the action is not allowed. Does not touch any grid.
function OpTiles.resize(tile, action)
    local allowed = false
    for _, a in ipairs(OpTiles.resize_actions(tile)) do
        if a == action then allowed = true end
    end
    if not allowed then return false end

    local op = tile.op
    local change = RESIZE[action]
    local rows, cols = tile_size(tile)
    local new_rows, new_cols = rows, cols
    if change.dim == "rows" then
        new_rows = rows + change.delta
        tile.tile_rows = new_rows
    else
        new_cols = cols + change.delta
        tile.tile_cols = new_cols
    end
    with_footprint(tile)

    local old_v_rows, old_v_cols = value_size(op, rows, cols)
    if old_v_rows then
        resize_values(tile, old_v_rows, old_v_cols, value_size(op, new_rows, new_cols))
    end

    local params = tile.params
    if op == "scale_row" and params and params.row then
        params.row = clamp(params.row, 1, new_rows)
    elseif op == "scale_col" and params and params.col then
        params.col = clamp(params.col, 1, new_cols)
    end
    return true
end

return OpTiles
