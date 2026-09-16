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
	if ws_id and state.workspaces and state.workspaces[ws_id] ~= nil then
		return state.workspaces[ws_id] == true
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
	}
end

-- Sorting windows: sidebars to edges, primary editors in focus/center
local function sort_mosaic_windows(windows)
	local sidebars, editors, terminals, canvases = {}, {}, {}, {}

	for _, w in ipairs(windows) do
		local arch = db.classify(w)
		w._archetype = arch
		if arch.name == "sidebar" then
			table.insert(sidebars, w)
		elseif arch.name == "editor" then
			table.insert(editors, w)
		elseif arch.name == "terminal" then
			table.insert(terminals, w)
		else
			table.insert(canvases, w)
		end
	end

	-- Order: Sidebars on the left, Editors in the center, Terminals/Canvases on the right
	local ordered = {}
	for _, w in ipairs(sidebars) do table.insert(ordered, w) end
	for _, w in ipairs(editors) do table.insert(ordered, w) end
	for _, w in ipairs(canvases) do table.insert(ordered, w) end
	for _, w in ipairs(terminals) do table.insert(ordered, w) end

	return ordered
end

-- The Mosaic Geometric Solver
-- Returns array of { win = w, rect = { x, y, w, h } }
local function solve_mosaic(windows, wa)
	local n = #windows
	local results = {}
	if n == 0 then
		return results
	end

	local gap = wa.gap or 8

	-- Case N = 1: Comfortable focal sizing (The Anti-Stretch Rule)
	if n == 1 then
		local w = windows[1]
		local arch = w._archetype or db.classify(w)
		local target_w, target_h

		if arch.name == "sidebar" then
			target_w = clamp(math.floor(wa.w * 0.32), 400, 560)
			target_h = wa.h
		elseif arch.name == "terminal" then
			target_w = clamp(math.floor(wa.w * 0.65), 720, 1200)
			target_h = clamp(math.floor(wa.h * 0.85), 520, 850)
		elseif arch.name == "editor" or arch.name == "canvas" then
			-- Golden reading focus size: 76% width, 90% height
			target_w = math.floor(wa.w * 0.78)
			target_h = math.floor(wa.h * 0.92)
		else
			target_w = math.floor(wa.w * 0.75)
			target_h = math.floor(wa.h * 0.85)
		end

		local x = wa.x + math.floor((wa.w - target_w) / 2)
		local y = wa.y + math.floor((wa.h - target_h) / 2)
		table.insert(results, { win = w, rect = { x = x, y = y, w = target_w, h = target_h } })
		return results
	end

	-- Case N = 2: Intelligent Asymmetric or Symmetric Duo
	if n == 2 then
		local w1, w2 = windows[1], windows[2]
		local a1, a2 = w1._archetype, w2._archetype

		local w1_ratio = 0.50
		if a1.name == "sidebar" and a2.name ~= "sidebar" then
			w1_ratio = 0.28
		elseif a2.name == "sidebar" and a1.name ~= "sidebar" then
			w1_ratio = 0.72
		elseif a1.name == "editor" and a2.name == "terminal" then
			w1_ratio = 0.62
		elseif a2.name == "editor" and a1.name == "terminal" then
			w1_ratio = 0.38
		end

		local width1 = math.floor((wa.w - gap) * w1_ratio)
		local width2 = wa.w - gap - width1

		table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = width1, h = wa.h } })
		table.insert(results, { win = w2, rect = { x = wa.x + width1 + gap, y = wa.y, w = width2, h = wa.h } })
		return results
	end

	-- Case N = 3: Trio (3 Columns or Master + 2-Stack T-Layout)
	if n == 3 then
		local w1, w2, w3 = windows[1], windows[2], windows[3]
		local has_sidebar = (w1._archetype.name == "sidebar" or w2._archetype.name == "sidebar" or w3._archetype.name == "sidebar")

		if has_sidebar then
			-- 3-Column Layout: Sidebar (24%), Center Main (52%), Right Secondary (24%)
			local ws_side = clamp(math.floor(wa.w * 0.24), 360, 480)
			local ws_sec = clamp(math.floor(wa.w * 0.26), 400, 540)
			local ws_main = wa.w - (2 * gap) - ws_side - ws_sec

			table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = ws_side, h = wa.h } })
			table.insert(results, { win = w2, rect = { x = wa.x + ws_side + gap, y = wa.y, w = ws_main, h = wa.h } })
			table.insert(results, { win = w3, rect = { x = wa.x + ws_side + ws_main + (2 * gap), y = wa.y, w = ws_sec, h = wa.h } })
			return results
		else
			-- Master + 2 Stack: Left takes 60% full height, Right splits top/bottom
			local w_left = math.floor((wa.w - gap) * 0.60)
			local w_right = wa.w - gap - w_left
			local h_half = math.floor((wa.h - gap) * 0.50)
			local h_rem = wa.h - gap - h_half

			table.insert(results, { win = w1, rect = { x = wa.x, y = wa.y, w = w_left, h = wa.h } })
			table.insert(results, { win = w2, rect = { x = wa.x + w_left + gap, y = wa.y, w = w_right, h = h_half } })
			table.insert(results, { win = w3, rect = { x = wa.x + w_left + gap, y = wa.y + h_half + gap, w = w_right, h = h_rem } })
			return results
		end
	end

	-- Case N = 4: Power Grid (Sidebar + Main + 2-Stack OR 2x2 Grid)
	if n == 4 then
		local w1, w2, w3, w4 = windows[1], windows[2], windows[3], windows[4]
		local has_sidebar = (w1._archetype.name == "sidebar")

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

	-- Case N >= 5: Adaptive Multi-Column Masonry
	-- Left takes primary 45%, middle takes 30% split in 2, right takes 25% split in 2
	local w_left = math.floor((wa.w - (2 * gap)) * 0.44)
	local w_mid = math.floor((wa.w - (2 * gap)) * 0.30)
	local w_right = wa.w - (2 * gap) - w_left - w_mid
	local h_half = math.floor((wa.h - gap) * 0.50)
	local h_rem = wa.h - gap - h_half

	table.insert(results, { win = windows[1], rect = { x = wa.x, y = wa.y, w = w_left, h = wa.h } })
	table.insert(results, { win = windows[2], rect = { x = wa.x + w_left + gap, y = wa.y, w = w_mid, h = h_half } })
	table.insert(results, { win = windows[3], rect = { x = wa.x + w_left + gap, y = wa.y + h_half + gap, w = w_mid, h = h_rem } })
	table.insert(results, { win = windows[4], rect = { x = wa.x + w_left + w_mid + (2 * gap), y = wa.y, w = w_right, h = h_half } })
	table.insert(results, { win = windows[5], rect = { x = wa.x + w_left + w_mid + (2 * gap), y = wa.y + h_half + gap, w = w_right, h = h_rem } })

	return results
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

	local mon = (hl.get_monitor_at_cursor and hl.get_monitor_at_cursor())
		or (hl.get_monitors() and hl.get_monitors()[1])
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

	for _, item in ipairs(layout) do
		local w = item.win
		local rect = item.rect
		local th = titlebar_h(w)

		pcall(function()
			-- Float if tiled
			if not w.floating then
				hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
			end
			-- Unset maximize/fullscreen if active
			if w.fullscreen and w.fullscreen ~= 0 then
				hl.dispatch(hl.dsp.window.fullscreen({ window = w, action = "unset" }))
			end
			-- Apply geometry
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
		end)
	end
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
	end, { timeout = delay or 80, type = "oneshot" })
end

hl.on("window.open", function(w)
	local ws_id = w and w.workspace and w.workspace.id
	if ws_id and M.is_active(ws_id) then
		schedule_recalculate(100)
	end
end)

hl.on("window.close", function(w)
	local ws_id = w and w.workspace and w.workspace.id
	if ws_id and M.is_active(ws_id) then
		schedule_recalculate(50)
	end
end)

hl.on("window.move_to_workspace", function(w, ws)
	local ws_id = (ws and ws.id) or (w and w.workspace and w.workspace.id)
	if ws_id and M.is_active(ws_id) then
		schedule_recalculate(80)
	end
end)

hl.on("workspace.active", function(ws)
	if ws and ws.id and M.is_active(ws.id) then
		schedule_recalculate(60)
	end
end)

return M
