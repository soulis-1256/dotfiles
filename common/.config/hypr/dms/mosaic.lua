-- Mosaic Layout Engine for Hyprland
-- Intelligent content-aware 2D tessellation based on application archetypes.
-- Windows remain floating under the hood, but are positioned and scaled
-- smoothly into an organic, non-overlapping masonry mosaic.

local M = {}

local db = require("dms.mosaic-db")

local LOG_FILE = "/tmp/mosaic_mode.log"
local function log(msg)
	local f = io.open(LOG_FILE, "a")
	if f then
		f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
		f:close()
	end
end
M.log = log

-- State management
_G.mosaic_mode = _G.mosaic_mode or {
	active = false,
	workspaces = {},
}

local CACHE_PATH = (os.getenv("HOME") or "") .. "/.cache/hypr_mosaic_mode"
local WS_CACHE_PATH = (os.getenv("HOME") or "") .. "/.cache/hypr_mosaic_workspaces.json"

local function write_state()
	local f = io.open(CACHE_PATH, "w")
	if f then
		f:write(_G.mosaic_mode.active and "1\n" or "0\n")
		f:close()
	end

	local parts = {}
	for id, v in pairs(_G.mosaic_mode.workspaces or {}) do
		table.insert(parts, string.format("%q: %s", tostring(id), v and "true" or "false"))
	end
	table.sort(parts)
	local json = string.format('{"active": %s, "workspaces": {%s}}\n',
		_G.mosaic_mode.active and "true" or "false",
		table.concat(parts, ", "))

	local fj = io.open(WS_CACHE_PATH, "w")
	if fj then
		fj:write(json)
		fj:close()
	end
end

local function load_state()
	local f = io.open(WS_CACHE_PATH, "r")
	if f then
		local content = f:read("*a") or ""
		f:close()
		local a = content:match('"active"%s*:%s*(%a+)')
		if a == "true" then
			_G.mosaic_mode.active = true
		elseif a == "false" then
			_G.mosaic_mode.active = false
		end
		local ws_block = content:match('"workspaces"%s*:%s*%{(.-)%}')
		if ws_block then
			for id, val in ws_block:gmatch('"([^"]+)"%s*:%s*(%a+)') do
				_G.mosaic_mode.workspaces[tonumber(id) or id] = (val == "true")
			end
		end
	end
end
load_state()

function M.is_active(ws_id)
	local state = _G.mosaic_mode
	if not state then
		return false
	end
	if ws_id then
		local num_id = tonumber(ws_id)
		if state.workspaces then
			if num_id and state.workspaces[num_id] ~= nil then
				return state.workspaces[num_id] == true
			elseif state.workspaces[ws_id] ~= nil then
				return state.workspaces[ws_id] == true
			elseif state.workspaces[tostring(ws_id)] ~= nil then
				return state.workspaces[tostring(ws_id)] == true
			end
		end
	end
	return state.active == true
end

-- Helpers
local function clamp(val, min_v, max_v)
	return math.max(min_v, math.min(max_v, val))
end

local function titlebar_h(w)
	if _G.window_has_hyprbar and _G.window_has_hyprbar(w) then
		return 30
	end
	return 0
end

local function is_ignorable(w)
	if not w then
		return true
	end
	if _G.window_is_transient_float and _G.window_is_transient_float(w) then
		return true
	end
	local pinned = false
	pcall(function()
		pinned = w.pinned and true or false
	end)
	if pinned then
		return true
	end
	local title = (w.title or ""):lower()
	if title:match("picture[%- ]in[%- ]picture") then
		return true
	end
	return false
end

local function get_work_area(mon)
	local is_rotated = (mon.transform and (mon.transform % 2 == 1))
	local scale = (mon.scale and mon.scale > 0) and mon.scale or 1
	local raw_w = is_rotated and mon.height or mon.width
	local raw_h = is_rotated and mon.width or mon.height
	local logical_w = math.floor(raw_w / scale + 0.5)
	local logical_h = math.floor(raw_h / scale + 0.5)

	local res = mon.reserved or {}
	local res_top = (res.top ~= nil) and res.top or 0
	local res_bottom = (res.bottom ~= nil) and res.bottom or 52
	local res_left = (res.left ~= nil) and res.left or 0
	local res_right = (res.right ~= nil) and res.right or 0

	local gap = 8
	return {
		x = mon.x + res_left + gap,
		y = mon.y + res_top + gap,
		w = logical_w - res_left - res_right - (gap * 2),
		h = logical_h - res_top - res_bottom - (gap * 2),
		gap = gap,
		-- Gapless full-bleed area (reserved bar space still respected).
		-- Used for solo-window fills so a single window looks maximized:
		-- no gaps, and apply_geom zeroes borders/rounding for it.
		fx = mon.x + res_left,
		fy = mon.y + res_top,
		fw = logical_w - res_left - res_right,
		fh = logical_h - res_top - res_bottom,
	}
end

local function resolve_workspace_monitor(ws_id)
	local monitors = hl.get_monitors() or {}
	if ws_id then
		for _, m in ipairs(monitors) do
			if m.active_workspace and (m.active_workspace.id == ws_id or m.active_workspace.name == tostring(ws_id)) then
				return m
			end
		end
		for _, w in ipairs(hl.get_workspace_windows(ws_id) or {}) do
			if _G.resolve_window_monitor then
				local m = _G.resolve_window_monitor(w)
				if m then return m end
			end
		end
	end
	return (hl.get_monitor_at_cursor and hl.get_monitor_at_cursor()) or monitors[1]
end

-- Windows with a Hyprland `size = {...}` rule must keep their fixed size
-- instead of being stretched to fill. Mirror of windowrules.lua + the
-- SKIP_GEOMETRY_CLASS list in floating-mode.lua.
local FIXED_SIZE_CLASSES = {
	["com.danklinux.dms"] = true,
	["org.gnome.loupe"] = true,
}

local function has_fixed_size_rule(w)
	if not w then
		return false
	end
	local cls = (w.class or w.initial_class or w.initialClass or ""):lower()
	return FIXED_SIZE_CLASSES[cls] == true
end

--------------------------------------------------------------------------------
-- Real tiling backend: lua:mosaic
--
-- Registers mosaic as a first-class Hyprland layout (hl.layout.register,
-- used as `lua:mosaic`). Windows stay TILED: the compositor calls recalculate
-- and owns geometry/animations/gaps. Floating windows (dialogs, file
-- managers via window rules, user Super+F floats) never reach recalculate.
-- When registration is unavailable, the legacy floating engine further below
-- takes over automatically (guarded by M.real_available()).
--------------------------------------------------------------------------------

local real_layout_ok = false
function M.real_available()
	return real_layout_ok == true
end

-- Shared first-error throttle: recalculate runs constantly, so never log raw.
local last_layout_err = nil
local function log_layout_err(msg)
	if msg ~= last_layout_err then
		last_layout_err = msg
		log("lua:mosaic: " .. tostring(msg))
	end
end

-- Defensive classify for layout target windows. Anything unreadable (or a
-- group target with no window) falls back to canvas = neutral 50/50.
local function classify_layout_window(w)
	if not w then
		return db.ARCHETYPES.canvas
	end
	local ok, arch = pcall(db.classify, w)
	if ok and arch then
		return arch
	end
	return db.ARCHETYPES.canvas
end

-- Persistent arrangement per workspace. Hyprland mouse drags (SUPER+drag)
-- float the window and re-tile it on release via newTarget (append at end),
-- so target order alone cannot tell left-drop from right-drop: dragging the
-- right window left still re-appends at the end, and vice versa. Keyboard
-- movewindow swaps adjacent targets in place (no transient removal), which
-- IS visible as a same-set reorder. Newcomers insert at archetype rank, so
-- open placement stays deterministic (zen still lands left of ghostty).
-- Sizes always follow archetype (duo_frac handles both orders), so a moved
-- window keeps its share on either side. Keyed by workspace id read off the
-- targets; the "__shared__" fallback degrades gracefully (fresh rank per
-- call, drags not remembered across workspace switches), never a crash.
--
-- Drag tracking: a drag shows up as shrink (n-1, dragged floated away) then
-- return (n, dragged re-appended). layout_order keeps the full order through
-- the shrink (grace period) instead of clobbering to the survivor, so the
-- return is recognized as a returner (not a newcomer) and ordered by DROP
-- POSITION (target.box / window.at centers, x in landscape, y when stacked),
-- not by append order and not by archetype rank. Truly new windows (never in
-- the full order, or pruned after the grace = closed) still use rank.
local layout_order = {} -- ws_key -> array of target ids (full, grace-kept)
local layout_prev_present = {} -- ws_key -> {id -> true} from last recalculate
local layout_last_seen = {} -- ws_key -> {id -> os.clock()}
local LAYOUT_DRAG_GRACE = 2.0 -- s: floated-for-drag returns; closed never does

