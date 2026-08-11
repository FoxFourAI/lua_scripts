local ARM_AUTHORIZATION_CHECK_DELAY_MS = 1000

-- Add parameters for arm authorization
local PARAM_TABLE_KEY = 73
assert(param:add_table(PARAM_TABLE_KEY, "SCR_ARM_", 30), 'could not add param table')
assert(param:add_param(PARAM_TABLE_KEY, 1, 'ENABLED', 1), 'could not add SCR_ARM_ENABLED param')
assert(param:add_param(PARAM_TABLE_KEY, 2, 'CTRL_S', 0), 'could not add SCR_ARM_CTRL_S param')
assert(param:add_param(PARAM_TABLE_KEY, 3, 'VIDEO_S', 0), 'could not add SCR_ARM_VIDEO_S param')
assert(param:add_param(PARAM_TABLE_KEY, 4, 'MVLNK_S', 0), 'could not add SCR_ARM_MVLNK_S param')
assert(param:add_param(PARAM_TABLE_KEY, 5, 'VIO_S', 0), 'could not add SCR_ARM_VIO_S param')
assert(param:add_param(PARAM_TABLE_KEY, 6, 'AI_S', 0), 'could not add SCR_ARM_AI_S param')

-- Set local variables through which we can read and write parameters
local arm_enabled_param = Parameter("SCR_ARM_ENABLED")
local arm_control_state = Parameter("SCR_ARM_CTRL_S")
local arm_video_state   = Parameter("SCR_ARM_VIDEO_S")
local arm_mavlink_state = Parameter("SCR_ARM_MVLNK_S")
local arm_vio_state     = Parameter("SCR_ARM_VIO_S")
local arm_ai_state      = Parameter("SCR_ARM_AI_S")
local mav_mode          = vehicle:get_mode()


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

-- Helper function to not authorize arm and send status text
local function not_authorize_with_message(auth_id, message)
    gcs:send_text(6, "VGM err: " .. message)
    arming:set_aux_auth_failed(auth_id, message)
end

-- Enum for easy conversion of control state to a string
local ControlState, ControlStateDescription = create_enum {
    INITIAL = { value = -1, description = "" },
    MISSING = { value = 0, description = "No control status from VGM" },
    OK = { value = 1, description = "Control is running" },
    BAD_MAVLINK = { value = 2, description = "Bad MavLink conn. to FCU" },
    MOTOR_PARAMS_ABSENT = { value = 3, description = "Motor params not set" },
    LOW_MESSAGE_RATE = { value = 4, description = "MavLink message rate low" },
    WAITING = { value = 5, description = "Waiting for control" },
    HOVER_THROTTLE_ABSENT = { value = 6, description = "Hover throttle unknown"}
}

-- Enum for easy conversion of video state to a string
local VideoState, VideoStateDescription = create_enum {
    INITIAL = { value = -1, description = "" },
    MISSING = { value = 0, description = "No video status from VGM" },
    OK = { value = 1, description = "Stream is running" },
    WAITING = { value = 2, description = "Waiting for video" },
    FAILED = { value = 3, description = "Video stream failed" },
    CAMERA_ABSENT = { value = 4, description = "Targeting camera missing" }
}

-- Enum for easy conversion of video state to a string
local MavlinkState, MavlinkStateDescription = create_enum {
    INITIAL = { value = -1, description = "" },
    MISSING = { value = 0, description = "No MavLink conn." },
    OK = { value = 1, description = "Mavlink conn present" }
}

-- Enum for easy conversion of VIO state to a string
local VIOState, VIOStateDescription = create_enum {
    INITIAL = { value = -1, description = "" },
    MISSING = { value = 0, description = "No VIO status from VGM" },
    OK = { value = 1, description = "VIO is OK" },
    WAITING = { value = 2, description = "Waiting for VIO to start" },
    LOW_MESSAGE_RATE = { value = 3, description = "MavLink message rate low" },
    LOW_FPS = { value = 4, description = "Low camera FPS" },
    CAMERA_ABSENT = { value = 5, description = "Camera is absent" },
    WRONG_EKF = { value = 6, description = "Wrong EKF config" },
    LOW_SATS = { value = 7, description = "Low Satellite count" },
    HIGH_HDOP = { value = 8, description = "High HDOP for GPS init" }
}

