-- lua/util/json.lua
-- Minimal JSON decoder for Lua 5.1 / LuaJIT (Love2D).
-- Only decodes; no encoder.
-- Usage: local JSON = require("lua/util/json")
--        local t = JSON.decode(str)

local JSON = {}

-- ── helpers ────────────────────────────────────────────────────────────────

local function skip_ws(s, i)
  while i <= #s do
    local c = s:sub(i, i)
    if c == ' ' or c == '\t' or c == '\r' or c == '\n' then
      i = i + 1
    else
      break
    end
  end
  return i
end

local function parse_error(s, i, msg)
  local snippet = s:sub(math.max(1, i - 10), i + 10)
  error(("JSON decode error at pos %d near %q: %s"):format(i, snippet, msg))
end

-- forward declaration
local parse_value

-- ── string ─────────────────────────────────────────────────────────────────

local escape_map = {
  ['"']  = '"',
  ['\\'] = '\\',
  ['/']  = '/',
  ['b']  = '\b',
  ['f']  = '\f',
  ['n']  = '\n',
  ['r']  = '\r',
  ['t']  = '\t',
}

local function parse_string(s, i)
  -- i points to opening '"'
  local result = {}
  i = i + 1  -- skip '"'
  while i <= #s do
    local c = s:sub(i, i)
    if c == '"' then
      return table.concat(result), i + 1
    elseif c == '\\' then
      i = i + 1
      local esc = s:sub(i, i)
      if esc == 'u' then
        -- unicode escape: \uXXXX
        local hex = s:sub(i + 1, i + 4)
        if #hex < 4 then parse_error(s, i, "incomplete \\u escape") end
        local codepoint = tonumber(hex, 16)
        if not codepoint then parse_error(s, i, "invalid \\u hex") end
        -- encode as UTF-8
        if codepoint < 0x80 then
          result[#result + 1] = string.char(codepoint)
        elseif codepoint < 0x800 then
          result[#result + 1] = string.char(
            0xC0 + math.floor(codepoint / 64),
            0x80 + (codepoint % 64))
        else
          result[#result + 1] = string.char(
            0xE0 + math.floor(codepoint / 4096),
            0x80 + math.floor((codepoint % 4096) / 64),
            0x80 + (codepoint % 64))
        end
        i = i + 5
      else
        local mapped = escape_map[esc]
        if not mapped then parse_error(s, i, "unknown escape \\" .. esc) end
        result[#result + 1] = mapped
        i = i + 1
      end
    else
      result[#result + 1] = c
      i = i + 1
    end
  end
  parse_error(s, i, "unterminated string")
end

-- ── number ─────────────────────────────────────────────────────────────────

local function parse_number(s, i)
  local j = i
  -- optional minus
  if s:sub(j, j) == '-' then j = j + 1 end
  -- integer part
  if s:sub(j, j) == '0' then
    j = j + 1
  else
    if not s:sub(j, j):match('%d') then parse_error(s, i, "bad number") end
    while j <= #s and s:sub(j, j):match('%d') do j = j + 1 end
  end
  -- fractional part
  if j <= #s and s:sub(j, j) == '.' then
    j = j + 1
    if not s:sub(j, j):match('%d') then parse_error(s, i, "bad number fraction") end
    while j <= #s and s:sub(j, j):match('%d') do j = j + 1 end
  end
  -- exponent
  if j <= #s and (s:sub(j, j) == 'e' or s:sub(j, j) == 'E') then
    j = j + 1
    if j <= #s and (s:sub(j, j) == '+' or s:sub(j, j) == '-') then j = j + 1 end
    if not s:sub(j, j):match('%d') then parse_error(s, i, "bad number exponent") end
    while j <= #s and s:sub(j, j):match('%d') do j = j + 1 end
  end
  local num_str = s:sub(i, j - 1)
  local n = tonumber(num_str)
  if not n then parse_error(s, i, "cannot convert " .. num_str .. " to number") end
  return n, j
end

-- ── array ──────────────────────────────────────────────────────────────────

local function parse_array(s, i)
  local arr = {}
  i = i + 1  -- skip '['
  i = skip_ws(s, i)
  if s:sub(i, i) == ']' then return arr, i + 1 end
  while true do
    local val
    val, i = parse_value(s, i)
    arr[#arr + 1] = val
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == ']' then return arr, i + 1 end
    if c ~= ',' then parse_error(s, i, "expected ',' or ']'") end
    i = i + 1
    i = skip_ws(s, i)
  end
end

-- ── object ─────────────────────────────────────────────────────────────────

local function parse_object(s, i)
  local obj = {}
  i = i + 1  -- skip '{'
  i = skip_ws(s, i)
  if s:sub(i, i) == '}' then return obj, i + 1 end
  while true do
    i = skip_ws(s, i)
    if s:sub(i, i) ~= '"' then parse_error(s, i, "expected string key") end
    local key
    key, i = parse_string(s, i)
    i = skip_ws(s, i)
    if s:sub(i, i) ~= ':' then parse_error(s, i, "expected ':'") end
    i = i + 1
    i = skip_ws(s, i)
    local val
    val, i = parse_value(s, i)
    obj[key] = val
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == '}' then return obj, i + 1 end
    if c ~= ',' then parse_error(s, i, "expected ',' or '}'") end
    i = i + 1
  end
end

-- ── value dispatcher ───────────────────────────────────────────────────────

parse_value = function(s, i)
  i = skip_ws(s, i)
  if i > #s then parse_error(s, i, "unexpected end of input") end
  local c = s:sub(i, i)
  if c == '"' then
    return parse_string(s, i)
  elseif c == '{' then
    return parse_object(s, i)
  elseif c == '[' then
    return parse_array(s, i)
  elseif c == 't' then
    if s:sub(i, i + 3) == 'true' then return true, i + 4 end
    parse_error(s, i, "invalid literal")
  elseif c == 'f' then
    if s:sub(i, i + 4) == 'false' then return false, i + 5 end
    parse_error(s, i, "invalid literal")
  elseif c == 'n' then
    if s:sub(i, i + 3) == 'null' then return nil, i + 4 end
    parse_error(s, i, "invalid literal")
  elseif c == '-' or c:match('%d') then
    return parse_number(s, i)
  else
    parse_error(s, i, "unexpected character " .. c)
  end
end

-- ── public API ─────────────────────────────────────────────────────────────

function JSON.decode(str)
  if type(str) ~= "string" then
    error("JSON.decode: expected string, got " .. type(str))
  end
  local value, i = parse_value(str, 1)
  i = skip_ws(str, i)
  if i <= #str then
    parse_error(str, i, "trailing data after JSON value")
  end
  return value
end

return JSON
