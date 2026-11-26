-- Every Two Sources puzzle, opened through level select and won with its reference
-- solution (documented at the top of each puzzle file) by real input.

local S = require("tests/support/shipped")

-- sol.tiles: { op, x, y, turns (clicks on the selected button), facing }.
-- sol.pushers: cells, placed in letter order.
-- sol.commands: { tick, { pusher letter, command }, ... }, one lane each.
local function solve(id, name, sol, extra)
    local steps = S.steps({ { press = "return" }, S.arrows("two_sources") })
    local function add(step) steps[#steps + 1] = step end

    add({ click_button = S.row(id) })
    add({ assert_text = name })
    add({ assert_text = "INPUT 2" })
    for _, t in ipairs(sol.tiles or {}) do
        local button = { id = "palette:" .. t.op }
        add({ click_button = button })
        for _ = 1, t.turns or 0 do add({ click_button = button }) end
        add({ click_cell = { t.x, t.y } })
        add({ assert_tile = { x = t.x, y = t.y, kind = "op", op = t.op, facing = t.facing } })
    end
    add({ click_button = { id = "palette:pusher" } })
    for _, cell in ipairs(sol.pushers) do
        add({ click_cell = cell })
        add({ assert_tile = { x = cell[1], y = cell[2], kind = "pusher" } })
    end
    for _, column in ipairs(sol.commands) do
        local tick = column[1]
        for lane = 1, #column - 1 do
            local who, cmd = column[lane + 1][1], column[lane + 1][2]
            add({ click_button = { id = "psel:" .. who } })
            add({ drag = { from = { id = "chip:" .. cmd }, to = { slot = { lane, tick } } } })
            add({ assert_slot = { lane = lane, tick = tick,
                                  pusher = who:byte() - 64, cmd = cmd } })
        end
    end
    add({ click_button = "Run" })
    add({ wait_until = { text = "WIN!", max_frames = 3000 } })
    for _, step in ipairs(extra or {}) do add(step) end

    return {
        name  = "solve " .. name,
        given = { solved = S.before("two_sources") },
        steps = steps,
    }
end

return {
    solve("first_sum", "First Sum", {
        pushers  = { { 1, 4 }, { 9, 4 }, { 4, 3 } },
        commands = {
            { 1, { "A", "right" }, { "B", "left" } },
            { 2, { "B", "stop" } },
            { 3, { "A", "stop" }, { "C", "down" } },
        },
    }, {
        { click_button = "Continue" },
        { assert_text = "SOLVED!" },
    }),

    solve("turned_sum", "Turned Sum", {
        tiles    = { { op = "matrix_add", x = 4, y = 4, turns = 1, facing = "bottom" } },
        pushers  = { { 4, 1 }, { 4, 9 }, { 3, 5 } },
        commands = {
            { 1, { "A", "down" }, { "B", "up" } },
            { 2, { "A", "stop" } },
            { 3, { "B", "stop" }, { "A", "down" } },
            { 5, { "A", "stop" }, { "C", "right" } },
        },
    }),

    solve("operand_order", "Operand Order", {
        tiles    = { { op = "matrix_mul", x = 6, y = 3, turns = 2, facing = "left" } },
        pushers  = { { 1, 3 }, { 10, 3 }, { 6, 2 } },
        commands = {
            { 1, { "A", "right" }, { "B", "left" } },
            { 2, { "B", "stop" } },
            { 3, { "A", "stop" }, { "C", "down" } },
        },
    }),

    solve("merge_maze", "Merge Maze", {
        tiles    = {
            { op = "transpose", x = 8, y = 2 },
            { op = "matrix_mul", x = 5, y = 7, facing = "right" },
        },
        pushers  = { { 4, 2 }, { 6, 1 }, { 1, 7 }, { 3, 6 }, { 1, 8 } },
        commands = {
            { 1, { "A", "right" }, { "C", "right" } },
            { 2, { "A", "stop" }, { "C", "stop" }, { "B", "down" } },
            { 5, { "B", "stop" }, { "D", "down" } },
            { 6, { "D", "stop" }, { "E", "right" } },
        },
    }),
}
