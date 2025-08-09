local M = {}

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

function M.tiktoken_installed()
	if not M.venv_exists() then
		return false, "Virtual environment does not exist"
	end

	local python_path = M.get_python_path()
	local check_cmd = { python_path, "-c", "import tiktoken; print('OK')" }
	local result = vim.system(check_cmd, { text = true }):wait()

	if result.code == 0 and result.stdout:match("OK") then
		return true, nil
	else
		return false, result.stderr or "Import failed"
	end
end

--- Check if anthropic is installed in the venv
--- @return boolean installed Whether anthropic is available
--- @return string|nil error Error message if check failed
function M.anthropic_installed()
	if not M.venv_exists() then
		return false, "Virtual environment does not exist"
	end

	local python_path = M.get_python_path()
	local check_cmd = { python_path, "-c", "import anthropic; print('OK')" }
	local result = vim.system(check_cmd, { text = true }):wait()

	if result.code == 0 and result.stdout:match("OK") then
		return true, nil
	else
		return false, result.stderr or "Import failed"
	end
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

function M.install_tiktoken(callback)
	if not M.venv_exists() then
		callback(false, "Virtual environment does not exist")
		return
	end

	local python_path = M.get_python_path()
	local log = require("token-count.log")

	log.info("Installing tiktoken in virtual environment")

	-- Install tiktoken using pip
	local install_cmd = { python_path, "-m", "pip", "install", "tiktoken" }

	local job_id = vim.fn.jobstart(install_cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.info("pip install: " .. line)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.warn("pip install warning: " .. line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				log.info("tiktoken installed successfully")
				callback(true, nil)
			else
				local error_msg = "Failed to install tiktoken (exit code: " .. exit_code .. ")"
				log.error(error_msg)
				callback(false, error_msg)
			end
		end,
	})

	if job_id <= 0 then
		local error_msg = "Failed to start tiktoken installation"
		log.error(error_msg)
		callback(false, error_msg)
	end
end

--- Install anthropic library in the virtual environment
--- @param callback function Callback function that receives (success, error)
function M.install_anthropic(callback)
	if not M.venv_exists() then
		callback(false, "Virtual environment does not exist")
		return
	end

	local python_path = M.get_python_path()
	local log = require("token-count.log")

	log.info("Installing anthropic in virtual environment")

	-- Install anthropic using pip
	local install_cmd = { python_path, "-m", "pip", "install", "anthropic" }

	local job_id = vim.fn.jobstart(install_cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.info("pip install anthropic: " .. line)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.warn("pip install anthropic warning: " .. line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				log.info("anthropic installed successfully")
				callback(true, nil)
			else
				local error_msg = "Failed to install anthropic (exit code: " .. exit_code .. ")"
				log.error(error_msg)
				callback(false, error_msg)
			end
		end,
	})

	if job_id <= 0 then
		local error_msg = "Failed to start anthropic installation"
		log.error(error_msg)
		callback(false, error_msg)
	end
end

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

--- Get status information about the venv setup
--- @return table status Status information
function M.get_status()
	local python_available, python_info = M.check_python_available()
	local venv_exists = M.venv_exists()
	local tiktoken_installed, tiktoken_error = M.tiktoken_installed()

	return {
		python_available = python_available,
		python_info = python_info,
		venv_exists = venv_exists,
		venv_path = get_venv_path(),
		python_path = M.get_python_path(),
		tiktoken_installed = tiktoken_installed,
		tiktoken_error = tiktoken_error,
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
