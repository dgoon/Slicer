
#-----------------------------------------------------------------------------
set(BASELINE ${CMAKE_CURRENT_SOURCE_DIR}/../Data/Baseline)
set(CLP ${MODULE_NAME})

#-----------------------------------------------------------------------------
add_executable(${CLP}Test ${CLP}Test.cxx)
target_link_libraries(${CLP}Test ${CLP}Lib)
set_target_properties(${CLP}Test PROPERTIES LABELS ${CLP})

set(testname ${CLP}Test)
add_test(NAME ${testname} COMMAND ${SEM_LAUNCH_COMMAND} $<TARGET_FILE:${CLP}Test>
  --compare ${BASELINE}/LabelMapSmoothingTest.nhdr
            ${TEMP}/LabelMapSmoothingTest.nhdr
  ModuleEntryPoint
    --labelToSmooth 1
    --numberOfIterations 50
    --maxRMSError 0.01
    --gaussianSigma 3
   ${TEST_DATA}/CTHeadResampledOtsuSegmented.nhdr
   ${TEMP}/LabelMapSmoothingTest.nhdr
  )
set_property(TEST ${testname} PROPERTY LABELS ${CLP})

