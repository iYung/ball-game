-- Op definitions (lua/game/ops.lua) and the shared tile drawing (op_tile.lua).
local Ops    = require("lua/game/ops")
local OpTile = require("lua/game/op_tile")
local Stubs  = require("lua/headless/stubs")

local function eq(got, want, label)
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function same(got, want, label)
    for k, v in pairs(want) do eq(got[k], v, label .. "." .. tostring(k)) end
    for k in pairs(got) do
        assert(want[k] ~= nil, label .. ": unexpected key " .. tostring(k))
    end
end

-- id, label, scalar default, min, max, has edge
local CASES = {
    { "scalar_mul", "xk",  2,   -9,  9,   false },
    { "edge_scale", "xk^", 2,   -9,  9,   true  },
    { "scalar_add", "+k",  1,   0,   9,   false },
    { "edge_add",   "+k^", 1,   0,   9,   true  },
    { "scalar_sub", "-k",  1,   0,   9,   false },
    { "edge_sub",   "-k^", 1,   0,   9,   true  },
    { "transpose",  "T",   nil, nil, nil, false },
    { "rotate_90",  "R90", nil, nil, nil, false },
    { "flip_h",     "FLh", nil, nil, nil, false },
    { "flip_v",     "FLv", nil, nil, nil, false },
}

