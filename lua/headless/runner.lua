local HeadlessInput = require("lua/headless/input")
local SceneManager  = require("lua/core/scene_manager")

local runner = {
    -- Set to true before setup() to enable visual mode: tick() yields each
    -- frame so love.draw() renders between updates.
    _visual    = false,
    -- Populated by setup() in visual mode so love.draw() can find the scene.
    _active_sm = nil,
}

-- Creates a HeadlessInput and SceneManager; wires them together; switches to
-- the scene returned by scene_factory(input, sm).  scene_factory is required
-- and must not be nil.
-- Returns { input = input, sm = sm }.
function runner.setup(scene_factory)
    if scene_factory == nil then
        error("runner.setup: scene_factory is required")
    end

    local input = HeadlessInput.new()
    local sm    = SceneManager.new(1280, 720)

    local scene = scene_factory(input, sm)

    sm:switch(scene)

    if runner._visual then
        runner._active_sm = sm
    end

    return { input = input, sm = sm }
end

-- Advances the simulation n times (default 1) by dt seconds each (default
-- 1/60).  Calls input:update() then scene_manager:update(dt) each iteration.
-- In visual mode, yields after each frame so love.draw() can render it.
function runner.tick(input, scene_manager, n, dt)
    n  = n  or 1
    dt = dt or (1 / 60)
    for _ = 1, n do
        input:update()
        scene_manager:update(dt)
        if runner._visual then
            coroutine.yield()
        end
    end
end

-- Advances the simulation one tick at a time (dt=1.0) until condition_fn()
-- returns true, incrementing elapsed by 1.0 each tick.
-- Errors if cap (default 600) iterations are exceeded.
-- Returns the updated elapsed.
function runner.fast_forward_until(ctx, condition_fn, elapsed, cap)
    cap = cap or 600
    local iters = 0
    while not condition_fn() do
        if iters >= cap then
            error("fast_forward_until: condition not met after " .. cap .. " simulated seconds")
        end
        runner.tick(ctx.input, ctx.sm, 1, 1.0)
        elapsed = elapsed + 1.0
        iters   = iters + 1
    end
    return elapsed
end

-- Loads and executes test_file inside a pcall, prints a PASS/FAIL summary
-- line, then quits Love2D with exit code 0 (all passed) or 1 (failure).
-- When test_file is nil, discovers and runs all *.lua files under tests/.
function runner.run(test_file)
    _G.runner = runner

    if test_file == nil then
        local items = love.filesystem.getDirectoryItems("tests")
        local files = {}
        for _, name in ipairs(items) do
            if name:sub(-4) == ".lua" then
                files[#files + 1] = name
            end
        end
        table.sort(files)

        local passed = 0
        local total  = #files
        local any_failed = false
        for _, filename in ipairs(files) do
            local path = "tests/" .. filename
            local ok, err = pcall(dofile, path)
            if ok then
                print("PASS  " .. path)
                passed = passed + 1
            else
                print("FAIL  " .. path .. " — " .. tostring(err))
                any_failed = true
            end
        end

        print(passed .. "/" .. total .. " passed")
        love.event.quit(any_failed and 1 or 0)
        return
    end

    local ok, err = pcall(dofile, test_file)

    if ok then
        print("PASS")
        love.event.quit(0)
    else
        print("FAIL: " .. tostring(err))
        love.event.quit(1)
    end
end

return runner
