ardour {
    ["type"] = "EditorAction",
    name = "Last Tweaked: Show Lane",
    description = [[Shows the automation lane for the last plugin parameter changed in Manual mode. Requires the Last Tweaked monitor hook.]]
}

function factory ()
    return function ()
        if not Session then return end
        local path = os.getenv ("HOME") .. "/Library/Preferences/Ardour9/last-tweaked-request"
        local file = assert (io.open (path, "w"))
        assert (file:write (Session:path ()))
        assert (file:close ())
    end
end
