ardour {
	["type"]    = "EditorAction",
	name        = "TEST: Binding Probe",
	author      = "test",
	description = [[Checks which learn/touch related members are reachable from
Lua on the first plugin found in the session. Output appears in the
script window (Window > Scripting) when run from there, or in Window > Log.]]
}

function factory ()
	return function ()
		local function probe (label, fn)
			local ok, res = pcall (fn)
			if ok and res ~= nil then
				print (string.format ("[ YES ] %s", label))
			else
				print (string.format ("[ NO  ] %s  (%s)", label, ok and "nil" or tostring (res)))
			end
		end

		-- find the first plugin insert in the session
		local pi, rname
		for r in Session:get_routes ():iter () do
			local i = 0
			while true do
				local proc = r:nth_plugin (i)
				if proc:isnil () then break end
				i = i + 1
				local ok, res = pcall (function () return proc:to_insert () end)
				if not (ok and res and not res:isnil ()) then
					ok, res = pcall (function () return proc:to_plugininsert () end)
				end
				if ok and res and not res:isnil () then pi = res; rname = r:name (); break end
			end
			if pi then break end
		end

		if not pi then
			print ("No plugin found. Add Vital to a track first.")
			return
		end
		print ("Probing first plugin on track: " .. rname)

		local plugin = pi:plugin (0)
		print ("Plugin: " .. plugin:name () .. ", parameters: " .. plugin:parameter_count ())

		-- plugin-level signals / methods
		probe ("plugin.ParameterChangedExternally", function () return plugin.ParameterChangedExternally end)
		probe ("plugin.StartTouch",                 function () return plugin.StartTouch end)
		probe ("plugin.EndTouch",                   function () return plugin.EndTouch end)

		-- per-control members
		local port = plugin:nth_parameter (0, false)
		local param = Evoral.Parameter (ARDOUR.AutomationType.PluginAutomation, 0, port)
		local ok, ctrl = pcall (function () return pi:to_automatable ():automation_control (param, false) end)
		if not ok then
			print ("Control lookup failed: " .. tostring (ctrl))
			return
		end
		if ctrl and ctrl:isnil () then ctrl = nil end

		probe ("got an AutomationControl for param 0", function () return ctrl end)
		if ctrl then
			probe ("ctrl:get_value",          function () return ctrl.get_value end)
			probe ("ctrl:set_automation_state", function () return ctrl.set_automation_state end)
			probe ("ctrl:automation_state",   function () return ctrl.automation_state end)
			probe ("ctrl:alist():touching",   function () return ctrl:alist ().touching end)
			probe ("ctrl:start_touch",        function () return ctrl.start_touch end)
			probe ("ctrl.Changed (signal)",   function () return ctrl.Changed end)
			probe ("ctrl.TouchChanged (signal)", function () return ctrl.TouchChanged end)
			probe ("ctrl:start_learning (MIDI learn)", function () return ctrl.start_learning end)
			probe ("ctrl:stop_learning",      function () return ctrl.stop_learning end)
		end

		-- is the timer signal available for the tracker script?
		if LuaSignal == nil then
			print ("[ SKIP ] LuaSignal: unavailable in this editor context; test the timer by enabling the hook.")
			return
		end
		probe ("LuaSignal.LuaTimerDS", function () return LuaSignal.LuaTimerDS end)
	end
end
