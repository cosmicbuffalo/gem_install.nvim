local M = {}

M.config = {
	bundle_install_timeout = 60000,
	cache_file = vim.fn.stdpath("cache") .. "/bundle_install_cache.json",
	log_file = vim.fn.stdpath("log") .. "/bundle_gem_debug.log",
}

local cache = require("gem_install.cache")
local installer = require("gem_install.installer")

function M.install(gem_name)
	installer.install(gem_name)
end

function M.open_log()
	vim.cmd("edit " .. M.config.log_file)
end

function M.clear_log()
	if vim.fn.filereadable(M.config.log_file) == 1 then
		vim.fn.delete(M.config.log_file)
		vim.notify("[gem_install.nvim] Bundle/gem debug log cleared.", vim.log.levels.INFO)
	else
		vim.notify("[gem_install.nvim] No bundle/gem debug log found.", vim.log.levels.INFO)
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
