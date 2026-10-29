-- Exercise the real script through the ArduPilot parameter/arming API boundary.
local now, value, passed, message = 0, 0, nil, nil
local uint32 = {}
uint32.__index = uint32
uint32.__sub = function(a, b)
    return setmetatable({value = (a.value - b.value) % 2^32}, uint32)
end
function uint32:tofloat() return self.value end
function millis() return setmetatable({value = now % 2^32}, uint32) end
param = {
    add_table = function() return true end,
    add_param = function() return true end,
}
function Parameter(name)
    assert(name == "SCR_PCAM_RST")
    return {
        get = function() return value end,
        set = function(_, next_value) value = next_value end,
    }
end
arming = {
    get_aux_auth_id = function() return 1 end,
    set_aux_auth_failed = function(_, id, text)
        assert(id == 1)
        passed, message = false, text
    end,
    set_aux_auth_passed = function(_, id)
        assert(id == 1)
        passed = true
    end,
}
local update, delay = dofile("photolit_arm_authorization.lua")
assert(delay == 1000 and passed == false and value == 1, "Saved ready state must not allow boot arming")
now = 20000; update()
assert(passed == false, "Absent VGM must keep arming blocked")
value = 0; update()
assert(passed == true and value == 1, "Fresh SDK pulse must be consumed")
now = 29999; update()
assert(passed == true, "Freshness window should tolerate normal SDK intervals")
now = 30000; update()
assert(passed == false and message == "Photolit camera missing/stale", "Stopped VGM/camera must expire")
value = 0; update()
assert(passed == true, "Reconnection must recover")
value = 2; update()
assert(passed == false, "Explicit missing camera must block immediately")
value = 0; update(); value = 99; update()
assert(passed == false, "Unknown status must fail closed")
now = 2^32 - 2000; value = 0; update()
now = 2000; update()
assert(passed == true, "millis wrap must preserve recent pulse")
now = 8000; update()
assert(passed == false, "Timeout must also work across millis wrap")
print("Photolit arm guard: boot, missing, ready, expiry, disconnect, reconnect, invalid and wrap checks PASS")
