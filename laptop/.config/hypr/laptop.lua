-- Laptop-Specific Hyprland Overrides
-- Loaded automatically when stowed from the 'laptop' package.

-- Picture-in-Picture on Laptop (centered, aspect-matched within 640x360 bounds)
-- Size and centering are applied proportionally on window.open by fit_pip_window() in hyprland.lua.
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	float = true,
	pin = true,
})

_G.pip_layout = {
	max_w = 640,
	max_h = 360,
	center = true,
}
