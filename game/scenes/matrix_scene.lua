local Scene        = require("lua/core/scene")
local Matrix       = require("game/matrix_math")
local Grid         = require("game/grid")
local Sim          = require("game/pusher_sim")
local Palette      = require("game/palette")
local HUD          = require("game/hud")
local PuzzleLoader = require("game/puzzle_loader")

local function cell_key(x, y) return x .. "," .. y end

local MatrixScene = {}
MatrixScene.__index = MatrixScene

-- Layout constants
local GRID_X     = 95
local GRID_Y     = 20
local CELL_SIZE  = 63
local PALETTE_Y  = 660
local HUD_X      = 820

-- Ops that expose editable parameters
local PARAM_DEFS = {
    scale_row  = { {key="row",    label="row", min=1, max=4},
                   {key="scalar", label="x",   min=-9, max=9} },
    swap_rows  = { {key="row_a",  label="r1",  min=1, max=4},
                   {key="row_b",  label="r2",  min=1, max=4} },
    scalar_mul = { {key="scalar", label="x",   min=-9, max=9} },
    set_row    = { {key="row", label="row", min=1, max=4} },
}

local DEFAULT_PARAMS = {
    scale_row  = {row=1,  scalar=2},
    swap_rows  = {row_a=1, row_b=2},
    scalar_mul = {scalar=2},
    set_row    = {row=1},
}

local OP_SYMBOLS = {
    transpose  = "T",
    scale_row  = "xRn",
    swap_rows  = "<>R",
    negate     = "-I",
    scalar_mul = "xk",
    add_matrix = "+M",
    sub_matrix = "-M",
    mul_matrix = "xM",
    set_row    = "=R",
}

-- How many board cells each op tile spans: {cols, rows}
local OP_SIZES = {
    transpose  = {1, 1},
    negate     = {1, 1},
    scalar_mul = {2, 1},
    scale_row  = {1, 4},
    swap_rows  = {1, 2},
    add_matrix = {1, 1},
    sub_matrix = {1, 1},
    mul_matrix = {1, 1},
    set_row    = {2, 1},
}

-- Timeline panel: one row per pusher, one slot per tick, shared length n.
local TL = { ROW_H=15, SLOT_W=22, SLOT_GAP=2, LABEL_W=26, MIN_N=1, MAX_N=16, DEFAULT_N=8, MAX_PUSHERS=8 }
local CMD_ORDER = { "idle", "up", "right", "down", "left" }
local CMD_GLYPH = { idle=".", up="^", down="v", left="<", right=">" }
local MAX_TICKS = 500

local function op_width(op)        return (OP_SIZES[op] or {1,1})[1] end
local function op_height(op, tile)
    if op == "scale_row" then return (tile and tile.tile_rows) or 4 end
    return (OP_SIZES[op] or {1,1})[2]
end

local DIR_ARROWS = { right="->", left="<-", up="^", down="v" }

