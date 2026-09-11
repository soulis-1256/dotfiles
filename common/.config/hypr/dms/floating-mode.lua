-- Global Floating Mode for Hyprland
-- Unconditionally floats all windows in floating mode, and tiles all windows in tiling mode.

local M = {}

local LOG_FILE = "/tmp/floating_mode.log"
local function log(msg)
	local f = io.open(LOG_FILE, "a")
	if f then
		f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
		f:close()
	end
end

M.log = log

_G.floating_mode = _G.floating_mode or {
	active = false,
}

-- Restore state from runtime indicator if present
local rf = io.open("/tmp/hypr_floating_mode", "r")
if rf then
	local content = rf:read("*a") or ""
	rf:close()
	if content:match("^1") then
		_G.floating_mode.active = true
	end
end

log("floating-mode loaded. Current active = " .. tostring(_G.floating_mode.active))

local function is_special_overlay(w)
	if not w then return false end
	local title = (w.title or ""):lower()
	local cls = (w.class or ""):lower()
	if title:match("picture[%- ]in[%- ]picture") then return true end
	if cls:match("^steam") and title:match("^notificationtoasts") then return true end
	return false
end

function M.toggle()
	local state = _G.floating_mode
	state.active = not state.active

	log("==================================================================")
	log(">>> TOGGLE ACTIVATED: Mode is now " .. (state.active and "FLOATING" or "TILED"))

	local windows = hl.get_windows() or {}
	local count = 0

	for _, w in ipairs(windows) do
		if not is_special_overlay(w) then
			pcall(function()
				if state.active then
					-- Floating mode: EVERY window floats
					hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
				else
					-- Tiled mode: EVERY window tiles
					hl.dispatch(hl.dsp.window.float({ window = w, action = "unset" }))
				end
			end)
			count = count + 1
		end
	end

	log(string.format("Dispatched float=%s to %d windows", tostring(state.active), count))

	local f = io.open("/tmp/hypr_floating_mode", "w")
	if f then
		f:write(state.active and "1\n" or "0\n")
		f:close()
	end
end

function M.is_active()
	return _G.floating_mode and _G.floating_mode.active == true
end

_G.floating_mode_toggle = function()
	M.toggle()
end

-- Auto-float new windows cleanly without duplicate dispatches or animation glitches
local handled_windows = {}

local function handle_new_window(w)
	if not w then return end
	local title = (w.title or ""):lower()
	if title:match("picture[%- ]in[%- ]picture") then
		if not w.pinned then
			pcall(function()
				hl.dispatch(hl.dsp.window.pin({ window = w }))
			end)
		end
		return
	end

	local state = _G.floating_mode
	if not state or not state.active then
		return
	end

	local addr = w.address
	if not addr or handled_windows[addr] or is_special_overlay(w) then
		return
	end
	handled_windows[addr] = true

	local function ensure_float()
		if not w.floating then
			pcall(function()
				hl.dispatch(hl.dsp.window.float({ window = w, action = "set" }))
			end)
		end
	end

	-- Dispatch once on window.open
	ensure_float()

	-- One gentle fallback check at 60ms in case the layout engine queued it
	hl.timer(function()
		ensure_float()
	end, { timeout = 60, type = "oneshot" })
end

hl.on("window.open", handle_new_window)

hl.on("window.close", function(w)
	if w and w.address then
		handled_windows[w.address] = nil
	end
end)

-- Keep pinned windows (like Picture-in-Picture) Always on Top above all floating windows
-- NOTE: param is `mode`, not `action` (action causes "'mode' is required" toast on every focus change)
local last_raise = 0
hl.on("window.active", function(active_win)
	if not M.is_active() then
		return
	end
	local now = os.clock()
	if now - last_raise < 0.05 then
		return
	end
	last_raise = now
	for _, w in ipairs(hl.get_windows() or {}) do
		if w.pinned and w.floating and (not active_win or w.address ~= active_win.address) then
			pcall(function()
				hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
			end)
		end
	end
end)

return M
