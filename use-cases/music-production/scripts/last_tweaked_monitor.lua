ardour {
    ["type"] = "EditorHook",
    name = "Last Tweaked: Monitor",
    description = [[Remembers plugin parameter changes in Manual mode. The Show Lane action reveals the last unambiguous parameter without changing its automation mode.]]
}

function signals ()
    local s = LuaSignal.Set ()
    s:add ({ [LuaSignal.LuaTimerDS] = true })
    return s
end

function factory ()
    local controls = {}
    local last = nil
    local session_path = nil
    local ticks = 0
    local config_path = os.getenv ("HOME") .. "/Library/Preferences/Ardour9/"
    local request_path = config_path .. "last-tweaked-request"

    local function add_plugin (route, proc, previous)
        local pi = proc:to_plugininsert ()
        if pi:isnil () then return end
        local plugin = pi:plugin (0)
        if plugin:isnil () then return end
        for index = 0, plugin:parameter_count () - 1 do
            local port = plugin:nth_parameter (index, false)
            local param = Evoral.Parameter (ARDOUR.AutomationType.PluginAutomation, 0, port)
            local ctrl = pi:to_automatable ():automation_control (param, false)
            if ctrl and not ctrl:isnil () then
                local key = proc:to_stateful ():id ():to_s () .. ":" .. port
                controls[key] = { ctrl = ctrl, value = previous[key] and previous[key].value or ctrl:get_value (), label = route:name () .. " / " .. proc:name () .. " / " .. ctrl:desc ().label }
            end
        end
    end

    local function add_route (route, previous)
        local index = 0
        while true do
            local proc = route:nth_plugin (index)
            if proc:isnil () then return end
            add_plugin (route, proc, previous)
            index = index + 1
        end
    end

    local function rebuild ()
        local previous = controls
        controls = {}
        for route in Session:get_routes ():iter () do
            add_route (route, previous)
        end
        if last and not controls[last] then last = nil end
    end

    local function poll ()
        local changed = {}
        for key, entry in pairs (controls) do
            local value = entry.ctrl:get_value ()
            if entry.ctrl:automation_state () == ARDOUR.AutoState.Off and math.abs (value - entry.value) > 1e-6 then
                changed[#changed + 1] = key
            end
            entry.value = value
        end
        if #changed == 0 then return end
        if #changed > 1 then
            last = nil
            print ("Last Tweaked: multiple parameters changed together; tweak a single knob before showing its lane.")
            return
        end
        last = changed[1]
        print ("Last Tweaked: " .. controls[last].label)
    end

    local function saved_show_on_touch (path)
        local file = io.open (path, "r")
        if not file then return nil end
        local text = assert (file:read ("*a"))
        assert (file:close ())
        local editor = text:match ("<Editor%s([^>]+)")
        if not editor then return nil end
        return editor:match ('show%-touched%-automation="([01])"')
    end

    local function reveal ()
        if not last then
            print ("Last Tweaked: tweak one plugin knob in Manual mode first.")
            return
        end
        local ctrl = controls[last].ctrl
        if ctrl:automation_state () ~= ARDOUR.AutoState.Off then
            print ("Last Tweaked: parameter is no longer in Manual mode; no synthetic touch was sent.")
            return
        end
        local enabled = saved_show_on_touch (Session:path () .. "/instant.xml") or saved_show_on_touch (config_path .. "instant.xml")
        if enabled ~= "1" then Editor:access_action ("Editor", "show-touched-automation") end
        ctrl:start_touch (Temporal.timepos_t (Session:transport_sample ()))
        print ("Last Tweaked: showing lane for " .. controls[last].label)
    end

    local function handle_request ()
        local file = io.open (request_path, "r")
        if not file then return end
        local requested_session = assert (file:read ("*a"))
        assert (file:close ())
        assert (os.remove (request_path))
        if requested_session ~= Session:path () then
            print ("Last Tweaked: ignored a request from another session.")
            return
        end
        rebuild ()
        reveal ()
    end

    return function ()
        if not Session then return end
        if session_path ~= Session:path () then
            session_path = Session:path ()
            controls = {}
            last = nil
            ticks = 0
        end
        if ticks % 20 == 0 then rebuild () end
        ticks = ticks + 1
        poll ()
        handle_request ()
    end
end
