local Scene        = require("lua/core/scene")
local Matrix       = require("lua/game/matrix_math")
local Grid         = require("lua/game/grid")
local Sim          = require("lua/game/pusher_sim")
local Timeline     = require("lua/game/timeline")
local Palette      = require("lua/game/palette")
local HUD          = require("lua/game/hud")
local PuzzleLoader = require("lua/game/puzzle_loader")
local UI           = require("lua/core/ui")
local SettingsMenu = require("lua/game/scenes/settings_menu")
local Ops          = require("lua/game/ops")
local OpTile       = require("lua/game/op_tile")
local TwoCell      = require("lua/game/two_cell")

local function cell_key(x, y) return x .. "," .. y end

-- Where the run state of each travelling matrix lives: 1 is the primary (source
-- 1's matrix, after a merge the result), 2 the other one in a two-source run.
local SLOTS = {
    { matrix = "current_matrix", fired = "occupied_ops", last = "_last_fp" },
    { matrix = "second_matrix",  fired = "second_fired", last = "_second_fp" },
}

-- Matrix border colour by source; a merged result keeps the left operand's.
local MATRIX_BORDER = { [1] = {0.91, 0.73, 0.15}, [2] = {0.25, 0.80, 0.90} }
local PREVIEW_DIM   = 0.52   -- idle previews use a dimmed border
local SRC_TAG_W, SRC_TAG_H = 40, 13   -- "SRC n" tag above a preview's first value

local MatrixScene = {}
MatrixScene.__index = MatrixScene

-- Layout constants
-- Layout (1280x720): ops column left, grid, HUD right, bottom bar (timeline area + run controls).
local SCREEN_W        = 1280
local BAR_Y           = 540                -- top of the bottom bar
local BAR_H           = 180
local OPS_W           = 120                -- ops column width (x 0..120)
local GRID_X          = 130
local GRID_Y          = 10
local CELL_SIZE       = 52                 -- 10 cells -> 520px, grid ends at y=530
local HUD_X           = 670
local HUD_W           = SCREEN_W - HUD_X
local CMD_BTN_W       = 72
local CMD_BTN_H       = 40
local CMD_BTN_GAP     = 6
local CMD_BTN_X       = SCREEN_W - 10 - (2 * CMD_BTN_W + CMD_BTN_GAP)   -- 2x2 block, bottom-right corner
local CMD_BTN_Y       = 720 - 10 - (2 * CMD_BTN_H + CMD_BTN_GAP)

local STATUS_COLORS = {
    win       = {0.2, 0.8, 0.3, 1},
    fail      = {0.9, 0.2, 0.2, 1},
    blocked   = {0.9, 0.2, 0.2, 1},
    stuck     = {0.9, 0.6, 0.1, 1},
    running   = {0.4, 0.6, 1.0, 1},
    no_pusher = {0.9, 0.6, 0.1, 1},
    collided    = {0.9, 0.2, 0.2, 1},
    both_inputs = {0.9, 0.2, 0.2, 1},
    bad_shape   = {0.9, 0.2, 0.2, 1},   -- text comes from status_message
    uncombined  = {0.9, 0.2, 0.2, 1},
}

local STATUS_LABELS = {
    win       = "WIN!",
    fail      = "FAIL — matrix mismatch",
    blocked   = "FAIL — matrix is blocked",
    stuck     = "STUCK — nothing is pushing",
    running   = "Running...",
    no_pusher = "Place a pusher first",
    collided    = "FAIL — matrices collided",
    both_inputs = "FAIL — one matrix on both inputs",
    uncombined  = "FAIL — matrices not combined",
}

-- Bottom bar (x 0..CMD_BTN_X-10): pusher selector + instruction chips, then 4 lanes x 60 ticks.
local CMD_GLYPH   = { up="^", down="v", left="<", right=">", stop=".", clear="CLR" }
local CHIP_ORDER  = { "up", "down", "left", "right", "stop", "clear" }
local BAR = {
    PANEL_X = 8,  PSEL_Y = BAR_Y + 10, PSEL_W = 28, PSEL_H = 28, PSEL_STEP = 30,
    CHIP_Y  = BAR_Y + 60, CHIP_W = 38, CHIP_H = 38, CHIP_STEP = 42,
    TL_X    = 260, TL_RIGHT = CMD_BTN_X - 10,
    ARROW_W = 16,
    HEAD_Y  = BAR_Y + 6,  HEAD_H = 16,
    LANE_Y  = BAR_Y + 26, LANE_H = 34, LANE_STEP = 36,
    SLOT_W  = 30, SLOT_STEP = 32, PAGE = 5,
}
BAR.SLOT_X   = BAR.TL_X + BAR.ARROW_W + 4
BAR.SLOT_END = BAR.TL_RIGHT - BAR.ARROW_W - 4
BAR.VIS      = math.floor((BAR.SLOT_END - BAR.SLOT_X) / BAR.SLOT_STEP)

local DIR_ARROWS = { right="->", left="<-", up="^", down="v" }

-- Pusher | the k ops | the shape ops | Mv, erase (op order and labels come from Ops).
local PALETTE_BUTTONS = { { kind="pusher", label="P" }, { sep=true } }
for i, op in ipairs(Ops.ORDER) do
    table.insert(PALETTE_BUTTONS, { kind="op", op=op, label=Ops.label(op) })
    if i == 6 then table.insert(PALETTE_BUTTONS, { sep=true }) end
end
-- The two-cell ops stay in the shape group (a separator of their own would overflow).
for _, op in ipairs(Ops.MATRIX_ORDER) do
    table.insert(PALETTE_BUTTONS, { kind="op", op=op, label=Ops.label(op) })
end
table.insert(PALETTE_BUTTONS, { sep=true })
table.insert(PALETTE_BUTTONS, { kind="drag", label="Mv" })
table.insert(PALETTE_BUTTONS, { erase=true, label="[X]" })

local CMD_BUTTONS = {
    { id="run",      label="Run",      color_fill={0.12,0.28,0.12}, color_border={0.30,0.75,0.30} },
    { id="reset",    label="Reset",    color_fill={0.28,0.16,0.06}, color_border={0.85,0.55,0.20} },
    { id="menu",     label="Menu",     color_fill={0.12,0.15,0.28}, color_border={0.35,0.45,0.72} },
    { id="continue", label="Continue", color_fill={0.12,0.28,0.12}, color_border={0.30,0.75,0.30} },
}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function screen_to_cell(mx, my)
    local cx = math.floor((mx - GRID_X) / CELL_SIZE) + 1
    local cy = math.floor((my - GRID_Y) / CELL_SIZE) + 1
    return cx, cy
end

local function cell_top_left(cx, cy)
    return GRID_X + (cx - 1) * CELL_SIZE,
           GRID_Y + (cy - 1) * CELL_SIZE
end

local function in_grid_panel(mx, my)
    return mx >= GRID_X and mx < GRID_X + 10 * CELL_SIZE
       and my >= GRID_Y and my < GRID_Y + 10 * CELL_SIZE
end

local function lerp(a, b, t) return a + (b - a) * t end

-- Board cells (keyed by cell_key) a matrix anchored at pos = { x, y } covers.
local function footprint_of(grid, pos, mat)
    local fp = {}
    for r = 0, mat.rows - 1 do
        for c = 0, mat.cols - 1 do
            local x, y = pos.x + c, pos.y + r
            if grid:in_bounds(x, y) then
                fp[cell_key(x, y)] = {x=x, y=y}
            end
        end
    end
    return fp
end

-- True when the footprints of two matrices share a cell.
local function overlaps(a_pos, a, b_pos, b)
    return a_pos.x < b_pos.x + b.cols and b_pos.x < a_pos.x + a.cols
       and a_pos.y < b_pos.y + b.rows and b_pos.y < a_pos.y + a.rows
end

-- Forgets fired op tiles that footprint fp no longer covers, so they can fire again.
local function rearm_fired(fired, fp)
    for key in pairs(fired) do
        if not fp[key] then fired[key] = nil end
    end
end

-- True for a palette button, or the selection made from it, that is a two-cell
-- tool the player can turn (fixed ones keep their preset facing).
local function is_turnable_tool(tool)
    return tool ~= nil and tool.kind == "op" and not tool.fixed and Ops.is_two_cell(tool.op)
end

local function is_two_cell_tile(tile)
    return tile ~= nil and tile.kind == "op" and Ops.is_two_cell(tile.op)
end

-- ── Constructor ────────────────────────────────────────────────────────────

function MatrixScene.new(puzzle_index, scene_manager, settings_state, back_scene)
    local base = Scene.new(1280, 720)
    local self  = setmetatable(base, MatrixScene)
    self._start_puzzle    = puzzle_index or 1
    self._scene_manager   = scene_manager
    self._settings_state  = settings_state
    self._back_scene      = back_scene
    return self
end

function MatrixScene.new_from_def(puzzle_def, scene_manager, back_scene, settings_state)
    local base = Scene.new(1280, 720)
    local self  = setmetatable(base, MatrixScene)
    self._start_puzzle    = nil
    self._custom_puzzle   = puzzle_def
    self._scene_manager   = scene_manager
    self._settings_state  = settings_state
    self._back_scene      = back_scene
    return self
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────

function MatrixScene:on_enter()
    self._settings_menu = SettingsMenu.new(self._settings_state, self._scene_manager, function()
        self:_leave()
    end)
    self.palette      = Palette.new()
    self.hud          = HUD.new(HUD_X, 0, HUD_W, BAR_Y)
    self.font_cell    = love.graphics.newFont(14)
    self.font_ui      = love.graphics.newFont(11)
    self.font_key     = love.graphics.newFont(11)
    self.font_val     = love.graphics.newFont(13)
    self.run_speed    = 0.35
    self.anim_from_x  = 0;  self.anim_from_y = 0
    self.anim_to_x    = 0;  self.anim_to_y   = 0
    self.anim_t       = 1
    self.anim_ready   = false
    self._drag_tile   = nil
    self._drag_origin = nil
    self._drag_ghost  = nil
    self._drag_grab   = nil   -- "R" when a two-cell tile is held by its right operand
    self._drag_facing = nil   -- its facing when picked up
    self._mouse       = nil   -- last logical mouse position (for the T key)

    self:load_puzzle(self._start_puzzle)

    local Sound = require("lua/core/sound")
    Sound.fade_music("menu", 0, 2)
    local _bgs = {"bg1","bg2","bg3","bg4"}
    self._bg_track = _bgs[math.random(#_bgs)]
    self._prev_bg_track = self._bg_track
    Sound.fade_music(self._bg_track, 1, 2)
end

function MatrixScene:on_exit()
    self.drawer:clear()
    local Sound = require("lua/core/sound")
    for _, n in ipairs({"bg1","bg2","bg3","bg4"}) do
        Sound.stop_music(n)
    end
end

-- Leaves the puzzle: back to the scene that opened it (editor Test), else level select.
function MatrixScene:_leave()
    if self._back_scene then
        self._scene_manager:switch(self._back_scene)
    else
        local LevelSelectScene = require("lua/game/scenes/level_select_scene")
        self._scene_manager:switch(LevelSelectScene.new(self._scene_manager, self._settings_state))
    end
end

-- ── Puzzle management ──────────────────────────────────────────────────────

function MatrixScene:load_puzzle(n)
    if self._custom_puzzle then
        self.puzzle_index = 0
        self.puzzle       = self._custom_puzzle
    else
        self.puzzle_index = math.max(1, math.min(n, PuzzleLoader.count()))
        self.puzzle       = PuzzleLoader.load(self.puzzle_index)
    end
    local p             = self.puzzle
    self.input_matrix   = Matrix.new(p.input.rows,  p.input.cols,  p.input.values)
    local two_sources   = p.source2 ~= nil and p.input2 ~= nil
    self.input2_matrix  = two_sources
        and Matrix.new(p.input2.rows, p.input2.cols, p.input2.values) or nil
    self.target_matrix  = Matrix.new(p.target.rows, p.target.cols, p.target.values)
    self.current_matrix = nil
    self._anim_display_matrix = nil
    self.status         = nil
    self.running        = false
    self.sim            = nil
    self.cur_slot       = nil
    self.timeline       = Timeline.new()
    self.timeline_scroll  = 0      -- first visible tick is timeline_scroll + 1
    self.sel_pusher       = nil    -- selected pusher id (1 = A)
    self.armed_chip       = nil    -- armed instruction ("up".."stop")
    self._palette_scroll  = 0
    self.grid            = Grid.new(p.grid_w, p.grid_h)

    -- Locked puzzle tiles are one cell (any size fields on an entry are ignored),
    -- except the two-cell matrix ops, which are placed last.
    local locked = p.locked or {}
    local pusher_ids = Sim.assign_pusher_ids(locked)
    local two_cell = {}
    for _, t in ipairs(locked) do
        if t.kind == "op" and Ops.is_two_cell(t.op) then
            two_cell[#two_cell + 1] = t
        elseif t.kind ~= "pusher" or pusher_ids[t] then
            self.grid:set(t.x, t.y, {
                kind   = t.kind,
                dir    = t.dir,
                op     = t.op,
                id     = pusher_ids[t],
                params = Ops.params(t.op, t.params),
                locked = true,
            })
        end
    end
    local function put_source(at, input, index)
        self.grid:set_multi_2d(at.x, at.y, {
            kind="source", locked=true, width=input.cols, height=input.rows, index=index
        }, input.cols, input.rows)
    end
    put_source(p.source, p.input, two_sources and 1 or nil)
    if two_sources then put_source(p.source2, p.input2, 2) end
    self.grid:set(p.sink.x,   p.sink.y,   {kind="sink",   locked=true})
    self.gaps = {}
    for _, g in ipairs(p.gaps or {}) do
        self.gaps[g.y] = self.gaps[g.y] or {}
        self.gaps[g.y][g.x] = true
        self.grid:set(g.x, g.y, {kind="gap", locked=true})
    end
    for _, t in ipairs(two_cell) do
        local tile = { kind="op", op=t.op, params=Ops.params(t.op, t.params), locked=true }
        if self.grid:fits(t.x, t.y, tile) then self.grid:put(t.x, t.y, tile) end
    end
    self.occupied_ops = {}
    self._last_fp     = {}
    self:_clear_pair_state()
    self._tool_facing = {}
    for _, op in ipairs(Ops.MATRIX_ORDER) do self._tool_facing[op] = Ops.params(op).facing end
    self:_build_palette()
    self:_sync_pushers()
end

-- Ops column (left, two buttons wide, scrolls by rows). Positions are computed here, never in
-- draw, so the registry, hit-testing and drawing all read the same rects. Constants only.
local PAL_LEFT      = 8
local PAL_STEP      = 56    -- 48 wide + 8 gap (both axes)
local PAL_BTN_W     = 48
local PAL_BTN_H     = 48
local PAL_SEP       = 14    -- extra vertical gap at each separator
local SCROLL_H      = 14
local OPS_TOP       = GRID_Y + SCROLL_H + 4                  -- first button row (28)
local OPS_BOTTOM    = GRID_Y + 520 - SCROLL_H - 4            -- buttons must end by here (512)
local SCROLL_UP_Y   = GRID_Y                                 -- 10..24
local SCROLL_DOWN_Y = GRID_Y + 520 - SCROLL_H                -- 516..530
local SCROLL_BTN_W  = 2 * PAL_BTN_W + (PAL_STEP - PAL_BTN_W) -- spans both button columns (104)

local function palette_id(btn)
    if btn.fixed then return "palette:fixed:" .. btn.op end
    if btn.erase then return "palette:erase" end
    if btn.kind == "op" then return "palette:" .. btn.op end
    return "palette:" .. btn.kind
end

-- Collects every palette item (PALETTE_BUTTONS order, then fixed ops) with row/col and the
-- separator offset (px) accumulated before it. Each separator starts a new row.
function MatrixScene:_build_palette()
    local allowed
    if self.puzzle.ops then
        allowed = {}
        for _, op in ipairs(self.puzzle.ops) do allowed[op] = true end
    end
    local fixed_allowed = {}
    local items, sep_px, pending = {}, 0, false
    local row, k = 0, 0   -- k = items placed in the current group
    local function push(btn)
        if pending then
            sep_px = sep_px + PAL_SEP
            pending = false
            if k > 0 then row = row + 1 end
            k = 0
        elseif k > 0 and k % 2 == 0 then
            row = row + 1
        end
        items[#items + 1] = { id = palette_id(btn), btn = btn, sep = sep_px, row = row, col = k % 2 }
        k = k + 1
    end
    for _, btn in ipairs(PALETTE_BUTTONS) do
        if btn.sep then
            pending = true
        elseif not btn.op or (allowed and allowed[btn.op])
            or (not allowed and not Ops.is_two_cell(btn.op)) then
            -- Two-cell ops are offered only when the puzzle lists them.
            push(btn)
        end
    end
    if self.puzzle.fixed_ops and #self.puzzle.fixed_ops > 0 then
        pending = true
        -- An entry is an op id, or { op=, params= } to preset the placed tiles.
        for _, entry in ipairs(self.puzzle.fixed_ops) do
            local op, params = entry, nil
            if type(entry) == "table" then op, params = entry.op, entry.params end
            if Ops.is_op(op) then
                fixed_allowed[op] = true
                push({ kind="op", op=op, label=Ops.fixed_label(op, params),
                       params=Ops.params(op, params), fixed=true })
            end
        end
    end
    self._palette_items  = items
    self._palette_scroll = 0
    self:_layout_palette()

    local sel = self.palette:selected()
    if sel and sel.kind == "op" and Ops.is_two_cell(sel.op) then
        -- Keep a matrix tool only when this puzzle has its button.
        local id, kept = palette_id(sel), nil
        for _, it in ipairs(items) do
            if it.id == id then kept = it.btn end
        end
        if kept then self:_palette_select(kept) else self.palette:select(nil) end
    elseif sel and sel.kind == "op" and allowed and not allowed[sel.op] then
        if not fixed_allowed[sel.op] then self.palette:select(nil) end
    end
    self:_build_cmd_buttons()
end

-- Rebuilds _palette_rects (visible buttons, plus up/down arrows when the column overflows)
-- for the current _palette_scroll (a row index). _btn_rects stays the full item list.
function MatrixScene:_layout_palette()
    local items = self._palette_items or {}
    local n     = #items
    -- Separator offset of the first item in each row (rows are contiguous from 0).
    local row_sep, last_row = {}, 0
    for _, it in ipairs(items) do
        if row_sep[it.row] == nil then row_sep[it.row] = it.sep end
        last_row = it.row
    end
    local function y_of(it, scroll)
        return OPS_TOP + (it.row - scroll) * PAL_STEP + it.sep - row_sep[scroll]
    end
    local fits = n == 0 or (OPS_TOP + last_row * PAL_STEP + items[n].sep + PAL_BTN_H <= OPS_BOTTOM)

    -- Largest scroll (in rows) that still shows the last item.
    local max_scroll = 0
    if not fits then
        while max_scroll < last_row and y_of(items[n], max_scroll) + PAL_BTN_H > OPS_BOTTOM do
            max_scroll = max_scroll + 1
        end
    end
    local scroll = math.max(0, math.min(self._palette_scroll or 0, max_scroll))
    self._palette_scroll     = scroll
    self._palette_max_scroll = max_scroll

    local rects = {}
    local function add(id, x, y, w, h, btn, enabled)
        rects[#rects + 1] = { id=id, x=x, y=y, w=w, h=h, btn=btn, enabled=enabled }
    end
    if not fits then
        add("palette:scroll_up", PAL_LEFT, SCROLL_UP_Y, SCROLL_BTN_W, SCROLL_H,
            { kind="scroll", dir=-1, label="^" }, scroll > 0)
    end
    for _, it in ipairs(items) do
        if it.row >= scroll then
            local y = y_of(it, scroll)
            if y + PAL_BTN_H <= OPS_BOTTOM then
                add(it.id, PAL_LEFT + it.col * PAL_STEP, y, PAL_BTN_W, PAL_BTN_H, it.btn)
            end
        end
    end
    if not fits then
        add("palette:scroll_down", PAL_LEFT, SCROLL_DOWN_Y, SCROLL_BTN_W, SCROLL_H,
            { kind="scroll", dir=1, label="v" }, scroll < max_scroll)
    end
    self._palette_rects = rects
    self._btn_rects     = items
end

-- Scrolls the ops column by dir (-1/+1) rows when that arrow is enabled.
function MatrixScene:_palette_scroll_by(dir)
    local s = (self._palette_scroll or 0) + dir
    if s < 0 or s > (self._palette_max_scroll or 0) then return end
    self._palette_scroll = s
    self:_layout_palette()
end

function MatrixScene:_build_cmd_buttons()
    self._cmd_btn_rects = {}
    for i, btn in ipairs(CMD_BUTTONS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        self._cmd_btn_rects[i] = {
            id           = btn.id,
            label        = btn.label,
            color_fill   = btn.color_fill,
            color_border = btn.color_border,
            x            = CMD_BTN_X + col * (CMD_BTN_W + CMD_BTN_GAP),
            y            = CMD_BTN_Y + row * (CMD_BTN_H + CMD_BTN_GAP),
            w            = CMD_BTN_W,
            h            = CMD_BTN_H,
        }
    end
end

-- Run state that only matters with a second matrix or a two-cell tile.
function MatrixScene:_clear_pair_state()
    self.second_matrix  = nil
    self.second_fired   = {}
    self._second_fp     = {}
    self._tag           = 1       -- border colour (source) of the primary matrix
    self.disarmed       = {}      -- two-cell tiles ignored until the result leaves them
    self.status_message = nil     -- banner text overriding the status label
    self._anim_second   = nil     -- the second matrix's slide in the current tick
    self._anim_tag      = nil
    self._anim_merged   = nil     -- the current tick merged the two matrices
end

function MatrixScene:do_reset()
    self.current_matrix = nil
    self._anim_display_matrix = nil
    self.status         = nil
    self.running        = false
    self.sim            = nil
    self.cur_slot        = nil
    self.timeline_scroll = 0
    self.occupied_ops   = {}
    self._last_fp       = {}
    self:_clear_pair_state()
    self.anim_t         = 1
    self.anim_ready     = false
    self:_clear_drag()   -- a held tile goes back to the board
    self:_sync_pushers() -- it may be a pusher, which can be selected again
end

-- Forgets the Mv drag without touching the board.
function MatrixScene:_end_drag()
    self._drag_tile   = nil
    self._drag_origin = nil
    self._drag_ghost  = nil
    self._drag_grab   = nil
    self._drag_facing = nil
end

-- Cancels an Mv drag: the tile returns to where, and how, it was picked up.
function MatrixScene:_clear_drag()
    local tile = self._drag_tile
    if tile and self._drag_origin then
        if self._drag_facing then tile.params.facing = self._drag_facing end
        self.grid:put(self._drag_origin.x, self._drag_origin.y, tile)
    end
    self:_end_drag()
end

-- Returns a table keyed by cell_key for every board cell the primary matrix covers.
function MatrixScene:get_footprint()
    local mat  = self.current_matrix
    if not mat or not self.sim then return {} end
    return footprint_of(self.grid, self.sim, mat)
end

function MatrixScene:_snap_anim_to_matrix()
    if self.sim then
        local px, py = cell_top_left(self.sim.x, self.sim.y)
        self.anim_from_x=px; self.anim_from_y=py
        self.anim_to_x=px;   self.anim_to_y=py
        self.anim_t = 1
    end
end

function MatrixScene:start_run()
    local p             = self.puzzle
    self.current_matrix = self.input_matrix:copy()
    self._anim_display_matrix = nil
    self.sim            = { x=p.source.x, y=p.source.y, tick=0, idle=0,
                            pushers=self:_pusher_list(), gaps=self.gaps }
    self.status          = "running"
    self.running         = true
    self.occupied_ops    = {}
    self._last_fp        = {}
    self:_clear_pair_state()
    if self.input2_matrix then
        self.second_matrix = self.input2_matrix:copy()
        self.sim.second    = { x=p.source2.x, y=p.source2.y }
    end
    self.cur_slot        = nil
    self.timeline_scroll = 0
    self.anim_t          = 1
    self.anim_ready      = true
    self._run_frames     = {}
    if self.sim.second and overlaps(self.sim, self.current_matrix,
                                    self.sim.second, self.second_matrix) then
        self:_end_run("collided")
    else
        -- Ops under the starting footprints fire immediately (the sink is not checked).
        self:_resolve_ops()
    end
    -- After the ops: a merge may have moved the primary to the left operand.
    self:_snap_anim_to_matrix()
end

-- Stops the run with a final status; message overrides the status label in the banner.
function MatrixScene:_end_run(status, message)
    self.running        = false
    self.status         = status
    self.status_message = message
end

function MatrixScene:_count_pieces()
    local count = 0
    for cy = 1, self.grid.h do
        for cx = 1, self.grid.w do
            local is_r = self.grid:is_ref(cx, cy)
            if not is_r then
                local tile = self.grid:get(cx, cy)
                if tile and not tile.locked then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- For one travelling matrix (slot 1, the primary, by default): recomputes the
-- footprint, re-arms op tiles it has left, and fires each newly entered single-cell
-- op tile once. Returns the new footprint, and true when an op ended the run.
function MatrixScene:_process_footprint(old_fp, slot)
    slot = slot or 1
    local names = SLOTS[slot]
    local pos   = slot == 1 and self.sim or self.sim.second
    local mat   = self[names.matrix]
    local fired = self[names.fired]
    local new_fp = footprint_of(self.grid, pos, mat)
    self[names.last] = new_fp
    rearm_fired(fired, new_fp)

    local entered = {}
    for key, cell in pairs(new_fp) do
        if not old_fp[key] and not fired[key] then
            entered[#entered+1] = {x=cell.x, y=cell.y, key=key}
        end
    end
    -- Fire in top-to-bottom, left-to-right order.
    table.sort(entered, function(a, b)
        return a.y < b.y or (a.y == b.y and a.x < b.x)
    end)

    local other_pos, other
    if self.sim.second then
        if slot == 1 then
            other_pos, other = self.sim.second, self.second_matrix
        else
            other_pos, other = self.sim, self.current_matrix
        end
    end

    for _, info in ipairs(entered) do
        local tile = self.grid:get(info.x, info.y)
        -- Two-cell tiles react to coverage by both matrices (_resolve_two_cell).
        if tile and tile.kind == "op" and not Ops.is_two_cell(tile.op) then
            mat = Sim.apply_op(tile, mat)
            fired[info.key] = true
            local failure
            if not Sim.footprint_clear(pos.x, pos.y,
                                       mat.rows, mat.cols,
                                       self.grid.w, self.grid.h,
                                       self.sim.gaps, self.sim.pushers) then
                failure = "blocked"
            elseif other and overlaps(pos, mat, other_pos, other) then
                failure = "collided"
            end
            if failure then
                self[names.matrix] = mat
                self:_end_run(failure)
                return new_fp, true
            end
        end
    end
    self[names.matrix] = mat

    -- An op may have changed the matrix dimensions (e.g. transpose), so the pre-op
    -- new_fp may no longer reflect which cells are covered. Recompute the true footprint
    -- and re-arm any occupied op that the post-op matrix no longer overlaps.
    local actual_fp = footprint_of(self.grid, pos, mat)
    rearm_fired(fired, actual_fp)
    self[names.last] = actual_fp
    return actual_fp, false
end

-- Fires the two-cell tiles for the matrices where they now are, merging the two into
-- the result when a tile has one on each cell. Returns ok (false: the run ended) and
-- merged.
function MatrixScene:_resolve_two_cell()
    local sim   = self.sim
    local tiles = self.grid:two_cell_tiles()
    local a = { x = sim.x, y = sim.y, matrix = self.current_matrix }
    local b = sim.second
        and { x = sim.second.x, y = sim.second.y, matrix = self.second_matrix }
    -- Tiles are only disarmed after a merge, when the primary is the one matrix left.
    TwoCell.rearm(self.disarmed, tiles, a)
    local verdict = TwoCell.judge(tiles, a, b, self.disarmed)
    if not verdict then return true, false end
    if verdict.status then
        self:_end_run(verdict.status, verdict.message)
        return false, false
    end

    -- The result takes the left operand's place; the right operand is consumed.
    local left, result = verdict.left, verdict.matrix
    if not Sim.footprint_clear(left.x, left.y, result.rows, result.cols,
                               self.grid.w, self.grid.h, sim.gaps, sim.pushers) then
        self:_end_run("blocked")
        return false, false
    end
    if left == b then
        self.occupied_ops = self.second_fired
        self._tag         = 2
    end
    sim.x, sim.y, sim.second = left.x, left.y, nil
    self.current_matrix = result
    self.second_matrix  = nil
    self.second_fired   = {}
    self._second_fp     = {}
    -- Single-cell tiles newly under the result wait until it leaves and re-enters.
    self._last_fp = self:get_footprint()
    rearm_fired(self.occupied_ops, self._last_fp)
    TwoCell.disarm(self.disarmed, tiles, { x = sim.x, y = sim.y, matrix = result })
    return true, true
end

-- The op part of a tick: single-cell ops (source 1's matrix fully, then source 2's),
-- then two-cell tiles. Stops at the first failure. Returns ok, merged.
function MatrixScene:_resolve_ops()
    local _, failed = self:_process_footprint(self._last_fp, 1)
    if not failed and self.sim.second then
        _, failed = self:_process_footprint(self._second_fp, 2)
    end
    if failed then return false, false end
    return self:_resolve_two_cell()
end

-- Pushers on the board, ordered by letter id.
function MatrixScene:_pusher_list()
    local list = {}
    for y = 1, self.grid.h do
        for x = 1, self.grid.w do
            local t = self.grid:get(x, y)
            if t and t.kind == "pusher" then
                list[#list+1] = {x=x, y=y, id=t.id}
            end
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function MatrixScene:do_step()
    if not self.sim then self:start_run(); return end

    local sim  = self.sim
    local grid = self.grid
    local mat  = self.current_matrix
    local from_x, from_y = cell_top_left(sim.x, sim.y)

    local pushers_from = {}
    for _, p in ipairs(sim.pushers) do
        local px, py = cell_top_left(p.x, p.y)
        pushers_from[#pushers_from + 1] = { id = p.id, px = px, py = py }
    end

    local st = {
        x=sim.x, y=sim.y, rows=mat.rows, cols=mat.cols,
        w=grid.w, h=grid.h, pushers=sim.pushers,
        tick=sim.tick, gaps=sim.gaps,
    }
    -- The second matrix's slide this tick: its pre-op values and pixel path.
    local second
    if sim.second then
        local m = self.second_matrix
        st.second = { x=sim.second.x, y=sim.second.y, rows=m.rows, cols=m.cols }
        local px, py = cell_top_left(sim.second.x, sim.second.y)
        second = { matrix = m, from_x = px, from_y = py }
    end
    local moved, blocked, collided = Sim.advance(st, Timeline.column(self.timeline, sim.tick + 1))
    if blocked then
        self:_end_run(collided and "collided" or "blocked")
        return
    end
    sim.x, sim.y, sim.tick = st.x, st.y, st.tick
    if second then
        sim.second.x, sim.second.y = st.second.x, st.second.y
        second.to_x, second.to_y   = cell_top_left(sim.second.x, sim.second.y)
    end
    sim.idle     = moved and 0 or sim.idle + 1
    self.cur_slot = sim.tick
    self:_follow_tick(sim.tick)

    local to_x, to_y = cell_top_left(sim.x, sim.y)
    -- Ops fire on entry, but the matrices slide in with their pre-op values (as in the recap).
    local tag = self._tag or 1
    self._anim_display_matrix = mat
    self._anim_tag            = tag
    self._anim_second         = second
    local ok, merged          = self:_resolve_ops()
    self._anim_merged         = merged

    if self._run_frames then
        local pushers_to = {}
        for _, p in ipairs(sim.pushers) do
            local px, py = cell_top_left(p.x, p.y)
            pushers_to[#pushers_to + 1] = { id = p.id, px = px, py = py }
        end
        local frame = {
            from_x       = from_x,       from_y       = from_y,
            to_x         = to_x,         to_y         = to_y,
            matrix       = mat:copy(),
            tag          = tag,
            pushers_from = pushers_from,
            pushers_to   = pushers_to,
        }
        if second then
            frame.second = {
                from_x = second.from_x, from_y = second.from_y,
                to_x   = second.to_x,   to_y   = second.to_y,
                matrix = second.matrix:copy(), tag = 2,
            }
        end
        if merged then
            local px, py = cell_top_left(sim.x, sim.y)
            frame.merged = { x = px, y = py, matrix = self.current_matrix:copy(), tag = self._tag }
        end
        self._run_frames[#self._run_frames + 1] = frame
    end

    -- An op failure is final. Otherwise any matrix cell on the sink ends the run.
    local stuck = false
    if ok then
        local key = cell_key(self.puzzle.sink.x, self.puzzle.sink.y)
        if self._last_fp[key] or (sim.second and self._second_fp[key]) then
            if sim.second then
                self:_end_run("uncombined")
            else
                self:_end_run(self.current_matrix:equals(self.target_matrix) and "win" or "fail")
            end
        elseif sim.tick > Timeline.last_tick(self.timeline) and not moved then
            stuck = true
            self:_end_run("stuck")
        end
    end

    -- Animate the step in (a final one too: running=false prevents further steps).
    -- A stuck tick moved nothing, so it is shown settled.
    if stuck then
        self.anim_from_x=to_x; self.anim_from_y=to_y
    else
        self.anim_from_x=from_x; self.anim_from_y=from_y
    end
    self.anim_to_x=to_x; self.anim_to_y=to_y
    self.anim_t     = stuck and 1 or 0
    self.anim_ready = false
end

-- ── Update ─────────────────────────────────────────────────────────────────

function MatrixScene:update(dt)
    local Sound = require("lua/core/sound")
    if self._bg_track and not Sound.is_music_playing(self._bg_track) then
        local _bgs = {"bg1","bg2","bg3","bg4"}
        local next_track
        repeat
            next_track = _bgs[math.random(#_bgs)]
        until #_bgs == 1 or next_track ~= self._prev_bg_track
        self._prev_bg_track = self._bg_track
        self._bg_track = next_track
        Sound.fade_music(self._bg_track, 1, 1)
    end
    if self._settings_menu and self._settings_menu.is_open then
        self._settings_menu:update(dt)
        return
    end
    if self.anim_t < 1 then
        self.anim_t = math.min(1, self.anim_t + dt / self.run_speed)
        if self.anim_t >= 1 and self.running then
            self.anim_ready = true
        end
    end
    if self.running and self.anim_ready then
        self.anim_ready = false
        self:do_step()
    end
end

-- ── Draw helpers ───────────────────────────────────────────────────────────

function MatrixScene:draw_grid()
    love.graphics.setColor(0.08, 0.08, 0.13, 1)
    love.graphics.rectangle("fill", 0, 0, HUD_X, BAR_Y)

    -- Pass 1: checkerboard backgrounds and grid lines
    for cy = 1, 10 do
        for cx = 1, 10 do
            local sx, sy = cell_top_left(cx, cy)
            if (cx + cy) % 2 == 0 then
                love.graphics.setColor(0.10, 0.10, 0.15, 1)
            else
                love.graphics.setColor(0.11, 0.11, 0.17, 1)
            end
            love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
            love.graphics.setColor(0.20, 0.20, 0.30, 1)
            love.graphics.rectangle("line", sx, sy, CELL_SIZE, CELL_SIZE)
            local tile_raw = self.grid.cells[cy][cx]
            if tile_raw and tile_raw.kind == "gap" then
                love.graphics.setColor(0.04, 0.04, 0.06, 1)
                love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
                love.graphics.setColor(0.3, 0.1, 0.1, 1)
                love.graphics.rectangle("line", sx, sy, CELL_SIZE, CELL_SIZE)
            end
        end
    end

    -- Pass 2: source ref cells fill in first, so they cannot cover a source label.
    -- (A two-cell tile's ref cell is drawn by its anchor.)
    for cy = 1, 10 do
        for cx = 1, 10 do
            if self.grid:is_ref(cx, cy) and self.grid:get(cx, cy).kind ~= "op" then
                self:draw_ref_cell(cx, cy)
            end
        end
    end

    -- Pass 3: tile content. A source anchor draws its label across its full span.
    for cy = 1, 10 do
        for cx = 1, 10 do
            if not self.grid:is_ref(cx, cy) then
                local tile = self.grid:get(cx, cy)
                if tile then self:draw_tile(tile, cx, cy) end
            end
        end
    end

    -- Ghost preview while dragging
    local pair, ax, ay = self:_two_cell_preview()
    if pair then
        self:_draw_two_cell_preview(pair, ax, ay)
    elseif self._drag_tile and self._drag_ghost then
        local tile = self._drag_tile
        local gx, gy = self._drag_ghost.cx, self._drag_ghost.cy
        local label
        if tile.kind == "pusher" then
            label = string.char(64 + (tile.id or 1))
        else
            label = Ops.tile_text(tile.op, tile.params)
        end
        self:_draw_ghost_cell(gx, gy, self:_can_drop(gx, gy), label)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- One cell of a drag preview: green when the drop is valid, red when not.
function MatrixScene:_draw_ghost_cell(cx, cy, valid, label)
    local sx, sy = cell_top_left(cx, cy)
    if valid then
        love.graphics.setColor(0.14, 0.35, 0.14, 1)
    else
        love.graphics.setColor(0.35, 0.14, 0.14, 1)
    end
    love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
    love.graphics.setColor(valid and 0.34 or 0.74, valid and 0.74 or 0.26, valid and 0.34 or 0.26, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx + 1, sy + 1, CELL_SIZE - 2, CELL_SIZE - 2)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.82, 0.82, 0.82, 1)
    love.graphics.setFont(self.font_cell)
    love.graphics.printf(label, sx, sy + CELL_SIZE / 2 - 8, CELL_SIZE, "center")
end

-- The two-cell tile a drag (Mv or from the palette) would drop now, as
-- tile, x, y (its left-operand cell); nil when there is none over the board.
function MatrixScene:_two_cell_preview()
    local ghost = self._drag_ghost
    if is_two_cell_tile(self._drag_tile) and ghost then
        return self._drag_tile, self:_drop_anchor(ghost.cx, ghost.cy)
    end
    local d = self._dnd
    local btn = d and d.btn
    if self.running or not (btn and d.moved and btn.kind == "op" and Ops.is_two_cell(btn.op)) then
        return nil
    end
    local cx, cy = screen_to_cell(d.x, d.y)
    if not self.grid:in_bounds(cx, cy) then return nil end
    local facing = btn.fixed and btn.params.facing or self._tool_facing[btn.op]
    return { kind = "op", op = btn.op, params = { facing = facing } }, cx, cy
end

-- Both cells (those on the board), each naming its operand.
function MatrixScene:_draw_two_cell_preview(tile, ax, ay)
    local valid = self.grid:fits(ax, ay, tile)
    local rx, ry = Ops.partner(ax, ay, tile.params.facing)
    for _, cell in ipairs({ { "L", ax, ay }, { "R", rx, ry } }) do
        if self.grid:in_bounds(cell[2], cell[3]) then
            self:_draw_ghost_cell(cell[2], cell[3], valid, cell[1] .. " " .. Ops.label(tile.op))
        end
    end
end

function MatrixScene:draw_pusher(id, sx, sy, ghost, dir)
    local cs, a = CELL_SIZE, ghost and 0.20 or 1
    love.graphics.setColor(0.30, 0.18, 0.45, a)
    love.graphics.rectangle("fill", sx + 4, sy + 4, cs - 8, cs - 8, 6, 6)
    love.graphics.setColor(0.80, 0.60, 1.0, ghost and 0.35 or 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx + 4, sy + 4, cs - 8, cs - 8, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.font_cell)
    love.graphics.printf(string.char(64 + (id or 1)), sx, sy + cs / 2 - 8, cs, "center")
    if not ghost then
        if dir and dir ~= "stop" and CMD_GLYPH[dir] then
            love.graphics.setColor(1, 0.9, 0.4, 1)
            love.graphics.setFont(self.font_val)
            love.graphics.printf(CMD_GLYPH[dir], sx, sy + cs - 22, cs, "center")
        end
    end
end

function MatrixScene:draw_live_pushers()
    if not self.sim then return end
    for _, p in ipairs(self.sim.pushers) do
        local sx, sy = cell_top_left(p.x, p.y)
        self:draw_pusher(p.id, sx, sy, false, p.dir)
    end
end

-- Fills one of a source tile's non-anchor cells.
function MatrixScene:draw_ref_cell(cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    love.graphics.setColor(0.09, 0.29, 0.17, 1)
    love.graphics.rectangle("fill", sx, sy, CELL_SIZE, CELL_SIZE)
end

-- draw_tile takes cell coordinates; the source draws a background spanning its cells.
function MatrixScene:draw_tile(tile, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs     = CELL_SIZE
    local mid_y  = sy + cs / 2

    if tile.kind == "source" then
        local span_w = (tile.width  or 1) * cs
        local span_h = (tile.height or 1) * cs
        love.graphics.setColor(0.09, 0.29, 0.17, 1)
        love.graphics.rectangle("fill", sx, sy, span_w, span_h)
        love.graphics.setColor(0.4, 1.0, 0.5, 1)
        love.graphics.setFont(self.font_cell)
        local label = tile.index and ("SRC " .. tile.index) or "SRC"
        love.graphics.printf(label, sx, sy + span_h / 2 - 7, span_w, "center")

    elseif tile.kind == "sink" then
        love.graphics.setColor(0.09, 0.19, 0.42, 1)
        love.graphics.rectangle("fill", sx, sy, cs, cs)
        love.graphics.setColor(0.5, 0.75, 1.0, 1)
        love.graphics.setFont(self.font_cell)
        love.graphics.printf("SINK", sx, mid_y - 7, cs, "center")

    elseif tile.kind == "pusher" then
        -- During a run the placed tile only marks the start; the live pusher is drawn separately.
        self:draw_pusher(tile.id, sx, sy, self.sim ~= nil)

    elseif tile.kind == "gap" then
        love.graphics.setColor(0.5, 0.15, 0.15, 1)
        love.graphics.setFont(self.font_cell)
        love.graphics.printf("×", sx, mid_y - 8, cs, "center")

    elseif tile.kind == "op" then
        local immutable = (tile.fixed or tile.locked) and true or false
        OpTile.draw(tile, sx, sy, cs, { cell = self.font_cell, ui = self.font_ui },
            { marks = not immutable, immutable = immutable })
    end

    if tile.locked and tile.kind ~= "gap" then
        love.graphics.setColor(0.50, 0.50, 0.50, 1)
        love.graphics.circle("fill", sx + cs - 8, sy + 7, 3)
        love.graphics.rectangle("fill", sx + cs - 10, sy + 7, 4, 5)
    end
    if tile.fixed then
        love.graphics.setColor(0.42, 0.62, 0.83, 1)
        love.graphics.setFont(self.font_ui)
        love.graphics.printf("=", sx + cs - 14, sy + 4, 12, "right")
    end
end

-- The matrix the player sees: pre-op values while sliding into an op, post-op once settled.
function MatrixScene:_display_matrix()
    if self.anim_t < 1 and self._anim_display_matrix then
        return self._anim_display_matrix
    end
    return self.current_matrix
end

-- The matrices on screen now, primary first: { matrix, px, py (drawn top-left),
-- x, y (logical cell), tag, preview }. Idle, these are the inputs at their sources;
-- while sliding, the pre-op matrices headed for their new cells.
function MatrixScene:_shown_matrices()
    local out = {}
    local mat = self:_display_matrix()
    if not mat then
        if self.sim == nil and self.input_matrix then
            local function preview(m, at, tag)
                local px, py = cell_top_left(at.x, at.y)
                out[#out + 1] = { matrix = m, px = px, py = py, x = at.x, y = at.y,
                                  tag = tag, preview = true }
            end
            preview(self.input_matrix, self.puzzle.source, 1)
            if self.input2_matrix then preview(self.input2_matrix, self.puzzle.source2, 2) end
        end
        return out
    end

    local t  = self.anim_t
    local et = t * t * (3 - 2 * t)  -- smooth-step
    local sliding = t < 1 and self._anim_display_matrix ~= nil

    local first = { matrix = mat, tag = self._tag or 1,
                    px = lerp(self.anim_from_x, self.anim_to_x, et),
                    py = lerp(self.anim_from_y, self.anim_to_y, et) }
    if sliding then
        first.tag = self._anim_tag or first.tag
        first.x, first.y = screen_to_cell(self.anim_to_x, self.anim_to_y)
    elseif self.sim then
        first.x, first.y = self.sim.x, self.sim.y
        -- A merge result appears at the left operand, wherever the primary slid to.
        if self._anim_merged then first.px, first.py = cell_top_left(first.x, first.y) end
    else
        first.x, first.y = screen_to_cell(self.anim_to_x, self.anim_to_y)
    end
    out[1] = first

    local slide = sliding and self._anim_second
    if slide then
        local x, y = screen_to_cell(slide.to_x, slide.to_y)
        out[2] = { matrix = slide.matrix, tag = 2, x = x, y = y,
                   px = lerp(slide.from_x, slide.to_x, et),
                   py = lerp(slide.from_y, slide.to_y, et) }
    elseif not sliding and self.sim and self.sim.second then
        local at = self.sim.second
        local px, py = cell_top_left(at.x, at.y)
        out[2] = { matrix = self.second_matrix, tag = 2, x = at.x, y = at.y, px = px, py = py }
    end
    return out
end

-- Each matrix element covers one board cell.
function MatrixScene:_draw_matrix_cells(body)
    local mat, border = body.matrix, MATRIX_BORDER[body.tag]
    local dim = body.preview and PREVIEW_DIM or 1
    for r = 1, mat.rows do
        for c = 1, mat.cols do
            local cx = body.px + (c - 1) * CELL_SIZE
            local cy = body.py + (r - 1) * CELL_SIZE
            local v  = mat.values[r][c]

            if body.preview then
                love.graphics.setColor(0.11, 0.11, 0.17, 1)
            else
                love.graphics.setColor(0.08, 0.08, 0.15, 1)
            end
            love.graphics.rectangle("fill", cx, cy, CELL_SIZE, CELL_SIZE)

            love.graphics.setColor(border[1] * dim, border[2] * dim, border[3] * dim, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx+1, cy+1, CELL_SIZE-2, CELL_SIZE-2)
            love.graphics.setLineWidth(1)

            local s
            if v == math.floor(v) then s = tostring(math.floor(v))
            else s = string.format("%.1f", v) end
            if body.preview then
                love.graphics.setColor(0.50, 0.50, 0.53, 1)
            else
                love.graphics.setColor(0.95, 0.95, 1.0, 1)
            end
            love.graphics.setFont(self.font_cell)
            love.graphics.printf(s, cx, cy + CELL_SIZE / 2 - 9, CELL_SIZE, "center")
        end
    end
end

-- An idle preview hides its source tile's label, so with two sources each preview
-- carries a tag at the top of its first cell, clear of the value.
function MatrixScene:_draw_source_tag(body)
    local x, y = body.px + (CELL_SIZE - SRC_TAG_W) / 2, body.py + 3
    local border = MATRIX_BORDER[body.tag]
    love.graphics.setColor(0.04, 0.04, 0.06, 1)
    love.graphics.rectangle("fill", x, y, SRC_TAG_W, SRC_TAG_H)
    love.graphics.setColor(border[1], border[2], border[3], 1)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf("SRC " .. body.tag, x, y, SRC_TAG_W, "center")
end

function MatrixScene:draw_travelling_matrix()
    local shown = self:_shown_matrices()
    for _, body in ipairs(shown) do
        self:_draw_matrix_cells(body)
        if body.preview and self.input2_matrix then self:_draw_source_tag(body) end
    end

    OpTile.draw_covered_badges(self.grid:two_cell_tiles(), shown, cell_top_left,
                               CELL_SIZE, self.font_ui)

    love.graphics.setColor(1, 1, 1, 1)
end

-- Single source of truth for command enabled state (buttons, clicks, keys, registry).
function MatrixScene:_cmd_enabled(id)
    if id == "run" then
        return not self.running and self.status ~= "running" and self.status ~= "win"
    elseif id == "continue" then
        return self.status == "win"
    elseif id == "reset" then
        return self.sim ~= nil or self.status ~= nil
    elseif id == "menu" then
        return true
    end
    return false
end

-- Performs a command's action. Callers check _cmd_enabled first.
function MatrixScene:_cmd_activate(id)
    if id == "run" then
        if #self:_pusher_list() == 0 then
            self.status = "no_pusher"
            self.status_message = nil
        else
            self:start_run()
        end
    elseif id == "continue" then
        if self._scene_manager then
            -- Editor Test: no replay, so a test win records no progress.
            if self._back_scene then
                self:_leave()
                return
            end
            local SolutionRecapScene = require("lua/game/scenes/solution_recap_scene")
            local stats = {
                ticks        = self.sim.tick,
                pieces       = self:_count_pieces(),
                puzzle_name  = self.puzzle.name,
                puzzle_index = self.puzzle_index,
            }
            local board = {
                grid        = self.grid,
                timeline    = self.timeline,
                puzzle      = self.puzzle,
            }
            self._scene_manager:switch(
                SolutionRecapScene.new(stats, board, self._run_frames or {}, self.run_speed, self._scene_manager, self._settings_state)
            )
        end
    elseif id == "reset" then
        self:do_reset()
    elseif id == "menu" then
        if self._scene_manager then
            self:_leave()
        end
    end
end

function MatrixScene:_draw_cmd_buttons()
    if not self._cmd_btn_rects then return end
    for _, r in ipairs(self._cmd_btn_rects) do
        local enabled = self:_cmd_enabled(r.id)
        local cf = r.color_fill   or {0.25, 0.25, 0.40}
        local cb = r.color_border or {0.45, 0.45, 0.65}

        if enabled then
            love.graphics.setColor(cf[1], cf[2], cf[3], 1)
        else
            love.graphics.setColor(cf[1] * 0.5, cf[2] * 0.5, cf[3] * 0.5, 1)
        end
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)

        if enabled then
            love.graphics.setColor(cb[1], cb[2], cb[3], 1)
        else
            love.graphics.setColor(0.14, 0.14, 0.21, 1)
        end
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4, 4)

        if enabled then
            love.graphics.setColor(0.85, 0.85, 0.9, 1)
        else
            love.graphics.setColor(0.4, 0.4, 0.5, 1)
        end
        love.graphics.setFont(self.font_ui)
        love.graphics.printf(r.label, r.x, r.y + math.floor((r.h - 11) / 2) - 1, r.w, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- True when the palette selection is the tool this button represents.
function MatrixScene:_palette_is_selected(btn)
    local sel = self.palette:selected()
    if sel == nil then return btn.erase == true end
    if btn.kind ~= sel.kind then return false end
    if btn.kind == "pusher" or btn.kind == "drag" then return true end
    if btn.kind == "op" then
        return (btn.op == sel.op) and ((btn.fixed or false) == (sel.fixed or false))
    end
    return false
end

-- The label a palette button shows now: a turnable two-cell tool points towards
-- its right operand.
function MatrixScene:_button_label(btn)
    if is_turnable_tool(btn) then return Ops.tool_label(btn.op, self._tool_facing[btn.op]) end
    return btn.label
end

-- Turns a two-cell tool clockwise.
function MatrixScene:_turn_tool(op)
    self._tool_facing[op] = Ops.next_facing(self._tool_facing[op])
end

-- Applies a palette button click (same semantics as before the registry).
function MatrixScene:_palette_select(btn)
    if btn.erase then
        self.palette:select(nil)
    elseif btn.kind == "pusher" then
        self.palette:select({kind="pusher"})
    elseif btn.kind == "op" then
        self.palette:select({kind="op", op=btn.op, fixed=btn.fixed, params=btn.params})
    elseif btn.kind == "drag" then
        self.palette:select({kind="drag"})
    end
end

function MatrixScene:draw_palette()
    love.graphics.setColor(0.06, 0.06, 0.10, 1)
    -- Ops column background, then the bottom bar background.
    love.graphics.rectangle("fill", 0, 0, OPS_W, BAR_Y)
    love.graphics.setColor(0.04, 0.08, 0.12, 1)
    love.graphics.rectangle("fill", 0, BAR_Y, SCREEN_W, BAR_H)
    love.graphics.setColor(0.2, 0.4, 0.5, 1)
    love.graphics.rectangle("fill", 0, BAR_Y, SCREEN_W, 1)

    for _, rect in ipairs(self._palette_rects) do
        local btn     = rect.btn
        local is_sel  = self:_palette_is_selected(btn)
        local enabled = rect.enabled ~= false

        love.graphics.setColor(enabled and 0.12 or 0.08, enabled and 0.12 or 0.08, enabled and 0.20 or 0.14, 1)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)
        if not enabled then
            love.graphics.setColor(0.14, 0.14, 0.21, 1)
        else
            love.graphics.setColor(is_sel and {0.8,0.9,1.0,1} or {0.3,0.3,0.45,1})
        end
        love.graphics.setLineWidth(is_sel and 2 or 1)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 4, 4)
        love.graphics.setLineWidth(1)
        if enabled then
            love.graphics.setColor(0.85, 0.85, 0.9, 1)
        else
            love.graphics.setColor(0.4, 0.4, 0.5, 1)
        end
        love.graphics.setFont(self.font_ui)
        love.graphics.printf(self:_button_label(btn), rect.x, rect.y + math.floor((rect.h - 11) / 2) - 1, rect.w, "center")
    end

    self:_draw_cmd_buttons()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Draw ───────────────────────────────────────────────────────────────────

-- ── Bottom bar: pusher selector, instruction chips, timeline ───────────────

local function pusher_letter(id) return string.char(64 + id) end

local function rect_el(id, label, kind, x, y, w, h, enabled, selected)
    return { id = id, label = label, kind = kind,
             rect = { x = x, y = y, w = w, h = h },
             enabled = enabled, selected = selected }
end

-- Keeps the selected pusher valid and drops commands of pushers no longer on the board.
function MatrixScene:_sync_pushers()
    local on_board = {}
    local list = self:_pusher_list()
    for _, p in ipairs(list) do on_board[p.id] = true end
    for lane = 1, Timeline.LANES do
        for _, c in pairs(self.timeline[lane]) do
            if not on_board[c.pusher] then Timeline.remove_pusher(self.timeline, c.pusher) end
        end
    end
    if not (self.sel_pusher and on_board[self.sel_pusher]) then
        self.sel_pusher = list[1] and list[1].id or nil
    end
end

function MatrixScene:_tl_max_scroll()
    return math.max(0, Timeline.MAX_TICKS - BAR.VIS)
end

function MatrixScene:_tl_scroll_by(delta)
    self.timeline_scroll = math.max(0, math.min(self:_tl_max_scroll(), (self.timeline_scroll or 0) + delta))
end

-- Scrolls just enough to keep the tick visible.
function MatrixScene:_follow_tick(tick)
    local scroll = self.timeline_scroll or 0
    if tick > scroll + BAR.VIS then
        self.timeline_scroll = tick - BAR.VIS
    elseif tick <= scroll then
        self.timeline_scroll = math.max(0, tick - 1)
    end
    self:_tl_scroll_by(0)
end

-- Screen rect of the slot for (lane, tick), or nil when the tick is scrolled out of view.
function MatrixScene:_slot_rect(lane, tick)
    local col = tick - (self.timeline_scroll or 0) - 1
    if col < 0 or col >= BAR.VIS then return nil end
    return { x = BAR.SLOT_X + col * BAR.SLOT_STEP,
             y = BAR.LANE_Y + (lane - 1) * BAR.LANE_STEP,
             w = BAR.SLOT_W, h = BAR.LANE_H }
end

local function slot_label(c)
    return pusher_letter(c.pusher) .. CMD_GLYPH[c.cmd]
end

function MatrixScene:_bar_elements(out)
    local idle = not self.running
    for i, p in ipairs(self:_pusher_list()) do
        local letter = pusher_letter(p.id)
        out[#out + 1] = rect_el("psel:" .. letter, letter, "button",
            BAR.PANEL_X + (i - 1) * BAR.PSEL_STEP, BAR.PSEL_Y, BAR.PSEL_W, BAR.PSEL_H,
            idle, self.sel_pusher == p.id)
    end
    for i, cmd in ipairs(CHIP_ORDER) do
        out[#out + 1] = rect_el("chip:" .. cmd, CMD_GLYPH[cmd], "button",
            BAR.PANEL_X + (i - 1) * BAR.CHIP_STEP, BAR.CHIP_Y, BAR.CHIP_W, BAR.CHIP_H,
            idle, self.armed_chip == cmd)
    end
    local scroll = self.timeline_scroll or 0
    local lanes_h = (Timeline.LANES - 1) * BAR.LANE_STEP + BAR.LANE_H
    out[#out + 1] = rect_el("tl:scroll_left", "<", "button", BAR.TL_X, BAR.LANE_Y,
        BAR.ARROW_W, lanes_h, scroll > 0)
    out[#out + 1] = rect_el("tl:scroll_right", ">", "button", BAR.TL_RIGHT - BAR.ARROW_W, BAR.LANE_Y,
        BAR.ARROW_W, lanes_h, scroll < self:_tl_max_scroll())
    for lane = 1, Timeline.LANES do
        for col = 1, BAR.VIS do
            local tick = scroll + col
            local r = self:_slot_rect(lane, tick)
            local id = "slot:" .. lane .. ":" .. tick
            out[#out + 1] = rect_el(id, id, "slot", r.x, r.y, r.w, r.h, idle)
        end
    end
end

-- Handles clicks on bottom-bar elements. Returns true when the element belonged to the bar.
function MatrixScene:_bar_click(e, btn)
    local id = e.id
    local kind, a, b = id:match("^(%a+):([%w_]+):?(%d*)$")
    if kind == "psel" then
        if e.enabled and btn == 1 then self.sel_pusher = string.byte(a) - 64 end
    elseif kind == "chip" then
        if e.enabled and btn == 1 then self.armed_chip = a end
    elseif kind == "tl" then
        if e.enabled and btn == 1 then
            self:_tl_scroll_by(a == "scroll_left" and -BAR.PAGE or BAR.PAGE)
        end
    elseif kind == "slot" then
        if not e.enabled then return true end
        local lane, tick = tonumber(a), tonumber(b)
        if btn == 2 then
            Timeline.clear(self.timeline, lane, tick)
        elseif btn == 1 and self.armed_chip == "clear" then
            Timeline.clear(self.timeline, lane, tick)
        elseif btn == 1 and self.armed_chip and self.sel_pusher then
            Timeline.set(self.timeline, lane, tick, self.sel_pusher, self.armed_chip)
        end
    else
        return false
    end
    return true
end

function MatrixScene:_draw_bar()
    love.graphics.setColor(0.07, 0.08, 0.12, 1)
    love.graphics.rectangle("fill", 0, BAR_Y, CMD_BTN_X - 4, BAR_H)
    love.graphics.setFont(self.font_ui)
    for _, e in ipairs(self:ui_elements()) do
        local id, r = e.id, e.rect
        local kind = id:match("^(%a+):")
        if kind == "psel" or kind == "chip" or kind == "tl" then
            local a = e.enabled and 1 or 0.4
            love.graphics.setColor(e.selected and 0.30 or 0.14, e.selected and 0.45 or 0.16, e.selected and 0.20 or 0.24, a)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
            love.graphics.setColor(e.selected and 1 or 0.5, e.selected and 0.9 or 0.55, e.selected and 0.4 or 0.75, a)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4, 4)
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.printf(e.label, r.x, r.y + r.h / 2 - 6, r.w, "center")
        elseif kind == "slot" then
            local lane, tick = id:match("^slot:(%d+):(%d+)$")
            lane, tick = tonumber(lane), tonumber(tick)
            local c = Timeline.get(self.timeline, lane, tick)
            local current = self.sim and self.sim.tick == tick
            love.graphics.setColor(current and 0.35 or 0.12, current and 0.30 or 0.13, current and 0.12 or 0.18, 1)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
            love.graphics.setColor(current and 1 or 0.3, current and 0.9 or 0.35, current and 0.4 or 0.5, 1)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 3, 3)
            if c then
                love.graphics.setColor(1, 0.9, 0.5, 1)
                love.graphics.printf(slot_label(c), r.x, r.y + r.h / 2 - 6, r.w, "center")
            end
        end
    end
    -- Tick-number header
    love.graphics.setColor(0.6, 0.65, 0.8, 1)
    local scroll = self.timeline_scroll or 0
    for col = 1, BAR.VIS do
        love.graphics.printf(tostring(scroll + col), BAR.SLOT_X + (col - 1) * BAR.SLOT_STEP, BAR.HEAD_Y, BAR.SLOT_W, "center")
    end
    love.graphics.print("INSTRUCTIONS", BAR.PANEL_X, BAR_Y + 44)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── UI element registry (see docs/checklists/ui-tests.md, C1/C2) ───────────

local function el(id, label, kind, r, enabled, selected)
    return { id = id, label = label, kind = kind,
             rect = { x = r.x, y = r.y, w = r.w, h = r.h },
             enabled = enabled, selected = selected }
end

function MatrixScene:ui_elements()
    if self._settings_menu and self._settings_menu.is_open then
        return self._settings_menu:ui_elements()
    end
    self:_sync_pushers()
    local out = {}
    for _, r in ipairs(self._palette_rects or {}) do
        local enabled = r.enabled ~= false
        out[#out + 1] = el(r.id, self:_button_label(r.btn), "button", r, enabled,
                           self:_palette_is_selected(r.btn))
    end
    for _, r in ipairs(self._cmd_btn_rects or {}) do
        out[#out + 1] = el("cmd:" .. r.id, r.label, "button", r, self:_cmd_enabled(r.id))
    end
    for y = 1, self.grid.h do
        for x = 1, self.grid.w do
            local sx, sy = cell_top_left(x, y)
            local id = "cell:" .. x .. "," .. y
            out[#out + 1] = el(id, id, "cell", { x = sx, y = sy, w = CELL_SIZE, h = CELL_SIZE }, true)
        end
    end
    self:_bar_elements(out)
    return out
end

local function plain_rows(m)
    local rows = {}
    for r = 1, m.rows do
        rows[r] = {}
        for c = 1, m.cols do rows[r][c] = m.values[r][c] end
    end
    return rows
end

-- C6 query: matrix values currently shown, as plain rows (the primary matrix).
function MatrixScene:ui_matrix()
    return plain_rows(self:_display_matrix() or self.input_matrix)
end

-- C6 query: every matrix shown now, primary first, as { x, y, values } where x,y is
-- the logical grid cell of its top-left.
function MatrixScene:ui_matrices()
    local out = {}
    for _, body in ipairs(self:_shown_matrices()) do
        out[#out + 1] = { x = body.x, y = body.y, values = plain_rows(body.matrix) }
    end
    return out
end

-- C6 query: timeline slot content at (lane, tick), or nil when empty.
function MatrixScene:ui_slot(lane, tick)
    return Timeline.get(self.timeline, lane, tick)
end

-- C6 query: tile at a grid cell (ref cells resolve to their anchor tile), or nil.
function MatrixScene:ui_tile(x, y)
    if not self.grid:in_bounds(x, y) then return nil end
    local tile = self.grid:get(x, y)
    if tile == nil then return nil end
    local params = tile.params or {}
    return { kind = tile.kind, op = tile.op, dir = tile.dir,
             edge = params.edge, scalar = params.scalar,
             facing = params.facing, index = tile.index }
end

function MatrixScene:_draw_status_banner()
    local col = self.status and STATUS_COLORS[self.status]
    if not col then return end
    local bh = 40
    local by = BAR_Y - bh
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.rectangle("fill", OPS_W, by, HUD_X - OPS_W, bh)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.font_ui)
    local text = self.status_message or STATUS_LABELS[self.status] or self.status
    love.graphics.printf(text, OPS_W, by + 13, HUD_X - OPS_W, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function MatrixScene:draw()
    self:draw_grid()
    self:draw_live_pushers()
    self:draw_travelling_matrix()
    self:draw_palette()
    self:_draw_bar()
    self.hud:draw(self.input_matrix, self.target_matrix, self.puzzle.name, self.input2_matrix)
    love.graphics.setColor(0.5, 0.65, 0.5, 1)
    love.graphics.setFont(self.font_key)
    love.graphics.print(string.format("Puzzle %d/%d", self.puzzle_index, PuzzleLoader.count()), HUD_X + 8, 12)
    love.graphics.setColor(1, 1, 1, 1)
    self:_draw_status_banner()
    self:_draw_dnd_ghost()
    if self._settings_menu then
        self._settings_menu:draw()
    end
    -- main.lua draws the scene canvas with the current color, so a leaked color tints the screen.
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Input ──────────────────────────────────────────────────────────────────

function MatrixScene:_place_tile_at(cx, cy, spec)
    if not self.grid:in_bounds(cx, cy) then return end
    local old = self.grid:get(cx, cy)
    if old and old.locked then return end

    -- A two-cell tile goes only where both cells are free; it overwrites nothing.
    if spec.kind == "op" and Ops.is_two_cell(spec.op) then
        local facing = spec.params and spec.params.facing or self._tool_facing[spec.op]
        local tile = { kind = "op", op = spec.op, params = { facing = facing },
                       locked = false, fixed = spec.fixed or false }
        if self.grid:fits(cx, cy, tile) then self.grid:put(cx, cy, tile) end
        return
    end

    -- Pushers get the lowest free letter id (a pusher being replaced frees its own id)
    local pusher_id
    if spec.kind == "pusher" then
        local used = {}
        for _, p in ipairs(self:_pusher_list()) do
            if not (p.x == cx and p.y == cy) then used[p.id] = true end
        end
        pusher_id = Sim.free_pusher_id(used)
        if not pusher_id then return end
    end

    self.grid:clear(cx, cy)
    self.grid:set(cx, cy, {
        kind=spec.kind, dir=spec.dir, op=spec.op, id=pusher_id,
        params=Ops.params(spec.op, spec.params), locked=false,
        fixed=spec.fixed or false,
    })
    self:_sync_pushers()
end

-- The anchor cell the dragged tile gets when dropped with the cursor on (cx, cy):
-- a tile held by its right-operand cell keeps that cell under the cursor.
function MatrixScene:_drop_anchor(cx, cy)
    if self._drag_grab ~= "R" then return cx, cy end
    local ox, oy = Ops.partner(0, 0, self._drag_tile.params.facing)
    return cx - ox, cy - oy
end

-- True when the dragged tile may be dropped with the cursor on (cx, cy): every
-- cell it would take is on the board and empty.
function MatrixScene:_can_drop(cx, cy)
    local ax, ay = self:_drop_anchor(cx, cy)
    return self.grid:fits(ax, ay, self._drag_tile)
end

function MatrixScene:mouse_moved(mx, my)
    self._mouse = { x = mx, y = my }
    local d = self._dnd
    if d then
        d.x, d.y, d.moved = mx, my, true
        -- A drag that leaves the button no longer counts as a click on it.
        if d.turn and not UI.hit(d.rect, mx, my) then d.turn = nil end
    end
    if not self._drag_tile then return end
    if in_grid_panel(mx, my) then
        local cx, cy = screen_to_cell(mx, my)
        if self.grid:in_bounds(cx, cy) then
            self._drag_ghost = {cx=cx, cy=cy}
        else
            self._drag_ghost = nil
        end
    else
        self._drag_ghost = nil
    end
end

function MatrixScene:mouse_pressed(mx, my, btn)
    self._mouse = { x = mx, y = my }
    if self._settings_menu and self._settings_menu.is_open then
        self._settings_menu:mouse_pressed(mx, my)
        return
    end
    self._dnd = nil
    local e = (btn == 1 and not self.running) and UI.element_at(self:ui_elements(), mx, my) or nil
    local dnd = e and self:_dnd_begin(e)
    if dnd then
        dnd.x, dnd.y = mx, my
        self._dnd = dnd
        if dnd.defer_click then return end   -- a filled slot acts on release
    end
    self:_mouse_pressed_inner(mx, my, btn)
    self:_sync_pushers()
end

-- ── Drag-and-drop between registry elements (ops/chips/slots) ──────────────

-- Returns a drag payload when element e can be picked up, else nil.
function MatrixScene:_dnd_begin(e)
    if not e.enabled then return nil end
    local id = e.id
    if id:sub(1, 8) == "palette:" then
        for _, r in ipairs(self._palette_rects) do
            if r.id == id and r.btn.kind ~= "scroll" and r.btn.kind ~= "drag" then
                -- Clicking the already selected tool turns it, on release.
                local turn = is_turnable_tool(r.btn) and self:_palette_is_selected(r.btn)
                return { src = "palette", id = id, btn = r.btn, rect = e.rect,
                         turn = turn and r.btn.op or nil }
            end
        end
    elseif id:sub(1, 5) == "chip:" then
        return { src = "chip", id = id, label = e.label, cmd = id:sub(6) }
    elseif id:sub(1, 5) == "slot:" then
        local lane, tick = id:match("^slot:(%d+):(%d+)$")
        lane, tick = tonumber(lane), tonumber(tick)
        local c = Timeline.get(self.timeline, lane, tick)
        if c then
            return { src = "slot", id = id, lane = lane, tick = tick, cmd = c,
                     label = slot_label(c), defer_click = true }
        end
    end
    return nil
end

function MatrixScene:_dnd_drop(d, mx, my)
    local e = UI.element_at(self:ui_elements(), mx, my)
    local tid = e and e.enabled and e.id or nil
    local tlane, ttick
    if tid then tlane, ttick = tid:match("^slot:(%d+):(%d+)$") end
    if d.src == "palette" then
        if tid and tid:sub(1, 5) == "cell:" then
            -- Only a click turns a two-cell tile; of the dragged tools just the
            -- eraser acts on one.
            if d.btn.erase or not is_two_cell_tile(self.grid:get(screen_to_cell(mx, my))) then
                self:_mouse_pressed_inner(mx, my, 1)
            end
        end
    elseif d.src == "chip" then
        if tlane and self.sel_pusher then
            Timeline.set(self.timeline, tonumber(tlane), tonumber(ttick), self.sel_pusher, d.cmd)
        end
    else -- slot
        if tid == d.id then
            self:_mouse_pressed_inner(mx, my, 1)   -- plain click on a filled slot
        elseif tlane then
            Timeline.clear(self.timeline, d.lane, d.tick)
            Timeline.set(self.timeline, tonumber(tlane), tonumber(ttick), d.cmd.pusher, d.cmd.cmd)
        elseif my < BAR_Y then
            Timeline.clear(self.timeline, d.lane, d.tick)
        end
    end
end

function MatrixScene:_draw_dnd_ghost()
    local d = self._dnd
    if not d or not d.x or not d.moved then return end
    love.graphics.setFont(self.font_ui)
    love.graphics.setColor(0.17, 0.21, 0.33, 1)
    love.graphics.rectangle("fill", d.x - 22, d.y - 16, 44, 32, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    local label = d.btn and self:_button_label(d.btn) or d.label
    love.graphics.printf(label, d.x - 22, d.y - 6, 44, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function MatrixScene:_mouse_pressed_inner(mx, my, btn)
    -- All hit-testing goes through the UI element registry.
    local e = UI.element_at(self:ui_elements(), mx, my)
    if e == nil then return end

    local id = e.id
    if id:sub(1, 4) == "cmd:" then
        local cmd = id:sub(5)
        if self:_cmd_enabled(cmd) then self:_cmd_activate(cmd) end
        return
    elseif id:sub(1, 8) == "palette:" then
        for _, r in ipairs(self._palette_rects) do
            if r.id == id then
                if r.btn.kind == "scroll" then
                    if e.enabled then self:_palette_scroll_by(r.btn.dir) end
                else
                    -- During a run there is no drag, so a second click turns at once.
                    if self.running and btn == 1 and is_turnable_tool(r.btn)
                        and self:_palette_is_selected(r.btn) then
                        self:_turn_tool(r.btn.op)
                    end
                    self:_palette_select(r.btn)
                end
                break
            end
        end
        return
    elseif self:_bar_click(e, btn) then
        return
    end

    -- Grid cell: clear, drag, edit or place.
    local cx, cy = screen_to_cell(mx, my)
    if not self.grid:in_bounds(cx, cy) then return end

    if btn == 2 then
        if self._drag_tile then
            self:_clear_drag()
        else
            self.grid:clear(cx, cy)
        end
        return
    end

    if btn == 1 then
        local tile = self.grid:get(cx, cy)

        -- Drag pickup: when in drag mode, pick up an existing unlocked tile
        if self.palette:is_drag() and not self.running then
            if tile and not tile.locked and tile.kind ~= "gap" then
                local ax, ay = self.grid:get_anchor(cx, cy)
                self._drag_tile   = tile
                self._drag_origin = {x=ax, y=ay}
                self._drag_ghost  = {cx=cx, cy=cy}
                self._drag_grab   = (ax ~= cx or ay ~= cy) and "R" or nil
                self._drag_facing = is_two_cell_tile(tile) and tile.params.facing or nil
                self.grid:clear(cx, cy)
            end
            return
        end

        local spec = self.palette:selected()
        if spec == nil and tile and not tile.locked then
            self.grid:clear(cx, cy)
            return
        end

        -- Clicking an op tile edits it (thirds of the cell, or a turn for either
        -- cell of a two-cell tile); it is never replaced.
        if tile and tile.kind == "op" then
            if tile.fixed or tile.locked then return end
            if Ops.is_two_cell(tile.op) then
                if not self.palette:is_drag() then self.grid:rotate(cx, cy) end
            else
                local left = cell_top_left(cx, cy)
                Ops.click(tile.op, tile.params, Ops.part(mx - left, CELL_SIZE))
            end
            return
        end

        -- Empty or non-op cell: apply the palette tool (locked tiles refuse it)
        if spec then self:_place_tile_at(cx, cy, spec) end
    end
end

function MatrixScene:mouse_released(mx, my, btn)
    if btn == 1 and self._dnd then
        local d = self._dnd
        self._dnd = nil
        if d.turn and UI.hit(d.rect, mx, my) then
            self:_turn_tool(d.turn)
        elseif not self.running then
            self:_dnd_drop(d, mx, my)
            self:_sync_pushers()
        end
        return
    end
    if btn ~= 1 or not self._drag_tile then return end
    local tile = self._drag_tile
    local ghost = self._drag_ghost
    if ghost and self:_can_drop(ghost.cx, ghost.cy) then
        local ax, ay = self:_drop_anchor(ghost.cx, ghost.cy)
        self.grid:put(ax, ay, tile)
        self:_end_drag()
        return
    end
    self:_clear_drag()
end

-- The T key turns, in this order of priority: the thing being dragged, else the
-- editable two-cell tile under the cursor, else the selected two-cell tool.
function MatrixScene:_turn_key()
    local held = self._drag_tile
    if held then
        -- A lifted tile turns freely; the preview shows where it fits.
        if is_two_cell_tile(held) and not held.fixed then
            held.params.facing = Ops.next_facing(held.params.facing)
        end
        return
    end
    local d = self._dnd
    if d then
        if is_turnable_tool(d.btn) then
            self:_turn_tool(d.btn.op)
            d.turn = nil   -- the release must not turn it a second time
        end
        return
    end
    local m = self._mouse
    if m then
        local cx, cy = screen_to_cell(m.x, m.y)
        local tile = self.grid:in_bounds(cx, cy) and self.grid:get(cx, cy)
        if tile and is_two_cell_tile(tile) and not (tile.locked or tile.fixed) then
            self.grid:rotate(cx, cy)
            return
        end
    end
    local sel = self.palette:selected()
    if is_turnable_tool(sel) then self:_turn_tool(sel.op) end
end

function MatrixScene:key_pressed(key)
    if self._settings_menu and self._settings_menu.is_open then
        if self._settings_menu:key_pressed(key) then return end
        if key == "t" then return end
    end
    local KEY_CMD = { r = "run", backspace = "reset" }
    local cmd = KEY_CMD[key]
    if cmd then
        if self:_cmd_enabled(cmd) then self:_cmd_activate(cmd) end
    elseif key == "t" then
        self:_turn_key()
    elseif key == "return" and self.status == "win" then
        self:_cmd_activate("continue")
    elseif key == "escape" then
        if self._settings_menu then
            self._settings_menu:open()
        end
    end
end

function MatrixScene:text_input(_) end

-- Board geometry shared with the solution recap so replays line up with the game board.
MatrixScene.GEOM = { GRID_X = GRID_X, GRID_Y = GRID_Y, CELL_SIZE = CELL_SIZE, HUD_X = HUD_X,
                     MATRIX_BORDER = MATRIX_BORDER }

return MatrixScene
