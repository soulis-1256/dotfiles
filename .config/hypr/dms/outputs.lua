-- Dynamic Monitor & Host Configuration Loader
-- Automatically loads host-specific geometry or falls back to chassis detection.

local function trim(s)
	return s and s:match("^%s*(.-)%s*$") or ""
end

local function get_hostname()
	local handle = io.popen("uname -n 2>/dev/null")
	if handle then
		local result = handle:read("*l")
		handle:close()
		return trim(result)
	end
	return ""
end

local function is_laptop()
	-- Check 1: Chassis type via hostnamectl
	local handle = io.popen("hostnamectl chassis 2>/dev/null")
	if handle then
		local chassis = trim(handle:read("*l"))
		handle:close()
		if chassis == "laptop" or chassis == "convertible" or chassis == "handheld" or chassis == "notebook" then
			return true
		end
	end
	-- Check 2: Check for internal eDP panel
	if os.execute("test -d /sys/class/drm/*-eDP-1 -o -d /sys/class/drm/*-eDP-2 2>/dev/null") == 0 then
		return true
	end
	-- Check 3: Battery existence
	if os.execute("test -d /sys/class/power_supply/BAT0 -o -d /sys/class/power_supply/BAT1 2>/dev/null") == 0 then
		return true
	end
	return false
end

local hostname = get_hostname()
local loaded = false

-- 1. Try hostname-specific host file (e.g. hosts/soulis-cachyos.lua)
if hostname ~= "" then
	loaded = pcall(require, "hosts." .. hostname)
end

-- 2. Fallback to chassis-based profiles if no exact hostname match
if not loaded then
	if is_laptop() then
		loaded = pcall(require, "hosts.laptop")
		if not loaded then
			hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.0 })
			hl.config({ gestures = { workspace_swipe = true, workspace_swipe_fingers = 3 } })
		end
	else
		-- Generic multi/single-monitor desktop fallback
		hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
	end
end
