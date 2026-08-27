local headless = false
for _, v in ipairs(arg or {}) do
    if v == "--headless" then
        headless = true
        break
    end
end

function love.conf(t)
    t.window.width    = 1280
    t.window.height   = 720
    t.window.title    = "Love Exemplar"
    t.window.resizable = true

    if headless then
        t.window.width  = 1
        t.window.height = 1

        t.modules.window   = false
        t.modules.graphics = false
        t.modules.audio    = false
        t.modules.sound    = false
        t.modules.joystick = false
        t.modules.touch    = false
        t.modules.video    = false
    end
end
