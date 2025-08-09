local M = {}

M.defaults = {
	model = "generic",
	log_level = "warn", -- "info", "warn", "error"
	context_warning_threshold = 0.4, -- Warn when buffers use >40% of context window
}

--- Merge user configuration with defaults
--- @param user_config table|nil User provided configuration
--- @return table config Merged configuration
function M.setup(user_config)
	user_config = user_config or {}

	-- Deep merge user config with defaults
	local config = vim.tbl_deep_extend("force", M.defaults, user_config)

	-- Validate log_level
	local valid_levels = { info = true, warn = true, error = true }
	if not valid_levels[config.log_level] then
		vim.notify("Invalid log_level '" .. tostring(config.log_level) .. "'. Using 'warn'.", vim.log.levels.WARN)
		config.log_level = "warn"
	end

	-- Store the merged config
	M.current = config

	return config
end

--- Get current configuration
--- @return table config Current configuration
function M.get()
	return M.current or M.defaults
end

return M
