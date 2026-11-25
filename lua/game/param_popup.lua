local ParamPopup = {}
ParamPopup.__index = ParamPopup

local W, H = 1280, 720
local BOX_W, BOX_H = 360, 220
local BOX_X = (W - BOX_W) / 2
local BOX_Y = (H - BOX_H) / 2

local FIELD_DEFS = {
    scale_row  = { {name="row",    kind="int"}, {name="scalar", kind="num"} },
    add_rows   = { {name="src",    kind="int"}, {name="dst",    kind="int"}, {name="scalar", kind="num"} },
    swap_rows  = { {name="row_a",  kind="int"}, {name="row_b",  kind="int"} },
    scalar_mul = { {name="scalar", kind="num"} },
    transpose  = {},
    negate     = {},
}

local C = {
    bg           = {0.12, 0.12, 0.18, 1},
    border       = {0.4,  0.6,  1.0,  1},
    field_bg     = {0.08, 0.08, 0.14, 1},
    field_border = {0.7,  0.9,  1.0,  1},
    text         = {0.9,  0.9,  0.95, 1},
    title        = {0.7,  0.9,  1.0,  1},
    hint         = {0.6,  0.6,  0.65, 1},
    error        = {1.0,  0.4,  0.4,  1},
}

function ParamPopup.new()
    return setmetatable({
        _open       = false,
        _op         = nil,
        _fields     = {},
        _values     = {},
        _focus      = 1,
        _on_confirm = nil,
        _on_cancel  = nil,
        _error      = nil,
    }, ParamPopup)
end

function ParamPopup:open(op_type, current_params, on_confirm_cb, on_cancel_cb)
    self._open       = true
    self._op         = op_type
    self._fields     = FIELD_DEFS[op_type] or {}
    self._on_confirm = on_confirm_cb
    self._on_cancel  = on_cancel_cb
    self._focus      = 1
    self._error      = nil
    self._values     = {}
    local cp = current_params or {}
    for _, f in ipairs(self._fields) do
        local v = cp[f.name]
        self._values[f.name] = v and tostring(v) or ""
    end
end

function ParamPopup:close()
    self._open = false
end

function ParamPopup:is_open()
    return self._open
end

function ParamPopup:key_pressed(key)
    if not self._open then return end
    if key == "escape" then
        self._open = false
        if self._on_cancel then self._on_cancel() end
    elseif key == "return" or key == "kpenter" then
        self:_try_confirm()
    elseif key == "tab" then
        if #self._fields > 0 then
            self._focus = (self._focus % #self._fields) + 1
            self._error = nil
        end
    elseif key == "backspace" then
        local f = self._fields[self._focus]
        if f then
            local v = self._values[f.name] or ""
            self._values[f.name] = v:sub(1, -2)
            self._error = nil
        end
    end
end

function ParamPopup:text_input(text)
    if not self._open then return end
    local f = self._fields[self._focus]
    if f then
        self._values[f.name] = (self._values[f.name] or "") .. text
        self._error = nil
    end
end

function ParamPopup:_try_confirm()
    local params = {}
    for _, f in ipairs(self._fields) do
        local raw = self._values[f.name] or ""
        local n = tonumber(raw)
        if n == nil then
            self._error = "'" .. f.name .. "' must be a number"
            return
        end
        if f.kind == "int" and math.floor(n) ~= n then
            self._error = "'" .. f.name .. "' must be a whole number"
            return
        end
        params[f.name] = (f.kind == "int") and math.floor(n) or n
    end
    self._open = false
    if self._on_confirm then self._on_confirm(params) end
end

function ParamPopup:draw()
    if not self._open then return end

    -- Box background
    love.graphics.setColor(C.bg)
    love.graphics.rectangle("fill", BOX_X, BOX_Y, BOX_W, BOX_H, 8, 8)
    love.graphics.setColor(C.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", BOX_X, BOX_Y, BOX_W, BOX_H, 8, 8)

    local px, py = BOX_X + 20, BOX_Y + 18

    -- Title
    love.graphics.setColor(C.title)
    love.graphics.print(self._op or "", px, py)
    py = py + 28

    if #self._fields == 0 then
        love.graphics.setColor(C.hint)
        love.graphics.print("No parameters needed.", px, py)
        py = py + 24
    end

    local field_h = 28
    local field_w = BOX_W - 40

    for i, f in ipairs(self._fields) do
        local focused = (i == self._focus)
        local val     = self._values[f.name] or ""

        love.graphics.setColor(C.text)
        love.graphics.print(f.name .. ":", px, py)
        py = py + 18

        love.graphics.setColor(C.field_bg)
        love.graphics.rectangle("fill", px, py, field_w, field_h, 4, 4)
        love.graphics.setColor(focused and C.field_border or C.border)
        love.graphics.setLineWidth(focused and 2 or 1)
        love.graphics.rectangle("line", px, py, field_w, field_h, 4, 4)

        love.graphics.setColor(C.text)
        love.graphics.print(val .. (focused and "_" or ""), px + 6, py + 6)

        py = py + field_h + 10
    end

    -- Error
    if self._error then
        love.graphics.setColor(C.error)
        love.graphics.print(self._error, px, py)
        py = py + 20
    end

    -- Hint
    local hint = "[Enter] Confirm  [Esc] Cancel"
    if #self._fields > 1 then hint = hint .. "  [Tab] Next field" end
    love.graphics.setColor(C.hint)
    love.graphics.print(hint, BOX_X + 10, BOX_Y + BOX_H - 22)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return ParamPopup
