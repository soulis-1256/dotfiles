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

-- hyprctl reload does not unregister hl.on / hl.timer from the previous
-- load. Ignore callbacks that belong to an older copy of this file (same
-- pattern as floating-mode.lua). Without this, rapid saves stack N
-- generations of spill handlers that all fire per open and fight over the
-- newcomer (extra holes, double moves). mosaic_recalculate itself is NOT
-- guarded: whichever provider the compositor calls must place windows.
_G.mosaic_epoch = (_G.mosaic_epoch or 0) + 1
local EPOCH = _G.mosaic_epoch
local function from_this_load()
	return _G.mosaic_epoch == EPOCH
end

function M.is_active(ws_id)
	if _G.layout_manager and _G.layout_manager.get_mode then
		return _G.layout_manager.get_mode(ws_id) == "mosaic"
	end
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

-- Arrangement vs compositor list.
--
-- lua:mosaic cannot positional-reorder on drop. Hyprland's tiled drag
-- floats the window, then newTarget() re-appends it at the end of m_targets.
-- Keyboard movewindow DOES swap m_targets in place. So compositor order is
-- the truth for swaps/opens/closes, and a lie for mouse drops.
--
-- During drag (shrink): Hyprland owns the floating window. Survivors hold
-- their last mosaic cells — no N-1 recast, no solo-fill jump.
-- After drop (returner): cursor slot (dwindle addTarget rule), persist that
-- order, recast mosaic. Quiet recalculates keep the persisted order even
-- though Hyprland still has the window appended, so the drop does not yank
-- back. A real compositor reorder (keyboard swap) is incoming != last
-- compositor list and is adopted.
-- Opens still rank-insert (zen left of ghostty). State lives in _G so a
-- reload does not snap everyone back to archetype order.
_G.mosaic_layout_order = _G.mosaic_layout_order or {} -- ws_key -> visual id order
_G.mosaic_layout_compositor = _G.mosaic_layout_compositor or {} -- ws_key -> last incoming ids
_G.mosaic_layout_prev_present = _G.mosaic_layout_prev_present or {} -- ws_key -> {id -> true}
_G.mosaic_layout_last_seen = _G.mosaic_layout_last_seen or {} -- ws_key -> {id -> os.clock()}
_G.mosaic_last_cells = _G.mosaic_last_cells or {} -- ws_key -> last FULL mosaic cells
_G.mosaic_last_area = _G.mosaic_last_area or {} -- ws_key -> {x,y,w,h} of last place
_G.mosaic_user_cells = _G.mosaic_user_cells or {} -- ws_key -> user-resized cells
local layout_order = _G.mosaic_layout_order
local layout_compositor = _G.mosaic_layout_compositor
local layout_prev_present = _G.mosaic_layout_prev_present
local layout_last_seen = _G.mosaic_layout_last_seen
local layout_last_cells = _G.mosaic_last_cells
local layout_last_area = _G.mosaic_last_area
local layout_user_cells = _G.mosaic_user_cells
local LAYOUT_DRAG_GRACE = 2.0 -- s: floated-for-drag returns; closed never does

-- Shrink poke: drag and close both look like n-1 on the first recalculate.
-- Hold cells, then re-check. A still-floating missing window is a drag
-- (keep holding). A gone window is a close (recast mosaic). File-local is
-- fine: a reload just holds one more beat.
local shrink_seen = {} -- ws_key -> true after the first shrink frame
local poke_armed = {}
local SHRINK_POKE_MS = 400

local function settle_arm(key)
	if poke_armed[key] then
		return
	end
	poke_armed[key] = true
	hl.timer(function()
		poke_armed[key] = nil
		if not from_this_load() then
			return
		end
		-- layout("mosaic:settle") only hits the focused workspace. A window
		-- leaving an unfocused monitor would otherwise stay shrunk until
		-- you tab onto that workspace.
		if M.poke_visible then
			pcall(M.poke_visible)
		else
			local focused = hl.get_active_workspace and hl.get_active_workspace()
			local focused_id = focused and focused.id
			if focused_id and M.is_active(focused_id) then
				pcall(function()
					hl.dispatch(hl.dsp.layout("mosaic:settle"))
				end)
			end
		end
	end, { timeout = SHRINK_POKE_MS, type = "oneshot" })
end

-- One-line drop diagnostics: what the sorter saw on drag-relevant
-- transitions (returner/shrink). Read with `cat /tmp/mosaic_drop.log`
-- after reproducing one bad drag. Rare events only, no per-frame spam.
local DROP_LOG = "/tmp/mosaic_drop.log"
-- %d throws on fractional widths (splits are floats like 1286.4) — and a
-- throw here would fail the entire recalculate. Always format defensively.
local function fmt_n(v)
	local n = tonumber(v)
	if not n or n ~= n or n == math.huge or n == -math.huge then
		return "?"
	end
	return tostring(math.floor(n + 0.5))
end
local function trace_ids(ids, by_id)
	local parts = {}
	for _, id in ipairs(ids or {}) do
		local cls = "?"
		local e = by_id and by_id[id]
		if e and e.target then
			pcall(function()
				local w = e.target.window
				if w then
					cls = tostring(w.class or w.initial_class or "?")
				end
			end)
		end
		table.insert(parts, cls)
	end
	return table.concat(parts, ",")
end
local function trace_drop(line)
	pcall(function()
		local f = io.open(DROP_LOG, "a")
		if not f then
			return
		end
		if f:seek("end") > 200000 then
			f:close()
			f = io.open(DROP_LOG, "w")
			if not f then
				return
			end
		end
		f:write(os.date("[%H:%M:%S] ") .. line .. "\n")
		f:close()
	end)
