# Makefile for kube-ctx-manager

.PHONY: install uninstall test lint clean format help

# Default target
all: test lint

# Installation
install:
	@echo "Installing kube-ctx-manager..."
	./install.sh

# Uninstallation
uninstall:
	@echo "Uninstalling kube-ctx-manager..."
	./uninstall.sh

# Testing
test:
	@echo "Running tests..."
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/; \
	else \
		echo "bats-core not found. Install with: brew install bats-core"; \
		exit 1; \
	fi

test-verbose:
	@echo "Running tests with verbose output..."
	@if command -v bats >/dev/null 2>&1; then \
		bats -t tests/; \
	else \
		echo "bats-core not found. Install with: brew install bats-core"; \
		exit 1; \
	fi

# Linting
lint:
	@echo "Running shellcheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck lib/*.sh *.bash *.zsh install.sh uninstall.sh; \
	else \
		echo "shellcheck not found. Install with: brew install shellcheck"; \
		exit 1; \
	fi

# Format (shell formatting is limited, but we can check basic style)
format:
	@echo "Checking shell script formatting..."
	@echo "Note: Consider using shfmt for formatting: go install mvdan.cc/sh/v3/cmd/shfmt@latest"

# Clean
clean:
	@echo "Cleaning up test files..."
	rm -f test-results/*
	rm -f coverage/*
	rm -f *.tmp *.temp

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	@if command -v brew >/dev/null 2>&1; then \
		brew install bats-core shellcheck fzf kubectl; \
	else \
		echo "Please install bats-core, shellcheck, fzf, and kubectl manually"; \
	fi

# Local testing
test-local:
	@echo "Testing local installation..."
	@echo "Sourcing bash version..."
	bash -c "source ./kube-ctx-manager.bash && command -v kx"
	@echo "Sourcing zsh version..."
	@if command -v zsh >/dev/null 2>&1; then \
		zsh -c "source ./kube-ctx-manager.plugin.zsh && command -v kx"; \
	else \
		echo "Zsh not available, skipping zsh test"; \
	fi

# Release preparation
release-check:
	@echo "Preparing for release..."
	@echo "Running full test suite..."
	$(MAKE) test
	@echo "Running lint checks..."
	$(MAKE) lint
	@echo "Checking for TODO/FIXME comments..."
	@grep -r "TODO\|FIXME" lib/ --include="*.sh" || echo "No TODO/FIXME found"
	@echo "Checking documentation..."
	@if [ -f README.md ]; then \
		echo "README.md exists"; \
	else \
		echo "ERROR: README.md missing"; \
		exit 1; \
	fi

# Help
help:
	@echo "Available targets:"
	@echo "  install      - Install kube-ctx-manager"
	@echo "  uninstall    - Uninstall kube-ctx-manager"
	@echo "  test         - Run tests"
	@echo "  test-verbose - Run tests with verbose output"
	@echo "  lint         - Run shellcheck linting"
	@echo "  format       - Check formatting"
	@echo "  clean        - Clean up temporary files"
	@echo "  dev-setup    - Install development dependencies"
	@echo "  test-local   - Test local installation"
	@echo "  release-check- Prepare for release"
	@echo "  help         - Show this help message"