local function layout_target_id(t, i)
	local ok, id = pcall(function()
		local w = t.window
		if not w then
			return nil
		end
		local sid = w.stable_id
		local addr = w.address
		local s1 = (sid ~= nil) and tostring(sid) or ""
		local s2 = (addr ~= nil) and tostring(addr):lower() or ""
		if s1 ~= "" or s2 ~= "" then
			return "w:" .. s1 .. "@" .. s2
		end
		return nil
	end)
	if ok and id then
		return id
	end
	return "i:" .. tostring(i)
end

local function layout_ws_key(targets)
	for _, t in ipairs(targets) do
		local ok, wid = pcall(function()
			local w = t.window
			local ws = w and w.workspace
			return ws and ws.id
		end)
		if ok and wid ~= nil then
			return "ws:" .. tostring(wid)
		end
	end
	return "ws:__shared__"
end

local function archetype_rank(arch)
	if not arch or not arch.name then
		return 2
	end
	if arch.name == "sidebar" then
		return 1
	elseif arch.name == "editor" then
		return 3
	elseif arch.name == "terminal" then
		return 4
	end
	return 2 -- canvas and everything else
end

-- Center of a layout target for drop-position detection. Prefers the
-- compositor target box (drop position right after re-tile); falls back to
-- window.at/size goals. Returns nil,nil when unreadable (never a crash).
local function layout_target_center(t)
	local ok, cx, cy = pcall(function()
		local b = t and t.box
		if type(b) == "table" then
			local x = tonumber(b.x)
			local y = tonumber(b.y)
			local w = tonumber(b.w) or tonumber(b.width)
			local h = tonumber(b.h) or tonumber(b.height)
			if x and y and w and h then
				return x + w / 2, y + h / 2
			end
		end
		local wobj = t and t.window
		if wobj then
			local at = wobj.at
			local sz = wobj.size
			if type(at) == "table" and type(sz) == "table" then
				local ax = tonumber(at.x)
				local ay = tonumber(at.y)
				local sx = tonumber(sz.x)
				local sy = tonumber(sz.y)
				if ax and ay and sx and sy then
					return ax + sx / 2, ay + sy / 2
				end
			end
		end
		return nil, nil
	end)
	if ok then
		return cx, cy
	end
	return nil, nil
end

