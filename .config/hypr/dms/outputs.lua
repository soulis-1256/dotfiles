-- Per-output monitor rules. Deploy writes ~/.config/hypr/dms/outputs.lua
--
-- Physical cabinets sit bottom-aligned:
--   Left  DP-2  AOC 24G2W1G3   1920x1080, transform 1 (portrait)
--   Right DP-1  ASUS XG27ACS   2560x1440, landscape
--
-- Portrait "bottom" is the monitor's landscape-right side (~6 mm side bezel).
-- Landscape bottom is the ASUS chin (~20 mm, ROG logo + G-SYNC badge).
-- So the ASUS panel sits 14 mm higher than the AOC panel.
--
-- AOC portrait: 1920 px / 527.04 mm = 3.643 px/mm
-- 14 mm × 3.643 ≈ 51 px  →  ASUS bottom is 51 px above AOC bottom.
-- AOC at y=0 (bottom 1920); ASUS y = 1920 - 51 - 1440 = 429.

hl.monitor({
	output = "DP-2",
	mode = "1920x1080@165.003",
	position = "0x0",
	scale = 1,
	transform = 1,
	vrr = 0,
})
hl.monitor({
	output = "DP-1",
	mode = "2560x1440@179.999",
	position = "1080x429",
	scale = 1,
	vrr = 1,
})

-- Default fallback
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
