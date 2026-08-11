local ekf_state = ahrs:get_posvelyaw_source_set()

local PARAM_TABLE_KEY = 75
assert(param:add_table(PARAM_TABLE_KEY, "SCR_EKF_", 30), 'could not add param table')
assert(param:add_param(PARAM_TABLE_KEY, 1, 'SRC', 1), 'could not add SCR_EKF_SRC param')
local ekf_src = Parameter("SCR_EKF_SRC")
local user2 = Parameter("SCR_USER2")
-- setting user2 to 0 on startup
user2:set(0)
ekf_src:set(0)

-- Helper function to work easily with enums
local function create_enum(tbl)
    local enum = {}
    local descriptions = {}
    for k, v in pairs(tbl) do
        enum[k] = v.value
        descriptions[v.value] = v.description
    end
    setmetatable(enum, {
        __index = function(_, key)
            error("Attempt to access invalid enum value: " .. tostring(key))
        end,
        __newindex = function(_, key, _)
            error("Attempt to modify read-only enum: " .. tostring(key))
        end
    })
    return enum, descriptions
end

local EkfState, EkfStateDescription = create_enum {
    GPS = { value = 0, description = "GPS" },
    VIO = { value = 1, description = "VIO" },
    AUX = { value = 2, description = "Aux" },
}

function check_ekf_switch()
    if (ekf_state ~= ahrs:get_posvelyaw_source_set()) then
        ekf_state = ahrs:get_posvelyaw_source_set()
        gcs:send_text(5, "EKF switched to " .. EkfStateDescription[ekf_state])
        gcs:send_text(5, "setting SCR_EKF_SRC to " .. ekf_state)
        ekf_src:set(ekf_state)
    end
    return check_ekf_switch, 1000
end

return check_ekf_switch()