-- Bucket order for layout targets (persistent, see above). Float archetypes
-- only appear here if the user manually untiled them, so they place as
-- neutral canvas. `stacked` selects the drop axis (y when portrait/narrow
-- rows, x otherwise) and must match mosaic_recalculate_inner's decision.
local function sort_layout_targets(targets, stacked)
	-- Classify once per unique id; dedupe incoming keeping the LAST
	-- occurrence (a dragged window re-appended at the end: latest = intent;
	-- also collapses phantom slots so no cell is ever assigned twice).
	local by_id, last_pos = {}, {}
	for i, t in ipairs(targets) do
		local id = layout_target_id(t, i)
		local arch = classify_layout_window(t.window)
		if arch.float then
			arch = db.ARCHETYPES.canvas
		end
		by_id[id] = { target = t, archetype = arch }
		last_pos[id] = i
	end
	local incoming = {}
	for id, pos in pairs(last_pos) do
		table.insert(incoming, { id = id, pos = pos })
	end
	table.sort(incoming, function(a, b) return a.pos < b.pos end)
	local incoming_ids = {}
	for _, e in ipairs(incoming) do
		table.insert(incoming_ids, e.id)
	end

	local key = layout_ws_key(targets)
	local prev = layout_order[key] or {}
	local prev_present = layout_prev_present[key] or {}
	local last_seen = layout_last_seen[key] or {}
	layout_last_seen[key] = last_seen
	local now = os.clock()
	local present = {}
	for _, id in ipairs(incoming_ids) do
		present[id] = true
		last_seen[id] = now
	end

	-- Full order with grace: keep missing ids that vanished recently (drag
	-- float-away). Older missing ids are closes: drop them for good.
	local pruned = {}
	local pruned_set = {}
	for _, id in ipairs(prev) do
		if present[id] then
			table.insert(pruned, id)
			pruned_set[id] = true
		else
			local seen = last_seen[id]
			if seen and (now - seen) < LAYOUT_DRAG_GRACE then
				table.insert(pruned, id)
				pruned_set[id] = true
			else
				last_seen[id] = nil
			end
		end
	end

	local newcomers, returners = {}, {}
	local returner_set = {}
	for _, id in ipairs(incoming_ids) do
		if not pruned_set[id] then
			table.insert(newcomers, id)
		elseif not prev_present[id] then
			table.insert(returners, id)
			returner_set[id] = true
		end
	end

	-- Survivors (+ returners) in persisted order; newcomers handled below.
	local function rank_insert_into(list, id)
		local r = archetype_rank(by_id[id].archetype)
		local at = #list + 1
		for j, eid in ipairs(list) do
			local er = by_id[eid] and archetype_rank(by_id[eid].archetype) or 2
			if er > r then
				at = j
				break
			end
		end
		table.insert(list, at, id)
	end

	local final_ids = nil
	local stored_ids = nil

	if #returners > 0 then
		-- Drag-return: order by DROP POSITION, never by append or rank.
		local old_present = {}
		for _, id in ipairs(pruned) do
			if present[id] and not returner_set[id] then
				-- survivors in old order; returners placed via drop below
				table.insert(old_present, id)
			end
		end
		-- Start from survivors in old order; place each returner by drop.
		local ordered_old = {}
		for _, id in ipairs(old_present) do
			table.insert(ordered_old, id)
		end
		local drop_ok = true
		for _, rid in ipairs(returners) do
			local rcx, rcy = layout_target_center(by_id[rid].target)
			if rcx == nil then
				drop_ok = false
				break
			end
			if #ordered_old == 1 and #incoming_ids == 2 then
				-- 1+1: the reported case. Left/top drop goes first.
				local sid = ordered_old[1]
				local scx, scy = layout_target_center(by_id[sid].target)
				if scx == nil then
					drop_ok = false
					break
				end
				if stacked then
					ordered_old = (rcy < scy) and { rid, sid } or { sid, rid }
				else
					ordered_old = (rcx < scx) and { rid, sid } or { sid, rid }
				end
			else
				-- N>2: swap the returner with the closest survivor cell
				-- (Hyprland swap semantics). Falls back to append below.
				local best, best_d2 = nil, nil
				for _, sid in ipairs(ordered_old) do
					local scx, scy = layout_target_center(by_id[sid].target)
					if scx ~= nil then
						local dx, dy = rcx - scx, rcy - scy
						local d2 = dx * dx + dy * dy
						if not best_d2 or d2 < best_d2 then
							best, best_d2 = sid, d2
						end
					end
				end
				if not best then
					drop_ok = false
					break
				end
				-- Insert at the closest cell's slot (shift, don't swap):
				-- dropping onto a cell takes it, others slide. For N=2
				-- this equals swap; for N>2 it matches tab-reorder feel.
				local at = #ordered_old + 1
				for j, eid in ipairs(ordered_old) do
					if eid == best then
						at = j
						break
					end
				end
				-- Decide before/after within the cell by drop axis.
				local bcx, bcy = layout_target_center(by_id[best].target)
				if bcx ~= nil then
					if stacked and rcy > bcy then
						at = at + 1
					elseif (not stacked) and rcx > bcx then
						at = at + 1
					end
				end
				table.insert(ordered_old, at, rid)
			end
		end
		if not drop_ok then
			-- Centers unreadable (or multi-returner race): incoming append
			-- order still beats archetype rank for a drag.
			ordered_old = {}
			for _, id in ipairs(incoming_ids) do
				if returner_set[id] or pruned_set[id] then
					table.insert(ordered_old, id)
				end
			end
			-- Any pruned-present ids missing from incoming (shouldn't
			-- happen here) keep old relative order at the front.
			for _, id in ipairs(pruned) do
				if present[id] and not returner_set[id] then
					local found = false
					for _, e in ipairs(ordered_old) do
						if e == id then
							found = true
							break
						end
					end
					if not found then
						table.insert(ordered_old, 1, id)
					end
				end
			end
		end
		-- Truly new windows (if any arrived the same frame) still rank in.
		for _, id in ipairs(newcomers) do
			rank_insert_into(ordered_old, id)
		end
		final_ids = ordered_old
		-- Stored keeps remaining grace-away ids (multi-drag) at the end.
		stored_ids = {}
		for _, id in ipairs(final_ids) do
			table.insert(stored_ids, id)
		end
		for _, id in ipairs(pruned) do
			if not present[id] then
				table.insert(stored_ids, id)
			end
		end
	elseif #newcomers > 0 then
		-- Genuine open / inter-workspace move: deterministic rank placement.
		local base = {}
		for _, id in ipairs(pruned) do
			if present[id] then
				table.insert(base, id)
			end
		end
		for _, id in ipairs(newcomers) do
			rank_insert_into(base, id)
		end
		final_ids = base
		stored_ids = {}
		for _, id in ipairs(final_ids) do
			table.insert(stored_ids, id)
		end
		for _, id in ipairs(pruned) do
			if not present[id] then
				table.insert(stored_ids, id)
			end
		end
	else
		local same_set = (#pruned == #incoming_ids)
		if same_set then
			-- Keyboard movewindow swap (no transient removal): adopt the
			-- compositor order wholesale so the move sticks.
			final_ids = incoming_ids
			stored_ids = incoming_ids
		else
			-- Transient shrink (drag in progress, close animating): keep
			-- survivors in persisted spots, keep the away window in stored
			-- for its imminent return instead of clobbering.
			local base = {}
			for _, id in ipairs(pruned) do
				if present[id] then
					table.insert(base, id)
				end
			end
			final_ids = base
			stored_ids = pruned
		end
	end

	if #stored_ids == 0 then
		layout_order[key] = nil
	else
		layout_order[key] = stored_ids
	end
	layout_prev_present[key] = present

	local ordered = {}
	for _, id in ipairs(final_ids) do
		local e = by_id[id]
		if e then
			table.insert(ordered, { target = e.target, archetype = e.archetype })
		end
	end
	return ordered
end

-- Numeric area dims. The layout API passes area as {x, y, w, h}; anything
-- else degrades to equal splits (never a crash).
local function layout_area_dims(area)
	if type(area) ~= "table" then
		return nil, nil
	end
	local W = tonumber(area.w) or tonumber(area.width)
	local H = tonumber(area.h) or tonumber(area.height)
	return W, H
end

-- Sidebar width as a fraction of W (mirrors the legacy clamp sizing).
local function layout_sidebar_frac(W, ratio, min_w, max_w)
	if not W or W <= 0 then
		return ratio
	end
	return clamp(W * ratio, min_w, max_w) / W
end

-- k full-width rows out of box via chained splits. NOTE: the remainder is
-- split(box, "bottom", 1 - f), NOT f — "bottom f" is the bottom f-sized
-- slice, which collapses rows and leaves dead space (invisible at f = 0.5,
-- which is why only k > 2 ever broke).
local function layout_rows(ctx, box, k)
	local out = {}
	local rest = box
	for i = 1, k - 1 do
		local f = 1 / (k - i + 1)
		table.insert(out, ctx:split(rest, "top", f))
		rest = ctx:split(rest, "bottom", 1 - f)
	end
	table.insert(out, rest)
	return out
end

-- k full-height columns out of box via chained splits.
local function layout_cols(ctx, box, k)
	local out = {}
	local rest = box
	for i = 1, k - 1 do
		local f = 1 / (k - i + 1)
		table.insert(out, ctx:split(rest, "left", f))
		rest = ctx:split(rest, "right", 1 - f)
	end
	table.insert(out, rest)
	return out
end

-- N = 2 width fraction for the left window (mirrors the legacy duo table).
local function layout_duo_frac(a1, a2)
	if a1.name == "canvas" and a2.name == "terminal" then return 0.67 end
	if a2.name == "canvas" and a1.name == "terminal" then return 0.33 end
	if a1.name == "editor" and a2.name == "terminal" then return 0.64 end
	if a2.name == "editor" and a1.name == "terminal" then return 0.36 end
	if a1.name == "editor" and a2.name == "canvas" then return 0.52 end
	if a2.name == "editor" and a1.name == "canvas" then return 0.48 end
	if a1.name == a2.name then return 0.50 end
	local t1 = a1.target_ratio or 0.50
	local t2 = a2.target_ratio or 0.50
	return clamp(t1 / (t1 + t2), 0.32, 0.68)
end

-- Placement log for the current recalculate (see safe_place). Reset per run.
-- Declared before safe_place so it binds as an upvalue (Lua lexical scope).
local active_placements = nil

local function safe_place(target, box)
	local ok, err = pcall(function()
		target:place(box)
	end)
	if not ok then
		log_layout_err("place failed: " .. tostring(err))
		return
	end
	-- Record what was actually placed for _G.mosaic_debug().
	if active_placements then
		local cls = "?"
		pcall(function()
			local w = target.window
			if w then
				cls = tostring(w.class or w.initial_class or "?")
			end
		end)
		table.insert(active_placements, {
			class = cls,
			x = box.x, y = box.y, w = box.w, h = box.h,
		})
	end
end

local function mosaic_recalculate_inner(ctx)
	local targets = (ctx and ctx.targets) or {}
	if #targets == 0 then
		return
	end
	local area = ctx.area
	if type(area) ~= "table" then
		return
	end
	local W, H = layout_area_dims(area)
	local portrait = (W and H and H > W) or false
	local narrow = (W and W < 600) or false
	local stacked = portrait or narrow

	local ordered = sort_layout_targets(targets, stacked)
	local n = #ordered
	if n == 0 then
		return
	end

	-- Snapshot for _G.mosaic_debug(): what the layout last saw. If targets
	-- is 0 while windows are visibly there, the workspace rule isn't active
	-- (or everything is floating) — that is the first thing to check.
	active_placements = {}
	_G.mosaic_last_recalc = {
		targets = #targets,
		w = W,
		h = H,
		portrait = portrait and true or false,
		time = os.date("%H:%M:%S"),
	}

	-- N = 1: solo fill. Gaps/borders come from the compositor config and the
	-- existing tiled smart-gaps workspace rules (no scripted hacks needed).
	if n == 1 then
		safe_place(ordered[1].target, area)
		return
	end

	-- Portrait/narrow: always stack full-width rows, at any count. Columns
	-- here would be half (or less) of an already-narrow width: chat/canvas
	-- content that tolerates narrow-but-tall (landscape sidebar) or
	-- short-but-wide (stacked rows) breaks when it gets neither — exactly
	-- what the 2x2 quarters did. Rows keep full width forever and grow
	-- stably: adding a window resplits heights, never the strategy.
	if stacked then
		local rows = layout_rows(ctx, area, n)
		for i = 1, n do
			safe_place(ordered[i].target, rows[i])
		end
		return
	end

	-- N = 2 landscape: asymmetric duo, canvas/editor left of terminal.
	if n == 2 then
		local a1, a2 = ordered[1].archetype, ordered[2].archetype
		local f = layout_duo_frac(a1, a2)
		if a1.name == "sidebar" and a2.name ~= "sidebar" then
			f = layout_sidebar_frac(W, 0.26, 380, 480)
		elseif a2.name == "sidebar" and a1.name ~= "sidebar" then
			f = 1 - layout_sidebar_frac(W, 0.26, 380, 480)
		end
		safe_place(ordered[1].target, ctx:split(area, "left", f))
		safe_place(ordered[2].target, ctx:split(area, "right", 1 - f))
		return
	end

	-- N = 3 landscape.
	if n == 3 then
		local a1, a2, a3 = ordered[1].archetype, ordered[2].archetype, ordered[3].archetype
		if a1.name == "sidebar" or a2.name == "sidebar" or a3.name == "sidebar" then
			-- Sidebar | center | right columns.
			local fs = layout_sidebar_frac(W, 0.24, 360, 460)
			local rest = ctx:split(area, "right", 1 - fs)
			local wr_frac = W and (clamp(W * 0.28, 400, 560) / W) or 0.28
			local fr = ((1 - fs) > 0) and clamp(wr_frac / (1 - fs), 0, 1) or 0.5
			safe_place(ordered[1].target, ctx:split(area, "left", fs))
			safe_place(ordered[2].target, ctx:split(rest, "left", 1 - fr))
			safe_place(ordered[3].target, ctx:split(rest, "right", fr))
			return
		end
		-- Master left full height, two stacked right.
		local f = 0.58
		if (a1.name == "canvas" or a1.name == "editor") and a2.name == "terminal" and a3.name == "terminal" then
			f = 0.62
		end
		local R = ctx:split(area, "right", 1 - f)
		safe_place(ordered[1].target, ctx:split(area, "left", f))
		local rows = layout_rows(ctx, R, 2)
		safe_place(ordered[2].target, rows[1])
		safe_place(ordered[3].target, rows[2])
		return
	end

	-- N = 4 landscape: sidebar variant or clean 2x2 grid.
	if n == 4 then
		if ordered[1].archetype.name == "sidebar" then
			local fs = layout_sidebar_frac(W, 0.22, 340, 460)
			local rest = ctx:split(area, "right", 1 - fs)
			local wst_frac = W and (clamp(W * 0.30, 450, 600) / W) or 0.30
			local rest_w = 1 - fs
			local fc = (rest_w > 0) and clamp(1 - wst_frac / rest_w, 0, 1) or 0.5
			safe_place(ordered[1].target, ctx:split(area, "left", fs))
			safe_place(ordered[2].target, ctx:split(rest, "left", fc))
			local S = ctx:split(rest, "right", 1 - fc)
			local rows = layout_rows(ctx, S, 2)
			safe_place(ordered[3].target, rows[1])
			safe_place(ordered[4].target, rows[2])
			return
		end
		local L = ctx:split(area, "left", 0.5)
		local R = ctx:split(area, "right", 0.5)
		local rL = layout_rows(ctx, L, 2)
		local rR = layout_rows(ctx, R, 2)
		safe_place(ordered[1].target, rL[1])
		safe_place(ordered[2].target, rR[1])
		safe_place(ordered[3].target, rL[2])
		safe_place(ordered[4].target, rR[2])
		return
	end

	-- N = 5 landscape: masonry (left full | mid 2-stack | right 2-stack).
	if n == 5 then
		local L = ctx:split(area, "left", 0.44)
		local RR = ctx:split(area, "right", 0.56)
		local M = ctx:split(RR, "left", 0.30 / 0.56)
		local R = ctx:split(RR, "right", 0.26 / 0.56)
		safe_place(ordered[1].target, L)
		local rM = layout_rows(ctx, M, 2)
		local rR = layout_rows(ctx, R, 2)
		safe_place(ordered[2].target, rM[1])
		safe_place(ordered[3].target, rM[2])
		safe_place(ordered[4].target, rR[1])
		safe_place(ordered[5].target, rR[2])
		return
	end

	-- N > 5 landscape: uniform 3-column grid. Real tiling has no overlapping
	-- cascade; every target must own non-overlapping space.
	local rows = math.ceil(n / 3)
	local full_rows = layout_rows(ctx, area, rows)
	for r = 1, rows do
		local from = (r - 1) * 3 + 1
		local cnt = math.min(3, n - from + 1)
		if cnt == 3 then
			local cs = layout_cols(ctx, full_rows[r], 3)
			for k = 0, 2 do
				safe_place(ordered[from + k].target, cs[k + 1])
			end
		elseif cnt == 2 then
			safe_place(ordered[from].target, ctx:split(full_rows[r], "left", 0.5))
			safe_place(ordered[from + 1].target, ctx:split(full_rows[r], "right", 0.5))
		else
			safe_place(ordered[from].target, full_rows[r])
		end
	end
end

local function mosaic_recalculate(ctx)
	local ok, err = pcall(mosaic_recalculate_inner, ctx)
	if not ok then
		log_layout_err("recalculate failed: " .. tostring(err))
	elseif _G.mosaic_last_recalc then
		_G.mosaic_last_recalc.placements = active_placements or {}
	end
	active_placements = nil
end

local function register_mosaic_layout()
	if not (hl.layout and hl.layout.register) then
		log("lua:mosaic unavailable (hl.layout.register missing) — legacy floating engine active")
		return false
	end
	local ok, err = pcall(hl.layout.register, "mosaic", { recalculate = mosaic_recalculate })
	if not ok then
		log("lua:mosaic registration failed: " .. tostring(err) .. " — legacy floating engine active")
		return false
	end
	log("lua:mosaic registered as a real tiling layout")
	return true
end

real_layout_ok = register_mosaic_layout()
_G.mosaic_real_layout = real_layout_ok

-- Point a workspace at a tiling algorithm (real-layout path). Repeated calls
-- for the same workspace update the rule in place.
local function set_ws_layout(id, layout_name)
	if not real_layout_ok then
		return false
	end
	local ok, err = pcall(hl.workspace_rule, { workspace = tostring(id), layout = layout_name })
	log(string.format(">>> WS %s layout -> %s (%s)", tostring(id), layout_name, ok and "ok" or ("FAILED: " .. tostring(err))))
	return ok
end

-- One-time cleanup when entering real mosaic: unfloat windows the legacy
-- floating engine managed and clear its scripted props, so lua:mosaic starts
-- from clean tiled state. Genuine floats (transients, pinned, utilities,
-- fixed-size dialogs) are spared.
local function migrate_legacy_floats(id)
	for _, w in ipairs(hl.get_workspace_windows(id) or {}) do
		pcall(function()
			if is_ignorable(w) then
				return
			end
			hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "no_anim", value = "unset" }))
			hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "border_size", value = "unset" }))
			hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "rounding", value = "unset" }))
			local arch = db.classify(w)
			if not arch.float and not has_fixed_size_rule(w) and w.floating then
				hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
			end
		end)
	end
