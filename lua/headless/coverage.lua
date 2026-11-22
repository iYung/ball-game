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

-- Collect the set of lines that the Lua VM can fire the debug hook on for a
-- given source file.  We do this by loading the file and walking every
-- reachable function prototype via debug.getinfo(fn,"L").activelines, which
-- returns exactly that set -- no source-text heuristics required.
local function get_active_lines(path)
    local result = {}
    local seen   = {}
    local scan_fn, scan_table

    scan_fn = function(fn)
        if type(fn) ~= "function" or seen[fn] then return end
        seen[fn] = true
        local info = debug.getinfo(fn, "SuL")
        -- Only collect lines that belong to this file.
        if info.source ~= "@" .. path then return end
        if info.activelines then
            for ln in pairs(info.activelines) do result[ln] = true end
        end
        -- Recurse into upvalues: local helper functions close over their
        -- enclosing scope and show up here.
        for i = 1, info.nups do
            local _, v = debug.getupvalue(fn, i)
            if     type(v) == "function" then scan_fn(v)
            elseif type(v) == "table"    then scan_table(v) end
        end
    end

    scan_table = function(t)
        if type(t) ~= "table" or seen[t] then return end
        seen[t] = true
        for _, v in pairs(t) do
            if     type(v) == "function" then scan_fn(v)
            elseif type(v) == "table"    then scan_table(v) end
        end
    end

    -- Load (but don't execute) to get the outer chunk's active lines.
    local chunk = loadfile(path)
    if not chunk then return result end
    scan_fn(chunk)

    -- Execute the module to materialise inner closures.  Also hook call events
    -- so that functions invoked at module-load time (e.g. a local _load() called
    -- during initialisation) are captured even if they never appear in the
    -- returned table or any upvalue chain.
    debug.sethook(function()
        local info = debug.getinfo(2, "Sf")
        if info and info.func then scan_fn(info.func) end
    end, "c")
    local ok, ret = pcall(chunk)
    debug.sethook()

    if ok then
        if     type(ret) == "function" then scan_fn(ret)
        elseif type(ret) == "table"    then scan_table(ret) end
    end

    return result
end

function M.report()
    debug.sethook()

    -- Gather all source files, including those never loaded.
    local all_files = {}
    for _, f in ipairs(find_lua_files("lua/game")) do
        all_files[#all_files + 1] = f
    end

    local rows = {}
    local grand_hit, grand_exec = 0, 0
    local active_sets = {}  -- cache: reused for verbose output to avoid non-determinism

    for _, path in ipairs(all_files) do
        local active     = get_active_lines(path)
        active_sets[path] = active
        local exec_lines = 0
        for _ in pairs(active) do exec_lines = exec_lines + 1 end

        local hit_lines = 0
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
        local pct  = r.exec > 0 and math.floor(r.hit / r.exec * 100) or 0
        local flag = pct == 100 and "" or (pct < 50 and " !" or "")
        print(string.format("%-55s  %5d  %5d  %4d%%%s",
            r.path, r.hit, r.exec, pct, flag))
    end

    print(BAR)
    local overall = grand_exec > 0 and math.floor(grand_hit / grand_exec * 100) or 0
    print(string.format("%-55s  %5d  %5d  %4d%%",
        "TOTAL", grand_hit, grand_exec, overall))
    print(BAR .. "\n")

    if overall < 100 then
        print(string.format("COVERAGE FAIL: %d%% (need 100%%)\n", overall))
        -- Verbose: list uncovered lines per file so gaps can be diagnosed.
        local verbose = false
        for _, v in ipairs(arg or {}) do
            if v == "--verbose-gaps" then verbose = true end
        end
        if verbose then
            print("=== UNCOVERED LINES ===")
            for _, path in ipairs(all_files) do
                local active = active_sets[path]
                local missed = {}
                for ln in pairs(active) do
                    if not (_hits[path] and _hits[path][ln]) then
                        missed[#missed + 1] = ln
                    end
                end
                if #missed > 0 then
                    table.sort(missed)
                    local f = io.open(path, "r")
                    local source = {}
                    if f then
                        for line in f:lines() do source[#source + 1] = line end
                        f:close()
                    end
                    print(string.format("\n%s (%d missed):", path, #missed))
                    for _, ln in ipairs(missed) do
                        local text = source[ln] or ""
                        print(string.format("  %4d: %s", ln, text))
                    end
                end
            end
            print("=== END UNCOVERED LINES ===")
        end
        os.exit(1)
    end
end

return M