local PALETTE_BUTTONS = {
    { kind="pusher", label="P" },
    { sep=true },
    { kind="op", op="transpose",  label="T"  },
    { kind="op", op="scale_row",  label="xR" },
    { kind="op", op="swap_rows",  label="<>R"},
    { kind="op", op="negate",     label="-I" },
    { kind="op", op="scalar_mul", label="xk" },
    { kind="op", op="add_matrix", label="+M"  },
    { kind="op", op="sub_matrix", label="-M"  },
    { kind="op", op="mul_matrix", label="xM"  },
    { kind="op", op="set_row",    label="=R"  },
    { sep=true },
    { erase=true, label="[X]" },
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

-- ── Constructor ────────────────────────────────────────────────────────────

function MatrixScene.new(puzzle_index, scene_manager)
    local base = Scene.new(1280, 720)
    local self  = setmetatable(base, MatrixScene)
    self._start_puzzle    = puzzle_index or 1
    self._scene_manager   = scene_manager
    self._win_timer       = nil
    return self
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────

function MatrixScene:on_enter()
    self.palette      = Palette.new()
    self.hud          = HUD.new(HUD_X, 0, 460, 720)
    self.font_cell    = love.graphics.newFont(14)
    self.font_ui      = love.graphics.newFont(11)
    self.font_key     = love.graphics.newFont(11)
    self.font_val     = love.graphics.newFont(13)
    self.run_speed    = 0.22
    self.anim_from_x  = 0;  self.anim_from_y = 0
    self.anim_to_x    = 0;  self.anim_to_y   = 0
    self.anim_t       = 1
    self.anim_ready   = false
    self._expand_rects = {}

    self:load_puzzle(self._start_puzzle)
end

function MatrixScene:on_exit()
    self.drawer:clear()
end

-- ── Puzzle management ──────────────────────────────────────────────────────

function MatrixScene:load_puzzle(n)
    self.puzzle_index   = math.max(1, math.min(n, PuzzleLoader.count()))
    self.puzzle         = PuzzleLoader.load(self.puzzle_index)
    local p             = self.puzzle
    self.input_matrix   = Matrix.new(p.input.rows,  p.input.cols,  p.input.values)
    self.target_matrix  = Matrix.new(p.target.rows, p.target.cols, p.target.values)
    self.current_matrix = nil
    -- Clamp row-index params to actual matrix row count
    local nr = p.input.rows
    PARAM_DEFS.scale_row[1].max  = nr
    PARAM_DEFS.swap_rows[1].max  = nr
    PARAM_DEFS.swap_rows[2].max  = nr
    self.status         = nil
    self.running        = false
    self.sim            = nil
    self.cur_slot       = nil
    self.timeline       = {}
    self.timeline_n     = TL.DEFAULT_N
    self._win_timer     = nil
    self.grid           = Grid.new(p.grid_w, p.grid_h)

    if p.locked then
        for _, t in ipairs(p.locked) do
            self.grid:set(t.x, t.y, {
                kind=t.kind, dir=t.dir, op=t.op,
                params=t.params or {}, locked=true,
            })
        end
    end
    self.grid:set(p.source.x, p.source.y, {kind="source", locked=true})
    self.grid:set(p.sink.x,   p.sink.y,   {kind="sink",   locked=true})
    self.gaps = {}
    for _, g in ipairs(p.gaps or {}) do
        self.gaps[g.y] = self.gaps[g.y] or {}
        self.gaps[g.y][g.x] = true
        self.grid:set(g.x, g.y, {kind="gap", locked=true})
    end
    self.occupied_ops = {}
    self._last_fp     = {}
    self:_build_palette()
end

-- Lays out the palette: pusher, the puzzle's available ops (all when it lists none), erase.
function MatrixScene:_build_palette()
    local allowed
    if self.puzzle.ops then
        allowed = {}
        for _, op in ipairs(self.puzzle.ops) do allowed[op] = true end
    end
    self._btn_rects = {}
    local bx, by = 10, PALETTE_Y + 6
    local bw, bh, gap = 48, 48, 56
    local pending_sep = false
    for i, btn in ipairs(PALETTE_BUTTONS) do
        if btn.sep then
            pending_sep = true
        elseif not btn.op or not allowed or allowed[btn.op] then
            if pending_sep then bx = bx + 20; pending_sep = false end
            self._btn_rects[i] = { x=bx, y=by, w=bw, h=bh, btn=btn }
            bx = bx + gap
        end
    end
    local sel = self.palette:selected()
    if sel and sel.kind == "op" and allowed and not allowed[sel.op] then
        self.palette:select(nil)
    end
end

function MatrixScene:do_reset()
    self.current_matrix = nil
    self.status         = nil
    self.running        = false
    self.sim            = nil
    self.cur_slot       = nil
    self.occupied_ops   = {}
    self._last_fp       = {}
    self.anim_t         = 1
    self.anim_ready     = false
end

-- Returns a table keyed by cell_key for every board cell the matrix currently covers.
function MatrixScene:get_footprint()
    local mat  = self.current_matrix
    if not mat or not self.sim then return {} end
    local cx, cy = self.sim.x, self.sim.y
    local fp = {}
    for r = 0, mat.rows - 1 do
        for c = 0, mat.cols - 1 do
            local x, y = cx + c, cy + r
            if self.grid:in_bounds(x, y) then
                fp[cell_key(x, y)] = {x=x, y=y}
            end
        end
    end
    return fp
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
    self.sim            = { x=p.source.x, y=p.source.y, tick=0, idle=0,
                            pushers=self:_pusher_list(), gaps=self.gaps }
    self.status         = "running"
    self.running        = true
    self.occupied_ops   = {}
    self._last_fp       = {}
    self.cur_slot       = nil
    self.anim_t         = 1
    self.anim_ready     = true
    self:_snap_anim_to_matrix()
    -- Ops under the starting footprint fire immediately.
    self:_process_footprint({})
end

-- Recomputes the footprint, re-arms op tiles the matrix has fully left, and fires
-- each newly entered op tile once (deduplicated by anchor). Returns the new footprint.
function MatrixScene:_process_footprint(old_fp)
    local new_fp  = self:get_footprint()
    self._last_fp = new_fp

    for akey, info in pairs(self.occupied_ops) do
        local tile   = self.grid:get(info.ax, info.ay)
        local width  = (tile and tile.width)  or 1
        local height = (tile and tile.height) or 1
        local still_covered = false
        for dy = 0, height - 1 do
            for dx = 0, width - 1 do
                if new_fp[cell_key(info.ax + dx, info.ay + dy)] then
                    still_covered = true; break
                end
            end
            if still_covered then break end
        end
        if not still_covered then self.occupied_ops[akey] = nil end
    end

    local entered_anchors = {}
    local seen = {}
    for key, cell in pairs(new_fp) do
        if not old_fp[key] then
            local ax, ay = self.grid:get_anchor(cell.x, cell.y)
            local akey = cell_key(ax, ay)
            if not self.occupied_ops[akey] and not seen[akey] then
                seen[akey] = true
                entered_anchors[#entered_anchors+1] = {x=ax, y=ay, akey=akey}
            end
        end
    end
    -- Fire in top-to-bottom, left-to-right order (by anchor position).
    table.sort(entered_anchors, function(a, b)
        return a.y < b.y or (a.y == b.y and a.x < b.x)
    end)

    local mat = self.current_matrix
    for _, info in ipairs(entered_anchors) do
        local tile = self.grid:get(info.x, info.y)
        if tile and tile.kind == "op" then
            mat = Sim.apply_op(tile, mat)
            self.occupied_ops[info.akey] = {ax=info.x, ay=info.y}
        end
    end
    self.current_matrix = mat
    return new_fp
end

-- Pushers on the board with their timeline commands, ordered by letter id.
function MatrixScene:_pusher_list()
    local list = {}
    for y = 1, self.grid.h do
        for x = 1, self.grid.w do
            local t = self.grid:get(x, y)
            if t and t.kind == "pusher" then
                list[#list+1] = {x=x, y=y, id=t.id, cmds=self.timeline[t.id] or {}}
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

    local st = {
        x=sim.x, y=sim.y, rows=mat.rows, cols=mat.cols,
        w=grid.w, h=grid.h, pushers=sim.pushers,
        n=self.timeline_n, tick=sim.tick, gaps=sim.gaps,
    }
    local moved = Sim.advance(st)
    sim.x, sim.y, sim.tick = st.x, st.y, st.tick
    sim.idle     = moved and 0 or sim.idle + 1
    self.cur_slot = Sim.slot(sim.tick, self.timeline_n)

    local to_x, to_y = cell_top_left(sim.x, sim.y)
    local new_fp     = self:_process_footprint(self._last_fp)

    -- Any matrix cell on the sink ends the run.
    local status = "ok"
    if new_fp[cell_key(self.puzzle.sink.x, self.puzzle.sink.y)] then
        status = "sink"
    elseif sim.idle >= self.timeline_n then
        status = "stuck"
    elseif sim.tick >= MAX_TICKS then
        status = "timeout"
    end

    if status == "sink" then
        self.running = false
        self.status  = self.current_matrix:equals(self.target_matrix) and "win" or "fail"
        -- Animate the final step in; running=false prevents any further steps.
        self.anim_from_x=from_x; self.anim_from_y=from_y
        self.anim_to_x=to_x;     self.anim_to_y=to_y
        self.anim_t     = 0
        self.anim_ready = false
    elseif status ~= "ok" then
        self.running = false
        self.status  = status
        self.anim_from_x=to_x; self.anim_from_y=to_y
        self.anim_to_x=to_x;   self.anim_to_y=to_y
        self.anim_t  = 1
        self.anim_ready = false
    else
        self.anim_from_x=from_x; self.anim_from_y=from_y
        self.anim_to_x=to_x;     self.anim_to_y=to_y
        self.anim_t     = 0
        self.anim_ready = false
    end
end

-- ── Update ─────────────────────────────────────────────────────────────────

function MatrixScene:update(dt)
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
    if self.status == "win" and self._scene_manager then
        self._win_timer = (self._win_timer or 0) + dt
        if self._win_timer >= 0.8 then
            local LevelSelectScene = require("game/scenes/level_select_scene")
            self._scene_manager:switch(LevelSelectScene.new(self._scene_manager))
        end
    end
end

-- ── Draw helpers ───────────────────────────────────────────────────────────

function MatrixScene:draw_grid()
    love.graphics.setColor(0.08, 0.08, 0.13, 1)
    love.graphics.rectangle("fill", 0, 0, HUD_X, PALETTE_Y)

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

    -- Pass 2: tile content — anchor cells draw their full span, ref cells draw param content
    for cy = 1, 10 do
        for cx = 1, 10 do
            local is_r, ax, ay = self.grid:is_ref(cx, cy)
            if is_r then
                local anchor_tile = self.grid:get(cx, cy)
                local dc = cx - ax
                local dr = cy - ay
                self:draw_ref_cell(anchor_tile, dc, dr, cx, cy)
            else
                local tile = self.grid:get(cx, cy)
                if tile then self:draw_tile(tile, cx, cy) end
            end
        end
    end

    -- Pass 3: expand/shrink affordances for resizable ops
    self._expand_rects = {}
    local EXPAND_OPS = {add_matrix=true, sub_matrix=true, mul_matrix=true, set_row=true, scale_row=true}
    for cy2 = 1, 10 do
        for cx2 = 1, 10 do
            local is_r2, _, _ = self.grid:is_ref(cx2, cy2)
            if not is_r2 then
                local tile2 = self.grid:get(cx2, cy2)
                if tile2 and tile2.kind == "op" and EXPAND_OPS[tile2.op] and not tile2.locked then
                    local ax2, ay2 = cx2, cy2
                    local tc = tile2.tile_cols or 1
                    local tr = tile2.tile_rows
                    local has_col_resize = tile2.tile_cols ~= nil

                    -- +col strip to the right
                    if has_col_resize and tc < 4 then
                        local sx2, sy2 = cell_top_left(ax2 + tc, ay2)
                        local sh = (tr or 1) * CELL_SIZE
                        local sw = CELL_SIZE / 3
                        love.graphics.setColor(0.3, 0.6, 0.3, 0.7)
                        love.graphics.rectangle("fill", sx2, sy2, sw, sh)
                        love.graphics.setColor(0.5, 1.0, 0.5, 1)
                        love.graphics.setFont(self.font_ui)
                        love.graphics.printf("+", sx2, sy2 + (tr or 1) * CELL_SIZE / 2 - 7, sw, "center")
                        table.insert(self._expand_rects, {ax=ax2,ay=ay2,action="grow_col",x=sx2,y=sy2,w=sw,h=sh})
                    end

                    -- -col strip (right inside edge), only if tc > 1
                    if has_col_resize and tc > 1 then
                        local sx2, sy2 = cell_top_left(ax2 + tc - 1, ay2)
                        local sw = CELL_SIZE / 4
                        local sh = (tr or 1) * CELL_SIZE
                        local rx = sx2 + CELL_SIZE - sw
                        love.graphics.setColor(0.6, 0.2, 0.2, 0.6)
                        love.graphics.rectangle("fill", rx, sy2, sw, sh)
                        love.graphics.setColor(1.0, 0.4, 0.4, 1)
                        love.graphics.setFont(self.font_ui)
                        love.graphics.printf("-", rx, sy2 + (tr or 1) * CELL_SIZE / 2 - 7, sw, "center")
                        table.insert(self._expand_rects, {ax=ax2,ay=ay2,action="shrink_col",x=rx,y=sy2,w=sw,h=sh})
                    end

                    -- +row and -row only for matrix ops (not set_row)
                    if tr then
                        if tr < 4 then
                            local sx2, sy2 = cell_top_left(ax2, ay2 + tr)
                            local sw = tc * CELL_SIZE
                            local sh = CELL_SIZE / 3
                            love.graphics.setColor(0.3, 0.6, 0.3, 0.7)
                            love.graphics.rectangle("fill", sx2, sy2, sw, sh)
                            love.graphics.setColor(0.5, 1.0, 0.5, 1)
                            love.graphics.setFont(self.font_ui)
                            love.graphics.printf("+", sx2, sy2 + sh / 2 - 7, sw, "center")
                            table.insert(self._expand_rects, {ax=ax2,ay=ay2,action="grow_row",x=sx2,y=sy2,w=sw,h=sh})
                        end
                        if tr > 1 then
                            local sx2, sy2 = cell_top_left(ax2, ay2 + tr - 1)
                            local sh = CELL_SIZE / 4
                            local ry = sy2 + CELL_SIZE - sh
                            local sw = tc * CELL_SIZE
                            love.graphics.setColor(0.6, 0.2, 0.2, 0.6)
                            love.graphics.rectangle("fill", sx2, ry, sw, sh)
                            love.graphics.setColor(1.0, 0.4, 0.4, 1)
                            love.graphics.setFont(self.font_ui)
                            love.graphics.printf("-", sx2, ry + sh / 2 - 7, sw, "center")
                            table.insert(self._expand_rects, {ax=ax2,ay=ay2,action="shrink_row",x=sx2,y=ry,w=sw,h=sh})
                        end
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function MatrixScene:draw_pusher(id, sx, sy, ghost)
    local cs, a = CELL_SIZE, ghost and 0.25 or 0.95
    love.graphics.setColor(0.30, 0.18, 0.45, a)
    love.graphics.rectangle("fill", sx + 4, sy + 4, cs - 8, cs - 8, 6, 6)
    love.graphics.setColor(0.80, 0.60, 1.0, ghost and 0.4 or 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx + 4, sy + 4, cs - 8, cs - 8, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.font_cell)
    love.graphics.printf(string.char(64 + (id or 1)), sx, sy + cs / 2 - 8, cs, "center")
    if not ghost then
        local cmd = self.cur_slot and (self.timeline[id] or {})[self.cur_slot]
        if cmd and cmd ~= "idle" then
            love.graphics.setColor(1, 0.9, 0.4, 1)
            love.graphics.setFont(self.font_val)
            love.graphics.printf(CMD_GLYPH[cmd], sx, sy + cs - 22, cs, "center")
        end
    end
end

function MatrixScene:draw_live_pushers()
    if not self.sim then return end
    for _, p in ipairs(self.sim.pushers) do
        local sx, sy = cell_top_left(p.x, p.y)
        self:draw_pusher(p.id, sx, sy, false)
    end
end

-- draw_ref_cell: called for each ref cell in Pass 2.
-- dc, dr are 0-based offsets from the anchor.
function MatrixScene:draw_ref_cell(tile, dc, dr, cx, cy)
    local op = tile and tile.op
    if op == "add_matrix" or op == "sub_matrix" or op == "mul_matrix" then
        self:draw_matrix_value_cell(tile, dc + 1, dr + 1, cx, cy)
    elseif op == "scale_row" then
        self:draw_scale_band(tile, dr + 1, cx, cy)
    elseif op == "swap_rows" then
        self:draw_swap_strip(tile, dr + 1, cx, cy)
    elseif op == "set_row" then
        if dc == 0 then
            self:draw_param_cell(tile, 1, cx, cy)
        else
            self:draw_set_row_value_cell(tile, dc, cx, cy)
        end
    else
        -- existing ops (scalar_mul, etc.)
        self:draw_param_cell(tile, dc, cx, cy)
    end
end

-- draw_tile takes cell coordinates so multi-cell ops can draw a spanning background.
function MatrixScene:draw_tile(tile, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs     = CELL_SIZE
    local mid_y  = sy + cs / 2

    if tile.kind == "source" then
        love.graphics.setColor(0.1, 0.5, 0.2, 0.5)
        love.graphics.rectangle("fill", sx, sy, cs, cs)
        love.graphics.setColor(0.4, 1.0, 0.5, 1)
        love.graphics.setFont(self.font_cell)
        love.graphics.printf("SRC", sx, mid_y - 7, cs, "center")

    elseif tile.kind == "sink" then
        love.graphics.setColor(0.1, 0.3, 0.7, 0.5)
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
        local w = op_width(tile.op)
        local h = op_height(tile.op, tile)
        local span_w = w * cs
        local span_h = h * cs

        -- Spanning background
        love.graphics.setColor(0.22, 0.14, 0.03, 0.92)
        love.graphics.rectangle("fill", sx, sy, span_w, span_h)
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx + 1, sy + 1, span_w - 2, span_h - 2)
        love.graphics.setLineWidth(1)

        local op = tile.op
        if op == "add_matrix" or op == "sub_matrix" or op == "mul_matrix" then
            -- Small op symbol top-left; anchor cell value
            love.graphics.setColor(0.9, 0.7, 0.3, 0.6)
            love.graphics.setFont(self.font_ui)
            love.graphics.print(OP_SYMBOLS[op] or "?", sx + 2, sy + 2)
            self:draw_matrix_value_cell(tile, 1, 1, cx, cy)
        elseif op == "scale_row" then
            for band = 1, h do
                self:draw_scale_band(tile, band, cx, cy + band - 1)
            end
        elseif op == "swap_rows" then
            self:draw_swap_strip(tile, 1, cx, cy)
            self:draw_swap_strip(tile, 2, cx, cy + 1)
            -- ⇅ symbol at the border between the two cells
            love.graphics.setColor(0.9, 0.7, 0.3, 1)
            love.graphics.setFont(self.font_ui)
            love.graphics.printf("⇅", sx, sy + cs - 8, cs, "center")
        elseif op == "set_row" then
            self:draw_param_cell(tile, 1, cx, cy)
            for dc = 1, tile.tile_cols or 1 do
                self:draw_set_row_value_cell(tile, dc, cx + dc, cy)
            end
        else
            -- Existing 1D ops (transpose, negate, scalar_mul anchor)
            love.graphics.setColor(0.9, 0.7, 0.3, 1)
            love.graphics.setFont(self.font_cell)
            love.graphics.printf(OP_SYMBOLS[op] or "?", sx, mid_y - 8, cs, "center")
        end
    end

    if tile.locked and tile.kind ~= "gap" then
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
        love.graphics.circle("fill", sx + cs - 8, sy + 7, 3)
        love.graphics.rectangle("fill", sx + cs - 10, sy + 7, 4, 5)
    end
end

-- Draw a parameter cell for a multi-cell op tile.
-- param_index is 1-based (1 = first param of the op).
function MatrixScene:draw_param_cell(tile, param_index, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs     = CELL_SIZE
    local defs   = PARAM_DEFS[tile.op]
    if not defs or not defs[param_index] then return end
    local def = defs[param_index]
    local val = tostring((tile.params or {})[def.key] or 0)

    -- Param label
    love.graphics.setColor(0.65, 0.5, 0.15, 1)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf(def.label, sx, sy + 5, cs, "center")

    -- Value
    love.graphics.setColor(0.95, 0.85, 0.5, 1)
    love.graphics.setFont(self.font_cell)
    love.graphics.printf(val, sx, sy + cs / 2 - 10, cs, "center")

    -- [-] / [+] affordances in the bottom area; left and right thirds
    love.graphics.setColor(0.55, 0.42, 0.15, 0.9)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf("-", sx, sy + cs - 18, cs / 3, "center")
    love.graphics.printf("+", sx + cs * 2 / 3, sy + cs - 18, cs / 3, "center")
end

function MatrixScene:draw_matrix_value_cell(tile, col_1, row_1, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs = CELL_SIZE
    local v = 0
    if tile.values and tile.values[row_1] then
        v = tile.values[row_1][col_1] or 0
    end
    local val = tostring(v)

    love.graphics.setColor(0.65, 0.5, 0.15, 1)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf(col_1 .. "," .. row_1, sx, sy + 5, cs, "center")

    love.graphics.setColor(0.95, 0.85, 0.5, 1)
    love.graphics.setFont(self.font_cell)
    love.graphics.printf(val, sx, sy + cs / 2 - 10, cs, "center")

    love.graphics.setColor(0.55, 0.42, 0.15, 0.9)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf("-", sx, sy + cs - 18, cs / 3, "center")
    love.graphics.printf("+", sx + cs * 2 / 3, sy + cs - 18, cs / 3, "center")
end

function MatrixScene:draw_scale_band(tile, band, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs = CELL_SIZE
    local selected = (band == (tile.params or {}).row)
    local scalar = (tile.params or {}).scalar or 2

    if selected then
        love.graphics.setColor(0.35, 0.22, 0.04, 1)
        love.graphics.rectangle("fill", sx, sy, cs, cs)
        love.graphics.setColor(1.0, 0.85, 0.4, 1)
        love.graphics.setFont(self.font_ui)
        love.graphics.print("R" .. band, sx + 4, sy + cs / 2 - 7)
        love.graphics.setFont(self.font_cell)
        love.graphics.printf("×" .. scalar, sx, sy + cs / 2 - 9, cs, "right")
        love.graphics.setColor(0.7, 0.55, 0.2, 0.9)
        love.graphics.setFont(self.font_ui)
        love.graphics.printf("-", sx, sy + cs - 18, cs / 3, "center")
        love.graphics.printf("+", sx + cs * 2 / 3, sy + cs - 18, cs / 3, "center")
    else
        love.graphics.setColor(0.55, 0.40, 0.12, 1)
        love.graphics.setFont(self.font_ui)
        love.graphics.printf("R" .. band, sx, sy + cs / 2 - 7, cs, "center")
    end
end

function MatrixScene:draw_swap_strip(tile, strip, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs = CELL_SIZE
    local params = tile.params or {}
    local row_n = (strip == 1) and (params.row_a or 1) or (params.row_b or 2)

    love.graphics.setColor(0.95, 0.85, 0.5, 1)
    love.graphics.setFont(self.font_cell)
    love.graphics.printf("R" .. row_n, sx, sy + cs / 2 - 9, cs, "center")

    love.graphics.setColor(0.55, 0.42, 0.15, 0.9)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf("-", sx, sy + cs - 18, cs / 3, "center")
    love.graphics.printf("+", sx + cs * 2 / 3, sy + cs - 18, cs / 3, "center")
end

function MatrixScene:draw_set_row_value_cell(tile, dc, cx, cy)
    local sx, sy = cell_top_left(cx, cy)
    local cs = CELL_SIZE
    local v = 0
    if tile.values and tile.values[1] then
        v = tile.values[1][dc] or 0
    end

    love.graphics.setColor(0.65, 0.5, 0.15, 1)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf("c" .. dc, sx, sy + 5, cs, "center")

    love.graphics.setColor(0.95, 0.85, 0.5, 1)
    love.graphics.setFont(self.font_cell)
    love.graphics.printf(tostring(v), sx, sy + cs / 2 - 10, cs, "center")

    love.graphics.setColor(0.55, 0.42, 0.15, 0.9)
    love.graphics.setFont(self.font_ui)
    love.graphics.printf("-", sx, sy + cs - 18, cs / 3, "center")
    love.graphics.printf("+", sx + cs * 2 / 3, sy + cs - 18, cs / 3, "center")
end

function MatrixScene:draw_travelling_matrix()
    local mat = self.current_matrix
    if not mat then return end

    local t  = self.anim_t
    local et = t * t * (3 - 2 * t)  -- smooth-step
    local px = lerp(self.anim_from_x, self.anim_to_x, et)
    local py = lerp(self.anim_from_y, self.anim_to_y, et)

    -- Each matrix element = one board cell
    local bx = px
    local by = py

    for r = 1, mat.rows do
        for c = 1, mat.cols do
            local cx = bx + (c - 1) * CELL_SIZE
            local cy = by + (r - 1) * CELL_SIZE
            local v  = mat.values[r][c]

            love.graphics.setColor(0.08, 0.08, 0.16, 0.92)
            love.graphics.rectangle("fill", cx, cy, CELL_SIZE, CELL_SIZE)

            love.graphics.setColor(1, 0.80, 0.15, 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx+1, cy+1, CELL_SIZE-2, CELL_SIZE-2)
            love.graphics.setLineWidth(1)

            local s
            if v == math.floor(v) then s = tostring(math.floor(v))
            else s = string.format("%.1f", v) end
            love.graphics.setColor(0.95, 0.95, 1.0, 1)
            love.graphics.setFont(self.font_cell)
            love.graphics.printf(s, cx, cy + CELL_SIZE / 2 - 9, CELL_SIZE, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function MatrixScene:draw_palette()
    love.graphics.setColor(0.06, 0.06, 0.10, 1)
    love.graphics.rectangle("fill", 0, PALETTE_Y, HUD_X, 60)

    local sel = self.palette:selected()
    for _, rect in pairs(self._btn_rects) do
        local btn    = rect.btn
        local is_sel = false
        if sel == nil and btn.erase then
            is_sel = true
        elseif sel and btn.kind == sel.kind then
            if btn.kind == "pusher" then is_sel = true
            elseif btn.kind == "op" then is_sel = (btn.op == sel.op) end
        end

        love.graphics.setColor(0.12, 0.12, 0.20, 1)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)
        love.graphics.setColor(is_sel and {0.8,0.9,1.0,1} or {0.3,0.3,0.45,1})
        love.graphics.setLineWidth(is_sel and 2 or 1)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 4, 4)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.85, 0.85, 0.9, 1)
        love.graphics.setFont(self.font_ui)
        love.graphics.printf(btn.label, rect.x, rect.y + 17, rect.w, "center")
    end

    love.graphics.setColor(0.5, 0.5, 0.65, 1)
    love.graphics.setFont(self.font_key)
    love.graphics.print("[R] Run", 620, PALETTE_Y + 22)
    love.graphics.print("[Spc] Step", 685, PALETTE_Y + 22)
    love.graphics.print("[Bsp] Reset", 755, PALETTE_Y + 22)

    love.graphics.setColor(0.5, 0.65, 0.5, 1)
    local nav = string.format("Puzzle %d/%d  [Esc] Menu", self.puzzle_index, PuzzleLoader.count())
    love.graphics.printf(nav, 0, PALETTE_Y + 6, HUD_X, "right")
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Draw ───────────────────────────────────────────────────────────────────

-- ── Timeline panel ─────────────────────────────────────────────────────────

local function in_rect(r, mx, my)
    return mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h
end

local function cycle_cmd(cur, delta)
    local idx = 1
    for i, c in ipairs(CMD_ORDER) do
        if c == (cur or "idle") then idx = i end
    end
    return CMD_ORDER[((idx - 1 + delta) % #CMD_ORDER) + 1]
end

-- Rects for the length controls and every pusher row/slot; nil until the HUD has drawn once.
function MatrixScene:_timeline_layout()
    local top = self._tl_top
    if not top then return nil end
    local x0    = HUD_X + 20
    local len_x = HUD_X + 460 - 20 - 78
    local L = {
        x0 = x0, top = top, rows = {},
        dec = { x=len_x,      y=top, w=18, h=16 },
        val = { x=len_x + 18, y=top, w=42, h=16 },
        inc = { x=len_x + 60, y=top, w=18, h=16 },
    }
    for i, p in ipairs(self:_pusher_list()) do
        local ry  = top + 20 + (i - 1) * TL.ROW_H
        local row = { id=p.id, y=ry, slots={} }
        for s = 1, self.timeline_n do
            row.slots[s] = {
                x = x0 + TL.LABEL_W + (s - 1) * (TL.SLOT_W + TL.SLOT_GAP),
                y = ry, w = TL.SLOT_W, h = TL.ROW_H - 1,
            }
        end
        L.rows[i] = row
    end
    return L
end

function MatrixScene:draw_timeline()
    local L = self:_timeline_layout()
    if not L then return end

    love.graphics.setFont(self.font_ui)
    love.graphics.setColor(0.6, 0.75, 1.0, 1)
    love.graphics.print("TIMELINE", L.x0, L.top + 2)

    for _, b in ipairs({ { L.dec, "-" }, { L.inc, "+" } }) do
        love.graphics.setColor(0.25, 0.25, 0.4, 1)
        love.graphics.rectangle("fill", b[1].x, b[1].y, b[1].w, b[1].h, 2, 2)
        love.graphics.setColor(0.85, 0.85, 0.95, 1)
        love.graphics.printf(b[2], b[1].x, b[1].y + 2, b[1].w, "center")
    end
    love.graphics.setColor(0.85, 0.85, 0.95, 1)
    love.graphics.printf("len " .. self.timeline_n, L.val.x, L.val.y + 2, L.val.w, "center")

    if #L.rows == 0 then
        love.graphics.setColor(0.45, 0.45, 0.6, 1)
        love.graphics.print("Place a pusher [P], then program it here", L.x0, L.top + 24)
        return
    end

    for _, row in ipairs(L.rows) do
        love.graphics.setColor(0.80, 0.60, 1.0, 1)
        love.graphics.printf(string.char(64 + row.id), L.x0, row.y + 1, TL.LABEL_W - 6, "right")
        local cmds = self.timeline[row.id] or {}
        for s, r in ipairs(row.slots) do
            local current = self.sim and self.cur_slot == s
            love.graphics.setColor(current and 0.35 or 0.14, current and 0.30 or 0.14, current and 0.15 or 0.22, 1)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 2, 2)
            love.graphics.setColor(0.3, 0.3, 0.45, 1)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 2, 2)
            local cmd = cmds[s] or "idle"
            love.graphics.setColor(cmd == "idle" and 0.4 or 1, cmd == "idle" and 0.4 or 0.9, cmd == "idle" and 0.5 or 0.4, 1)
            love.graphics.printf(CMD_GLYPH[cmd], r.x, r.y + 1, r.w, "center")
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Left-click cycles a slot forward, right-click backward; -/+ change the timeline length.
function MatrixScene:_timeline_click(mx, my, btn)
    local L = self:_timeline_layout()
    if not L or self.running then return end

    if btn == 1 and in_rect(L.dec, mx, my) then
        self.timeline_n = math.max(TL.MIN_N, self.timeline_n - 1)
    elseif btn == 1 and in_rect(L.inc, mx, my) then
        self.timeline_n = math.min(TL.MAX_N, self.timeline_n + 1)
    else
        for _, row in ipairs(L.rows) do
            for s, r in ipairs(row.slots) do
                if in_rect(r, mx, my) then
                    local cmds = self.timeline[row.id] or {}
                    self.timeline[row.id] = cmds
                    cmds[s] = cycle_cmd(cmds[s], btn == 2 and -1 or 1)
                    return
                end
            end
        end
    end
end

function MatrixScene:draw()
    self:draw_grid()
    self:draw_live_pushers()
    self:draw_travelling_matrix()
    self:draw_palette()
    self._tl_top = self.hud:draw(self.input_matrix, self.target_matrix, self.puzzle.name, self.status)
    self:draw_timeline()
end

-- ── Input ──────────────────────────────────────────────────────────────────

function MatrixScene:_place_tile_at(cx, cy, spec)
    local matrix_rows = self.input_matrix and self.input_matrix.rows or 4
    local w = op_width(spec.op or "")
    local h = op_height(spec.op or "", {matrix_rows = matrix_rows})
    if spec.kind == "arrow" then w = 1; h = 1 end

    if not self.grid:in_bounds_multi_2d(cx, cy, w, h) then return end

    -- Reject if any cell in range is locked
    for dy = 0, h - 1 do
        for dx = 0, w - 1 do
            local t = self.grid:get(cx + dx, cy + dy)
            if t and t.locked then return end
        end
    end

    -- Pushers get the lowest free letter id (a pusher being replaced frees its own id)
    local pusher_id
    if spec.kind == "pusher" then
        local used = {}
        for _, p in ipairs(self:_pusher_list()) do
            if not (p.x == cx and p.y == cy) then used[p.id] = true end
        end
        for id = 1, TL.MAX_PUSHERS do
            if not used[id] then pusher_id = id; break end
        end
        if not pusher_id then return end
    end

    -- Clear existing tiles
    for dy = 0, h - 1 do
        for dx = 0, w - 1 do
            self.grid:clear(cx + dx, cy + dy)
        end
    end

    local params = {}
    if DEFAULT_PARAMS[spec.op] then
        for k, v in pairs(DEFAULT_PARAMS[spec.op]) do params[k] = v end
    end
    if spec.params then
        for k, v in pairs(spec.params) do params[k] = v end
    end

    -- Build tile values for matrix ops
    local values = nil
    local tile_rows, tile_cols = nil, nil
    if spec.op == "add_matrix" or spec.op == "sub_matrix" then
        tile_rows, tile_cols = 1, 1
        values = {{0}}
    elseif spec.op == "mul_matrix" then
        tile_rows, tile_cols = 1, 1
        values = {{1}}
    elseif spec.op == "set_row" then
        tile_cols = 1
        values = {{0}}
    elseif spec.op == "scale_row" then
        tile_rows = 4
    end

    local tile = {
        kind=spec.kind, dir=spec.dir, op=spec.op, id=pusher_id,
        params=params, locked=false,
        width=w, height=h,
        tile_rows=tile_rows, tile_cols=tile_cols,
        values=values,
        matrix_rows=(spec.op == "scale_row") and matrix_rows or nil,
    }

    if w > 1 or h > 1 then
        self.grid:set_multi_2d(cx, cy, tile, w, h)
    else
        self.grid:set(cx, cy, tile)
    end
    if pusher_id then self.timeline[pusher_id] = {} end
end

function MatrixScene:_resize_tile(ax, ay, action)
    local tile = self.grid:get(ax, ay)
    if not tile or tile.locked then return end

    local old_w = tile.width  or 1
    local old_h = tile.height or 1
    local tc    = tile.tile_cols or 1
    local tr    = tile.tile_rows or 1

    if action == "grow_col" and tc < 4 then
        -- Clear old footprint
        self.grid:clear(ax, ay)
        -- Grow
        local fill = (tile.op == "mul_matrix") and 1 or 0
        for r = 1, tr do
            if not tile.values[r] then tile.values[r] = {} end
            tile.values[r][tc + 1] = fill
        end
        tile.tile_cols = tc + 1
        tile.width     = old_w + 1
        self.grid:set_multi_2d(ax, ay, tile, tile.tile_cols, tr)

    elseif action == "shrink_col" and tc > 1 then
        self.grid:clear(ax, ay)
        for r = 1, tr do
            if tile.values[r] then tile.values[r][tc] = nil end
        end
        tile.tile_cols = tc - 1
        tile.width     = old_w - 1
        local new_w = (tile.op == "set_row") and (1 + tile.tile_cols) or tile.tile_cols
        tile.width = new_w
        self.grid:set_multi_2d(ax, ay, tile, new_w, tr)

    elseif action == "grow_row" and tr < 4 then
        self.grid:clear(ax, ay)
        if tile.values then
            local fill = (tile.op == "mul_matrix") and 1 or 0
            tile.values[tr + 1] = {}
            for c = 1, tc do tile.values[tr + 1][c] = fill end
        end
        tile.tile_rows = tr + 1
        tile.height    = old_h + 1
        self.grid:set_multi_2d(ax, ay, tile, tc, tile.tile_rows)

    elseif action == "shrink_row" and tr > 1 then
        self.grid:clear(ax, ay)
        if tile.values then tile.values[tr] = nil end
        tile.tile_rows = tr - 1
        tile.height    = old_h - 1
        if tile.params and tile.params.row then
            tile.params.row = math.min(tile.params.row, tile.tile_rows)
        end
        self.grid:set_multi_2d(ax, ay, tile, tc, tile.tile_rows)
    end
end

function MatrixScene:mouse_pressed(mx, my, btn)
    if mx >= HUD_X then
        self:_timeline_click(mx, my, btn)
        return
    end

    -- Palette bar
    if my >= PALETTE_Y then
        for _, rect in pairs(self._btn_rects) do
            if mx >= rect.x and mx < rect.x + rect.w
            and my >= rect.y and my < rect.y + rect.h then
                local b = rect.btn
                if b.erase then
                    self.palette:select(nil)
                elseif b.kind == "pusher" then
                    self.palette:select({kind="pusher"})
                elseif b.kind == "op" then
                    self.palette:select({kind="op", op=b.op})
                end
                return
            end
        end
        return
    end

    if not in_grid_panel(mx, my) then return end
    local cx, cy = screen_to_cell(mx, my)
    if not self.grid:in_bounds(cx, cy) then return end

    if btn == 2 then
        self.grid:clear(cx, cy)
        return
    end

    if btn == 1 then
        -- Check expand/shrink affordances first
        for _, rect in ipairs(self._expand_rects or {}) do
            if mx >= rect.x and mx < rect.x + rect.w
            and my >= rect.y and my < rect.y + rect.h then
                self:_resize_tile(rect.ax, rect.ay, rect.action)
                return
            end
        end

        local is_r, ax, ay = self.grid:is_ref(cx, cy)
        local anchor_tile
        if is_r then
            anchor_tile = self.grid:get(cx, cy)
        else
            anchor_tile = self.grid:get(cx, cy)
            ax, ay = cx, cy
        end

        local dc = cx - ax
        local dr = cy - ay
        local op = anchor_tile and anchor_tile.op

        if anchor_tile and not anchor_tile.locked and self.palette:is_eraser() then
            self.grid:clear(cx, cy)
            return
        end

        -- Handle op-specific clicks
        if anchor_tile and anchor_tile.kind == "op" then
            if op == "add_matrix" or op == "sub_matrix" or op == "mul_matrix" then
                if is_r or (dc == 0 and dr == 0) then
                    -- value cell: left/right third = dec/inc
                    local cell_sx, _ = cell_top_left(cx, cy)
                    local rel_x = mx - cell_sx
                    local row_1 = dr + 1
                    local col_1 = dc + 1
                    if not anchor_tile.values then anchor_tile.values = {} end
                    if not anchor_tile.values[row_1] then anchor_tile.values[row_1] = {} end
                    local cur = anchor_tile.values[row_1][col_1] or 0
                    if rel_x < CELL_SIZE / 3 then
                        anchor_tile.values[row_1][col_1] = math.max(-9, cur - 1)
                    elseif rel_x >= CELL_SIZE * 2 / 3 then
                        anchor_tile.values[row_1][col_1] = math.min(9, cur + 1)
                    end
                end
                return

            elseif op == "set_row" then
                if dc == 0 then
                    -- Row selector param cell
                    local defs = PARAM_DEFS["set_row"]
                    if defs and defs[1] then
                        local def = defs[1]
                        local cell_sx, _ = cell_top_left(cx, cy)
                        local rel_x = mx - cell_sx
                        if rel_x < CELL_SIZE / 3 then
                            anchor_tile.params[def.key] = math.max(def.min, (anchor_tile.params[def.key] or 1) - 1)
                        elseif rel_x >= CELL_SIZE * 2 / 3 then
                            anchor_tile.params[def.key] = math.min(def.max, (anchor_tile.params[def.key] or 1) + 1)
                        end
                    end
                else
                    -- Value cell
                    local cell_sx, _ = cell_top_left(cx, cy)
                    local rel_x = mx - cell_sx
                    if not anchor_tile.values then anchor_tile.values = {{}} end
                    if not anchor_tile.values[1] then anchor_tile.values[1] = {} end
                    local cur = anchor_tile.values[1][dc] or 0
                    if rel_x < CELL_SIZE / 3 then
                        anchor_tile.values[1][dc] = math.max(-9, cur - 1)
                    elseif rel_x >= CELL_SIZE * 2 / 3 then
                        anchor_tile.values[1][dc] = math.min(9, cur + 1)
                    end
                end
                return

            elseif op == "scale_row" then
                local band = dr + 1  -- 1-based band index
                local params = anchor_tile.params
                if band ~= params.row then
                    -- Select this band
                    params.row = band
                else
                    -- Already selected: left/right = scalar dec/inc
                    local cell_sx, _ = cell_top_left(cx, cy)
                    local rel_x = mx - cell_sx
                    if rel_x < CELL_SIZE / 3 then
                        params.scalar = math.max(-9, (params.scalar or 2) - 1)
                    elseif rel_x >= CELL_SIZE * 2 / 3 then
                        params.scalar = math.min(9, (params.scalar or 2) + 1)
                    end
                end
                return

            elseif op == "swap_rows" then
                local strip = dr + 1  -- 1 or 2
                local key = (strip == 1) and "row_a" or "row_b"
                local other_key = (strip == 1) and "row_b" or "row_a"
                local params = anchor_tile.params
                local cell_sx, _ = cell_top_left(cx, cy)
                local rel_x = mx - cell_sx
                local delta = 0
                if rel_x < CELL_SIZE / 3 then delta = -1
                elseif rel_x >= CELL_SIZE * 2 / 3 then delta = 1
                end
                if delta ~= 0 then
                    local new_val = math.max(1, math.min(4, (params[key] or 1) + delta))
                    if new_val ~= params[other_key] then
                        params[key] = new_val
                    end
                end
                return

            elseif is_r then
                -- Existing param-cell handling for other ops (e.g. scalar_mul)
                local param_index = dc
                local defs = PARAM_DEFS[op]
                if defs and defs[param_index] then
                    local def = defs[param_index]
                    local cell_sx, _ = cell_top_left(cx, cy)
                    local rel_x = mx - cell_sx
                    local delta = 0
                    if rel_x < CELL_SIZE / 3 then delta = -1
                    elseif rel_x >= CELL_SIZE * 2 / 3 then delta = 1
                    end
                    if delta ~= 0 then
                        local cur = anchor_tile.params[def.key] or 0
                        anchor_tile.params[def.key] = math.max(def.min, math.min(def.max, cur + delta))
                    end
                end
                return
            end
        end

        -- Clicking empty or non-op cell: apply palette tool
        if not is_r then
            local spec = self.palette:selected()
            if spec == nil then
                self.grid:clear(cx, cy)
            else
                self:_place_tile_at(cx, cy, spec)
            end
        end
    end
end

function MatrixScene:key_pressed(key)
    if key == "r" then
        if not self.running and (self.status == nil or self.status == "fail"
                              or self.status == "stuck" or self.status == "timeout") then
            self:start_run()
        end
    elseif key == "space" then
        if not self.running and (self.status == nil or self.status == "running") then
            self.anim_t = 1
            self:do_step()
            self.anim_t = 1
        end
    elseif key == "backspace" then
        self:do_reset()
    elseif key == "escape" then
        if self._scene_manager then
            local LevelSelectScene = require("game/scenes/level_select_scene")
            self._scene_manager:switch(LevelSelectScene.new(self._scene_manager))
        end
    end
end

function MatrixScene:text_input(_) end

return MatrixScene
