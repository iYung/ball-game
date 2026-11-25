local Scene   = require("lua/core/scene")
local Grid    = require("lua/game/grid")
local UI      = require("lua/core/ui")
local OpTiles = require("lua/game/op_tiles")

-- Layout constants (matching MatrixScene)
local GRID_X    = 95
local GRID_Y    = 20
local CELL_SIZE = 63
local PALETTE_Y = 660
local HUD_X     = 820
local W         = 1280
local H         = 720

-- One row of 23 buttons, ending at x = 802 (the command buttons start at HUD_X).
local PAL_BTN_W   = 30
local PAL_ERASE_W = 48
local PAL_BTN_H   = 48
local PAL_GAP     = 3
local PAL_LEFT    = 10
local PAL_SEP     = 6      -- extra space at each separator
local BAR_BTN_Y   = PALETTE_Y + 6

local CMD_BTN_W    = 56
local CMD_BTN_H    = 48
local CMD_BTN_STEP = 62

local MAX_PUSHERS = 8   -- ids 1..8, drawn as letters A-H

-- HUD layout constants
local HUD_PAD  = 12
local MAT_CS   = 44   -- matrix cell size in HUD
local SPIN_W   = 20
local SPIN_H   = 20
local OPS_W    = 36
local OPS_H    = 22
local OPS_GAP  = 4

local OP_NAMES = {
    "transpose","scale_row","swap_rows","negate","scalar_mul",
    "add_matrix","sub_matrix","mul_matrix","set_row","add_rows",
    "scale_col","swap_cols","add_cols","set_col",
    "rotate_90","flip_h","flip_v","abs",
}
local OP_LABELS = {
    transpose="T",   scale_row="xR",  swap_rows="<>R", negate="-I",
    scalar_mul="xk", add_matrix="+M", sub_matrix="-M", mul_matrix="xM",
    set_row="=R",    add_rows="+R",   scale_col="xC",  swap_cols="<>C",
    add_cols="+C",   set_col="=C",    rotate_90="R90", flip_h="FLh",
    flip_v="FLv",    abs="|x|",
}

local EDITOR_PALETTE = {
    { id="editor:pal:source",   kind="source",  label="SRC"  },
    { id="editor:pal:sink",     kind="sink",    label="SNK"  },
    { id="editor:pal:gap",      kind="gap",     label="GAP"  },
    { sep=true },
    { id="editor:pal:pusher",   kind="pusher",  label="P"    },
    { sep=true },
    { id="editor:pal:transpose",  kind="op", op="transpose",  label="T"    },
    { id="editor:pal:scale_row",  kind="op", op="scale_row",  label="xR"   },
    { id="editor:pal:swap_rows",  kind="op", op="swap_rows",  label="<>R"  },
    { id="editor:pal:negate",     kind="op", op="negate",     label="-I"   },
    { id="editor:pal:scalar_mul", kind="op", op="scalar_mul", label="xk"   },
    { id="editor:pal:add_matrix", kind="op", op="add_matrix", label="+M"   },
    { id="editor:pal:sub_matrix", kind="op", op="sub_matrix", label="-M"   },
    { id="editor:pal:mul_matrix", kind="op", op="mul_matrix", label="xM"   },
    { id="editor:pal:set_row",    kind="op", op="set_row",    label="=R"   },
    { id="editor:pal:add_rows",   kind="op", op="add_rows",   label="+R"   },
    { id="editor:pal:scale_col",  kind="op", op="scale_col",  label="xC"   },
    { id="editor:pal:swap_cols",  kind="op", op="swap_cols",  label="<>C"  },
    { id="editor:pal:add_cols",   kind="op", op="add_cols",   label="+C"   },
    { id="editor:pal:set_col",    kind="op", op="set_col",    label="=C"   },
    { id="editor:pal:rotate_90",  kind="op", op="rotate_90",  label="R90"  },
    { id="editor:pal:flip_h",     kind="op", op="flip_h",     label="FLh"  },
    { id="editor:pal:flip_v",     kind="op", op="flip_v",     label="FLv"  },
    { id="editor:pal:abs",        kind="op", op="abs",        label="|x|"  },
    { sep=true },
    { id="editor:pal:erase",  kind="erase", label="Erase", w=PAL_ERASE_W },
}

local CMD_BUTTONS = {
    { id="editor:back",  label="Back"  },
    { id="editor:test",  label="Test"  },
    { id="editor:copy",  label="Copy"  },
    { id="editor:paste", label="Paste" },
}

