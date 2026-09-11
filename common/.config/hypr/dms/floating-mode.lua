-- Global Floating Mode for Hyprland
-- Remembers last floating size and position per application (Windows 11 behavior)
-- and cleanly floats/tiles windows according to active workspace/global state.

local M = {}

local LOG_FILE = "/tmp/floating_mode.log"
local function log(msg)
	local f = io.open(LOG_FILE, "a")
	if f then
		f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
		f:close()
	end
end

M.log = log

_G.floating_mode = _G.floating_mode or {
	active = false,
	workspaces = {},
}
_G.floating_mode.workspaces = _G.floating_mode.workspaces or {}

-- Restore mode from runtime indicator if present
local rf = io.open("/tmp/hypr_floating_mode", "r")
if rf then
	local content = rf:read("*a") or ""
	rf:close()
	if content:match("^1") then
		_G.floating_mode.active = true
	end
end

log("floating-mode loaded. Current active = " .. tostring(_G.floating_mode.active))

--------------------------------------------------------------------------------
-- App Geometry Persistence (Windows 11-style size & position memory)
--------------------------------------------------------------------------------

local CACHE_PATH = (os.getenv("HOME") or "") .. "/.cache/hypr_app_geometry.json"
_G.app_geometry_cache = _G.app_geometry_cache or {}
local cache_dirty = false
local known_windows = {}

local function is_special_overlay(w)
	if not w then return false end
	local title = (w.title or ""):lower()
	local cls = (w.class or ""):lower()
	if title:match("picture[%- ]in[%- ]picture") then return true end
	if cls:match("^steam") and title:match("^notificationtoasts") then return true end
	return false
end

local function get_app_key(w)
	if not w then return nil end
	local cls = w.class or ""
	if cls ~= "" then
		return cls:lower()
	end
	local icls = w.initialClass or w.initial_class or ""
	if icls ~= "" then
		return icls:lower()
	end
	local title = w.title or ""
	if title ~= "" then
		return title:lower()
	end
	return nil
end

local function load_geometry_cache()
	local f = io.open(CACHE_PATH, "r")
	if not f then return end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then return end
	for app, w, h, x, y, mon in content:gmatch('"([^"]+)":%s*{[^}]*"w":%s*(%-?%d+)[^}]*"h":%s*(%-?%d+)[^}]*"x":%s*(%-?%d+)[^}]*"y":%s*(%-?%d+)[^}]*"mon":%s*"([^"]*)"[^}]*}') do
		_G.app_geometry_cache[app] = {
			w = tonumber(w),
			h = tonumber(h),
			x = tonumber(x),
			y = tonumber(y),
			mon = mon,
		}
	end
end

local function save_geometry_cache()
	if not _G.app_geometry_cache then return end
	local entries = {}
	for k, v in pairs(_G.app_geometry_cache) do
		if v and v.w and v.h and v.x and v.y and v.w > 100 and v.h > 100 then
			table.insert(entries, string.format(
				'  %q: {"w": %d, "h": %d, "x": %d, "y": %d, "mon": %q}',
				k, math.floor(v.w), math.floor(v.h), math.floor(v.x), math.floor(v.y), tostring(v.mon or "")
			))
		end
	end
	local str = "{\n" .. table.concat(entries, ",\n") .. "\n}\n"
	local f = io.open(CACHE_PATH, "w")
	if f then
		f:write(str)
		f:close()
		cache_dirty = false
	end
end

-- Initialize persistent cache
load_geometry_cache()

-- Initial scan of currently active windows
hl.timer(function()
	record_all_windows()
end, { timeout = 200, type = "oneshot" })

local function get_monitor_work_area(mon)
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

	return {
		x = mon.x + res_left,
		y = mon.y + res_top,
		w = logical_w - res_left - res_right,
		h = logical_h - res_top - res_bottom,
		screen_w = logical_w,
		screen_h = logical_h,
		res_top = res_top,
		res_bottom = res_bottom,
		res_left = res_left,
		res_right = res_right,
	}
end