end

-- Re-assert persisted mosaic workspaces after (re)load: compositor workspace
-- rules do not survive a restart, the state file does. Migration runs here
-- too: legacy floats persist across a reload, and floating windows are
-- invisible to layouts, so without it an old session comes back as a pile of
-- stale overlapping floats (new tiles land around/under them).
if real_layout_ok then
	for id, v in pairs(_G.mosaic_mode.workspaces or {}) do
		if v then
			set_ws_layout(id, "lua:mosaic")
			migrate_legacy_floats(id)
		end
	end
end

-- Orientation helpers.
-- The solver splits along the SHORT axis so windows keep a usable aspect:
-- landscape (wide) -> side-by-side columns, portrait (tall) -> stacked rows.
-- This is derived from the live work area each time, so it adapts to any
-- monitor / rotation / scale without hardcoded resolutions.
local function is_portrait(wa)
	return (wa.h or 0) > (wa.w or 0)
end

-- True when the work area is too narrow for any side-by-side layout to
-- honor minimum usable widths. Falls back to stacking even on landscape
-- (tiny outputs, scaled VMs, unexplored systems).
local function too_narrow_for_columns(wa)
	return (wa.w or 0) < 600
end

-- Vertical stack of n full-width rows. Returns array of rects.
local function stack_rows(wa, gap, n)
	local rects = {}
	if n <= 0 then
		return rects
	end
	local total_gap = (n - 1) * gap
	local base_h = math.floor((wa.h - total_gap) / n)
	local y = wa.y
	for i = 1, n do
		local h = (i < n) and base_h or (wa.h - (y - wa.y))
		table.insert(rects, { x = wa.x, y = y, w = wa.w, h = h })
		y = y + h + gap
	end
	return rects
end

-- Sorting windows: sidebars to left, main canvas/editor in center, terminals to right
local function sort_mosaic_windows(windows)
	local sidebars, editors, canvases, terminals = {}, {}, {}, {}

	for _, w in ipairs(windows) do
		local arch = db.classify(w)
		local item = { win = w, archetype = arch }
		if arch.name == "sidebar" then
			table.insert(sidebars, item)
		elseif arch.name == "editor" then
			table.insert(editors, item)
		elseif arch.name == "terminal" then
			table.insert(terminals, item)
		else
			table.insert(canvases, item)
		end
	end

	-- Order: Sidebars on the left, Canvases/Editors in the center/main, Terminals on the right
	local ordered = {}
	for _, it in ipairs(sidebars) do table.insert(ordered, it) end
	for _, it in ipairs(canvases) do table.insert(ordered, it) end
	for _, it in ipairs(editors) do table.insert(ordered, it) end
	for _, it in ipairs(terminals) do table.insert(ordered, it) end

	return ordered
end