-- Op tiles whose cells do not show the op symbol get a small one on the anchor cell, as
-- {dy, align}: top-left, except scale_col, whose band label is there (bottom centre,
-- between the -/+ marks).
local SYMBOL_SPOTS = {
    scale_row = {2, "left"},
    scale_col = {CELL_SIZE - 18, "center"},
    swap_rows = {2, "left"},
    swap_cols = {2, "left"},
    set_row   = {2, "left"},
    set_col   = {2, "left"},
}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function cell_top_left(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE,
           GRID_Y + (cy - 1) * CELL_SIZE
end

-- Grid coordinates of the cell containing the point (x, y).
local function cell_at(x, y)
    return math.floor((x - GRID_X) / CELL_SIZE) + 1,
           math.floor((y - GRID_Y) / CELL_SIZE) + 1
end

-- Rect of a resize strip. Grow strips lie on the free cells next to the tile, shrink strips
-- inside it; none overlaps another or covers a value cell's -/centre/+ click points.
local function strip_rect(tile, ax, ay, action)
    local left, top = cell_top_left(ax, ay)
    local w, h  = tile.width, tile.height
    local cs    = CELL_SIZE
    local third = cs / 3
    local q     = math.floor(cs / 4)
    if action == "grow_col" then
        return { x = left + w*cs, y = top, w = third, h = h*cs }
    elseif action == "grow_row" then
        return { x = left + third, y = top + h*cs, w = w*cs - third, h = third }
    elseif action == "shrink_col" then
        return { x = left + (w-1)*cs + cs*2/3, y = top, w = third, h = q }
    end
    return { x = left + third, y = top + h*cs - q, w = third, h = q }   -- shrink_row
end

local function fmt_values(values)
    local rows = {}
    for _, row in ipairs(values) do
        local cells = {}
        for _, v in ipairs(row) do cells[#cells+1] = tostring(v) end
        rows[#rows+1] = "{" .. table.concat(cells, ",") .. "}"
    end
    return "{ " .. table.concat(rows, ", ") .. " }"
end

local function deep_copy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = deep_copy(v) end
    return t
end

-- One `locked` entry of a def as a Lua table constructor, with a fixed key order.
local ENTRY_NUMBER_KEYS = { "x", "y", "id", "width", "height", "tile_rows", "tile_cols" }
local function fmt_entry(entry)
    local parts = { string.format('kind="%s"', entry.kind) }
    if entry.op then parts[#parts+1] = string.format('op="%s"', entry.op) end
    for _, k in ipairs(ENTRY_NUMBER_KEYS) do
        if entry[k] then parts[#parts+1] = k .. "=" .. tostring(entry[k]) end
    end
    if entry.params then
        local keys = {}
        for k in pairs(entry.params) do keys[#keys+1] = k end
        table.sort(keys)
        local params = {}
        for _, k in ipairs(keys) do params[#params+1] = k .. "=" .. tostring(entry.params[k]) end
        parts[#parts+1] = "params={" .. table.concat(params, ", ") .. "}"
    end
    if entry.values then parts[#parts+1] = "values=" .. fmt_values(entry.values) end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local function ensure_matrix_values(mat)
    for r = 1, mat.rows do
        if not mat.values[r] then mat.values[r] = {} end
        for c = 1, mat.cols do
            if mat.values[r][c] == nil then mat.values[r][c] = 0 end
        end
        for c = mat.cols + 1, #mat.values[r] do mat.values[r][c] = nil end
    end
    for r = mat.rows + 1, #mat.values do mat.values[r] = nil end
end

local function is_pusher_id(id)
    return type(id) == "number" and id >= 1 and id <= MAX_PUSHERS and id == math.floor(id)
end

-- Lowest pusher id not in the `used` set, or nil when all are taken.
local function free_pusher_id(used)
    for id = 1, MAX_PUSHERS do
        if not used[id] then return id end
    end
    return nil
end

-- Maps each in-bounds pusher entry of an imported def to its id. Valid explicit ids are
-- reserved first (first occurrence wins); the other pushers take the lowest free ids.
-- Entries left without a free id are absent from the result.
local function assign_pusher_ids(entries, grid)
    local pushers = {}
    for _, t in ipairs(entries) do
        if t.kind == "pusher" and grid:in_bounds(t.x, t.y) then pushers[#pushers+1] = t end
    end
    local ids, used = {}, {}
    for _, t in ipairs(pushers) do
        if is_pusher_id(t.id) and not used[t.id] then
            ids[t], used[t.id] = t.id, true
        end
    end
    for _, t in ipairs(pushers) do
        if not ids[t] then
            local id = free_pusher_id(used)
            if id then ids[t], used[id] = id, true end
        end
    end
    return ids
end

-- ── EditorScene ────────────────────────────────────────────────────────────

local EditorScene = setmetatable({}, { __index = Scene })
EditorScene.__index = EditorScene

function EditorScene.new(scene_manager)
    local self = Scene.new(W, H)
    setmetatable(self, EditorScene)
    self._scene_manager  = scene_manager
    self._grid           = Grid.new(10, 10)
    self._name           = "Untitled"
    self._name_focus     = false
    self._input          = { rows=2, cols=2, values={{1,0},{0,1}} }
    self._target         = { rows=2, cols=2, values={{1,0},{0,1}} }
    self._sel            = nil
    self._copy_flash     = 0
    self._paste_error    = nil
    self._paste_error_t  = 0
    self._allowed_ops    = {}
    self._source         = nil
    self._sink           = nil
    self._pal_rects      = {}
    self._hud_els        = {}
    -- stored y positions for section labels (set by _rebuild_hud)
    self._hud_inp_lbl_y  = 70
    self._hud_tgt_lbl_y  = 230
    self._hud_ops_lbl_y  = 390
    self._hud_inp_cell_y = 118
    self._hud_tgt_cell_y = 278
    return self
end

function EditorScene:on_enter()
    self._font_cell  = love.graphics.newFont(14)
    self._font_ui    = love.graphics.newFont(11)
    self._font_title = love.graphics.newFont(16)
    self:_layout_palette()
    self:_rebuild_hud()
end

-- ── Palette layout ─────────────────────────────────────────────────────────

function EditorScene:_layout_palette()
    local rects = {}
    local x = PAL_LEFT

    for _, btn in ipairs(EDITOR_PALETTE) do
        if btn.sep then
            x = x + PAL_SEP
        else
            local w = btn.w or PAL_BTN_W
            rects[#rects+1] = { id=btn.id, btn=btn, x=x, y=BAR_BTN_Y, w=w, h=PAL_BTN_H }
            x = x + w + PAL_GAP
        end
    end

    self._pal_rects = rects
end

-- ── HUD layout ─────────────────────────────────────────────────────────────

-- Appends matrix-section UI elements into `out`.
-- Returns the y just below all cells in this section.
function EditorScene:_add_matrix_section(out, key, cy)
    local hx    = HUD_X + HUD_PAD   -- 832
    local mat   = key == "input" and self._input or self._target
    local spin_y = cy + 22
    local cell_y = cy + 50

    -- Rows spinners: dec at hx+44, inc at hx+68
    local rdec_x, rinc_x = hx + 44, hx + 68
    out[#out+1] = {id="editor:"..key.."_rows_dec", label="-", kind="button",
        rect={x=rdec_x, y=spin_y, w=SPIN_W, h=SPIN_H}, enabled=true}
    out[#out+1] = {id="editor:"..key.."_rows_inc", label="+", kind="button",
        rect={x=rinc_x, y=spin_y, w=SPIN_W, h=SPIN_H}, enabled=true}
    -- Cols spinners: dec at hx+160, inc at hx+184
    local cdec_x, cinc_x = hx + 160, hx + 184
    out[#out+1] = {id="editor:"..key.."_cols_dec", label="-", kind="button",
        rect={x=cdec_x, y=spin_y, w=SPIN_W, h=SPIN_H}, enabled=true}
    out[#out+1] = {id="editor:"..key.."_cols_inc", label="+", kind="button",
        rect={x=cinc_x, y=spin_y, w=SPIN_W, h=SPIN_H}, enabled=true}

    -- Matrix value cells, centred in HUD
    local grid_w = mat.cols * MAT_CS
    local cell_x = HUD_X + math.floor((460 - grid_w) / 2)
    for r = 1, mat.rows do
        for c = 1, mat.cols do
            out[#out+1] = {
                id      = "editor:"..key.."_cell:"..r..","..c,
                label   = tostring(mat.values[r] and mat.values[r][c] or 0),
                kind    = "cell",
                rect    = {x=cell_x+(c-1)*MAT_CS, y=cell_y+(r-1)*MAT_CS, w=MAT_CS, h=MAT_CS},
                enabled = true,
            }
        end
    end

    return cell_y + mat.rows * MAT_CS
end

function EditorScene:_rebuild_hud()
    local hx   = HUD_X + HUD_PAD   -- 832
    local hw   = W - HUD_X - HUD_PAD * 2  -- 436
    local out  = {}
    local cy   = 36

    -- Name field
    out[#out+1] = {id="editor:name",
        label = self._name ~= "" and self._name or " ",
        kind="button", rect={x=hx, y=cy, w=hw, h=24},
        enabled=true, selected=self._name_focus}
    cy = cy + 32   -- 68

    -- INPUT section
    self._hud_inp_lbl_y  = cy
    self._hud_inp_cell_y = cy + 50
    local inp_next = self:_add_matrix_section(out, "input", cy)
    cy = inp_next + 10

    -- TARGET section
    self._hud_tgt_lbl_y  = cy
    self._hud_tgt_cell_y = cy + 50
    local tgt_next = self:_add_matrix_section(out, "target", cy)
    cy = tgt_next + 10

    -- Op allowlist
    self._hud_ops_lbl_y = cy
    local ops_per_row = 8
    for i, op in ipairs(OP_NAMES) do
        local row = math.floor((i - 1) / ops_per_row)
        local col = (i - 1) % ops_per_row
        local ox  = hx + col * (OPS_W + OPS_GAP)
        local oy  = cy + row * (OPS_H + OPS_GAP)
        if oy + OPS_H <= PALETTE_Y - 4 then
            out[#out+1] = {
                id      = "editor:allow:"..op,
                label   = OP_LABELS[op] or op,
                kind    = "button",
                rect    = {x=ox, y=oy, w=OPS_W, h=OPS_H},
                enabled = true,
                selected = self._allowed_ops[op] == true,
            }
        end
    end

    self._hud_els = out
end

-- ── UI registry ────────────────────────────────────────────────────────────

-- Read-only tile query used by assert_tile in UI specs.
function EditorScene:ui_tile(x, y)
    if not self._grid:in_bounds(x, y) then return nil end
    local tile = self._grid:get(x, y)
    if tile == nil then return nil end
    return { kind = tile.kind, op = tile.op }
end

function EditorScene:_sel_matches(btn)
    if not self._sel       then return false end
    if btn.kind == "op"    then return self._sel.kind == "op" and self._sel.op == btn.op end
    if btn.kind == "erase" then return self._sel.kind == "erase" end
    return self._sel.kind == btn.kind
end

-- True when the tile anchored at (ax, ay) has room for a resize action.
function EditorScene:_can_resize(tile, ax, ay, action)
    local w, h = tile.width, tile.height
    if action == "grow_col" and not self:_area_free(ax + w, ay, 1, h) then return false end
    if action == "grow_row" and not self:_area_free(ax, ay + h, w, 1) then return false end

    -- An imported width/height may differ from the footprint a resize gives the tile, so
    -- check every cell the resized tile would newly cover, whatever the action.
    local resized = deep_copy(tile)
    OpTiles.resize(resized, action)
    for dy = 0, resized.height - 1 do
        for dx = 0, resized.width - 1 do
            if (dx >= w or dy >= h) and not self:_area_free(ax + dx, ay + dy, 1, 1) then
                return false
            end
        end
    end
    return true
end

-- Appends the resize strips of every op tile (none while Erase is selected).
function EditorScene:_add_resize_strips(els)
    if self._sel and self._sel.kind == "erase" then return end
    for cy = 1, 10 do
        for cx = 1, 10 do
            local tile = self._grid.cells[cy][cx]
            if tile and tile.kind == "op" then
                for _, action in ipairs(OpTiles.resize_actions(tile)) do
                    if self:_can_resize(tile, cx, cy, action) then
                        els[#els+1] = {
                            id      = "resize:" .. cx .. "," .. cy .. ":" .. action,
                            label   = action:find("^grow") and "+" or "-",
                            kind    = "resize",
                            rect    = strip_rect(tile, cx, cy, action),
                            enabled = true,
                        }
                    end
                end
            end
        end
    end
end

function EditorScene:ui_elements()
    local els = {}

    -- Listed before the grid cells so hit-testing finds a strip first.
    self:_add_resize_strips(els)

    -- Grid cells (10×10), registered so click_cell / assert_tile work in specs.
    for cy = 1, 10 do
        for cx = 1, 10 do
            local id = "cell:" .. cx .. "," .. cy
            els[#els+1] = {
                id      = id,
                label   = id,
                kind    = "cell",
                rect    = { x = GRID_X + (cx-1)*CELL_SIZE,
                             y = GRID_Y + (cy-1)*CELL_SIZE,
                             w = CELL_SIZE, h = CELL_SIZE },
                enabled = true,
            }
        end
    end

    for _, r in ipairs(self._pal_rects) do
        els[#els+1] = {
            id=r.id, label=r.btn.label, kind="button",
            rect={x=r.x, y=r.y, w=r.w, h=r.h},
            enabled=true, selected=self:_sel_matches(r.btn),
        }
    end

    for i, cmd in ipairs(CMD_BUTTONS) do
        els[#els+1] = {
            id=cmd.id, label=cmd.label, kind="button",
            rect={x=HUD_X+(i-1)*CMD_BTN_STEP, y=BAR_BTN_Y, w=CMD_BTN_W, h=CMD_BTN_H},
            enabled=true,
        }
    end

    for _, e in ipairs(self._hud_els) do
        els[#els+1] = e
    end

    return els
end

-- ── Grid mutation ──────────────────────────────────────────────────────────

-- Set of pusher ids currently on the grid.
function EditorScene:_used_pusher_ids()
    local used = {}
    for cy = 1, 10 do
        for cx = 1, 10 do
            local tile = self._grid.cells[cy][cx]
            if tile and tile.kind == "pusher" then used[tile.id] = true end
        end
    end
    return used
end

function EditorScene:_erase_at(cx, cy)
    if not self._grid:in_bounds(cx, cy) then return end
    local raw = self._grid.cells[cy][cx]
    if raw == nil then return end

    local ax, ay
    if raw.ref then ax, ay = raw.ax, raw.ay
    else            ax, ay = cx, cy end

    local tile = self._grid.cells[ay][ax]
    if tile == nil then return end

    if tile.kind == "source" then self._source = nil end
    if tile.kind == "sink"   then self._sink   = nil end

    local tw = tile.width  or 1
    local th = tile.height or 1
    for dy = 0, th - 1 do
        for dx = 0, tw - 1 do
            if self._grid:in_bounds(ax+dx, ay+dy) then
                self._grid.cells[ay+dy][ax+dx] = nil
            end
        end
    end
end

-- Applies a resize strip's action and re-places the tile with its new footprint.
function EditorScene:_resize_at(ax, ay, action)
    local tile = self._grid:get(ax, ay)
    self:_erase_at(ax, ay)
    OpTiles.resize(tile, action)
    self._grid:set_multi_2d(ax, ay, tile, tile.width, tile.height)
end

-- Left click on a grid cell (rel_x pixels from its left edge). Erase removes the tile
-- under the cursor. Otherwise a placed tile is never replaced (an op's param or value cell
-- is edited, whatever `locked` says) and an empty cell takes the selected tool.
function EditorScene:_click_cell(cx, cy, rel_x)
    if self._sel and self._sel.kind == "erase" then self:_erase_at(cx, cy); return end

    if self._grid.cells[cy][cx] == nil then
        if self._sel then self:_place_at(cx, cy) end
        return
    end

    local ax, ay = self._grid:get_anchor(cx, cy)
    local tile   = self._grid:get(ax, ay)
    if tile.kind == "op" then
        local rows = self._input.rows
        OpTiles.click(tile, cx - ax, cy - ay, rel_x, CELL_SIZE,
            { rows = rows, cols = self._input.cols, set_row = rows })
    end
end

-- True when the w x h area anchored at (x, y) is in bounds and empty.
function EditorScene:_area_free(x, y, w, h)
    if not self._grid:in_bounds_multi_2d(x, y, w, h) then return false end
    for dy = 0, h-1 do
        for dx = 0, w-1 do
            if self._grid.cells[y+dy][x+dx] then return false end
        end
    end
    return true
end

-- Places the selected tool on the empty cell (cx, cy).
function EditorScene:_place_at(cx, cy)
    local sel = self._sel

    if sel.kind == "source" then
        if self._source then self:_erase_at(self._source.x, self._source.y) end
        self._source = nil
        local sc, sr = self._input.cols, self._input.rows
        if not self._grid:in_bounds_multi_2d(cx, cy, sc, sr) then return end
        for dy = 0, sr-1 do
            for dx = 0, sc-1 do
                if self._grid.cells[cy+dy] and self._grid.cells[cy+dy][cx+dx] then return end
            end
        end
        self._grid:set_multi_2d(cx, cy, {kind="source", locked=true, width=sc, height=sr}, sc, sr)
        self._source = {x=cx, y=cy}
        return
    end

    if sel.kind == "sink" then
        if self._sink then self._grid.cells[self._sink.y][self._sink.x] = nil end
        self._grid:set(cx, cy, {kind="sink", locked=true})
        self._sink = {x=cx, y=cy}; return
    end

    if sel.kind == "gap" then
        self._grid:set(cx, cy, {kind="gap", locked=true}); return
    end

    if sel.kind == "op" then
        local tile   = OpTiles.new_tile(sel.op, self._input.rows)
        local tw, th = tile.width, tile.height
        if not self:_area_free(cx, cy, tw, th) then return end
        self._grid:set_multi_2d(cx, cy, tile, tw, th)
        return
    end

    if sel.kind == "pusher" then
        local id = free_pusher_id(self:_used_pusher_ids())
        if not id then return end
        self._grid:set(cx, cy, {kind="pusher", locked=true, id=id})
    end
end

-- ── Matrix helpers ─────────────────────────────────────────────────────────

-- Re-places the source tile at its current position with the current input dimensions.
-- Called whenever input rows/cols change so the source footprint stays in sync.
function EditorScene:_refit_source()
    if not self._source then return end
    local sx, sy = self._source.x, self._source.y
    self:_erase_at(sx, sy)   -- also sets self._source = nil
    local sc, sr = self._input.cols, self._input.rows
    if not self._grid:in_bounds_multi_2d(sx, sy, sc, sr) then return end
    for dy = 0, sr-1 do
        for dx = 0, sc-1 do
            if self._grid.cells[sy+dy] and self._grid.cells[sy+dy][sx+dx] then return end
        end
    end
    self._grid:set_multi_2d(sx, sy, {kind="source", locked=true, width=sc, height=sr}, sc, sr)
    self._source = {x=sx, y=sy}
end

function EditorScene:_adjust_matrix(mat, new_rows, new_cols)
    mat.rows = math.max(1, math.min(4, new_rows))
    mat.cols = math.max(1, math.min(4, new_cols))
    ensure_matrix_values(mat)
end

function EditorScene:_cell_click(mat, r, c, mx, rect_x)
    local v = mat.values[r][c] or 0
    if mx < rect_x + MAT_CS / 3 then v = v - 1
    else                              v = v + 1 end
    mat.values[r][c] = math.max(-9, math.min(9, v))
end

-- ── Input ──────────────────────────────────────────────────────────────────

function EditorScene:key_pressed(key)
    if self._name_focus then
        if key == "backspace" then
            self._name = self._name:sub(1, -2)
        elseif key == "return" or key == "escape" then
            self._name_focus = false
        end
        return
    end
    if key == "escape" then
        local StartScene = require("lua/game/scenes/start_scene")
        self._scene_manager:switch(StartScene.new(self._scene_manager))
    end
end

function EditorScene:text_input(ch)
    if self._name_focus then
        self._name = self._name .. ch
    end
end

function EditorScene:mouse_pressed(mx, my, btn)
    local e = UI.element_at(self:ui_elements(), mx, my)
    if e then
        -- Resize strips: left click resizes; right click erases what lies underneath.
        if e.kind == "resize" then
            if btn == 1 then
                local ax, ay, action = e.id:match("^resize:(%d+),(%d+):(.+)$")
                self:_resize_at(tonumber(ax), tonumber(ay), action)
            elseif btn == 2 then
                self:_erase_at(cell_at(mx, my))
            end
            return
        end

        -- Grid cell elements: route to place/erase.
        local cell_x, cell_y = e.id:match("^cell:(%d+),(%d+)$")
        if cell_x then
            local cx, cy = tonumber(cell_x), tonumber(cell_y)
            if btn == 1 then
                self:_click_cell(cx, cy, mx - e.rect.x)
            elseif btn == 2 then
                self:_erase_at(cx, cy)
            end
            return
        end

        if btn == 1 then
            if e.id == "editor:back" then
                local StartScene = require("lua/game/scenes/start_scene")
                self._scene_manager:switch(StartScene.new(self._scene_manager))
            elseif e.id == "editor:name" then
                self._name_focus = true
            elseif e.id == "editor:copy" then
                love.system.setClipboardText(self:_serialize())
                self._copy_flash = 2.0
            elseif e.id == "editor:paste" then
                        local text = love.system.getClipboardText()
                        local ok, def = pcall(function() return load(text or "")() end)
                        if ok and type(def) == "table" and def.input and def.target then
                            self:_load_def(def)
                        else
                            self._paste_error   = "Parse error"
                            self._paste_error_t = 2.0
                        end
                    elseif e.id == "editor:test" then
                        local def = self:_build_def()
                        local ms  = require("lua/game/scenes/matrix_scene")
                        self._scene_manager:switch(ms.new_from_def(def, self._scene_manager, self))
            elseif e.id == "editor:input_rows_dec" then
                self:_adjust_matrix(self._input, self._input.rows-1, self._input.cols)
                self:_refit_source()
            elseif e.id == "editor:input_rows_inc" then
                self:_adjust_matrix(self._input, self._input.rows+1, self._input.cols)
                self:_refit_source()
            elseif e.id == "editor:input_cols_dec" then
                self:_adjust_matrix(self._input, self._input.rows, self._input.cols-1)
                self:_refit_source()
            elseif e.id == "editor:input_cols_inc" then
                self:_adjust_matrix(self._input, self._input.rows, self._input.cols+1)
                self:_refit_source()
            elseif e.id == "editor:target_rows_dec" then
                self:_adjust_matrix(self._target, self._target.rows-1, self._target.cols)
            elseif e.id == "editor:target_rows_inc" then
                self:_adjust_matrix(self._target, self._target.rows+1, self._target.cols)
            elseif e.id == "editor:target_cols_dec" then
                self:_adjust_matrix(self._target, self._target.rows, self._target.cols-1)
            elseif e.id == "editor:target_cols_inc" then
                self:_adjust_matrix(self._target, self._target.rows, self._target.cols+1)
            else
                local ir, ic = e.id:match("^editor:input_cell:(%d+),(%d+)$")
                if ir then
                    self:_cell_click(self._input, tonumber(ir), tonumber(ic), mx, e.rect.x)
                    return
                end
                local tr, tc = e.id:match("^editor:target_cell:(%d+),(%d+)$")
                if tr then
                    self:_cell_click(self._target, tonumber(tr), tonumber(tc), mx, e.rect.x)
                    return
                end
                local op = e.id:match("^editor:allow:(.+)$")
                if op then
                    if self._allowed_ops[op] then self._allowed_ops[op] = nil
                    else                          self._allowed_ops[op] = true end
                    return
                end
                for _, pal_btn in ipairs(EDITOR_PALETTE) do
                    if pal_btn.id == e.id then
                        if     pal_btn.kind == "erase" then self._sel = {kind="erase"}
                        elseif pal_btn.kind == "op"    then self._sel = {kind="op", op=pal_btn.op}
                        elseif pal_btn.kind then
                            self._sel = {kind=pal_btn.kind}
                        end
                        break
                    end
                end
            end
        end
        return
    end
end

-- ── Update ─────────────────────────────────────────────────────────────────

function EditorScene:update(dt)
    if self._copy_flash > 0 then
        self._copy_flash = math.max(0, self._copy_flash - dt)
    end
    if self._paste_error_t > 0 then
        self._paste_error_t = math.max(0, self._paste_error_t - dt)
        if self._paste_error_t == 0 then self._paste_error = nil end
    end
end

-- ── Build / Load def ──────────────────────────────────────────────────────

function EditorScene:_build_def()
    local src = self._source or {x=1, y=1}
    local snk = self._sink   or {x=10, y=10}

    local gaps = {}
    for cy = 1, 10 do
        for cx = 1, 10 do
            local tile = self._grid.cells[cy][cx]
            if tile and tile.kind == "gap" then
                gaps[#gaps+1] = {x=cx, y=cy}
            end
        end
    end

    local locked = {}
    for cy = 1, 10 do
        for cx = 1, 10 do
            if not self._grid:is_ref(cx, cy) then
                local tile = self._grid.cells[cy][cx]
                if tile and tile.locked
                   and tile.kind ~= "source" and tile.kind ~= "sink" and tile.kind ~= "gap" then
                    local entry = { kind=tile.kind, x=cx, y=cy }
                    if tile.op     then entry.op      = tile.op end
                    if tile.kind == "pusher" then entry.id = tile.id end
                    if tile.params and next(tile.params) then
                        entry.params = deep_copy(tile.params)
                    end
                    if tile.tile_rows then entry.tile_rows = tile.tile_rows end
                    if tile.tile_cols then entry.tile_cols = tile.tile_cols end
                    if tile.values then entry.values = deep_copy(tile.values) end
                    if tile.width  and tile.width  > 1 then entry.width  = tile.width  end
                    if tile.height and tile.height > 1 then entry.height = tile.height end
                    locked[#locked+1] = entry
                end
            end
        end
    end

    local enabled_ops = {}
    for _, op in ipairs(OP_NAMES) do
        if self._allowed_ops[op] then enabled_ops[#enabled_ops+1] = op end
    end

    local def = {
        name   = self._name ~= "" and self._name or "Untitled",
        grid_w = 10, grid_h = 10,
        source = { x=src.x, y=src.y },
        sink   = { x=snk.x, y=snk.y },
        input  = { rows=self._input.rows,  cols=self._input.cols,
                   values=deep_copy(self._input.values) },
        target = { rows=self._target.rows, cols=self._target.cols,
                   values=deep_copy(self._target.values) },
    }
    if #gaps   > 0 then def.gaps   = gaps   end
    if #locked > 0 then def.locked = locked end
    if #enabled_ops > 0 and #enabled_ops < #OP_NAMES then def.ops = enabled_ops end
    return def
end

function EditorScene:_load_def(def)
    self._name        = def.name or "Untitled"
    self._name_focus  = false
    self._grid        = Grid.new(10, 10)
    self._source      = nil
    self._sink        = nil
    self._allowed_ops = {}
    self._copy_flash  = 0
    self._paste_error = nil
    self._paste_error_t = 0

    -- Input / target matrices
    self._input  = { rows=def.input.rows,  cols=def.input.cols,
                     values=deep_copy(def.input.values) }
    self._target = { rows=def.target.rows, cols=def.target.cols,
                     values=deep_copy(def.target.values) }
    ensure_matrix_values(self._input)
    ensure_matrix_values(self._target)

    -- No tile is placed over another (or off the grid). Locked tiles go first: without a
    -- placed source or sink the def carries a default position that a tile may occupy.

    -- Locked tiles
    local pusher_ids = assign_pusher_ids(def.locked or {}, self._grid)
    for _, t in ipairs(def.locked or {}) do
        local tile
        if t.kind == "op" then
            tile = OpTiles.tile_from_def(t)
        else
            tile = {
                kind      = t.kind,
                op        = t.op,
                id        = pusher_ids[t],
                locked    = true,
                params    = deep_copy(t.params or {}),
                width     = t.width  or 1,
                height    = t.height or 1,
                tile_rows = t.tile_rows,
                tile_cols = t.tile_cols,
            }
        end
        local tw, th = tile.width, tile.height
        if self:_area_free(t.x, t.y, tw, th)
           and (t.kind ~= "pusher" or pusher_ids[t]) then
            self._grid:set_multi_2d(t.x, t.y, tile, tw, th)
        end
    end

    -- Source
    if def.source then
        local sx, sy = def.source.x, def.source.y
        local sc, sr = def.input.cols, def.input.rows
        if self:_area_free(sx, sy, sc, sr) then
            self._grid:set_multi_2d(sx, sy, {kind="source", locked=true, width=sc, height=sr}, sc, sr)
            self._source = {x=sx, y=sy}
        end
    end

    -- Sink
    if def.sink then
        local sx, sy = def.sink.x, def.sink.y
        if self:_area_free(sx, sy, 1, 1) then
            self._grid:set(sx, sy, {kind="sink", locked=true})
            self._sink = {x=sx, y=sy}
        end
    end

    -- Gaps
    for _, g in ipairs(def.gaps or {}) do
        if self:_area_free(g.x, g.y, 1, 1) then
            self._grid:set(g.x, g.y, {kind="gap", locked=true})
        end
    end

    -- Op allowlist
    for _, op in ipairs(def.ops or {}) do
        self._allowed_ops[op] = true
    end
end

-- ── Serialization ─────────────────────────────────────────────────────────

-- The clipboard text of the table that Test plays: _build_def() is the only source.
function EditorScene:_serialize()
    local def = self:_build_def()
    local lines = {"return {"}

    lines[#lines+1] = string.format('    name   = %q,', def.name)
    lines[#lines+1] = string.format("    grid_w = %d, grid_h = %d,", def.grid_w, def.grid_h)
    lines[#lines+1] = string.format("    source = { x=%d, y=%d },", def.source.x, def.source.y)
    lines[#lines+1] = string.format("    sink   = { x=%d, y=%d },", def.sink.x, def.sink.y)

    -- ops (present only when a subset is selected)
    if def.ops then
        local parts = {}
        for _, op in ipairs(def.ops) do parts[#parts+1] = '"' .. op .. '"' end
        lines[#lines+1] = "    ops    = { " .. table.concat(parts, ", ") .. " },"
    end

    if def.locked then
        lines[#lines+1] = "    locked = {"
        for _, entry in ipairs(def.locked) do
            lines[#lines+1] = "        " .. fmt_entry(entry) .. ","
        end
        lines[#lines+1] = "    },"
    end

    if def.gaps then
        local parts = {}
        for _, g in ipairs(def.gaps) do parts[#parts+1] = string.format("{x=%d,y=%d}", g.x, g.y) end
        lines[#lines+1] = "    gaps   = {"
        lines[#lines+1] = "        " .. table.concat(parts, ",") .. ","
        lines[#lines+1] = "    },"
    end

    -- input / target
    for _, key in ipairs({"input", "target"}) do
        local mat = def[key]
        lines[#lines+1] = string.format("    %-6s = { rows=%d, cols=%d, values=%s },",
            key, mat.rows, mat.cols, fmt_values(mat.values))
    end

    lines[#lines+1] = "}"
    return table.concat(lines, "\n")
end

-- ── Draw helpers ───────────────────────────────────────────────────────────

local function draw_op_content(tile, sx, sy, fonts)
    for dy = 0, (tile.height or 1) - 1 do
        for dx = 0, (tile.width or 1) - 1 do
            OpTiles.draw_cell(tile, dx, dy, sx + dx * CELL_SIZE, sy + dy * CELL_SIZE,
                CELL_SIZE, fonts, true)
        end
    end
    OpTiles.draw_overlay(tile, sx, sy, CELL_SIZE, fonts)

    local spot = SYMBOL_SPOTS[tile.op]
    if spot then
        local dy, align = spot[1], spot[2]
        love.graphics.setColor(0.56, 0.44, 0.21, 1)
        love.graphics.setFont(fonts.ui)
        love.graphics.printf(OpTiles.SYMBOLS[tile.op],
            align == "left" and sx + 2 or sx, sy + dy, CELL_SIZE, align)
    end
end

local function draw_tile(tile, cx, cy, font_cell, font_ui)
    if not tile then return end
    local sx, sy = cell_top_left(cx, cy)
    local cs     = CELL_SIZE
    local tw     = tile.width  or 1
    local th     = tile.height or 1
    local span_w = tw * cs
    local span_h = th * cs

    if tile.kind == "source" then
        love.graphics.setColor(0.09, 0.29, 0.17, 1)
        love.graphics.rectangle("fill", sx, sy, span_w, span_h)
        love.graphics.setColor(0.4, 1.0, 0.5, 1)
        love.graphics.setFont(font_cell)
        love.graphics.printf("SRC", sx, sy + span_h/2 - 7, span_w, "center")
    elseif tile.kind == "sink" then
        love.graphics.setColor(0.09, 0.19, 0.42, 1)
        love.graphics.rectangle("fill", sx, sy, cs, cs)
        love.graphics.setColor(0.5, 0.75, 1.0, 1)
        love.graphics.setFont(font_cell)
        love.graphics.printf("SINK", sx, sy + cs/2 - 7, cs, "center")
    elseif tile.kind == "gap" then
        love.graphics.setColor(0.5, 0.15, 0.15, 1)
        love.graphics.setFont(font_cell)
        love.graphics.printf("×", sx, sy + cs/2 - 8, cs, "center")
    elseif tile.kind == "op" then
        love.graphics.setColor(0.21, 0.14, 0.04, 1)
        love.graphics.rectangle("fill", sx, sy, span_w, span_h)
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx+1, sy+1, span_w-2, span_h-2)
        love.graphics.setLineWidth(1)
        draw_op_content(tile, sx, sy, { cell = font_cell, ui = font_ui })
    elseif tile.kind == "pusher" then
        love.graphics.setColor(0.30, 0.18, 0.45, 1)
        love.graphics.rectangle("fill", sx+4, sy+4, cs-8, cs-8, 6, 6)
        love.graphics.setColor(0.80, 0.60, 1.0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx+4, sy+4, cs-8, cs-8, 6, 6)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(font_cell)
        love.graphics.printf(string.char(64 + (tile.id or 1)), sx, sy+cs/2-8, cs, "center")
        if tile.locked then
            love.graphics.setColor(0.50, 0.50, 0.50, 1)
            love.graphics.circle("fill", sx+cs-8, sy+7, 3)
            love.graphics.rectangle("fill", sx+cs-10, sy+7, 4, 5)
        end
    end
end

-- A resize strip: green "+" to grow, red "-" to shrink, as in the puzzle scene.
local function draw_strip(e)
    local r    = e.rect
    local grow = e.label == "+"
    love.graphics.setColor(grow and {0.23,0.44,0.23,1} or {0.44,0.15,0.15,1})
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    love.graphics.setColor(grow and {0.5,1.0,0.5,1} or {1.0,0.4,0.4,1})
    love.graphics.printf(e.label, r.x, r.y + r.h/2 - 7, r.w, "center")
end

function EditorScene:_draw_hud()
    local hx = HUD_X + HUD_PAD
    local fu = self._font_ui
    local fc = self._font_cell

    for _, e in ipairs(self._hud_els) do
        local r = e.rect
        if e.id == "editor:name" then
            love.graphics.setColor(e.selected and {0.14,0.14,0.24,1} or {0.10,0.10,0.18,1})
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
            love.graphics.setColor(e.selected and {0.6,0.8,1.0,1} or {0.3,0.3,0.5,1})
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 3, 3)
            love.graphics.setFont(fu)
            love.graphics.setColor(0.85, 0.85, 0.95, 1)
            local disp = self._name ~= "" and self._name or "(name)"
            if self._name_focus then disp = disp .. "|" end
            love.graphics.printf(disp, r.x+4, r.y+6, r.w-8, "left")

        elseif e.id:find("_rows_dec$") or e.id:find("_rows_inc$") or
               e.id:find("_cols_dec$") or e.id:find("_cols_inc$") then
            love.graphics.setColor(0.12, 0.12, 0.22, 1)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 2, 2)
            love.graphics.setColor(0.4, 0.4, 0.65, 1)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 2, 2)
            love.graphics.setFont(fu)
            love.graphics.setColor(0.85, 0.85, 0.95, 1)
            love.graphics.printf(e.label, r.x, r.y+3, r.w, "center")

        elseif e.kind == "cell" then
            love.graphics.setColor(0.10, 0.10, 0.18, 1)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
            love.graphics.setColor(0.3, 0.3, 0.5, 1)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
            love.graphics.setFont(fc)
            love.graphics.setColor(0.9, 0.9, 1.0, 1)
            love.graphics.printf(e.label, r.x, r.y+r.h/2-9, r.w, "center")
            love.graphics.setColor(0.28, 0.28, 0.43, 1)
            love.graphics.setFont(fu)
            love.graphics.printf("-", r.x, r.y+r.h-14, r.w/3, "center")
            love.graphics.printf("+", r.x+r.w*2/3, r.y+r.h-14, r.w/3, "center")

        elseif e.id:find("^editor:allow:") then
            love.graphics.setColor(e.selected and {0.20,0.30,0.50,1} or {0.10,0.10,0.18,1})
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 2, 2)
            love.graphics.setColor(e.selected and {0.5,0.75,1.0,1} or {0.22,0.22,0.36,1})
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 2, 2)
            love.graphics.setFont(fu)
            love.graphics.setColor(e.selected and {0.9,0.95,1.0,1} or {0.5,0.5,0.6,1})
            love.graphics.printf(e.label, r.x, r.y+r.h/2-6, r.w, "center")
        end
    end

    -- Section labels (text only, not UI elements)
    love.graphics.setFont(fu)
    -- INPUT / TARGET labels
    love.graphics.setColor(0.60, 0.75, 1.0, 1)
    love.graphics.printf("INPUT",  HUD_X, self._hud_inp_lbl_y+4, W-HUD_X, "center")
    love.graphics.printf("TARGET", HUD_X, self._hud_tgt_lbl_y+4, W-HUD_X, "center")
    -- Spinner labels
    local spin_off = 22 + 4  -- spin_y offset within section + small nudge
    love.graphics.setColor(0.5, 0.5, 0.65, 1)
    love.graphics.printf("rows:", hx, self._hud_inp_lbl_y+spin_off, 42, "right")
    love.graphics.printf("cols:", hx+118, self._hud_inp_lbl_y+spin_off, 40, "right")
    love.graphics.printf("rows:", hx, self._hud_tgt_lbl_y+spin_off, 42, "right")
    love.graphics.printf("cols:", hx+118, self._hud_tgt_lbl_y+spin_off, 40, "right")
    -- Spinner values
    love.graphics.setColor(0.9, 0.9, 1.0, 1)
    love.graphics.printf(tostring(self._input.rows),  hx+90,  self._hud_inp_lbl_y+spin_off, 20, "center")
    love.graphics.printf(tostring(self._input.cols),  hx+206, self._hud_inp_lbl_y+spin_off, 20, "center")
    love.graphics.printf(tostring(self._target.rows), hx+90,  self._hud_tgt_lbl_y+spin_off, 20, "center")
    love.graphics.printf(tostring(self._target.cols), hx+206, self._hud_tgt_lbl_y+spin_off, 20, "center")
    -- OPS label
    love.graphics.setColor(0.60, 0.75, 1.0, 1)
    love.graphics.printf("OPS:", hx, self._hud_ops_lbl_y - 2, 50, "left")
    -- Dividers
    love.graphics.setColor(0.2, 0.2, 0.3, 1)
    local d1 = self._hud_inp_cell_y + self._input.rows * MAT_CS + 4
    love.graphics.rectangle("fill", HUD_X+20, d1, W-HUD_X-40, 1)
    local d2 = self._hud_tgt_cell_y + self._target.rows * MAT_CS + 4
    love.graphics.rectangle("fill", HUD_X+20, d2, W-HUD_X-40, 1)
end

function EditorScene:draw()
    self:_rebuild_hud()

    -- Background
    love.graphics.setColor(0.06, 0.06, 0.10, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Grid area
    love.graphics.setColor(0.08, 0.08, 0.13, 1)
    love.graphics.rectangle("fill", 0, 0, HUD_X, PALETTE_Y)

    -- Checkerboard + grid lines
    for cy = 1, 10 do
        for cx = 1, 10 do
            local sx, sy = cell_top_left(cx, cy)
            if (cx + cy) % 2 == 0 then love.graphics.setColor(0.10, 0.10, 0.15, 1)
            else                        love.graphics.setColor(0.11, 0.11, 0.17, 1) end
            love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
            love.graphics.setColor(0.20, 0.20, 0.30, 1)
            love.graphics.rectangle("line", sx, sy, CELL_SIZE, CELL_SIZE)
        end
    end

    -- Tiles
    for cy = 1, 10 do
        for cx = 1, 10 do
            if not self._grid:is_ref(cx, cy) then
                local tile = self._grid:get(cx, cy)
                if tile then draw_tile(tile, cx, cy, self._font_cell, self._font_ui) end
            end
        end
    end

    -- Resize strips, over the tiles
    love.graphics.setFont(self._font_ui)
    for _, e in ipairs(self:ui_elements()) do
        if e.kind == "resize" then draw_strip(e) end
    end

    -- HUD background
    love.graphics.setColor(0.07, 0.07, 0.12, 1)
    love.graphics.rectangle("fill", HUD_X, 0, W-HUD_X, PALETTE_Y)

    -- HUD title
    love.graphics.setFont(self._font_title)
    love.graphics.setColor(0.85, 0.85, 0.95, 1)
    love.graphics.printf("PUZZLE EDITOR", HUD_X, 12, W-HUD_X, "center")

    self:_draw_hud()

    -- Palette bar
    love.graphics.setColor(0.06, 0.06, 0.10, 1)
    love.graphics.rectangle("fill", 0, PALETTE_Y, W, H-PALETTE_Y)

    -- Palette + cmd buttons (y >= PALETTE_Y only)
    for _, e in ipairs(self:ui_elements()) do
        if e.rect.y >= PALETTE_Y then
            local r = e.rect
            love.graphics.setColor(0.12, 0.12, 0.20, 1)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
            love.graphics.setColor(e.selected and {0.8,0.9,1.0,1} or {0.3,0.3,0.45,1})
            love.graphics.setLineWidth(e.selected and 2 or 1)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4, 4)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.85, 0.85, 0.9, 1)
            love.graphics.setFont(self._font_ui)
            love.graphics.printf(e.label, r.x, r.y+17, r.w, "center")
        end
    end

    -- Flash messages
    if self._copy_flash > 0 then
        love.graphics.setColor(0.4, 1.0, 0.5, math.min(1, self._copy_flash * 2))
        love.graphics.setFont(self._font_title)
        love.graphics.printf("Copied!", HUD_X, PALETTE_Y-30, W-HUD_X, "center")
    end
    if self._paste_error and self._paste_error_t > 0 then
        love.graphics.setColor(1.0, 0.4, 0.4, math.min(1, self._paste_error_t * 2))
        love.graphics.setFont(self._font_title)
        love.graphics.printf(self._paste_error, HUD_X, PALETTE_Y-30, W-HUD_X, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return EditorScene
