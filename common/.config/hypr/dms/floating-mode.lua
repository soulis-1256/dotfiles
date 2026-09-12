-- Global Floating Mode for Hyprland
-- Every window is floated in floating mode. Restore is binary:
--   maximized (last drag-to-top / hyprbar maximize) or a fixed centered size.

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

local MODE_CACHE_PATH = (os.getenv("HOME") or "") .. "/.cache/hypr_floating_mode"
local MODE_TMP_PATH = "/tmp/hypr_floating_mode"

local function read_mode_indicator()
	local f = io.open(MODE_CACHE_PATH, "r") or io.open(MODE_TMP_PATH, "r")
	if f then
		local content = f:read("*a") or ""
		f:close()
		return content:match("^1") ~= nil
	end
	return false
end

if read_mode_indicator() then
	_G.floating_mode.active = true
end

log("floating-mode loaded. Current active = " .. tostring(_G.floating_mode.active))

-- hyprctl reload does not unregister hl.on / hl.timer from the previous
-- load. Ignore callbacks that belong to an older copy of this file.
_G.floating_mode_epoch = (_G.floating_mode_epoch or 0) + 1
local EPOCH = _G.floating_mode_epoch
local function from_this_load()
	return _G.floating_mode_epoch == EPOCH
end

local WS_STATE_CACHE_PATH = (os.getenv("HOME") or "") .. "/.cache/hypr_floating_workspaces.json"
local WS_STATE_TMP_PATH = "/tmp/hypr_floating_workspaces.json"

local function write_mode_indicator(active)
	local val = active and "1\n" or "0\n"
	local f1 = io.open(MODE_CACHE_PATH, "w")
	if f1 then
		f1:write(val)
		f1:close()
	end
	local f2 = io.open(MODE_TMP_PATH, "w")
	if f2 then
		f2:write(val)
		f2:close()
	end

	local state = _G.floating_mode
	local parts = {}
	if state and state.workspaces then
		for id, v in pairs(state.workspaces) do
			table.insert(parts, string.format("%q: %s", tostring(id), v and "true" or "false"))
		end
		table.sort(parts)
	end
	local json = string.format('{"active": %s, "workspaces": {%s}}\n',
		(active or (state and state.active)) and "true" or "false",
		table.concat(parts, ", "))
	local j1 = io.open(WS_STATE_CACHE_PATH, "w")
	if j1 then
		j1:write(json)
		j1:close()
	end
	local j2 = io.open(WS_STATE_TMP_PATH, "w")
	if j2 then
		j2:write(json)
		j2:close()
	end
end

write_mode_indicator(_G.floating_mode.active)

--------------------------------------------------------------------------------
-- Maximized-state persistence
--
-- Hyprland does not persist "was this window maximized?" across close.
-- `persistent_size` is session-only, size-only, and matches class+title.
-- Live windows expose `fullscreen` (0/1/2/3) and current `size`/`at`, but
-- Windows-style maximize (drag to top / hyprbar) is custom geometry, not
-- xdg/Hyprland maximize. See README.
--------------------------------------------------------------------------------

local CACHE_PATH = (os.getenv("HOME") or "") .. "/.cache/hypr_app_float_state.json"
local DEFAULT_FLOAT_W = 1280
local DEFAULT_FLOAT_H = 800
local DEFAULT_MARGIN = 24
local TITLEBAR_H = 30
local MAX_SLOP = 8

_G.app_float_state = _G.app_float_state or {}
local cache_dirty = false
local known_windows = {}
local pending_restore = {}
local apply_gen = 0
local record_suppress = 0

local SKIP_GEOMETRY_CLASS = {
	["com.danklinux.dms"] = true,
	["org.gnome.loupe"] = true,
}

local function is_special_overlay(w)
	if not w then return false end
	local title = (w.title or ""):lower()
	local cls = (w.class or ""):lower()
	if title:match("picture[%- ]in[%- ]picture") then return true end
	if cls:match("^steam") and title:match("^notificationtoasts") then return true end
	return false
end

-- PiP / toasts / transients share an app_id with the parent. xdg-maximize
-- on the child makes Firefox/Zen unmax the parent, and CSD restore then
-- slams both to the 1280x800 default. These windows are geometry-only.
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

