describe("installer module", function()
  local installer
  local cache
  local test_dir
  local original_cwd

  before_each(function()
    -- Reset module cache to get fresh state
    package.loaded["gem_install"] = nil
    package.loaded["gem_install.cache"] = nil
    package.loaded["gem_install.installer"] = nil

    test_dir = _G.test_helpers.create_temp_dir()
    original_cwd = vim.fn.getcwd()

    -- Set up gem_install with test cache file
    local gem_install = require("gem_install")
    gem_install.config.cache_file = test_dir .. "/test_cache.json"
    gem_install.config.log_file = test_dir .. "/test_log.txt"
    gem_install.config.bundle_install_timeout = 5000

    cache = require("gem_install.cache")
    installer = require("gem_install.installer")
  end)

  after_each(function()
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    _G.test_helpers.cleanup_temp_dir(test_dir)
  end)

  describe("install", function()
    describe("when executable already exists", function()
      it("should succeed immediately without installation", function()
        -- "ls" is a common executable that should exist
        local callback_called = false
        local callback_result = nil

        installer.install("ls", function(installed, gem_name, err)
          callback_called = true
          callback_result = { installed = installed, gem_name = gem_name, err = err }
        end)

        assert.is_true(callback_called)
        assert.is_true(callback_result.installed)
        assert.equals("ls", callback_result.gem_name)
        assert.is_nil(callback_result.err)
      end)
    end)

    describe("when cache indicates previous failure", function()
      it("should skip installation and return error", function()
        -- Create a project directory with Gemfile
        local project_dir = test_dir .. "/project"
        vim.fn.mkdir(project_dir, "p")
        _G.test_helpers.create_gemfile(project_dir)

        -- Mark as failed in cache using the absolute path
        local abs_project_dir = vim.fn.fnamemodify(project_dir, ":p"):gsub("/$", "")
        cache.save({ [abs_project_dir] = { failed = true, reason = "bundle_install_failed" } })

        -- Change to project directory so Gemfile is found
        vim.cmd("cd " .. vim.fn.fnameescape(project_dir))

        local callback_called = false
        local callback_result = nil

        -- Use a gem name that won't be found as executable
        installer.install("nonexistent-gem-12345", function(installed, gem_name, err)
          callback_called = true
          callback_result = { installed = installed, gem_name = gem_name, err = err }
        end)

        -- The callback is synchronous when cache indicates failure
        assert.is_true(callback_called)
        assert.is_false(callback_result.installed)
        assert.is_not_nil(callback_result.err)
        assert.is_true(callback_result.err:match("previously failed") ~= nil)
      end)
    end)

    describe("when bundle is not available", function()
      it("should fall back to gem install path", function()
        -- Create a directory without Gemfile
        local project_dir = test_dir .. "/no_gemfile"
        vim.fn.mkdir(project_dir, "p")
        vim.cmd("cd " .. vim.fn.fnameescape(project_dir))

        -- Mock executable check to ensure bundle is not found but gem is
        local original_executable = vim.fn.executable
        local original_jobstart = vim.fn.jobstart
        local gem_install_called = false

        vim.fn.executable = function(name)
          if name == "bundle" or name == "test-gem-xyz" then
            return 0
          end
          return original_executable(name)
        end

        -- Mock jobstart to capture what command is run
        vim.fn.jobstart = function(cmd, opts)
          if type(cmd) == "string" and cmd:match("^gem install") then
            gem_install_called = true
            -- Simulate immediate failure
            vim.schedule(function()
              if opts and opts.on_exit then
                opts.on_exit(nil, 1)
              end
            end)
            return 1
          end
          return original_jobstart(cmd, opts)
        end

        local callback_called = false

        installer.install("test-gem-xyz", function(_installed, _gem_name, _err)
          callback_called = true
        end)

        -- Wait for async operations
        _G.test_helpers.wait_for(function()
          return callback_called
        end, 5000)

        vim.fn.executable = original_executable
        vim.fn.jobstart = original_jobstart

        -- The key assertion: gem install path was taken since bundle wasn't available
        assert.is_true(gem_install_called, "Expected gem install to be called when bundle is unavailable")
      end)
    end)

    describe("callback invocation", function()
      it("should call callback with gem_name parameter", function()
        local received_gem_name = nil

        installer.install("ls", function(_installed, gem_name, _err)
          received_gem_name = gem_name
        end)

        assert.equals("ls", received_gem_name)
      end)

      it("should not error when callback is nil", function()
        -- Should not throw
        installer.install("ls", nil)
      end)
    end)
  end)
end)
