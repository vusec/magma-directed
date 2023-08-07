#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "lib.h"

struct mystruct {
    void (*fn)();
};

#define NOINLINE __attribute__((noinline))

void NOINLINE set_fn(struct mystruct *s, void (*fn)())
{
    s->fn = fn;
}

void NOINLINE call_fn(struct mystruct *s)
{
    s->fn();
}

void NOINLINE foo()
{
    target_function();
}

void NOINLINE bar()
{
    puts("bar");
}

void NOINLINE baz()
{
    puts("baz");
    bar();
}

void NOINLINE indir1()
{
    puts("indir1");
    // XXX: needs a call to a function that would not directly reach the target
    bar();
}

void NOINLINE indir2()
{
    puts("indir2");
    // XXX: needs a call to a function that would not directly reach the target
    baz();
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    if (size < 2) {
        return 0;
    }

    struct mystruct s;

    void (*fn)() = NULL;
    if (data[0] < 42) {
        fn = indir1;
    } else {
        fn = indir2;
    }

    // XXX: removing this indirection and calling fn() directly makes SVF catch the indirect edges
    // into the call graph without any complex pointer analisys
    set_fn(&s, fn);
    call_fn(&s);

    if (data[1] == 42) {
        foo();
    }

    return 0;
}
