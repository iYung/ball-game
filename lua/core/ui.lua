-- lua/core/ui.lua
-- Shared hit-testing helpers for scene UI element registries.
-- Rects are { x, y, w, h } in logical 1280x720 space and are half-open:
-- a point is inside if x <= px < x+w and y <= py < y+h.
-- This module must not require any game module.

local UI = {}

function UI.hit(rect, x, y)
    return x >= rect.x and x < rect.x + rect.w
       and y >= rect.y and y < rect.y + rect.h
end

-- First element (in list order) whose rect contains (x, y), or nil.
function UI.element_at(elements, x, y)
    for _, e in ipairs(elements or {}) do
        if e.rect and UI.hit(e.rect, x, y) then return e end
    end
    return nil
end

-- Element with the given id, or nil.
function UI.find(elements, id)
    for _, e in ipairs(elements or {}) do
        if e.id == id then return e end
    end
    return nil
end

-- Centre of a rect, rounded to whole pixels.
function UI.centre(rect)
    return math.floor(rect.x + rect.w / 2 + 0.5),
           math.floor(rect.y + rect.h / 2 + 0.5)
end

-- True iff the rects intersect with positive area (shared edges do not count).
function UI.overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w
       and a.y < b.y + b.h and b.y < a.y + a.h
end

return UI
