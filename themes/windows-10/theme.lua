-- Windows 10 Theme for Hyprland
-- Sharp corners, electric blue accent, no gaps, snappy window animations

hl.config({
	general = {
		gaps_in = 0,
		gaps_out = 0,
		border_size = 2,
		col = {
			inactive_border = "rgb(2b2b2b)",
		},
	},
	decoration = {
		rounding = 0,
		blur = {
			enabled = false,
		},
		shadow = {
			enabled = true,
			range = 16,
			render_power = 2,
			offset = "0 2",
			color = "rgba(00000060)",
		},
	},
})

-- Snappy, crisp window animations reminiscent of Windows 10
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "default" })

if _G.setup_hyprbars_buttons then
	_G.setup_hyprbars_buttons("windows-10")
end
