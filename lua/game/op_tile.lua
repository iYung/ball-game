-- The one op-tile drawing, shared by the game, editor and recap scenes.
-- Lock and fixed ("=") markers are drawn by the scenes, in the top-right corner.
local Ops = require("lua/game/ops")

local OpTile = {}

local BAR_W     = 4   -- thickness of the targeted-edge bar
local BAR_INSET = 3   -- distance from the targeted side
local BAR_END   = 18  -- gap left at each end, clear of corner markers and -/+ marks

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

-- fonts = { cell = <value font>, ui = <marks and arrow font> }
-- opts  = { marks = bool (dim "-" / "+" on k ops), immutable = bool (dimmer value) }
function OpTile.draw(tile, sx, sy, cs, fonts, opts)
    local op = tile.op
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
