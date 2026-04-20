# Ψ-4ndr0666 Production Build System
# Artifact: mem-police (Memory Policing Daemon)
# Version: 3.0

CC         := cc
CFLAGS     := -O2 -std=c11 -Wall -Wextra -pedantic -D_POSIX_C_SOURCE=200809L
LDFLAGS    := -lpcre2-8
TARGET     := mem-police
# Aligned with mem-police.service:
INSTALLDIR := /usr/local/bin
TESTER     := mem-police-tester.sh

.PHONY: all build install uninstall test lint clean help

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

uninstall: # Remove the installed files
	@echo "🗑️  Removing $(INSTALLDIR)/$(TARGET)..."
	@sudo rm -f $(INSTALLDIR)/$(TARGET)
	@echo "🗑️  Removing $(INSTALLDIR)/$(TESTER)..."
	@sudo rm -f $(INSTALLDIR)/$(TESTER)
	@echo "✅ Uninstallation complete!"

test: # Run the integration test script
	@echo "🧪 Running integration test suite..."
	@if ! pgrep -x $(TARGET) >/dev/null 2>&1; then \
		echo "   -> Error: '$(TARGET)' daemon is not running. Please start it as root."; \
		exit 1; \
	fi
	@sudo ./${TESTER}

lint: # Run shellcheck on the test script
	@echo "🔍 Running shellcheck on the test script..."
	@shellcheck $(TESTER)

clean: # Remove the compiled binary
	@echo "🧹 Cleaning up build artifacts..."
	@rm -f $(TARGET)
	@echo "✅ Cleaned."

help: # Show this help message
	@echo "mem-police Project Makefile"
	@echo "==========================="
	@echo "make build        Compile the $(TARGET) daemon"
	@echo "make install      Compile and install the daemon and tester"
	@echo "make uninstall    Remove installed files"
	@echo "make test         Run the integration test suite"
	@echo "make lint         Run shellcheck on the test script"
	@echo "make clean        Remove the compiled binary"
	@echo "make help         Show this help"