local function is_ignorable_window(w)
	if not w or is_special_overlay(w) then return true end
	local title = (w.title or ""):lower()
	if title:match("updater") or title:match("splash") or title:match("^notification") then
		return true
	end
	-- Splash/updater sized windows only. Do not treat a normal small app
	-- (or a just-unmaxed 1280x800 float) as ignorable.
	if w.size then
		local sx = w.size.x or 0
		local sy = w.size.y or 0
		if sx > 0 and sy > 0 and sx < 400 and sy < 300 then
			return true
		end
	end
	return false
end

local function skip_geometry(w)
	if not w or is_special_overlay(w) or is_ignorable_window(w) then
		return true
	end
	local cls = (w.class or ""):lower()
	if SKIP_GEOMETRY_CLASS[cls] then
		return true
	end
	return false
end

local function get_app_key(w)
	if not w then return nil end
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

local function window_addr(w)
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

local function addr_variants(addr)
	if not addr or addr == "" then
		return {}
	end
	local clean = addr:gsub("^0x", "")
	return { addr, clean, "0x" .. clean }
end

local function load_float_state()
	local f = io.open(CACHE_PATH, "r")
	if not f then return end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then return end
	for app, val in content:gmatch('"([^"]+)"%s*:%s*{[^}]*"maximized"%s*:%s*([%a]+)') do
		if val == "true" or val == "false" then
			_G.app_float_state[app] = { maximized = (val == "true") }
		end
	end
end

local function save_float_state()
	if not _G.app_float_state then return end
	local entries = {}
	for k, v in pairs(_G.app_float_state) do
		if v and v.maximized ~= nil then
			table.insert(entries, string.format(
				'  %q: {"maximized": %s}',
				k, v.maximized and "true" or "false"
			))
		end
	end
	table.sort(entries)
	local str = "{\n" .. table.concat(entries, ",\n") .. "\n}\n"
	local f = io.open(CACHE_PATH, "w")
	if f then
		f:write(str)
		f:close()
		cache_dirty = false
	end
end

load_float_state()

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

local function default_float_size(wa)
	local w = math.min(DEFAULT_FLOAT_W, math.max(400, wa.w - DEFAULT_MARGIN * 2))
	local h = math.min(DEFAULT_FLOAT_H, math.max(300, wa.h - DEFAULT_MARGIN * 2))
	return math.floor(w), math.floor(h)
end

local function max_geometry(w, wa)
	local has_bar = true
	if _G.window_has_hyprbar then
		has_bar = _G.window_has_hyprbar(w)
	end
	local title_h = has_bar and TITLEBAR_H or 0
	return {
		x = wa.x,
		y = wa.y + title_h,
		w = wa.w,
		h = wa.h - title_h,
	}
end

local function has_xdg_maximize(w)
	return w and (w.fullscreen == 1 or w.fullscreen == 3)
end

local function is_real_fullscreen(w)
	return w and w.fullscreen == 2
end

-- CSD apps (Zen, Discord, Chrome) maximize via xdg; hyprbar apps and
-- transients (PiP, pinned popouts) use geometry so the parent is untouched.
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
		if tostring(ws_id) == "10" then
			for _, m in ipairs(hl.get_monitors() or {}) do
				if m.name == "DP-2" then
					return m
				end
			end
		end
	end
	return (hl.get_monitor_at_cursor and hl.get_monitor_at_cursor()) or (hl.get_monitors() and hl.get_monitors()[1])
end
_G.resolve_window_monitor = resolve_window_monitor

local function geometry_is_maximized(w)
	if not w or not w.floating or not w.size or not w.at then
		return false
	end
	local mon = resolve_window_monitor(w)
	if not mon then
		return false
	end
	local wa = get_monitor_work_area(mon)
	local g = max_geometry(w, wa)
	return math.abs((w.size.x or 0) - g.w) <= MAX_SLOP
		and math.abs((w.size.y or 0) - g.h) <= MAX_SLOP
		and math.abs((w.at.x or 0) - g.x) <= MAX_SLOP
		and math.abs((w.at.y or 0) - g.y) <= MAX_SLOP
end

