local M = {}

local function get_cache_file()
    return require("gem_install").config.cache_file
end

--- @return table
function M.load()
    local cache_file = get_cache_file()
    local file = io.open(cache_file, "r")
    if not file then
        return {}
    end
    local content = file:read("*a")
    file:close()
    local success, cache = pcall(vim.json.decode, content)
    return success and cache or {}
end

--- @param cache table
function M.save(cache)
    local cache_file = get_cache_file()
    local file = io.open(cache_file, "w")
    if file then
        file:write(vim.json.encode(cache))
        file:close()
    end
end

function M.clear()
    local cache_file = get_cache_file()
    if vim.fn.filereadable(cache_file) == 1 then
        vim.fn.delete(cache_file)
        vim.notify(
            "Bundle/gem install cache cleared. Failed projects will be retried on next open.",
            vim.log.levels.INFO
        )
    else
        vim.notify("No bundle/gem install cache found.", vim.log.levels.INFO)
    end
end

function M.open()
    local cache_file = get_cache_file()
    vim.cmd("edit " .. cache_file)
end

return M
