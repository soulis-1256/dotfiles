-- Window rules. Deploy writes ~/.config/hypr/dms/windowrules.lua
-- Extra rules from the previous hyprland.conf (stock DMS rules stay in hyprland.lua).

-- Float Steam's main windows (toast popups are handled in hyprland.lua)
hl.window_rule({ match = { class = "^(steam)$" }, float = true })

-- Allow immediate presentation (tearing / direct scanout) for all games
hl.window_rule({ match = { class = "^(steam_app_.*|cs2|.*\\.exe.*|ACBlackFlag.*)$" }, immediate = true })

-- Automatically launch all games on dedicated gaming Workspace 9
hl.window_rule({ match = { class = "^(steam_app_.*|cs2|.*\\.exe.*|ACBlackFlag.*)$" }, workspace = "9" })


-- Send Vesktop to workspace 10 silently without stealing focus (secondary monitor DP-2)
hl.window_rule({
	match = { class = "^(vesktop)$" },
	workspace = "10 silent",
	no_initial_focus = true,
	border_size = 0,
	rounding = 0,
	opaque = true,
	opacity = "1.0 1.0",
	no_blur = true,
	no_shadow = true,
	no_dim = true,
})

-- Picture-in-Picture from any toolkit (float, pin across all workspaces, send to secondary monitor DP-2, position at bottom)
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	float = true,
	pin = true,
	move = "66 1247",
	workspace = "10",
})

-- Slightly fade unfocused tiled windows
hl.window_rule({
	match = { float = false, focus = false },
	opacity = "0.9 0.9",
})

-- Do not change border_size on focus: that resizes the window. Inactive
-- borders stay 2px and transparent (see hyprland.lua col.inactive_border).

-- Win11-style floats: hovering them does not steal mouse/keyboard focus
hl.window_rule({ match = { float = true }, no_follow_mouse = true })