local function is_window_maximized(w)
	if not w then
		return false
	end
	-- Intent: xdg maximize counts even if Hyprland's size is mid-transition.
	if has_xdg_maximize(w) then
		return true
	end
	return geometry_is_maximized(w)
end

local function saved_state(w)
	local app_key = get_app_key(w)
	if not app_key then
		return nil, nil
	end
	return app_key, _G.app_float_state[app_key]
end

local function set_saved_maximized(app_key, maximized, reason)
	if not app_key or app_key == "" then
		return
	end
	local prev = _G.app_float_state[app_key]
	local prev_val = prev and prev.maximized
	if prev_val ~= maximized then
		log(string.format("STATE CHANGE: app=%s max=%s (was %s) reason=%s",
			app_key, tostring(maximized), tostring(prev_val), tostring(reason or "unknown")))
		_G.app_float_state[app_key] = { maximized = maximized and true or false }
		cache_dirty = true
	end
end

_G.set_app_float_maximized = function(w, maximized, reason)
	if not w or is_transient_float(w) then return end
	local app_key = get_app_key(w)
	if not app_key or app_key == "" then return end
	set_saved_maximized(app_key, maximized, reason or "explicit")
	save_float_state()
	local addr = window_addr(w)
	if addr then
		known_windows[addr] = { app_key = app_key, maximized = maximized and true or false }
	end
	log(string.format("explicit set_app_float_maximized class=%s addr=%s max=%s reason=%s",
		app_key, tostring(addr), tostring(maximized), tostring(reason or "explicit")))
end

_G.window_is_float_maximized = is_window_maximized

local function record_window_state(w, source)
	if record_suppress > 0 then
		return
	end
	if not w or is_special_overlay(w) or w.pinned or is_ignorable_window(w) then
		return
	end
	-- Real fullscreen (games): don't clobber the last floating maximize bit
	if w.fullscreen == 2 then
		return
	end
	-- Tiled windows keep whatever was last recorded while floating
	if not w.floating then
		return
	end
	local app_key = get_app_key(w)
	if not app_key then
		return
	end
	local addr = window_addr(w)
	local maximized = is_window_maximized(w)

	-- Poll / focus must not own the persisted bit OR overwrite an explicit
	-- unmax: a still-maxed sibling used to flip the class back to true, and
	-- a post-unmax poll seeing old geometry flipped known_windows back too.
	if source == "poll" or source == "window.active" then
		if addr and not known_windows[addr] then
			known_windows[addr] = { app_key = app_key, maximized = maximized }
		end
		return
	end
	if addr then
		known_windows[addr] = { app_key = app_key, maximized = maximized }
	end
	if addr and pending_restore[addr] and os.clock() < pending_restore[addr] then
		if not maximized then
			return
		end
	end

	set_saved_maximized(app_key, maximized, source or "record_window_state")
end

local function record_all_windows()
	local windows = hl.get_windows() or {}
	for _, w in ipairs(windows) do
		record_window_state(w, "poll")
	end
	if cache_dirty then
		save_float_state()
	end
end

local function clear_snap_cache(addr)
	if not _G.win11_snap_cache or not addr then
		return
	end
	for _, key in ipairs(addr_variants(addr)) do
		_G.win11_snap_cache[key] = nil
	end
end

local function set_snap_restore(addr, restore)
	_G.win11_snap_cache = _G.win11_snap_cache or {}
	for _, key in ipairs(addr_variants(addr)) do
		_G.win11_snap_cache[key] = restore
	end
end

-- Prefer a freshly resolved live window. Stale userdata after close/reload
-- is how spam-open used to crash Hyprland.
local function live_window(addr)
	if not addr or addr == "" then
		return nil
	end
	local ok, win = pcall(function()
		return hl.get_window("address:" .. addr)
	end)
	if ok and win then
		return win
	end
	return nil
end

-- Prefer the live window object. String selectors that fail to match
-- make resize/move silently target the *active* window instead.
local function resolve_window(w)
	if not w then
		return nil
	end
	local addr = window_addr(w)
	if addr then
		local live = live_window(addr)
		if live then
			return live, addr
		end
		return nil, addr
	end
	return w, addr
end

