local COPTER_GUIDED_MODE = 4
local COPTER_AUTO_MODE   = 3
local COPTER_LOITER_MODE = 5

local mav_mode           = vehicle:get_mode()
local last_mission_index = mission:get_current_nav_index()
local total_indexes      = mission:num_commands()
gcs:send_text(6, string.format('auto_mission: Total mission indexes: %i', total_indexes))

local user_param = Parameter('SCR_USER1')
local n_waypoints_before_end_param = Parameter('SCR_USER3')
n_waypoints_before_end_param:set(2)
user_param:set(2)
local run_value = user_param:get()

if run_value then
  gcs:send_text(6, string.format('auto_mission: SCR_USER1 value is: %i', run_value))
else
  gcs:send_text(6, 'auto_mission: read SCR_USER1 failed')
end

-- wait set some time and then swith parameter value from 0 to 1
function mission_loop()
  if (mav_mode ~= vehicle:get_mode()) then
    -- GUIDED is 4, GUIDED_NOGPS is 20
    if (vehicle:get_mode() == 4 or vehicle:get_mode() == 20) then
      gcs:send_text(5, "TARGET LOCK: EXTERMINATE")
    end
    mav_mode = vehicle:get_mode()
  end

  local mission_index = mission:get_current_nav_index()

  -- see if we have changed since we last checked
  if mission_index ~= last_mission_index then
    gcs:send_text(6, "Mission: New Mission Waypoint") -- we spotted a change

    gcs:send_text(6,
      string.format("Mission Prev: %d, Mission Current: %d", mission:get_prev_nav_cmd_id(), mission:get_current_nav_id()))
    gcs:send_text(6,
      string.format("Current mission index: %d, mission length: %d", mission_index, mission:num_commands()))

    last_mission_index = mission_index;

    local mission_length = mission:num_commands()

    -- if mission index almost done (prelast waypoint) then run ai
    if mission_length > 1 and mission_index >= mission_length - n_waypoints_before_end_param:get() then -- last N waypoints
      gcs:send_text(5, "Mission: Reached Kill Zone !")
      user_param:set(1)
    end
  end
  return mission_loop, 100 -- reschedules the loop
end

return mission_loop()
