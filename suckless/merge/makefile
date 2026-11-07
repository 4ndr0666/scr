# merge 3.2.0 — portable release flags; DESTDIR-aware staging.
CC = cc
CPPFLAGS += -D_POSIX_C_SOURCE=200809L -D_DEFAULT_SOURCE
CFLAGS ?= -O2 -g
CFLAGS += -Wall -Wextra -Wpedantic -std=c99
TARGET = merge
SRC = merge.c
PREFIX ?= /usr/local/bin
DESTDIR ?=
.PHONY: all clean install uninstall test
all: $(TARGET)
$(TARGET): $(SRC) makefile
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $(SRC) $(LDLIBS)
clean:
	$(RM) -- "$(TARGET)"
install: $(TARGET)
	install -d -- "$(DESTDIR)$(PREFIX)"
	install -m 755 -- "$(TARGET)" "$(DESTDIR)$(PREFIX)/$(TARGET)"
uninstall:
	$(RM) -- "$(DESTDIR)$(PREFIX)/$(TARGET)"
test: $(TARGET)
	python3 tests.py
