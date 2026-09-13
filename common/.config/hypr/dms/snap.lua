-- Snap layouts: drag-to-edge, top flyout, maximize/restore.
-- Loaded for every theme. QML overlay lives in themes/shared/plugins/snap.

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

_G.win11_toggle_maximize = function(target_addr)
	local w = (target_addr and hl.get_window("address:" .. target_addr)) or hl.get_active_window()
	if not w then
		return
	end

	_G.win11_snap_cache = _G.win11_snap_cache or {}
	local raw_addr = w.address:lower()
	local clean_addr = raw_addr:gsub("^0x", "")
	local full_addr = "0x" .. clean_addr

	local mon = (_G.resolve_window_monitor and _G.resolve_window_monitor(w))
		or (type(w.monitor) == "table" and w.monitor)
		or (hl.get_monitor_at_cursor and hl.get_monitor_at_cursor())
		or (hl.get_monitors() and hl.get_monitors()[1])
	if not mon then
		return
	end

	local wa = get_monitor_work_area(mon)

	-- Check whether window has hyprbars titlebar using centralized helper
	local has_bar = true
	if _G.window_has_hyprbar then
		has_bar = _G.window_has_hyprbar(w)
	end

	local title_h = has_bar and 30 or 0
	local max_x = wa.x
	local max_y = wa.y + title_h
	local max_w = wa.w
	local max_h = wa.h - title_h

	local is_currently_maximized = false
	local cached = _G.win11_snap_cache[full_addr] or _G.win11_snap_cache[clean_addr]
	local use_xdg = _G.window_uses_xdg_maximize and _G.window_uses_xdg_maximize(w)
	local transient = _G.window_is_transient_float and _G.window_is_transient_float(w)

	if math.abs(w.size.x - max_w) <= 4 and math.abs(w.size.y - max_h) <= 4
		and math.abs(w.at.x - max_x) <= 4 and math.abs(w.at.y - max_y) <= 4 then
		is_currently_maximized = true
	end
	if not transient and (w.fullscreen == 1 or w.fullscreen == 3) then
		is_currently_maximized = true
	end

	local function targeted_resize_move(win, x, y, width, height)
		if not win then
			return
		end
		pcall(function()
			hl.dispatch(hl.dsp.window.set_prop({ window = win, prop = "no_anim", value = "1" }))
			hl.dispatch(hl.dsp.window.resize({ window = win, x = width, y = height, relative = false }))
			hl.dispatch(hl.dsp.window.move({ window = win, x = x, y = y }))
			hl.dispatch(hl.dsp.window.set_prop({ window = win, prop = "no_anim", value = "unset" }))
		end)
	end

	if is_currently_maximized then
		-- RESTORE (to pre-snap size and position)
		hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "border_size", value = "unset" }))
		hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "rounding", value = "unset" }))

		-- Never xdg-unmax transients: Firefox/Zen unmaxes the parent too.
		if use_xdg and (w.fullscreen == 1 or w.fullscreen == 3) then
			pcall(function()
				hl.dispatch(hl.dsp.window.fullscreen({ window = "address:" .. full_addr, mode = "maximized", action = "unset", layout_aware = false }))
			end)
		end

		local s = cached or { w = math.floor(wa.w * 0.6), h = math.floor(wa.h * 0.7) }
		_G.win11_snap_cache[full_addr] = nil
		_G.win11_snap_cache[clean_addr] = nil

		local newX = s.x or math.max(wa.x + 20, wa.x + math.floor((wa.w - s.w) / 2))
		local newY = s.y or math.max(wa.y + 40, wa.y + math.floor((wa.h - s.h) / 2))

		w = hl.get_window("address:" .. full_addr) or w
		targeted_resize_move(w, newX, newY, s.w, s.h)

		if _G.set_app_float_maximized then
			_G.set_app_float_maximized(w, false, "win11_toggle_maximize")
		end
	else
		-- MAXIMIZE (identical to dragging to top edge)
		if not w.floating then
			hl.dispatch(hl.dsp.window.float({ window = "address:" .. full_addr, action = "set" }))
		end

		_G.win11_snap_cache[full_addr] = { w = w.size.x, h = w.size.y, x = w.at.x, y = w.at.y }
		_G.win11_snap_cache[clean_addr] = _G.win11_snap_cache[full_addr]

		w = hl.get_window("address:" .. full_addr) or w
		if use_xdg then
			-- CSD: xdg maximize only. Geometry fill poisons native restore.
			pcall(function()
				hl.dispatch(hl.dsp.window.fullscreen({
					window = "address:" .. full_addr, mode = "maximized", action = "set",
				}))
				hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "border_size", value = 0 }))
				hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "rounding", value = 0 }))
			end)
		else
			targeted_resize_move(w, max_x, max_y, max_w, max_h)
			pcall(function()
				hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "border_size", value = 0 }))
				hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "rounding", value = 0 }))
			end)
		end

		if _G.set_app_float_maximized then
			_G.set_app_float_maximized(w, true, "win11_toggle_maximize")
		end
	end
	return (hl.dsp and hl.dsp.no_op and hl.dsp.no_op()) or nil