local function record_window_geometry(w)
	if not w or not w.floating or w.pinned or is_special_overlay(w) then
		return
	end
	if w.fullscreen and w.fullscreen ~= 0 then
		return
	end

	local app_key = get_app_key(w)
	if not app_key or app_key == "" then
		return
	end

	local raw_addr = (w.address or ""):lower()
	local full_addr = raw_addr:find("^0x") and raw_addr or ("0x" .. raw_addr)
	local clean_addr = raw_addr:gsub("^0x", "")

	local w_val = w.size and w.size.x
	local h_val = w.size and w.size.y
	local x_val = w.at and w.at.x
	local y_val = w.at and w.at.y

	-- If the window is currently snapped or maximized by Win11 Snap, record its restored floating bounds
	if _G.win11_snap_cache and (_G.win11_snap_cache[full_addr] or _G.win11_snap_cache[clean_addr]) then
		local s = _G.win11_snap_cache[full_addr] or _G.win11_snap_cache[clean_addr]
		if s and s.w and s.h and s.x and s.y then
			w_val, h_val, x_val, y_val = s.w, s.h, s.x, s.y
		end
	end

	if not w_val or not h_val or w_val < 150 or h_val < 150 then
		return
	end

	local mon = w.monitor or (hl.get_monitors() and hl.get_monitors()[1])
	local mon_name = mon and mon.name or ""

	local prev = _G.app_geometry_cache[app_key]
	if not prev or prev.w ~= w_val or prev.h ~= h_val or prev.x ~= x_val or prev.y ~= y_val or prev.mon ~= mon_name then
		_G.app_geometry_cache[app_key] = {
			w = w_val,
			h = h_val,
			x = x_val,
			y = y_val,
			mon = mon_name,
		}
		cache_dirty = true
	end

	known_windows[full_addr] = {
		app_key = app_key,
		w = w_val,
		h = h_val,
		x = x_val,
		y = y_val,
		mon = mon_name,
	}
end

local function record_all_windows()
	local windows = hl.get_windows() or {}
	for _, w in ipairs(windows) do
		record_window_geometry(w)
	end
	if cache_dirty then
		save_geometry_cache()
	end
end

function M.restore_geometry(w)
	if not w or is_special_overlay(w) then
		return
	end
	local app_key = get_app_key(w)
	if not app_key or app_key == "" then
		return
	end

	local mon = w.monitor or (hl.get_monitor_at_cursor and hl.get_monitor_at_cursor()) or (hl.get_monitors() and hl.get_monitors()[1])
	if not mon then
		return
	end
	local wa = get_monitor_work_area(mon)

	local saved = _G.app_geometry_cache and _G.app_geometry_cache[app_key]
	local target_w, target_h, target_x, target_y

	if saved and saved.w and saved.h and saved.w > 100 and saved.h > 100 then
		target_w = math.min(saved.w, wa.w - 16)
		target_h = math.min(saved.h, wa.h - 16)

		-- If saved position is within work area on the same monitor
		if saved.mon == mon.name and saved.x and saved.y
		   and saved.x >= (wa.x - 100) and saved.x <= (wa.x + wa.w - 100)
		   and saved.y >= (wa.y - 100) and saved.y <= (wa.y + wa.h - 100) then
			target_x = math.max(wa.x + 8, math.min(saved.x, wa.x + wa.w - target_w - 8))
			target_y = math.max(wa.y + 8, math.min(saved.y, wa.y + wa.h - target_h - 8))
		else
			-- Center on current monitor
			target_x = wa.x + math.floor((wa.w - target_w) / 2)
			target_y = wa.y + math.floor((wa.h - target_h) / 2)
		end
	else
		-- First time seeing this app in floating mode: proportional Windows 11 defaults
		if app_key:find("ghostty") or app_key:find("terminal") then
			target_w = math.min(960, math.floor(wa.w * 0.55))
			target_h = math.min(640, math.floor(wa.h * 0.55))
		else
			target_w = math.min(1280, math.floor(wa.w * 0.65))
			target_h = math.min(820, math.floor(wa.h * 0.70))
		end
		target_x = wa.x + math.floor((wa.w - target_w) / 2)
		target_y = wa.y + math.floor((wa.h - target_h) / 2)
	end

	target_w = math.floor(target_w)
	target_h = math.floor(target_h)
	target_x = math.floor(target_x)
	target_y = math.floor(target_y)

	local raw_addr = (w.address or ""):lower()
	local full_addr = raw_addr:find("^0x") and raw_addr or ("0x" .. raw_addr)

	hl.dispatch(hl.dsp.focus({ window = "address:" .. full_addr }))
	hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h }))
	hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y }))

	_G.app_geometry_cache[app_key] = {
		w = target_w,
		h = target_h,
		x = target_x,
		y = target_y,
		mon = mon.name,
	}
	cache_dirty = true
end

--------------------------------------------------------------------------------
-- Floating / Tiling Mode Toggle & State Management
--------------------------------------------------------------------------------

function M.toggle()
	local state = _G.floating_mode
	state.active = not state.active
	state.workspaces = {}

	log("==================================================================")
	log(">>> TOGGLE ACTIVATED: Mode is now " .. (state.active and "FLOATING" or "TILED"))

	local windows = hl.get_windows() or {}
	local count = 0

	for _, w in ipairs(windows) do
		if not is_special_overlay(w) then
			pcall(function()
				if state.active then
					-- Floating mode: Float and restore saved geometry
					hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
					M.restore_geometry(w)
				else
					-- Tiled mode: Record current floating geometry, then tile
					record_window_geometry(w)
					hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
				end
			end)
			count = count + 1
		end
	end

	log(string.format("Dispatched float=%s to %d windows", tostring(state.active), count))

	local f = io.open("/tmp/hypr_floating_mode", "w")
	if f then
		f:write(state.active and "1\n" or "0\n")
		f:close()
	end
end

