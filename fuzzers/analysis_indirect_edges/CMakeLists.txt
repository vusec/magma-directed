cmake_minimum_required(VERSION 3.19)
# Requirement for LLVM >= 13
# cmake_minimum_required(VERSION 3.13.4)
project(IndirectBranchCounter)

include(GNUInstallDirs)

find_package(LLVM REQUIRED CONFIG HINTS "${LLVM_DIR}")

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)

include(FetchContent)

FetchContent_Declare(
  Corrosion
  GIT_REPOSITORY https://github.com/corrosion-rs/corrosion.git
  GIT_TAG v0.3.5
)
set(Rust_TOOLCHAIN nightly)
FetchContent_MakeAvailable(Corrosion)

find_package(Python3 REQUIRED)

set(PASS_NAME IndirectBranchCounter)
set(RTLIB_NAME sancov-dumper)

add_subdirectory(pass)
add_subdirectory(wrapper)

corrosion_import_crate(
  MANIFEST_PATH sancov-dumper/Cargo.toml
  FEATURES indicalls retaddr
  CRATE_TYPES cdylib staticlib
)

# Corrosion does not currently support installing libraries through CMake, so it
# is necessary to install this one manually. See:
# https://github.com/AndrewGaspar/corrosion/issues/64
install(FILES $<TARGET_FILE:${RTLIB_NAME}-shared> TYPE LIB)
install(FILES $<TARGET_FILE:${RTLIB_NAME}-static> TYPE LIB)
