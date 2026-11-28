-- Layout of the bottom-left buttons: the 3x2 chip grid, the pusher selectors above it
-- and the "INSTRUCTIONS" label.

local S = require("tests/support/shipped")
local runner   = require("lua/headless/runner")
local Stubs    = require("lua/headless/stubs")
local UI       = require("lua/core/ui")
local UIRunner = require("lua/headless/ui_runner")

local ctx = runner.setup(function(_, sm)
    return require("lua/game/scenes/matrix_scene").new(S.puzzle("identity"), sm)
end)
local scene = ctx.sm.current
scene:draw()

-- Eight pushers on free cells, so every selector A..H is shown.
for n = 1, 8 do
    local x, y = n + 1, 2
    assert(scene.grid:get(x, y) == nil, "cell " .. x .. "," .. y .. " is free")
    scene:_place_tile_at(x, y, { kind = "pusher" })
    local tile = scene.grid:get(x, y)
    assert(tile and tile.kind == "pusher", "pusher " .. n .. " placed")
end

local els = scene:ui_elements()

local function rect(id)
    local e = UI.find(els, id)
    assert(e, "element " .. id .. " present")
    return e.rect
end

local function assert_rect(id, x, y, w, h)
    local r = rect(id)
    assert(r.x == x and r.y == y and r.w == w and r.h == h,
        string.format("%s rect is (%s,%s,%s,%s), expected (%d,%d,%d,%d)",
            id, tostring(r.x), tostring(r.y), tostring(r.w), tostring(r.h), x, y, w, h))
end

local CHIPS = {
    { "stop", 10, 624 }, { "up",   88, 624 }, { "clear", 166, 624 },
    { "left", 10, 670 }, { "down", 88, 670 }, { "right", 166, 670 },
}
local LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H" }

-- Exact rects of the chips and the selectors.
for _, c in ipairs(CHIPS) do
    assert_rect("chip:" .. c[1], c[2], c[3], 72, 40)
end
for i, letter in ipairs(LETTERS) do
    assert_rect("psel:" .. letter, 10 + (i - 1) * 30, 574, 28, 28)
end

-- The chip rows line up with the command button rows, 10px from the bottom edge.
do
    local run, menu = rect("cmd:run"), rect("cmd:menu")
    assert(menu.y > run.y, "cmd:menu is on the second command row")
    for _, c in ipairs(CHIPS) do
        local r = rect("chip:" .. c[1])
        local row = c[3] == 624 and run or menu
        assert(r.y == row.y and r.h == row.h, "chip:" .. c[1] .. " lines up with its command row")
    end
    for _, cmd in ipairs({ "left", "down", "right" }) do
        local r = rect("chip:" .. cmd)
        assert(720 - (r.y + r.h) == 10, "chip:" .. cmd .. " bottom margin is 10")
    end
    assert(720 - (menu.y + menu.h) == 10, "command bottom margin is 10")
end

-- Everything stays left of the timeline, and the registry stays well formed.
do
    local tl_x = rect("tl:scroll_left").x
    assert(tl_x == 260, "timeline starts at x=260")
    for _, c in ipairs(CHIPS) do
        local r = rect("chip:" .. c[1])
        assert(r.x + r.w <= tl_x, "chip:" .. c[1] .. " left of the timeline")
    end
    for _, letter in ipairs(LETTERS) do
        local r = rect("psel:" .. letter)
        assert(r.x + r.w <= tl_x, "psel:" .. letter .. " left of the timeline")
    end
    local err = UIRunner.check_invariants(els)
    assert(err == nil, tostring(err))
end

-- The label sits between the selectors and the grid. Stubs.drawn_text() keeps only
-- strings, so capture the position by wrapping love.graphics.print for one draw.
do
    local original = love.graphics.print
    local seen = {}
    love.graphics.print = function(text, x, y, ...)
        if text == "INSTRUCTIONS" then seen[#seen + 1] = { x = x, y = y } end
        return original(text, x, y, ...)
    end
    Stubs.clear_text()
    local ok, err = pcall(scene.draw, scene)
    love.graphics.print = original
    assert(ok, tostring(err))
    assert(#seen == 1, "INSTRUCTIONS drawn once, got " .. #seen)
    assert(seen[1].x == 10 and seen[1].y == 606,
        "INSTRUCTIONS drawn at " .. tostring(seen[1].x) .. "," .. tostring(seen[1].y))
end

print("test_chip_layout passed")