-- Enum for easy conversion of AI state to a string
local AIState, AIStateDescription = create_enum {
    INITIAL = { value = -1, description = "" },
    MISSING = { value = 0, description = "No AI status from VGM" },
    OK = { value = 1, description = "AI is OK" },
    WRONG_MODEL = { value = 2, description = "AI failed" },
    WAITING = { value = 3, description = "Waiting for AI to start" },
    FAILED = { value = 4, description = "AI failed" },
}

local mavlink_state_value = MavlinkState.INITIAL
local video_state_value = VideoState.INITIAL
local ai_state_value = AIState.INITIAL
local control_state_value = ControlState.INITIAL
local vio_state_value = VIOState.INITIAL


-- Set the default states to "MISSING" as we haven't received any messages yet
arm_control_state:set(ControlState.MISSING)
arm_video_state:set(VideoState.MISSING)
arm_ai_state:set(AIState.MISSING)
arm_mavlink_state:set(MavlinkState.MISSING)
arm_vio_state:set(VIOState.MISSING)

auth_id = arming:get_aux_auth_id()

gcs:send_text(6, "Arm authorization is on. Waiting...")
arming:set_aux_auth_failed(auth_id, "Arm authorization still off")

-- This variable determines if some component has authorized arm on the previous lap.
-- The main reason for it is that when no parameters are changed currently and some node auhorizes arm, we need to call "not_authorize_with_message" to update the arm not authorization message
local component_arm_authorized = false

function check_arm_authorization()
    if (mav_mode ~= vehicle:get_mode()) then
        -- GUIDED is 4, GUIDED_NOGPS is 20
        if (vehicle:get_mode() == 4 or vehicle:get_mode() == 20) then
            gcs:send_text(5, "Attack!")
        end
        mav_mode = vehicle:get_mode()
    end

    -- Doing nothing if the check is disabled or the drone is already armed
    if (arm_enabled_param:get() == 0 or arming:is_armed()) then
        arming:set_aux_auth_passed(auth_id)
        goto done
    end

    -- Firstly checking the MavLink. If it is not connected, other parameters are unlikely to be changed
    if (mavlink_state_value ~= arm_mavlink_state:get() or component_arm_authorized == true) then
        mavlink_state_value = arm_mavlink_state:get()
        if (mavlink_state_value ~= MavlinkState.OK) then
            component_arm_authorized = false
            not_authorize_with_message(auth_id, MavlinkStateDescription[mavlink_state_value])
            goto done
        end
        component_arm_authorized = true
    end

    -- Then, checking the video as if the stream failed, there is no reason to wait more
    if (video_state_value ~= arm_video_state:get() or component_arm_authorized == true) then
        video_state_value = arm_video_state:get()
        if (video_state_value ~= VideoState.OK) then
            component_arm_authorized = false
            not_authorize_with_message(auth_id, VideoStateDescription[video_state_value])
            goto done
        end
        component_arm_authorized = true
    end

    -- If previous checks are passed, check the status from control
    if (control_state_value ~= arm_control_state:get() or component_arm_authorized == true) then
        control_state_value = arm_control_state:get()
        if (control_state_value ~= ControlState.OK) then
            component_arm_authorized = false
            not_authorize_with_message(auth_id, ControlStateDescription[control_state_value])
            goto done
        end
        component_arm_authorized = true
    end

    -- If previous checks are passed, check the status from VIO
    if (vio_state_value ~= arm_vio_state:get() or component_arm_authorized == true) then
        vio_state_value = arm_vio_state:get()
        if (vio_state_value ~= VIOState.OK) then
            component_arm_authorized = false
            not_authorize_with_message(auth_id, VIOStateDescription[vio_state_value])
            goto done
        end
        component_arm_authorized = true
    end

    -- If previous checks are passed, check the status from AI
    if (ai_state_value ~= arm_ai_state:get() or component_arm_authorized == true) then
        ai_state_value = arm_ai_state:get()
        if (ai_state_value ~= AIState.OK) then
            component_arm_authorized = false
            not_authorize_with_message(auth_id, AIStateDescription[ai_state_value])
            goto done
        end
        component_arm_authorized = true
    end

    -- Authorize arm if all the checks were passed
    if (mavlink_state_value == MavlinkState.OK and video_state_value == VideoState.OK and control_state_value == ControlState.OK and vio_state_value == VIOState.OK and ai_state_value == AIState.OK) then
        arming:set_aux_auth_passed(auth_id)
    end

    ::done::
    return check_arm_authorization, ARM_AUTHORIZATION_CHECK_DELAY_MS
end

return check_arm_authorization()
