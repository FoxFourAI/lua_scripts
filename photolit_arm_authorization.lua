-- VGM writes 0 after a fresh Photolit SDK check, 2 when unavailable; Lua consumes the pulse.
local TIMEOUT_MS = 10000
local auth_id = assert(arming:get_aux_auth_id(), "No Photolit arm authorization slot")
arming:set_aux_auth_failed(auth_id, "Photolit: waiting for camera")

local PARAM_TABLE_KEY = 76
assert(param:add_table(PARAM_TABLE_KEY, "SCR_PCAM_", 2), "Could not add SCR_PCAM_ table")
assert(param:add_param(PARAM_TABLE_KEY, 1, "RST", 1), "Could not add SCR_PCAM_RST")
assert(param:add_param(PARAM_TABLE_KEY, 2, "EN", 0), "Could not add SCR_PCAM_EN")
local reset = Parameter("SCR_PCAM_RST")
local enabled = Parameter("SCR_PCAM_EN") -- Retain the last VGM-confirmed mode across FCU reboots.
reset:set(1) -- Never trust a ready value saved before this script started.
local last_ready = nil

local function update()
    if enabled:get() == 0 then
        last_ready = nil
        reset:set(1)
        arming:set_aux_auth_passed(auth_id)
        return update, 1000
    end

    local state = reset:get()
    if state == 0 then
        last_ready = millis()
        reset:set(1)
    elseif state ~= 1 then
        last_ready = nil
    end

    if last_ready and (millis() - last_ready):tofloat() < TIMEOUT_MS then
        arming:set_aux_auth_passed(auth_id)
    else
        arming:set_aux_auth_failed(auth_id, "Photolit camera missing/stale")
    end
    return update, 1000
end

return update()