-- Keyboard focus does not restack floats. xdg-maximize (Zen after Super+Z)
-- also ignores bring_to_top; re-set maximize so it covers the window we
-- just raised above it.
-- Floats default to allowedOverFullscreen, so bring_to_top paints them above
-- an xdg-maxed Zen while focus (and XWayland input) stay on Zen. Alt-tab to a
-- maxed window must lower the others; alt-tab to a small one must focus it.
_G.win11_raise_window = function(w)
	if not w then
		return
	end
	local addr
	w, addr = resolve_window(w)
	if not w then
		return
	end
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

local function dispatch_float(w, action)
	if not w then
		return
	end
	hl.dispatch(hl.dsp.window.float({ window = w, action = action }))
end

local function suppress_record(ms)
	record_suppress = record_suppress + 1
	hl.timer(function()
		record_suppress = math.max(0, record_suppress - 1)
	end, { timeout = ms or 600, type = "oneshot" })
end

local function bump_gen()
	apply_gen = apply_gen + 1
	return apply_gen
end

local function any_floating_mode()
	local state = _G.floating_mode
	if state and state.active == true then
		return true
	end
	if state and state.workspaces then
		for _, v in pairs(state.workspaces) do
			if v then
				return true
			end
		end
	end
	return false
end

-- While fully tiled, ignore client maximize requests so Zen/Discord cannot
-- immediately re-max after we unset. Off again whenever any workspace is
-- floating (CSD maximize must work there). Mixed Super+X is handled in
-- window.fullscreen by rejecting maximize only on tiled workspaces.
-- Reuse the rule across reloads: hyprctl reload does not drop the old one,
-- and a leftover enabled copy swallows Zen's button even while floating.
local suppress_maximize_rule = _G.floating_mode_suppress_maximize_rule
pcall(function()
	if not suppress_maximize_rule then
		suppress_maximize_rule = hl.window_rule({
			name = "tiled-mode-no-maximize",
			match = { class = ".*" },
			suppress_event = "maximize",
		})
		_G.floating_mode_suppress_maximize_rule = suppress_maximize_rule
	end
	if suppress_maximize_rule then
		suppress_maximize_rule:set_enabled(not any_floating_mode())
	end
end)

local function focused_workspace_id()
	local ws = hl.get_active_workspace()
	return ws and ws.id
end

local function sync_mode_guards()
	-- on_focus_under_fullscreen is compositor-global. Follow the focused
	-- workspace: 0 = don't unmax when focusing a sibling (floating Zen);
	-- default 2 = unmax (normal tiled).
	local floating_here = M.is_active(focused_workspace_id())
	pcall(function()
		hl.config({ misc = { on_focus_under_fullscreen = floating_here and 0 or 2 } })
	end)
	if suppress_maximize_rule then
		pcall(function()
			suppress_maximize_rule:set_enabled(not any_floating_mode())
		end)
	end
	-- Geometry-filled CSD with fullscreen=0 shows maximize and the click
	-- does nothing. Re-arm xdg so the native button is restore.
	if floating_here then
		for _, w in ipairs(hl.get_windows() or {}) do
			pcall(function()
				local ws_id = w.workspace and w.workspace.id
				if M.is_active(ws_id) and uses_xdg_maximize(w) and w.floating
					and not is_real_fullscreen(w) and geometry_is_maximized(w)
					and not has_xdg_maximize(w) then
					log(string.format("arm csd xdg class=%s", tostring(w.class)))
					hl.dispatch(hl.dsp.window.fullscreen({
						window = w, mode = "maximized", action = "set",
					}))
				end
			end)
		end
	end
end

-- `action = "unset"` with no mode does not clear xdg maximize (Zen stays
-- fullscreen=1 after tiling). Set both compositor and client state to none.
local function force_unmaximize(w)
	w = select(1, resolve_window(w)) or w
	if not w then
		return
	end
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

local function set_xdg_maximize(w)
	w = select(1, resolve_window(w)) or w
	if not w then
		return
	end
	pcall(function()
		hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "maximized", action = "set" }))
	end)
end

-- Tiled-mode CSD bounce: drop maximize only. Do not touch real fullscreen
-- (Super+Shift+F) and do not zero fullscreen_state (that also clears it).
local function unset_maximize_only(w)
	w = select(1, resolve_window(w)) or w
	if not w or is_real_fullscreen(w) then
		return
	end
	pcall(function()
		hl.dispatch(hl.dsp.window.fullscreen({
			window = w, mode = "maximized", action = "unset", layout_aware = false,
		}))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "border_size", value = "unset" }))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "rounding", value = "unset" }))
	end)
