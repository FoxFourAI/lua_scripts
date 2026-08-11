### LUA scripts for ardupilot

This directory contains lua scripts that can be uploaded to ardupilot to run along the VGM

List of scripts:
- arm_authorization.lua - script to block UAV arm until VGM authorizes it. Without it user will still see messages but will be able to always arm the drone
- auto_mission.lua - scripts for autonomous mission execution. Does not interfer with drone flight, but sets parameters accordingly to the current mission state
- ekf_switch_detector.lua - scripts to be used with VIO for convenient logging. Sends logs wen EKF3 source is switched (e.g. between VIO and GPS)
- tracking_status_rate_setter.lua - script that sends the tracking status rate to the camera component, so the VGM could send the message without a request from the ground station.
