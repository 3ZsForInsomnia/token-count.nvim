local M = {}

function M.count_tokens_async(text, model_name, callback)
	-- Get the path to the tokencost counter script
	local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/tokencost_counter.py"

	-- Use the plugin's managed virtual environment
	local venv = require("token-count.venv")

	-- Check if venv is ready
	local status = venv.get_status()
	if not status.ready then
		callback(nil, "Virtual environment not ready. Run :TokenCountVenvSetup to initialize.")
		return
	end

	local python_path = venv.get_python_path()
	local config = require("token-count.config").get()
	
	-- Pass configuration flags for official providers
	local enable_anthropic = config.enable_official_anthropic_counter and "true" or "false"
	local enable_gemini = config.enable_official_gemini_counter and "true" or "false"
	
	local cmd = { python_path, script_path, model_name, enable_anthropic, enable_gemini, text }

	local job_id = vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data and data[1] and data[1] ~= "" then
				local token_count = tonumber(data[1])
				if token_count then
					callback(token_count, nil)
				else
					callback(nil, "Invalid token count returned: " .. data[1])
				end
			end
		end,
		on_stderr = function(_, data)
			if data and data[1] and data[1] ~= "" then
				local error_msg = table.concat(data, "\n")
				callback(nil, "Tokencost error: " .. error_msg)
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				callback(nil, "Tokencost process failed with exit code: " .. exit_code)
			end
		end,
	})

	if job_id <= 0 then
		callback(nil, "Failed to start tokencost counting job")
	end
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