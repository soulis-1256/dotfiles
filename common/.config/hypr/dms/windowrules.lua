-- Window rules. Deploy writes ~/.config/hypr/dms/windowrules.lua
-- Extra rules from the previous hyprland.conf (stock DMS rules stay in hyprland.lua).

-- Float Steam dialogs and tile the main client
hl.window_rule({ match = { class = "^(steam)$" }, float = true })
hl.window_rule({
	match = { class = "^(steam)$", title = "^(Steam)$" },
	tile = true,
})
-- Steam client on 8 (silent so it does not steal the active workspace)
hl.window_rule({
	match = { class = "^(steam)$" },
	workspace = "8 silent",
	no_initial_focus = true,
})
-- Remove borders and disable blur/shadow effects on Steam
hl.window_rule({
	match = { class = "^([sS]team.*)$" },
	border_size = 0,
	no_blur = true,
	no_shadow = true,
})

-- Games on workspace 9. Map-time workspace/monitor pins do not stick
-- if the client later fullscreen-outputs onto another monitor.
hl.window_rule({
	match = { class = "^(steam_app_.*|.*\\.exe.*)$" },
	immediate = true,
	workspace = "9",
	suppress_event = "fullscreenoutput",
})

-- Picture-in-Picture from any toolkit (float and pin across workspaces)
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	float = true,
	pin = true,
})

-- DMS Settings: float at the current size, centered on the focused monitor
hl.window_rule({
	match = { class = "^(com\\.danklinux\\.dms)$", title = "^(Settings)$" },
	float = true,
	center = true,
	size = {1535, 994},
})

-- Loupe Image Viewer: float at fixed dimensions, centered (matching DMS Settings)
hl.window_rule({
	match = { class = "^(org\\.gnome\\.Loupe)$" },
	float = true,
	center = true,
	size = {1535, 994},
})

-- Win11-style floats: hovering them does not steal mouse/keyboard focus
hl.window_rule({ match = { float = true }, no_follow_mouse = true })

-- Electron reports Discord as fully opaque and sets no_blur, so Hyprland
-- skips compositor frost even with Vencord transparency. The window rule
-- is not enough; set_prop on open is what actually clears those flags.
-- 0.99 opacity is the usual Electron alpha hack (not a visible fade).
-- Needs decoration.blur.enabled (Win11 theme).
hl.window_rule({
	match = { class = "^(discord)$" },
	opaque = false,
	no_blur = false,
	opacity = "0.99 override 0.99 override",
})

-- Electron advertises the window as fully opaque after map, which overrides
-- the window_rule above. set_prop after open is what actually enables frost.
local function frost_discord(w)
	if not w or w.class ~= "discord" then
		return
	end
	local function apply()
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "opaque", value = 0 }))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "no_blur", value = 0 }))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "opacity", value = 0.99 }))
	end
	apply()
	hl.timer(apply, { timeout = 250, type = "oneshot" })
end

hl.on("window.open", frost_discord)

-- hyprbars blacklist: suppress top bars on apps that already have their own bars
hl.window_rule({
	match = { class = "^(discord|zen|zen-alpha|chromium|google-chrome)$" },
	["hyprbars:no_bar"] = true,
})
hl.window_rule({
	match = { class = "^(com\\.danklinux\\.dms)$" },
	["hyprbars:no_bar"] = true,
})
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	["hyprbars:no_bar"] = true,
})
hl.window_rule({
	match = { class = "^(steam_app_.*|.*\\.exe.*)$" },
	["hyprbars:no_bar"] = true,
})
hl.window_rule({
	match = { class = "^([sS]team.*)$", title = "^(notificationtoasts.*)$" },
	["hyprbars:no_bar"] = true,
})
