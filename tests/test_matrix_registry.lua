-- MatrixScene UI element registry, single command-enabled function, registry hit-testing.
-- Uses puzzle 2 (small palette).
local runner = require("lua/headless/runner")
local UI     = require("lua/core/ui")
local UIRunner = require("lua/headless/ui_runner")

local function new_scene(n)
    local ctx = runner.setup(function(_, sm)
        return require("lua/game/scenes/matrix_scene").new(n or 2, sm)
    end)
    local scene = ctx.sm.current
    scene:draw()  -- sets _tl_top so timeline elements exist
    return scene, ctx
end

local function ids(elements)
    local out = {}
    for i, e in ipairs(elements) do out[i] = e.id end
    return out
end

local function click(scene, id, btn)
    local e = UI.find(scene:ui_elements(), id)
    assert(e, "element " .. id .. " present")
    local x, y = UI.centre(e.rect)
    scene:mouse_pressed(x, y, btn or 1)
end

-- Ids are unique, order is stable, and the expected sections are present in C2 order.
do
    local scene = new_scene()
    local a, b = ids(scene:ui_elements()), ids(scene:ui_elements())
    assert(#a == #b, "same length across calls")
    local seen = {}
    for i = 1, #a do
        assert(a[i] == b[i], "order stable at " .. i)
        assert(not seen[a[i]], "duplicate id " .. a[i])
        seen[a[i]] = true
    end
    assert(a[1] == "palette:pusher", "palette first, got " .. tostring(a[1]))
    assert(seen["palette:transpose"] and seen["palette:drag"] and seen["palette:erase"], "palette ids")
    assert(not seen["palette:negate"], "puzzle 2 only offers transpose")
    for _, c in ipairs({ "cmd:run", "cmd:reset", "cmd:menu" }) do
        assert(seen[c], c .. " present")
    end
    assert(seen["cell:1,1"] and seen["cell:10,10"], "cells present")
    assert(seen["tl:scroll_left"] and seen["tl:scroll_right"], "timeline scroll controls")
    assert(seen["chip:right"] and seen["chip:stop"] and seen["slot:1:1"] and seen["slot:4:1"], "chips and slots")
    -- Order: palette, cmd, cells, tl
    local pos = {}
    for i, id in ipairs(a) do pos[id] = i end
    assert(pos["palette:erase"] < pos["cmd:run"], "palette before commands")
    assert(pos["cmd:menu"] < pos["cell:1,1"], "commands before cells")
    assert(pos["cell:2,1"] < pos["cell:1,2"], "cells are y-major")
    assert(pos["cell:10,10"] < pos["tl:scroll_left"], "cells before timeline")
    assert(pos["tl:scroll_left"] < pos["tl:scroll_right"] and pos["tl:scroll_right"] < pos["slot:1:1"], "timeline order")
    assert(UIRunner.check_invariants(scene:ui_elements()) == nil,
        "puzzle 2 invariants: " .. tostring(UIRunner.check_invariants(scene:ui_elements())))
    -- _btn_rects is a dense array with ids and btn.label
    for i, r in ipairs(scene._btn_rects) do
        assert(r.id and r.btn and r.btn.label, "btn rect " .. i .. " well-formed")
    end
    print("PASS: registry ids unique and ordered")
end

-- Clicking palette:pusher at its centre selects the pusher.
do
    local scene = new_scene()
    local erase = UI.find(scene:ui_elements(), "palette:erase")
    assert(erase.selected == true, "erase selected initially")
    click(scene, "palette:pusher")
    local sel = scene.palette:selected()
    assert(sel and sel.kind == "pusher", "pusher selected")
    assert(UI.find(scene:ui_elements(), "palette:pusher").selected == true, "pusher reports selected")
    assert(UI.find(scene:ui_elements(), "palette:erase").selected == false, "erase no longer selected")
    print("PASS: palette click selects")
end

-- Clicking cmd:run with status "win" does nothing.
do
    local scene = new_scene()
    scene:_place_tile_at(1, 5, { kind = "pusher" })
    scene.status = "win"
    assert(UI.find(scene:ui_elements(), "cmd:run").enabled == false, "run disabled on win")
    click(scene, "cmd:run")
    assert(scene.status == "win" and scene.sim == nil and not scene.running, "run click ignored on win")
    print("PASS: cmd:run disabled after win")
end

-- key r with status "win" does nothing (follows the Run button state).
do
    local scene = new_scene()
    scene:_place_tile_at(1, 5, { kind = "pusher" })
    scene.status = "win"
    scene:key_pressed("r")
    assert(scene.status == "win" and scene.sim == nil and not scene.running, "r ignored on win")
    print("PASS: r follows Run enabled state")
end

-- backspace with nothing to reset changes nothing.
do
    local scene = new_scene()
    scene:_place_tile_at(3, 3, { kind = "op", op = "transpose" })
    scene.palette:select({ kind = "drag" })
    scene:mouse_pressed(130 + 2 * 52 + 10, 10 + 2 * 52 + 10, 1)
    local held = scene._drag_tile
    assert(held ~= nil, "tile held")
    assert(scene.sim == nil and scene.status == nil, "nothing to reset")
    assert(scene:_cmd_enabled("reset") == false, "reset disabled")
    scene:key_pressed("backspace")
    assert(scene._drag_tile == held, "backspace did not run do_reset")
    print("PASS: backspace follows Reset enabled state")
end

-- cmd:reset enabled mirrors _cmd_enabled("reset").
do
    local scene = new_scene()
    local function check()
        local e = UI.find(scene:ui_elements(), "cmd:reset")
        assert(e.enabled == scene:_cmd_enabled("reset"), "reset enabled mirrors _cmd_enabled")
    end
    check()
    scene.status = "fail"
    check()
    assert(UI.find(scene:ui_elements(), "cmd:reset").enabled == true, "reset enabled after fail")
    click(scene, "cmd:reset")
    assert(scene.status == nil, "reset click resets")
    check()
    print("PASS: cmd:reset enabled matches")
end

-- Pusher selector buttons appear once a pusher is placed; chips write slots through the registry.
-- Rewritten: the old test cycled slot:A:1 by clicking and used tl:inc/tl:dec for the length;
-- slots are now slot:<lane>:<tick>, written by an armed chip, and the length is fixed.
do
    local Timeline = require("lua/game/timeline")
    local scene = new_scene()
    assert(UI.find(scene:ui_elements(), "psel:A") == nil, "no selector without a pusher")
    local s1 = UI.find(scene:ui_elements(), "slot:1:1")
    assert(s1 and s1.kind == "slot" and s1.enabled, "slot:1:1 present and enabled")
    scene:_place_tile_at(1, 5, { kind = "pusher" })
    assert(UI.find(scene:ui_elements(), "psel:A").selected, "first pusher auto-selected")
    click(scene, "chip:up")
    assert(UI.find(scene:ui_elements(), "chip:up").selected, "chip armed")
    click(scene, "slot:1:1")
    local c = Timeline.get(scene.timeline, 1, 1)
    assert(c and c.cmd == "up" and c.pusher == 1, "slot written")
    click(scene, "slot:1:1", 2)
    assert(Timeline.get(scene.timeline, 1, 1) == nil, "right-click clears")
    scene.running = true
    assert(UI.find(scene:ui_elements(), "slot:1:1").enabled == false, "slot disabled while running")
    assert(UI.find(scene:ui_elements(), "chip:up").enabled == false, "chip disabled while running")
    assert(UI.find(scene:ui_elements(), "psel:A").enabled == false, "selector disabled while running")
    click(scene, "slot:1:1")
    assert(Timeline.get(scene.timeline, 1, 1) == nil, "slot click ignored while running")
    print("PASS: timeline slots via registry")
end

-- ui_tile / ui_matrix shapes.
do
    local scene = new_scene()
    local m = scene:ui_matrix()
    assert(#m == 2 and #m[1] == 2 and m[1][1] == 1 and m[1][2] == 2 and m[2][1] == 3 and m[2][2] == 4,
        "ui_matrix returns input values")
    assert(getmetatable(m) == nil, "plain rows")
    assert(scene:ui_tile(5, 1) == nil, "empty cell is nil")
    local src = scene:ui_tile(3, 6)  -- ref cell of the 2x2 source at (2,5)
    assert(src and src.kind == "source", "ref cell resolves to source anchor")
    scene:_place_tile_at(1, 5, { kind = "pusher" })
    local t = scene:ui_tile(1, 5)
    assert(t.kind == "pusher" and t.op == nil, "pusher tile shape")
    scene:_place_tile_at(5, 2, { kind = "op", op = "transpose" })
    assert(scene:ui_tile(5, 2).op == "transpose", "op tile shape")
    print("PASS: ui_tile / ui_matrix")
end

-- tl:scroll_left sits left of the first slot and tl:scroll_right right of the last visible one.
do
    local scene = new_scene()
    local els = scene:ui_elements()
    local sl, sr = UI.find(els, "tl:scroll_left"), UI.find(els, "tl:scroll_right")
    local first = UI.find(els, "slot:1:1")
    assert(sl.rect.x + sl.rect.w <= first.rect.x, "scroll_left clear of the first slot")
    local last
    for _, e in ipairs(els) do if e.kind == "slot" and e.id:match("^slot:1:") then last = e end end
    assert(last.rect.x + last.rect.w <= sr.rect.x, "scroll_right clear of the last visible slot")
    print("PASS: timeline scroll arrows do not overlap slots")
end

-- MatrixScene:text_input(_) is a no-op and must not raise.
do
    local scene = new_scene()
    local ok, err = pcall(function() scene:text_input("a") end)
    assert(ok, "text_input must not error: " .. tostring(err))
    print("PASS: MatrixScene text_input is a no-op")
end

-- HUD:draw_matrix with a float value hits the fmt_num "%.2f" branch (hud.lua:20).
do
    local HUD    = require("lua/game/hud")
    local Matrix = require("lua/game/matrix_math")

    local hud = HUD.new(820, 0, 460, 720)
    -- Non-integer value ensures fmt_num takes the string.format("%.2f", v) branch.
    local mat = Matrix.new(1, 1, { {1.5} })
    local ok, err = pcall(function()
        hud:draw_matrix(mat, 820 + 230, 10, hud.font_num)
    end)
    assert(ok, "HUD draw_matrix with float must not error: " .. tostring(err))
    print("PASS: HUD fmt_num float branch (hud.lua:20)")
end

print("ALL REGISTRY TESTS PASSED")
