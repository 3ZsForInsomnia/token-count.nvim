local M = {}

--- Dependencies configuration
local DEPENDENCIES = {
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
local function get_venv_path()
	local data_dir = vim.fn.stdpath("data")
	return data_dir .. "/token-count.nvim/venv"
end

--- Get the path to the Python executable in the venv
--- @return string python_path Path to the Python executable
function M.get_python_path()
	local venv_path = get_venv_path()
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

--- Check if a dependency is installed in the venv
--- @param dependency_name string The dependency name (tiktoken, anthropic, gemini)
--- @return boolean installed Whether the dependency is available
--- @return string|nil error Error message if check failed
local function is_dependency_installed(dependency_name)
	if not M.venv_exists() then
		return false, "Virtual environment does not exist"
	end

	local dep_config = DEPENDENCIES[dependency_name]
	if not dep_config then
		return false, "Unknown dependency: " .. dependency_name
	end

	local python_path = M.get_python_path()
	local check_cmd = { python_path, "-c", dep_config.import_test }
	local result = vim.system(check_cmd, { text = true }):wait()

	if result.code == 0 and result.stdout:match("OK") then
		return true, nil
	else
		return false, result.stderr or "Import failed"
	end
end

--- Install a dependency in the virtual environment
--- @param dependency_name string The dependency name (tiktoken, anthropic, gemini)
--- @param callback function Callback function that receives (success, error)
local function install_dependency(dependency_name, callback)
	if not M.venv_exists() then
		callback(false, "Virtual environment does not exist")
		return
	end

	local dep_config = DEPENDENCIES[dependency_name]
	if not dep_config then
		callback(false, "Unknown dependency: " .. dependency_name)
		return
	end

	local python_path = M.get_python_path()
	local log = require("token-count.log")

	log.info("Installing " .. dep_config.display_name .. " in virtual environment")

	local install_cmd = { python_path, "-m", "pip", "install", dep_config.package }

	local job_id = vim.fn.jobstart(install_cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.info("pip install " .. dependency_name .. ": " .. line)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.warn("pip install " .. dependency_name .. " warning: " .. line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				log.info(dep_config.display_name .. " installed successfully")
				callback(true, nil)
			else
				local error_msg = "Failed to install " .. dep_config.display_name .. " (exit code: " .. exit_code .. ")"
				log.error(error_msg)
				callback(false, error_msg)
			end
		end,
	})

	if job_id <= 0 then
		local error_msg = "Failed to start " .. dep_config.display_name .. " installation"
		log.error(error_msg)
		callback(false, error_msg)
	end
end

--- Public API for checking individual dependencies
function M.tiktoken_installed()
	return is_dependency_installed("tiktoken")
end

function M.anthropic_installed()
	return is_dependency_installed("anthropic")
end

function M.gemini_installed()
	return is_dependency_installed("gemini")
end

--- Public API for installing individual dependencies
function M.install_tiktoken(callback)
	install_dependency("tiktoken", callback)
end

function M.install_anthropic(callback)
	install_dependency("anthropic", callback)
end

function M.install_gemini(callback)
	install_dependency("gemini", callback)
end

--- Install all Python dependencies
--- @param callback function Callback function that receives (success, warnings)
function M.install_all_dependencies(callback)
	callback = callback or function() end
	local log = require("token-count.log")

	if not M.venv_exists() then
		callback(false, "Virtual environment does not exist")
		return
	end

	log.info("Installing all Python dependencies...")

	local dependencies_to_install = {}
	local warnings = {}

	-- Check which dependencies need installation
	for dep_name, _ in pairs(DEPENDENCIES) do
		local installed, _ = is_dependency_installed(dep_name)
		if not installed then
			table.insert(dependencies_to_install, dep_name)
		else
			log.info(DEPENDENCIES[dep_name].display_name .. " already installed")
		end
	end

	if #dependencies_to_install == 0 then
		log.info("All dependencies already installed")
		callback(true, nil)
		return
	end

	-- Install dependencies sequentially
	local function install_next_dependency(index)
		if index > #dependencies_to_install then
			-- All done, check final status
			local tiktoken_ok, _ = is_dependency_installed("tiktoken")
			if tiktoken_ok then
				local warning_msg = nil
				if #warnings > 0 then
					warning_msg = "Some optional providers failed to install: " .. table.concat(warnings, ", ")
				end
				callback(true, warning_msg)
			else
				callback(false, "Critical dependency tiktoken failed to install")
			end
			return
		end

		local dep_name = dependencies_to_install[index]
		install_dependency(dep_name, function(success, error)
			if not success then
				local warning = DEPENDENCIES[dep_name].display_name .. " (" .. (error or "unknown error") .. ")"
				table.insert(warnings, warning)
				log.warn(
					"Failed to install " .. DEPENDENCIES[dep_name].display_name .. ": " .. (error or "unknown error")
				)
			end

			-- Continue with next dependency regardless of success/failure
			install_next_dependency(index + 1)
		end)
	end

	install_next_dependency(1)
end

function M.create_venv(callback)
	local venv_path = get_venv_path()
	local log = require("token-count.log")

	-- Ensure parent directory exists
	vim.fn.mkdir(vim.fn.fnamemodify(venv_path, ":h"), "p")

	log.info("Creating virtual environment at: " .. venv_path)

	-- Create venv using python -m venv
	local create_cmd = { "python3", "-m", "venv", venv_path }

	local job_id = vim.fn.jobstart(create_cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.info("venv creation: " .. line)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.warn("venv creation warning: " .. line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				log.info("Virtual environment created successfully")
				callback(true, nil)
			else
				local error_msg = "Failed to create virtual environment (exit code: " .. exit_code .. ")"
				log.error(error_msg)
				callback(false, error_msg)
			end
		end,
	})

	if job_id <= 0 then
		local error_msg = "Failed to start venv creation process"
		log.error(error_msg)
		callback(false, error_msg)
	end
end

--- Setup virtual environment (create if needed, install tiktoken for basic functionality)
--- @param callback function Callback function that receives (success, error)
function M.setup_venv(callback)
	callback = callback or function() end

	-- Check if already set up
	local installed, error = M.tiktoken_installed()
	if installed then
		require("token-count.log").info("Virtual environment already set up with tiktoken")
		callback(true, nil)
		return
	end

	-- Create venv if it doesn't exist
	if not M.venv_exists() then
		M.create_venv(function(success, create_error)
			if not success then
				callback(false, create_error)
				return
			end

			-- Install tiktoken after venv creation
			M.install_tiktoken(callback)
		end)
	else
		-- Venv exists but tiktoken not installed
		M.install_tiktoken(callback)
	end
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
local function check_api_keys()
	return {
		anthropic = vim.fn.getenv("ANTHROPIC_API_KEY") ~= vim.NIL
			and vim.fn.getenv("ANTHROPIC_API_KEY") ~= ""
			and vim.fn.getenv("ANTHROPIC_API_KEY") ~= nil,
		gemini = vim.fn.getenv("GOOGLE_API_KEY") ~= vim.NIL
			and vim.fn.getenv("GOOGLE_API_KEY") ~= ""
			and vim.fn.getenv("GOOGLE_API_KEY") ~= nil,
	}
end

--- Get comprehensive status information about the venv setup
--- @return table status Status information
function M.get_status()
	local python_available, python_info = M.check_python_available()
	local venv_exists = M.venv_exists()
	local tiktoken_installed, tiktoken_error = M.tiktoken_installed()
	local anthropic_installed, anthropic_error = M.anthropic_installed()
	local gemini_installed, gemini_error = M.gemini_installed()
	local api_keys = check_api_keys()

	return {
		python_available = python_available,
		python_info = python_info,
		venv_exists = venv_exists,
		venv_path = get_venv_path(),
		python_path = M.get_python_path(),

		-- Dependencies
		tiktoken_installed = tiktoken_installed,
		tiktoken_error = tiktoken_error,
		anthropic_installed = anthropic_installed,
		anthropic_error = anthropic_error,
		gemini_installed = gemini_installed,
		gemini_error = gemini_error,

		-- API Keys
		anthropic_api_key = api_keys.anthropic,
		gemini_api_key = api_keys.gemini,

		-- Overall readiness
		ready = python_available and venv_exists and tiktoken_installed,
	}
end

--- Clean up the virtual environment (remove it completely)
--- @param callback function Callback function that receives (success, error)
function M.clean_venv(callback)
	local venv_path = get_venv_path()
	local log = require("token-count.log")

	if not M.venv_exists() then
		callback(true, "Virtual environment does not exist")
		return
	end

	log.info("Removing virtual environment: " .. venv_path)

	-- Use system command to remove directory
	local remove_cmd
	if vim.fn.has("win32") == 1 then
		remove_cmd = { "rmdir", "/s", "/q", venv_path }
	else
		remove_cmd = { "rm", "-rf", venv_path }
	end

	local job_id = vim.fn.jobstart(remove_cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				log.info("Virtual environment removed successfully")
				callback(true, nil)
			else
				local error_msg = "Failed to remove virtual environment (exit code: " .. exit_code .. ")"
				log.error(error_msg)
				callback(false, error_msg)
			end
		end,
	})

	if job_id <= 0 then
		local error_msg = "Failed to start venv removal process"
		log.error(error_msg)
		callback(false, error_msg)
	end
end

return M
