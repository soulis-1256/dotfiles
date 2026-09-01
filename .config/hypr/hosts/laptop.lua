-- Host Profile: Laptop (Generic / Portable)
-- Automatically loaded when running on any laptop device

-- Display output: auto-configured single panel
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "0x0",
	scale = 1.0, -- Set to 1.25 or 1.5 if on high-DPI (e.g. 14" 1440p/4K)
	vrr = 0,
})

-- Fallback for second screen / HDMI plugged in
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- Touchpad Gestures
hl.config({
	gestures = {
		workspace_swipe = true,
		workspace_swipe_fingers = 3,
		workspace_swipe_distance = 300,
	},
})

-- Hardware Brightness Controls
hl.bind({ keys = { "", "XF86MonBrightnessUp" }, exec = "brightnessctl set +5%" })
hl.bind({ keys = { "", "XF86MonBrightnessDown" }, exec = "brightnessctl set 5%-" })

-- Lid Close Event (Lock screen)
hl.bindl({ keys = { "", "switch:on:Lid Switch" }, exec = "hyprlock" })
