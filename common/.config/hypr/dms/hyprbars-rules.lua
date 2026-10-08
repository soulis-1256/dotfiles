-- Hyprbars blacklist and helpers. Kept out of windowrules.lua because DMS 1.6
-- rewrites that file from its window-rules store and would drop these.

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
		"brave-browser",
		"[lL]ocal[sS]end",
		"org\\.localsend\\.localsend_app",
		-- Loupe is GTK4/adwaita with its own CSD headerbar
		"org\\.gnome\\.Loupe",
		"[sS]team.*",
		"com\\.danklinux\\.dms",
		"steam_app_.*",
		".*\\.exe.*",
		"[uU]nreal.*",
	},
	titles = {
		".*[Pp]icture[- ][iI]n[- ][pP]icture.*",
	},
}

-- Register hyprbars:no_bar window rules dynamically with +nobar tag
pcall(function()
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
end)

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
