function parameters_reset()
    local ek3_primary = Parameter("EK3_PRIMARY")

    -- EKF source set 1
    local src1_posxy = Parameter("EK3_SRC1_POSXY")
    local src1_velxy = Parameter("EK3_SRC1_VELXY")
    local src1_posz  = Parameter("EK3_SRC1_POSZ")
    local src1_velz  = Parameter("EK3_SRC1_VELZ")
    local src1_yaw   = Parameter("EK3_SRC1_YAW")
    
    -- EKF source set 2
    local src2_posxy = Parameter("EK3_SRC2_POSXY")
    local src2_velxy = Parameter("EK3_SRC2_VELXY")
    local src2_posz  = Parameter("EK3_SRC2_POSZ")
    local src2_velz  = Parameter("EK3_SRC2_VELZ")
    local src2_yaw   = Parameter("EK3_SRC2_YAW")

    -- Primary EKF core, always set to the first one
    ek3_primary:set(0)

    -- Reset the EKF source set 2 to the values of source set 1
    src2_posxy:set(src1_posxy:get())
    src2_velxy:set(src1_velxy:get())
    src2_posz:set(src1_posz:get())
    src2_velz:set(src1_velz:get())
    src2_yaw:set(src1_yaw:get())
end

return parameters_reset()
