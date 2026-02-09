local M = {}

local cache = require("gem_install.cache")

local function get_config()
  return require("gem_install").config
end

local function debug_log(msg)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local log_line = string.format("[%s] %s\n", timestamp, msg)

  vim.schedule(function()
    local file = io.open(get_config().log_file, "a")
    if file then
      file:write(log_line)
      file:close()
    end
  end)
end

function M.install(gem_name, callback)
  local function invoke_callback(installed, err)
    if callback then
      callback(installed, gem_name, err)
    end
  end

  -- Step 1: Check if the executable already exists - if so, we're done
  if vim.fn.executable(gem_name) == 1 then
    debug_log(string.format("%s executable found, skipping installation", gem_name))
    invoke_callback(true, nil)
    return
  end

  local gemfile = vim.fn.findfile("Gemfile", ".;")
  local cwd = gemfile ~= "" and vim.fn.fnamemodify(gemfile, ":p:h") or vim.fn.getcwd()
  -- Normalize the path (remove trailing slash)
  cwd = cwd:gsub("/$", "")

  local cache_data = cache.load()
  if cache_data[cwd] and cache_data[cwd].failed then
    debug_log(
      string.format(
        "Skipping install for %s (previously failed). Remove cache to retry: rm %s",
        gem_name,
        get_config().cache_file
      )
    )
    invoke_callback(false, "Skipping install (previously failed)")
    return
  end

  local progress = require("fidget.progress")
  local handle = progress.handle.create({
    title = gem_name,
    message = "checking...",
    lsp_client = { name = gem_name },
  })

  local function run_gem_install()
    handle.message = "gem install " .. gem_name .. "..."
    local gem_output = {}
    vim.fn.jobstart("gem install " .. gem_name, {
      cwd = cwd,
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= "" then
              table.insert(gem_output, line)
              handle.message = line
            end
          end
        end
      end,
      on_stderr = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= "" then
              table.insert(gem_output, line)
              handle.message = line
            end
          end
        end
      end,
      on_exit = function(_, gem_exit_code)
        if gem_exit_code == 0 then
          handle:finish()
          cache_data[cwd] = { failed = false }
          cache.save(cache_data)
          if #gem_output > 0 then
            debug_log(string.format("gem install %s succeeded:\n%s", gem_name, table.concat(gem_output, "\n")))
          end
          invoke_callback(true, nil)
        else
          local message = string.format("gem install %s failed. Run manually if needed.", gem_name)
          handle.message = message
          handle:cancel()
          if #gem_output > 0 then
            message = message .. "\n" .. table.concat(gem_output, "\n")
          end
          cache_data[cwd] = { failed = true, reason = "gem_install_failed", gem = gem_name }
          cache.save(cache_data)
          debug_log(message)
          invoke_callback(false, message)
        end
      end,
    })
  end

  local function run_bundle_install()
    handle.message = "bundle install..."
    local output = {}
    local bundle_job_id
    local timeout_ms = get_config().bundle_install_timeout
    local timed_out = false

    local timer = vim.defer_fn(function()
      if bundle_job_id then
        timed_out = true
        vim.fn.jobstop(bundle_job_id)
      end
    end, timeout_ms)

    bundle_job_id = vim.fn.jobstart("bundle install", {
      cwd = cwd,
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= "" then
              table.insert(output, line)
              handle.message = line
            end
          end
        end
      end,
      on_stderr = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= "" then
              table.insert(output, line)
              handle.message = line
            end
          end
        end
      end,
      on_exit = function(_, exit_code)
        if timer then
          pcall(function()
            timer:stop()
          end)
        end

        if timed_out then
          local message =
            string.format("bundle install timed out after %ds. Skipping %s setup.", timeout_ms / 1000, gem_name)
          handle.message = message
          handle:cancel()
          cache_data[cwd] = { failed = true, reason = "timeout" }
          cache.save(cache_data)
          if #output > 0 then
            message = message .. "\nOutput:\n" .. table.concat(output, "\n")
          end
          debug_log(message)
          invoke_callback(false, message)
          return
        end

        if exit_code == 0 then
          if #output > 0 then
            debug_log(string.format("bundle install succeeded:\n%s", table.concat(output, "\n")))
          end
          handle:finish()
          cache_data[cwd] = { failed = false }
          cache.save(cache_data)
          invoke_callback(true, nil)
        else
          handle.message = "bundle install failed"
          handle:cancel()
          cache_data[cwd] = { failed = true, reason = "bundle_install_failed" }
          cache.save(cache_data)
          local message = string.format(
            "bundle install failed. Skipping %s setup. Run 'bundle install' manually if needed, it will not be attempted again automatically.",
            gem_name
          )
          if #output > 0 then
            message = message .. "\n" .. table.concat(output, "\n")
          end
          debug_log(message)
          invoke_callback(false, message)
        end
      end,
    })
  end

  -- Step 2: If bundle is available, try bundle check/install
  if vim.fn.executable("bundle") == 1 and gemfile ~= "" then
    vim.fn.jobstart("bundle check", {
      cwd = cwd,
      on_exit = function(_, check_exit_code)
        if check_exit_code == 0 then
          -- Bundle is satisfied, we're done
          handle:finish()
          cache_data[cwd] = { failed = false }
          cache.save(cache_data)
          debug_log(string.format("bundle check passed for %s", gem_name))
          invoke_callback(true, nil)
        else
          run_bundle_install()
        end
      end,
    })
  else
    -- Step 3: No bundle available, fall back to gem install
    debug_log("bundle not available, falling back to gem install")
    run_gem_install()
  end
end

return M
