local PuzzleLoader = require("lua/game/puzzle_loader")

local SAVE_FILE = "progress.lua"

local _solved         = {}  -- set: _solved[n] = true if puzzle n is solved
local _seen_cutscene  = {}  -- set: _seen_cutscene[w] = true if world w cutscene has been seen

local function _persist()
    if not love.filesystem or not love.filesystem.write then return end
    local solved_indices = {}
    for n, v in pairs(_solved) do
        if v then solved_indices[#solved_indices + 1] = n end
    end
    table.sort(solved_indices)

    local cutscene_indices = {}
    for w, v in pairs(_seen_cutscene) do
        if v then cutscene_indices[#cutscene_indices + 1] = w end
    end
    table.sort(cutscene_indices)

    local solved_parts   = {}
    for _, n in ipairs(solved_indices)   do solved_parts[#solved_parts + 1]     = tostring(n) end
    local cutscene_parts = {}
    for _, w in ipairs(cutscene_indices) do cutscene_parts[#cutscene_parts + 1] = tostring(w) end

    local data = string.format(
        "return {solved={%s},cutscenes={%s}}\n",
        table.concat(solved_parts, ","),
        table.concat(cutscene_parts, ",")
    )
    local ok, err = pcall(love.filesystem.write, SAVE_FILE, data)
    if not ok then
        -- silently ignore write failures (e.g. headless)
        _ = err
    end
end

local function _load()
    if not love.filesystem or not love.filesystem.read then return end
    if love.filesystem.getInfo and not love.filesystem.getInfo(SAVE_FILE) then return end
    local ok, data = pcall(love.filesystem.read, SAVE_FILE)
    if not ok or type(data) ~= "string" then return end
    local chunk, err = (loadstring or load)(data)
    if not chunk then return end
    local ok2, tbl = pcall(chunk)
    if not ok2 or type(tbl) ~= "table" then return end
    -- New format: {solved={...}, cutscenes={...}}
    -- Old format: plain array {1,2,3,...} — treat as solved list
    if tbl.solved then
        for _, n in ipairs(tbl.solved) do
            if type(n) == "number" then _solved[n] = true end
        end
        for _, w in ipairs(tbl.cutscenes or {}) do
            if type(w) == "number" then _seen_cutscene[w] = true end
        end
    else
        for _, n in ipairs(tbl) do
            if type(n) == "number" then _solved[n] = true end
        end
    end
end

_load()

local Progress = {}

function Progress.mark_solved(n)
    if _solved[n] then return end
    _solved[n] = true
    _persist()
end

function Progress.is_solved(n)
    return _solved[n] == true
end

function Progress.is_world_unlocked(w)
    if w == 1 then return true end
    for prev = 1, w - 1 do
        local world = PuzzleLoader.world(prev)
        for _, puzzle in ipairs(world.puzzles) do
            if not _solved[puzzle.index] then
                return false
            end
        end
    end
    return true
end

function Progress.unlock_world(w)
    local world = PuzzleLoader.world(w)
    for _, puzzle in ipairs(world.puzzles) do
        _solved[puzzle.index] = true
    end
    -- Clear the first-visit cutscene for the world that just became accessible,
    -- so a tester pressing U can still see the full first-visit flow.
    _seen_cutscene[w + 1] = nil
    _persist()
end

function Progress.unlock_all()
    for n = 1, PuzzleLoader.count() do
        _solved[n] = true
    end
    _persist()
end

function Progress.is_cutscene_seen(w)
    return _seen_cutscene[w] == true
end

function Progress.mark_cutscene_seen(w)
    if _seen_cutscene[w] then return end
    _seen_cutscene[w] = true
    _persist()
end

function Progress.reset()
    _solved = {}
    _seen_cutscene = {}
    _persist()
end

return Progress
