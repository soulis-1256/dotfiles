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
hl.bind("SUPER + grave", hl.dsp.exec_cmd("ghostty"), { description = "Terminal (ghostty)" })
hl.unbind("SUPER + asciitilde")
hl.bind("SUPER + asciitilde", hl.dsp.exec_cmd("ghostty"), { description = "Terminal (ghostty)" })
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
hl.unbind("SUPER + F")
hl.bind("SUPER + F", function()
	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
	local function sync()
		if _G.sync_workspace_floating_from_windows then
			_G.sync_workspace_floating_from_windows()
		end
	end
	sync()
	hl.timer(sync, { timeout = 50, type = "oneshot" })
end, { description = "Toggle floating" })
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


