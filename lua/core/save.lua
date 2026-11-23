local Save = {}

local function serialize(val)
    local t = type(val)
    if t == "nil" then
        return "nil"
    elseif t == "number" then
        return tostring(val)
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        local parts = {}
        for k, v in pairs(val) do
            local kt = type(k)
            if kt == "number" and math.floor(k) == k then
                parts[#parts + 1] = "[" .. tostring(k) .. "]=" .. serialize(v)
            elseif kt == "string" then
                if k:match("^[%a_][%w_]*$") then
                    parts[#parts + 1] = k .. "=" .. serialize(v)
                else
                    parts[#parts + 1] = "[" .. string.format("%q", k) .. "]=" .. serialize(v)
                end
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

function Save.exists()
    return love.filesystem.getInfo("save.dat") ~= nil
end

function Save.write(data)
    love.filesystem.write("save.dat", "return " .. serialize(data))
end

function Save.read()
    if not love.filesystem.getInfo("save.dat") then return nil end
    local content, _ = love.filesystem.read("save.dat")
    if not content then return nil end
    local loader = loadstring or load
    local ok, result = pcall(function()
        return loader(content)()
    end)
    if not ok then return nil end
    return result
end

function Save.settings_exist()
    return love.filesystem.getInfo("settings.dat") ~= nil
end

function Save.write_settings(data)
    love.filesystem.write("settings.dat", "return " .. serialize(data))
end

function Save.read_settings()
    if not love.filesystem.getInfo("settings.dat") then return nil end
    local content, _ = love.filesystem.read("settings.dat")
    if not content then return nil end
    local loader = loadstring or load
    local ok, result = pcall(function()
        return loader(content)()
    end)
    if not ok then return nil end
    return result
end

return Save
