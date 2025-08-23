local M = {}

function M.count_tokens_async(text, model_name, callback)
	-- Check content size limit (reasonable limit for API calls)
	if #text > 100000 then
		-- Guesstimate: ~4 characters per token for most text
		local estimated_tokens = math.floor(#text / 4)
		require("token-count.log").warn(
			string.format(
				"Content too large for Gemini API (%d chars), returning estimate: %d tokens",
				#text,
				estimated_tokens
			)
		)
		callback(estimated_tokens, nil)
		return
	end

	-- Get the path to the gemini counter script
	local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/gemini_counter.py"

	-- Use the plugin's managed virtual environment
	local venv = require("token-count.venv")

	-- Check if venv is ready
	local status = venv.get_status()
	if not status.ready then
		callback(nil, "Virtual environment not ready. Run :TokenCountVenvSetup to initialize.")
		return
	end

	local python_path = venv.get_python_path()
	local cmd = { python_path, script_path, model_name, text }

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
				callback(nil, "Gemini error: " .. error_msg)
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				callback(nil, "Gemini process failed with exit code: " .. exit_code)
			end
		end,
	})

	if job_id <= 0 then
		callback(nil, "Failed to start Gemini counting job")
	end
end

function M.count_tokens_sync(text, model_name)
	-- Check content size limit (reasonable limit for API calls)
	if #text > 100000 then
		-- Guesstimate: ~4 characters per token for most text
		local estimated_tokens = math.floor(#text / 4)
		require("token-count.log").warn(
			string.format(
				"Content too large for Gemini API (%d chars), returning estimate: %d tokens",
				#text,
				estimated_tokens
			)
		)
		return estimated_tokens, nil
	end

	local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/gemini_counter.py"

	-- Use the plugin's managed virtual environment
	local venv = require("token-count.venv")

	-- Check if venv is ready
	local status = venv.get_status()
	if not status.ready then
		return nil, "Virtual environment not ready. Run :TokenCountVenvSetup to initialize."
	end

	local python_path = venv.get_python_path()
	local cmd = { python_path, script_path, model_name, text }
	local result = vim.system(cmd, { text = true }):wait()

	if result.code == 0 then
		local token_count = tonumber(result.stdout:gsub("%s+", ""))
		if token_count then
			return token_count, nil
		else
			return nil, "Invalid token count returned: " .. result.stdout
		end
	else
		return nil, "Gemini error: " .. (result.stderr or "Unknown error")
	end
end

function M.check_availability()
	-- Check if API key is set
	local api_key = vim.fn.getenv("GOOGLE_API_KEY")
	if not api_key or api_key == vim.NIL or api_key == "" then
		return false, "GOOGLE_API_KEY environment variable not set"
	end

	-- Check if google-genai library is available in the managed venv
	local venv = require("token-count.venv")
	local status = venv.get_status()
	if not status.ready then
		return false, "Virtual environment not ready"
	end

	local python_path = venv.get_python_path()
	local check_cmd = { python_path, "-c", "import google.genai; print('OK')" }
	local result = vim.system(check_cmd, { text = true }):wait()

	if result.code ~= 0 or not result.stdout:match("OK") then
		return false, "google-genai library not installed in venv (will be installed automatically if needed)"
	end

	return true, nil
end

return M
