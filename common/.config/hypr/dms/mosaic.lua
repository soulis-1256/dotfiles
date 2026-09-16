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
		M.apply_workspace(id)
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
		M.apply_workspace(id)
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
		for _, w in ipairs(hl.get_workspace_windows(id) or {}) do
			pcall(function()
				if not is_ignorable(w) and w.floating then
					hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
				end
			end)
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

_G.mosaic_toggle = function(ws_id)
	M.toggle(ws_id)
end

_G.mosaic_apply = function(ws_id)
	M.apply_workspace(ws_id)
end

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
	local ws_id = (ws and ws.id) or (w and w.workspace and w.workspace.id)
	if ws_id and M.is_active(ws_id) then
		schedule_recalculate(40)
	end
end)

hl.on("workspace.active", function(ws)
	if ws and ws.id and M.is_active(ws.id) then
		schedule_recalculate(40)
	end
end)

return M
