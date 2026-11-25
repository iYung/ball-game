-- Reads a puzzle definition from text without running it. The editor's Paste
-- takes whatever is on the clipboard, so it must never be passed to load().
--
-- Accepts one table literal, optionally preceded by `return`: nested tables,
-- name or ["string"] keys, strings, numbers, true/false/nil and comments.
-- Anything else (calls, variables, operators, long strings) is an error.

local DefParser = {}

local MAX_LENGTH = 100000
local MAX_DEPTH  = 16

local ESCAPES = {
    a="\a", b="\b", f="\f", n="\n", r="\r", t="\t", v="\v",
    ["\\"]="\\", ['"']='"', ["'"]="'", ["\n"]="\n",
}
local LITERALS = { ["true"]=true, ["false"]=false }

local function fail(pos, what)
    error(string.format("%s at character %d", what, pos), 0)
end

-- Position of the next character that is not whitespace or part of a comment.
local function skip(s, i)
    while true do
        i = s:find("%S", i) or #s + 1
        if s:sub(i, i+1) ~= "--" then return i end
        local eq = s:match("^%[(=*)%[", i+2)
        if eq then
            local _, close = s:find("]" .. eq .. "]", i+4+#eq, true)
            if not close then fail(i, "unfinished comment") end
            i = close + 1
        else
            i = s:find("\n", i+2, true) or #s + 1
        end
    end
end

local function read_string(s, i)
    local quote = s:sub(i, i)
    local out = {}
    local j = i + 1
    while true do
        local c = s:sub(j, j)
        if c == "" or c == "\n" then fail(i, "unfinished string") end
        if c == quote then return table.concat(out), j + 1 end
        if c == "\\" then
            local digits = s:match("^%d%d?%d?", j+1)
            if digits then
                if tonumber(digits) > 255 then fail(j, "bad escape") end
                out[#out+1] = string.char(tonumber(digits))
                j = j + 1 + #digits
            else
                local e = ESCAPES[s:sub(j+1, j+1)]
                if not e then fail(j, "bad escape") end
                out[#out+1] = e
                j = j + 2
            end
        else
            out[#out+1] = c
            j = j + 1
        end
    end
end

local function read_number(s, i)
    local token = s:match("^%-?[%w%.]+", i)
    if token and token:match("[eE]$") then
        token = token .. (s:match("^[%+%-]%d+", i + #token) or "")
    end
    local n = token and tonumber(token)
    if not n then fail(i, "unexpected text") end
    return n, i + #token
end

local read_value

local function read_table(s, i, depth)
    if depth > MAX_DEPTH then fail(i, "tables nested too deeply") end
    local t, n = {}, 0
    i = skip(s, i + 1)
    while s:sub(i, i) ~= "}" do
        local key
        local name, after = s:match("^([%a_][%w_]*)()", i)
        if name then
            local eq = skip(s, after)
            if s:sub(eq, eq) == "=" then key, i = name, skip(s, eq + 1) end
        elseif s:sub(i, i) == "[" then
            local k = skip(s, i + 1)
            if not s:match("^[\"']", k) then fail(k, "key must be a string") end
            key, k = read_string(s, k)
            k = skip(s, k)
            if s:sub(k, k) ~= "]" then fail(k, "expected ']'") end
            k = skip(s, k + 1)
            if s:sub(k, k) ~= "=" then fail(k, "expected '='") end
            i = skip(s, k + 1)
        end
        local value
        value, i = read_value(s, i, depth)
        if key == nil then
            n = n + 1
            t[n] = value
        else
            t[key] = value
        end
        i = skip(s, i)
        local sep = s:sub(i, i)
        if sep == "," or sep == ";" then i = skip(s, i + 1)
        elseif sep ~= "}" then fail(i, "expected ',' or '}'") end
    end
    return t, i + 1
end

read_value = function(s, i, depth)
    local c = s:sub(i, i)
    if c == "{" then return read_table(s, i, depth + 1) end
    if c == '"' or c == "'" then return read_string(s, i) end
    local word, after = s:match("^([%a_][%w_]*)()", i)
    if word then
        if word == "nil" then return nil, after end
        if LITERALS[word] == nil then fail(i, "unexpected name '" .. word .. "'") end
        return LITERALS[word], after
    end
    return read_number(s, i)
end

-- Returns the table, or nil and a message.
function DefParser.parse(text)
    if type(text) ~= "string" then return nil, "no text" end
    if #text > MAX_LENGTH then return nil, "text is too long" end
    local ok, result = pcall(function()
        local i = skip(text, 1)
        local after = text:match("^return%f[^%w_]()", i)
        if after then i = skip(text, after) end
        if text:sub(i, i) ~= "{" then fail(i, "expected '{'") end
        local t
        t, i = read_table(text, i, 1)
        i = skip(text, i)
        if text:sub(i, i) == ";" then i = skip(text, i + 1) end
        if i <= #text then fail(i, "unexpected text") end
        return t
    end)
    if not ok then return nil, result end
    return result
end

return DefParser
