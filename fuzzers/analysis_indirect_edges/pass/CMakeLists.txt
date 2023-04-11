cmake_minimum_required(VERSION 3.13.4)
project(llvm-skeleton)

find_package(LLVM REQUIRED CONFIG HINTS "${LLVM_DIR}")

list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)

include_directories(SYSTEM ${LLVM_INCLUDE_DIRS})
# add_definitions(${LLVM_DEFINITIONS})

# Use the same C++ standard as LLVM does
set(CMAKE_CXX_STANDARD 17 CACHE STRING "")

# LLVM is normally built without RTTI. Be consistent with that.
if(NOT LLVM_ENABLE_RTTI)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-rtti")
endif()

add_llvm_pass_plugin(IndirectBranchCounter IndirectBranchCounter.cpp)

# Allow undefined symbols in shared objects on Darwin (this is the default
# behaviour on Linux)
# target_link_libraries(IndirectBranchCounter
#   "$<$<PLATFORM_ID:Darwin>:-undefined dynamic_lookup>")
