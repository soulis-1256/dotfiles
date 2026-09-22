-- DMS user keybind overrides (edit via Control Center or dms; do not remove this header)

hl.unbind("Print")
hl.bind("Print", hl.dsp.exec_cmd("dms screenshot --no-confirm -d /tmp"), { description = "dms screenshot" })
hl.unbind("SUPER + R")
hl.bind("SUPER + R", hl.dsp.exec_cmd("dms ipc call spotlight toggle"), { description = "Spotlight" })
hl.unbind("SUPER + 0")
hl.bind("SUPER + 0", hl.dsp.focus({ workspace = "10" }), { description = "Workspace 10" })
hl.unbind("SUPER + SHIFT + 0")
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }), { description = "Move to workspace 10" })
hl.unbind("SUPER + SHIFT + parenright")
hl.bind("SUPER + SHIFT + parenright", hl.dsp.window.move({ workspace = "10" }), { description = "Move to workspace 10" })
hl.unbind("SUPER + T")
hl.unbind("SUPER + grave")
-- Crowded mosaic workspaces spill: switch-then-wait-then-spawn via mosaic_exec
-- so the terminal maps directly onto the hole (no open-here-switch-move flash).
-- Falls back to plain exec when mosaic is unavailable (e.g. hyprctl reload race).
local function spawn_ghostty()
	if _G.mosaic_exec then
		_G.mosaic_exec("ghostty")
	else
		hl.dispatch(hl.dsp.exec_cmd("ghostty"))
	end
end
hl.bind("SUPER + grave", spawn_ghostty, { description = "Terminal (ghostty)" })
hl.unbind("SUPER + asciitilde")
hl.bind("SUPER + asciitilde", spawn_ghostty, { description = "Terminal (ghostty)" })
local function addr_of(w)
	if not w or not w.address then
		return nil
	end
	local a = tostring(w.address):lower()
	if a:find("^0x") then
		return a
	end
	return "0x" .. a
end

local function alt_tab(back)
	local ws = hl.get_active_workspace()
	local ws_id = ws and ws.id
	local prev_addr = addr_of(hl.get_active_window())
	if back then
		hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
	else
		hl.dispatch(hl.dsp.window.cycle_next())
	end
	local w = hl.get_active_window()
	if not w or addr_of(w) == prev_addr then
		-- cycle_next often no-ops when the other window is under an
		-- xdg-maximized client. Pick another mapped window on this workspace.
		for _, c in ipairs(hl.get_windows() or {}) do
			local ok, take = pcall(function()
				return c.mapped and not c.hidden and not c.pinned
					and c.workspace and c.workspace.id == ws_id
					and addr_of(c) ~= prev_addr
			end)
			if ok and take then
				w = c
				pcall(function()
					hl.dispatch(hl.dsp.focus({ window = w }))
				end)
				break
			end
		end
	end
	if not w then
		return
	end
	if _G.win11_raise_window then
		_G.win11_raise_window(w, { force = true })
	else
		pcall(function()
			hl.dispatch(hl.dsp.focus({ window = w }))
			hl.dispatch(hl.dsp.window.bring_to_top({ window = w }))
			hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
		end)
	end
end
hl.unbind("ALT + SHIFT + TAB")
hl.bind("ALT + SHIFT + TAB", function()
	alt_tab(true)
end, { description = "Switch to previous window" })
hl.unbind("ALT + TAB")
hl.bind("ALT + TAB", function()
	alt_tab(false)
end, { description = "Switch to next window" })
local function toggle_floating()
	local w = hl.get_active_window()
	if not w then
		hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
		return
	end
	local ws_id = w.workspace and w.workspace.id
	if not ws_id then
		local aws = hl.get_active_workspace()
		ws_id = aws and aws.id
	end
	local is_mosaic = false
	pcall(function()
		if _G.mosaic_is_active then
			is_mosaic = _G.mosaic_is_active(ws_id)
		elseif _G.mosaic_mode and _G.mosaic_mode.is_active then
			is_mosaic = _G.mosaic_mode.is_active(ws_id)
		end
	end)

	if is_mosaic then
		local was_floating = w.floating
		local addr = nil
		pcall(function()
			if w.address then
				addr = tostring(w.address):lower()
				if not addr:find("^0x") then addr = "0x" .. addr end
			end
		end)

		if not was_floating then
			-- Tiling -> Floating
			_G.mosaic_explicit_floats = _G.mosaic_explicit_floats or {}
			_G.mosaic_user_tiled = _G.mosaic_user_tiled or {}
			if addr then
				_G.mosaic_explicit_floats[addr] = true
				_G.mosaic_user_tiled[addr] = nil
			end
			hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
			if _G.mosaic_enforce_float_geometry then
				_G.mosaic_enforce_float_geometry(w)
				hl.timer(function()
					if not addr or not _G.mosaic_enforce_float_geometry then
						return
					end
					local ok, live = pcall(function()
						return hl.get_window("address:" .. addr)
					end)
					if ok and live then
						_G.mosaic_enforce_float_geometry(live)
					end
				end, { timeout = 50, type = "oneshot" })
			end
			-- Poke mosaic to retile remaining tiled windows immediately
			hl.timer(function()
				if _G.mosaic_poke_workspace then
					_G.mosaic_poke_workspace(ws_id)
				elseif _G.mosaic_apply then
					_G.mosaic_apply(ws_id)
				end
			end, { timeout = 30, type = "oneshot" })
		else
			-- Floating -> Tiling. Remember this so the layout does not
			-- immediately pull a utility back out of the grid.
			_G.mosaic_user_tiled = _G.mosaic_user_tiled or {}
			if addr then
				_G.mosaic_user_tiled[addr] = true
				if _G.mosaic_explicit_floats then
					_G.mosaic_explicit_floats[addr] = nil
				end
			end
			hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
			-- Poke mosaic to retile with the newly tiled window
			hl.timer(function()
				if _G.mosaic_poke_workspace then
					_G.mosaic_poke_workspace(ws_id)
				elseif _G.mosaic_apply then
					_G.mosaic_apply(ws_id)
				end
			end, { timeout = 40, type = "oneshot" })
		end
	else
		hl.dispatch(hl.dsp.window.float({ window = w, action = "toggle" }))
	end
