-- Unified Workspace Layout Manager for Hyprland & DMS
-- Single source of truth for workspace layout modes: "mosaic" | "floating" | "tiled"
-- Default mode across reboots and new workspaces: "mosaic"

local M = {}

local floating = require("dms.floating-mode")
local mosaic = require("dms.mosaic")

local LOG_FILE = "/tmp/layout_manager.log"
local function log(msg)
	local f = io.open(LOG_FILE, "a")
	if f then
		f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
		f:close()
	end
end
M.log = log

local HOME = os.getenv("HOME") or ""
local CACHE_DIR = HOME .. "/.cache"

local STATE_FILE = CACHE_DIR .. "/hypr_layout_state.json"
local LEGACY_MOSAIC_WS = CACHE_DIR .. "/hypr_mosaic_workspaces.json"
local LEGACY_FLOAT_WS = CACHE_DIR .. "/hypr_floating_workspaces.json"

_G.layout_manager_epoch = (_G.layout_manager_epoch or 0) + 1
local EPOCH = _G.layout_manager_epoch
local function from_this_load()
	return _G.layout_manager_epoch == EPOCH
end

_G.layout_state = _G.layout_state or {
	default = "mosaic",
	workspaces = {},
}

local function safe_write(path, content)
	local f = io.open(path, "w")
	if f then
		f:write(content)
		f:close()
		return true
	end
	return false
end

local function save_state()
	local parts = {}
	for id, mode in pairs(_G.layout_state.workspaces or {}) do
		table.insert(parts, string.format("%q: %q", tostring(id), tostring(mode)))
	end
	table.sort(parts)
	local json = string.format('{"default": %q, "workspaces": {%s}}\n',
		_G.layout_state.default or "mosaic",
		table.concat(parts, ", "))
	safe_write(STATE_FILE, json)
end

local function load_state()
	local f = io.open(STATE_FILE, "r")
	if f then
		local content = f:read("*a") or ""
		f:close()
		local def = content:match('"default"%s*:%s*"([^"]+)"')
		if def then
			_G.layout_state.default = def
		else
			_G.layout_state.default = "mosaic"
		end
		local ws_block = content:match('"workspaces"%s*:%s*%{(.-)%}')
		if ws_block then
			for id, val in ws_block:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do
				local num_id = tonumber(id)
				_G.layout_state.workspaces[num_id or id] = val
			end
		end
		log("Loaded state from " .. STATE_FILE .. ", default=" .. tostring(_G.layout_state.default))
		return
	end

	-- Migration from legacy cache files if STATE_FILE does not exist
	log("Migrating state from legacy cache files...")
	_G.layout_state.default = "mosaic"
	_G.layout_state.workspaces = {}

	local fm = io.open(LEGACY_MOSAIC_WS, "r")
	if fm then
		local c = fm:read("*a") or ""
		fm:close()
		local ws_block = c:match('"workspaces"%s*:%s*%{(.-)%}')
		if ws_block then
			for id, val in ws_block:gmatch('"([^"]+)"%s*:%s*(%a+)') do
				if val == "true" then
					local num_id = tonumber(id)
					_G.layout_state.workspaces[num_id or id] = "mosaic"
				end
			end
		end
	end

	local ff = io.open(LEGACY_FLOAT_WS, "r")
	if ff then
		local c = ff:read("*a") or ""
		ff:close()
		local ws_block = c:match('"workspaces"%s*:%s*%{(.-)%}')
		if ws_block then
			for id, val in ws_block:gmatch('"([^"]+)"%s*:%s*(%a+)') do
				if val == "true" then
					local num_id = tonumber(id)
					_G.layout_state.workspaces[num_id or id] = "floating"
				end
			end
		end
	end

	save_state()
end

load_state()

function M.get_mode(ws_id)
	local id = ws_id
	if not id then
		local ws = hl.get_active_workspace and hl.get_active_workspace()
		id = ws and ws.id
	end
	if not id then
		return _G.layout_state.default or "mosaic"
	end
	local num_id = tonumber(id)
	if num_id and _G.layout_state.workspaces[num_id] ~= nil then
		return _G.layout_state.workspaces[num_id]
	elseif _G.layout_state.workspaces[id] ~= nil then
		return _G.layout_state.workspaces[id]
	elseif _G.layout_state.workspaces[tostring(id)] ~= nil then
		return _G.layout_state.workspaces[tostring(id)]
	end
	return _G.layout_state.default or "mosaic"