-- The Mosaic Geometric Solver
-- Returns array of { win = w, rect = { x, y, w, h } }
local function solve_mosaic(items, wa)
	local n = #items
	local results = {}
	if n == 0 then
		return results
	end

	local gap = wa.gap or 8

	-- Case N = 1: single window fills the whole work area, unless it has
	-- a Hyprland fixed-size rule (or is a floating utility) — then keep it
	-- centered at its current size.
	if n == 1 then
		local it = items[1]
		local w = it.win
		local arch = it.archetype or db.classify(w)
		if arch.float or has_fixed_size_rule(w) then
			local uw = w.size and w.size.x or wa.w
			local uh = w.size and w.size.y or wa.h
			uw = math.min(uw, wa.w)
			uh = math.min(uh, wa.h)
			local x = wa.x + math.floor((wa.w - uw) / 2)
			local y = wa.y + math.floor((wa.h - uh) / 2)
			table.insert(results, { win = w, rect = { x = x, y = y, w = uw, h = uh } })
			return results
		end
		table.insert(results, { win = w, rect = { x = wa.fx, y = wa.fy, w = wa.fw, h = wa.fh }, solo = true })
		return results
	end

	-- Case N = 2: Intelligent Asymmetric or Symmetric Duo
	if n == 2 then
		local it1, it2 = items[1], items[2]
		local a1, a2 = it1.archetype, it2.archetype
		local w1, w2 = it1.win, it2.win

		-- Portrait / very narrow: stack full-width rows (top/bottom 50/50).
		-- Side-by-side columns on a tall screen produce skinny strips that
		-- clients can't honor (their min widths overflow -> visual overlap).
		-- Scoped to portrait/narrow only; landscape keeps columns below.
		if is_portrait(wa) or too_narrow_for_columns(wa) then
			local rows = stack_rows(wa, gap, 2)
			table.insert(results, { win = w1, rect = rows[1] })
			table.insert(results, { win = w2, rect = rows[2] })
			return results
		end

		-- If one is a sidebar, it gets its fixed comfortable sidebar width
		if a1.name == "sidebar" and a2.name ~= "sidebar" then
			local w_side = clamp(math.floor(wa.w * 0.26), 380, 480)
			local w_other = wa.w - gap - w_side
			table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = w_side, h = wa.h } })
			table.insert(results, { win = w2, rect = { x = wa.x + w_side + gap, y = wa.y, w = w_other, h = wa.h } })
			return results
		elseif a2.name == "sidebar" and a1.name ~= "sidebar" then
			local w_side = clamp(math.floor(wa.w * 0.26), 380, 480)
			local w_other = wa.w - gap - w_side
			table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = w_other, h = wa.h } })
			table.insert(results, { win = w2, rect = { x = wa.x + w_other + gap, y = wa.y, w = w_side, h = wa.h } })
			return results
		end

		-- Archetype pairings:
		local w1_ratio = 0.50
		if a1.name == "canvas" and a2.name == "terminal" then
			w1_ratio = 0.67 -- Browser 67%, Terminal 33%
		elseif a2.name == "canvas" and a1.name == "terminal" then
			w1_ratio = 0.33
		elseif a1.name == "editor" and a2.name == "terminal" then
			w1_ratio = 0.64 -- Editor 64%, Terminal 36%
		elseif a2.name == "editor" and a1.name == "terminal" then
			w1_ratio = 0.36
		elseif a1.name == "editor" and a2.name == "canvas" then
			w1_ratio = 0.52 -- Web dev: 52% Editor, 48% Browser
		elseif a2.name == "editor" and a1.name == "canvas" then
			w1_ratio = 0.48
		elseif a1.name == a2.name then
			w1_ratio = 0.50 -- Clean 50/50 for identical archetypes
		else
			local t1 = a1.target_ratio or 0.50
			local t2 = a2.target_ratio or 0.50
			w1_ratio = clamp(t1 / (t1 + t2), 0.32, 0.68)
		end

		local width1 = math.floor((wa.w - gap) * w1_ratio)
		local width2 = wa.w - gap - width1

		table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = width1, h = wa.h } })
		table.insert(results, { win = w2, rect = { x = wa.x + width1 + gap, y = wa.y, w = width2, h = wa.h } })
		return results
	end

	-- Case N = 3: Trio (3 Columns or Master + 2-Stack T-Layout)
	if n == 3 then
		local it1, it2, it3 = items[1], items[2], items[3]
		local w1, w2, w3 = it1.win, it2.win, it3.win
		local a1, a2, a3 = it1.archetype, it2.archetype, it3.archetype

		-- Portrait / very narrow: 3 full-width rows. Columns here would be
		-- ~1/3 of an already-narrow width (unusable + overflow overlap).
		if is_portrait(wa) or too_narrow_for_columns(wa) then
			local rows = stack_rows(wa, gap, 3)
			table.insert(results, { win = w1, rect = rows[1] })
			table.insert(results, { win = w2, rect = rows[2] })
			table.insert(results, { win = w3, rect = rows[3] })
			return results
		end

		-- If any is sidebar: 3 columns (Sidebar, Center Main, Right Secondary)
		if a1.name == "sidebar" or a2.name == "sidebar" or a3.name == "sidebar" then
			local ws_side = clamp(math.floor(wa.w * 0.24), 360, 460)
			local ws_right = clamp(math.floor(wa.w * 0.28), 400, 560)
			local ws_center = wa.w - (2 * gap) - ws_side - ws_right

			table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = ws_side, h = wa.h } })
			table.insert(results, { win = w2, rect = { x = wa.x + ws_side + gap, y = wa.y, w = ws_center, h = wa.h } })
			table.insert(results, { win = w3, rect = { x = wa.x + ws_side + ws_center + (2 * gap), y = wa.y, w = ws_right, h = wa.h } })
			return results
		end

		-- If 1 Main (Canvas or Editor) + 2 Terminals: Left (62%), Right 2-stack (38%)
		if (a1.name == "canvas" or a1.name == "editor") and (a2.name == "terminal" and a3.name == "terminal") then
			local w_main = math.floor((wa.w - gap) * 0.62)
			local w_stack = wa.w - gap - w_main
			local h_half = math.floor((wa.h - gap) * 0.50)
			local h_rem = wa.h - gap - h_half

			table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = w_main, h = wa.h } })
			table.insert(results, { win = w2, rect = { x = wa.x + w_main + gap, y = wa.y, w = w_stack, h = h_half } })
			table.insert(results, { win = w3, rect = { x = wa.x + w_main + gap, y = wa.y + h_half + gap, w = w_stack, h = h_rem } })
			return results
		end

		-- Master + 2-Stack: Left takes 58% full height, Right splits top/bottom
		local w_left = math.floor((wa.w - gap) * 0.58)
		local w_right = wa.w - gap - w_left
		local h_half = math.floor((wa.h - gap) * 0.50)
		local h_rem = wa.h - gap - h_half

		table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = w_left, h = wa.h } })
		table.insert(results, { win = w2, rect = { x = wa.x + w_left + gap, y = wa.y, w = w_right, h = h_half } })
		table.insert(results, { win = w3, rect = { x = wa.x + w_left + gap, y = wa.y + h_half + gap, w = w_right, h = h_rem } })
		return results
	end

	-- Case N = 4: Power Grid (Sidebar + Main + 2-Stack OR 2x2 Grid)
	if n == 4 then
		local it1, it2, it3, it4 = items[1], items[2], items[3], items[4]
		local w1, w2, w3, w4 = it1.win, it2.win, it3.win, it4.win
		-- 2x2 grid works in both orientations. The 3-column sidebar layout
		-- below would be unusably narrow on portrait, so it is landscape-only.
		local has_sidebar = (it1.archetype.name == "sidebar")
			and not is_portrait(wa) and not too_narrow_for_columns(wa)

		if has_sidebar then
			-- Sidebar Left (22%) | Center Main (48%) | Right 2-Stack (30%)
			local w_side = clamp(math.floor(wa.w * 0.22), 340, 460)
			local w_stack = clamp(math.floor(wa.w * 0.30), 450, 600)
			local w_center = wa.w - (2 * gap) - w_side - w_stack
			local h_half = math.floor((wa.h - gap) * 0.50)
			local h_rem = wa.h - gap - h_half

			table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = w_side, h = wa.h } })
			table.insert(results, { win = w2, rect = { x = wa.x + w_side + gap, y = wa.y, w = w_center, h = wa.h } })
			table.insert(results, { win = w3, rect = { x = wa.x + w_side + w_center + (2 * gap), y = wa.y, w = w_stack, h = h_half } })
			table.insert(results, { win = w4, rect = { x = wa.x + w_side + w_center + (2 * gap), y = wa.y + h_half + gap, w = w_stack, h = h_rem } })
			return results
		else
			-- Clean 2x2 Grid
			local col_w = math.floor((wa.w - gap) * 0.50)
			local row_h = math.floor((wa.h - gap) * 0.50)
			local col_w2 = wa.w - gap - col_w
			local row_h2 = wa.h - gap - row_h

			table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = col_w, h = row_h } })
			table.insert(results, { win = w2, rect = { x = wa.x + col_w + gap, y = wa.y, w = col_w2, h = row_h } })
			table.insert(results, { win = w3, rect = { x = wa.x, y = wa.y + row_h + gap, w = col_w, h = row_h2 } })
			table.insert(results, { win = w4, rect = { x = wa.x + col_w + gap, y = wa.y + row_h + gap, w = col_w2, h = row_h2 } })
			return results
		end
	end

	-- Case N >= 5: Adaptive Multi-Column Masonry (landscape) /
	-- 2-column grid (portrait or very narrow, where 3 columns won't fit).
	if is_portrait(wa) or too_narrow_for_columns(wa) then
		local cols = 2
		local rows = math.ceil(n / cols)
		local col_w = math.floor((wa.w - gap) / cols)
		local col_w2 = wa.w - gap - col_w
		local row_h = math.floor((wa.h - (rows - 1) * gap) / rows)
		for i = 1, n do
			local r = math.floor((i - 1) / cols)
			local c = (i - 1) % cols
			local last_row_single = (r == rows - 1) and (n % cols == 1)
			local cw = last_row_single and wa.w or ((c == 0) and col_w or col_w2)
			local cx = (last_row_single or c == 0) and wa.x or (wa.x + col_w + gap)
			local cy = wa.y + r * (row_h + gap)
			local ch = (r == rows - 1) and (wa.h - (cy - wa.y)) or row_h
			table.insert(results, { win = items[i].win, rect = { x = cx, y = cy, w = cw, h = ch } })
		end
		return results
	end

	local w_left = math.floor((wa.w - (2 * gap)) * 0.44)
	local w_mid = math.floor((wa.w - (2 * gap)) * 0.30)
	local w_right = wa.w - (2 * gap) - w_left - w_mid
	local h_half = math.floor((wa.h - gap) * 0.50)
	local h_rem = wa.h - gap - h_half

	table.insert(results, { win = items[1].win, rect = { x = wa.x, y = wa.y, w = w_left, h = wa.h } })
	table.insert(results, { win = items[2].win, rect = { x = wa.x + w_left + gap, y = wa.y, w = w_mid, h = h_half } })
	table.insert(results, { win = items[3].win, rect = { x = wa.x + w_left + gap, y = wa.y + h_half + gap, w = w_mid, h = h_rem } })
	table.insert(results, { win = items[4].win, rect = { x = wa.x + w_left + w_mid + (2 * gap), y = wa.y, w = w_right, h = h_half } })
	table.insert(results, { win = items[5].win, rect = { x = wa.x + w_left + w_mid + (2 * gap), y = wa.y + h_half + gap, w = w_right, h = h_rem } })

	if n > 5 then
		for i = 6, n do
			-- Wrap the drift so a deep stack stays on screen instead of
			-- sliding off the work area on new/unexplored setups.
			local step = ((i - 6) % 10) * 20
			table.insert(results, { win = items[i].win, rect = { x = wa.x + step, y = wa.y + step, w = w_mid, h = h_half } })
		end
	end

	return results
end

-- False only when the client is provably gone (mid-close). Unknown (nil)
-- counts as live so odd clients never get skipped by accident.
local function is_live_window(w)
	if not w then
		return false
	end
	local ok, mapped = pcall(function()
		return w.mapped
	end)
	if ok and mapped == false then
		return false
	end
	return true
end

-- True when the workspace is in the loose cascade zone (landscape N>5):
-- overflow windows overlap by design, so re-tiling on every close just
-- reshuffles the stack and fights the close animation. Survivors keep
-- their spots instead. Portrait/narrow grids stay strict (no overlap).
local function in_cascade_zone(ws_id)
	local mon = resolve_workspace_monitor(ws_id)
	if not mon then
		return false
	end
	local wa = get_work_area(mon)
	if is_portrait(wa) or too_narrow_for_columns(wa) then
		return false
	end
	local n = 0
	for _, w in ipairs(hl.get_workspace_windows(ws_id) or {}) do
		if not is_ignorable(w) and is_live_window(w) then
			local ok, arch = pcall(db.classify, w)
			if ok and arch and not arch.float then
				n = n + 1
			end
		end
	end
	return n > 5
end

local function force_unmaximize(w)
	pcall(function()
		hl.dispatch(hl.dsp.window.fullscreen({
			window = w, mode = "maximized", action = "unset", layout_aware = false,
		}))
		hl.dispatch(hl.dsp.window.fullscreen({
			window = w, mode = "fullscreen", action = "unset", layout_aware = false,
		}))
		hl.dispatch(hl.dsp.window.fullscreen_state({
			window = w, internal = 0, client = 0, action = "set", layout_aware = false,
		}))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "border_size", value = "unset" }))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "rounding", value = "unset" }))
	end)
