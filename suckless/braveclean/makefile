# Ψ-4ndr0666 Production Build System
# Artifact: braveclean (Browser Sanitizer)
# Version: 2.1.2

CC = cc
CFLAGS = -Wall -Wextra -std=c99 -D_DEFAULT_SOURCE -D_POSIX_C_SOURCE=200809L -D_XOPEN_SOURCE=500 -O3 -march=native
LDFLAGS = -lsqlite3
TARGET = braveclean
SRC = braveclean.c
PREFIX = /usr/local/bin

.PHONY: all clean install uninstall

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC) $(LDFLAGS)
	@echo "[+] Build complete: $(TARGET)"

clean:
	rm -f $(TARGET)
	@echo "[+] Cleaned build artifacts."

install: $(TARGET)
	install -m 755 $(TARGET) $(PREFIX)/$(TARGET)
	@echo "[+] Installed $(TARGET) to $(PREFIX)"

uninstall:
	rm -f $(PREFIX)/$(TARGET)
	@echo "[+] Uninstalled $(TARGET)"
