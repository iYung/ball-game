-- The Two Sources puzzles that need an op on a matrix before the merge, opened through
-- level select and won with their reference solutions by real input.
-- Merge Maze, which also does, is solved in 23_two_source_world.lua.

local S = require("tests/support/shipped")

-- sol.tiles: { op, x, y, turns (clicks on the selected button), facing,
-- k (target value, reached by clicking the placed tile's left third from 2) }.
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
        for _ = 1, t.k and (2 - t.k) or 0 do
            add({ click_cell = { t.x, t.y, part = "left" } })
        end
        add({ assert_tile = { x = t.x, y = t.y, kind = "op", op = t.op, facing = t.facing,
                              scalar = t.k } })
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
    solve("take_away", "Take Away", {
        tiles    = { { op = "scalar_mul", x = 7, y = 4, k = -1 } },
        pushers  = { { 1, 4 }, { 10, 4 }, { 4, 3 } },
        commands = {
            { 1, { "A", "right" }, { "B", "left" } },
            { 3, { "A", "stop" }, { "B", "stop" }, { "C", "down" } },
        },
    }),

    solve("two_preps", "Two Preps", {
        tiles    = {
            { op = "scalar_mul", x = 4, y = 4, k = 2 },
            { op = "flip_h", x = 6, y = 6 },
            { op = "matrix_add", x = 4, y = 5, turns = 1, facing = "bottom" },
        },
        pushers  = { { 4, 1 }, { 9, 6 }, { 3, 4 } },
        commands = {
            { 1, { "A", "down" }, { "B", "left" } },
            { 3, { "A", "stop" } },
            { 4, { "B", "stop" }, { "C", "right" } },
        },
    }),
}
