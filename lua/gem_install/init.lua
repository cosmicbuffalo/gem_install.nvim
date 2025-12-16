local M = {}

M.config = {
    bundle_install_timeout = 60000,
    cache_file = vim.fn.stdpath("cache") .. "/bundle_install_cache.json",
    log_file = vim.fn.stdpath("log") .. "/bundle_gem_debug.log",
}

local cache = require("gem_install.cache")

local function debug_log(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_line = string.format("[%s] %s\n", timestamp, msg)

    vim.schedule(function()
        local file = io.open(M.config.log_file, "a")
        if file then
            file:write(log_line)
            file:close()
        end
    end)
end

--- @param gem_name string
function M.install(gem_name)
    local gemfile = vim.fn.findfile("Gemfile", ".;")
    if gemfile == "" then
        vim.notify("No Gemfile found in current directory or parents", vim.log.levels.WARN)
        return
    end

    local cwd = vim.fn.fnamemodify(gemfile, ":h")

    local cache_data = cache.load()
    if cache_data[cwd] and cache_data[cwd].failed then
        debug_log(
            string.format(
                "Skipping bundle install for %s (previously failed). Remove cache to retry: rm %s",
                gem_name,
                M.config.cache_file
            )
        )
        return
    end

    local progress = require("fidget.progress")
    local handle = progress.handle.create({
        title = gem_name,
        message = "checking bundle...",
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
                        debug_log(
                            string.format("gem install %s succeeded:\n%s", gem_name, table.concat(gem_output, "\n"))
                        )
                    end
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
                end
            end,
        })
    end

    local function check_and_install_gem()
        handle.message = "checking gem " .. gem_name .. "..."
        vim.fn.jobstart("gem list -i '^" .. gem_name .. "$'", {
            cwd = cwd,
            on_exit = function(_, gem_list_exit_code)
                if gem_list_exit_code == 0 then
                    handle.message = "already installed"
                    handle:finish()
                    cache_data[cwd] = { failed = false }
                    cache.save(cache_data)
                else
                    run_gem_install()
                end
            end,
        })
    end

    vim.fn.jobstart("bundle check", {
        cwd = cwd,
        on_exit = function(_, check_exit_code)
            if check_exit_code == 0 then
                check_and_install_gem()
                return
            end

            handle.message = "bundle install..."
            local output = {}
            local bundle_job_id
            local timeout_ms = M.config.bundle_install_timeout
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
                        local message = string.format(
                            "bundle install timed out after %ds. Skipping %s setup.",
                            timeout_ms / 1000,
                            gem_name
                        )
                        handle.message = message
                        handle:cancel()
                        cache_data[cwd] = { failed = true, reason = "timeout" }
                        cache.save(cache_data)
                        if #output > 0 then
                            message = message .. "\nOutput:\n" .. table.concat(output, "\n")
                        end
                        debug_log(message)
                        return
                    end

                    if exit_code == 0 then
                        if #output > 0 then
                            debug_log(string.format("bundle install succeeded:\n%s", table.concat(output, "\n")))
                        end
                        check_and_install_gem()
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
                    end
                end,
            })
        end,
    })
end

function M.open_log()
    vim.cmd("edit " .. M.config.log_file)
end

function M.clear_log()
    if vim.fn.filereadable(M.config.log_file) == 1 then
        vim.fn.delete(M.config.log_file)
        vim.notify("Bundle/gem debug log cleared.", vim.log.levels.INFO)
    else
        vim.notify("No bundle/gem debug log found.", vim.log.levels.INFO)
    end
end

function M.open_cache()
    cache.open()
end

function M.clear_cache()
    cache.clear()
end

local function setup_user_commands()
    vim.api.nvim_create_user_command("GemInstall", function(opts)
        M.install(opts.args)
    end, { nargs = 1, desc = "Install a Ruby gem" })

    vim.api.nvim_create_user_command("GemInstallLog", function()
        M.open_log()
    end, { desc = "Open bundle/gem debug log" })

    vim.api.nvim_create_user_command("GemInstallLogClear", function()
        M.clear_log()
    end, { desc = "Clear bundle/gem install debug log" })

    vim.api.nvim_create_user_command("GemInstallCache", function()
        M.open_cache()
    end, { desc = "Open bundle/gem install cache file" })

    vim.api.nvim_create_user_command("GemInstallCacheClear", function()
        M.clear_cache()
    end, { desc = "Clear bundle install failure cache" })
end

--- @param opts table|nil
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    setup_user_commands()
end

return M
