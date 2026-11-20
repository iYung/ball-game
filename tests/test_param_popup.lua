require("lua/headless/stubs")
local ParamPopup = require("lua/game/param_popup")

-- new() / is_open() starts closed
do
    local p = ParamPopup.new()
    assert(not p:is_open(), "new popup is closed")
    print("PASS: new popup is closed")
end

-- open() with each op type, then close()
do
    local ops = { "scale_row", "add_rows", "swap_rows", "scalar_mul", "transpose", "negate" }
    for _, op in ipairs(ops) do
        local p = ParamPopup.new()
        p:open(op, nil, function() end, function() end)
        assert(p:is_open(), "open() sets open for " .. op)
        p:close()
        assert(not p:is_open(), "close() clears open for " .. op)
    end
    print("PASS: open/close for all op types")
end

-- open() with current_params pre-fills values
do
    local p = ParamPopup.new()
    p:open("scale_row", { row = 2, scalar = 1.5 }, function() end, function() end)
    assert(p._values["row"] == "2", "row pre-filled")
    assert(p._values["scalar"] == "1.5", "scalar pre-filled")
    print("PASS: open() pre-fills current_params")
end

-- key_pressed "escape" fires cancel callback and closes
do
    local cancelled = false
    local p = ParamPopup.new()
    p:open("scale_row", nil, function() end, function() cancelled = true end)
    p:key_pressed("escape")
    assert(not p:is_open(), "escape closes popup")
    assert(cancelled, "escape fires cancel callback")
    print("PASS: escape closes and fires cancel")
end

-- key_pressed when closed is a no-op
do
    local p = ParamPopup.new()
    p:key_pressed("escape")  -- should not error
    assert(not p:is_open(), "key_pressed on closed popup is no-op")
    print("PASS: key_pressed on closed popup is no-op")
end

-- key_pressed "return" happy path: valid int + num
do
    local confirmed_params = nil
    local p = ParamPopup.new()
    p:open("scale_row", { row = 1, scalar = 2.0 }, function(params) confirmed_params = params end, function() end)
    p._values["row"] = "3"
    p._values["scalar"] = "1.5"
    p:key_pressed("return")
    assert(not p:is_open(), "return closes popup on valid input")
    assert(confirmed_params ~= nil, "confirm callback fired")
    assert(confirmed_params.row == 3, "row is int 3")
    assert(confirmed_params.scalar == 1.5, "scalar is num 1.5")
    print("PASS: return confirm happy path")
end

-- key_pressed "kpenter" behaves like return
do
    local confirmed = false
    local p = ParamPopup.new()
    p:open("scale_row", nil, function() confirmed = true end, function() end)
    p._values["row"] = "1"
    p._values["scalar"] = "2"
    p:key_pressed("kpenter")
    assert(confirmed, "kpenter fires confirm")
    print("PASS: kpenter fires confirm")
end

-- _try_confirm: non-numeric input sets _error
do
    local p = ParamPopup.new()
    p:open("scale_row", nil, function() end, function() end)
    p._values["row"] = "abc"
    p._values["scalar"] = "1.0"
    p:key_pressed("return")
    assert(p:is_open(), "popup stays open on error")
    assert(p._error ~= nil, "error is set for non-numeric")
    print("PASS: non-numeric input sets error")
end

-- _try_confirm: float for int field sets _error
do
    local p = ParamPopup.new()
    p:open("scale_row", nil, function() end, function() end)
    p._values["row"] = "1.5"
    p._values["scalar"] = "2.0"
    p:key_pressed("return")
    assert(p:is_open(), "popup stays open on float-for-int")
    assert(p._error ~= nil, "error is set for float-for-int")
    print("PASS: float-for-int sets error")
end

-- _try_confirm: 0-field op (transpose) confirms immediately
do
    local confirmed = false
    local p = ParamPopup.new()
    p:open("transpose", nil, function(params)
        confirmed = true
        assert(type(params) == "table", "params is table")
    end, function() end)
    p:key_pressed("return")
    assert(confirmed, "0-field op confirms with return")
    assert(not p:is_open(), "popup closed after 0-field confirm")
    print("PASS: 0-field op confirm")
