describe("gem_install module", function()
  local gem_install
  local test_dir

  before_each(function()
    -- Reset module cache to get fresh state
    package.loaded["gem_install"] = nil
    package.loaded["gem_install.cache"] = nil
    package.loaded["gem_install.installer"] = nil

    test_dir = _G.test_helpers.create_temp_dir()
    gem_install = require("gem_install")
  end)

  after_each(function()
    _G.test_helpers.cleanup_temp_dir(test_dir)
  end)

  describe("config", function()
    it("should have default bundle_install_timeout", function()
      assert.is_number(gem_install.config.bundle_install_timeout)
      assert.equals(60000, gem_install.config.bundle_install_timeout)
    end)

    it("should have default cache_file path", function()
      assert.is_string(gem_install.config.cache_file)
      assert.is_true(gem_install.config.cache_file:match("bundle_install_cache.json") ~= nil)
    end)

    it("should have default log_file path", function()
      assert.is_string(gem_install.config.log_file)
      assert.is_true(gem_install.config.log_file:match("bundle_gem_debug.log") ~= nil)
    end)

    it("should have default cache_ttl_days", function()
      assert.is_number(gem_install.config.cache_ttl_days)
      assert.equals(7, gem_install.config.cache_ttl_days)
    end)
  end)

  describe("setup", function()
    it("should merge user config with defaults", function()
      gem_install.setup({
        bundle_install_timeout = 30000,
      })

      assert.equals(30000, gem_install.config.bundle_install_timeout)
      -- Other defaults should remain
      assert.is_true(gem_install.config.cache_file:match("bundle_install_cache.json") ~= nil)
    end)

    it("should create user commands", function()
      gem_install.setup({})

      -- Check that commands were created
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.GemInstall)
      assert.is_not_nil(commands.GemInstallLog)
      assert.is_not_nil(commands.GemInstallLogClear)
      assert.is_not_nil(commands.GemInstallCache)
      assert.is_not_nil(commands.GemInstallCacheClear)
    end)
  end)

  describe("install", function()
    it("should be a function", function()
      assert.is_function(gem_install.install)
    end)

    it("should delegate to installer module", function()
      -- Just verify it can be called without error for existing executable
      local called = false
      gem_install.install("ls", function()
        called = true
      end)
      assert.is_true(called)
    end)
  end)

  describe("clear_cache", function()
    it("should be a function", function()
      assert.is_function(gem_install.clear_cache)
    end)
  end)

  describe("clear_log", function()
    it("should be a function", function()
      assert.is_function(gem_install.clear_log)
    end)

    it("should notify when log file does not exist", function()
      gem_install.config.log_file = test_dir .. "/nonexistent.log"

      local notifier = _G.test_helpers.capture_notifications()
      gem_install.clear_log()
      notifier.restore()

      assert.equals(1, #notifier.notifications)
      assert.is_true(notifier.notifications[1].msg:match("No bundle/gem debug log found") ~= nil)
    end)

    it("should delete log file and notify when it exists", function()
      local log_file = test_dir .. "/test.log"
      gem_install.config.log_file = log_file

      -- Create the log file
      local file = io.open(log_file, "w")
      file:write("test log content")
      file:close()

      local notifier = _G.test_helpers.capture_notifications()
      gem_install.clear_log()
      notifier.restore()

      assert.equals(0, vim.fn.filereadable(log_file))
      assert.equals(1, #notifier.notifications)
      assert.is_true(notifier.notifications[1].msg:match("cleared") ~= nil)
    end)
  end)
end)
