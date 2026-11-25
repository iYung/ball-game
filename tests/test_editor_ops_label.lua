-- The "OPS:" label sits above the op allowlist buttons, even with the tallest matrices.
require("lua/headless/stubs")
local EditorScene = require("lua/game/scenes/editor_scene")

local LABEL_H = 14   -- one line of the 11pt UI font

local scene = EditorScene.new({})
for _, size in ipairs({ 1, 4 }) do
    scene._input.rows, scene._target.rows = size, size
    scene:_adjust_matrix(scene._input, size, 2)
    scene:_adjust_matrix(scene._target, size, 2)
    scene:_rebuild_hud()
    scene:_layout_palette()
    local label_bottom = scene._hud_ops_lbl_y - 2 + LABEL_H
    local count = 0
    for _, e in ipairs(scene:ui_elements()) do
        if e.id:find("^editor:allow:") then
            count = count + 1
            assert(e.rect.y >= label_bottom, e.id .. " overlaps the OPS label")
            assert(e.rect.y + e.rect.h <= 656, e.id .. " runs into the palette bar")
        end
    end
    assert(count == 10, "all 10 allowlist buttons shown, got " .. count)
end
print("PASS: OPS label clear of allowlist buttons")
