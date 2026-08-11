local mavlink_msgs = {}

local MAV_CMD_SET_MESSAGE_INTERVAL = 511
local MAVLINK_MSG_ID_CAMERA_TRACKING_IMAGE_STATUS = 275
local HEARTBEAT_ID = 0
local CAM_BASE_ID = 100
local CAM_MAX_ID = 105
local UPDATE_RATE = 5000
local cameras = {}
local user5 = Parameter("SCR_USER5")
local system = -1


local COMMAND_LONG = {}
COMMAND_LONG.id = 76
COMMAND_LONG.crc_extra = 152
COMMAND_LONG.fields = {
             { "param1", "<f" },
             { "param2", "<f" },
             { "param3", "<f" },
             { "param4", "<f" },
             { "param5", "<f" },
             { "param6", "<f" },
             { "param7", "<f" },
             { "command", "<I2" },
             { "target_system", "<B" },
             { "target_component", "<B" },
             { "confirmation", "<B" },
             }

function mavlink_msgs.decode_header(message)
    local result = {}
    local read_marker = 3

    result.protocol_version, read_marker = string.unpack("<B", message, read_marker)
    if (result.protocol_version == 0xFE) then     -- mavlink 1
        result.protocol_version = 1
    elseif (result.protocol_version == 0XFD) then --mavlink 2
        result.protocol_version = 2
    else
        gcs:send_text(5,"unknown mavlink version")
        return nil, nil
    end

    _, read_marker = string.unpack("<B", message, read_marker)
    result.incompat_flags, result.compat_flags, read_marker = string.unpack("<BB", message, read_marker)
    result.seq, result.sysid, result.compid, read_marker = string.unpack("<BBB", message, read_marker)
    result.msgid, read_marker = string.unpack("<I3", message, read_marker)

    return result, read_marker
end

function mavlink_msgs.encode(message)
  local message_map = COMMAND_LONG

  local packString = "<"
  local packedTable = {}
  local packedIndex = 1
  for i,v in ipairs(message_map.fields) do
    if v[3] then
      packString = (packString .. string.rep(string.sub(v[2], 2), v[3]))
      for j = 1, v[3] do
        packedTable[packedIndex] = message[message_map.fields[i][1]][j]
        if packedTable[packedIndex] == nil then
          packedTable[packedIndex] = 0
        end
        packedIndex = packedIndex + 1
      end
    else
      packString = (packString .. string.sub(v[2], 2))
      packedTable[packedIndex] = message[message_map.fields[i][1]]
      packedIndex = packedIndex + 1
    end
  end
  return message_map.id, string.pack(packString, table.unpack(packedTable))
end

function add_if_valid(arr, comp_id, chan, min, max)
    if comp_id <= min or comp_id >= max then
        return
    end
    for _, v in ipairs(arr) do
        gcs:send_text(5,"checking ".. v[1])
        if v[1] == comp_id then
            return
        end
    end
    gcs:send_text(5,"adding camera component: " .. comp_id)
    arr[#arr + 1] = {comp_id, chan}
end

function send_refresh_rate(arr)
    if system < 1 then
        return
    end

    local rate_hz = user5:get()
    if not rate_hz or rate_hz <= 0 then
        return
    end
    local interval_us = math.floor(1000000 / rate_hz)
    for _, v in ipairs(arr) do

        local comm = {}
        comm.command = MAV_CMD_SET_MESSAGE_INTERVAL
        comm.target_system = system
        comm.target_component = v[1]
        comm.confirmation = 0
        comm.param1 = MAVLINK_MSG_ID_CAMERA_TRACKING_IMAGE_STATUS
        comm.param2 = interval_us
        comm.param3 = 0
        comm.param4 = 0
        comm.param5 = 0
        comm.param6 = 0
        comm.param7 = 0

        mavlink:send_chan(v[2],mavlink_msgs.encode(comm))
    end
end

mavlink:init(10, 1)
mavlink:register_rx_msgid(HEARTBEAT_ID)

function update()
    while(true)
    do
        local msg, chan = mavlink:receive_chan()
        if msg then
            local header, offset = mavlink_msgs.decode_header(msg)
            if header == nil then
                goto continue
            end

            local comp_id = header.compid
            if system < 0 and comp_id > CAM_BASE_ID and comp_id < CAM_MAX_ID then
                system = header.sysid
            end
            add_if_valid(cameras, comp_id, chan, CAM_BASE_ID, CAM_MAX_ID)
        else
            break
        end
    end
    ::continue::
    send_refresh_rate(cameras)
    return update, UPDATE_RATE
end

return update()