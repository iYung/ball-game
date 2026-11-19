local PuzzleLoader = require("game/puzzle_loader")

local SAVE_FILE = "progress.lua"

local _solved = {}  -- set: _solved[n] = true if puzzle n is solved

local function _persist()
    if not love.filesystem or not love.filesystem.write then return end
    local indices = {}
    for n, v in pairs(_solved) do
        if v then indices[#indices + 1] = n end
    end
    table.sort(indices)
    local parts = {}
    for _, n in ipairs(indices) do parts[#parts + 1] = tostring(n) end
    local ok, err = pcall(love.filesystem.write, SAVE_FILE, "return {" .. table.concat(parts, ",") .. "}\n")
    if not ok then
        -- silently ignore write failures (e.g. headless)
        _ = err
    end
end

local function _load()
    if not love.filesystem or not love.filesystem.read then return end
    local ok, data = pcall(love.filesystem.read, SAVE_FILE)
    if not ok or not data then return end
    local chunk, err = load(data)
    if not chunk then return end
    local ok2, tbl = pcall(chunk)
    if not ok2 or type(tbl) ~= "table" then return end
    for _, n in ipairs(tbl) do
        if type(n) == "number" then
            _solved[n] = true
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

function Progress.unlock_all()
    for n = 1, PuzzleLoader.count() do
        _solved[n] = true
    end
    _persist()
end

function Progress.reset()
    _solved = {}
    _persist()
end

return Progress
