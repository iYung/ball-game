-- Finds shipped puzzles and worlds by id, so tests keep working when a level or
-- a world is inserted anywhere. Not a test: the runner only executes the .lua
-- files directly in tests/ and tests/ui/.
local PuzzleLoader = require("lua/game/puzzle_loader")

local S = {}

-- Position of a puzzle id.
function S.puzzle(id)
    for n = 1, PuzzleLoader.count() do
        if PuzzleLoader.id(n) == id then return n end
    end
    error("no puzzle with id " .. tostring(id))
end

-- World number of a world id.
function S.world(id)
    for w = 1, PuzzleLoader.world_count() do
        if PuzzleLoader.world_id(w) == id then return w end
    end
    error("no world with id " .. tostring(id))
end

-- Name of the puzzle `offset` places after the puzzle `id`.
function S.name_after(id, offset)
    return PuzzleLoader.load(S.puzzle(id) + offset).name
end

-- Level select element selectors.
function S.row(id) return { id = "puzzle:" .. S.puzzle(id) } end
function S.tab(id) return { id = "world:" .. S.world(id) } end

-- Positions of every puzzle in the worlds before `world` (an id or a number):
-- solving them unlocks it.
function S.before(world)
    local w = type(world) == "string" and S.world(world) or world
    local out = {}
    for earlier = 1, w - 1 do
        for _, n in ipairs(PuzzleLoader.world_indices(earlier)) do out[#out + 1] = n end
    end
    return out
end

-- The Right presses that take level select from the first world to `world`
-- (an id or a number). Every world on the way must be unlocked.
function S.arrows(world)
    local w = type(world) == "string" and S.world(world) or world
    local steps = {}
    for _ = 2, w do steps[#steps + 1] = { press = "right" } end
    return steps
end

-- Flattens UI spec steps: an entry that is itself a list of steps (such as the
-- result of S.arrows, possibly empty) is spliced in.
function S.steps(entries)
    local out = {}
    for _, entry in ipairs(entries) do
        if entry[1] ~= nil or next(entry) == nil then
            for _, step in ipairs(entry) do out[#out + 1] = step end
        else
            out[#out + 1] = entry
        end
    end
    return out
end

return S