end

-- Pass the window object. Never focus-then-resize: that hits whatever is
-- active if focus loses the race, which is how one unmax shrank every Ghostty.
local function set_window_geometry(w, x, y, width, height)
	w = select(1, resolve_window(w))
	if not w then
		return
	end
	pcall(function()
		hl.dispatch(hl.dsp.window.resize({ window = w, x = width, y = height, relative = false }))
		hl.dispatch(hl.dsp.window.move({ window = w, x = x, y = y }))
	end)
end

local function apply_maximized(w)
	local addr
	w, addr = resolve_window(w)
	if not w or not addr then
		return
	end
	if not w.floating then
		pcall(function()
			dispatch_float(w, "set")
		end)
		w = select(1, resolve_window(w)) or w
	end

	local mon = resolve_window_monitor(w)
	if not mon then
		return
	end
	local wa = get_monitor_work_area(mon)
	local g = max_geometry(w, wa)
	local dw, dh = default_float_size(wa)
	local restore = {
		w = dw,
		h = dh,
		x = wa.x + math.floor((wa.w - dw) / 2),
		y = wa.y + math.floor((wa.h - dh) / 2),
	}
	local existing = _G.win11_snap_cache and (_G.win11_snap_cache[addr] or _G.win11_snap_cache[addr:gsub("^0x", "")])
	if not existing then
		set_snap_restore(addr, restore)
	end

	-- CSD (Zen/Discord): xdg maximize only. Filling geometry first poisons
	-- the restore size, so the native button returns to the same full window.
	if uses_xdg_maximize(w) then
		pcall(function()
			hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "border_size", value = 0 }))
			hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "rounding", value = 0 }))
		end)
		if not has_xdg_maximize(w) then
			set_xdg_maximize(w)
		end
		return
	end

	-- Clear xdg maximize *before* filling geometry. Doing it after
	-- undoes the compositor-side maximize for hyprbar apps.
	force_unmaximize(w)
	w = select(1, resolve_window(w)) or w

	pcall(function()
		set_window_geometry(w, g.x, g.y, g.w, g.h)
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "border_size", value = 0 }))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "rounding", value = 0 }))
	end)
end

local function apply_centered_default(w)
	local addr
	w, addr = resolve_window(w)
	if not w or not addr then
		return
	end
	force_unmaximize(w)
	local mon = resolve_window_monitor(w)
	if not mon then
		return
	end
	local wa = get_monitor_work_area(mon)
	local dw, dh = default_float_size(wa)
	local dx = wa.x + math.floor((wa.w - dw) / 2)
	local dy = wa.y + math.floor((wa.h - dh) / 2)
	clear_snap_cache(addr)
	set_window_geometry(w, dx, dy, dw, dh)
end

function M.apply_floating_state(w, want_maximized)
	if not w or is_special_overlay(w) or is_ignorable_window(w) then
		return
	end
	local addr
	w, addr = resolve_window(w)
	if not w or not addr then
		return
	end
	if not w.floating then
		pcall(function()
			dispatch_float(w, "set")
		end)
		w = select(1, resolve_window(w)) or w
	end
	if skip_geometry(w) then
		return
	end
	if want_maximized == true then
		apply_maximized(w)
	elseif want_maximized == false then
		apply_centered_default(w)
	else
		-- Unknown / first launch: if client already has maximize, ensure proper maximize geometry.
		-- Otherwise, leave it alone: do NOT force unmaximize or slam to 1280x800.
		if is_window_maximized(w) then
			apply_maximized(w)
		end
	end
end

local function should_maximize(w)
	local _, saved = saved_state(w)
	if saved and saved.maximized ~= nil then
		return saved.maximized
	end
	if is_window_maximized(w) then
		return true
	end
	return nil
end

--------------------------------------------------------------------------------
-- Floating / Tiling Mode Toggle & State Management
--------------------------------------------------------------------------------

