-- Default Theme for Hyprland
-- Mirrors the user's custom base configuration: 12px rounding, 5px gaps, 2px borders, deep shadows

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 5,
		border_size = 2,
		col = {
			inactive_border = "rgba(00000000)",
		},
	},
	decoration = {
		rounding = 12,
		shadow = {
			enabled = true,
			range = 30,
			render_power = 5,
			offset = "0 5",
			color = "rgba(00000070)",
		},
	},
})

-- Default animations
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "default" })
