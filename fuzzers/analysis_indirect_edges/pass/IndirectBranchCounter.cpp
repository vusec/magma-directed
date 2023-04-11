#include "llvm/IR/Function.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Pass.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"

#include <cstdlib>
#include <fstream>
#include <iostream>

using namespace llvm;

namespace {

#define DEBUG_TYPE "IndirectBranchCounter"

cl::opt<std::string> OutputFilenameCLI("indirect-branch-counter-output",
                                       cl::desc("Specify output filename"),
                                       cl::value_desc("filename"));

bool runIndirectBranchCounter(Module &M) {
  auto OutputFilename = OutputFilenameCLI.getValue();
  if (OutputFilename.empty()) {
    auto EnvFilename = std::getenv("INDIRECT_BRANCH_COUNTER_OUTPUT");
    if (EnvFilename != nullptr) {
      OutputFilename = EnvFilename;
    }
  }

  if (OutputFilename.empty()) {
    OutputFilename = "indirect-branch-counter.txt";
  }

  errs() << "IndirectBranchCounter: output: " << OutputFilename << '\n';

  unsigned long total = 0;
  for (auto &F : M) {
    for (auto &I : instructions(F)) {
      CallBase *CI = dyn_cast<CallBase>(&I);
      if (CI && CI->isIndirectCall()) {
        LLVM_DEBUG(dbgs() << "IndirectBranchCounter: " << F.getName() << "\n\t"
                          << *CI << '\n');
        total++;
      }
    }
  }

  errs() << "IndirectBranchCounter: Total indirect call-sites: " << total
         << '\n';

  std::ofstream OutFile(OutputFilename);
  OutFile << total << std::endl;
  OutFile.close();

  return false;
}

struct LegacyIndirectBranchCounter : public ModulePass {
  static char ID;
  LegacyIndirectBranchCounter() : ModulePass(ID) {}
  bool runOnModule(Module &M) override { return runIndirectBranchCounter(M); }
};

struct IndirectBranchCounter : PassInfoMixin<IndirectBranchCounter> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) {
    if (!runIndirectBranchCounter(M))
      return PreservedAnalyses::all();
    return PreservedAnalyses::none();
  }
};

} // namespace

char LegacyIndirectBranchCounter::ID = 0;

static RegisterPass<LegacyIndirectBranchCounter>
    X("indirect-branch-counter", "Pass that counts indirect branches",
      false /* Only looks at CFG */, false /* Analysis Pass */);

/* New PM Registration */
llvm::PassPluginLibraryInfo getIndirectBranchCounterPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "IndirectBranchCounter", LLVM_VERSION_STRING,
        [](PassBuilder &PB) {
          PB.registerOptimizerLastEPCallback(
              [](llvm::ModulePassManager &PM,
#if LLVM_VERSION_MAJOR <= 13
                 llvm::PassBuilder::OptimizationLevel Level) {
#else
                 llvm::OptimizationLevel Level) {
#endif
                PM.addPass(IndirectBranchCounter());
              });
          PB.registerPipelineParsingCallback(
              [](StringRef Name, llvm::ModulePassManager &PM,
                 ArrayRef<llvm::PassBuilder::PipelineElement>) {
                if (Name == "indirect-branch-counter") {
                  PM.addPass(IndirectBranchCounter());
                  return true;
                }
                return false;
              });
        }
  };
}

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getIndirectBranchCounterPluginInfo();
}
