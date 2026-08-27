return {
    from = function(path, hinting)
        hinting = hinting or "light"
        return { new = function(size) return love.graphics.newFont(path, size, hinting) end }
    end
}
