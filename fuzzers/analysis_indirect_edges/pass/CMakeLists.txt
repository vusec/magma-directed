add_llvm_pass_plugin(${PASS_NAME} IndirectBranchCounter.cpp)
target_compile_definitions(${PASS_NAME} PRIVATE ${LLVM_DEFINITIONS})
target_include_directories(${PASS_NAME} PRIVATE ${LLVM_INCLUDE_DIRS})
