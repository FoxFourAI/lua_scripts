### LUA scripts for ardupilot

This directory contains lua scripts that can be uploaded to ardupilot to run along the VGM

List of scripts:
- arm_authorization.lua - script to block UAV arm until VGM authorizes it. Without it user will still see messages but will be able to always arm the drone
- auto_mission.lua - scripts for autonomous mission execution. Does not interfer with drone flight, but sets parameters accordingly to the current mission state
- ekf_switch_detector.lua - scripts to be used with VIO for convenient logging. Sends logs wen EKF3 source is switched (e.g. between VIO and GPS)
- tracking_status_rate_setter.lua - script that sends the tracking status rate to the camera component, so the VGM could send the message without a request from the ground station.

### Photolit camera pre-arm guard

Install `photolit_arm_authorization.lua` in the flight controller's `APM/scripts/` directory and enable ArduPilot scripting (`SCR_ENABLE=1`), then reboot the flight controller.
After loading the intended scripts, configure `SCR_LD_CHECKSUM` and `SCR_RUN_CHECKSUM` so missing scripts also block arming; [ArduPilot documents generating both using `SCR_DEBUG_OPTS` bit 5](https://ardupilot.org/dev/docs/common-lua-scripts.html#script-crashes-and-errors).
It is a camera-only guard for Photolit V2/V3 and does not require video streaming or trigger a photograph.
Use it instead of `arm_authorization.lua` on a camera-only Photolit setup; other vehicle-specific pre-arm checks still apply.
The matching VGM update must publish `SCR_PCAM_RST`: 0 is a fresh successful SDK check, 2 is unavailable, and Lua consumes 0 by setting 1.
Arming starts blocked and is blocked again after 10 seconds without a fresh pulse, including VGM/camera-service failure.
The script never arms or disarms the aircraft.
Do not manually set this status parameter; it is a watchdog handshake, not a configuration switch.

Run the offline guard checks with `lua tests/photolit_arm_authorization_test.lua`.
