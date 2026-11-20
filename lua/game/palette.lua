local Palette = {}
Palette.__index = Palette

function Palette.new()
    local self = setmetatable({}, Palette)
    self._selected = nil
    return self
end

function Palette:select(spec)
    if spec == nil then
        self._selected = nil
    else
        local copy = {}
        for k, v in pairs(spec) do copy[k] = v end
        self._selected = copy
    end
end

function Palette:selected()
    return self._selected
end

function Palette:is_eraser()
    return self._selected == nil
end

function Palette:is_drag()
    return self._selected ~= nil and self._selected.kind == "drag"
end

return Palette