end

local function get_zone_geometry(mon, zone, has_bar)
	local wa = get_monitor_work_area(mon)
	local title_h = has_bar and 30 or 0
	local gap = 8
	local w = wa.w
	local h = wa.h
	local half_w = math.floor(w / 2 + 0.5)
	local half_h = math.floor(h / 2 + 0.5)
	local two_thirds_w = math.floor(w * 0.67 + 0.5)
	local one_third_w = math.floor(w / 3 + 0.5)
	local two_thirds_h = math.floor(h * 0.67 + 0.5)
	local one_third_h = math.floor(h / 3 + 0.5)

	local zx, zy, zw, zh = 0, 0, w, h
	if zone == "maximize" then
		zx, zy, zw, zh = 0, title_h, w, h - title_h
	elseif zone == "half-left" or zone == "left" then
		zx, zy = gap, gap + title_h
		zw, zh = half_w - (gap * 1.5), h - (gap * 2) - title_h
	elseif zone == "half-right" or zone == "right" then
		zx, zy = half_w + (gap * 0.5), gap + title_h
		zw, zh = half_w - (gap * 1.5), h - (gap * 2) - title_h
	elseif zone == "half-top" or zone == "top" then
		zx, zy = gap, gap + title_h
		zw, zh = w - (gap * 2), half_h - (gap * 1.5) - title_h
	elseif zone == "half-bottom" or zone == "bottom" then
		zx, zy = gap, half_h + (gap * 0.5) + title_h
		zw, zh = w - (gap * 2), half_h - (gap * 1.5) - title_h
	elseif zone == "left-two-thirds" then
		zx, zy = gap, gap + title_h
		zw, zh = two_thirds_w - (gap * 1.5), h - (gap * 2) - title_h
	elseif zone == "right-one-third" then
		zx, zy = two_thirds_w + (gap * 0.5), gap + title_h
		zw, zh = (w - two_thirds_w) - (gap * 1.5), h - (gap * 2) - title_h
	elseif zone == "top-two-thirds" then
		zx, zy = gap, gap + title_h
		zw, zh = w - (gap * 2), two_thirds_h - (gap * 1.5) - title_h
	elseif zone == "bottom-one-third" then
		zx, zy = gap, two_thirds_h + (gap * 0.5) + title_h
		zw, zh = w - (gap * 2), (h - two_thirds_h) - (gap * 1.5) - title_h
	elseif zone == "col-1" then
		zx, zy = gap, gap + title_h
		zw, zh = one_third_w - (gap * 1.5), h - (gap * 2) - title_h
	elseif zone == "col-2" then
		zx, zy = one_third_w + (gap * 0.5), gap + title_h
		zw, zh = one_third_w - gap, h - (gap * 2) - title_h
	elseif zone == "col-3" then
		zx, zy = (one_third_w * 2) + (gap * 0.5), gap + title_h
		zw, zh = (w - (one_third_w * 2)) - (gap * 1.5), h - (gap * 2) - title_h
	elseif zone == "row-1" then
		zx, zy = gap, gap + title_h
		zw, zh = w - (gap * 2), one_third_h - (gap * 1.5) - title_h
	elseif zone == "row-2" then
		zx, zy = gap, one_third_h + (gap * 0.5) + title_h
		zw, zh = w - (gap * 2), one_third_h - gap - title_h
	elseif zone == "row-3" then
		zx, zy = gap, (one_third_h * 2) + (gap * 0.5) + title_h
		zw, zh = w - (gap * 2), (h - (one_third_h * 2)) - (gap * 1.5) - title_h
	elseif zone == "top-left" then
		zx, zy = gap, gap + title_h
		zw, zh = half_w - (gap * 1.5), half_h - (gap * 1.5) - title_h
	elseif zone == "top-right" then
		zx, zy = half_w + (gap * 0.5), gap + title_h
		zw, zh = half_w - (gap * 1.5), half_h - (gap * 1.5) - title_h
	elseif zone == "bottom-left" then
		zx, zy = gap, half_h + (gap * 0.5) + title_h
		zw, zh = half_w - (gap * 1.5), half_h - (gap * 1.5) - title_h
	elseif zone == "bottom-right" then
		zx, zy = half_w + (gap * 0.5), half_h + (gap * 0.5) + title_h
		zw, zh = half_w - (gap * 1.5), half_h - (gap * 1.5) - title_h
	end

	return {
		x = wa.x + math.floor(zx),
		y = wa.y + math.floor(zy),
		w = math.floor(zw),
		h = math.floor(zh),
	}
