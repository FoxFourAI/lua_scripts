local mavlink_msgs = {}

local STATUSTEXT_ID = 253
local HEARTBEAT_ID = 0
local MAV_SEVERITY_WARNING = 4

local last_gcs_seen_time = 0
local gcs_timeout = 10000 -- 10 seconds in milliseconds

local STATUSTEXT_MAP = {}
STATUSTEXT_MAP.id = STATUSTEXT_ID
STATUSTEXT_MAP.fields = {
    { "severity", "<B" },
    { "text",     "c50" } -- 50-char string
}

local HEARTBEAT_MAP = {}
HEARTBEAT_MAP.id = HEARTBEAT_ID
HEARTBEAT_MAP.fields = {
    { "type",            "<B" },
    { "autopilot",       "<B" },
    { "base_mode",       "<B" },
    { "custom_mode",     "<I4" },
    { "system_status",   "<B" },
    { "mavlink_version", "<B" }
}


function mavlink_msgs.decode_header(message)
    -- build up a map of the result
    local result = {}

    local read_marker = 3

    -- id the MAVLink version
    result.protocol_version, read_marker = string.unpack("<B", message, read_marker)
    if (result.protocol_version == 0xFE) then     -- mavlink 1
        result.protocol_version = 1
    elseif (result.protocol_version == 0XFD) then --mavlink 2
        result.protocol_version = 2
    else
        -- If for some reason the magic is invalid, we just silently skip the message
        return nil, nil
    end

    _, read_marker = string.unpack("<B", message, read_marker) -- payload is always the second byte

    -- strip the incompat/compat flags
    result.incompat_flags, result.compat_flags, read_marker = string.unpack("<BB", message, read_marker)

    -- fetch seq/sysid/compid
    result.seq, result.sysid, result.compid, read_marker = string.unpack("<BBB", message, read_marker)

    -- fetch the message id
    result.msgid, read_marker = string.unpack("<I3", message, read_marker)

    return result, read_marker
end

function mavlink_msgs.decode(message, message_map)
    if not message_map then
        -- we don't know how to decode this message, bail on it
        return nil, nil
    end

    local result, offset = mavlink_msgs.decode_header(message)

    if result == nil then
        return nil, nil
    end

    -- map all the fields out
    for _, v in ipairs(message_map.fields) do
        if v[3] then
            result[v[1]] = {}
            for j = 1, v[3] do
                result[v[1]][j], offset = string.unpack(v[2], message, offset)
            end
        else
            result[v[1]], offset = string.unpack(v[2], message, offset)
        end
    end

    -- ignore the idea of a checksum

    return result;
end

-- Table of component IDs for onboard computers
local onboard_comp_ids = {
    [191] = true, -- MAV_COMP_ID_ONBOARD_COMPUTER
    [192] = true, -- MAV_COMP_ID_ONBOARD_COMPUTER1
    [193] = true, -- MAV_COMP_ID_ONBOARD_COMPUTER2
    [194] = true  -- MAV_COMP_ID_ONBOARD_COMPUTER3
}

local gcs_ids = {
    [190] = true, -- MAV_COMP_ID_MISSIONPLANNER
}

-- Initialize MAVLink reception
mavlink:init(10, 2)
mavlink:register_rx_msgid(STATUSTEXT_ID)
mavlink:register_rx_msgid(HEARTBEAT_ID)

function update()
    while (true)
    do
        local msg, chan = mavlink:receive_chan()
        if msg then
            -- Firstly, parse the message header
            local result, offset = mavlink_msgs.decode_header(msg)

            -- If the header was not decoded properly, we just skip this message
            if result == nil then
                goto continue
            end

            local msgid = result.msgid
            local compid = result.compid

            -- If we receive at least one message from the ground station, we stop the script, as there is no need for relaying messages
            if gcs_ids[compid] then
                last_gcs_seen_time = millis()
                goto continue
            end

            local now = millis()
            local gcs_active = (now - last_gcs_seen_time) < gcs_timeout

            -- If we have seen the ground station recently, do not relay any logs to avoid spamming
            if gcs_active then
                goto continue
            end

            -- Then, we parse only statustext messages from onboard computers
            if msgid ~= STATUSTEXT_ID or not onboard_comp_ids[compid] then
                goto continue
            end

            -- Finally, parse the message and display on OSD
            local parsed_msg = mavlink_msgs.decode(msg, STATUSTEXT_MAP)
            -- Relaying parameters only with warning or smaller (error, critical, alert, ...) severities
            if parsed_msg and parsed_msg.severity <= MAV_SEVERITY_WARNING then
                -- Forward to GCS (and analog OSD) with same severity (0-7)
                gcs:send_text(parsed_msg.severity, "VGM: " .. parsed_msg.text)
            end
        else
            break
        end
        ::continue::
    end
    return update, 1000
end

return update()
