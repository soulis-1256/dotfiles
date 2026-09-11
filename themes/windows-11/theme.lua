-- Windows 11 Theme for Hyprland
-- 8px rounding, mica-style blur, soft shadows.
-- Outer gaps apply only with 2+ tiled windows (hyprland.lua zeros them for a single window).

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 4,
		border_size = 1,
		col = {
			inactive_border = "rgb(2c2c2c)",
		},
	},
	decoration = {
		rounding = 8,
		blur = {
			enabled = true,
			size = 5,
			passes = 2,
			vibrancy = 0.15,
		},
		shadow = {
			enabled = true,
			range = 20,
			render_power = 3,
			offset = "0 4",
			color = "rgba(00000055)",
		},
	},
})

-- Soft, slightly slower than Win10 — closer to Fluent motion
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.4, bezier = "default" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.4, bezier = "default" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.4, bezier = "default" })

if _G.setup_hyprbars_buttons then
	_G.setup_hyprbars_buttons("windows-11")
end