end

_G.win11_snap_window = function(target_addr, zone, screen_name)
	if not zone or zone == "" then
		return (hl.dsp and hl.dsp.no_op and hl.dsp.no_op()) or nil
	end
	if zone == "maximize" then
		if _G.win11_toggle_maximize then
			return _G.win11_toggle_maximize(target_addr)
		end
		return (hl.dsp and hl.dsp.no_op and hl.dsp.no_op()) or nil
	end

	local w = (target_addr and target_addr ~= "" and hl.get_window("address:" .. target_addr)) or hl.get_active_window()
	if not w then
		return (hl.dsp and hl.dsp.no_op and hl.dsp.no_op()) or nil
	end

	local raw_addr = w.address:lower()
	local clean_addr = raw_addr:gsub("^0x", "")
	local full_addr = "0x" .. clean_addr

	local mon = nil
	if screen_name and screen_name ~= "" then
		for _, m in ipairs(hl.get_monitors() or {}) do
			if m.name == screen_name then
				mon = m
				break
			end
		end
	end
	if not mon then
		mon = w.monitor or (hl.get_monitors() and hl.get_monitors()[1])
	end
	if not mon then
		return (hl.dsp and hl.dsp.no_op and hl.dsp.no_op()) or nil
	end

	if not w.floating then
		hl.dispatch(hl.dsp.window.float({ window = "address:" .. full_addr, action = "set" }))
	end

	_G.win11_snap_cache = _G.win11_snap_cache or {}
	if not _G.win11_snap_cache[full_addr] and not _G.win11_snap_cache[clean_addr] then
		_G.win11_snap_cache[full_addr] = { w = w.size.x, h = w.size.y, x = w.at.x, y = w.at.y }
		_G.win11_snap_cache[clean_addr] = _G.win11_snap_cache[full_addr]
	end

	local has_bar = true
	if _G.window_has_hyprbar then
		has_bar = _G.window_has_hyprbar(w)
	end

	local geom = get_zone_geometry(mon, zone, has_bar)

	w = hl.get_window("address:" .. full_addr) or w
	pcall(function()
		hl.dispatch(hl.dsp.window.resize({ window = w, x = geom.w, y = geom.h, relative = false }))
		hl.dispatch(hl.dsp.window.move({ window = w, x = geom.x, y = geom.y }))
		hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "border_size", value = "unset" }))
		hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "rounding", value = "unset" }))
	end)
	if _G.set_app_float_maximized then
		_G.set_app_float_maximized(w, false, "win11_snap")
	end
	return (hl.dsp and hl.dsp.no_op and hl.dsp.no_op()) or nil
end

-- Keep the drag grab under the cursor after unmax/unsnap.
-- X is proportional (grab 30% from the left of a maxed window stays 30%
-- from the left of the restored size). Y is the original titlebar offset
-- (hyprbar grabs sit above the window, so this can be negative).
local function follow_cursor_restore_pos(cursorX, cursorY, grabX, grabY, oldW, newW)
	cursorX = tonumber(cursorX) or 0
	cursorY = tonumber(cursorY) or 0
	grabX = tonumber(grabX) or 0
	grabY = tonumber(grabY) or 0
	oldW = tonumber(oldW) or 0
	newW = tonumber(newW) or 0
	local ratio = 0.5
	if oldW > 1 then
		ratio = grabX / oldW
	end
	if ratio < 0.05 then
		ratio = 0.05
	elseif ratio > 0.95 then
		ratio = 0.95
	end
	local offsetX = (newW > 0) and (newW * ratio) or 0
	return math.floor(cursorX - offsetX + 0.5), math.floor(cursorY - grabY + 0.5)
end

