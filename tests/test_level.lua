local Level = require("game/level")

-- Test 1: wall count and gap coverage for a split top exit
do
    local def = {
        id = 1,
        exit = { side = "top", pos = 640, gap = 160 },
        obstacles = {},
    }
    local walls = Level.walls(def)
    assert(#walls == 5, "expected 5 rects (2 top segments + bottom + left + right), got " .. #walls)

    for _, r in ipairs(walls) do
        if r.y == 0 and r.h == 40 then
            local covers_gap = (r.x + r.w > 560) and (r.x < 720)
            assert(not covers_gap,
                "top wall rect should not overlap gap span [560,720]: got x="
                .. r.x .. " w=" .. r.w)
        end
    end
    print("PASS: level: walls() returns 5 rects and top gap is uncovered")
end

-- Test 2: obstacles pass through unchanged
do
    local obstacle = { x = 500, y = 300, w = 50, h = 50 }
    local def = {
        id = 2,
        exit = { side = "left", pos = 360, gap = 120 },
        obstacles = { obstacle },
    }
    local walls = Level.walls(def)

    local found = false
    for _, r in ipairs(walls) do
        if r.x == obstacle.x and r.y == obstacle.y and r.w == obstacle.w and r.h == obstacle.h then
            found = true
        end
    end
    assert(found, "walls() should include the obstacle rect unchanged")
    print("PASS: level: walls() passes obstacles through unchanged")
end

-- Test 3: mirrored_entry returns the opposite side for all 4 sides, pos/gap unchanged
do
    local expected_opposite = {
        top = "bottom",
        bottom = "top",
        left = "right",
        right = "left",
    }

    for side, opposite in pairs(expected_opposite) do
        local def = {
            id = 3,
            exit = { side = side, pos = 333, gap = 100 },
            obstacles = {},
        }
        local entry = Level.mirrored_entry(def)
        assert(entry.side == opposite,
            "mirrored_entry side for exit=" .. side .. " should be " .. opposite .. ", got " .. tostring(entry.side))
        assert(entry.pos == 333,
            "mirrored_entry pos should be unchanged at 333, got " .. tostring(entry.pos))
        assert(entry.gap == 100,
            "mirrored_entry gap should match the exit gap (100), got " .. tostring(entry.gap))
    end
    print("PASS: level: mirrored_entry() returns opposite side with unchanged pos/gap for all 4 sides")
end

-- Test 3b: walls() also carves a gap on the entry side when one is passed,
-- distinct from the exit side — regression test for a bug where a level
-- entered via a mirrored entry had no opening on its entry wall at all
do
    local def = {
        id = 4,
        exit = { side = "right", pos = 300, gap = 160 },
        obstacles = {},
    }
    local entry = { side = "bottom", pos = 640, gap = 160 }
    local walls = Level.walls(def, entry)

    assert(#walls == 6, "expected 6 rects (top + left + 2 right segments + 2 bottom segments), got " .. #walls)

    for _, r in ipairs(walls) do
        if r.h == 40 and r.y == 680 then -- bottom wall segments
            local covers_gap = (r.x + r.w > 560) and (r.x < 720)
            assert(not covers_gap,
                "bottom (entry) wall rect should not overlap gap span [560,720]: got x=" .. r.x .. " w=" .. r.w)
        end
    end
    print("PASS: level: walls() carves a gap on the entry side too")
end

-- Test 4: spawn placement for a bottom entry (vertical side) — fish should
-- face straight up (into the room) along the inward normal
do
    local entry = { side = "bottom", pos = 640 }
    local spawn = Level.spawn(entry)

    assert(spawn.x == 640, "spawn x should be 640, got " .. tostring(spawn.x))
    assert(math.abs(spawn.y - 706) < 0.01, "spawn y should be ~706, got " .. tostring(spawn.y))
    assert(math.abs(spawn.heading - (-math.pi / 2)) < 0.01,
        "spawn heading for a bottom entry should face up (-pi/2), got " .. tostring(spawn.heading))
    print("PASS: level: spawn() places ball correctly for bottom entry")
end

-- Test 5: spawn placement for a left entry (non-vertical side) — should face right
do
    local entry = { side = "left", pos = 300 }
    local spawn = Level.spawn(entry)

    assert(math.abs(spawn.x - 14) < 0.01, "spawn x should be ~14, got " .. tostring(spawn.x))
    assert(spawn.y == 300, "spawn y should be 300, got " .. tostring(spawn.y))
    assert(math.abs(spawn.heading - 0) < 0.01,
        "spawn heading for a left entry should face right (0), got " .. tostring(spawn.heading))
    print("PASS: level: spawn() places ball correctly for left entry")
end

-- Test 6: default_spawn() is clear of every wall in a level with only a top
-- gap (i.e. its own bottom/left/right sides are solid) — regression test for
-- a bug where the level-1 boot spawn embedded the ball in its solid bottom
-- wall and immediately shoved it out of bounds.
do
    local def = {
        id = 1,
        exit = { side = "top", pos = 640, gap = 160 },
        obstacles = {},
    }
    local walls = Level.walls(def)
    local spawn = Level.default_spawn()

    for _, r in ipairs(walls) do
        local inside = spawn.x >= r.x and spawn.x <= r.x + r.w
            and spawn.y >= r.y and spawn.y <= r.y + r.h
        assert(not inside, "default_spawn() should not land inside any wall rect")
    end
    assert(spawn.x > 0 and spawn.x < 1280 and spawn.y > 0 and spawn.y < 720,
        "default_spawn() should be within the room bounds")
    assert(math.abs(spawn.heading - (-math.pi / 2)) < 0.01,
        "default_spawn heading should face up (-pi/2), got " .. tostring(spawn.heading))
    print("PASS: level: default_spawn() lands clear of walls and inside the room")
end

print("ALL TESTS PASSED")
