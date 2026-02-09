-- Minimal init.lua for running tests with plenary

local plenary_dir = os.getenv("PLENARY_DIR") or "/tmp/plenary.nvim"
local plugin_dir = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":p:h:h")

-- Add plenary and gem_install to runtime path
vim.opt.rtp:append(plenary_dir)
vim.opt.rtp:append(plugin_dir)

-- Load plenary
vim.cmd("runtime! plugin/plenary.vim")

-- Mock fidget.nvim (required dependency)
package.loaded["fidget"] = {}
package.loaded["fidget.progress"] = {
  handle = {
    create = function(_opts)
      return {
        message = "",
        finish = function() end,
        cancel = function() end,
      }
    end,
  },
}

-- Seed random number generator for unique directory names
math.randomseed(os.time() + vim.loop.hrtime())

-- Counter for unique directory names
local temp_dir_counter = 0

-- Helper function available to all tests
_G.test_helpers = {
  -- Create a temporary directory for testing
  create_temp_dir = function()
    temp_dir_counter = temp_dir_counter + 1
    local dir = "/tmp/gem_install_test_" .. os.time() .. "_" .. temp_dir_counter .. "_" .. math.random(100000, 999999)
    vim.fn.mkdir(dir, "p")
    return dir
  end,

  -- Clean up a temporary directory
  cleanup_temp_dir = function(dir)
    if dir and dir:match("^/tmp/gem_install_test_") then
      vim.fn.delete(dir, "rf")
    end
  end,

  -- Wait for async operation to complete
  wait_for = function(condition, timeout_ms)
    timeout_ms = timeout_ms or 5000
    local ok = vim.wait(timeout_ms, condition, 10)
    return ok
  end,

  -- Capture vim.notify calls
  capture_notifications = function()
    local notifications = {}
    local original_notify = vim.notify

    vim.notify = function(msg, level, opts)
      table.insert(notifications, {
        msg = msg,
        level = level,
        opts = opts,
      })
    end

    return {
      notifications = notifications,
      restore = function()
        vim.notify = original_notify
      end,
    }
  end,

  -- Create a mock executable script
  create_mock_executable = function(dir, name)
    local path = dir .. "/" .. name
    local file = io.open(path, "w")
    if file then
      file:write("#!/bin/sh\nexit 0\n")
      file:close()
      vim.fn.system("chmod +x " .. vim.fn.shellescape(path))
    end
    return path
  end,

  -- Create a Gemfile in a directory
  create_gemfile = function(dir, content)
    content = content or 'source "https://rubygems.org"\n'
    local path = dir .. "/Gemfile"
    local file = io.open(path, "w")
    if file then
      file:write(content)
      file:close()
    end
    return path
  end,
}
