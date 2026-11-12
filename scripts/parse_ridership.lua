-- parse_ridership.lua
-- Run with: luajit scripts/parse_ridership.lua
-- Reads data/raw/turnstile.csv and data/stations.json
-- Writes data/ridership.json

-- ─── Tomohiko Sakamoto's day-of-week algorithm ───────────────────────────────
-- Returns 0=Sunday, 1=Monday, ..., 6=Saturday
local dow_t = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}
local function day_of_week(y, m, d)
  if m < 3 then y = y - 1 end
  return (y + math.floor(y/4) - math.floor(y/100) + math.floor(y/400) + dow_t[m] + d) % 7
end
-- Convert to task format: 1=Monday ... 7=Sunday
local function task_dow(y, m, d)
  local w = day_of_week(y, m, d)
  if w == 0 then return 7 end  -- Sunday
  return w                      -- Mon=1 .. Sat=6
end

-- ─── Parse ISO timestamp to (dow, hour) ─────────────────────────────────────
-- Format: "2024-03-15T08:00:00.000"
-- Positions (1-indexed): year=1-4, month=6-7, day=9-10, hour=12-13
local function parse_timestamp(ts)
  local y = tonumber(ts:sub(1, 4))
  local m = tonumber(ts:sub(6, 7))
  local d = tonumber(ts:sub(9, 10))
  local h = tonumber(ts:sub(12, 13))
  if not (y and m and d and h) then return nil, nil end
  return task_dow(y, m, d), h
end

-- ─── Minimal JSON serialiser ─────────────────────────────────────────────────
local function json_str(s)
  s = tostring(s)
  s = s:gsub('\\', '\\\\')
  s = s:gsub('"',  '\\"')
  s = s:gsub('\n', '\\n')
  s = s:gsub('\r', '\\r')
  s = s:gsub('\t', '\\t')
  return '"' .. s .. '"'
end

-- ─── Load stations.json ───────────────────────────────────────────────────────
print("[1/3] Loading data/stations.json ...")
local sf = io.open("data/stations.json", "r")
if not sf then error("Cannot open data/stations.json") end
local stations_raw = sf:read("*a")
sf:close()

-- Parse station IDs from JSON using pattern matching
-- Only collect stations whose id is purely numeric (IRT lines),
-- since those directly correspond to turnstile station_complex_id values.
-- The alphanumeric GTFS IDs (A02, D22, etc.) cannot be matched to the
-- numeric-only turnstile complex IDs without a name column in the CSV.
local gtfs_numeric_ids = {}   -- complex_id_string -> gtfs_id_string
for id_val in stations_raw:gmatch('"id"%s*:%s*"(%d+)"') do
  gtfs_numeric_ids[id_val] = id_val
end

local n_gtfs = 0
for _ in pairs(gtfs_numeric_ids) do n_gtfs = n_gtfs + 1 end
print(string.format("    Found %d numeric GTFS station IDs for direct matching.", n_gtfs))

-- ─── Accumulator ─────────────────────────────────────────────────────────────
-- buckets[gtfs_id][dow][hour] = {sum, count}
-- dow: "1".."7"  (1=Mon, 7=Sun)
-- hour: "0".."23"
local buckets = {}
for cid, gid in pairs(gtfs_numeric_ids) do
  buckets[gid] = {}
  for dow = 1, 7 do
    buckets[gid][tostring(dow)] = {}
    for h = 0, 23 do
      buckets[gid][tostring(dow)][tostring(h)] = {sum = 0, count = 0}
    end
  end
end

-- ─── Stream turnstile CSV ────────────────────────────────────────────────────
print("[2/3] Streaming data/raw/turnstile.csv ...")
local tf = io.open("data/raw/turnstile.csv", "r")
if not tf then error("Cannot open data/raw/turnstile.csv") end

-- Read and inspect header
local header = tf:read("*l")
-- Expected: "station_complex_id","transit_timestamp","ridership"
-- or possibly with additional columns including a name column
local has_name_col = false
local name_col_idx = nil
local id_col_idx   = nil
local ts_col_idx   = nil
local rid_col_idx  = nil

-- Parse header to find column positions
local col_idx = 0
for col in header:gmatch('"([^"]*)"') do
  col_idx = col_idx + 1
  local lc = col:lower()
  if lc == "station_complex_id" then id_col_idx  = col_idx end
  if lc == "transit_timestamp"  then ts_col_idx  = col_idx end
  if lc == "ridership"          then rid_col_idx = col_idx end
  if lc == "station_complex" or lc == "station_name" then
    has_name_col  = true
    name_col_idx  = col_idx
  end
end