end

-- Apply positions smoothly via Hyprland dispatcher
function M.apply_workspace(ws_id)
	local ws = ws_id and { id = ws_id } or hl.get_active_workspace()
	if not ws or not ws.id then
		return
	end
	local id = tonumber(ws.id) or ws.id

	if not M.is_active(id) then
		return
	end

	-- Real-layout path: the compositor tiles; just make sure this workspace
	-- points at lua:mosaic. No window iteration (user floats stay floating).
	if real_layout_ok then
		set_ws_layout(id, "lua:mosaic")
		return
	end

	local mon = resolve_workspace_monitor(id)
	if not mon then
		return
	end

	local wa = get_work_area(mon)
	local all_windows = hl.get_workspace_windows(id) or {}
	local mosaic_windows = {}

	for _, w in ipairs(all_windows) do
		if not is_ignorable(w) then
			local arch = db.classify(w)
			if not arch.float then
				table.insert(mosaic_windows, w)
			else
				-- Utility window: center gently
				pcall(function()
					force_unmaximize(w)
					if not w.floating then
						hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
					end
					local uw = math.min(w.size.x, wa.w - 40)
					local uh = math.min(w.size.y, wa.h - 40)
					local ux = wa.x + math.floor((wa.w - uw) / 2)
					local uy = wa.y + math.floor((wa.h - uh) / 2)
					hl.dispatch(hl.dsp.window.resize({ window = w, x = uw, y = uh, relative = false }))
					hl.dispatch(hl.dsp.window.move({ window = w, x = ux, y = uy }))
				end)
			end
		end
	end

	local sorted = sort_mosaic_windows(mosaic_windows)
	local layout = solve_mosaic(sorted, wa)

	log(string.format(">>> Applying mosaic to %d windows on WS %s", #layout, tostring(id)))

	local function apply_geom(w, rect, solo)
		if not is_live_window(w) then
			return
		end
		local th = titlebar_h(w)
		force_unmaximize(w)
		if not w.floating then
			hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
		end
		if solo then
			-- Solo fill: chromeless like a maximize (smart-gaps equivalent
			-- for mosaic floats, which the tiled workspace rules don't match).
			pcall(function()
				hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "border_size", value = 0 }))
				hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "rounding", value = 0 }))
			end)
		end
		hl.dispatch(hl.dsp.window.resize({
			window = w,
			x = rect.w,
			y = rect.h - th,
			relative = false,
		}))
		hl.dispatch(hl.dsp.window.move({
			window = w,
			x = rect.x,
			y = rect.y + th,
		}))
	end

	for _, item in ipairs(layout) do
		pcall(function()
			apply_geom(item.win, item.rect, item.solo)
		end)
	end

	-- Delayed second pass to enforce geometry after Wayland client buffer negotiation (e.g. Zen / Firefox).
	-- Skips windows that died since (e.g. closed via hyprbar just now) so we
	-- never dispatch resizes at a dead client mid-close.
	hl.timer(function()
		for _, item in ipairs(layout) do
			if is_live_window(item.win) then
				pcall(function()
					apply_geom(item.win, item.rect, item.solo)
				end)
			end
		end
	end, { timeout = 120, type = "oneshot" })
end

-- Toggle Mosaic Mode for Workspace
function M.toggle(ws_id)
	local ws = ws_id and { id = ws_id } or hl.get_active_workspace()
	if not ws or not ws.id then
		return
	end
	local id = tonumber(ws.id) or ws.id

	local current = M.is_active(id)
	local next_state = not current
	_G.mosaic_mode.workspaces[id] = next_state
	write_state()

	log(string.format(">>> MOSAIC TOGGLE: WS %s is now %s", tostring(id), next_state and "MOSAIC" or "OFF"))

	if next_state then
		if real_layout_ok then
			set_ws_layout(id, "lua:mosaic")
			migrate_legacy_floats(id)
		else
			M.apply_workspace(id)
		end
	else
		if real_layout_ok then
			set_ws_layout(id, "dwindle")
		else
			-- Return windows to native tiling
			local windows = hl.get_workspace_windows(id) or {}
			for _, w in ipairs(windows) do
				if not is_ignorable(w) and w.floating then
					pcall(function()
						hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
					end)
				end
			end
		end
	end

	local lf = io.open("/tmp/hypr_layout_mode", "w")
	if lf then
		lf:write((next_state and "mosaic" or "tiled") .. "\n")
		lf:close()
	end
