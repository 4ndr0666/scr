# Ψ-4ndr0666 Production Build System
# Artifact: bravetoggle (Brave pause/resume utility)
# Version: 1.0.0

CC     = cc
CFLAGS = -Wall -Wextra -std=c99 -D_DEFAULT_SOURCE -D_POSIX_C_SOURCE=200809L \
         -D_XOPEN_SOURCE=500 -O3 -march=native
TARGET = bravetoggle
SRC    = bravetoggle.c
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
