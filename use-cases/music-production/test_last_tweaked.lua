local scripts = assert (arg[1])
local config = os.getenv ("HOME") .. "/Library/Preferences/Ardour9/"
local mode = 0
local shown = {}
local toggles = 0
local logs = {}
local plugins = true
local session_path = "/test/session"
local params = {
    { value = 0, state = 0, label = "Cutoff" },
    { value = 0, state = 0, label = "Resonance" }
}

for _, control in ipairs (params) do
    control.isnil = function () return false end
    control.get_value = function (self) return self.value end
    control.automation_state = function (self) return self.state end
    control.desc = function (self) return { label = self.label } end
    control.start_touch = function (self) shown[#shown + 1] = self.label end
end

ardour = function () end
ARDOUR = { AutoState = { Off = 0 }, AutomationType = { PluginAutomation = 1 } }
Evoral = { Parameter = function (_, _, port) return port end }
Temporal = { timepos_t = function (sample) return sample end }
LuaSignal = { LuaTimerDS = 1, Set = function () return { add = function () end } end }

local plugin = {
    isnil = function () return false end,
    parameter_count = function () return 2 end,
    nth_parameter = function (_, index) return 211 + index end
}
local processor = {
    isnil = function () return false end,
    to_stateful = function ()
        return { id = function () return { to_s = function () return "processor-1" end } end }
    end,
    name = function () return "Vital" end,
    plugin = function () return plugin end,
    automation_control = function (_, port, create)
        assert (create == false)
        return params[port - 210]
    end
}
processor.to_plugininsert = function () return processor end
processor.to_automatable = function () return processor end
local route = {
    name = function () return "Synth" end,
    nth_plugin = function (_, index)
        if plugins and index == 0 then return processor end
        return { isnil = function () return true end }
    end
}
Session = {
    path = function () return session_path end,
    transport_sample = function () return 0 end,
    get_routes = function ()
        return { iter = function ()
            local pending = true
            return function ()
                if not pending then return nil end
                pending = false
                return route
            end
        end }
    end
}
Editor = { access_action = function (_, group, action)
    assert (group == "Editor" and action == "show-touched-automation")
    toggles = toggles + 1
    local file = assert (io.open (config .. "instant.xml", "w"))
    file:write ('<Instant><Editor show-touched-automation="1"/></Instant>')
    file:close ()
end }
print = function (message) logs[#logs + 1] = message end

local hook_env = setmetatable ({}, { __index = _G })
assert (loadfile (scripts .. "/last_tweaked_monitor.lua", "t", hook_env)) ()
local monitor = hook_env.factory ()
local action_env = setmetatable ({}, { __index = _G })
assert (loadfile (scripts .. "/show_last_tweaked.lua", "t", action_env)) ()
local show = action_env.factory ()

monitor ()
show ()
monitor ()
assert (#shown == 0)
params[1].value = 0.5
monitor ()
show ()
monitor ()
assert (#shown == 1 and shown[1] == "Cutoff")
assert (toggles == 1 and params[1].state == 0)
show ()
monitor ()
assert (#shown == 2 and toggles == 1)

params[1].value = 0.7
params[2].value = 0.4
monitor ()
show ()
monitor ()
assert (#shown == 2)

params[2].state = 1
params[2].value = 0.8
monitor ()
show ()
monitor ()
assert (#shown == 2)

params[1].value = 0.9
monitor ()
params[1].state = 1
show ()
monitor ()
assert (#shown == 2)

session_path = "/test/another-session"
monitor ()
show ()
monitor ()
assert (#shown == 2)
assert (io.open (config .. "last-tweaked-request", "r") == nil)
io.stdout:write ("Manual detection, lane request, ambiguity, automation guards and session reset passed\n")
