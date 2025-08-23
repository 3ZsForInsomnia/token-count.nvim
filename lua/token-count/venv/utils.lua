--- Configuration and utilities for virtual environment management
local M = {}

--- Dependencies configuration
M.DEPENDENCIES = {
	tiktoken = {
		package = "tiktoken",
		import_test = "import tiktoken; print('OK')",
		display_name = "tiktoken",
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

--- Check if Python 3 is available on the system
--- @return boolean available Whether Python 3 is available
--- @return string|nil error Error message if not available
function M.check_python_available()
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

--- Check if provider API keys are configured
--- @return table api_status Status of API key configuration for each provider
function M.check_api_keys()
	return {
		anthropic = vim.fn.getenv("ANTHROPIC_API_KEY") ~= vim.NIL
			and vim.fn.getenv("ANTHROPIC_API_KEY") ~= ""
			and vim.fn.getenv("ANTHROPIC_API_KEY") ~= nil,
		gemini = vim.fn.getenv("GOOGLE_API_KEY") ~= vim.NIL
			and vim.fn.getenv("GOOGLE_API_KEY") ~= ""
			and vim.fn.getenv("GOOGLE_API_KEY") ~= nil,
	}
end

return M