BIN := bin
PROGS := $(patsubst %.c,$(BIN)/%,$(wildcard test*.c))

CFLAGS += -Wall

all: $(PROGS)

$(BIN):
	mkdir -p $@

$(BIN)/%: %.c lib.a $(BIN)
	$(CC) $(CFLAGS) -o $@ $< -L. $(LDFLAGS) -l:lib.a $(LIBS)

lib.a: lib.o
	ar rcs $@ $<

clean:
	rm -rf $(BIN) lib.o lib.a

.PHONY: all clean
