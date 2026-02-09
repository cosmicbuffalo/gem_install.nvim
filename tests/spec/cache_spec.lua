describe("cache module", function()
  local cache
  local test_dir

  before_each(function()
    -- Reset module cache to get fresh state
    package.loaded["gem_install"] = nil
    package.loaded["gem_install.cache"] = nil

    test_dir = _G.test_helpers.create_temp_dir()

    -- Set up gem_install with test cache file
    local gem_install = require("gem_install")
    gem_install.config.cache_file = test_dir .. "/test_cache.json"
    gem_install.config.log_file = test_dir .. "/test_log.txt"

    cache = require("gem_install.cache")
  end)

  after_each(function()
    _G.test_helpers.cleanup_temp_dir(test_dir)
  end)

  describe("load", function()
    it("should return empty table when cache file does not exist", function()
      local data = cache.load()
      assert.is_table(data)
      assert.are.same({}, data)
    end)

    it("should return cached data when file exists", function()
      -- Write some cache data manually
      local cache_file = require("gem_install").config.cache_file
      local file = io.open(cache_file, "w")
      file:write('{"test_dir":{"failed":true,"reason":"test"}}')
      file:close()

      local data = cache.load()
      assert.is_table(data)
      assert.is_not_nil(data.test_dir)
      assert.is_true(data.test_dir.failed)
      assert.equals("test", data.test_dir.reason)
    end)

    it("should return empty table when cache file contains invalid JSON", function()
      local cache_file = require("gem_install").config.cache_file
      local file = io.open(cache_file, "w")
      file:write("not valid json {{{")
      file:close()

      local data = cache.load()
      assert.is_table(data)
      assert.are.same({}, data)
    end)
  end)

  describe("save", function()
    it("should write cache data to file", function()
      local test_data = {
        ["/some/path"] = { failed = true, reason = "bundle_install_failed" },
      }

      cache.save(test_data)

      local cache_file = require("gem_install").config.cache_file
      local file = io.open(cache_file, "r")
      assert.is_not_nil(file)
      local content = file:read("*a")
      file:close()

      local decoded = vim.json.decode(content)
      assert.is_true(decoded["/some/path"].failed)
      assert.equals("bundle_install_failed", decoded["/some/path"].reason)
    end)

    it("should overwrite existing cache data", function()
      cache.save({ old = { failed = true } })
      cache.save({ new = { failed = false } })

      local data = cache.load()
      assert.is_nil(data.old)
      assert.is_not_nil(data.new)
      assert.is_false(data.new.failed)
    end)
  end)

  describe("clear", function()
    it("should delete the cache file and notify", function()
      -- Create a cache file first
      cache.save({ test = { failed = true } })

      local notifier = _G.test_helpers.capture_notifications()

      cache.clear()

      notifier.restore()

      local cache_file = require("gem_install").config.cache_file
      assert.equals(0, vim.fn.filereadable(cache_file))
      assert.equals(1, #notifier.notifications)
      assert.is_true(notifier.notifications[1].msg:match("cleared") ~= nil)
    end)

    it("should notify when no cache file exists", function()
      local notifier = _G.test_helpers.capture_notifications()

      cache.clear()

      notifier.restore()

      assert.equals(1, #notifier.notifications)
      assert.is_true(notifier.notifications[1].msg:match("No bundle/gem install cache found") ~= nil)
    end)
  end)
end)
