# Magma: A Ground-Truth Fuzzing Benchmark

This is an extension to the original Magma for directed fuzzing. See [LibAFLGo](https://github.com/vusec/libaflgo).

This extension is based on the original Magma v1.2, see
[diff](https://github.com/vusec/magma-directed/compare/v1.2..directed)

The [original documentation](https://hexhive.epfl.ch/magma) should still be valid for the most part.

Beside integrating additional fuzzers, we extended the evaluation infrastructure to run directed
fuzzers, where a single target bug is compiled in the SUT. To this end, the `captain` tool can be
configured to run specific harness-bug pairs (e.g. `DEFAULT_<target>_<program>_BUGS`).
