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
	border_size = 0,
	rounding = 0,
	opaque = true,
	opacity = "1.0 1.0",
	no_blur = true,
	no_shadow = true,
	no_dim = true,
})

-- 3. Slightly fade unfocused tiled windows on desktop
hl.window_rule({
	match = { float = false, focus = false },
	opacity = "0.9 0.9",
})

-- 4. Picture-in-Picture on Desktop (send to secondary portrait monitor DP-2 on Workspace 10, bottom position)
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	float = true,
	pin = true,
	move = "66 1247",
	workspace = "10",
})