function M.toggle_workspace(ws_id)
	local state = _G.floating_mode
	state.workspaces = state.workspaces or {}

	local ws = ws_id and { id = ws_id } or hl.get_active_workspace()
	if not ws or not ws.id then
		return
	end
	local id = ws.id

	local is_floating = false
	if state.workspaces[id] ~= nil then
		is_floating = state.workspaces[id]
	else
		local windows = hl.get_workspace_windows(id) or {}
		local non_special_count = 0
		local float_count = 0
		for _, w in ipairs(windows) do
			if not is_special_overlay(w) then
				non_special_count = non_special_count + 1
				if w.floating then
					float_count = float_count + 1
				end
			end
		end
		if non_special_count > 0 and float_count == non_special_count then
			is_floating = true
		else
			is_floating = false
		end
	end

	local target_floating = not is_floating
	state.workspaces[id] = target_floating

	log(string.format(">>> WORKSPACE TOGGLE: WS %s is now %s", tostring(id), target_floating and "FLOATING" or "TILED"))

	local windows = hl.get_workspace_windows(id) or {}
	local count = 0
	for _, w in ipairs(windows) do
		if not is_special_overlay(w) then
			pcall(function()
				if target_floating then
					hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
					M.restore_geometry(w)
				else
					record_window_geometry(w)
					hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
				end
			end)
			count = count + 1
		end
	end

	log(string.format("Dispatched float=%s to %d windows on workspace %s", tostring(target_floating), count, tostring(id)))
end

function M.is_active(ws_id)
	local state = _G.floating_mode
	if not state then
		return false
	end
	if ws_id and state.workspaces and state.workspaces[ws_id] ~= nil then
		return state.workspaces[ws_id] == true
	end
	return state.active == true
end

_G.floating_mode_toggle = function()
	M.toggle()
end

_G.workspace_floating_toggle = function(ws_id)
	M.toggle_workspace(ws_id)
end

--------------------------------------------------------------------------------
-- Window Event Handlers (open, close, active)
--------------------------------------------------------------------------------

local handled_windows = {}

local function handle_new_window(w)
	if not w then return end
	local title = (w.title or ""):lower()
	if title:match("picture[%- ]in[%- ]picture") then
		if not w.pinned then
			pcall(function()
				hl.dispatch(hl.dsp.window.pin({ window = w }))
			end)
		end
		return
	end

	local ws_id = w.workspace and w.workspace.id
	if not M.is_active(ws_id) then
		return
	end

	local addr = w.address
	if not addr or handled_windows[addr] or is_special_overlay(w) then
		return
	end
	handled_windows[addr] = true

	local raw_addr = addr:lower()
	local full_addr = raw_addr:find("^0x") and raw_addr or ("0x" .. raw_addr)

	local function apply_floating_and_geometry()
		local win = hl.get_window("address:" .. full_addr) or w
		if not win.floating then
			pcall(function()
				hl.dispatch(hl.dsp.window.float({ window = win, action = "set" }))
			end)
		end
		M.restore_geometry(win)
	end

	-- Dispatch immediately on map
	apply_floating_and_geometry()

	-- Secondary check at 80ms to ensure post-map geometry is settled
	hl.timer(function()
		local win = hl.get_window("address:" .. full_addr) or w
		if win then
			apply_floating_and_geometry()
		end
	end, { timeout = 80, type = "oneshot" })
end

hl.on("window.open", handle_new_window)

hl.on("window.close", function(w)
	if w and w.address then
		local raw_addr = w.address:lower()
		local full_addr = raw_addr:find("^0x") and raw_addr or ("0x" .. raw_addr)
		handled_windows[w.address] = nil
		handled_windows[full_addr] = nil

		if known_windows[full_addr] then
			local k = known_windows[full_addr]
			if k.app_key and k.w and k.h and k.x and k.y then
				_G.app_geometry_cache = _G.app_geometry_cache or {}
				_G.app_geometry_cache[k.app_key] = {
					w = k.w,
					h = k.h,
					x = k.x,
					y = k.y,
					mon = k.mon or "",
				}
				save_geometry_cache()
			end
			known_windows[full_addr] = nil
		end
	end
end)

-- Keep pinned windows (Picture-in-Picture) on top and track active window geometry
local last_raise = 0
hl.on("window.active", function(active_win)
	local ws_id = active_win and active_win.workspace and active_win.workspace.id
	if M.is_active(ws_id) and active_win then
		record_window_geometry(active_win)
	end

	local now = os.clock()
	if now - last_raise < 0.05 then
		return
	end
	last_raise = now
	for _, w in ipairs(hl.get_windows() or {}) do
		if w.pinned and w.floating and (not active_win or w.address ~= active_win.address) then
			pcall(function()
				hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
			end)
		end
	end
end)

-- Periodic geometry tracker (1s timer) to continuously record window moves and resizes
hl.timer(function()
	record_all_windows()
end, { timeout = 1000, type = "repeat" })

return M