end

_G.set_workspace_layout_mode = function(mode, ws_id)
	local ws = ws_id and { id = ws_id } or hl.get_active_workspace()
	if not ws or not ws.id then
		return
	end
	local id = tonumber(ws.id) or ws.id
	mode = (mode or "tiled"):lower()

	log(string.format(">>> SET LAYOUT MODE: WS %s -> %s", tostring(id), mode))

	if mode == "mosaic" then
		if _G.floating_mode and _G.floating_mode.workspaces then
			_G.floating_mode.workspaces[id] = false
		end
		_G.mosaic_mode.workspaces[id] = true
		write_state()
		if real_layout_ok then
			set_ws_layout(id, "lua:mosaic")
			migrate_legacy_floats(id)
		else
			M.apply_workspace(id)
		end
	elseif mode == "floating" then
		_G.mosaic_mode.workspaces[id] = false
		write_state()
		if _G.floating_mode then
			_G.floating_mode.workspaces = _G.floating_mode.workspaces or {}
			_G.floating_mode.workspaces[id] = true
		end
		for _, w in ipairs(hl.get_workspace_windows(id) or {}) do
			pcall(function()
				if not is_ignorable(w) and not w.floating then
					hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
				end
			end)
		end
	else
		-- tiled
		_G.mosaic_mode.workspaces[id] = false
		write_state()
		if _G.floating_mode and _G.floating_mode.workspaces then
			_G.floating_mode.workspaces[id] = false
		end
		if real_layout_ok then
			set_ws_layout(id, "dwindle")
		else
			for _, w in ipairs(hl.get_workspace_windows(id) or {}) do
				pcall(function()
					if not is_ignorable(w) and w.floating then
						hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
					end
				end)
			end
		end
	end

	local function write_indicator(path, content)
		local f = io.open(path, "w")
		if f then
			f:write(content)
			f:close()
		end
	end

	local home = os.getenv("HOME") or ""
	write_indicator("/tmp/hypr_layout_mode", mode .. "\n")
	write_indicator(home .. "/.cache/hypr_layout_mode", mode .. "\n")
	write_indicator("/tmp/hypr_floating_mode", (mode == "floating" and "1\n" or "0\n"))
	write_indicator(home .. "/.cache/hypr_floating_mode", (mode == "floating" and "1\n" or "0\n"))
end

_G.get_workspace_layout_mode = function(ws_id)
	local ws = ws_id and { id = ws_id } or hl.get_active_workspace()
	if not ws or not ws.id then
		return "tiled"
	end
	local id = tonumber(ws.id) or ws.id
	if _G.mosaic_mode and _G.mosaic_mode.workspaces and _G.mosaic_mode.workspaces[id] == true then
		return "mosaic"
	end
	if _G.floating_mode and _G.floating_mode.workspaces and _G.floating_mode.workspaces[id] == true then
		return "floating"
	end
	if _G.floating_mode and _G.floating_mode.active == true then
		return "floating"
	end
	return "tiled"
end

-- On-device truth: run `hyprctl eval '_G.mosaic_debug()'` (or cat
-- /tmp/mosaic_debug.log) when the layout looks wrong and send me the output.
_G.mosaic_debug = function()
	local lines = {
		"real_layout=" .. tostring(real_layout_ok),
		"hl.layout=" .. tostring(hl.layout ~= nil),
		"last_err=" .. tostring(last_layout_err),
	}
	local ws = _G.mosaic_mode and _G.mosaic_mode.workspaces or {}
	local ids = {}
	for id, v in pairs(ws) do
		if v then
			table.insert(ids, tostring(id))
		end
	end
	table.sort(ids)
	table.insert(lines, "mosaic_workspaces={" .. table.concat(ids, ",") .. "}")
	local r = _G.mosaic_last_recalc or {}
	table.insert(lines, string.format("last_recalc: targets=%s w=%s h=%s portrait=%s time=%s",
		tostring(r.targets), tostring(r.w), tostring(r.h), tostring(r.portrait), tostring(r.time)))
	for _, p in ipairs(r.placements or {}) do
		table.insert(lines, string.format("  placed %s x=%s y=%s w=%s h=%s",
			tostring(p.class), tostring(p.x), tostring(p.y), tostring(p.w), tostring(p.h)))
	end
	local live = hl.get_active_workspace and hl.get_active_workspace()
	table.insert(lines, "active_workspace=" .. tostring(live and live.id))
	for k, order in pairs(layout_order or {}) do
		table.insert(lines, "order[" .. tostring(k) .. "]=" .. table.concat(order or {}, ","))
	end
	local s = table.concat(lines, "\n")
	local f = io.open("/tmp/mosaic_debug.log", "w")
	if f then
		f:write(s .. "\n")
		f:close()
	end
	return s
end

_G.mosaic_toggle = function(ws_id)
	M.toggle(ws_id)
end

_G.mosaic_apply = function(ws_id)
	M.apply_workspace(ws_id)
end

--------------------------------------------------------------------------------
-- Overflow spill (real-layout path): a mosaic workspace holds at most
-- MAX_MOSAIC_WINDOWS tiled windows. A window opening onto a crowded mosaic
-- workspace never paints there: pre-paint (open_early) moves it straight to
-- the hole and the viewport follows, so first paint reads as "opened there".
-- Occupied targets shift onward transitively to make space. System-reserved
-- workspaces (8 silent steam, 9 games, 10 pinned) are never landing pads and
-- their contents never shift. For keybind launches prefer M.exec(cmd):
-- switch-then-wait-then-spawn, so the client maps directly onto the hole and
-- the reactive path stays a fallback for external launchers (spotlight).
--------------------------------------------------------------------------------

local MAX_MOSAIC_WINDOWS = 6
local MAX_SPILL_SCAN = 20
-- Proactive spawn wait: viewport lands on the hole first, client maps after
-- the beat so the switch reads as intentional (reactive path needs no wait:
-- it moves pre-paint, before first paint).
local SPILL_SPAWN_WAIT = 250
local SPILL_BLOCKED = { [8] = true, [9] = true, [10] = true }

-- Stable window identity: object handles are unreliable across listings, so
-- compare normalized addresses (same pattern as floating-mode.lua).
local function spill_addr(w)
	if not w then
		return nil
	end
	local ok, raw = pcall(function()
		if not w.address then
			return nil
		end
		return tostring(w.address):lower()
	end)
	if not ok or not raw or raw == "" then
		return nil
	end
	if raw:find("^0x") then
		return raw
	end
	return "0x" .. raw
end

-- Tiled (layout-managed) windows on a workspace, optionally excluding one by
-- address. Exclusion makes the count exact whether or not the newcomer is in
-- the listing yet.
local function spill_tiled_on(ws_id, exclude_addr)
	local out = {}
	for _, w in ipairs(hl.get_workspace_windows(ws_id) or {}) do
		if not is_ignorable(w) and is_live_window(w) then
			if not (exclude_addr and spill_addr(w) == exclude_addr) then
				local ok, arch = pcall(db.classify, w)
				if ok and arch and not arch.float then
					table.insert(out, w)
				end
			end
		end
	end
	return out
end

local function spill_ws_empty(ws_id)
	for _, w in ipairs(hl.get_workspace_windows(ws_id) or {}) do
		if not is_ignorable(w) and is_live_window(w) then
			return false
		end
	end
	return true
end

local function spill_move_contents(from_id, to_id)
	for _, ow in ipairs(hl.get_workspace_windows(from_id) or {}) do
		pcall(function()
			if not is_ignorable(ow) and is_live_window(ow) then
				hl.dispatch(hl.dsp.window.move({ window = ow, workspace = tostring(to_id) }))
			end
		end)
	end
end

-- First empty, non-reserved workspace ahead + shift the chain back-to-front
-- so the returned hole is free. Reserved workspaces are never touched nor
-- landed on. Returns hole or nil. Shared by both spill paths.
local function spill_make_hole(num)
	local empty_at = nil
	for k = num + 1, num + MAX_SPILL_SCAN do
		if not SPILL_BLOCKED[k] and spill_ws_empty(k) then
			empty_at = k
			break
		end
	end
	if not empty_at then
		return nil
	end
	local hole = empty_at
	for k = empty_at - 1, num + 1, -1 do
		if not SPILL_BLOCKED[k] and not SPILL_BLOCKED[k + 1] then
			spill_move_contents(k, k + 1)
			hole = k
		end
	end
	return hole
end

