# suckless-bclean Makefile
# simple, explicit, portable

CC      = cc
CFLAGS  = -Wall -Wextra -std=c99 -O2
LDFLAGS = -lsqlite3

BIN     = braveclean
SRC     = braveclean.c

all: $(BIN)

$(BIN): $(SRC)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(LDFLAGS)

clean:
	rm -f $(BIN)

install: $(BIN)
	install -Dm755 $(BIN) /usr/local/bin/$(BIN)

uninstall:
	rm -f /usr/local/bin/$(BIN)

.PHONY: all clean install uninstall
