-- Helpers for drag-to-top maximize and alt-tab restack.
-- Snap (snap.lua, SnapTopBar) owns the gesture. This file does not
-- float every window or install a custom tiling layout.
--
-- A named rule from the old floating mode survives hyprctl reload and
-- swallows client maximize. Redeclare it (named rules merge) and disable it.

pcall(function()
	local rule = _G.floating_mode_suppress_maximize_rule
	if not rule then
		rule = hl.window_rule({
			name = "tiled-mode-no-maximize",
			match = { class = ".*" },
			suppress_event = "maximize",
		})
	end
	if rule and rule.set_enabled then
		rule:set_enabled(false)
	end
	_G.floating_mode_suppress_maximize_rule = rule
end)

-- Workspace rules from lua:mosaic also survive reload. Named dwindle
-- rules are the last word for the workspaces this session already has.
pcall(hl.config, { general = { layout = "dwindle" } })

local function force_dwindle(id)
	if id == nil then
		return
	end
	pcall(hl.workspace_rule, {
		workspace = tostring(id),
		layout = "dwindle",
	})
end

for i = 1, 10 do
	force_dwindle(i)
end
pcall(function()
	for _, ws in ipairs(hl.get_workspaces() or {}) do
		force_dwindle(ws.id)
	end
end)

local TITLEBAR_H = 30
local MAX_SLOP = 8
local CACHE_PATH = (os.getenv("HOME") or "") .. "/.cache/hypr_app_float_state.json"

_G.app_float_state = _G.app_float_state or {}

local function is_special_overlay(w)
	if not w then
		return false
	end
	local title = (w.title or w.initial_title or w.initialTitle or ""):lower()
	local cls = (w.class or w.initial_class or w.initialClass or ""):lower()
	if title:match("picture[%- ]in[%- ]picture") then
		return true
	end
	if cls:match("^steam") and title:match("^notificationtoasts") then
		return true
	end
	return false
end

local function is_transient_float(w)
	if not w then
		return false
	end
	if is_special_overlay(w) then
		return true
	end
	local pinned = false
	pcall(function()
		pinned = w.pinned and true or false
	end)
	if pinned then
		return true
	end
	local parent = nil
	pcall(function()
		if type(w.parent) == "function" then
			parent = w.parent()
		else
			parent = w.parent
		end
	end)
	if parent and parent ~= w then
		return true
	end
	return false
end
_G.window_is_transient_float = is_transient_float

-- CSD apps maximize via xdg. Hyprbar windows and transients use geometry
-- so a child cannot unmax its parent.
local function uses_xdg_maximize(w)
	if not w or is_transient_float(w) then
		return false
	end
	if _G.window_has_hyprbar then
		return not _G.window_has_hyprbar(w)
	end
	return false
end
_G.window_uses_xdg_maximize = uses_xdg_maximize

local function resolve_window_monitor(w)
	if not w then
		return (hl.get_monitors() and hl.get_monitors()[1])
	end
	if type(w.monitor) == "table" and w.monitor.width then
		return w.monitor
	end
	if w.monitor ~= nil then
		for _, m in ipairs(hl.get_monitors() or {}) do
			if m.id == w.monitor or m.name == tostring(w.monitor) then
				return m
			end
		end
	end
	local ws_id = w.workspace and w.workspace.id
	if ws_id then
		for _, m in ipairs(hl.get_monitors() or {}) do
			local m_ws = m.active_workspace or m.activeWorkspace
			if m_ws and m_ws.id == ws_id then
				return m
			end
		end
	end
	return (hl.get_monitor_at_cursor and hl.get_monitor_at_cursor())
		or (hl.get_monitors() and hl.get_monitors()[1])
end
_G.resolve_window_monitor = resolve_window_monitor

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
	}
end

local function titlebar_h(w)
	if _G.window_has_hyprbar and _G.window_has_hyprbar(w) then
		return TITLEBAR_H
	end
	return 0
end

local function geometry_is_maximized(w)
	if not w or not w.floating or not w.size or not w.at then
		return false
	end
	local mon = resolve_window_monitor(w)
	if not mon then
		return false
	end
	local wa = get_monitor_work_area(mon)
	local th = titlebar_h(w)
	return math.abs((w.size.x or 0) - wa.w) <= MAX_SLOP
		and math.abs((w.size.y or 0) - (wa.h - th)) <= MAX_SLOP
		and math.abs((w.at.x or 0) - wa.x) <= MAX_SLOP
		and math.abs((w.at.y or 0) - (wa.y + th)) <= MAX_SLOP
