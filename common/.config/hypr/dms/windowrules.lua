-- Window rules. Deploy writes ~/.config/hypr/dms/windowrules.lua
-- Extra rules from the previous hyprland.conf (stock DMS rules stay in hyprland.lua).

-- Float Steam dialogs and tile the main client
hl.window_rule({ match = { class = "^(steam)$" }, float = true })
hl.window_rule({
	match = { class = "^(steam)$", title = "^(Steam)$" },
	tile = true,
})
-- Steam client on 8 (silent so it does not steal the active workspace)
hl.window_rule({
	match = { class = "^(steam)$" },
	workspace = "8 silent",
	no_initial_focus = true,
})
-- Remove borders and disable blur/shadow effects on Steam
hl.window_rule({
	match = { class = "^([sS]team.*)$" },
	border_size = 0,
	no_blur = true,
	no_shadow = true,
})

-- Games on workspace 9. Map-time workspace/monitor pins do not stick
-- if the client later fullscreen-outputs onto another monitor.
hl.window_rule({
	match = { class = "^(steam_app_.*|.*\\.exe.*)$" },
	immediate = true,
	workspace = "9",
	suppress_event = "fullscreenoutput",
})

-- Picture-in-Picture from any toolkit (float and pin across workspaces)
hl.window_rule({
	match = { title = ".*[Pp]icture[- ][iI]n[- ][pP]icture.*" },
	float = true,
	pin = true,
})

-- DMS Settings: float at the current size, centered on the focused monitor
hl.window_rule({
	match = { class = "^(com\\.danklinux\\.dms)$", title = "^(Settings)$" },
	float = true,
	center = true,
	size = {1535, 994},
})

-- Loupe Image Viewer: float at fixed dimensions, centered (matching DMS Settings)
hl.window_rule({
	match = { class = "^(org\\.gnome\\.Loupe)$" },
	float = true,
	center = true,
	size = {1535, 994},
})

-- Win11-style floats: hovering them does not steal mouse/keyboard focus
hl.window_rule({ match = { float = true }, no_follow_mouse = true })

-- Electron reports Discord as fully opaque and sets no_blur, so Hyprland
-- skips compositor frost even with Vencord transparency. The window rule
-- is not enough; set_prop on open is what actually clears those flags.
-- 0.99 opacity is the usual Electron alpha hack (not a visible fade).
-- Needs decoration.blur.enabled (Win11 theme).
hl.window_rule({
	match = { class = "^(discord)$" },
	opaque = false,
	no_blur = false,
	opacity = "0.99 override 0.99 override",
})

-- Electron advertises the window as fully opaque after map, which overrides
-- the window_rule above. set_prop after open is what actually enables frost.
local function frost_discord(w)
	if not w or w.class ~= "discord" then
		return
	end
	local function apply()
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "opaque", value = 0 }))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "no_blur", value = 0 }))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "opacity", value = 0.99 }))
	end
	apply()
	hl.timer(apply, { timeout = 250, type = "oneshot" })
end

hl.on("window.open", frost_discord)

-- hyprbars blacklist: single source of truth for apps without top bars
_G.hyprbars_blacklist = {
	classes = {
		"discord",
		"zen",
		"zen-alpha",
		"chromium",
		"google-chrome",
		"[lL]ocal[sS]end",
		"org\\.localsend\\.localsend_app",
		"com\\.danklinux\\.dms",
		"steam_app_.*",
		".*\\.exe.*",
	},
	titles = {
		".*[Pp]icture[- ][iI]n[- ][pP]icture.*",
	},
}

-- Register hyprbars:no_bar window rules dynamically with +nobar tag
hl.window_rule({
	match = { class = "^(" .. table.concat(_G.hyprbars_blacklist.classes, "|") .. ")$" },
	["hyprbars:no_bar"] = true,
	tag = "+nobar",
})

for _, t_pat in ipairs(_G.hyprbars_blacklist.titles) do
	hl.window_rule({
		match = { title = t_pat },
		["hyprbars:no_bar"] = true,
		tag = "+nobar",
	})
end

hl.window_rule({
	match = { class = "^([sS]team.*)$", title = "^(notificationtoasts.*)$" },
	["hyprbars:no_bar"] = true,
	tag = "+nobar",
})

-- Centralized helper used by maximize and snap geometry calculations
_G.window_has_hyprbar = function(w)
	if not w then
		return true
	end
	local cls = (w.class or ""):lower()
	local title = (w.title or ""):lower()

	if title:match("picture[%- ]in[%- ]picture") then
		return false
	end
	if cls:match("^steam") and title:match("^notificationtoasts") then
		return false
	end

	for _, item in ipairs((_G.hyprbars_blacklist and _G.hyprbars_blacklist.classes) or {}) do
		local pat = item:lower():gsub("%\\%.", "%%."):gsub("%[%w+%]", function(m)
			return m:sub(2, 2):lower()
		end)
		if cls == pat or cls:match("^" .. pat .. "$") or cls:match(pat) then
			return false
		end
	end

	return true
end
