local M = {}

-- Cache for Python availability check to avoid repeated blocking calls
local python_cache = {
	checked = false,
	available = false,
	version = nil,
	error = nil,
}

M.DEPENDENCIES = {
	tiktoken = {
		package = "tiktoken",
		import_test = "import tiktoken; print('OK')",
		display_name = "tiktoken",
	},
	tokencost = {
		package = "tokencost",
		import_test = "import tokencost; print('OK')",
		display_name = "tokencost",
	},
	deepseek_tokenizer = {
		package = "deepseek_tokenizer",
		import_test = "import deepseek_tokenizer; print('OK')",
		display_name = "DeepSeek Tokenizer",
	},
	anthropic = {
		package = "anthropic",
		import_test = "import anthropic; print('OK')",
		display_name = "Anthropic",
	},
	gemini = {
		package = "google-genai",
		import_test = "import google.genai; print('OK')",
		display_name = "Google GenAI",
	},
}

--- Get the path to the plugin's virtual environment
--- @return string venv_path Path to the virtual environment directory
function M.get_venv_path()
	local data_dir = vim.fn.stdpath("data")
	return data_dir .. "/token-count.nvim/venv"
end

--- Get the path to the Python executable in the venv
--- @return string python_path Path to the Python executable
function M.get_python_path()
	local venv_path = M.get_venv_path()
	if vim.fn.has("win32") == 1 then
		return venv_path .. "/Scripts/python.exe"
	else
		return venv_path .. "/bin/python"
	end
end

--- Check if the virtual environment exists and is valid
--- @return boolean exists Whether the venv exists and has Python
function M.venv_exists()
	local python_path = M.get_python_path()
	return vim.fn.filereadable(python_path) == 1
end

--- Internal function to actually check Python availability (blocking)
--- This should only be called once during plugin initialization
--- @return boolean available Whether Python 3 is available
--- @return string|nil version_or_error Version string if available, error message if not
local function _check_python_available_impl()
	local python_cmd = { "python3", "--version" }
	local result = vim.system(python_cmd, { text = true }):wait()

	if result.code == 0 then
		local version = result.stdout:gsub("%s+$", "")
		return true, version
	else
		-- Try just "python" as fallback
		python_cmd = { "python", "--version" }
		result = vim.system(python_cmd, { text = true }):wait()

		if result.code == 0 and result.stdout:match("Python 3") then
			local version = result.stdout:gsub("%s+$", "")
			return true, version
		else
			return false, "Python 3 not found in PATH"
		end
	end
end

--- Async version of Python availability check
--- @param callback function Callback with (available, version_or_error)
local function _check_python_available_async(callback)
	local python_cmd = { "python3", "--version" }
	vim.system(python_cmd, { text = true }, function(result)
		if result.code == 0 then
			local version = result.stdout:gsub("%s+$", "")
			callback(true, version)
		else
			-- Try just "python" as fallback
			local python_cmd_fallback = { "python", "--version" }
			vim.system(python_cmd_fallback, { text = true }, function(fallback_result)
				if fallback_result.code == 0 and fallback_result.stdout:match("Python 3") then
					local version = fallback_result.stdout:gsub("%s+$", "")
					callback(true, version)
				else
					callback(false, "Python 3 not found in PATH")
				end
			end)
		end
	end)
end

--- Initialize Python cache asynchronously
--- @param callback function|nil Optional callback when complete
function M.init_python_cache_async(callback)
	if python_cache.checked then
		if callback then callback() end
		return
	end
	
	_check_python_available_async(function(available, version_or_error)
		python_cache.checked = true
		python_cache.available = available
		if available then
			python_cache.version = version_or_error
			python_cache.error = nil
		else
			python_cache.version = nil
			python_cache.error = version_or_error
		end
		if callback then callback() end
	end)
end

--- Initialize the Python availability cache
--- This should be called once during plugin startup
function M.init_python_cache()
	if not python_cache.checked then
		local available, version_or_error = _check_python_available_impl()
		python_cache.checked = true
		python_cache.available = available
		if available then
			python_cache.version = version_or_error
			python_cache.error = nil
		else
			python_cache.version = nil
			python_cache.error = version_or_error
		end
	end
end

function M.check_python_available()
	-- Return cached result if available
	if python_cache.checked then
		if python_cache.available then
			return true, python_cache.version
		else
			return false, python_cache.error
		end
	end
	
	-- Try to initialize cache synchronously, with fallback for fast event contexts
	local success, err = pcall(M.init_python_cache)
	if success then
		-- Synchronous init worked, return the result
		return M.check_python_available() -- Recursive call with cache now populated
	else
		-- Fast event context or other error - schedule async init and return optimistic result
		vim.schedule(function()
			M.init_python_cache_async()
		end)
		return true, "Python 3 (checking in background)"
	end
end

function M.clear_python_cache()
	python_cache.checked = false
	python_cache.available = false
	python_cache.version = nil
	python_cache.error = nil
end

--- Check if provider API keys are configured
--- @return table api_status Status of API key configuration for each provider
function M.check_api_keys()
	return {
		anthropic = vim.env.ANTHROPIC_API_KEY ~= nil
			and vim.env.ANTHROPIC_API_KEY ~= "",
		gemini = vim.env.GOOGLE_API_KEY ~= nil
			and vim.env.GOOGLE_API_KEY ~= "",
	}
end

return M
