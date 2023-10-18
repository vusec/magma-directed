#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <limits>

#include "lib.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    const auto mx_val = std::numeric_limits<int>::max();
    std::cout << "val: " << 42 % mx_val << std::endl;

    if (size < sizeof(int))
        return 0;

    if (reinterpret_cast<const int *>(data)[0] > mx_val)
        target_function();

    return 0;
}
