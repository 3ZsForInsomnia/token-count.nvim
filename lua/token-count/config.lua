local M = {}

M.defaults = {
	model = "gpt-4",
	log_level = "warn", -- "info", "warn", "error"
	context_warning_threshold = 0.4, -- Warn when buffers use >40% of context window
	enable_official_anthropic_counter = false, -- Use official Anthropic API for token counting
	enable_official_gemini_counter = false, -- Use official Gemini API for token counting
	cache = {
		enabled = true,
		interval = 30000, -- 30 seconds
		max_files_per_batch = 10,
		cache_ttl = 300000, -- 5 minutes
		placeholder_text = "⋯",
	},
}

--- @param user_config table|nil User provided configuration
--- @return table config Merged configuration
function M.setup(user_config)
	user_config = user_config or {}

	local config = vim.tbl_deep_extend("force", M.defaults, user_config)

	local valid_levels = { info = true, warn = true, error = true }
	if not valid_levels[config.log_level] then
		vim.notify("Invalid log_level '" .. tostring(config.log_level) .. "'. Using 'warn'.", vim.log.levels.WARN)
		config.log_level = "warn"
	end

	-- Resolve model name to technical name if needed
	if config.model then
		local models = require("token-count.models.utils")
		local technical_name = models.resolve_model_name(config.model)
		if technical_name then
			config.model = technical_name
		else
			vim.notify("Invalid model '" .. tostring(config.model) .. "'. Using 'generic'.", vim.log.levels.WARN)
			config.model = "generic"
		end
	end

	M.current = config

	return config
end

--- @return table config Current configuration
function M.get()
	return M.current or M.defaults
end

return M
