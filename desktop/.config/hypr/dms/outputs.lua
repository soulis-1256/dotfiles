-- Desktop Monitor & Workspace Configuration
-- Physical cabinets sit bottom-aligned:
--   Left  DP-2  AOC 24G2W1G3   1920x1080, transform 1 (portrait)
--   Right DP-1  ASUS XG27ACS   2560x1440, landscape

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

-- Fallback for unconfigured monitors
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Workspace Bindings
for i = 1, 9 do
	hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1" })
end
hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
hl.workspace_rule({ workspace = "10", monitor = "DP-2", default = true, persistent = true, gaps_in = 0, gaps_out = 0 })
