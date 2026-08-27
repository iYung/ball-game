local BALL_RADIUS   = 10
local MIN_RADIUS    = 50
local MAX_RADIUS    = 300
local RADIUS_RATE   = 140
local ANGULAR_SPEED = 2.4

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local Player = {}
Player.__index = Player

function Player.new(x, y, center_x, center_y, direction)
    local self      = setmetatable({}, Player)
    self.x          = x
    self.y          = y
    self.center_x   = center_x
    self.center_y   = center_y
    self.direction  = direction or 1
    local dx, dy    = x - center_x, y - center_y
    self.radius     = math.sqrt(dx * dx + dy * dy)
    self.angle      = math.atan2(y - center_y, x - center_x)
    return self
end

function Player:update(dt, space_held, walls)
    local desired_radius = clamp(self.radius + RADIUS_RATE * dt * (space_held and 1 or -1), MIN_RADIUS, MAX_RADIUS)

    -- Re-pivot around the fixed ball: the ball doesn't move here, only the
    -- center slides along the ball-to-center line to the new radius.
    local ux, uy = self.center_x - self.x, self.center_y - self.y
    local ulen = math.sqrt(ux * ux + uy * uy)
    if ulen > 0 then
        ux, uy = ux / ulen, uy / ulen
    else
        ux, uy = 1, 0
    end
    self.center_x = self.x + ux * desired_radius
    self.center_y = self.y + uy * desired_radius
    self.radius   = desired_radius

    self.angle = math.atan2(self.y - self.center_y, self.x - self.center_x)
    self.angle = self.angle + self.direction * ANGULAR_SPEED * dt
    local new_x = self.center_x + self.radius * math.cos(self.angle)
    local new_y = self.center_y + self.radius * math.sin(self.angle)

    if walls then
        for _, rect in ipairs(walls) do
            local closest_x = clamp(new_x, rect.x, rect.x + rect.w)
            local closest_y = clamp(new_y, rect.y, rect.y + rect.h)
            local dx, dy = new_x - closest_x, new_y - closest_y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < BALL_RADIUS then
                if dist > 0 then
                    new_x = closest_x + dx / dist * BALL_RADIUS
                    new_y = closest_y + dy / dist * BALL_RADIUS
                else
                    local pen_x = math.min(new_x - rect.x, rect.x + rect.w - new_x)
                    local pen_y = math.min(new_y - rect.y, rect.y + rect.h - new_y)
                    if pen_x < pen_y then
                        new_x = (new_x < rect.x + rect.w / 2) and (rect.x - BALL_RADIUS) or (rect.x + rect.w + BALL_RADIUS)
                    else
                        new_y = (new_y < rect.y + rect.h / 2) and (rect.y - BALL_RADIUS) or (rect.y + rect.h + BALL_RADIUS)
                    end
                end
                self.direction = -self.direction
                self.angle = math.atan2(new_y - self.center_y, new_x - self.center_x)
                break
            end
        end
    end

    self.x, self.y = new_x, new_y
end

function Player:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self.x, self.y, BALL_RADIUS)
end

return Player
