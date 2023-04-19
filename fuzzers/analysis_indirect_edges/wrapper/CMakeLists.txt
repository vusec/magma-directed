set(PLUGIN_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/lib${LLVM_LIBDIR_SUFFIX}")
set(PASS_PATH "${PLUGIN_INSTALL_PREFIX}/$<TARGET_FILE_NAME:${PASS_NAME}>")

set(RTLIB_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
set(RTLIB_PATH "${RTLIB_INSTALL_PREFIX}/$<TARGET_FILE_NAME:${RTLIB_NAME}-static>")

configure_file(indicalls_cc.in indicalls_cc.gen @ONLY)
file(GENERATE OUTPUT indicalls_cc INPUT "${CMAKE_CURRENT_BINARY_DIR}/indicalls_cc.gen")
install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/indicalls_cc" TYPE BIN)
install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/indicalls_cc" TYPE BIN RENAME indicalls_cxx)

if(BUILD_TESTING)
  # If testing is enabled, build a version of the wrapper that refers to the
  # artifacts in the build directory. This version of the wrapper can be used
  # directly in tests, without requiring to install the project.

  set(PASS_PATH $<TARGET_FILE:${PASS_NAME}>)
  set(RTLIB_PATH "$<TARGET_FILE:${RTLIB_NAME}-shared>")

  configure_file(indicalls_cc.in indicalls_cc_test.gen @ONLY)
  file(GENERATE OUTPUT indicalls_cc_test INPUT "${CMAKE_CURRENT_BINARY_DIR}/indicalls_cc_test.gen")

  add_custom_target(build_indicalls_cxx_test ALL
    DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/indicalls_cxx_test")
  add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/indicalls_cxx_test"
    COMMAND ${CMAKE_COMMAND} -E copy
            "${CMAKE_CURRENT_BINARY_DIR}/indicalls_cc_test"
            "${CMAKE_CURRENT_BINARY_DIR}/indicalls_cxx_test")
endif()
