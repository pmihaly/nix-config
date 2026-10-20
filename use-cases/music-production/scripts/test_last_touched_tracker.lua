ardour {
	["type"]    = "EditorHook",
	name        = "TEST: Last Touched Tracker (touch-based)",
	author      = "test",
	description = [[Polls every plugin automation list's touching() state ~10x/second and
logs a line (Window > Log) when a touch STARTS, i.e. when you grab a knob in the
plugin's own GUI. Automation playback does not set touching(), so it is ignored.
Try it with the track in Manual and in Touch mode and compare.]]
}

function signals ()
	local s = LuaSignal.Set ()
	s:add ({ [LuaSignal.LuaTimerDS] = true })  -- fires every 100 ms
	return s
end

function factory ()
	local controls = {}   -- list of {rname, pname, port, ctrl}
	local was = {}        -- key -> was touching last tick
	local ticks = 0

	local function to_pi (proc)
		local ok, res = pcall (function () return proc:to_insert () end)
		if ok and res and not res:isnil () then return res end
		ok, res = pcall (function () return proc:to_plugininsert () end)
		if ok and res and not res:isnil () then return res end
		return nil
	end

	-- build (and periodically rebuild) the list of controls to watch
	local function rebuild ()
		controls = {}
		for r in Session:get_routes ():iter () do
			local i = 0
			while true do
				local proc = r:nth_plugin (i)
				if proc:isnil () then break end
				i = i + 1
				local pi = to_pi (proc)
				if pi then
					local plugin = pi:plugin (0)
					for j = 0, plugin:parameter_count () - 1 do
						-- map the j-th parameter to its control port number
						local port = j
						local okp, p1 = pcall (function () return (plugin:nth_parameter (j, false)) end)
						if okp and type (p1) == "number" then port = p1 end

						local param = Evoral.Parameter (ARDOUR.AutomationType.PluginAutomation, 0, port)
						local ctrl = pi:to_automatable ():automation_control (param, false)
						if ctrl and not ctrl:isnil () then
							table.insert (controls, { r:name (), proc:name (), port, ctrl, r:name () .. "|" .. i .. "|" .. port })
						end
					end
				end
			end
		end
		print (string.format ("Last Touched Tracker: watching %d controls", #controls))
	end

	return function (signal, ref, ...)
		if ticks % 50 == 0 then rebuild () end   -- refresh every ~5 s
		ticks = ticks + 1

		for _, c in ipairs (controls) do
			local alist = c[4]:alist ()
			if alist and not alist:isnil () then
				local t = alist:touching ()
				local key = c[5]
				if t and not was[key] then
					local okv, v = pcall (function () return c[4]:get_value () end)
					print (string.format ("TOUCHED: track '%s', plugin '%s', control port %d, value %s",
						c[1], c[2], c[3], okv and string.format ("%.4f", v) or "?"))
				end
				was[key] = t
			end
		end
	end
end