end

function M.any_floating()
	if (_G.layout_state.default or "mosaic") == "floating" then
		return true
	end
	for _, m in pairs(_G.layout_state.workspaces or {}) do
		if m == "floating" then
			return true
		end
	end
	return false
end

function M.sync_indicators(ws_id)
	local id = ws_id
	if not id then
		local ws = hl.get_active_workspace and hl.get_active_workspace()
		id = ws and ws.id
	end
	local active_mode = M.get_mode(id)
	local is_float = (active_mode == "floating")
	local is_mosaic = (active_mode == "mosaic")

	-- Live layout mode indicator for QuickShell / DMS
	safe_write("/tmp/hypr_layout_mode", active_mode .. "\n")
	safe_write(CACHE_DIR .. "/hypr_layout_mode", active_mode .. "\n")

	-- Floating mode indicators
	safe_write("/tmp/hypr_floating_mode", (is_float and "1\n" or "0\n"))
	safe_write(CACHE_DIR .. "/hypr_floating_mode", (is_float and "1\n" or "0\n"))

	-- Mosaic mode indicators
	safe_write("/tmp/hypr_mosaic_mode", (is_mosaic and "1\n" or "0\n"))
	safe_write(CACHE_DIR .. "/hypr_mosaic_mode", (is_mosaic and "1\n" or "0\n"))

	-- Backward compatible workspace json files
	local float_parts = {}
	local mosaic_parts = {}
	for wid, m in pairs(_G.layout_state.workspaces or {}) do
		table.insert(float_parts, string.format("%q: %s", tostring(wid), (m == "floating") and "true" or "false"))
		table.insert(mosaic_parts, string.format("%q: %s", tostring(wid), (m == "mosaic") and "true" or "false"))
	end
	table.sort(float_parts)
	table.sort(mosaic_parts)

	local float_json = string.format('{"active": %s, "workspaces": {%s}}\n',
		is_float and "true" or "false", table.concat(float_parts, ", "))
	safe_write("/tmp/hypr_floating_workspaces.json", float_json)
	safe_write(CACHE_DIR .. "/hypr_floating_workspaces.json", float_json)

	local mosaic_json = string.format('{"active": %s, "workspaces": {%s}}\n',
		is_mosaic and "true" or "false", table.concat(mosaic_parts, ", "))
	safe_write(CACHE_DIR .. "/hypr_mosaic_workspaces.json", mosaic_json)
end

function M.apply_layout_rule(id, mode)
	if not id then return end
	local rule_name = (mode == "mosaic") and "lua:mosaic" or "dwindle"
	local ok, err = pcall(hl.workspace_rule, { workspace = tostring(id), layout = rule_name })
	log(string.format(">>> WS %s workspace_rule layout -> %s (%s)", tostring(id), rule_name, ok and "ok" or tostring(err)))
end

