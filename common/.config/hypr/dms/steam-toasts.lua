-- Steam XWayland toasts ignore layer-shell exclusive zones. Clamp them
-- into each monitor's reserved work area (any bar edge, height, or
-- monitor). Stay invisible while Steam finishes mapping/moving, then
-- show once — so the tug-of-war never hits the screen.
--
-- Known limitation: a right-edge bar can still twitch. Steam keeps
-- pinning the toast to the X11 screen edge after we place it. Revisit
-- when the Steam client is actually native Wayland (Ozone/Hyprland is
-- not); xdg/layer toasts would not need this hook.

hl.window_rule({
	match = { class = "^(steam)$", title = "^(notificationtoasts)" },
	no_initial_focus = true,
	pin = true,
	no_anim = true,
})

hl.window_rule({
	name = "steam-toast-hidden",
	match = {
		class = "^(steam)$",
		title = "^(notificationtoasts)",
		tag = "negative:steam-toast-ready",
	},
	opacity = "0 override 0 override 0 override",
})

local GAP_PX = 8
local POLL_MS = 32
local STABLE_POLLS = 8
local MAX_POLLS = 40
local watching = {}

local function is_steam_toast(w)
	if not w then
		return false
	end
	local class = string.lower(w.class or w.initial_class or "")
	local title = string.lower(w.title or w.initial_title or "")
	return class == "steam" and string.find(title, "^notificationtoasts", 1, false) ~= nil
end

-- Hyprland reports untransformed width/height; odd transforms are 90/270.
local function monitor_layout(mon)
	local width, height = mon.width, mon.height
	local transform = tonumber(mon.transform) or 0
	if transform % 2 == 1 then
		width, height = height, width
	end
	return mon.x, mon.y, width, height
end

local function workarea_for(w)
	local mon = w.monitor
	local size = w.size
	if not mon or not size then
		return nil
	end
	local win_w, win_h = size.x, size.y
	if not win_w or not win_h or win_w <= 1 or win_h <= 1 then
		return nil
	end
	local mx, my, mw, mh = monitor_layout(mon)
	local reserved = mon.reserved or {}
	local left = reserved.left or 0
	local top = reserved.top or 0
	local right = reserved.right or 0
	local bottom = reserved.bottom or 0
	-- Only pad edges the panel actually occupies, so a side bar does not
	-- also fight Steam's own bottom-right margin on the other axis.
	local min_x = mx + left + (left > 0 and GAP_PX or 0)
	local min_y = my + top + (top > 0 and GAP_PX or 0)
	local max_x = mx + mw - right - (right > 0 and GAP_PX or 0) - win_w
	local max_y = my + mh - bottom - (bottom > 0 and GAP_PX or 0) - win_h
	if max_x < min_x then
		max_x = min_x
	end
	if max_y < min_y then
		max_y = min_y
	end
	return min_x, min_y, max_x, max_y, win_w, win_h
end

local function in_workarea(w)
	local at = w.at
	local min_x, min_y, max_x, max_y = workarea_for(w)
	if not at or not min_x then
		return false
	end
	local x, y = at.x, at.y
	return x and y and x >= min_x - 1 and x <= max_x + 1 and y >= min_y - 1 and y <= max_y + 1
end

local function clamp_into_workarea(w)
	local ok, mapped = pcall(function()
		return w.mapped
	end)
	if not ok or not mapped or not is_steam_toast(w) then
		return false
	end
	local at = w.at
	local min_x, min_y, max_x, max_y = workarea_for(w)
	if not at or not min_x then
		return false
	end
	local x, y = at.x, at.y
	if not x or not y then
		return false
	end
	local nx = math.min(math.max(x, min_x), max_x)
	local ny = math.min(math.max(y, min_y), max_y)
	if nx ~= x or ny ~= y then
		hl.dispatch(hl.dsp.window.move({ x = nx, y = ny, window = w }))
	end
	return true
end

local function reveal(w)
	pcall(function()
		hl.dispatch(hl.dsp.window.tag({ tag = "+steam-toast-ready", window = w }))
	end)
end

local function watch_steam_toast(w)
	if not is_steam_toast(w) then
		return
	end
	local addr = w.address
	if not addr or watching[addr] then
		return
	end
	watching[addr] = true

	local stable = 0
	local polls = 0
	local timer
	timer = hl.timer(function()
		polls = polls + 1
		local alive, mapped = pcall(function()
			return w.mapped
		end)
		if not alive or not mapped then
			timer:set_enabled(false)
			watching[addr] = nil
			return
		end

		-- Count stability against Steam's position, not our just-applied clamp.
		-- A right-edge bar in particular keeps restoring X after we move it.
		if in_workarea(w) then
			stable = stable + 1
		else
			stable = 0
			clamp_into_workarea(w)
		end

		if stable >= STABLE_POLLS or polls >= MAX_POLLS then
			if not in_workarea(w) then
				clamp_into_workarea(w)
			end
			reveal(w)
			timer:set_enabled(false)
			watching[addr] = nil
		end
	end, { timeout = POLL_MS, type = "repeat" })
end

hl.on("window.open", watch_steam_toast)
hl.on("window.title", watch_steam_toast)
