BIN := bin
PROGS := $(patsubst %.c,$(BIN)/%,$(wildcard test*.c))
PROGS += $(patsubst %.cpp,$(BIN)/%,$(wildcard test*.cpp))

CFLAGS += -Wall
CXXFLAGS += -Wall -std=c++11

LIBS += -l:lib.a

all: $(PROGS)

$(BIN):
	mkdir -p $@

$(BIN)/%: %.c lib.a $(BIN)
	$(CC) $(CFLAGS) -o $@ $< -L. $(LDFLAGS) $(LIBS)

$(BIN)/%: %.cpp lib.a $(BIN)
	$(CXX) $(CXXFLAGS) -o $@ $< -L. $(LDFLAGS) $(LIBS)

lib.a: lib.o
	ar rcs $@ $<

clean:
	rm -rf $(BIN) lib.o lib.a

.PHONY: all clean
