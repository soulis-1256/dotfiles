-- Desktop-Specific Hyprland Overrides
-- Loaded automatically when stowed from the 'desktop' package.

-- 1. Autostart Zen Browser on Workspace 1
hl.on("hyprland.start", function()
	hl.exec_cmd("[workspace 1] zen-browser")
	hl.dispatch(hl.dsp.focus({ workspace = "1" }))
end)

-- 2. Send Vesktop to Workspace 10 on the secondary portrait monitor
hl.window_rule({
	match = { class = "^(vesktop)$" },
	workspace = "10 silent",
	no_initial_focus = true,
	opaque = true,
	opacity = "1.0 1.0",
	no_blur = true,
	no_shadow = true,
	no_dim = true,
})

-- 3. Picture-in-Picture on Desktop (send to secondary portrait monitor DP-2 on Workspace 10, bottom position)
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	float = true,
	pin = true,
	size = "965 543",
	move = "66 1247",
	workspace = "10",
})

-- 4. Pin all games to primary monitor DP-1 on Desktop
hl.window_rule({
	match = { class = "^(steam_app_.*|.*\\.exe.*)$" },
	monitor = "DP-1",
})

-- 5. Pin DMS Settings to primary monitor DP-1 on Desktop
hl.window_rule({
	match = { class = "^(com\\.danklinux\\.dms)$", title = "^(Settings)$" },
	monitor = "DP-1",
})

-- 6. Pin Loupe Image Viewer to primary monitor DP-1 on Desktop
hl.window_rule({
	match = { class = "^(org\\.gnome\\.Loupe)$" },
	monitor = "DP-1",
})



