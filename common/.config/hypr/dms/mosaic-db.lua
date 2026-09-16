-- Mosaic App Archetype Database
-- Categorizes desktop applications into semantic archetypes for dynamic mosaic tiling.
-- Archetypes:
--   sidebar:  narrow, tall windows (Discord, Spotify, Telegram, etc.)
--   editor:   primary focus coding/writing environments (Zed, VSCode, Neovim, etc.)
--   terminal: command-line tools (Ghostty, Alacritty, Kitty, Foot, etc.)
--   canvas:   browsers, media, creative tools (Zen, Firefox, Chrome, GIMP, etc.)
--   utility:  floating dialogs, mixers, calculators (Pavucontrol, Loupe, Blueman, etc.)

local M = {}

M.ARCHETYPES = {
	sidebar = {
		name = "sidebar",
		target_ratio = 0.26,
		min_w = 360,
		max_w = 520,
		ideal_aspect = 9 / 16,
		preferred_side = "left",
	},
	editor = {
		name = "editor",
		target_ratio = 0.58,
		min_w = 700,
		max_w = 1600,
		ideal_aspect = 16 / 10,
		preferred_side = "center",
	},
	terminal = {
		name = "terminal",
		target_ratio = 0.38,
		min_w = 480,
		max_w = 1200,
		ideal_aspect = 4 / 3,
		preferred_side = "right",
	},
	canvas = {
		name = "canvas",
		target_ratio = 0.60,
		min_w = 750,
		max_w = 2000,
		ideal_aspect = 16 / 10,
		preferred_side = "center",
	},
	utility = {
		name = "utility",
		float = true,
		center = true,
	},
}

