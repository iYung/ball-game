local Scene      = require("lua/core/scene")
local Grid       = require("lua/game/grid")
local UI         = require("lua/core/ui")
local Ops        = require("lua/game/ops")
local Sim        = require("lua/game/pusher_sim")
local OpTile     = require("lua/game/op_tile")
local DefParser  = require("lua/game/def_parser")

-- Layout constants (matching MatrixScene)
local GRID_X    = 95
local GRID_Y    = 20
local CELL_SIZE = 63
local PALETTE_Y = 660
local HUD_X     = 820
local W         = 1280
local H         = 720

local PAL_BTN_W = 42
local PAL_BTN_H = 48
local PAL_STEP  = PAL_BTN_W + 6      -- 48
local PAL_LEFT  = 10
local PAL_SEP   = 12
local PAL_ERASE_W = 52
local BAR_BTN_Y = PALETTE_Y + 6

local CMD_BTN_W    = 56
local CMD_BTN_H    = 48
local CMD_BTN_STEP = 62
local CMD_COUNT    = 4
-- The command buttons end 10px from the right edge of the bar.
local CMD_X        = W - 10 - ((CMD_COUNT - 1) * CMD_BTN_STEP + CMD_BTN_W)

-- HUD layout constants
local HUD_PAD  = 12
local MAT_CS   = 44   -- matrix cell size in HUD
local SPIN_W   = 20
local SPIN_H   = 20
local OPS_W    = 36
local OPS_H    = 22
local OPS_GAP  = 4
local OPS_LBL_H = 14
local SEL_W    = 30   -- input selector buttons on the INPUT heading row
local SEL_H    = 20
local SEL_STEP = 34

