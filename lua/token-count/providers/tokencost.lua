local M = {}
-- Lazy load cleanup system to avoid circular dependencies
local function get_cleanup()
	local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
	return cleanup_ok and cleanup or nil
end

function M.count_tokens_async(text, model_name, callback)
	local errors = require("token-count.utils.errors")
	
	-- Use error handling wrapper for graceful degradation
	errors.with_fallback(function(fallback_callback)
		M._count_tokens_primary(text, model_name, fallback_callback)
	end, text, callback)
end

function M._count_tokens_primary(text, model_name, callback)
	-- Get the path to the tokencost counter script
	local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/tokencost_counter.py"

	-- Use the plugin's managed virtual environment
	local venv = require("token-count.venv")
	local errors = require("token-count.utils.errors")

	-- Early check: if Python is not available, fail silently to avoid error spam
	local venv_utils = require("token-count.venv.utils")
	local python_available, _ = venv_utils.check_python_available()
	if not python_available then
		-- Fail silently - don't spam errors when Python is simply not installed
		callback(false, { error = "Python not available", silent = true })
		return
	end

	-- Check if venv is ready
	local status = venv.get_status()
	if not status.ready then
		local error_obj = errors.create_error(
			errors.ErrorTypes.VENV_NOT_READY,
			"Virtual environment not ready",
			{text = text}
		)
		
		-- Attempt recovery with auto-setup
		errors.handle_with_recovery(error_obj, callback, function()
			M._count_tokens_primary(text, model_name, callback)
		end)
		return
	end

	local python_path = venv.get_python_path()
	local config = require("token-count.config").get()
	
	-- Pass configuration flags for official providers
	local enable_anthropic = config.enable_official_anthropic_counter and "true" or "false"
	local enable_gemini = config.enable_official_gemini_counter and "true" or "false"
	
	local cmd = { python_path, script_path, model_name, enable_anthropic, enable_gemini, text }

	-- Use vim.system instead of jobstart to avoid fast event context issues
	vim.system(cmd, { text = true }, function(result)
		-- Schedule callback to avoid fast event context restrictions
		vim.schedule(function()
			if result.code == 0 then
				local stdout = result.stdout and result.stdout:gsub("%s+$", "") or ""
				if stdout ~= "" then
					local token_count = tonumber(stdout)
					if token_count then
						callback(token_count, nil)
					else
						callback(nil, "Invalid token count returned: " .. stdout)
					end
				else
					callback(nil, "No output from tokencost")
				end
			else
				local error_msg = result.stderr and result.stderr:gsub("%s+$", "") or "Unknown error"
				callback(nil, "Tokencost error: " .. error_msg)
			end
		end)
	end)
end

--- Count tokens synchronously (blocks Neovim)
--- @param text string The text to count tokens for
--- @param model_name string The model name to use for counting
--- @return number|nil token_count The number of tokens, or nil on error
--- @return string|nil error Error message if counting failed
function M.count_tokens_sync(text, model_name)
	local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/tokencost_counter.py"

	-- Use the plugin's managed virtual environment
	local venv = require("token-count.venv")

	-- Early check: if Python is not available, fail quickly
	local venv_utils = require("token-count.venv.utils")
	local python_available, _ = venv_utils.check_python_available()
	if not python_available then
		return nil, "Python not available"
	end

	-- Check if venv is ready
	local status = venv.get_status()
	if not status.ready then
		return nil, "Virtual environment not ready. Run :TokenCountVenvSetup to initialize."
	end

	local python_path = venv.get_python_path()
	local config = require("token-count.config").get()
	
	-- Pass configuration flags for official providers
	local enable_anthropic = config.enable_official_anthropic_counter and "true" or "false"
	local enable_gemini = config.enable_official_gemini_counter and "true" or "false"
	
	local cmd = { python_path, script_path, model_name, enable_anthropic, enable_gemini, text }
	local result = vim.system(cmd, { text = true }):wait()

	if result.code == 0 then
		local cleaned_output = result.stdout:gsub("%s+", "")
		local token_count = tonumber(cleaned_output)
		if token_count then
			return token_count, nil
		else
			return nil, "Invalid token count returned: " .. cleaned_output
		end
	else
		return nil, "Tokencost error: " .. (result.stderr or "Unknown error")
	end
end

function M.check_availability()
	-- Check if tokencost library is available in the managed venv
	local venv = require("token-count.venv")
	local status = venv.get_status()
	if not status.ready then
		return false, "Virtual environment not ready"
	end

	local python_path = venv.get_python_path()
	local check_cmd = { python_path, "-c", "import tokencost; print('OK')" }
	local result = vim.system(check_cmd, { text = true }):wait()

	if result.code ~= 0 or not result.stdout:match("OK") then
		return false, "tokencost library not installed in venv (will be installed automatically if needed)"
	end

	return true, nil
end

return M