-- Curated rules mapped to class patterns (case-insensitive lua patterns)
M.RULES = {
	-- Sidebars & Communicators
	{ pattern = "^discord$", archetype = "sidebar" },
	{ pattern = "^vesktop$", archetype = "sidebar" },
	{ pattern = "^webcord$", archetype = "sidebar" },
	{ pattern = "^armcord$", archetype = "sidebar" },
	{ pattern = "^equibop$", archetype = "sidebar" },
	{ pattern = "^spotify$", archetype = "sidebar" },
	{ pattern = "^spotify%-launcher$", archetype = "sidebar" },
	{ pattern = "^telegram%-desktop$", archetype = "sidebar" },
	{ pattern = "^telegramdesktop$", archetype = "sidebar" },
	{ pattern = "^org%.telegram%.desktop$", archetype = "sidebar" },
	{ pattern = "^slack$", archetype = "sidebar" },
	{ pattern = "^signal$", archetype = "sidebar" },
	{ pattern = "^signal%-desktop$", archetype = "sidebar" },
	{ pattern = "^element$", archetype = "sidebar" },
	{ pattern = "^element%-desktop$", archetype = "sidebar" },
	{ pattern = "^whatsapp%-for%-linux$", archetype = "sidebar" },
	{ pattern = "^cider$", archetype = "sidebar" },
	{ pattern = "^feishin$", archetype = "sidebar" },
	{ pattern = "^amberol$", archetype = "sidebar" },
	{ pattern = "^obsidian$", archetype = "editor" }, -- versatile, default editor

	-- Editors & IDEs
	{ pattern = "^dev%.zed%.zed$", archetype = "editor" },
	{ pattern = "^code$", archetype = "editor" },
	{ pattern = "^code%-oss$", archetype = "editor" },
	{ pattern = "^vscodium$", archetype = "editor" },
	{ pattern = "^cursor$", archetype = "editor" },
	{ pattern = "^cursor%-url%-handler$", archetype = "editor" },
	{ pattern = "^sublime_text$", archetype = "editor" },
	{ pattern = "^emacs$", archetype = "editor" },
	{ pattern = "^neovide$", archetype = "editor" },
	{ pattern = "^goneovim$", archetype = "editor" },
	{ pattern = "^jetbrains%-.*", archetype = "editor" },
	{ pattern = "^idea$", archetype = "editor" },
	{ pattern = "^pycharm$", archetype = "editor" },
	{ pattern = "^clion$", archetype = "editor" },
	{ pattern = "^webstorm$", archetype = "editor" },
	{ pattern = "^rider$", archetype = "editor" },
	{ pattern = "^rustrover$", archetype = "editor" },
	{ pattern = "^goland$", archetype = "editor" },
	{ pattern = "^datagrip$", archetype = "editor" },
	{ pattern = "^android%-studio.*", archetype = "editor" },
	{ pattern = "^godot.*", archetype = "editor" },

	-- Terminals
	{ pattern = "^com%.mitchellh%.ghostty$", archetype = "terminal" },
	{ pattern = "^ghostty$", archetype = "terminal" },
	{ pattern = "^alacritty$", archetype = "terminal" },
	{ pattern = "^kitty$", archetype = "terminal" },
	{ pattern = "^foot$", archetype = "terminal" },
	{ pattern = "^org%.wezfurlong%.wezterm$", archetype = "terminal" },
	{ pattern = "^wezterm$", archetype = "terminal" },
	{ pattern = "^tilix$", archetype = "terminal" },
	{ pattern = "^konsole$", archetype = "terminal" },
	{ pattern = "^gnome%-terminal.*", archetype = "terminal" },
	{ pattern = "^terminator$", archetype = "terminal" },
	{ pattern = "^xterm$", archetype = "terminal" },

	-- Browsers & Canvas
	{ pattern = "^zen$", archetype = "canvas" },
	{ pattern = "^zen%-alpha$", archetype = "canvas" },
	{ pattern = "^zen%-beta$", archetype = "canvas" },
	{ pattern = "^firefox$", archetype = "canvas" },
	{ pattern = "^firefox%-developer%-edition$", archetype = "canvas" },
	{ pattern = "^librewolf$", archetype = "canvas" },
	{ pattern = "^floorp$", archetype = "canvas" },
	{ pattern = "^google%-chrome.*", archetype = "canvas" },
	{ pattern = "^chromium.*", archetype = "canvas" },
	{ pattern = "^brave%-browser.*", archetype = "canvas" },
	{ pattern = "^microsoft%-edge.*", archetype = "canvas" },
	{ pattern = "^vivaldi.*", archetype = "canvas" },
	{ pattern = "^mpv$", archetype = "canvas" },
	{ pattern = "^vlc$", archetype = "utility" }, -- floats centered like a dialog, not stretched as canvas
	{ pattern = "^celluloid$", archetype = "canvas" },
	{ pattern = "^clapper$", archetype = "canvas" },
	{ pattern = "^gimp.*", archetype = "canvas" },
	{ pattern = "^inkscape.*", archetype = "canvas" },
	{ pattern = "^blender.*", archetype = "canvas" },
	{ pattern = "^krita.*", archetype = "canvas" },
	{ pattern = "^darktable$", archetype = "canvas" },
	{ pattern = "^libreoffice.*", archetype = "canvas" },
	{ pattern = "^soffice%.bin$", archetype = "canvas" },
	{ pattern = "^virt%-manager$", archetype = "canvas" },

	-- File managers: transient tasks, float centered at their natural size
	-- instead of tiling as canvas (fullscreen alone, ~67% next to a terminal).
	-- Mirrors the `float = true` philosophy Nautilus already has in hyprland.lua.
	{ pattern = "^dolphin$", archetype = "utility" },
	{ pattern = "^org%.kde%.dolphin$", archetype = "utility" },
	{ pattern = "^nautilus$", archetype = "utility" },
	{ pattern = "^org%.gnome%.nautilus$", archetype = "utility" },
	{ pattern = "^thunar$", archetype = "utility" },
	{ pattern = "^nemo$", archetype = "utility" },
	{ pattern = "^caja$", archetype = "utility" },
	{ pattern = "^pcmanfm.*", archetype = "utility" },
	{ pattern = "^krusader$", archetype = "utility" },
	{ pattern = "^konqueror$", archetype = "utility" },

	-- Utilities / Modals (Ignored by Mosaic, float freely)
	{ pattern = "^pavucontrol$", archetype = "utility" },
	{ pattern = "^org%.pulseaudio%.pavucontrol$", archetype = "utility" },
	{ pattern = "^blueman%-manager$", archetype = "utility" },
	{ pattern = "^nm%-connection%-editor$", archetype = "utility" },
	{ pattern = "^org%.gnome%.calculator$", archetype = "utility" },
	{ pattern = "^gnome%-calculator$", archetype = "utility" },
	{ pattern = "^galculator$", archetype = "utility" },
	{ pattern = "^kcalc$", archetype = "utility" },
	{ pattern = "^org%.gnome%.loupe$", archetype = "utility" },
	{ pattern = "^loupe$", archetype = "utility" },
	{ pattern = "^imv$", archetype = "utility" },
	{ pattern = "^feh$", archetype = "utility" },
	{ pattern = "^xdg%-desktop%-portal.*", archetype = "utility" },
	{ pattern = "^polkit.*", archetype = "utility" },
	{ pattern = "^bitwarden$", archetype = "utility" },
	{ pattern = "^1password$", archetype = "utility" },
	{ pattern = "^keepassxc$", archetype = "utility" },
	{ pattern = "^localsend.*", archetype = "utility" },
	{ pattern = "^org%.localsend%.localsend_app$", archetype = "utility" },
	{ pattern = "^com%.danklinux%.dms$", archetype = "utility" },
}

-- Resolve archetype for a given window
function M.classify(win)
	if not win then
		return M.ARCHETYPES.canvas
	end

	local cls = (win.class or win.initial_class or win.initialClass or ""):lower()
	local title = (win.title or ""):lower()

	-- 1. Check curated rules
	for _, rule in ipairs(M.RULES) do
		if cls:match(rule.pattern) then
			return M.ARCHETYPES[rule.archetype] or M.ARCHETYPES.canvas
		end
	end

	-- 2. Heuristics based on name keywords
	if cls:match("term") or cls:match("console") or title:match("terminal") then
		return M.ARCHETYPES.terminal
	end
	if cls:match("edit") or cls:match("code") or cls:match("ide") then
		return M.ARCHETYPES.editor
	end
	if cls:match("chat") or cls:match("music") or cls:match("player") or cls:match("calc") then
		return M.ARCHETYPES.sidebar
	end
	if cls:match("browser") or cls:match("view") or cls:match("player") then
		return M.ARCHETYPES.canvas
	end

	-- 3. Geometry heuristic: if window's initial aspect is strongly vertical
	if win.size and win.size.y > 0 and (win.size.x / win.size.y) < 0.75 then
		return M.ARCHETYPES.sidebar
	end

	-- Default fallback
	return M.ARCHETYPES.canvas
end

return M
