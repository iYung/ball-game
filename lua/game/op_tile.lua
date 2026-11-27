-- The one op-tile drawing, shared by the game, editor and recap scenes.
-- Lock and fixed ("=") markers are drawn by the scenes, in the top-right corner
-- of the tile's anchor cell.
local Ops = require("lua/game/ops")

local OpTile = {}

local BAR_W     = 4   -- thickness of the targeted-edge bar
local BAR_INSET = 3   -- distance from the targeted side
local BAR_END   = 18  -- gap left at each end, clear of corner markers and -/+ marks

local ROLE_FONT_SIZE = 24
local BADGE_SIZE     = 14
-- Background shade of each operand cell of a two-cell tile.
local ROLE_SHADE = { L = { 0.42, 0.27, 0.05 }, R = { 0.13, 0.10, 0.19 } }

local role_font  -- the large L / R font, created on first use

local function draw_edge(edge, sx, sy, cs, font)
    love.graphics.setColor(0.9, 0.7, 0.3, 1)
    love.graphics.setFont(font)
    love.graphics.print(Ops.ARROWS[edge] or "?", sx + 4, sy + 3)

    local far, len = cs - BAR_INSET - BAR_W, cs - 2 * BAR_END
    if edge == "top" then
        love.graphics.rectangle("fill", sx + BAR_END, sy + BAR_INSET, len, BAR_W)
    elseif edge == "right" then
        love.graphics.rectangle("fill", sx + far, sy + BAR_END, BAR_W, len)
    elseif edge == "bottom" then
        love.graphics.rectangle("fill", sx + BAR_END, sy + far, len, BAR_W)
    elseif edge == "left" then
        love.graphics.rectangle("fill", sx + BAR_INSET, sy + BAR_END, BAR_W, len)
    end
end

local function draw_operand_cell(role, label, sx, sy, cs, font)
    local shade = ROLE_SHADE[role]
    love.graphics.setColor(shade[1], shade[2], shade[3], 1)
    love.graphics.rectangle("fill", sx, sy, cs, cs)
    love.graphics.setColor(0.98, 0.93, 0.75, 1)
    love.graphics.setFont(role_font)
    love.graphics.printf(role, sx, sy + 6, cs, "center")
    love.graphics.setColor(0.9, 0.7, 0.3, 1)
    love.graphics.setFont(font)
    love.graphics.printf(label, sx, sy + cs - 19, cs, "center")
end

-- sx, sy is the left-operand cell's top-left; the partner cell follows the facing.
local function draw_two_cell(tile, sx, sy, cs, fonts)
    role_font = role_font or love.graphics.newFont(ROLE_FONT_SIZE)
    local offset = Ops.OFFSETS[Ops.params(tile.op, tile.params).facing]
    local rx, ry = sx + offset.dx * cs, sy + offset.dy * cs
    local label  = Ops.label(tile.op)

    draw_operand_cell("L", label, sx, sy, cs, fonts.cell)
    draw_operand_cell("R", label, rx, ry, cs, fonts.cell)

    -- One border around the pair, none between the cells.
    local w = offset.dx ~= 0 and 2 * cs or cs
    local h = offset.dy ~= 0 and 2 * cs or cs
    love.graphics.setColor(0.9, 0.7, 0.3, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", math.min(sx, rx) + 1, math.min(sy, ry) + 1, w - 2, h - 2)
    love.graphics.setLineWidth(1)
end

-- Small "L" / "R" badge in a cell's top-left corner, drawn on top of a matrix so a
-- covered input cell can still be told apart.
function OpTile.draw_badge(role, sx, sy, cs, font)
    local size = math.min(BADGE_SIZE, cs)
    local shade = ROLE_SHADE[role]
    love.graphics.setColor(shade[1], shade[2], shade[3], 1)
    love.graphics.rectangle("fill", sx + 2, sy + 2, size, size)
    love.graphics.setColor(0.9, 0.7, 0.3, 1)
    love.graphics.rectangle("line", sx + 2, sy + 2, size, size)
    love.graphics.setColor(0.98, 0.93, 0.75, 1)
    love.graphics.setFont(font)
    love.graphics.printf(role, sx + 2, sy + 2, size, "center")
end

-- A matrix hides the tile under it: badges the operand cells of the two-cell
-- tiles (Grid:two_cell_tiles() entries) that are under a drawn matrix. bodies are
-- { matrix, px, py } at their drawn pixel positions, so a sliding matrix badges a
-- cell only once it is over the whole of it.
function OpTile.draw_covered_badges(tiles, bodies, cell_top_left, cs, font)
    for _, entry in ipairs(tiles) do
        for _, cell in ipairs({ { "L", entry.x, entry.y }, { "R", entry.rx, entry.ry } }) do
            local sx, sy = cell_top_left(cell[2], cell[3])
            for _, body in ipairs(bodies) do
                -- Half a pixel of slack absorbs rounding in the slide.
                if sx >= body.px - 0.5 and sx + cs <= body.px + body.matrix.cols * cs + 0.5
                   and sy >= body.py - 0.5 and sy + cs <= body.py + body.matrix.rows * cs + 0.5 then
                    OpTile.draw_badge(cell[1], sx, sy, cs, font)
                    break
                end
            end
        end
    end
end

-- fonts = { cell = <value font>, ui = <marks and arrow font> }
-- opts  = { marks = bool (dim "-" / "+" on k ops), immutable = bool (dimmer value) }
-- A two-cell tile draws both of its cells and ignores opts.
function OpTile.draw(tile, sx, sy, cs, fonts, opts)
    local op = tile.op
    if Ops.is_two_cell(op) then
        draw_two_cell(tile, sx, sy, cs, fonts)
        return
    end
    local has_k = Ops.has_scalar(op)

    love.graphics.setColor(0.21, 0.14, 0.04, 1)
    love.graphics.rectangle("fill", sx, sy, cs, cs)
    love.graphics.setColor(0.9, 0.7, 0.3, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx + 1, sy + 1, cs - 2, cs - 2)
    love.graphics.setLineWidth(1)

    if has_k then
        if opts.immutable then
            love.graphics.setColor(0.65, 0.65, 0.4, 1)
        else
            love.graphics.setColor(0.95, 0.85, 0.5, 1)
        end
    end
    love.graphics.setFont(fonts.cell)
    love.graphics.printf(Ops.tile_text(op, tile.params), sx, sy + cs / 2 - 9, cs, "center")

    if has_k and opts.marks then
        love.graphics.setColor(0.50, 0.38, 0.14, 1)
        love.graphics.setFont(fonts.ui)
        love.graphics.printf("-", sx, sy + cs - 18, cs / 3, "center")
        love.graphics.printf("+", sx + cs * 2 / 3, sy + cs - 18, cs / 3, "center")
    end

    if Ops.has_edge(op) then
        draw_edge(Ops.params(op, tile.params).edge, sx, sy, cs, fonts.ui)
    end
end

return OpTile
