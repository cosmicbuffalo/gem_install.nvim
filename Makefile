.PHONY: test format lint clean setup-plenary check

# Setup plenary.nvim if not already present
setup-plenary:
	@if [ ! -d "/tmp/plenary.nvim" ]; then \
		echo "Cloning plenary.nvim to /tmp/plenary.nvim..."; \
		git clone --depth=1 https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim; \
	else \
		echo "plenary.nvim already exists at /tmp/plenary.nvim"; \
	fi

# Test with plenary
test: setup-plenary
	@echo "Running tests with plenary.nvim..."
	@PLENARY_DIR=/tmp/plenary.nvim nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "lua require('plenary.test_harness').test_directory('tests/spec', { minimal_init = 'tests/minimal_init.lua' })"

# Format code with stylua
format:
	@echo "Formatting Lua files with stylua..."
	@stylua lua/ tests/

# Lint with selene (if available)
lint:
	@echo "Linting Lua files..."
	@if command -v selene >/dev/null 2>&1; then \
		selene lua/ tests/; \
	else \
		echo "selene not found, skipping linting"; \
	fi

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -rf /tmp/gem_install_test_*

# Run all checks
check: format lint test
	@echo "All checks completed!"
