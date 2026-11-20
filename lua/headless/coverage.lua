-- lua/headless/coverage.lua
-- Line-level coverage via debug.sethook.
-- Tracks lua/game/ only; ignores lua/core/ (rendering infrastructure) and test files.

local M = {}

local _hits = {}  -- { [filepath] = { [line] = true } }

local function hook(_, line)
    local info = debug.getinfo(2, "S")
    if not info or info.source:sub(1, 1) ~= "@" then return end
    local path = info.source:sub(2)
    if not path:match("^lua/game/") then return end
    if not _hits[path] then _hits[path] = {} end
    _hits[path][line] = true
end

function M.start()
    _hits = {}
    debug.sethook(hook, "l")
end

-- Returns true if a source line counts as executable (non-blank, non-comment,
-- not a bare structural keyword).
local _skip = {
    ["end"]    = true, ["end,"] = true,
    ["}"]      = true, ["},"]   = true,
    ["then"]   = true, ["do"]   = true,
    ["else"]   = true,
}
local function is_executable(raw)
    local t = raw:match("^%s*(.-)%s*$")
    if t == "" then return false end
    if t:sub(1, 2) == "--" then return false end
    if _skip[t] then return false end
    return true
end

-- Scan a directory recursively for *.lua files using the native OS find.
local function find_lua_files(dir)
    local files = {}
    local handle = io.popen('find ' .. dir .. ' -name "*.lua" | sort')
    if handle then
        for line in handle:lines() do
            files[#files + 1] = line
        end
        handle:close()
    end
    return files
end

-- Count executable lines in a file.
local function count_executable(path)
    local f = io.open(path, "r")
    if not f then return 0 end
    local n = 0
    for line in f:lines() do
        if is_executable(line) then n = n + 1 end
    end
    f:close()
    return n
end

function M.report()
    debug.sethook()

    -- Gather all source files, including those never loaded.
    local all_files = {}
    for _, dir in ipairs({ "lua/game" }) do
        for _, f in ipairs(find_lua_files(dir)) do
            all_files[#all_files + 1] = f
        end
    end

    local rows = {}
    local grand_hit, grand_exec = 0, 0

    for _, path in ipairs(all_files) do
        local exec_lines = count_executable(path)
        local hit_lines  = 0
        if _hits[path] then
            for _ in pairs(_hits[path]) do hit_lines = hit_lines + 1 end
        end
        rows[#rows + 1] = { path = path, hit = hit_lines, exec = exec_lines }
        grand_hit  = grand_hit  + hit_lines
        grand_exec = grand_exec + exec_lines
    end

    -- Print report.
    local BAR = string.rep("-", 72)
    print("\n" .. BAR)
    print(string.format("%-55s  %5s  %5s  %5s", "File", "Hit", "Exec", "Cov%"))
    print(BAR)

    for _, r in ipairs(rows) do
        local pct = r.exec > 0 and math.floor(r.hit / r.exec * 100) or 0
        local flag = pct == 100 and "" or (pct < 50 and " !" or "")
        print(string.format("%-55s  %5d  %5d  %4d%%%s",
            r.path, r.hit, r.exec, pct, flag))
    end

    print(BAR)
    local overall = grand_exec > 0 and math.floor(grand_hit / grand_exec * 100) or 0
    print(string.format("%-55s  %5d  %5d  %4d%%",
        "TOTAL", grand_hit, grand_exec, overall))
    print(BAR .. "\n")
end

return M
