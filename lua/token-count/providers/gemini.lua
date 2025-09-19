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
	local cmd = { python_path, script_path, model_name, text }

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
					callback(nil, "No output from Gemini")
				end
			else
				local error_msg = result.stderr and result.stderr:gsub("%s+$", "") or "Unknown error"
				callback(nil, "Gemini error: " .. error_msg)
			end
		end)
	end)
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
