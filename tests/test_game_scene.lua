local runner    = require("lua/headless/runner")
local GameScene = require("lua/game/scenes/game_scene")
local Player    = require("lua/game/player")

-- GameScene: on_enter, update, draw via the real scene loop
do
    local ctx = runner.setup(function(_, _) return GameScene.new() end)
    runner.tick(ctx.input, ctx.sm, 2)
    assert(ctx.sm.current ~= nil, "scene is live after 2 ticks")
    print("PASS: GameScene ticks without error")
end

-- Player: construction and read-only methods
do
    local p = Player.new(100, 200)
    assert(p ~= nil, "Player.new returns an object")
    print("PASS: Player.new")

    local c = p:centre()
    assert(type(c.x) == "number", "centre returns x as number")
    assert(type(c.y) == "number", "centre returns y as number")
    assert(c.x == 116, "centre.x == x + 16")
    assert(c.y == 224, "centre.y == y + 24")
    print("PASS: Player.centre")

    p:draw()   -- love.graphics is stubbed; must not raise
    print("PASS: Player.draw (graphics stubbed)")
end

-- Player:update movement branches – stub isDown for each direction
do
    local p    = Player.new(0, 0)
    local orig = love.keyboard.isDown

    local function with_key(key, fn)
        love.keyboard.isDown = function(k) return k == key end
        fn()
        love.keyboard.isDown = orig
    end

    local x0 = p.sprite.x
    with_key("a", function() p:update(1/60) end)
    assert(p.sprite.x < x0, "left key decreases sprite.x")
    print("PASS: Player moves left")

    local x1 = p.sprite.x
    with_key("d", function() p:update(1/60) end)
    assert(p.sprite.x > x1, "right key increases sprite.x")
    print("PASS: Player moves right")

    local y0 = p.sprite.y
    with_key("w", function() p:update(1/60) end)
    assert(p.sprite.y < y0, "up key decreases sprite.y")
    print("PASS: Player moves up")

    local y1 = p.sprite.y
    with_key("s", function() p:update(1/60) end)
    assert(p.sprite.y > y1, "down key increases sprite.y")
    print("PASS: Player moves down")
end

print("ALL GAME SCENE / PLAYER TESTS PASSED")