function M.set_mode(ws_id, mode)
	local ws = ws_id and { id = ws_id } or (hl.get_active_workspace and hl.get_active_workspace())
	if not ws or not ws.id then
		return
	end
	local id = tonumber(ws.id) or ws.id
	mode = (mode or "mosaic"):lower()
	if mode ~= "mosaic" and mode ~= "floating" and mode ~= "tiled" then
		mode = "mosaic"
	end

	log(string.format(">>> SET_MODE: WS %s -> %s", tostring(id), mode))
	_G.layout_state.workspaces[id] = mode
	save_state()

	-- Keep legacy global mirrors synchronized
	if _G.floating_mode and _G.floating_mode.workspaces then
		_G.floating_mode.workspaces[id] = (mode == "floating")
	end
	if _G.mosaic_mode and _G.mosaic_mode.workspaces then
		_G.mosaic_mode.workspaces[id] = (mode == "mosaic")
	end

	-- Apply compositor workspace layout rule
	M.apply_layout_rule(id, mode)

	local windows = hl.get_workspace_windows(id) or {}

	if mode == "mosaic" then
		-- Entering Mosaic: unfloat legacy/user floats (except archetypes/dialogs/pinned)
		if mosaic.migrate_legacy_floats then
			mosaic.migrate_legacy_floats(id)
		else
			for _, w in ipairs(windows) do
				pcall(function()
					if w.floating and not w.pinned then
						hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
					end
				end)
			end
		end
	elseif mode == "floating" then
		-- Entering Floating: float windows on this workspace
		if floating.apply_mode_to_windows then
			local gen = floating.bump_gen and floating.bump_gen() or 1
			floating.apply_mode_to_windows(windows, true, gen, id)
		else
			for _, w in ipairs(windows) do
				pcall(function()
					if not w.floating then
						hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
					end
				end)
			end
		end
	else
		-- Entering Tiled: unfloat managed windows and return to dwindle
		if floating.apply_mode_to_windows then
			local gen = floating.bump_gen and floating.bump_gen() or 1
			floating.apply_mode_to_windows(windows, false, gen, id)
		else
			for _, w in ipairs(windows) do
				pcall(function()
					if w.floating and not w.pinned then
						hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
					end
				end)
			end
		end
	end

	if floating.sync_mode_guards then
		floating.sync_mode_guards()
	end

	M.sync_indicators(id)
end

function M.cycle_mode(ws_id)
	local current = M.get_mode(ws_id)
	local next_mode = "mosaic"
	if current == "mosaic" then
		next_mode = "floating"
	elseif current == "floating" then
		next_mode = "tiled"
	else
		next_mode = "mosaic"
	end
	M.set_mode(ws_id, next_mode)
end

hl.on("workspace.active", function(ws)
	if not from_this_load() then
		return
	end
	local id = ws and ws.id
	if not id then
		return
	end
	local mode = M.get_mode(id)
	M.apply_layout_rule(id, mode)
	M.sync_indicators(id)
end)

hl.on("hyprland.start", function()
	if not from_this_load() then
		return
	end
	pcall(hl.config, { general = { layout = "lua:mosaic" } })
	for id, mode in pairs(_G.layout_state.workspaces or {}) do
		M.apply_layout_rule(id, mode)
	end
	local active = hl.get_active_workspace and hl.get_active_workspace()
	local active_id = active and active.id
	if active_id then
		M.apply_layout_rule(active_id, M.get_mode(active_id))
	end
	M.sync_indicators(active_id)
end)

-- Initial load execution
pcall(hl.config, { general = { layout = "lua:mosaic" } })
for id, mode in pairs(_G.layout_state.workspaces or {}) do
	M.apply_layout_rule(id, mode)
end
local initial_ws = hl.get_active_workspace and hl.get_active_workspace()
local initial_id = initial_ws and initial_ws.id
if initial_id then
	M.apply_layout_rule(initial_id, M.get_mode(initial_id))
end
M.sync_indicators(initial_id)

-- Expose to global environment for hyprctl eval and keybinds
_G.layout_manager = M
_G.set_workspace_layout_mode = function(mode, ws_id)
	M.set_mode(ws_id, mode)
end
_G.get_workspace_layout_mode = function(ws_id)
	return M.get_mode(ws_id)
end
_G.cycle_workspace_layout_mode = function(ws_id)
	M.cycle_mode(ws_id)
end

_G.mosaic_toggle = function(ws_id)
	local current = M.get_mode(ws_id)
	if current == "mosaic" then
		M.set_mode(ws_id, "tiled")
	else
		M.set_mode(ws_id, "mosaic")
	end
end

_G.workspace_floating_toggle = function(ws_id)
	local current = M.get_mode(ws_id)
	if current == "floating" then
		M.set_mode(ws_id, _G.layout_state.default or "mosaic")
	else
		M.set_mode(ws_id, "floating")
	end
end

_G.floating_mode_toggle = function()
	local ws = hl.get_active_workspace and hl.get_active_workspace()
	local id = ws and ws.id
	local current = M.get_mode(id)
	if current == "floating" then
		M.set_mode(id, _G.layout_state.default or "mosaic")
	else
		M.set_mode(id, "floating")
	end
end

return M
