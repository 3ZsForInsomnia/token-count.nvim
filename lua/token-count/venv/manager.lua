--- Virtual environment creation and management
local M = {}

local utils = require("token-count.venv.utils")

--- Create virtual environment
--- @param callback function Callback function that receives (success, error)
function M.create_venv(callback)
	local venv_path = utils.get_venv_path()
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

--- Clean up the virtual environment (remove it completely)
--- @param callback function Callback function that receives (success, error)
function M.clean_venv(callback)
	local venv_path = utils.get_venv_path()
	local log = require("token-count.log")

	if not utils.venv_exists() then
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