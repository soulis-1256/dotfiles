-- Window rules. Deploy writes ~/.config/hypr/dms/windowrules.lua
-- Extra rules from the previous hyprland.conf (stock DMS rules stay in hyprland.lua).

-- Float Steam's main windows and maximize the main client
hl.window_rule({ match = { class = "^(steam)$" }, float = true })
hl.window_rule({
	match = { class = "^(steam)$", title = "^(Steam)$" },
	maximize = true,
})
-- Remove borders and disable blur/shadow effects on Steam
hl.window_rule({
	match = { class = "^([sS]team.*)$" },
	border_size = 0,
	no_blur = true,
	no_shadow = true,
})

-- Allow immediate presentation (tearing / direct scanout) for all games
hl.window_rule({ match = { class = "^(steam_app_.*|.*\\.exe.*)$" }, immediate = true })

-- Automatically launch all games on dedicated gaming Workspace 9
hl.window_rule({
	match = { class = "^(steam_app_.*|.*\\.exe.*)$" },
	workspace = "9",
})

-- Picture-in-Picture from any toolkit (float and pin across workspaces)
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	float = true,
	pin = true,
})

-- Win11-style floats: hovering them does not steal mouse/keyboard focus
hl.window_rule({ match = { float = true }, no_follow_mouse = true })