eq(#Ops.ORDER, 10, "op count")
same(Ops.EDGES, { "top", "right", "bottom", "left" }, "EDGES")
same(Ops.ARROWS, { top = "^", right = ">", bottom = "v", left = "<" }, "ARROWS")

for i, case in ipairs(CASES) do
    local op, label, default, min, max, edge = unpack(case, 1, 6)
    eq(Ops.ORDER[i], op, "ORDER " .. i)
    eq(Ops.is_op(op), true, op .. " is_op")
    eq(Ops.label(op), label, op .. " label")
    eq(Ops.has_scalar(op), default ~= nil, op .. " has_scalar")
    eq(Ops.has_edge(op), edge, op .. " has_edge")
    local lo, hi = Ops.range(op)
    eq(lo, min, op .. " min")
    eq(hi, max, op .. " max")
    same(Ops.params(op), { scalar = default, edge = edge and "top" or nil }, op .. " defaults")
    eq(Ops.validate(op), true, op .. " validate nil")
    eq(Ops.validate(op, {}), true, op .. " validate empty")

    -- clamping at both limits; centre never changes k
    if default then
        local p = {}
        Ops.click(op, p, "right")
        eq(p.scalar, default + 1, op .. " right from missing")
        p = {}
        Ops.click(op, p, "left")
        eq(p.scalar, default - 1, op .. " left from missing")
        p = Ops.params(op)
        for _ = 1, 25 do Ops.click(op, p, "left") end
        eq(p.scalar, min, op .. " clamps at min")
        for _ = 1, 25 do Ops.click(op, p, "right") end
        eq(p.scalar, max, op .. " clamps at max")
        Ops.click(op, p, "centre")
        eq(p.scalar, max, op .. " centre keeps k")
        eq(p.edge, edge and "right" or nil, op .. " centre edge")
        eq(Ops.validate(op, { scalar = min }), true, op .. " min valid")
        eq(Ops.validate(op, { scalar = max }), true, op .. " max valid")
        for _, bad in ipairs({ min - 1, max + 1, 1.5, "2", 0 / 0, math.huge }) do
            local ok, msg = Ops.validate(op, { scalar = bad })
            eq(ok, false, op .. " rejects " .. tostring(bad))
            eq(msg, "Invalid scalar for " .. op .. ": " .. tostring(bad), op .. " message")
        end
    else
        for _, part in ipairs({ "left", "centre", "right" }) do
            local p = {}
            Ops.click(op, p, part)
            same(p, {}, op .. " " .. part .. " does nothing")
        end
        eq(Ops.tile_text(op), label, op .. " tile_text")
        eq(Ops.fixed_label(op), label .. "!", op .. " fixed_label")
    end
end

-- unknown ops
eq(Ops.is_op("negate"), false, "negate is_op")
eq(Ops.label("negate"), "?", "unknown label")
eq(Ops.has_scalar("negate"), false, "unknown has_scalar")
eq(Ops.has_edge("negate"), false, "unknown has_edge")
eq(Ops.range("negate"), nil, "unknown range")
same(Ops.params("negate", { scalar = 3 }), {}, "unknown params")
eq(Ops.tile_text("negate"), "?", "unknown tile_text")
local unknown = {}
Ops.click("negate", unknown, "right")
Ops.click("negate", unknown, "centre")
same(unknown, {}, "unknown click")

-- params: overrides, unsupported keys dropped, always a fresh table
local over = { scalar = -4, edge = "left", row = 2 }
same(Ops.params("edge_scale", over), { scalar = -4, edge = "left" }, "edge overrides")
same(Ops.params("scalar_add", over), { scalar = -4 }, "whole overrides")
same(Ops.params("flip_h", over), {}, "no-param overrides")
assert(Ops.params("edge_scale", over) ~= over, "params must be a fresh table")
assert(Ops.params("scalar_mul") ~= Ops.params("scalar_mul"), "defaults must be fresh")

-- edge turns clockwise and wraps, keeping k
local p = { scalar = 5 }
for _, want in ipairs({ "right", "bottom", "left", "top", "right" }) do
    Ops.click("edge_add", p, "centre")
    eq(p.edge, want, "clockwise")
    eq(p.scalar, 5, "k kept")
end

-- validate messages
local function rejects(op, params, want)
    local ok, msg = Ops.validate(op, params)
    eq(ok, false, want)
    eq(msg, want, "message")
end
rejects("negate", nil, "Unsupported op: negate")
rejects(nil, nil, "Unsupported op: nil")
rejects("scalar_mul", 3, "Invalid params for scalar_mul")
rejects("edge_add", { edge = "middle" }, "Invalid edge: middle")
rejects("edge_sub", { scalar = -1 }, "Invalid scalar for edge_sub: -1")
eq(Ops.validate("edge_scale", { edge = "bottom", scalar = -1 }), true, "valid edge tile")

-- part: thirds
eq(Ops.part(0, 60), "left", "part 0")
eq(Ops.part(19.9, 60), "left", "part 19.9")
eq(Ops.part(20, 60), "centre", "part 20")
eq(Ops.part(39.9, 60), "centre", "part 39.9")
eq(Ops.part(40, 60), "right", "part 40")
eq(Ops.part(59, 60), "right", "part 59")

-- tile_text and fixed_label
eq(Ops.tile_text("scalar_mul"), "x2", "default scale text")
eq(Ops.tile_text("scalar_mul", { scalar = -1 }), "x-1", "negative scale text")
eq(Ops.tile_text("edge_add", {}), "+1", "default add text")
eq(Ops.tile_text("edge_sub", { scalar = 3 }), "-3", "sub text")
eq(Ops.tile_text("scalar_sub", { scalar = 0 }), "-0", "sub zero text")
eq(Ops.fixed_label("scalar_mul", { scalar = -1 }), "x-1!", "fixed negate")
eq(Ops.fixed_label("edge_scale", { scalar = 3, edge = "right" }), "x3>!", "fixed edge")
eq(Ops.fixed_label("edge_scale"), "x2^!", "fixed edge defaults")
eq(Ops.fixed_label("scalar_mul"), "x2!", "fixed defaults")
eq(Ops.fixed_label("flip_v"), "FLv!", "fixed flip")

-- OpTile.draw ----------------------------------------------------------------
local FONTS = { cell = {}, ui = {} }
local CS = 52

local rects = {}
local orig_rect, orig_color = love.graphics.rectangle, love.graphics.setColor
love.graphics.rectangle = function(mode, x, y, w, h)
    rects[#rects + 1] = table.concat({ mode, x, y, w, h }, ",")
end
local colour
love.graphics.setColor = function(r, g, b, a)
    colour = table.concat({ r, g, b }, ",")
    eq(a, 1, "solid colours only")
end
local colour_of = {}
local orig_printf = love.graphics.printf
love.graphics.printf = function(text, ...)
    colour_of[text] = colour
    orig_printf(text, ...)
end

local function draw(tile, opts)
    rects, colour_of = {}, {}
    Stubs.clear_text()
    OpTile.draw(tile, 100, 200, CS, FONTS, opts)
    local texts = {}
    for _, t in ipairs(Stubs.drawn_text()) do texts[#texts + 1] = t end
    return table.concat(texts, " ")
end

local ON, OFF = { marks = true }, { marks = false, immutable = true }

local whole = { kind = "op", op = "scalar_mul", params = { scalar = -3 } }
eq(draw(whole, ON), "x-3 - +", "whole tile with marks")
eq(colour_of["x-3"], "0.95,0.85,0.5", "editable value colour")
eq(#rects, 2, "whole tile has only background and border")
eq(draw(whole, OFF), "x-3", "whole tile without marks")
eq(colour_of["x-3"], "0.65,0.65,0.4", "immutable value colour")

local BARS = {
    top    = "fill,118,203,16,4",
    right  = "fill,145,218,4,16",
    bottom = "fill,118,245,16,4",
    left   = "fill,103,218,4,16",
}
for _, edge in ipairs(Ops.EDGES) do
    local tile = { kind = "op", op = "edge_add", params = { scalar = 4, edge = edge } }
    local arrow = Ops.ARROWS[edge]
    eq(draw(tile, ON), "+4 - + " .. arrow, edge .. " with marks")
    eq(#rects, 3, edge .. " rect count")
    eq(rects[3], BARS[edge], edge .. " bar")
    eq(draw(tile, OFF), "+4 " .. arrow, edge .. " without marks")
    eq(rects[3], BARS[edge], edge .. " immutable bar")
end

eq(draw({ kind = "op", op = "flip_v" }, ON), "FLv", "no-param op has no marks")
eq(draw({ kind = "op", op = "negate" }, ON), "?", "unknown op")
eq(draw({ kind = "op", op = "negate" }, OFF), "?", "unknown op without marks")
eq(draw({ kind = "op", op = "edge_scale" }, ON), "x2 - + ^", "nil params use defaults")
eq(draw({ kind = "op", op = "edge_scale" }, OFF), "x2 ^", "nil params without marks")
eq(draw({ kind = "op", op = "scalar_sub" }, OFF), "-1", "nil params whole op")
eq(draw({ kind = "op", op = "edge_add", params = { edge = "middle" } }, OFF), "+1 ?", "bad edge")
eq(#rects, 2, "bad edge draws no bar")

love.graphics.rectangle, love.graphics.setColor = orig_rect, orig_color
love.graphics.printf = orig_printf

print("PASS: ops definitions and op tile drawing")
