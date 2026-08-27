local BALL_RADIUS = 10
local MAX_SPEED    = 260
local FLIP_BOOST   = 70
local FLIP_TURN    = 0.35
local DRAG         = 90

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local Player = {}
Player.__index = Player

function Player.new(x, y, heading)
    local self       = setmetatable({}, Player)
    self.x           = x
    self.y           = y
    self.heading     = heading or 0
    self.speed       = 0
    self.last_flip   = nil -- nil, "left", or "right" — tracks the alternation requirement
    return self
end

function Player:update(dt, flip_left, flip_right, walls)
    -- Every flip turns the heading, so steering is always direct and
    -- responsive. The speed boost — the actual forward propulsion — only
    -- comes from an *alternating* flip, mirroring a fish needing to beat its
    -- tail the other way each stroke to swim forward; flipping the same side
    -- repeatedly turns you sharply in place without adding speed, like
    -- paddling one side of a canoe.
    if flip_left then
        self.heading = self.heading - FLIP_TURN
        if self.last_flip ~= "left" then
            self.speed = clamp(self.speed + FLIP_BOOST, 0, MAX_SPEED)
        end
        self.last_flip = "left"
    elseif flip_right then
        self.heading = self.heading + FLIP_TURN
        if self.last_flip ~= "right" then
            self.speed = clamp(self.speed + FLIP_BOOST, 0, MAX_SPEED)
        end
        self.last_flip = "right"
    end

    self.speed = math.max(0, self.speed - DRAG * dt)

    local new_x = self.x + math.cos(self.heading) * self.speed * dt
    local new_y = self.y + math.sin(self.heading) * self.speed * dt

    if walls then
        for _, rect in ipairs(walls) do
            local closest_x = clamp(new_x, rect.x, rect.x + rect.w)
            local closest_y = clamp(new_y, rect.y, rect.y + rect.h)
            local dx, dy = new_x - closest_x, new_y - closest_y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < BALL_RADIUS then
                local nx, ny
                if dist > 0 then
                    nx, ny = dx / dist, dy / dist
                    new_x = closest_x + nx * BALL_RADIUS
                    new_y = closest_y + ny * BALL_RADIUS
                else
                    local pen_x = math.min(new_x - rect.x, rect.x + rect.w - new_x)
                    local pen_y = math.min(new_y - rect.y, rect.y + rect.h - new_y)
                    if pen_x < pen_y then
                        nx, ny = (new_x < rect.x + rect.w / 2) and -1 or 1, 0
                        new_x  = (new_x < rect.x + rect.w / 2) and (rect.x - BALL_RADIUS) or (rect.x + rect.w + BALL_RADIUS)
                    else
                        nx, ny = 0, (new_y < rect.y + rect.h / 2) and -1 or 1
                        new_y  = (new_y < rect.y + rect.h / 2) and (rect.y - BALL_RADIUS) or (rect.y + rect.h + BALL_RADIUS)
                    end
                end

                -- Reflect the heading off the wall normal: v' = v - 2(v.n)n
                local vx, vy = math.cos(self.heading), math.sin(self.heading)
                local vdotn  = vx * nx + vy * ny
                local rx, ry = vx - 2 * vdotn * nx, vy - 2 * vdotn * ny
                self.heading = math.atan2(ry, rx)
                break
            end
        end
    end

    self.x, self.y = new_x, new_y
end

function Player:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self.x, self.y, BALL_RADIUS)

    -- Heading indicator, so the swim direction is readable on screen.
    love.graphics.line(
        self.x, self.y,
        self.x + math.cos(self.heading) * BALL_RADIUS * 1.8,
        self.y + math.sin(self.heading) * BALL_RADIUS * 1.8
    )
end

return Player
