local Camera = require("lua/core/camera")

-- Test 1: default dimensions are 1280x720
do
    local c = Camera.new()
    assert(c._w == 1280, "default _w should be 1280, got " .. tostring(c._w))
    assert(c._h == 720,  "default _h should be 720, got "  .. tostring(c._h))
    print("PASS: camera: default dimensions are 1280x720")
end

-- Test 2: custom dimensions are stored
do
    local c = Camera.new(0, 0, 800, 600)
    assert(c._w == 800, "custom _w should be 800, got " .. tostring(c._w))
    assert(c._h == 600, "custom _h should be 600, got " .. tostring(c._h))
    print("PASS: camera: custom dimensions stored correctly")
end

-- Test 3: position and dimensions are independent
do
    local c = Camera.new(100, 200, 1920, 1080)
    assert(c.x   == 100,  "x should be 100")
    assert(c.y   == 200,  "y should be 200")
    assert(c._w  == 1920, "_w should be 1920")
    assert(c._h  == 1080, "_h should be 1080")
    print("PASS: camera: position and dimensions stored independently")
end

print("ALL TESTS PASSED")