-- At most one in-flight spill per window address: window.open_early and
-- window.open both fire for the same window, and whichever runs first owns
-- it. Entries expire (clock skew / dropped timers must never block a future
-- window reusing an address).
local spill_pending = {}

local function spill_claimed(addr)
	if not addr then
		return false
	end
	local t = spill_pending[addr]
	return t ~= nil and (os.clock() - t) < 5
end

local function spill_forget(addr)
	if addr then
		spill_pending[addr] = nil
	end
end

-- One staged flow, earliest available trigger. Pre-paint (open_early) moves
-- the newcomer to the hole BEFORE first paint and follows with the viewport,
-- so it never flashes on the crowded workspace. Synchronous: no delayed
-- second beat (that delay is what read as open-here-switch-move). pre_paint
-- skips the liveness check (unmapped is expected before first paint, not
-- death). Returns true when a flow started.
local function spill_begin(w, num, ws_id, newcomer_addr, pre_paint)
	if newcomer_addr and spill_claimed(newcomer_addr) then
		return false
	end
	if not pre_paint and not is_live_window(w) then
		return false
	end
	local cur = w.workspace and w.workspace.id
	if tonumber(cur) ~= num then
		return false -- already moved elsewhere
	end
	local okc, arch = pcall(db.classify, w)
	if not (okc and arch and not arch.float) then
		return false -- dialogs/floats never spill
	end
	-- Crowded? With a known address the count excludes the newcomer, so
	-- listing lag can't skew it. Without one, require strictly over max
	-- (a lagging listing then only delays, never false-spills).
	local crowded
	if newcomer_addr then
		crowded = #spill_tiled_on(num, newcomer_addr) >= MAX_MOSAIC_WINDOWS
	else
		crowded = #spill_tiled_on(num, nil) > MAX_MOSAIC_WINDOWS
	end
	if not crowded then
		return false -- room after all
	end
	local hole = spill_make_hole(num)
	if not hole then
		log(string.format(">>> SPILL: WS %d crowded but no empty workspace ahead; leaving window", num))
		return false
	end
	if newcomer_addr then
		spill_pending[newcomer_addr] = os.clock()
	end
	-- The hole continues the mosaic session, not dwindle: mark + point it
	-- at lua:mosaic before anything lands there.
	pcall(function()
		_G.mosaic_mode.workspaces[hole] = true
		write_state()
		set_ws_layout(hole, "lua:mosaic")
	end)
	-- Move pre-paint (never flashes on the crowded ws), then follow with
	-- the viewport when the user is still looking at the crowded ws. The
	-- pending claim is intentionally KEPT (expires in 5s): window.open fires
	-- right after open_early while the async move may not be visible in
	-- listings yet, and without the claim it would make a second hole.
	pcall(function()
		hl.dispatch(hl.dsp.window.move({ window = w, workspace = tostring(hole) }))
	end)
	local cur_ws = hl.get_active_workspace and hl.get_active_workspace()
	if cur_ws and tonumber(cur_ws.id) == num then
		pcall(function()
			hl.dispatch(hl.dsp.focus({ workspace = tostring(hole) }))
		end)
	end
	log(string.format(">>> SPILL: WS %d crowded, window opened on WS %d", num, hole))
	return true
end

-- Proactive launch: switch-then-wait-then-spawn. If the active mosaic
-- workspace is crowded, make the hole, go there, and only then spawn, so the
-- client maps directly onto the hole (no reactive move at all). Otherwise
-- spawn immediately. Keybinds (terminal etc.) should use this; external
-- launchers (spotlight) fall through to the reactive spill_begin above.
function M.exec(cmd)
	if not cmd or cmd == "" then
		return
	end
	local function spawn()
		pcall(function()
			hl.dispatch(hl.dsp.exec_cmd(cmd))
		end)
	end
	if not real_layout_ok then
		spawn()
		return
	end
	local aws = hl.get_active_workspace and hl.get_active_workspace()
	local num = aws and tonumber(aws.id)
	if not (aws and aws.id and num and num > 0 and M.is_active(aws.id)) then
		spawn()
		return
	end
	if #spill_tiled_on(num, nil) < MAX_MOSAIC_WINDOWS then
		spawn()
		return
	end
	local hole = spill_make_hole(num)
	if not hole then
		log(string.format(">>> SPILL-EXEC: WS %d crowded but no empty workspace ahead; spawning here", num))
		spawn()
		return
	end
	pcall(function()
		_G.mosaic_mode.workspaces[hole] = true
		write_state()
		set_ws_layout(hole, "lua:mosaic")
	end)
	pcall(function()
		hl.dispatch(hl.dsp.focus({ workspace = tostring(hole) }))
	end)
	log(string.format(">>> SPILL-EXEC: WS %d crowded, switched to WS %d, spawning in %dms", num, hole, SPILL_SPAWN_WAIT))
	hl.timer(spawn, { timeout = SPILL_SPAWN_WAIT, type = "oneshot" })
end

_G.mosaic_exec = function(cmd)
	M.exec(cmd)
end

-- Preferred trigger: pre-paint, so the switch precedes any flash on the
-- crowded workspace. Never guess the workspace here: rule-assigned opens
-- still in flight (steam -> 8) must not be spilled elsewhere. Address-less
-- windows defer to window.open (no dedupe possible pre-paint).
hl.on("window.open_early", function(w)
	if not real_layout_ok or not w then
		return
	end
	local ws_id = w.workspace and w.workspace.id
	if not ws_id then
		return
	end
	local num = tonumber(ws_id)
	if not (num and num > 0 and M.is_active(ws_id)) then
		return
	end
	local addr = spill_addr(w)
	if not addr then
		return
	end
	spill_begin(w, num, ws_id, addr, true)
end)

hl.on("window.open", function(w)
	if not real_layout_ok or not w then
		return
	end
	local ws_id = (w and w.workspace and w.workspace.id)
	if not ws_id then
		local aws = hl.get_active_workspace()
		ws_id = aws and aws.id
	end
	local num = tonumber(ws_id)
	if not (ws_id and num and num > 0 and M.is_active(ws_id)) then
		return
	end
	spill_begin(w, num, ws_id, spill_addr(w), false)
end)

-- Event Listeners
local debounce_timer = nil
local function schedule_recalculate(delay)
	if debounce_timer then
		return
	end
	debounce_timer = hl.timer(function()
		debounce_timer = nil
		local ws = hl.get_active_workspace()
		if ws and ws.id and M.is_active(ws.id) then
			M.apply_workspace(ws.id)
		end
	end, { timeout = delay or 40, type = "oneshot" })
end

hl.on("window.open_early", function(w)
	if real_layout_ok then return end
	if not w then return end
	local ws_id = w.workspace and w.workspace.id
	if not ws_id then
		local aws = hl.get_active_workspace()
		ws_id = aws and aws.id
	end
	if ws_id and M.is_active(ws_id) then
		pcall(function()
			hl.dispatch(hl.dsp.window.set_prop({
				window = w, prop = "no_anim", value = "1",
			}))
		end)
	end
end)

hl.on("window.open", function(w)
	if real_layout_ok then return end
	local ws_id = (w and w.workspace and w.workspace.id)
	if not ws_id then
		local aws = hl.get_active_workspace()
		ws_id = aws and aws.id
	end
	if ws_id and M.is_active(ws_id) then
		schedule_recalculate(30)
		hl.timer(function()
			if M.is_active(ws_id) then
				M.apply_workspace(ws_id)
			end
		end, { timeout = 150, type = "oneshot" })
	end
end)

hl.on("window.close", function(w)
	if real_layout_ok then return end
	local ws_id = (w and w.workspace and w.workspace.id)
	if not ws_id then
		local aws = hl.get_active_workspace()
		ws_id = aws and aws.id
	end
	if ws_id and M.is_active(ws_id) then
		-- Loose close: let the close animation finish, then only re-tile
		-- when back in a strict range. While still cascading, survivors keep
		-- their spots instead of reshuffling around the dying window.
		hl.timer(function()
			if not M.is_active(ws_id) then
				return
			end
			if in_cascade_zone(ws_id) then
				return
			end
			M.apply_workspace(ws_id)
		end, { timeout = 200, type = "oneshot" })
	end
end)

hl.on("window.move_to_workspace", function(w, ws)
	if real_layout_ok then return end
	local ws_id = (ws and ws.id) or (w and w.workspace and w.workspace.id)
	if ws_id and M.is_active(ws_id) then
		schedule_recalculate(40)
	end
end)

hl.on("workspace.active", function(ws)
	if real_layout_ok then return end
	if ws and ws.id and M.is_active(ws.id) then
		schedule_recalculate(40)
	end
end)

return M
