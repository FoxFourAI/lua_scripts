-- Run the existing FCU script at its ArduPilot API boundary; never arm an aircraft.
local values, passed, message = {}, nil, nil
local armed = false
param = {
    add_table = function(_, key, prefix)
        assert(key == 73 and prefix == "SCR_ARM_", "Use the existing authorization table")
        return true
    end,
    add_param = function(_, _, _, name, default)
        local key = "SCR_ARM_" .. name
        if values[key] == nil then values[key] = default end
        return true
    end,
}
function Parameter(name)
    assert(name:match("^SCR_ARM_"), "No separate Photolit parameter protocol")
    return {
        get = function() return values[name] end,
        set = function(_, value) values[name] = value end,
    }
end
vehicle = { get_mode = function() return 3 end }
gcs = { send_text = function() end }
arming = {
    get_aux_auth_id = function() return 1 end,
    is_armed = function() return armed end,
    set_aux_auth_failed = function(_, id, text)
        assert(id == 1)
        passed, message = false, text
    end,
    set_aux_auth_passed = function(_, id)
        assert(id == 1)
        passed, message = true, nil
    end,
}
local status_names = { "CTRL_S", "VIDEO_S", "MVLNK_S", "VIO_S", "AI_S" }
local update, delay = dofile("arm_authorization.lua")
assert(delay == 1000 and passed == false, "Boot must wait for VGM authorization")
for _, name in ipairs(status_names) do values["SCR_ARM_" .. name] = 1 end
update()
assert(passed == true, "All existing checks satisfied must pass")
values.SCR_ARM_VIDEO_S = 4; update()
assert(passed == false and message == "Targeting camera missing", "Missing/stale Photolit SDK must fail the existing video check")
values.SCR_ARM_VIDEO_S = 0; update()
assert(passed == false, "Unknown camera status must not authorize")
values.SCR_ARM_VIDEO_S = 1; update()
assert(passed == true, "Camera recovery must restore authorization")
for _, name in ipairs(status_names) do
    values["SCR_ARM_" .. name] = 0; update()
    assert(passed == false, "Camera readiness must not bypass " .. name)
    values["SCR_ARM_" .. name] = 1; update()
    assert(passed == true, "Restoring " .. name .. " must recover")
end
values.SCR_ARM_ENABLED = 0
for _, name in ipairs(status_names) do values["SCR_ARM_" .. name] = 0 end
update()
assert(passed == true, "The existing explicit disable switch must still work")
values.SCR_ARM_ENABLED = 1
armed = true; update()
assert(passed == true, "The existing already-armed behavior must remain unchanged")
armed = false; update()
assert(passed == false, "Returning to disarmed must require checks again")
for _, name in ipairs(status_names) do values["SCR_ARM_" .. name] = 1 end
update, delay = dofile("arm_authorization.lua")
assert(passed == false, "FCU script restart must clear old authorization statuses")
print("Existing arm authorization: boot, camera failure/recovery, all component checks, disable and restart PASS")
