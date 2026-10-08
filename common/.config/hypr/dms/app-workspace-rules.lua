-- Workspace and map-focus rules that DankMaterialShell 1.6 cannot store.
-- DMS windowrules.lua is rewritten from its rule store, which only has
-- `nofocus` → `no_focus` (window never focusable). These apps need
-- `no_initial_focus` so they land on a silent workspace without stealing
-- the current one, then still accept clicks and keys.

-- Steam client on 8 (silent so it does not steal the active workspace)
hl.window_rule({
	match = { class = "^(steam)$" },
	workspace = "8 silent",
	no_initial_focus = true,
})

-- Unreal Engine on 7
hl.window_rule({
	match = { class = "^([uU]nreal.*)$" },
	workspace = "7 silent",
	no_initial_focus = true,
})

-- Godot on 4
hl.window_rule({
	match = { class = "^([gG]odot.*)$" },
	workspace = "4 silent",
	no_initial_focus = true,
})

hl.window_rule({
	match = { title = "^(Reflex Saloon Demo.*)$" },
	workspace = "4 silent",
	no_initial_focus = true,
})

-- Games on workspace 9. Map-time workspace/monitor pins do not stick
-- if the client later fullscreen-outputs onto another monitor.
hl.window_rule({
	match = { class = "^(steam_app_.*|.*\\.exe.*)$" },
	immediate = true,
	workspace = "9",
	suppress_event = "fullscreenoutput",
})
