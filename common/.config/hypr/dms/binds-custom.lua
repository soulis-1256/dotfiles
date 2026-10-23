-- Custom keybinds with Lua closures / helpers protected from DMS Settings UI serialization
-- (DMS rewrites dms/binds-user.lua from its shortcut store, which cannot serialize Lua functions)

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
	pcall(function()
		hl.dispatch(hl.dsp.focus({ window = w }))
		hl.dispatch(hl.dsp.window.bring_to_top({ window = w }))
		hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
	end)
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
	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
end

hl.unbind("SUPER + F")
hl.bind("SUPER + F", toggle_floating, { description = "Toggle floating" })

hl.unbind("SUPER + SHIFT + T")
hl.bind("SUPER + SHIFT + T", toggle_floating, { description = "Toggle floating" })

-- Discord shortcuts
hl.bind("F22", hl.dsp.send_shortcut({ mods = "CTRL + SHIFT", key = "G", window = "class:^(discord)$" }), { description = "Discord start streaming" })
hl.bind("F23", hl.dsp.send_shortcut({ mods = "CTRL + SHIFT", key = "D", window = "class:^(discord)$" }), { description = "Discord toggle deafen" })
hl.bind("F24", hl.dsp.send_shortcut({ mods = "CTRL + SHIFT", key = "M", window = "class:^(discord)$" }), { description = "Discord toggle mute" })