end

local function window_layout_id(w)
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
end

local function layout_target_id(t, i)
	local ok, id = pcall(function()
		return window_layout_id(t.window)
	end)
	if ok and id then
		return id
	end
	return "i:" .. tostring(i)
end

local function ids_equal(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function ids_copy(src)
	local out = {}
	for _, id in ipairs(src or {}) do
		table.insert(out, id)
	end
	return out
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
	return 2
end

-- True when a missing id is still a mapped float on this workspace (drag).
-- false = gone (close) or already on another workspace (move).
-- nil = unknown (hold one beat).
local function missing_is_drag(key, missing_ids)
	if not missing_ids or #missing_ids == 0 then
		return false
	end
	local ws = tostring(key or ""):match("^ws:(.+)$")
	if not ws or ws == "__shared__" then
		return nil
	end
	local missing_set = {}
	for _, id in ipairs(missing_ids) do
		missing_set[id] = true
	end
	-- Move-away: the window already lives on a different workspace.
	local ok_all, all = pcall(function()
		return hl.get_windows()
	end)
	if ok_all and type(all) == "table" then
		for _, w in ipairs(all) do
			local id = nil
			pcall(function()
				id = window_layout_id(w)
			end)
			if id and missing_set[id] then
				local wws = nil
				pcall(function()
					wws = w.workspace and w.workspace.id
				end)
				if wws ~= nil and tostring(wws) ~= ws then
					return "move"
				end
			end
		end
	end
	local ok, wins = pcall(function()
		return hl.get_workspace_windows(tonumber(ws) or ws)
	end)
	if not ok or type(wins) ~= "table" then
		return nil
	end
	local floating = {}
	for _, w in ipairs(wins) do
		local is_f = false
		pcall(function()
			is_f = w.floating and true or false
		end)
		if is_f then
			local id = nil
			pcall(function()
				id = window_layout_id(w)
			end)
			if id then
				floating[id] = true
			end
		end
	end
	for _, id in ipairs(missing_ids) do
		if floating[id] then
			return true
		end
	end
	return false
end

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
			local at, sz = wobj.at, wobj.size
			if type(at) == "table" and type(sz) == "table" then
				local ax, ay = tonumber(at.x), tonumber(at.y)
				local sx, sy = tonumber(sz.x), tonumber(sz.y)
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

-- Live cursor position, nil-safe. Drop recalculate runs inside dragEnd, so
-- the cursor is still on the release cell (dwindle addTarget: window under
-- cursor, half decides before/after).
local function layout_cursor_pos()
	local ok, p = pcall(function()
		return hl.get_cursor_pos()
	end)
	if ok and type(p) == "table" then
		local x, y = tonumber(p.x), tonumber(p.y)
		if x and y then
			return x, y
		end
	end
	return nil, nil
end

local function area_contains(area, x, y)
	if type(area) ~= "table" or x == nil or y == nil then
		return false
	end
	local ax, ay = tonumber(area.x), tonumber(area.y)
	local aw = tonumber(area.w) or tonumber(area.width)
	local ah = tonumber(area.h) or tonumber(area.height)
	if not (ax and ay and aw and ah) then
		return false
	end
	return x >= ax and x < ax + aw and y >= ay and y < ay + ah
end

-- Dwindle-rule slot for one returner: cell under the cursor wins (containing
-- cell, else nearest center — mirrors getNodeFromWindow/windowAt, then
-- getClosestNode). Cursor on the left/top half of that cell inserts before
-- its occupant, else after. Returns nil when there are no usable cells.
local function cursor_slot_for(working, cells, cx, cy, stacked)
	local slot, found = nil, false
	for j, sid in ipairs(working) do
		local b = cells[sid]
		if b and cx >= b.x and cx < b.x + b.w and cy >= b.y and cy < b.y + b.h then
			if stacked then
				slot = (cy < b.y + b.h / 2) and j or (j + 1)
			else
				slot = (cx < b.x + b.w / 2) and j or (j + 1)
			end
			found = true
			break
		end
	end
	if not found then
		local best_j, best_d2 = nil, nil
		for j, sid in ipairs(working) do
			local b = cells[sid]
			if b then
				local dx, dy = cx - (b.x + b.w / 2), cy - (b.y + b.h / 2)
				local d2 = dx * dx + dy * dy
				if not best_d2 or d2 < best_d2 then
					best_j, best_d2 = j, d2
				end
			end
		end
		if best_j then
			local b = cells[working[best_j]]
			if stacked then
				slot = (cy < b.y + b.h / 2) and best_j or (best_j + 1)
			else
				slot = (cx < b.x + b.w / 2) and best_j or (best_j + 1)
			end
			found = true
		end
	end
	if found then
		slot = math.max(1, math.min(slot, #working + 1))
		return slot
	end
	return nil
end

-- Insert id into list at the first slot whose occupant ranks after it.
local function rank_insert_into(list, id, by_id)
	local r = archetype_rank(by_id[id] and by_id[id].archetype)
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

-- Place a returner by cursor (dwindle rule), else floating-box center, else
-- keep its pre-drag slot. Mutates `working` (survivor ids) in place.
local function place_returner(working, rid, by_id, cells, area, stacked)
	local ccx, ccy = layout_cursor_pos()
	if ccx ~= nil and area_contains(area, ccx, ccy) then
		local slot = cursor_slot_for(working, cells, ccx, ccy, stacked)
		if slot then
			table.insert(working, slot, rid)
			return "cursor", slot, ccx, ccy
		end
	end
	local rcx, rcy = layout_target_center(by_id[rid] and by_id[rid].target)
	if rcx ~= nil then
		local best, best_j, best_d2 = nil, nil, nil
		for j, sid in ipairs(working) do
			local scx, scy = layout_target_center(by_id[sid] and by_id[sid].target)
			if scx ~= nil then
				local dx, dy = rcx - scx, rcy - scy
				local d2 = dx * dx + dy * dy
				if not best_d2 or d2 < best_d2 then
					best, best_j, best_d2 = sid, j, d2
				end
			end
		end
		if best_j then
			local at = best_j
			local bcx, bcy = layout_target_center(by_id[best] and by_id[best].target)
			if bcx ~= nil then
				if stacked and rcy > bcy then
					at = at + 1
				elseif (not stacked) and rcx > bcx then
					at = at + 1
				end
			end
			table.insert(working, at, rid)
			return "center", at, rcx, rcy
		end
	end
	table.insert(working, rid)
	return "append", #working, nil, nil
end

-- Bucket order for layout targets (persistent, see above). Float archetypes
-- only appear here if the user manually untiled them, so they place as
-- neutral canvas. `stacked` selects the drop axis (y when portrait/narrow
-- rows, x otherwise) and must match mosaic_recalculate_inner's decision.
local function sort_layout_targets(targets, area, stacked)
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
	local now = os.clock()
	local prev = layout_order[key] or {}
	local prev_present = layout_prev_present[key] or {}
	local last_seen = layout_last_seen[key] or {}
	layout_last_seen[key] = last_seen
	local present = {}
	for _, id in ipairs(incoming_ids) do
		present[id] = true
		last_seen[id] = now
	end

	-- Full order with grace: keep missing ids that vanished recently (drag
	-- float-away). Older missing ids are closes: drop them for good.
	local pruned, pruned_set = {}, {}
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

	local newcomers, returners, returner_set = {}, {}, {}
	for _, id in ipairs(incoming_ids) do
		if not pruned_set[id] then
			table.insert(newcomers, id)
		elseif not prev_present[id] then
			table.insert(returners, id)
			returner_set[id] = true
		end
	end

	local missing = {}
	for _, id in ipairs(pruned) do
		if not present[id] then
			table.insert(missing, id)
		end
	end

	local kind, final_ids, stored_ids

	if #returners > 0 then
		kind = "returner"
		shrink_seen[key] = nil
		local working = {}
		for _, id in ipairs(pruned) do
			if present[id] and not returner_set[id] then
				table.insert(working, id)
			end
		end
		local cells = layout_last_cells[key] or {}
		local how, slot, cx, cy = "none", nil, nil, nil
		for _, rid in ipairs(returners) do
			how, slot, cx, cy = place_returner(working, rid, by_id, cells, area, stacked)
		end
		for _, id in ipairs(newcomers) do
			rank_insert_into(working, id, by_id)
		end
		final_ids = working
		stored_ids = ids_copy(final_ids)
		for _, id in ipairs(pruned) do
			if not present[id] then
				table.insert(stored_ids, id)
			end
		end
		trace_drop(string.format(
			"ws=%s decision=returner how=%s cursor=%s,%s slot=%s incoming=[%s] final=[%s]",
			tostring(key), tostring(how), fmt_n(cx), fmt_n(cy), tostring(slot),
			trace_ids(incoming_ids, by_id), trace_ids(final_ids, by_id)))
	elseif #newcomers > 0 then
		kind = "newcomer"
		shrink_seen[key] = nil
		local base = {}
		for _, id in ipairs(pruned) do
			if present[id] then
				table.insert(base, id)
			end
		end
		for _, id in ipairs(newcomers) do
			rank_insert_into(base, id, by_id)
		end
		final_ids = base
		stored_ids = ids_copy(final_ids)
		for _, id in ipairs(pruned) do
			if not present[id] then
				table.insert(stored_ids, id)
			end
		end
	elseif #missing > 0 then
		-- Shrink: drag float-away, close, or move to another monitor.
		-- A window already on another workspace is a move: recast immediately
		-- so the leftover window expands without a workspace-switch refresh.
		-- A still-floating window on THIS workspace is a drag: hold cells.
		-- Unknown/first-frame-gone still holds one beat (close vs drag race).
		local drag = missing_is_drag(key, missing)
		-- Move-away is certain (window already on another ws): recast now.
		-- A true close still holds one frame so a drag that isn't floating
		-- yet doesn't solo-fill then snap back.
		local treat_close = (drag == "move") or (drag == false and shrink_seen[key] == true)
		if treat_close then
			kind = "close"
			shrink_seen[key] = nil
			final_ids = {}
			for _, id in ipairs(pruned) do
				if present[id] then
					table.insert(final_ids, id)
				end
			end
			stored_ids = ids_copy(final_ids)
			trace_drop(string.format(
				"ws=%s decision=close incoming=[%s] final=[%s]",
				tostring(key), trace_ids(incoming_ids, by_id), trace_ids(final_ids, by_id)))
		else
			kind = "shrink"
			shrink_seen[key] = true
			settle_arm(key)
			final_ids = {}
			for _, id in ipairs(pruned) do
				if present[id] then
					table.insert(final_ids, id)
				end
			end
			stored_ids = ids_copy(pruned)
			trace_drop(string.format(
				"ws=%s decision=shrink drag=%s incoming=[%s] kept=[%s]",
				tostring(key), tostring(drag),
				trace_ids(incoming_ids, by_id), trace_ids(final_ids, by_id)))
		end
	else
		-- Same set. If Hyprland's list did not change, keep the persisted
		-- visual order (drop correction must survive later recalculates).
		-- If Hyprland's list DID change, that is a keyboard swap: adopt it.
		local last_comp = layout_compositor[key] or {}
		if #prev == 0 or not ids_equal(incoming_ids, last_comp) then
			kind = "same"
			shrink_seen[key] = nil
			final_ids = incoming_ids
			stored_ids = ids_copy(incoming_ids)
		else
			kind = "quiet"
			final_ids = {}
			for _, id in ipairs(prev) do
				if present[id] then
					table.insert(final_ids, id)
				end
			end
			if #final_ids == 0 then
				final_ids = incoming_ids
			end
			stored_ids = ids_copy(final_ids)
		end
	end

	if #stored_ids == 0 then
		layout_order[key] = nil
	else
		layout_order[key] = stored_ids
	end
	layout_compositor[key] = ids_copy(incoming_ids)
	layout_prev_present[key] = present

	local ordered = {}
	for _, id in ipairs(final_ids) do
		local e = by_id[id]
		if e then
			table.insert(ordered, { target = e.target, archetype = e.archetype, id = id })
		end
	end
	return ordered, kind, key
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

-- Sidebar width as a fraction of W. Prefer the archetype's own ratio/min/max
-- so Discord is not crushed to a 480px strip on a 1440p/ultrawide display.
local function layout_sidebar_frac(W, ratio, min_w, max_w)
	ratio = ratio or 0.38
	min_w = min_w or 640
	max_w = max_w or 1200
	if not W or W <= 0 then
		return ratio
	end
	return clamp(W * ratio, min_w, max_w) / W
end

local function sidebar_frac_for(arch, W)
	if not arch then
		return layout_sidebar_frac(W, 0.38, 640, 1200)
	end
	return layout_sidebar_frac(W, arch.target_ratio or 0.38, arch.min_w or 640, arch.max_w or 1200)
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
-- Last placed boxes per run, keyed by layout id (for drop-cell lookup on the
-- next recalculate). active_idmap maps target userdata -> layout id.
local active_boxes = nil
local active_idmap = nil

local function safe_place(target, box)
	local ok, err = pcall(function()
		target:place(box)
	end)
	if not ok then
		log_layout_err("place failed: " .. tostring(err))
		return
	end
	if active_boxes and active_idmap then
		local id = active_idmap[target]
		if id then
			active_boxes[id] = { x = box.x, y = box.y, w = box.w, h = box.h }
		end
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

-- Interactive resize. Hyprland's lua:layout resizeTarget ignores the delta
-- and just recalculates, so Super+RMB / border-drag would snap back without
-- this: we move the nearest internal split to the cursor and persist cells.
local RESIZE_EDGE = 16
local RESIZE_MIN = 280
_G.mosaic_resize_state = _G.mosaic_resize_state or nil

local function copy_cells(cells)
	local out = {}
	for id, b in pairs(cells or {}) do
		out[id] = { x = b.x, y = b.y, w = b.w, h = b.h }
	end
	return out
end

local function cells_complete(cells, ordered)
	if type(cells) ~= "table" or not ordered or #ordered == 0 then
		return false
	end
	for _, e in ipairs(ordered) do
		local b = e and e.id and cells[e.id]
		if not (b and tonumber(b.w) and tonumber(b.h)) then
			return false
		end
	end
	return true
end

local function area_same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	local function n(v)
		return tonumber(v) or 0
	end
	return math.abs(n(a.x) - n(b.x)) < 2
		and math.abs(n(a.y) - n(b.y)) < 2
		and math.abs(n(a.w) - n(b.w)) < 2
		and math.abs(n(a.h) - n(b.h)) < 2
end

local function collect_splits(cells, ordered)
	local v, h = {}, {}
	local function add(map, pos, side, id)
		pos = math.floor((tonumber(pos) or 0) + 0.5)
		local s = map[pos]
		if not s then
			s = { pos = pos, lo = {}, hi = {} }
			map[pos] = s
		end
		table.insert(s[side], id)
	end
	for _, e in ipairs(ordered) do
		local b = cells[e.id]
		if b then
			add(v, b.x, "hi", e.id)
			add(v, b.x + b.w, "lo", e.id)
			add(h, b.y, "hi", e.id)
			add(h, b.y + b.h, "lo", e.id)
		end
	end
	local splits = {}
	for _, pack in ipairs({ { axis = "x", m = v }, { axis = "y", m = h } }) do
		for _, s in pairs(pack.m) do
			if #s.lo > 0 and #s.hi > 0 then
				table.insert(splits, { axis = pack.axis, pos = s.pos, lo = s.lo, hi = s.hi })
			end
		end
	end
	return splits
end

local function apply_split(cells, split, new_pos, area)
	local min = RESIZE_MIN
	if split.axis == "x" then
		local lo = (area and area.x or 0) + min
		local hi = (area and area.x or 0) + (area and area.w or 0) - min
		new_pos = clamp(new_pos, lo, hi)
		for _, id in ipairs(split.lo) do
			local b = cells[id]
			if b then
				b.w = math.max(min, new_pos - b.x)
			end
		end
		for _, id in ipairs(split.hi) do
			local b = cells[id]
			if b then
				local r = b.x + b.w
				b.x = new_pos
				b.w = math.max(min, r - new_pos)
			end
		end
	else
		local lo = (area and area.y or 0) + min
		local hi = (area and area.y or 0) + (area and area.h or 0) - min
		new_pos = clamp(new_pos, lo, hi)
		for _, id in ipairs(split.lo) do
			local b = cells[id]
			if b then
				b.h = math.max(min, new_pos - b.y)
			end
		end
		for _, id in ipairs(split.hi) do
			local b = cells[id]
			if b then
				local r = b.y + b.h
				b.y = new_pos
				b.h = math.max(min, r - new_pos)
			end
		end
	end
end

local function nearest_split(splits, cx, cy, maxd)
	local best, bestd = nil, maxd
	for _, s in ipairs(splits) do
		local d = (s.axis == "x") and math.abs(cx - s.pos) or math.abs(cy - s.pos)
		if d <= bestd then
			best, bestd = s, d
		end
	end
	return best
end

local function split_from_state(splits, st)
	if not st or not st.axis or not st.lo or not st.hi then
		return nil
	end
	local function same(a, b)
		if #a ~= #b then
			return false
		end
		local set = {}
		for _, id in ipairs(b) do
			set[id] = true
		end
		for _, id in ipairs(a) do
			if not set[id] then
				return false
			end
		end
		return true
	end
	for _, s in ipairs(splits) do
		if s.axis == st.axis and same(s.lo, st.lo) and same(s.hi, st.hi) then
			return s
		end
	end
	return nil
end

local function maybe_resize_cells(cells, ordered, area)
	local cx, cy = layout_cursor_pos()
	if cx == nil or type(area) ~= "table" then
		return false
	end
	local splits = collect_splits(cells, ordered)
	if #splits == 0 then
		return false
	end
	local st = _G.mosaic_resize_state
	local split = split_from_state(splits, st)
	if not split then
		split = nearest_split(splits, cx, cy, (st and 1e9) or RESIZE_EDGE)
	end
	if not split then
		return false
	end
	local new_pos
	if st then
		st.axis, st.lo, st.hi = split.axis, split.lo, split.hi
		if st.orig_pos == nil then
			st.orig_pos = split.pos
			st.ox, st.oy = cx, cy
		end
		if split.axis == "x" then
			new_pos = st.orig_pos + (cx - (st.ox or cx))
		else
			new_pos = st.orig_pos + (cy - (st.oy or cy))
		end
	else
		new_pos = (split.axis == "x") and cx or cy
	end
	apply_split(cells, split, new_pos, area)
	return true
end

local function place_cells(ordered, cells)
	for _, e in ipairs(ordered) do
		local b = cells[e.id]
		if b then
			safe_place(e.target, { x = b.x, y = b.y, w = b.w, h = b.h })
		end
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

	local ordered, decision, wskey = sort_layout_targets(targets, area, stacked)
	local n = #ordered
	if n == 0 then
		return
	end

	-- Snapshot for _G.mosaic_debug(): what the layout last saw. If targets
	-- is 0 while windows are visibly there, the workspace rule isn't active
	-- (or everything is floating) — that is the first thing to check.
	active_placements = {}
	active_boxes = {}
	active_idmap = {}
	for _, e in ipairs(ordered) do
		if e.target ~= nil and e.id ~= nil then
			active_idmap[e.target] = e.id
		end
	end
	_G.mosaic_last_recalc = {
		targets = #targets,
		w = W,
		h = H,
		portrait = portrait and true or false,
		decision = decision,
		time = os.date("%H:%M:%S"),
	}
	_G.mosaic_last_decision = decision

	-- Transient shrink (drag mid-flight): survivors hold their last mosaic
	-- cells. Hyprland owns the floating dragged window. Recast happens on
	-- drop (returner) or once a close is confirmed.
	if decision == "shrink" then
		local cells = (wskey and layout_last_cells[wskey]) or {}
		if cells_complete(cells, ordered) then
			place_cells(ordered, cells)
			return
		end
		-- no usable cells: fall through to a fresh solve of the survivors
	end

	-- N = 1: solo fill. Gaps/borders come from the compositor config and the
	-- existing tiled smart-gaps workspace rules (no scripted hacks needed).
	if n == 1 then
		if wskey then
			layout_user_cells[wskey] = nil
		end
		safe_place(ordered[1].target, area)
		return
	end

	-- Quiet: same window set, compositor order unchanged. Keep last/user
	-- cells so Super+RMB and border-drag persist, and apply live split
	-- follow while a resize is in progress (or the cursor is on a split).
	if decision == "quiet" and wskey then
		local prev = layout_user_cells[wskey] or layout_last_cells[wskey]
		if cells_complete(prev, ordered) and area_same(layout_last_area[wskey], area) then
			local cells = copy_cells(prev)
			local resized = maybe_resize_cells(cells, ordered, area)
			place_cells(ordered, cells)
			if resized or _G.mosaic_resize_state then
				layout_user_cells[wskey] = cells
			end
			return
		end
	end

	-- Any recast (open/close/swap/returner) drops user resize.
	if wskey and decision ~= "quiet" and decision ~= "shrink" then
		layout_user_cells[wskey] = nil
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
			f = sidebar_frac_for(a1, W)
		elseif a2.name == "sidebar" and a1.name ~= "sidebar" then
			f = 1 - sidebar_frac_for(a2, W)
		end
		-- Usability floor: never squeeze a window under ~400px side by
		-- side (a terminal there can't render a line of code). Stack full
		-- width instead. Only bites on narrow landscape areas; portrait
		-- is stacked long before this (see above).
		if W and W > 0 and math.min(W * f, W * (1 - f)) < 400 then
			local rows = layout_rows(ctx, area, 2)
			safe_place(ordered[1].target, rows[1])
			safe_place(ordered[2].target, rows[2])
			return
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
			local side_arch = (a1.name == "sidebar" and a1) or (a2.name == "sidebar" and a2) or a3
			local fs = sidebar_frac_for(side_arch, W)
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
			local fs = sidebar_frac_for(ordered[1].archetype, W)
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
	-- Persist this run's cells for the next drop lookup. Skip shrink: that
	-- placement is a hold of the previous mosaic, and overwriting would
	-- drop the dragged window's old cell.
	if ok and active_boxes and _G.mosaic_last_decision ~= "shrink" then
		local kok, k = pcall(layout_ws_key, (ctx and ctx.targets) or {})
		if kok and k and k ~= "ws:__shared__" then
			layout_last_cells[k] = active_boxes
			local area = ctx and ctx.area
			if type(area) == "table" then
				layout_last_area[k] = {
					x = area.x, y = area.y,
					w = area.w or area.width,
					h = area.h or area.height,
				}
			end
		end
	end
	active_placements = nil
	active_boxes = nil
	active_idmap = nil
end

-- Settle poke target: `hl.dispatch(hl.dsp.layout("mosaic:settle"))` re-runs
-- recalculate (the compositor calls recalculate() after layout_msg).
local function mosaic_layout_msg(ctx, msg)
	return true
end

local function register_mosaic_layout()
	if not (hl.layout and hl.layout.register) then
		if _G.mosaic_layout_registered then
			log("lua:mosaic provider already serving (hl.layout unavailable this load) — keeping real backend")
			return true
		end
		log("lua:mosaic unavailable (hl.layout.register missing) — legacy floating engine active")
		return false
	end
	local ok, err = pcall(hl.layout.register, "mosaic", { recalculate = mosaic_recalculate, layout_msg = mosaic_layout_msg })
	if not ok then
		if tostring(err):match("already registered") and _G.mosaic_layout_registered then
			log("lua:mosaic already registered — keeping existing provider")
			return true
		end
		log("lua:mosaic registration failed: " .. tostring(err) .. " — legacy floating engine active")
		return false
	end
	_G.mosaic_layout_registered = true
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
M.set_ws_layout = set_ws_layout

-- Recast every visible mosaic workspace. Needed when a window leaves an
-- unfocused monitor: Hyprland may not recalculate that workspace, and
-- layout("mosaic:settle") only hits the focused one.
function M.poke_visible()
	if not real_layout_ok then
		return
	end
	local seen = {}
	for _, m in ipairs(hl.get_monitors() or {}) do
		local id = m.active_workspace and m.active_workspace.id
		if id and not seen[id] and M.is_active(id) then
			seen[id] = true
			set_ws_layout(id, "lua:mosaic")
		end
	end
	local focused = hl.get_active_workspace and hl.get_active_workspace()
	local focused_id = focused and focused.id
	if focused_id and M.is_active(focused_id) then
		pcall(function()
			hl.dispatch(hl.dsp.layout("mosaic:settle"))
		end)
	end
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
M.migrate_legacy_floats = migrate_legacy_floats

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
			local w_side = clamp(math.floor(wa.w * (a1.target_ratio or 0.38)), a1.min_w or 640, a1.max_w or 1200)
			local w_other = wa.w - gap - w_side
			table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = w_side, h = wa.h } })
			table.insert(results, { win = w2, rect = { x = wa.x + w_side + gap, y = wa.y, w = w_other, h = wa.h } })
			return results
		elseif a2.name == "sidebar" and a1.name ~= "sidebar" then
			local w_side = clamp(math.floor(wa.w * (a2.target_ratio or 0.38)), a2.min_w or 640, a2.max_w or 1200)
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

		-- Usability floor (mirrors the real-layout path): under ~400px a
		-- side-by-side window is unusable — stack full width instead.
		if math.min(width1, width2) < 400 then
			local rows = stack_rows(wa, gap, 2)
			table.insert(results, { win = w1, rect = rows[1] })
			table.insert(results, { win = w2, rect = rows[2] })
			return results
		end

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
			local side_arch = (a1.name == "sidebar" and a1) or (a2.name == "sidebar" and a2) or a3
			local ws_side = clamp(math.floor(wa.w * (side_arch.target_ratio or 0.38)), side_arch.min_w or 640, side_arch.max_w or 1200)
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
		-- Portrait / very narrow: full-width rows like every other count.
		-- A 2x2 grid here would be two unusable ~500px strips side by side
		-- (same reason the real-layout path stacks all portrait counts).
		if is_portrait(wa) or too_narrow_for_columns(wa) then
			local rows = stack_rows(wa, gap, 4)
			for i = 1, 4 do
				table.insert(results, { win = items[i].win, rect = rows[i] })
			end
			return results
		end
		-- Landscape-only from here (portrait returned above as full rows).
		-- The 3-column sidebar layout would be unusably narrow on portrait.
		local has_sidebar = (it1.archetype.name == "sidebar")

		if has_sidebar then
			-- Sidebar Left | Center Main | Right 2-Stack
			local side_arch = it1.archetype
			local w_side = clamp(math.floor(wa.w * (side_arch.target_ratio or 0.38)), side_arch.min_w or 640, side_arch.max_w or 1200)
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
	-- full-width rows on portrait or very narrow (mirrors the real-layout
	-- path: columns there would be unusable strips side by side).
	if is_portrait(wa) or too_narrow_for_columns(wa) then
		local rows = stack_rows(wa, gap, n)
		for i = 1, n do
			table.insert(results, { win = items[i].win, rect = rows[i] })
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

-- Test hook (no compositor use): lets the headless harness drive the legacy
-- geometric solver directly.
M.solve_for_test = solve_mosaic

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
		if not from_this_load() then
			return
		end
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
	table.insert(lines, string.format("last_recalc: targets=%s w=%s h=%s portrait=%s decision=%s time=%s",
		tostring(r.targets), tostring(r.w), tostring(r.h), tostring(r.portrait),
		tostring(r.decision), tostring(r.time)))
	for _, p in ipairs(r.placements or {}) do
		table.insert(lines, string.format("  placed %s x=%s y=%s w=%s h=%s",
			tostring(p.class), tostring(p.x), tostring(p.y), tostring(p.w), tostring(p.h)))
	end
	local live = hl.get_active_workspace and hl.get_active_workspace()
	table.insert(lines, "active_workspace=" .. tostring(live and live.id))
	for k, order in pairs(layout_order or {}) do
		local short = {}
		for _, id in ipairs(order or {}) do
			table.insert(short, tostring(id):sub(-12))
		end
		table.insert(lines, "order[" .. tostring(k) .. "]=" .. table.concat(short, ","))
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

_G.mosaic_is_active_here = function()
	local ws = hl.get_active_workspace and hl.get_active_workspace()
	return ws and ws.id and M.is_active(ws.id) or false
end

function M.resize_begin()
	local ws = hl.get_active_workspace and hl.get_active_workspace()
	if not (ws and ws.id and M.is_active(ws.id) and real_layout_ok) then
		pcall(function()
			hl.dispatch(hl.dsp.window.resize())
		end)
		return
	end
	local c = nil
	pcall(function()
		c = hl.get_cursor_pos()
	end)
	_G.mosaic_resize_state = {
		t = os.clock(),
		x = c and c.x,
		y = c and c.y,
	}
	local function tick()
		if not from_this_load() or not _G.mosaic_resize_state then
			return
		end
		pcall(function()
			hl.dispatch(hl.dsp.layout("mosaic:settle"))
		end)
		hl.timer(tick, { timeout = 16, type = "oneshot" })
	end
	hl.timer(tick, { timeout = 16, type = "oneshot" })
end

function M.resize_end()
	_G.mosaic_resize_state = nil
end

_G.mosaic_resize_begin = function()
	M.resize_begin()
end

_G.mosaic_resize_end = function()
	M.resize_end()
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
local SPILL_BLOCKED = { [8] = true, [9] = true }
local DP1_MIN = 1
local DP1_MAX = 7
local DP2_MIN = 10
local DP2_MAX = 19

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
	pcall(function()
		if _G.layout_manager and _G.layout_manager.set_mode then
			_G.layout_manager.set_mode(to_id, "mosaic")
		else
			_G.mosaic_mode.workspaces[to_id] = true
			write_state()
			set_ws_layout(to_id, "lua:mosaic")
		end
	end)
	for _, ow in ipairs(hl.get_workspace_windows(from_id) or {}) do
		pcall(function()
			if not is_ignorable(ow) and is_live_window(ow) then
				hl.dispatch(hl.dsp.window.move({ window = ow, workspace = tostring(to_id) }))
			end
		end)
	end
end

-- Monitor-aware hole finder:
-- On DP-1 (1..7): scans ahead up to 7, wraps around 1..num-1, or falls back to DP-2 (10..19).
-- On DP-2 (10..19): scans ahead up to 19, wraps around 10..num-1, or falls back to DP-1 (1..7).
-- Shifts the chain forward when empty_at is ahead on the same monitor.
local function spill_make_hole(num)
	if not num or num < 1 then
		return nil
	end

	local function find_empty(start_ws, end_ws)
		if start_ws > end_ws then
			return nil
		end
		for k = start_ws, end_ws do
			if not SPILL_BLOCKED[k] and spill_ws_empty(k) then
				return k
			end
		end
		return nil
	end

	local is_dp2 = (num >= DP2_MIN and num <= DP2_MAX)
	local is_dp1 = (num >= DP1_MIN and num <= DP1_MAX)
	local empty_at = nil

	if is_dp2 then
		-- DP-2: primary search ahead on DP-2
		empty_at = find_empty(num + 1, DP2_MAX)
		-- Wrap around on DP-2 if not found ahead
		if not empty_at and num > DP2_MIN then
			empty_at = find_empty(DP2_MIN, num - 1)
		end
		-- Fallback to DP-1 if DP-2 is completely full
		if not empty_at then
			empty_at = find_empty(DP1_MIN, DP1_MAX)
		end
	elseif is_dp1 then
		-- DP-1: primary search ahead on DP-1 (1..7, skipping 8/9)
		empty_at = find_empty(num + 1, DP1_MAX)
		-- Wrap around on DP-1 if not found ahead
		if not empty_at and num > DP1_MIN then
			empty_at = find_empty(DP1_MIN, num - 1)
		end
		-- Fallback to DP-2 if DP-1 is completely full
		if not empty_at then
			empty_at = find_empty(DP2_MIN, DP2_MAX)
		end
	else
		-- Generic workspace: search ahead up to MAX_SPILL_SCAN
		empty_at = find_empty(num + 1, num + MAX_SPILL_SCAN)
	end

	if not empty_at then
		return nil
	end

	-- If empty_at is ahead of num on the same monitor, shift chain forward so hole is num + 1
	local same_monitor = (is_dp2 and (empty_at >= DP2_MIN and empty_at <= DP2_MAX))
		or (is_dp1 and (empty_at >= DP1_MIN and empty_at <= DP1_MAX))

	if same_monitor and empty_at > num then
		local hole = empty_at
		for k = empty_at - 1, num + 1, -1 do
			if not SPILL_BLOCKED[k] and not SPILL_BLOCKED[k + 1] then
				spill_move_contents(k, k + 1)
				hole = k
			end
		end
		return hole
	end

	-- Wrap-around or cross-monitor fallback: empty_at is already empty, use it directly as hole
	return empty_at
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
		if _G.layout_manager and _G.layout_manager.set_mode then
			_G.layout_manager.set_mode(hole, "mosaic")
		else
			_G.mosaic_mode.workspaces[hole] = true
			write_state()
			set_ws_layout(hole, "lua:mosaic")
		end
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
		if _G.layout_manager and _G.layout_manager.set_mode then
			_G.layout_manager.set_mode(hole, "mosaic")
		else
			_G.mosaic_mode.workspaces[hole] = true
			write_state()
			set_ws_layout(hole, "lua:mosaic")
		end
	end)
	pcall(function()
		hl.dispatch(hl.dsp.focus({ workspace = tostring(hole) }))
	end)
	log(string.format(">>> SPILL-EXEC: WS %d crowded, switched to WS %d, spawning in %dms", num, hole, SPILL_SPAWN_WAIT))
	hl.timer(function()
		if not from_this_load() then
			return
		end
		spawn()
	end, { timeout = SPILL_SPAWN_WAIT, type = "oneshot" })
