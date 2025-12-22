# suckless-merge — minimal build
# Usage:
#   make
#   make install
#   make uninstall
#   make clean

CC      = cc
CFLAGS  = -Wall -Wextra -std=c99 -O2
LDFLAGS =
PREFIX  = /usr/local
BINDIR  = $(PREFIX)/bin

TARGET  = merge
SRC     = merge.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(LDFLAGS)

install: $(TARGET)
	mkdir -p $(BINDIR)
	cp -f $(TARGET) $(BINDIR)
	chmod 755 $(BINDIR)/$(TARGET)

uninstall:
	rm -f $(BINDIR)/$(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: all install uninstall clean