end

hl.unbind("SUPER + F")
hl.bind("SUPER + F", toggle_floating, { description = "Toggle floating" })
hl.unbind("SUPER + SHIFT + T")
hl.bind("SUPER + SHIFT + T", toggle_floating, { description = "Toggle floating" })
hl.unbind("SUPER + space")
hl.bind("SUPER + space", hl.dsp.exec_raw("hyprctl switchxkblayout all next"), { locked = true, description = "Switch keyboard layout" })
hl.bind("F22", hl.dsp.send_shortcut({ mods = "CTRL + SHIFT", key = "G", window = "class:^(discord)$" }), { description = "Discord start streaming" })
hl.bind("F23", hl.dsp.send_shortcut({ mods = "CTRL + SHIFT", key = "D", window = "class:^(discord)$" }), { description = "Discord toggle deafen" })
hl.bind("F24", hl.dsp.send_shortcut({ mods = "CTRL + SHIFT", key = "M", window = "class:^(discord)$" }), { description = "Discord toggle mute" })
hl.unbind("SUPER + L")
hl.bind("SUPER + L", hl.dsp.exec_cmd("dms ipc call lock lock"), { description = "Lock screen" })
hl.unbind("SUPER + ALT + L")
hl.unbind("SUPER + SHIFT + L")
hl.unbind("SUPER + CTRL + L")
hl.unbind("SUPER + SHIFT + CTRL + L")

hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("/home/soulis/.local/bin/dms-game-overlay"), { release = true, description = "Toggle Game Control Center" })

hl.unbind("SUPER + z")
hl.unbind("SUPER + Z")
local function toggle_floating()
	if _G.floating_mode_toggle then
		_G.floating_mode_toggle()
	end
end
hl.bind("SUPER + z", toggle_floating, { description = "Toggle global floating mode" })

hl.unbind("SUPER + x")
hl.unbind("SUPER + X")
local function toggle_workspace_floating()
	if _G.workspace_floating_toggle then
		_G.workspace_floating_toggle()
	end
end
hl.bind("SUPER + x", toggle_workspace_floating, { description = "Toggle workspace floating mode" })

hl.unbind("SUPER + m")
hl.unbind("SUPER + M")
local function toggle_mosaic()
	if _G.mosaic_toggle then
		_G.mosaic_toggle()
	end
end
hl.bind("SUPER + m", toggle_mosaic, { description = "Toggle workspace mosaic layout mode" })

hl.unbind("SUPER + up")
hl.unbind("SUPER + down")
hl.bind("SUPER + up", function()
	if _G.floating_mode_maximize_active then
		_G.floating_mode_maximize_active()
	end
end, { description = "Maximize window (floating mode)" })
hl.bind("SUPER + down", function()
	if _G.floating_mode_restore_active then
		_G.floating_mode_restore_active()
	end
end, { description = "Restore window size (floating mode)" })

-- Mosaic Super+RMB resize: mosaic_resize_begin dispatches window.resize()
-- so Hyprland shows the native drag cursor and grabs pointer motion for both
-- tiled and floating windows, while lua:mosaic tracks the cell splits for tiled mode.
hl.unbind("SUPER + mouse:273")
hl.bind("SUPER + mouse:273", function()
	if _G.mosaic_resize_begin then
		_G.mosaic_resize_begin()
	else
		hl.dispatch(hl.dsp.window.resize())
	end
end, { mouse = true, description = "Resize window" })
hl.bind("SUPER + mouse:273", function()
	if _G.mosaic_resize_end then
		_G.mosaic_resize_end()
	end
end, { mouse = true, release = true, description = "Resize window end" })