local total_cols = col_idx
print(string.format("    Header: %d columns. Has name column: %s",
  total_cols, tostring(has_name_col)))
print(string.format("    Column indices — id:%s ts:%s rid:%s name:%s",
  tostring(id_col_idx), tostring(ts_col_idx), tostring(rid_col_idx), tostring(name_col_idx)))

if not (id_col_idx and ts_col_idx and rid_col_idx) then
  error("Required columns not found in CSV header: " .. header)
end

-- Fast quoted-CSV row splitter
local function split_quoted_csv(line, ncols)
  local fields = {}
  local i = 1
  local len = #line
  while i <= len and #fields < ncols do
    if line:sub(i, i) == '"' then
      -- quoted field
      local j = i + 1
      local parts = {}
      while j <= len do
        local c = line:sub(j, j)
        if c == '"' then
          if line:sub(j+1, j+1) == '"' then
            parts[#parts+1] = '"'
            j = j + 2
          else
            j = j + 1
            break
          end
        else
          parts[#parts+1] = c
          j = j + 1
        end
      end
      fields[#fields+1] = table.concat(parts)
      if line:sub(j, j) == ',' then j = j + 1 end
      i = j
    else
      local j = line:find(',', i, true)
      if j then
        fields[#fields+1] = line:sub(i, j-1)
        i = j + 1
      else
        fields[#fields+1] = line:sub(i)
        i = len + 1
      end
    end
  end
  while #fields < ncols do fields[#fields+1] = "" end
  return fields
end

local row_count    = 0
local match_count  = 0
local skip_count   = 0

local line = tf:read("*l")
while line do
  row_count = row_count + 1

  if row_count % 500000 == 0 then
    io.write(string.format("    ... %d rows processed (%d matched, %d skipped)\n",
      row_count, match_count, skip_count))
    io.flush()
  end

  local fields = split_quoted_csv(line, total_cols)
  local complex_id = fields[id_col_idx]
  local timestamp  = fields[ts_col_idx]
  local ridership  = tonumber(fields[rid_col_idx])

  if complex_id and timestamp and ridership then
    -- strip hyphen suffix if any (e.g. "619-R31" -> "619")
    local base_id = complex_id:match("^(%d+)")

    local gtfs_id = base_id and gtfs_numeric_ids[base_id]
    if gtfs_id then
      local dow, hour = parse_timestamp(timestamp)
      if dow and hour then
        local bucket = buckets[gtfs_id][tostring(dow)][tostring(hour)]
        bucket.sum   = bucket.sum   + ridership
        bucket.count = bucket.count + 1
        match_count  = match_count  + 1
      else
        skip_count = skip_count + 1
      end
    else
      skip_count = skip_count + 1
    end
  else
    skip_count = skip_count + 1
  end

  line = tf:read("*l")
end
tf:close()

print(string.format("    Done. %d rows total: %d matched, %d skipped.",
  row_count, match_count, skip_count))

-- ─── Compute averages and write output ───────────────────────────────────────
print("[3/3] Writing data/ridership.json ...")

local out = io.open("data/ridership.json", "w")
if not out then error("Cannot write data/ridership.json") end

out:write("{\n")

-- Collect and sort station IDs for deterministic output
local station_ids = {}
for gid in pairs(buckets) do
  station_ids[#station_ids+1] = gid
end
table.sort(station_ids, function(a, b)
  local na, nb = tonumber(a), tonumber(b)
  if na and nb then return na < nb end
  return a < b
end)

local n_stations = #station_ids
for si, gid in ipairs(station_ids) do
  out:write("  " .. json_str(gid) .. ": {\n")

  local dow_keys = {"1","2","3","4","5","6","7"}
  for di, dk in ipairs(dow_keys) do
    out:write("    " .. json_str(dk) .. ": {")
    local hour_parts = {}
    for h = 0, 23 do
      local hk = tostring(h)
      local b  = buckets[gid][dk][hk]
      local avg
      if b.count > 0 then
        avg = b.sum / b.count
        -- round to 4 decimal places
        avg = math.floor(avg * 10000 + 0.5) / 10000
      else
        avg = 0
      end
      hour_parts[#hour_parts+1] = json_str(hk) .. ":" .. string.format("%.4g", avg)
    end
    out:write(table.concat(hour_parts, ","))
    if di < 7 then
      out:write("},\n")
    else
      out:write("}\n")
    end
  end

  if si < n_stations then
    out:write("  },\n")
  else
    out:write("  }\n")
  end
end

out:write("}\n")
out:close()

print(string.format("    Wrote ridership data for %d stations.", n_stations))
print("Done.")
