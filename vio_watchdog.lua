-- If this time passes without parameter being set, the watchdog will trigger EKF source change
local WATCHDOG_PERIOD_MS = 4000

local watchdog_active = false

-- Add parameters for VIO watchdog
local PARAM_TABLE_KEY = 74
assert(param:add_table(PARAM_TABLE_KEY, "SCR_WTCHDG_", 30), 'could not add param table')
assert(param:add_param(PARAM_TABLE_KEY, 1, 'RST', 1), 'could not add SCR_WTCHDG_RST param')

-- Set local variables through which we can read and write parameters
local watchdog_reset = Parameter("SCR_WTCHDG_RST")
watchdog_reset:set(1)

-- Helper function to switch back to EKF source 0
local function failsafe_ekf_switch()
    gcs:send_text(4, "VIO WATCHDOG EXPIRED!! Switching EKF source to 0")
    ahrs:set_posvelyaw_source_set(0)
end

gcs:send_text(6, "VIO watchdog is on...")

function watchdog_callback()
   local ekf_state = ahrs:get_posvelyaw_source_set()

   -- Watchdog does nothing when EKF source is not 1 (VIO)
   if ekf_state ~= 1 then
       return watchdog_callback, WATCHDOG_PERIOD_MS
   end

   local reset_param_value = watchdog_reset:get() -- fixed syntax: use ':' and declare as 'local'

    -- If the watchdog is activated and parameter value didn't change during the full cycle, trigger the failsafe
    if watchdog_active and reset_param_value == 1 then
        failsafe_ekf_switch()
        watchdog_active = false
    elseif not watchdog_active and reset_param_value == 0 then
        -- If during the last cycle user changed the reset parameter to 0, then activate the watchdog
        watchdog_active = true
        gcs:send_text(6, "VIO watchdog is activated...")
    end

    watchdog_reset:set(1) -- reset to 1 for the next cycle
    return watchdog_callback, WATCHDOG_PERIOD_MS
end

return watchdog_callback()