end

local function is_window_maximized(w)
	if not w then
		return false
	end
	if w.fullscreen == 1 or w.fullscreen == 3 then
		return true
	end
	return geometry_is_maximized(w)
end
_G.window_is_float_maximized = is_window_maximized

local function window_addr(w)
	if not w or not w.address then
		return nil
	end
	local raw = tostring(w.address):lower()
	if raw == "" then
		return nil
	end
	if raw:find("^0x") then
		return raw
	end
	return "0x" .. raw
end

local function get_app_key(w)
	if not w then
		return nil
	end
	local cls = w.class or ""
	if cls ~= "" then
		return cls:lower()
	end
	local icls = w.initial_class or w.initialClass or ""
	if icls ~= "" then
		return icls:lower()
	end
	local title = w.title or ""
	if title ~= "" then
		return title:lower()
	end
	return nil
end

local function load_float_state()
	local f = io.open(CACHE_PATH, "r")
	if not f then
		return
	end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then
		return
	end
	for app, val in content:gmatch('"([^"]+)"%s*:%s*{[^}]*"maximized"%s*:%s*([%a]+)') do
		if val == "true" or val == "false" then
			_G.app_float_state[app] = { maximized = (val == "true") }
		end
	end
end

local function save_float_state()
	local entries = {}
	for k, v in pairs(_G.app_float_state or {}) do
		if v and v.maximized ~= nil then
			table.insert(entries, string.format('  %q: {"maximized": %s}', k, v.maximized and "true" or "false"))
		end
	end
	table.sort(entries)
	local f = io.open(CACHE_PATH, "w")
	if f then
		f:write("{\n" .. table.concat(entries, ",\n") .. "\n}\n")
		f:close()
	end
end

load_float_state()

-- Snap records the bit. Nothing here floats a window or restores it on map.
_G.set_app_float_maximized = function(w, maximized, _reason)
	if not w or is_transient_float(w) then
		return
	end
	local app_key = get_app_key(w)
	if not app_key or app_key == "" then
		return
	end
	_G.app_float_state[app_key] = { maximized = maximized and true or false }
	save_float_state()
end

local overlay_geom = {}

local function overlay_drop_compositor_fs(w)
	if not w then
		return
	end
	pcall(function()
		hl.dispatch(hl.dsp.window.fullscreen_state({
			window = w, internal = 0, client = 0,
			action = "set", layout_aware = false,
		}))
	end)
end

_G.overlay_clear_fullscreen = overlay_drop_compositor_fs
_G.overlay_restore_geom = function(w)
	local addr = window_addr(w)
	return addr and overlay_geom[addr] or nil
end
_G.overlay_set_geometry_maxed = function(w, on)
	local addr = window_addr(w)
	if not addr or on then
		return
	end
	overlay_geom[addr] = nil
end

-- Focus does not restack. An xdg-maximized client ignores bring_to_top,
-- so other floats on that workspace are lowered first.
_G.win11_raise_window = function(w, _opts)
	if not w then
		return
	end
	local addr = window_addr(w)
	pcall(function()
		hl.dispatch(hl.dsp.focus({ window = w }))
	end)
	local fs, maxed, ws_id = 0, false, nil
	pcall(function()
		fs = w.fullscreen or 0
		maxed = is_window_maximized(w)
		ws_id = w.workspace and w.workspace.id
	end)
	if fs == 1 or fs == 3 or maxed then
		for _, o in ipairs(hl.get_windows() or {}) do
			pcall(function()
				if o.floating and not o.pinned and o.workspace and o.workspace.id == ws_id
					and window_addr(o) ~= addr then
					hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = o }))
				end
			end)
		end
		if fs == 1 or fs == 3 then
			pcall(function()
				hl.dispatch(hl.dsp.window.fullscreen({
					window = w, mode = "maximized", action = "set",
				}))
			end)
		end
	end
	pcall(function()
		hl.dispatch(hl.dsp.window.bring_to_top({ window = w }))
		hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
	end)
end
