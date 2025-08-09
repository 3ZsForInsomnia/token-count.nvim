local M = {}

--- Check if a Python library is available
--- @param library_name string Name of the Python library
--- @return boolean success Whether the library is available
local function check_python_library(library_name)
	-- Use the managed virtual environment if available
	local venv = require("token-count.venv")
	local status = venv.get_status()
	
	local python_path
	if status.ready then
		-- Use the managed venv Python
		python_path = venv.get_python_path()
	else
		-- Fallback to system Python for initial checks when venv isn't ready
		if status.python_available then
			-- Try to find the best available Python 3
			local python_candidates = { "python3", "python" }
			python_path = "python3" -- default fallback
			for _, cmd in ipairs(python_candidates) do
				local test_result = vim.system({ cmd, "--version" }, { text = true }):wait()
				if test_result.code == 0 and test_result.stdout:match("Python 3%.") then
					python_path = cmd
					break
				end
			end
		else
			return false, "Python 3 not available"
		end
	end
	
	local cmd = { python_path, "-c", "import " .. library_name .. "; print('OK')" }
	local result = vim.system(cmd, { text = true }):wait()

	if result.code == 0 and result.stdout:match("OK") then
		return true, nil
	else
		local error_msg = result.stderr and result.stderr:gsub("%s+$", "") or "Unknown error"
		return false, error_msg
	end
end

--- @return boolean success Whether tiktoken provider works
--- @return string|nil error_msg Error message if provider fails
local function check_tiktoken_provider()
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
local function check_models_config()
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
local function check_log_directory()
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

--- Report health check result
--- @param name string Name of the check
--- @param success boolean Whether the check passed
--- @param error_msg string|nil Error message if check failed
--- @param details string|nil Additional details
local function report_check(name, success, error_msg, details)
	if success then
		vim.health.ok(name .. (details and (" (" .. details .. ")") or ""))
	else
		vim.health.error(name, error_msg or "Unknown error")
	end
end

function M.check()
	vim.health.start("token-count.nvim")

	-- Check virtual environment setup
	local venv_ok, venv = pcall(require, "token-count.venv")
	if venv_ok then
		local status = venv.get_status()

		-- Check Python availability
		report_check("Python 3 available", status.python_available, status.python_info)

		-- Check virtual environment
		if status.venv_exists then
			report_check("Plugin virtual environment", true, nil, status.venv_path)
		else
			vim.health.warn("Plugin virtual environment", "Not found - will be created automatically")
		end

		-- Check tiktoken in venv
		if status.tiktoken_installed then
			report_check("tiktoken in venv", true)
		else
			vim.health.warn(
				"tiktoken in venv",
				status.tiktoken_error or "Not installed - will be installed automatically"
			)
		end

		-- Overall venv status
		if status.ready then
			vim.health.ok("Virtual environment ready")
		else
			vim.health.info("Virtual environment will be set up automatically on first use")
		end
	else
		vim.health.error("Virtual environment module", "Failed to load venv module")
	end

	-- Check anthropic library (optional)
	local anthropic_ok, anthropic_err = check_python_library("anthropic")
	if anthropic_ok then
		report_check("anthropic library", true, nil, "Available for future use")
	else
		vim.health.warn("anthropic library", anthropic_err .. " (optional - only needed for Anthropic models)")
	end

	-- Check models configuration
	local models_ok, models_err = check_models_config()
	report_check("models configuration", models_ok, models_err)

	-- Check log directory
	local log_ok, log_err = check_log_directory()
	report_check("log directory", log_ok, log_err)

	-- Check current configuration
	local config = require("token-count.config").get()
	local config_info = string.format("model=%s, log_level=%s", config.model, config.log_level)
	report_check("plugin configuration", true, nil, config_info)

	-- Summary
	vim.health.info("Run ':TokenCount' to test token counting on current buffer")
	vim.health.info("Run ':TokenCountModel' to change the active model")
	vim.health.info("Run ':TokenCountAll' to count tokens across all buffers")
end

return M