local function settle_mode(gen, want_floating, ws_id)
	local function pass()
		if not from_this_load() or apply_gen ~= gen then
			return
		end
		for _, w in ipairs(hl.get_windows() or {}) do
			local on_ws = not ws_id or (w.workspace and w.workspace.id == ws_id)
			if on_ws and not is_special_overlay(w) then
				pcall(function()
					if want_floating then
						if is_real_fullscreen(w) then
							return
						end
						if not M.is_active(w.workspace and w.workspace.id) then
							return
						end
						local maximize = should_maximize(w)
						if maximize then
							if not is_window_maximized(w) or (uses_xdg_maximize(w) and not geometry_is_maximized(w)) then
								log(string.format("settle re-max class=%s fs=%s float=%s",
									tostring(w.class), tostring(w.fullscreen), tostring(w.floating)))
								M.apply_floating_state(w, true)
							end
						elseif not w.floating then
							M.apply_floating_state(w, maximize)
						end
					else
						local still_fs = w.fullscreen and w.fullscreen ~= 0
						if w.floating or still_fs then
							log(string.format("settle re-tile class=%s fs=%s float=%s",
								tostring(w.class), tostring(w.fullscreen), tostring(w.floating)))
							force_unmaximize(w)
							dispatch_float(w, "unset")
						end
					end
				end)
			end
		end
	end
	hl.timer(pass, { timeout = 80, type = "oneshot" })
	hl.timer(pass, { timeout = 220, type = "oneshot" })
end

local function apply_mode_to_windows(windows, want_floating, gen, ws_id)
	local count = 0
	if not want_floating then
		for _, w in ipairs(windows) do
			if not is_special_overlay(w) then
				record_window_state(w)
			end
		end
		if cache_dirty then
			save_float_state()
		end
	end

	-- Suppress client maximize *before* we unset, so Zen cannot bounce back.
	-- Only when nothing is in floating mode; mixed Super+X uses window.fullscreen.
	if suppress_maximize_rule then
		pcall(function()
			suppress_maximize_rule:set_enabled(not any_floating_mode())
		end)
	end

	suppress_record(700)

	for _, w in ipairs(windows) do
		if not is_special_overlay(w) then
			pcall(function()
				local maximize = should_maximize(w)
				log(string.format(
					"  %s class=%s addr=%s float=%s fs=%s maximize=%s xdg=%s",
					want_floating and "float" or "tile",
					tostring(w.class), tostring(window_addr(w)),
					tostring(w.floating), tostring(w.fullscreen),
					tostring(maximize), tostring(uses_xdg_maximize(w))
				))
				if want_floating then
					if is_real_fullscreen(w) then
						log(string.format("skip real-fullscreen class=%s", tostring(w.class)))
						return
					end
					M.apply_floating_state(w, maximize)
				else
					force_unmaximize(w)
					dispatch_float(w, "unset")
				end
			end)
			count = count + 1
		end
	end

	if cache_dirty then
		save_float_state()
	end
	settle_mode(gen, want_floating, ws_id)
	return count
end

