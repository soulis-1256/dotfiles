-- Laptop-Specific Hyprland Overrides
-- Loaded automatically when stowed from the 'laptop' package.

-- Picture-in-Picture on Laptop (centered, clean 16:9 size on 1366x768 screen)
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	float = true,
	pin = true,
	size = "640 360",
	center = true,
})
