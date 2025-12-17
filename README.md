# gem_install.nvim

Install Ruby gems from Neovim! Handles `bundle install` and `gem install` with progress notifications and caching to prevent retries when installs fail. Useful for LSP servers and other tools that depend on gems being available.

## Features

- Runs `bundle check` before attempting installs
- Runs `bundle install` if needed (with configurable timeout)
- Installs gems via `gem install` if not already present
- Caches failures per-project to avoid repeated attempts
- Shows progress via [fidget.nvim](https://github.com/j-hui/fidget.nvim)
- Logs all output for debugging

## Dependencies

- [fidget.nvim](https://github.com/j-hui/fidget.nvim) (for progress UI)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "cosmicbuffalo/gem_install.nvim",
    opts = {},
    dependencies = { "j-hui/fidget.nvim" },
}
```


## Usage

```lua
require("gem_install").install("ruby-lsp")
```

## Configuration

```lua
-- Optional, below are built in defaults
require("gem_install").setup({
    -- Timeout for bundle install in milliseconds
    bundle_install_timeout = 60000,
    -- Cache file for tracking failed installs
    cache_file = vim.fn.stdpath("cache") .. "/bundle_install_cache.json",
    -- Log file for debug output
    log_file = vim.fn.stdpath("log") .. "/bundle_gem_debug.log",
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:GemInstall <gem>` | Install a gem |
| `:GemInstallLog` | Open the debug log file |
| `:GemInstallLogClear` | Clear the debug log |
| `:GemInstallCache` | Open the failure cache file |
| `:GemInstallCacheClear` | Clear failure cache (retries failed projects) |

## Caveats

- Requires a `Gemfile` in the current directory or a parent directory. The plugin will show a warning if no Gemfile is found.
- Once a project fails `bundle install`, it won't retry automatically. Use `:GemInstallCacheClear` to reset and try again.
- `bundle install` has a 60 second timeout by default (configurable via `bundle_install_timeout`).
