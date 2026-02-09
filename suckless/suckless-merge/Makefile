# suckless-merge — Ψ-4ndr0666 build configuration
# Usage:
#   make
#   make install
#   make uninstall
#   make clean

.POSIX:

CC      = cc
# Note: _POSIX_C_SOURCE and _DEFAULT_SOURCE are defined in the source file
# to prevent "redefined" warnings, they are omitted here.
CFLAGS  = -Wall -Wextra -std=c99 -O2 -pedantic
LDFLAGS = -s

PREFIX  = /usr/local
BINDIR  = $(PREFIX)/bin

TARGET  = merge
SRC     = suckless-merge.c
OBJ     = $(SRC:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $(OBJ)

.c.o:
	$(CC) $(CFLAGS) -c $<

install: $(TARGET)
	mkdir -p $(DESTDIR)$(BINDIR)
	install -m 755 $(TARGET) $(DESTDIR)$(BINDIR)/$(TARGET)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(TARGET)

clean:
	rm -f $(TARGET) $(OBJ)

.PHONY: all install uninstall clean
