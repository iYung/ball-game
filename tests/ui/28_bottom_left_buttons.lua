-- Bottom-left buttons: every instruction chip is armed by a click and used on a
-- slot, and every pusher selector (A..H) picks the pusher that gets the command.

local S = require("tests/support/shipped")

local function open_identity(rest)
    local steps = {
        { press = "return" },
        S.arrows("basics"),
        { click_button = S.row("identity") },
        { assert_text  = "Identity Check" },
        { click_button = "P" },
    }
    for _, step in ipairs(rest) do steps[#steps + 1] = step end
    return S.steps(steps)
end

-- Spec 1: arm each chip by clicking it, then fill a different tick with it.
local chip_steps = {
    { click_cell  = { 3, 3 } },
    { assert_tile = { 3, 3, kind = "pusher" } },
}
for tick, cmd in ipairs({ "up", "down", "left", "right", "stop" }) do
    local chip = { id = "chip:" .. cmd }
    chip_steps[#chip_steps + 1] = { click_button  = chip }
    chip_steps[#chip_steps + 1] = { assert_button = { id = chip.id, selected = true } }
    chip_steps[#chip_steps + 1] = { click_button  = { id = "slot:1:" .. tick } }
    chip_steps[#chip_steps + 1] = { assert_slot   = { lane = 1, tick = tick, pusher = 1, cmd = cmd } }
end
chip_steps[#chip_steps + 1] = { click_button  = { id = "chip:clear" } }
chip_steps[#chip_steps + 1] = { assert_button = { id = "chip:clear", selected = true } }
chip_steps[#chip_steps + 1] = { click_button  = { id = "slot:1:3" } }
chip_steps[#chip_steps + 1] = { assert_slot   = { lane = 1, tick = 3, empty = true } }

-- Spec 2: eight pushers, then give pusher n a command at tick n through its selector.
local psel_steps = {}
for n = 1, 8 do
    psel_steps[#psel_steps + 1] = { click_cell  = { n + 1, 2 } }
    psel_steps[#psel_steps + 1] = { assert_tile = { n + 1, 2, kind = "pusher" } }
end
for n, letter in ipairs({ "A", "B", "C", "D", "E", "F", "G", "H" }) do
    local psel = { id = "psel:" .. letter }
    psel_steps[#psel_steps + 1] = { click_button  = psel }
    psel_steps[#psel_steps + 1] = { assert_button = { id = psel.id, selected = true } }
    psel_steps[#psel_steps + 1] = { click_button  = { id = "chip:right" } }
    psel_steps[#psel_steps + 1] = { click_button  = { id = "slot:1:" .. n } }
    psel_steps[#psel_steps + 1] = { assert_slot   = { lane = 1, tick = n, pusher = n, cmd = "right" } }
end

return {
    {
        name  = "every instruction chip arms by click and edits a slot",
        given = { solved = S.before("basics") },
        steps = open_identity(chip_steps),
    },
    {
        name  = "every pusher selector A to H picks the pusher for a command",
        given = { solved = S.before("basics") },
        steps = open_identity(psel_steps),
    },
}
