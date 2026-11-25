-- Sweep: open every puzzle through level select so the runner's global
-- layout invariants run on each puzzle's screen. Also checks reachability:
-- every puzzle index must belong to some world.

local S = require("tests/support/shipped")
local PuzzleLoader = require("lua/game/puzzle_loader")

local worlds  = {}
local reached = {}
for w = 1, PuzzleLoader.world_count() do
    worlds[w] = PuzzleLoader.world(w)
    for _, p in ipairs(worlds[w].puzzles) do reached[p.index] = true end
end
for i = 1, PuzzleLoader.count() do
    if not reached[i] then error("unreachable puzzle " .. i) end
end

local steps = { { press = "return" } }
local function add(step) steps[#steps + 1] = step end

for w, world in ipairs(worlds) do
    for n, p in ipairs(world.puzzles) do
        -- Esc from a puzzle returns to level select on world 1.
        for _ = 1, w - 1 do add({ press = "right" }) end
        if n == 1 then
            add({ assert_button = { id = string.format("world:%d", w), selected = true } })
        end
        add({ assert_button = { id = "puzzle:" .. p.index } })
        add({ click_button = { id = "puzzle:" .. p.index } })
        add({ wait = 5 })
        add({ assert_text = p.name })
        if p.index == S.puzzle("identity") then
            -- identity has the most ops; the full palette fits without scroll arrows
            add({ assert_button = { id = "palette:scroll_down", visible = false } })
        end
        add({ press = "escape" })
        -- ESC now opens the settings overlay; "Exit to Menu" returns to level select
        add({ click_button = { id = "settings:exit" } })
    end
end

return {
    name  = "every puzzle opens from level select with a valid layout",
    given = { solved = "all" },
    steps = steps,
}