function M.toggle()
	local state = _G.floating_mode
	state.active = not state.active
	state.workspaces = {}

	local gen = bump_gen()
	log("==================================================================")
	log(">>> TOGGLE ACTIVATED: Mode is now " .. (state.active and "FLOATING" or "TILED") .. " gen=" .. tostring(gen))

	local count = apply_mode_to_windows(hl.get_windows() or {}, state.active, gen)
	log(string.format("Dispatched float=%s to %d windows", tostring(state.active), count))
	write_mode_indicator(state.active)
	sync_mode_guards()
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

	local gen = bump_gen()
	log(string.format(">>> WORKSPACE TOGGLE: WS %s is now %s gen=%s", tostring(id), target_floating and "FLOATING" or "TILED", tostring(gen)))

	local count = apply_mode_to_windows(hl.get_workspace_windows(id) or {}, target_floating, gen, id)
	log(string.format("Dispatched float=%s to %d windows on workspace %s", tostring(target_floating), count, tostring(id)))
	write_mode_indicator(state.active)
	sync_mode_guards()
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
	if not from_this_load() or not w then
		return
	end
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

	local addr = window_addr(w)
	if not addr or handled_windows[addr] or is_special_overlay(w) then
		return
	end
	handled_windows[addr] = true
	pending_restore[addr] = os.clock() + 2.5

	local mygen = apply_gen
	local ws_at_open = ws_id
	suppress_record(800)

	-- One apply path. Four overlapping timers were re-maxing a window the
	-- user had just unmaxed, and dispatching resize/move on dead clients.
	local function apply(wait_n)
		wait_n = wait_n or 0
		if not from_this_load() or apply_gen ~= mygen then
			return
		end
		if not M.is_active(ws_at_open) then
			return
		end
		local win = live_window(addr)
		if not win then
			return
		end
		local mapped = true
		pcall(function()
			mapped = win.mapped
		end)
		if not mapped then
			if wait_n < 10 then
				hl.timer(function() apply(wait_n + 1) end, { timeout = 50, type = "oneshot" })
			end
			return
		end

		local ignorable = false
		pcall(function()
			ignorable = is_ignorable_window(win)
		end)
		if ignorable then
			local title = ""
			pcall(function()
				title = (win.title or ""):lower()
			end)
			log(string.format("skip ignorable new window class=%s addr=%s title=%s",
				tostring(win.class), addr, tostring(win.title)))
			if title:match("updater") or title:match("splash") then
				return
			end
			if wait_n < 10 then
				hl.timer(function() apply(wait_n + 1) end, { timeout = 50, type = "oneshot" })
			end
			return
		end

		local maximize = should_maximize(win)
		log(string.format(
			"new window class=%s addr=%s maximize=%s fs=%s wait=%d",
			tostring(win.class), addr, tostring(maximize), tostring(win.fullscreen), wait_n
		))
		pcall(function()
			M.apply_floating_state(win, maximize)
		end)

		-- CSD apps (Discord/Zen): Electron may overwrite size after map.
		-- Hyprbar apps never have xdg maximize — do not retry those.
		if maximize == true then
			local xdg = false
			pcall(function()
				xdg = uses_xdg_maximize(win)
			end)
			if xdg then
				local function csd_retry(n)
					hl.timer(function()
						if not from_this_load() or apply_gen ~= mygen then
							return
						end
						local cur = live_window(addr)
						if not cur then
							return
						end
						local need = false
						pcall(function()
							need = not geometry_is_maximized(cur) or not has_xdg_maximize(cur)
						end)
						if need then
							log(string.format("retry apply_maximized class=%s addr=%s (retry %d)",
								tostring(cur.class), addr, n + 1))
							pcall(function()
								apply_maximized(cur)
							end)
							if n < 2 then
								csd_retry(n + 1)
							end
						end
					end, { timeout = (n == 0 and 200 or 500), type = "oneshot" })
				end
				csd_retry(0)
			end
		end
	end

	hl.timer(function() apply(0) end, { timeout = 40, type = "oneshot" })
end

hl.on("window.open", handle_new_window)

hl.on("window.close", function(w)
	if not from_this_load() or not w then
		return
	end
	-- Last explicit/closed window owns the class bit. OR-ing sibling
	-- maximize is why unmax → close → reopen came back maximized.
	pcall(function()
		local addr = window_addr(w)
		local known = addr and known_windows[addr]
		local app_key = get_app_key(w) or (known and known.app_key)

		if addr then
			handled_windows[addr] = nil
			pending_restore[addr] = nil
		end

		local ignorable = false
		pcall(function()
			ignorable = is_ignorable_window(w)
		end)
		if ignorable then
			log(string.format("close ignored splash/tiny window class=%s addr=%s",
				tostring(app_key), tostring(addr)))
			if addr then
				known_windows[addr] = nil
				clear_snap_cache(addr)
			end
			return
		end

		local maximized = nil
		if known and known.maximized ~= nil then
			maximized = known.maximized
		else
			pcall(function()
				if w.floating and w.fullscreen ~= 2 then
					maximized = is_window_maximized(w)
				end
			end)
		end

		if app_key and maximized ~= nil then
			log(string.format("close class=%s addr=%s maximized=%s",
				app_key, tostring(addr), tostring(maximized)))
			set_saved_maximized(app_key, maximized, "close")
			save_float_state()
		end

		if addr then
			known_windows[addr] = nil
			clear_snap_cache(addr)
		end
	end)
end)

