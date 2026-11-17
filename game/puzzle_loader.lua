local PUZZLES = {
    "data/puzzles/01_identity.lua",
    "data/puzzles/02_flip.lua",
    "data/puzzles/03_negate.lua",
    "data/puzzles/04_swap.lua",
    "data/puzzles/05_scale.lua",
    "data/puzzles/06_row_swap.lua",
    "data/puzzles/07_double_flip.lua",
    "data/puzzles/08_combo.lua",
    "data/puzzles/09_uturn.lua",
    "data/puzzles/10_set_row.lua",
}

local PuzzleLoader = {}

function PuzzleLoader.load(n)
    if type(n) ~= "number" or n < 1 or n > #PUZZLES then
        error(string.format("PuzzleLoader.load: index %s out of range (1–%d)", tostring(n), #PUZZLES))
    end
    local path = PUZZLES[n]
    local chunk, err = love.filesystem.load(path)
    if not chunk then
        error(string.format("PuzzleLoader.load: could not load '%s': %s", path, tostring(err)))
    end
    return chunk()
end

function PuzzleLoader.count()
    return #PUZZLES
end

return PuzzleLoader
