--- High-level virtual environment setup and status
local M = {}

local utils = require("token-count.venv.utils")
local manager = require("token-count.venv.manager")
local dependencies = require("token-count.venv.dependencies")

--- Setup virtual environment (create if needed, install tiktoken for basic functionality)
--- @param callback function Callback function that receives (success, error)
function M.setup_venv(callback)
	callback = callback or function() end

	-- Check if already set up
	local installed, error = dependencies.is_dependency_installed("tiktoken")
	if installed then
		require("token-count.log").info("Virtual environment already set up with tiktoken")
		callback(true, nil)
		return
	end

	-- Create venv if it doesn't exist
	if not utils.venv_exists() then
		manager.create_venv(function(success, create_error)
			if not success then
				callback(false, create_error)
				return
			end

			-- Install tiktoken after venv creation
			dependencies.install_dependency("tiktoken", callback)
		end)
	else
		-- Venv exists but tiktoken not installed
		dependencies.install_dependency("tiktoken", callback)
	end
end

--- Get comprehensive status information about the venv setup
--- @return table status Status information
function M.get_status()
	local python_available, python_info = utils.check_python_available()
	local venv_exists = utils.venv_exists()
	local tiktoken_installed, tiktoken_error = dependencies.is_dependency_installed("tiktoken")
	local anthropic_installed, anthropic_error = dependencies.is_dependency_installed("anthropic")
	local gemini_installed, gemini_error = dependencies.is_dependency_installed("gemini")
	local api_keys = utils.check_api_keys()

	return {
		python_available = python_available,
		python_info = python_info,
		venv_exists = venv_exists,
		venv_path = utils.get_venv_path(),
		python_path = utils.get_python_path(),

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

return M