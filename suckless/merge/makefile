# Ψ-4ndr0666 Production Build System
# Artifact: merge (Video/Image Unifier)
# Version: 3.1.1

CC = cc
# Includes _DEFAULT_SOURCE to handle modern POSIX/Linux extensions
CFLAGS = -Wall -Wextra -std=c99 -D_POSIX_C_SOURCE=200809L -D_DEFAULT_SOURCE -O3 -march=native
TARGET = merge
SRC = merge.c
PREFIX = /usr/local/bin

.PHONY: all clean install uninstall

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)
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
