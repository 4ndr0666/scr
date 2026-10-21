# Ψ-4ndr0666 Production Build System
# Artifact: mem-police (Memory Policing Daemon)
# Version: 3.2.4

CC         := cc
CFLAGS     := -O2 -std=c11 -Wall -Wextra -pedantic -D_POSIX_C_SOURCE=200809L -D_GNU_SOURCE
LDFLAGS    := -lpcre2-8
TARGET     := mem-police
# Aligned with mem-police.service:
INSTALLDIR := /usr/local/bin
TESTER     := mem-police-tester.sh
INSTALLER  := mem-police-installer.sh
SERVICE    := mem-police.service
CONF       := mem-police.conf
UNITDIR    := /etc/systemd/system
CONFPATH   := /etc/mem_police.conf

.PHONY: all build install install-service uninstall test lint lint-installer clean help

all: build

# Explicit file target leverages Make's timestamp tracking
$(TARGET): $(TARGET).c
	@echo "🏗️  Compiling $(TARGET)..."
	@$(CC) $(CFLAGS) -o $(TARGET) $(TARGET).c $(LDFLAGS)

build: $(TARGET)
	@echo "✅ Build complete!"

install: build # Install the daemon and test script securely
	@echo "📦 Installing $(TARGET) to $(INSTALLDIR)..."
	@sudo install -m 0755 $(TARGET) $(INSTALLDIR)/
	@echo "📦 Installing $(TESTER) to $(INSTALLDIR)..."
	@sudo install -m 0755 $(TESTER) $(INSTALLDIR)/
	@echo "✅ Installation complete!"

install-service: # Install the systemd unit and, only if absent, the default config
	@echo "📦 Installing $(SERVICE) to $(UNITDIR)..."
	@sudo install -m 0644 $(SERVICE) $(UNITDIR)/
	@if [ -e $(CONFPATH) ]; then echo "   -> Keeping existing $(CONFPATH)"; else sudo install -m 0600 -o root -g root $(CONF) $(CONFPATH); fi
	@sudo chown root:root $(CONFPATH)
	@sudo chmod 0600 $(CONFPATH)
	@if command -v systemctl >/dev/null 2>&1; then sudo systemctl daemon-reload 2>/dev/null || echo "   -> systemd not running here; run 'systemctl daemon-reload' on the target host"; fi
	@echo "✅ Service installed (not enabled or started)."

uninstall: # Remove the installed files
	@echo "🗑️  Removing $(INSTALLDIR)/$(TARGET)..."
	@sudo rm -f $(INSTALLDIR)/$(TARGET)
	@echo "🗑️  Removing $(INSTALLDIR)/$(TESTER)..."
	@sudo rm -f $(INSTALLDIR)/$(TESTER)
	@echo "🗑️  Removing $(UNITDIR)/$(SERVICE) ($(CONFPATH) is kept: it is your data)..."
	@sudo rm -f $(UNITDIR)/$(SERVICE)
	@echo "✅ Uninstallation complete!"

test: # Run the integration test script
	@echo "🧪 Running integration test suite..."
	@if ! pgrep -x $(TARGET) >/dev/null 2>&1; then \
		echo "   -> Error: '$(TARGET)' daemon is not running. Please start it as root."; \
		exit 1; \
	fi
	@sudo $(CURDIR)/$(TESTER)

lint: # Run shellcheck on the test script
	@echo "🔍 Running shellcheck on the test script..."
	@shellcheck $(TESTER)

lint-installer: # Run shellcheck on the installer script
	@echo "🔍 Running shellcheck on the installer script..."
	@shellcheck $(INSTALLER)

clean: # Remove the compiled binary
	@echo "🧹 Cleaning up build artifacts..."
	@rm -f $(TARGET)
	@echo "✅ Cleaned."

help: # Show this help message
	@echo "mem-police Project Makefile"
	@echo "==========================="
	@echo "make build        Compile the $(TARGET) daemon"
	@echo "make install      Compile and install the daemon and tester"
	@echo "make install-service Install the systemd unit and default config"
	@echo "make uninstall    Remove installed files"
	@echo "make test         Run the integration test suite"
	@echo "make lint         Run shellcheck on the test script"
	@echo "make lint-installer Run shellcheck on the installer script"
	@echo "make clean        Remove the compiled binary"
	@echo "make help         Show this help"
