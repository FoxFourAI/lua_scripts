### LUA scripts for ardupilot

This directory contains lua scripts that can be uploaded to ardupilot to run along the VGM

List of scripts:
- arm_authorization.lua - script to block UAV arm until VGM authorizes it. Without it user will still see messages but will be able to always arm the drone
- auto_mission.lua - scripts for autonomous mission execution. Does not interfer with drone flight, but sets parameters accordingly to the current mission state
- ekf_switch_detector.lua - scripts to be used with VIO for convenient logging. Sends logs wen EKF3 source is switched (e.g. between VIO and GPS)
- tracking_status_rate_setter.lua - script that sends the tracking status rate to the camera component, so the VGM could send the message without a request from the ground station.

### Photolit camera authorization

Photolit uses the existing `arm_authorization.lua`; install it in the FCU's `APM/scripts/` directory, enable ArduPilot scripting (`SCR_ENABLE=1`) and reboot.
Configure ArduPilot's `SCR_LD_CHECKSUM` and `SCR_RUN_CHECKSUM` after loading the intended scripts, as described in the [ArduPilot scripting documentation](https://ardupilot.org/dev/docs/common-lua-scripts.html#script-crashes-and-errors).

For `GUID_FRAME_TYPE=3`, the matching VGM firmware reports camera SDK readiness through the existing `SCR_ARM_VIDEO_S` status: 1 is ready and 4 is missing/stale.
The VGM requires a successful V2/V3 SDK reply within the last 10 seconds and reevaluates it in the existing authorization loop (every 15 seconds).
Video streaming is optional; this check does not trigger a photograph.
The VGM marks the streaming AI check as satisfied in Photolit mode, while MAVLink, control and VIO retain their existing checks and service-group rules.
Other frame types retain their existing authorization behavior.
No additional Lua script or `SCR_PCAM_*` parameters are required.
