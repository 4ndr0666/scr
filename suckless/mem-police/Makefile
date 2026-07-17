# Ψ-4ndr0666 Production Build System
# Artifact: mem-police (Memory Policing Daemon)
# Version: 3.2.0
#
# CHANGELOG (3.0 → 3.2.0):
#   - Version bumped to match mem-police.c 3.2.0 source.
#   - Added -D_GNU_SOURCE to CFLAGS: mem-police.c defines _GNU_SOURCE at the
#     top of file; making it explicit here keeps the Makefile, installer.sh,
#     and source header comment all in exact agreement.
#   - Added TESTER_INSTALLDIR := /usr/local/sbin — test scripts must not be
#     placed on the non-root PATH (/usr/local/bin) since they require root to
#     read /var/run/mem-police (mode 0700).
#   - install / uninstall updated to use TESTER_INSTALLDIR consistently.
#   - test target uses $(CURDIR)/$(TESTER) so `make -C /path test` is
#     idempotent regardless of the caller's working directory.
#   - Added lint-installer target; lint now runs shellcheck on both scripts.
#   - help updated to document all targets.

CC               := cc
CFLAGS           := -O2 -std=c11 -Wall -Wextra -pedantic \
                    -D_POSIX_C_SOURCE=200809L -D_GNU_SOURCE
LDFLAGS          := -lpcre2-8
TARGET           := mem-police
INSTALLDIR       := /usr/local/bin
TESTER_INSTALLDIR := /usr/local/sbin
TESTER           := mem-police-tester.sh
INSTALLER        := mem-police-installer.sh

.PHONY: all build install uninstall test lint lint-installer clean help

all: build

# Explicit file target leverages Make's timestamp tracking
$(TARGET): $(TARGET).c
	@echo "🏗️  Compiling $(TARGET)..."
	@$(CC) $(CFLAGS) -o $(TARGET) $(TARGET).c $(LDFLAGS)

build: $(TARGET)
	@echo "✅ Build complete!"

install: build
	@echo "📦 Installing $(TARGET) to $(INSTALLDIR)..."
	@install -m 0755 $(TARGET) $(INSTALLDIR)/
	@echo "📦 Installing $(TESTER) to $(TESTER_INSTALLDIR)..."
	@install -m 0755 $(TESTER) $(TESTER_INSTALLDIR)/
	@echo "✅ Installation complete!"

uninstall:
	@echo "🗑️  Removing $(INSTALLDIR)/$(TARGET)..."
	@rm -f $(INSTALLDIR)/$(TARGET)
	@echo "🗑️  Removing $(TESTER_INSTALLDIR)/$(TESTER)..."
	@rm -f $(TESTER_INSTALLDIR)/$(TESTER)
	@echo "✅ Uninstallation complete!"

test:
	@echo "🧪 Running integration test suite..."
	@if ! pgrep -x $(TARGET) >/dev/null 2>&1; then \
		echo "   -> Error: '$(TARGET)' daemon is not running. Please start it as root."; \
		exit 1; \
	fi
	@sudo $(CURDIR)/$(TESTER)

lint:
	@echo "🔍 Running shellcheck on $(TESTER)..."
	@shellcheck $(TESTER)
	@echo "✅ $(TESTER) lint passed."

lint-installer:
	@echo "🔍 Running shellcheck on $(INSTALLER)..."
	@shellcheck $(INSTALLER)
	@echo "✅ $(INSTALLER) lint passed."

clean:
	@echo "🧹 Cleaning up build artifacts..."
	@rm -f $(TARGET)
	@echo "✅ Cleaned."

help:
	@echo "mem-police Project Makefile (v3.2.0)"
	@echo "======================================"
	@echo "make build           Compile the $(TARGET) daemon"
	@echo "make install         Compile and install the daemon and tester"
	@echo "make uninstall       Remove installed files from $(INSTALLDIR) and $(TESTER_INSTALLDIR)"
	@echo "make test            Run the integration test suite (daemon must be running)"
	@echo "make lint            Run shellcheck on $(TESTER)"
	@echo "make lint-installer  Run shellcheck on $(INSTALLER)"
	@echo "make clean           Remove the compiled binary"
	@echo "make help            Show this help"