end

-- key_pressed "tab" cycles focus
do
    local p = ParamPopup.new()
    p:open("add_rows", nil, function() end, function() end)  -- 3 fields
    assert(p._focus == 1, "initial focus is 1")
    p:key_pressed("tab")
    assert(p._focus == 2, "tab moves to field 2")
    p:key_pressed("tab")
    assert(p._focus == 3, "tab moves to field 3")
    p:key_pressed("tab")
    assert(p._focus == 1, "tab wraps back to field 1")
    print("PASS: tab cycles focus")
end

-- tab on 0-field op is a no-op
do
    local p = ParamPopup.new()
    p:open("transpose", nil, function() end, function() end)
    p:key_pressed("tab")
    assert(p._focus == 1, "tab on 0-field op leaves focus at 1")
    print("PASS: tab no-op on 0-field op")
end

-- key_pressed "backspace" deletes last char
do
    local p = ParamPopup.new()
    p:open("scale_row", nil, function() end, function() end)
    p._values["row"] = "123"
    p:key_pressed("backspace")
    assert(p._values["row"] == "12", "backspace removes last char")
    p:key_pressed("backspace")
    p:key_pressed("backspace")
    p:key_pressed("backspace")  -- extra backspace on empty string is safe
    assert(p._values["row"] == "", "backspace on empty string is safe")
    print("PASS: backspace deletes last char")
end

-- backspace also clears error
do
    local p = ParamPopup.new()
    p:open("scale_row", nil, function() end, function() end)
    p._values["row"] = "abc"
    p._values["scalar"] = "1"
    p:key_pressed("return")  -- sets _error
    assert(p._error ~= nil, "error set before backspace")
    p:key_pressed("backspace")
    assert(p._error == nil, "backspace clears error")
    print("PASS: backspace clears error")
end

-- text_input appends to focused field
do
    local p = ParamPopup.new()
    p:open("scale_row", nil, function() end, function() end)
    p:text_input("1")
    p:text_input("2")
    assert(p._values["row"] == "12", "text_input appends to focused field")
    print("PASS: text_input appends")
end

-- text_input clears error
do
    local p = ParamPopup.new()
    p:open("scalar_mul", nil, function() end, function() end)
    p._values["scalar"] = "abc"
    p:key_pressed("return")
    assert(p._error ~= nil, "error set")
    p:text_input("5")
    assert(p._error == nil, "text_input clears error")
    print("PASS: text_input clears error")
end

-- text_input on closed popup is no-op
do
    local p = ParamPopup.new()
    p:text_input("x")  -- should not error
    print("PASS: text_input on closed popup is no-op")
end

-- draw() while open with 0 fields (transpose)
do
    local p = ParamPopup.new()
    p:open("transpose", nil, function() end, function() end)
    p:draw()  -- exercises 0-field draw branch
    print("PASS: draw() with 0 fields")
end

-- draw() with _error set
do
    local p = ParamPopup.new()
    p:open("scale_row", nil, function() end, function() end)
    p._values["row"] = "bad"
    p._values["scalar"] = "1"
    p:key_pressed("return")  -- sets _error
    assert(p._error ~= nil, "error is set for draw test")
    p:draw()  -- exercises error draw branch
    print("PASS: draw() with _error set")
end

-- draw() with multiple fields (adds Tab hint in footer)
do
    local p = ParamPopup.new()
    p:open("add_rows", nil, function() end, function() end)  -- 3 fields
    p:draw()
    print("PASS: draw() with multiple fields")
end

-- draw() while closed is a no-op
do
    local p = ParamPopup.new()
    p:draw()  -- should return immediately
    print("PASS: draw() while closed is no-op")
end

print("ALL PARAM POPUP TESTS PASSED")