_G.win11_restore_window = function(target_addr, posX, posY, grabX, grabY, origW)
	local w = (target_addr and target_addr ~= "" and hl.get_window("address:" .. target_addr)) or hl.get_active_window()
	if not w or not w.floating then
		return (hl.dsp and hl.dsp.no_op and hl.dsp.no_op()) or nil
	end

	local raw_addr = w.address:lower()
	local clean_addr = raw_addr:gsub("^0x", "")
	local full_addr = "0x" .. clean_addr

	local currently_max = (_G.window_is_float_maximized and _G.window_is_float_maximized(w))
		or (w.fullscreen == 1 or w.fullscreen == 3)
	local use_xdg = _G.window_uses_xdg_maximize and _G.window_uses_xdg_maximize(w)

	local cached = _G.win11_snap_cache and (_G.win11_snap_cache[full_addr] or _G.win11_snap_cache[clean_addr])

	-- Normal (not snapped/maxed) drag-drop: do not resize. Only unsnap/unmax.
	if not cached and not currently_max then
		return (hl.dsp and hl.dsp.no_op and hl.dsp.no_op()) or nil
	end

	-- Capture grab against the pre-unmax geometry. Hyprland unmaxes a
	-- CSD float at mouse-down and recenters; live size is then already
	-- small, so the ratio must use the original (maxed) width.
	local live = hl.get_cursor_pos()
	local cursorX = (live and live.x) or tonumber(posX) or 0
	local cursorY = (live and live.y) or tonumber(posY) or 0
	local winX, winY, liveW = w.at.x, w.at.y, w.size.x
	local usedGrabX = tonumber(grabX)
	local usedGrabY = tonumber(grabY)
	if not usedGrabX or usedGrabX < -90000 then
		usedGrabX = cursorX - winX
	end
	if not usedGrabY or usedGrabY < -90000 then
		usedGrabY = cursorY - winY
	end
	local usedOldW = tonumber(origW)
	if not usedOldW or usedOldW < 2 then
		usedOldW = liveW
	end

	_G.win11_drag_restore = true
	_G.win11_dragging = true

	hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "border_size", value = "unset" }))
	hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "rounding", value = "unset" }))
	pcall(function()
		hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "no_anim", value = "1" }))
	end)

	-- Geometry-only transients (PiP) must not xdg-unmax: that unmaxes the parent.
	-- Drop client fullscreen after geometry restore so the PiP HUD returns.
	if _G.window_is_transient_float and _G.window_is_transient_float(w) then
		if _G.overlay_set_geometry_maxed then
			_G.overlay_set_geometry_maxed(w, false)
		end
		local og = _G.overlay_restore_geom and _G.overlay_restore_geom(w)
		if og then
			cached = og
		end
	elseif use_xdg and (w.fullscreen == 1 or w.fullscreen == 3) then
		pcall(function()
			hl.dispatch(hl.dsp.window.fullscreen({
				window = "address:" .. full_addr, mode = "maximized", action = "unset", layout_aware = false,
			}))
		end)
	end

	if _G.set_app_float_maximized then
		_G.set_app_float_maximized(w, false, "win11_restore")
	end

	if _G.win11_snap_cache then
		_G.win11_snap_cache[full_addr] = nil
		_G.win11_snap_cache[clean_addr] = nil
	end

	local mon = (_G.resolve_window_monitor and _G.resolve_window_monitor(w))
		or (type(w.monitor) == "table" and w.monitor)
		or (hl.get_monitors() and hl.get_monitors()[1])
	local wa = mon and get_monitor_work_area(mon) or { x = 0, y = 0, w = 1920, h = 1080 }
	local dw = math.min(1280, math.max(400, math.floor(wa.w * 0.6)))
	local dh = math.min(800, math.max(300, math.floor(wa.h * 0.7)))
	local s = cached or { w = dw, h = dh }

	w = hl.get_window("address:" .. full_addr) or w
	local newX, newY = follow_cursor_restore_pos(cursorX, cursorY, usedGrabX, usedGrabY, usedOldW, s.w)
	pcall(function()
		hl.dispatch(hl.dsp.window.resize({ window = w, x = s.w, y = s.h, relative = false }))
		hl.dispatch(hl.dsp.window.move({ window = w, x = newX, y = newY }))
	end)
	if _G.window_is_transient_float and _G.window_is_transient_float(w) then
		if _G.overlay_clear_fullscreen then
			_G.overlay_clear_fullscreen(w)
		end
	end
	pcall(function()
		hl.dispatch(hl.dsp.window.set_prop({ window = "address:" .. full_addr, prop = "no_anim", value = "unset" }))
	end)
	-- Cleared on dragstop. Fallback if dragstop never arrives.
	hl.timer(function()
		if not _G.win11_dragging then
			_G.win11_drag_restore = false
		end
	end, { timeout = 2000, type = "oneshot" })
	return (hl.dsp and hl.dsp.no_op and hl.dsp.no_op()) or nil
end

_G.snap_window = _G.win11_snap_window
_G.snap_restore_window = _G.win11_restore_window
_G.snap_toggle_maximize = _G.win11_toggle_maximize