-- Keep pinned windows (Picture-in-Picture) on top and track active window state
local last_raise = 0
hl.on("window.active", function(active_win)
	if not from_this_load() then
		return
	end
	local ws_id = active_win and active_win.workspace and active_win.workspace.id
	if M.is_active(ws_id) and active_win then
		record_window_state(active_win, "window.active")
	elseif active_win and active_win.floating then
		record_window_state(active_win, "window.active")
	end

	-- Always raise the focused float. Debouncing this is why the second
	-- alt-tab left Spotify painted on top of a focused maximized Zen.
	if active_win then
		local floating = false
		pcall(function()
			floating = active_win.floating and true or false
		end)
		if floating and _G.win11_raise_window then
			_G.win11_raise_window(active_win)
		end
	end
	local now = os.clock()
	if now - last_raise < 0.05 then
		return
	end
	last_raise = now
	for _, w in ipairs(hl.get_windows() or {}) do
		local pinned = false
		pcall(function()
			pinned = w.pinned and w.floating and (not active_win or w.address ~= active_win.address)
		end)
		if pinned then
			pcall(function()
				hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
			end)
		end
	end
end)

local csd_restore_lock = false
hl.on("window.fullscreen", function(w)
	if not from_this_load() or not w then
		return
	end
	local ws_id = w.workspace and w.workspace.id
	-- Tiled workspace: CSD maximize is not a thing. Real fullscreen is.
	if not M.is_active(ws_id) and has_xdg_maximize(w) then
		log(string.format("tiled-mode reject maximize class=%s fs=%s",
			tostring(w.class), tostring(w.fullscreen)))
		unset_maximize_only(w)
		return
	end
	if record_suppress > 0 or csd_restore_lock then
		return
	end
	record_window_state(w, "window.fullscreen")
	if cache_dirty then
		save_float_state()
	end
	-- Floating CSD restore. Last floating size is often already the work
	-- area, so unset alone is a visual no-op; slam to the binary default.
	-- Never do this for PiP/transients: they are not CSD main windows, and
	-- the default size is what "forgot" the real PiP size.
	if M.is_active(ws_id) and uses_xdg_maximize(w) and w.floating
		and not is_transient_float(w)
		and not is_real_fullscreen(w) and not has_xdg_maximize(w) then
		log(string.format("csd restore class=%s addr=%s",
			tostring(w.class), tostring(window_addr(w))))
		csd_restore_lock = true
		apply_centered_default(w)
		hl.timer(function()
			csd_restore_lock = false
		end, { timeout = 200, type = "oneshot" })
	end
end)

hl.on("window.move_to_workspace", function(w, ws)
	if not from_this_load() or not w then
		return
	end
	local ws_id = (ws and ws.id) or (w.workspace and w.workspace.id)
	if not M.is_active(ws_id) and has_xdg_maximize(w) then
		unset_maximize_only(w)
	end
end)

hl.on("workspace.active", function(ws)
	if not from_this_load() then
		return
	end
	-- Dual monitor: this fires per output. Only follow the focused one;
	-- on_focus_under_fullscreen is a single global option.
	local focused = hl.get_active_workspace()
	if ws and focused and ws.id ~= focused.id then
		return
	end
	sync_mode_guards()
end)

hl.on("monitor.focused", function()
	if from_this_load() then
		sync_mode_guards()
	end
end)

-- If already in floating mode from a previous session, don't let tiled
-- focus steal xdg-maximize off Zen/Discord.
sync_mode_guards()

-- If floating mode was active from a persistent session, apply once after
-- windows have mapped. A second pass a second later re-maxed windows the
-- user had already unmaxed.
if _G.floating_mode.active then
	hl.timer(function()
		if from_this_load() and _G.floating_mode.active then
			local gen = bump_gen()
			apply_mode_to_windows(hl.get_windows() or {}, true, gen)
		end
	end, { timeout = 400, type = "oneshot" })
end

-- Record maximize/restore after drag-to-top or hyprbar clicks
hl.timer(function()
	if from_this_load() then
		record_all_windows()
	end
end, { timeout = 400, type = "repeat" })

hl.timer(function()
	if from_this_load() then
		record_all_windows()
	end
end, { timeout = 200, type = "oneshot" })

return M
