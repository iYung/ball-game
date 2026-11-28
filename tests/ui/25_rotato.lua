-- Solves "Rotato" with real input: one rotate tile, three pushers that bounce the
-- matrix across it and the locked edge scale, then into the sink.

local S = require("tests/support/shipped")

local steps = S.steps({ { press = "return" }, S.arrows("advanced") })
local function add(step) steps[#steps + 1] = step end

add({ click_button = S.row("rotato") })
add({ assert_text = "Rotato" })

for _, cell in ipairs({ { 1, 2 }, { 4, 1 }, { 4, 5 } }) do
    add({ click_button = { id = "palette:pusher" } })
    add({ click_cell = cell })
end

add({ click_button = { id = "palette:rotate_90" } })
add({ click_cell = { 4, 4 } })

-- { pusher, command, lane, tick }; a command repeats until the next one.
for _, c in ipairs({
    { "A", "right", 1, 1 },
    { "B", "down",  1, 3 }, { "A", "stop", 2, 3 },
    { "B", "up",    1, 4 }, { "C", "up",   2, 4 },
    { "B", "down",  1, 5 }, { "C", "left", 2, 5 },
    { "C", "stop",  1, 6 },
}) do
    add({ click_button = { id = "psel:" .. c[1] } })
    add({ drag = { from = { id = "chip:" .. c[2] }, to = { slot = { c[3], c[4] } } } })
    add({ assert_slot = { lane = c[3], tick = c[4], pusher = c[1]:byte() - 64, cmd = c[2] } })
end

add({ click_button = "Run" })
add({ wait_until = { text = "WIN!", max_frames = 3000 } })

return {
    name  = "solve Rotato",
    given = { solved = "all" },
    steps = steps,
}
