local M = {}
-- Lazy load cleanup system to avoid circular dependencies
local function get_cleanup()
	local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
	return cleanup_ok and cleanup or nil
end

function M.count_tokens_async(text, encoding, callback)
	-- Get the path to the tiktoken counter script
	local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/tiktoken_counter.py"

	-- Use the plugin's managed virtual environment
	local venv = require("token-count.venv")

	-- Early check: if Python is not available, fail silently to avoid error spam
	local venv_utils = require("token-count.venv.utils")
	local python_available, _ = venv_utils.check_python_available()
	if not python_available then
		-- Fail silently - don't spam errors when Python is simply not installed
		callback(nil, "Python not available")
		return
	end

	-- Check if venv is ready
	local status = venv.get_status()
	if not status.ready then
		callback(nil, "Virtual environment not ready. Run :TokenCountVenvSetup to initialize.")
		return
	end

	local python_path = venv.get_python_path()
	local cmd = { python_path, script_path, encoding, text }

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
					callback(nil, "No output from tiktoken")
				end
			else
				local error_msg = result.stderr and result.stderr:gsub("%s+$", "") or "Unknown error"
				callback(nil, "Tiktoken error: " .. error_msg)
			end
		end)
	end)
end

--- Count tokens synchronously (blocks Neovim)
--- @param text string The text to count tokens for
--- @param encoding string The tiktoken encoding to use
--- @return number|nil token_count The number of tokens, or nil on error
--- @return string|nil error Error message if counting failed
function M.count_tokens_sync(text, encoding)
	local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/tiktoken_counter.py"

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
	local cmd = { python_path, script_path, encoding, text }
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
		return nil, "Tiktoken error: " .. (result.stderr or "Unknown error")
	end
end

function M.check_availability()
	-- Check if tiktoken library is available in the managed venv
	local venv = require("token-count.venv")
	local status = venv.get_status()
	if not status.ready then
		return false, "Virtual environment not ready"
	end

	local python_path = venv.get_python_path()
	local check_cmd = { python_path, "-c", "import tiktoken; print('OK')" }
	local result = vim.system(check_cmd, { text = true }):wait()

	if result.code ~= 0 or not result.stdout:match("OK") then
		return false, "tiktoken library not installed in venv (will be installed automatically if needed)"
	end

	return true, nil
end

return M
