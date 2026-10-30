-- Hyprbars blacklist and helpers. Kept out of windowrules.lua because DMS 1.6
-- rewrites that file from its window-rules store and would drop these.

-- Electron reports Discord as fully opaque and sets no_blur, so Hyprland
-- skips compositor frost even with Vencord transparency. The window rule
-- is not enough; set_prop on open is what actually clears those flags.
-- 0.85 opacity matches Ghostty and the title bars.
-- Needs decoration.blur.enabled (Win11 theme).
hl.window_rule({
	match = { class = "^(discord)$" },
	opaque = false,
	no_blur = false,
	opacity = "0.85 override 0.85 override",
})

local function frost_discord(w)
	if not w or w.class ~= "discord" then
		return
	end
	local function apply()
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "opaque", value = 0 }))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "no_blur", value = 0 }))
		hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "opacity", value = 0.85 }))
	end
	apply()
	hl.timer(apply, { timeout = 250, type = "oneshot" })
end

hl.on("window.open", frost_discord)

-- hyprbars blacklist: single source of truth for apps without top bars
_G.hyprbars_blacklist = {
	classes = {
		-- Dux Labs and Dank apps (native CSD headerbars)
		"dev\\.duxlabs\\..*",
		"com\\.danklinux\\..*",
		"dfiles",
		"dux-.*",
		"dms",
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
