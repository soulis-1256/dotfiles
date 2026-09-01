-- Window rules. Deploy writes ~/.config/hypr/dms/windowrules.lua
-- Extra rules from the previous hyprland.conf (stock DMS rules stay in hyprland.lua).

-- Float Steam's main windows (toast popups are handled in hyprland.lua)
hl.window_rule({ match = { class = "^(steam)$" }, float = true })

-- Allow immediate presentation (tearing / direct scanout) for all games
hl.window_rule({ match = { class = "^(steam_app_.*|cs2|.*\\.exe.*|ACBlackFlag.*)$" }, immediate = true })

-- Automatically launch all games on dedicated gaming Workspace 9
hl.window_rule({ match = { class = "^(steam_app_.*|cs2|.*\\.exe.*|ACBlackFlag.*)$" }, workspace = "9" })

-- Picture-in-Picture from any toolkit (float and pin across workspaces)
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	float = true,
	pin = true,
})

-- Win11-style floats: hovering them does not steal mouse/keyboard focus
hl.window_rule({ match = { float = true }, no_follow_mouse = true })
