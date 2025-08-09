local M = {}

function M.count_tokens_async(text, encoding, callback)
	-- Get the path to the tiktoken counter script
	local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/tiktoken_counter.py"

	-- Use the plugin's managed virtual environment
	local venv = require("token-count.venv")
	
	-- Check if venv is ready
	local status = venv.get_status()
	if not status.ready then
		callback(nil, "Virtual environment not ready. Run :TokenCountVenvSetup to initialize.")
		return
	end
	
	local python_path = venv.get_python_path()
	local cmd = { python_path, script_path, encoding, text }

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
				callback(nil, "Tiktoken error: " .. error_msg)
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				callback(nil, "Tiktoken process failed with exit code: " .. exit_code)
			end
		end,
	})

	if job_id <= 0 then
		callback(nil, "Failed to start tiktoken counting job")
	end
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
	
	-- Check if venv is ready
	local status = venv.get_status()
	if not status.ready then
		return nil, "Virtual environment not ready. Run :TokenCountVenvSetup to initialize."
	end
	
	local python_path = venv.get_python_path()
	local cmd = { python_path, script_path, encoding, text }
	local result = vim.system(cmd, { text = true }):wait()

	if result.code == 0 then
		local token_count = tonumber(result.stdout:gsub("%s+", ""))
		if token_count then
			return token_count, nil
		else
			return nil, "Invalid token count returned: " .. result.stdout
		end
	else
		return nil, "Tiktoken error: " .. (result.stderr or "Unknown error")
	end
end

return M