local EDITOR_PALETTE = {
    { id="editor:pal:source",   kind="source",  label="SRC"  },
    { id="editor:pal:source2",  kind="source2", label="SRC2" },
    { id="editor:pal:sink",     kind="sink",    label="SNK"  },
    { id="editor:pal:gap",      kind="gap",     label="GAP"  },
    { sep=true },
    { id="editor:pal:pusher",   kind="pusher",  label="P"    },
    { sep=true },
}
-- Classic ops then the two-cell matrix ops, in palette and allowlist order.
local ALL_OPS = {}
for _, list in ipairs({ Ops.ORDER, Ops.MATRIX_ORDER }) do
    for _, op in ipairs(list) do ALL_OPS[#ALL_OPS+1] = op end
end
for _, op in ipairs(ALL_OPS) do
    EDITOR_PALETTE[#EDITOR_PALETTE+1] =
        { id="editor:pal:"..op, kind="op", op=op, label=Ops.label(op) }
end
EDITOR_PALETTE[#EDITOR_PALETTE+1] = { sep=true }
EDITOR_PALETTE[#EDITOR_PALETTE+1] = { id="editor:pal:erase", kind="erase", label="Erase", w=PAL_ERASE_W }

local CMD_BUTTONS = {
    { id="editor:back",  label="Back"  },
    { id="editor:test",  label="Test"  },
    { id="editor:copy",  label="Copy"  },
    { id="editor:paste", label="Paste" },
}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function cell_top_left(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE,
           GRID_Y + (cy - 1) * CELL_SIZE
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

-- The allowed ops in palette order. nil when the selection means "the ten classic
-- ops": nothing toggled, or exactly those ten.
local function ops_subset(allowed)
    local enabled, matrix = {}, false
    for _, op in ipairs(ALL_OPS) do
        if allowed[op] then
            enabled[#enabled+1] = op
            matrix = matrix or Ops.is_two_cell(op)
        end
    end
    if matrix or (#enabled > 0 and #enabled < #Ops.ORDER) then return enabled end
    return nil
end

-- A fixed_ops entry is an op id, or { op=, params= } presetting the placed tiles.
-- Copies a validated list, keeping only supported params; nil when it is empty.
local function copy_fixed_ops(list)
    local out = {}
    for _, entry in ipairs(list or {}) do
        if type(entry) == "table" then
            local copy = { op = entry.op }
            if entry.params then
                local params = Ops.params(entry.op, entry.params)
                if next(params) then copy.params = params end
            end
            out[#out+1] = copy
        else
            out[#out+1] = entry
        end
    end
    if #out > 0 then return out end
    return nil
end

-- k<eq>v for each param, sorted by key and comma separated.
local function fmt_params(params, eq)
    local keys = {}
    for k in pairs(params) do keys[#keys+1] = k end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
        local v = params[k]
        local text = type(v) == "string" and string.format("%q", v) or tostring(v)
        out[#out+1] = k .. eq .. text
    end
    return table.concat(out, ", ")
end

local function fmt_fixed_ops(list)
    local out = {}
    for _, entry in ipairs(list) do
        if type(entry) == "string" then
            out[#out+1] = string.format("%q", entry)
        else
            local text = string.format("op = %q", entry.op)
            if entry.params then
                text = text .. ", params = { " .. fmt_params(entry.params, " = ") .. " }"
            end
            out[#out+1] = "{ " .. text .. " }"
        end
    end
    return "{ " .. table.concat(out, ", ") .. " }"
end

-- true, or false plus a message naming the first unsupported op or invalid param.
local function validate_ops(def)
    for _, op in ipairs(def.ops or {}) do
        local ok, msg = Ops.validate(op)
        if not ok then return false, msg end
    end
    for _, t in ipairs(def.locked or {}) do
        if t.kind == "op" then
            local ok, msg = Ops.validate(t.op, t.params)
            if not ok then return false, msg end
        end
    end
    if def.fixed_ops ~= nil and type(def.fixed_ops) ~= "table" then
        return false, "Invalid fixed_ops"
    end
    for _, entry in ipairs(def.fixed_ops or {}) do
        local op, params = entry, nil
        if type(entry) == "table" then op, params = entry.op, entry.params end
        local ok, msg = Ops.validate(op, params)
        if not ok then return false, msg end
    end
    return true
end

local function is_integer(v)
    return type(v) == "number" and v == math.floor(v)
end

local function is_input_matrix(mat)
    if type(mat) ~= "table" then return false end
    for _, n in ipairs({ "rows", "cols" }) do
        if not (is_integer(mat[n]) and mat[n] >= 1 and mat[n] <= 4) then return false end
    end
    if type(mat.values) ~= "table" then return false end
    for _, row in pairs(mat.values) do
        if type(row) ~= "table" then return false end
        for _, v in pairs(row) do
            if type(v) ~= "number" then return false end
        end
    end
    return true
end

-- true, or false plus a message about the optional second source.
local function validate_second(def)
    if def.source2 == nil and def.input2 == nil then return true end
    if def.source2 == nil or def.input2 == nil then
        return false, "source2 and input2 come together"
    end
    if not is_input_matrix(def.input2) then return false, "Invalid input2" end
    local at = def.source2
    if not (type(at) == "table" and is_integer(at.x) and is_integer(at.y)) then
        return false, "Invalid source2"
    end
    return true
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

-- ── EditorScene ────────────────────────────────────────────────────────────

local EditorScene = setmetatable({}, { __index = Scene })
EditorScene.__index = EditorScene

function EditorScene.new(scene_manager, settings_state)
    local self = Scene.new(W, H)
    setmetatable(self, EditorScene)
    self._scene_manager  = scene_manager
    self._settings_state = settings_state
    self._grid           = Grid.new(10, 10)
    self._name           = "Untitled"
    self._name_focus     = false
    self._input          = { rows=2, cols=2, values={{1,0},{0,1}} }
    self._input2         = { rows=2, cols=2, values={{1,0},{0,1}} }
    self._input_sel      = 1      -- which input the matrix section edits
    self._target         = { rows=2, cols=2, values={{1,0},{0,1}} }
    self._sel            = nil
    self._copy_flash     = 0
    self._paste_error    = nil
    self._paste_error_t  = 0
    self._allowed_ops    = {}
    self._no_ops         = false  -- loaded with an empty ops list: no editable ops
    self._fixed_ops      = nil
    self._source         = nil
    self._source2        = nil    -- the puzzle has two sources only while this is set
    self._sink           = nil
    self._mouse          = nil    -- last logical mouse position (for the T key)
    self:_reset_tool_facing()
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
    -- Test fades the menu music out; fading it in also cancels a fade-out still running.
    local Sound = require("lua/core/sound")
    Sound.fade_music("menu", 1, 1)
end

-- ── Tools and inputs ───────────────────────────────────────────────────────

-- Each two-cell tool starts with its right operand to the right.
function EditorScene:_reset_tool_facing()
    self._tool_facing = {}
    for _, op in ipairs(Ops.MATRIX_ORDER) do self._tool_facing[op] = Ops.params(op).facing end
end

function EditorScene:_turn_tool(op)
    self._tool_facing[op] = Ops.next_facing(self._tool_facing[op])
end

-- The input matrix of source 1 or 2.
function EditorScene:_input_of(slot)
    if slot == 2 then return self._input2 end
    return self._input
end

-- ── Palette layout ─────────────────────────────────────────────────────────

function EditorScene:_layout_palette()
    local rects = {}
    local x = PAL_LEFT
    local pending_sep = false

    for _, btn in ipairs(EDITOR_PALETTE) do
        if btn.sep then
            pending_sep = true
        else
            if pending_sep then x = x + PAL_SEP; pending_sep = false end
            rects[#rects+1] = { id=btn.id, btn=btn, x=x, y=BAR_BTN_Y, w=btn.w or PAL_BTN_W, h=PAL_BTN_H }
            x = x + PAL_STEP
        end
    end

    self._pal_rects = rects
end

-- ── HUD layout ─────────────────────────────────────────────────────────────

-- Appends matrix-section UI elements into `out`.
-- Returns the y just below all cells in this section.
function EditorScene:_add_matrix_section(out, key, cy)
    local hx    = HUD_X + HUD_PAD   -- 832
    local mat   = key == "input" and self:_input_of(self._input_sel) or self._target
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
    for n = 1, 2 do
        out[#out+1] = {id="editor:input_sel:"..n, label="#"..n, kind="button",
            rect={x=hx+(n-1)*SEL_STEP, y=cy, w=SEL_W, h=SEL_H},
            enabled=true, selected=self._input_sel == n}
    end
    local inp_next = self:_add_matrix_section(out, "input", cy)
    cy = inp_next + 10

    -- TARGET section
    self._hud_tgt_lbl_y  = cy
    self._hud_tgt_cell_y = cy + 50
    local tgt_next = self:_add_matrix_section(out, "target", cy)
    cy = tgt_next + 10

    -- Op allowlist
    self._hud_ops_lbl_y = cy
    cy = cy + OPS_LBL_H   -- buttons start below the label
    local ops_per_row = 8
    for i, op in ipairs(ALL_OPS) do
        local row = math.floor((i - 1) / ops_per_row)
        local col = (i - 1) % ops_per_row
        local ox  = hx + col * (OPS_W + OPS_GAP)
        local oy  = cy + row * (OPS_H + OPS_GAP)
        if oy + OPS_H <= PALETTE_Y - 4 then
            out[#out+1] = {
                id      = (Ops.is_two_cell(op) and "editor:allow_matrix:" or "editor:allow:")..op,
                label   = Ops.label(op),
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
    local params = tile.params or {}
    return { kind = tile.kind, op = tile.op, dir = tile.dir,
             edge = params.edge, scalar = params.scalar,
             facing = params.facing, index = self:_source_index(tile) }
end

-- 1 or 2 for a source tile while there are two sources, else nil.
function EditorScene:_source_index(tile)
    if tile.kind == "source" and self._source2 then return tile.slot end
    return nil
end

function EditorScene:_sel_matches(btn)
    if not self._sel       then return false end
    if btn.kind == "op"    then return self._sel.kind == "op" and self._sel.op == btn.op end
    if btn.kind == "erase" then return self._sel.kind == "erase" end
    return self._sel.kind == btn.kind
end

function EditorScene:ui_elements()
    local els = {}

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
        local op    = r.btn.op
        local label = r.btn.label
        if op and Ops.is_two_cell(op) then label = Ops.tool_label(op, self._tool_facing[op]) end
        els[#els+1] = {
            id=r.id, label=label, kind="button",
            rect={x=r.x, y=r.y, w=r.w, h=r.h},
            enabled=true, selected=self:_sel_matches(r.btn),
        }
    end

    for i, cmd in ipairs(CMD_BUTTONS) do
        els[#els+1] = {
            id=cmd.id, label=cmd.label, kind="button",
            rect={x=CMD_X+(i-1)*CMD_BTN_STEP, y=BAR_BTN_Y, w=CMD_BTN_W, h=CMD_BTN_H},
            enabled=true,
        }
    end

    for _, e in ipairs(self._hud_els) do
        els[#els+1] = e
    end

    return els
end

-- ── Grid mutation ──────────────────────────────────────────────────────────

function EditorScene:_erase_at(cx, cy)
    if not self._grid:in_bounds(cx, cy) then return end
    local raw = self._grid.cells[cy][cx]
    if raw == nil then return end

    local ax, ay
    if raw.ref then ax, ay = raw.ax, raw.ay
    else            ax, ay = cx, cy end

    local tile = self._grid.cells[ay][ax]
    if tile == nil then return end

    if tile.kind == "source" then
        if tile.slot == 2 then self._source2 = nil
        else                   self._source  = nil end
    end
    if tile.kind == "sink"   then self._sink   = nil end

    -- A two-cell tile's partner can be on any side of the anchor.
    if tile.kind == "op" and Ops.is_two_cell(tile.op) then
        local px, py = Ops.partner(ax, ay, tile.params.facing)
        self._grid.cells[ay][ax] = nil
        self._grid.cells[py][px] = nil
        return
    end

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

function EditorScene:_used_pusher_ids()
    local used = {}
    for cy = 1, 10 do
        for cx = 1, 10 do
            local t = self._grid.cells[cy][cx]
            if t and t.kind == "pusher" then used[t.id] = true end
        end
    end
    return used
end

function EditorScene:_place_at(cx, cy)
    if not self._sel then return end
    if not self._grid:in_bounds(cx, cy) then return end
    local sel = self._sel

    if sel.kind == "erase" then self:_erase_at(cx, cy); return end

    if sel.kind == "source" or sel.kind == "source2" then
        local slot = sel.kind == "source2" and 2 or 1
        self:_remove_source(slot)
        self:_put_source(slot, cx, cy)
        return
    end

    if sel.kind == "sink" then
        if self._grid.cells[cy][cx] ~= nil then return end
        if self._sink then self._grid.cells[self._sink.y][self._sink.x] = nil end
        self._grid:set(cx, cy, {kind="sink", locked=true})
        self._sink = {x=cx, y=cy}; return
    end

    if sel.kind == "gap" then
        if self._grid.cells[cy][cx] == nil then
            self._grid:set(cx, cy, {kind="gap", locked=true})
        end; return
    end

    if sel.kind == "op" then
        -- facing only applies to the two-cell ops; nothing is ever overwritten.
        local params = Ops.params(sel.op, {facing=self._tool_facing[sel.op]})
        local tile   = {kind="op", op=sel.op, locked=true, params=params}
        if self._grid:fits(cx, cy, tile) then self._grid:put(cx, cy, tile) end
        return
    end

    if sel.kind == "pusher" then
        if self._grid.cells[cy][cx] ~= nil then return end
        local id = Sim.free_pusher_id(self:_used_pusher_ids())
        if id then self._grid:set(cx, cy, {kind="pusher", locked=true, id=id}) end
    end
end

-- ── Matrix helpers ─────────────────────────────────────────────────────────

function EditorScene:_source_pos(slot)
    if slot == 2 then return self._source2 end
    return self._source
end

function EditorScene:_remove_source(slot)
    local at = self:_source_pos(slot)
    if at then self:_erase_at(at.x, at.y) end   -- also forgets the position
end

-- Places source `slot`, sized by its input, with its top-left at (x,y) if every
-- cell of the footprint is on the grid and free.
function EditorScene:_put_source(slot, x, y)
    local input  = self:_input_of(slot)
    local sc, sr = input.cols, input.rows
    for dy = 0, sr-1 do
        for dx = 0, sc-1 do
            if not self:_is_free(x+dx, y+dy) then return end
        end
    end
    self._grid:set_multi_2d(x, y,
        {kind="source", locked=true, width=sc, height=sr, slot=slot}, sc, sr)
    if slot == 2 then self._source2 = {x=x, y=y}
    else              self._source  = {x=x, y=y} end
end

-- Re-places a source tile at its current position with its input's dimensions.
-- Called whenever those change so the footprint stays in sync; a source that no
-- longer fits is removed.
function EditorScene:_refit_source(slot)
    local at = self:_source_pos(slot)
    if not at then return end
    self:_remove_source(slot)
    self:_put_source(slot, at.x, at.y)
end

-- Spinner change of the selected input.
function EditorScene:_resize_input(drows, dcols)
    local mat = self:_input_of(self._input_sel)
    self:_adjust_matrix(mat, mat.rows+drows, mat.cols+dcols)
    self:_refit_source(self._input_sel)
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

-- ── Clipboard ──────────────────────────────────────────────────────────────

-- Loads the clipboard definition; on bad input shows why and changes nothing.
function EditorScene:_paste()
    local def = DefParser.parse(love.system.getClipboardText())
    local valid, msg = false, "Parse error"
    if def and def.input and def.target then
        valid, msg = validate_second(def)
        if valid then valid, msg = validate_ops(def) end
    end
    if valid then
        self:_load_def(def)
        self:_rebuild_hud()
    else
        self._paste_error   = msg
        self._paste_error_t = 2.0
    end
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
    if key == "t" then self:_turn_key(); return end
    if key == "escape" then
        local StartScene = require("lua/game/scenes/start_scene")
        self._scene_manager:switch(StartScene.new(self._scene_manager, self._settings_state))
    end
end

function EditorScene:text_input(ch)
    if self._name_focus then
        self._name = self._name .. ch
    end
end

-- The T key turns the two-cell tile under the cursor, else the selected matrix tool.
function EditorScene:_turn_key()
    local m = self._mouse
    local e = m and UI.element_at(self:ui_elements(), m.x, m.y)
    if e then
        local cx, cy = e.id:match("^cell:(%d+),(%d+)$")
        if cx then
            cx, cy = tonumber(cx), tonumber(cy)
            local tile = self._grid:get(cx, cy)
            if tile and tile.kind == "op" and Ops.is_two_cell(tile.op) then
                self._grid:rotate(cx, cy)   -- stops here even when it cannot turn
                return
            end
        end
    end
    local sel = self._sel
    if sel and sel.kind == "op" and Ops.is_two_cell(sel.op) then self:_turn_tool(sel.op) end
end

function EditorScene:mouse_moved(mx, my)
    self._mouse = {x=mx, y=my}
end

function EditorScene:mouse_pressed(mx, my, btn)
    self._mouse = {x=mx, y=my}
    local e = UI.element_at(self:ui_elements(), mx, my)
    if e then
        -- Grid cell elements: route to place/erase.
        local cell_x, cell_y = e.id:match("^cell:(%d+),(%d+)$")
        if cell_x then
            local cx, cy = tonumber(cell_x), tonumber(cell_y)
            if btn == 1 then
                local tile    = self._grid:get(cx, cy)
                local erasing = self._sel and self._sel.kind == "erase"
                local is_op   = not erasing and tile ~= nil and tile.kind == "op"
                if is_op and Ops.is_two_cell(tile.op) then
                    self._grid:rotate(cx, cy)
                elseif is_op and Ops.has_scalar(tile.op) then
                    Ops.click(tile.op, tile.params, Ops.part(mx - e.rect.x, CELL_SIZE))
                else
                    self:_place_at(cx, cy)
                end
            elseif btn == 2 then
                self:_erase_at(cx, cy)
            end
            return
        end

        if btn == 1 then
            if e.id == "editor:back" then
                local StartScene = require("lua/game/scenes/start_scene")
                self._scene_manager:switch(StartScene.new(self._scene_manager, self._settings_state))
            elseif e.id == "editor:name" then
                self._name_focus = true
            elseif e.id == "editor:copy" then
                love.system.setClipboardText(self:_serialize())
                self._copy_flash = 2.0
            elseif e.id == "editor:paste" then
                self:_paste()
            elseif e.id == "editor:test" then
                local def = self:_build_def()
                local ms  = require("lua/game/scenes/matrix_scene")
                self._scene_manager:switch(ms.new_from_def(def, self._scene_manager, self, self._settings_state))
            elseif e.id == "editor:input_rows_dec" then
                self:_resize_input(-1, 0)
            elseif e.id == "editor:input_rows_inc" then
                self:_resize_input(1, 0)
            elseif e.id == "editor:input_cols_dec" then
                self:_resize_input(0, -1)
            elseif e.id == "editor:input_cols_inc" then
                self:_resize_input(0, 1)
            elseif e.id:find("^editor:input_sel:") then
                self._input_sel = tonumber(e.id:match("(%d)$"))
                self:_rebuild_hud()   -- the cells now belong to the other input
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
                    self:_cell_click(self:_input_of(self._input_sel),
                        tonumber(ir), tonumber(ic), mx, e.rect.x)
                    return
                end
                local tr, tc = e.id:match("^editor:target_cell:(%d+),(%d+)$")
                if tr then
                    self:_cell_click(self._target, tonumber(tr), tonumber(tc), mx, e.rect.x)
                    return
                end
                local op = e.id:match("^editor:allow:(.+)$")
                    or e.id:match("^editor:allow_matrix:(.+)$")
                if op then
                    if self._allowed_ops[op] then self._allowed_ops[op] = nil
                    else                          self._allowed_ops[op] = true end
                    self._no_ops = false
                    return
                end
                for _, pal_btn in ipairs(EDITOR_PALETTE) do
                    if pal_btn.id == e.id then
                        if     pal_btn.kind == "erase" then self._sel = {kind="erase"}
                        elseif pal_btn.kind == "op"    then
                            -- Clicking the selected matrix tool again turns it.
                            if Ops.is_two_cell(pal_btn.op) and self:_sel_matches(pal_btn) then
                                self:_turn_tool(pal_btn.op)
                            end
                            self._sel = {kind="op", op=pal_btn.op}
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

-- True when the cell is on the grid and holds nothing.
function EditorScene:_is_free(cx, cy)
    return self._grid:in_bounds(cx, cy) and self._grid.cells[cy][cx] == nil
end

-- ── Build / Load def ──────────────────────────────────────────────────────

-- The def's ops list: the allowed subset, {} to keep "no editable ops", or nil for all.
function EditorScene:_def_ops()
    if self._no_ops and not next(self._allowed_ops) then return {} end
    return ops_subset(self._allowed_ops)
end

-- Where Copy and Test put source 1 when none is placed: (1,1), or with a second
-- source on the board the first spot (reading order) where input 1 covers nothing,
-- the default sink included; failing that, the first one clear of source 2.
function EditorScene:_default_source()
    if not self._source2 then return {x=1, y=1} end
    local cols, rows = self._input.cols, self._input.rows
    local beside
    for y = 1, 10 - rows + 1 do
        for x = 1, 10 - cols + 1 do
            local free, clear = true, true
            for cy = y, y + rows - 1 do
                for cx = x, x + cols - 1 do
                    local tile = self._grid:get(cx, cy)
                    if tile or (not self._sink and cx == 10 and cy == 10) then free = false end
                    if tile and tile.kind == "source" then clear = false end
                end
            end
            if free then return {x=x, y=y} end
            if clear then beside = beside or {x=x, y=y} end
        end
    end
    -- A 10x10 board always has room beside one source of at most 4x4.
    return beside
end

function EditorScene:_build_def()
    local src = self._source or self:_default_source()
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
                    if tile.id     then entry.id      = tile.id end
                    if tile.params and next(tile.params) then
                        entry.params = deep_copy(tile.params)
                    end
                    locked[#locked+1] = entry
                end
            end
        end
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
    if self._source2 then
        def.source2 = { x=self._source2.x, y=self._source2.y }
        def.input2  = { rows=self._input2.rows, cols=self._input2.cols,
                        values=deep_copy(self._input2.values) }
    end
    def.ops = self:_def_ops()
    if self._fixed_ops then def.fixed_ops = deep_copy(self._fixed_ops) end
    return def
end

function EditorScene:_load_def(def)
    self._name        = def.name or "Untitled"
    self._name_focus  = false
    self._grid        = Grid.new(10, 10)
    self._source      = nil
    self._source2     = nil
    self._sink        = nil
    self._input_sel   = 1
    self:_reset_tool_facing()
    self._allowed_ops = {}
    self._copy_flash  = 0
    self._paste_error = nil
    self._paste_error_t = 0

    -- Input / target matrices
    self._input  = { rows=def.input.rows,  cols=def.input.cols,
                     values=deep_copy(def.input.values) }
    self._target = { rows=def.target.rows, cols=def.target.cols,
                     values=deep_copy(def.target.values) }
    local input2 = def.input2 or { rows=2, cols=2, values={{1,0},{0,1}} }
    self._input2 = { rows=input2.rows, cols=input2.cols, values=deep_copy(input2.values) }
    ensure_matrix_values(self._input)
    ensure_matrix_values(self._input2)
    ensure_matrix_values(self._target)

    -- No tile is placed over another; one that does not fit is skipped whole.
    -- Locked tiles (one cell, or two for a matrix op) go first: without a placed
    -- source or sink the def carries a default position that a tile may occupy.
    local locked = def.locked or {}
    local pusher_ids = Sim.assign_pusher_ids(locked)
    for _, t in ipairs(locked) do
        if t.kind ~= "pusher" or pusher_ids[t] then
            local tile = { kind=t.kind, op=t.op, id=pusher_ids[t], locked=true }
            if t.kind == "op" then tile.params = Ops.params(t.op, t.params) end
            if self._grid:fits(t.x, t.y, tile) then self._grid:put(t.x, t.y, tile) end
        end
    end

    -- Sources
    if def.source  then self:_put_source(1, def.source.x,  def.source.y)  end
    if def.source2 then self:_put_source(2, def.source2.x, def.source2.y) end

    -- Sink
    if def.sink then
        local sx, sy = def.sink.x, def.sink.y
        if self:_is_free(sx, sy) then
            self._grid:set(sx, sy, {kind="sink", locked=true})
            self._sink = {x=sx, y=sy}
        end
    end

    -- Gaps
    for _, g in ipairs(def.gaps or {}) do
        if self:_is_free(g.x, g.y) then
            self._grid:set(g.x, g.y, {kind="gap", locked=true})
        end
    end

    -- Op allowlist and fixed ops
    for _, op in ipairs(def.ops or {}) do
        self._allowed_ops[op] = true
    end
    self._no_ops    = type(def.ops) == "table" and next(def.ops) == nil
    self._fixed_ops = copy_fixed_ops(def.fixed_ops)
end

-- ── Serialization ─────────────────────────────────────────────────────────

function EditorScene:_serialize()
    local lines = {"return {"}

    -- name
    local name = self._name ~= "" and self._name or "Untitled"
    lines[#lines+1] = string.format('    name   = %q,', name)

    -- grid size
    lines[#lines+1] = "    grid_w = 10, grid_h = 10,"

    -- source / sink
    local src = self._source or self:_default_source()
    local snk = self._sink   or {x=10, y=10}
    lines[#lines+1] = string.format("    source = { x=%d, y=%d },", src.x, src.y)
    local src2 = self._source2
    if src2 then
        lines[#lines+1] = string.format("    source2 = { x=%d, y=%d },", src2.x, src2.y)
    end
    lines[#lines+1] = string.format("    sink   = { x=%d, y=%d },", snk.x, snk.y)

    -- ops (omitted when all ops are offered: none or all toggled on)
    local enabled_ops = self:_def_ops()
    if enabled_ops and #enabled_ops == 0 then
        lines[#lines+1] = "    ops    = {},"
    elseif enabled_ops then
        local parts = {}
        for _, op in ipairs(enabled_ops) do parts[#parts+1] = '"' .. op .. '"' end
        lines[#lines+1] = "    ops    = { " .. table.concat(parts, ", ") .. " },"
    end

    if self._fixed_ops then
        lines[#lines+1] = "    fixed_ops = " .. fmt_fixed_ops(self._fixed_ops) .. ","
    end

    -- locked tiles (non-source/sink/gap anchors with locked=true)
    local locked_entries = {}
    for cy = 1, 10 do
        for cx = 1, 10 do
            if not self._grid:is_ref(cx, cy) then
                local tile = self._grid.cells[cy][cx]
                if tile and tile.locked
                   and tile.kind ~= "source" and tile.kind ~= "sink" and tile.kind ~= "gap" then
                    locked_entries[#locked_entries+1] = {x=cx, y=cy, tile=tile}
                end
            end
        end
    end
    if #locked_entries > 0 then
        lines[#lines+1] = "    locked = {"
        for _, lt in ipairs(locked_entries) do
            local t  = lt.tile
            local pp = {}
            pp[#pp+1] = string.format('kind="%s"', t.kind)
            if t.op  then pp[#pp+1] = string.format('op="%s"', t.op) end
            pp[#pp+1] = string.format("x=%d", lt.x)
            pp[#pp+1] = string.format("y=%d", lt.y)
            if t.id  then pp[#pp+1] = string.format("id=%d", t.id) end
            if t.params and next(t.params) then
                pp[#pp+1] = "params={" .. fmt_params(t.params, "=") .. "}"
            end
            lines[#lines+1] = "        { " .. table.concat(pp, ", ") .. " },"
        end
        lines[#lines+1] = "    },"
    end

    -- gaps
    local gap_entries = {}
    for cy = 1, 10 do
        for cx = 1, 10 do
            local tile = self._grid.cells[cy][cx]
            if tile and tile.kind == "gap" then
                gap_entries[#gap_entries+1] = string.format("{x=%d,y=%d}", cx, cy)
            end
        end
    end
    if #gap_entries > 0 then
        lines[#lines+1] = "    gaps   = {"
        lines[#lines+1] = "        " .. table.concat(gap_entries, ",") .. ","
        lines[#lines+1] = "    },"
    end

    -- input / target
    lines[#lines+1] = string.format(
        "    input  = { rows=%d, cols=%d, values=%s },",
        self._input.rows, self._input.cols, fmt_values(self._input.values))
    if src2 then
        lines[#lines+1] = string.format(
            "    input2 = { rows=%d, cols=%d, values=%s },",
            self._input2.rows, self._input2.cols, fmt_values(self._input2.values))
    end
    lines[#lines+1] = string.format(
        "    target = { rows=%d, cols=%d, values=%s },",
        self._target.rows, self._target.cols, fmt_values(self._target.values))

    lines[#lines+1] = "}"
    return table.concat(lines, "\n")
end

-- ── Draw helpers ───────────────────────────────────────────────────────────

local function draw_tile(tile, cx, cy, font_cell, font_ui, index)
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
        local text = index and ("SRC " .. index) or "SRC"
        love.graphics.printf(text, sx, sy + span_h/2 - 7, span_w, "center")
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
        OpTile.draw(tile, sx, sy, cs, {cell=font_cell, ui=font_ui}, {marks=true, immutable=false})
        if tile.locked then
            love.graphics.setColor(0.50, 0.50, 0.50, 1)
            love.graphics.circle("fill", sx+cs-8, sy+7, 3)
            love.graphics.rectangle("fill", sx+cs-10, sy+7, 4, 5)
        end
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

-- A two-cell tool's button: its name, then a triangle towards the right operand.
-- The arrow is a shape, not a character, so it never reads as an edge tile's arrow.
local function draw_tool_label(op, facing, r)
    love.graphics.printf(Ops.label(op), r.x, r.y+10, r.w, "center")
    local offset = Ops.OFFSETS[facing]
    local dx, dy = offset.dx, offset.dy
    local x, y   = r.x + r.w/2, r.y + 33
    love.graphics.polygon("fill",
        x + 6*dx,          y + 6*dy,
        x - 4*dx - 5*dy,   y - 4*dy + 5*dx,
        x - 4*dx + 5*dy,   y - 4*dy - 5*dx)
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

        elseif e.id:find("^editor:allow") or e.id:find("^editor:input_sel:") then
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
    local input = self:_input_of(self._input_sel)
    love.graphics.setColor(0.60, 0.75, 1.0, 1)
    love.graphics.printf("INPUT " .. self._input_sel, HUD_X, self._hud_inp_lbl_y+4, W-HUD_X, "center")
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
    love.graphics.printf(tostring(input.rows),  hx+90,  self._hud_inp_lbl_y+spin_off, 20, "center")
    love.graphics.printf(tostring(input.cols),  hx+206, self._hud_inp_lbl_y+spin_off, 20, "center")
    love.graphics.printf(tostring(self._target.rows), hx+90,  self._hud_tgt_lbl_y+spin_off, 20, "center")
    love.graphics.printf(tostring(self._target.cols), hx+206, self._hud_tgt_lbl_y+spin_off, 20, "center")
    -- OPS label
    love.graphics.setColor(0.60, 0.75, 1.0, 1)
    love.graphics.printf("OPS:", hx, self._hud_ops_lbl_y - 2, 50, "left")
    -- Dividers
    love.graphics.setColor(0.2, 0.2, 0.3, 1)
    local d1 = self._hud_inp_cell_y + input.rows * MAT_CS + 4
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
                if tile then
                    draw_tile(tile, cx, cy, self._font_cell, self._font_ui,
                        self:_source_index(tile))
                end
            end
        end
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
            local op = e.id:match("^editor:pal:(.+)$")
            if op and Ops.is_two_cell(op) then
                draw_tool_label(op, self._tool_facing[op], r)
            else
                love.graphics.printf(e.label, r.x, r.y+17, r.w, "center")
            end
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
