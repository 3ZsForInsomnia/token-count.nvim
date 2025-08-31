local M = {}

M.defaults = {
	model = "gpt-5",
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
		lazy_start = true, -- Start cache timer only when first request is made
	},
	-- Lazy loading options
	lazy_loading = {
		defer_venv_setup = true, -- Defer virtual environment setup until first use
		defer_autocommands = true, -- Defer setting up autocommands until first use
		defer_cache_setup = true, -- Defer cache initialization until needed
	},
}

--- Validate configuration and provide helpful error messages
--- @param config table Configuration to validate
--- @return boolean valid Whether configuration is valid
--- @return string[] errors List of validation errors
local function validate_config(config)
	local errors = {}
	local warnings = {}
	
	-- Validate model exists
	if config.model then
		local models_ok, models = pcall(require, "token-count.models.utils")
		if models_ok then
			local technical_name = models.resolve_model_name(config.model)
			if not technical_name then
				table.insert(errors, string.format(
					"Invalid model '%s'. Run :TokenCountModel to see available models.", 
					config.model
				))
			end
		end
	end
	
	-- Validate numeric ranges
	if config.context_warning_threshold then
		if type(config.context_warning_threshold) ~= "number" then
			table.insert(errors, "context_warning_threshold must be a number")
		elseif config.context_warning_threshold < 0 or config.context_warning_threshold > 1 then
			table.insert(errors, "context_warning_threshold must be between 0 and 1")
		end
	end
	
	-- Validate cache configuration
	if config.cache then
		if config.cache.interval and (type(config.cache.interval) ~= "number" or config.cache.interval < 1000) then
			table.insert(warnings, "cache.interval should be at least 1000ms for good performance")
		end
		
		if config.cache.max_files_per_batch and (type(config.cache.max_files_per_batch) ~= "number" or config.cache.max_files_per_batch < 1) then
			table.insert(errors, "cache.max_files_per_batch must be a positive number")
		end
		
		if config.cache.cache_ttl and (type(config.cache.cache_ttl) ~= "number" or config.cache.cache_ttl < 60000) then
			table.insert(warnings, "cache.cache_ttl should be at least 60000ms (1 minute)")
		end
	end
	
	-- Validate log level
	if config.log_level then
		local valid_levels = { info = true, warn = true, error = true }
		if not valid_levels[config.log_level] then
			table.insert(errors, "log_level must be one of: 'info', 'warn', 'error'")
		end
	end
	
	-- Check for deprecated options
	if config.enable_background_processing ~= nil then
		table.insert(warnings, "enable_background_processing is deprecated, use cache.enabled instead")
	end
	
	-- Warn about API key configuration if official counters are enabled
	if config.enable_official_anthropic_counter then
		local api_key = vim.fn.getenv("ANTHROPIC_API_KEY")
		if not api_key or api_key == vim.NIL or api_key == "" then
			table.insert(warnings, "enable_official_anthropic_counter is true but ANTHROPIC_API_KEY is not set")
		end
	end
	
	if config.enable_official_gemini_counter then
		local api_key = vim.fn.getenv("GOOGLE_API_KEY")
		if not api_key or api_key == vim.NIL or api_key == "" then
			table.insert(warnings, "enable_official_gemini_counter is true but GOOGLE_API_KEY is not set")
		end
	end
	
	-- Display warnings
	if #warnings > 0 then
		local warning_msg = "Configuration warnings:\n" .. table.concat(warnings, "\n")
		vim.schedule(function()
			vim.notify(warning_msg, vim.log.levels.WARN)
		end)
	end
	
	return #errors == 0, errors
end

--- @param user_config table|nil User provided configuration
--- @return table config Merged configuration
function M.setup(user_config)
	user_config = user_config or {}

	local config = vim.tbl_deep_extend("force", M.defaults, user_config)
	
	-- Validate configuration
	local valid, errors = validate_config(config)
	if not valid then
		local error_msg = "Configuration errors:\n" .. table.concat(errors, "\n")
		vim.notify(error_msg, vim.log.levels.ERROR)
		-- Continue with defaults for invalid settings
		config = vim.tbl_deep_extend("force", M.defaults, {})
	end

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
