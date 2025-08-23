--- Configuration and system checks
local M = {}

local utils = require("token-count.health.utils")

--- Check if tiktoken provider works
--- @return boolean success Whether tiktoken provider works
--- @return string|nil error_msg Error message if provider fails
function M.check_tiktoken_provider()
	local tiktoken = require("token-count.providers.tiktoken")
	local success = false
	local error_msg = nil

	-- Test with a simple string
	local test_text = "Hello, world!"
	local token_count, err = tiktoken.count_tokens_sync(test_text, "cl100k_base")

	if token_count and token_count > 0 then
		success = true
	else
		error_msg = err or "Unknown error"
	end

	return success, error_msg
end

--- Check if models configuration is valid
--- @return boolean success Whether models config is valid
--- @return string|nil error_msg Error message if config is invalid
function M.check_models_config()
	local models = require("token-count.models.utils")
	local config = require("token-count.config")

	-- Check if default model exists
	local default_model = config.get().model
	local model_config = models.get_model(default_model)

	if not model_config then
		return false, "Default model '" .. default_model .. "' not found in configuration"
	end

	-- Check if at least some models are defined
	local available_models = models.get_available_models()
	if #available_models == 0 then
		return false, "No models defined in configuration"
	end

	return true, nil
end

--- Check if log directory is writable
--- @return boolean success Whether log directory is writable
--- @return string|nil error_msg Error message if not writable
function M.check_log_directory()
	local log = require("token-count.log")
	local log_path = log.get_log_path()

	-- Try to write a test entry
	local test_file = io.open(log_path, "a")
	if test_file then
		test_file:write("") -- Just test that we can open for writing
		test_file:close()
		return true, nil
	else
		return false, "Cannot write to log file: " .. log_path
	end
end

--- Run configuration checks
function M.run_config_checks()
	-- Check models configuration
	local models_ok, models_err = M.check_models_config()
	utils.report_check("models configuration", models_ok, models_err)

	-- Check log directory
	local log_ok, log_err = M.check_log_directory()
	utils.report_check("log directory", log_ok, log_err)

	-- Check current configuration
	local config = require("token-count.config").get()
	local config_info = string.format("model=%s, log_level=%s", config.model, config.log_level)
	utils.report_check("plugin configuration", true, nil, config_info)
end

return M