end

_G.mosaic_exec = function(cmd)
	M.exec(cmd)
end

-- Preferred trigger: pre-paint, so the switch precedes any flash on the
-- crowded workspace. Never guess the workspace here: rule-assigned opens
-- still in flight (steam -> 8) must not be spilled elsewhere. Address-less
-- windows defer to window.open (no dedupe possible pre-paint).
hl.on("window.open_early", function(w)
	if not from_this_load() then
		return
	end
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
	if not from_this_load() then
		return
	end
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

--------------------------------------------------------------------------------
-- Boot self-heal: workspace rules set at config load don't always stick
-- (the workspace may not exist yet), so a mosaic workspace can show as
-- active while dwindle actually tiles it — until a manual toggle re-points
-- the rule. Re-assert the rule whenever a workspace becomes active and once
-- at compositor start. Idempotent: same rule rewritten in place.
--------------------------------------------------------------------------------

local function ensure_mosaic_rule(ws_id)
	if not real_layout_ok or not ws_id then
		return
	end
	if not M.is_active(ws_id) then
		return
	end
	set_ws_layout(tonumber(ws_id) or ws_id, "lua:mosaic")
end

hl.on("hyprland.start", function()
	if not from_this_load() then
		return
	end
	for id, v in pairs(_G.mosaic_mode.workspaces or {}) do
		if v then
			ensure_mosaic_rule(id)
		end
	end
end)

hl.on("workspace.active", function(ws)
	if not from_this_load() then
		return
	end
	if not real_layout_ok then
		return
	end
	local id = ws and ws.id
	if id then
		ensure_mosaic_rule(id)
	end
end)



-- Event Listeners
local debounce_timer = nil
local function schedule_recalculate(delay)
	if debounce_timer then
		return
	end
	debounce_timer = hl.timer(function()
		debounce_timer = nil
		if not from_this_load() then
			return
		end
		local ws = hl.get_active_workspace()
		if ws and ws.id and M.is_active(ws.id) then
			M.apply_workspace(ws.id)
		end
	end, { timeout = delay or 40, type = "oneshot" })
end

hl.on("window.open_early", function(w)
	if not from_this_load() then
		return
	end
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
	if not from_this_load() then
		return
	end
	if real_layout_ok then return end
	local ws_id = (w and w.workspace and w.workspace.id)
	if not ws_id then
		local aws = hl.get_active_workspace()
		ws_id = aws and aws.id
	end
	if ws_id and M.is_active(ws_id) then
		schedule_recalculate(30)
		hl.timer(function()
			if not from_this_load() then
				return
			end
			if M.is_active(ws_id) then
				M.apply_workspace(ws_id)
			end
		end, { timeout = 150, type = "oneshot" })
	end
end)

hl.on("window.close", function(w)
	if not from_this_load() then
		return
	end
	if real_layout_ok then
		hl.timer(function()
			if from_this_load() then
				M.poke_visible()
			end
		end, { timeout = 80, type = "oneshot" })
		return
	end
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
			if not from_this_load() then
				return
			end
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
	if not from_this_load() then
		return
	end
	if real_layout_ok then
		hl.timer(function()
			if from_this_load() then
				M.poke_visible()
			end
		end, { timeout = 40, type = "oneshot" })
		return
	end
	local ws_id = (ws and ws.id) or (w and w.workspace and w.workspace.id)
	if ws_id and M.is_active(ws_id) then
		schedule_recalculate(40)
	end
end)

hl.on("workspace.active", function(ws)
	if not from_this_load() then
		return
	end
	if real_layout_ok then return end
	if ws and ws.id and M.is_active(ws.id) then
		schedule_recalculate(40)
	end
end)

return M
