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
    "data/puzzles/11_rotate_gap.lua",
    "data/puzzles/12_negate_swap.lua",
    "data/puzzles/13_flip_scale.lua",
    "data/puzzles/14_elimination.lua",
    "data/puzzles/15_scale_swap.lua",
    "data/puzzles/16_triple.lua",
    "data/puzzles/17_add_rows.lua",
    "data/puzzles/18_col_ops.lua",
    "data/puzzles/19_flips.lua",
    "data/puzzles/20_abs_rotate.lua",
    "data/puzzles/21_fixed_player.lua",
    "data/puzzles/22_fixed_puzzle.lua",
    "data/puzzles/23_locked_scale.lua",
}

local WORLDS = {
    { name = "Basics",   puzzles = { 1,  2,  3,  4,  5 } },
    { name = "Combos",   puzzles = { 6,  7,  8,  9, 10, 11 } },
    { name = "Advanced", puzzles = { 12, 13, 14, 15, 16 } },
}

local WORLDS = {
    { name = "Basics",   puzzles = { 1,  2,  3,  4,  5 } },
    { name = "Combos",   puzzles = { 6,  7,  8,  9, 10, 11 } },
    { name = "Advanced", puzzles = { 12, 13, 14, 15, 16 } },
}

local PuzzleLoader = {}

function PuzzleLoader.world_count()
    return #WORLDS
end

function PuzzleLoader.world(w)
    if type(w) ~= "number" or w < 1 or w > #WORLDS then
        error(string.format("PuzzleLoader.world: index %s out of range (1–%d)", tostring(w), #WORLDS))
    end
    local def = WORLDS[w]
    local result = { name = def.name, puzzles = {} }
    for _, idx in ipairs(def.puzzles) do
        result.puzzles[#result.puzzles + 1] = {
            index = idx,
            name  = PuzzleLoader.load(idx).name or ("Puzzle " .. idx),
        }
    end
    return result
end

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
