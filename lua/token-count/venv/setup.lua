--- High-level virtual environment setup and status
local M = {}

local utils = require("token-count.venv.utils")
local manager = require("token-count.venv.manager")
local dependencies = require("token-count.venv.dependencies")

-- Cache for venv status to avoid repeated system calls in fast event contexts
local status_cache = {
	checked = false,
	status = nil
}

function M.setup_venv(callback)
	callback = callback or function() end

	-- Check if already set up with primary dependencies
	local tokencost_installed = dependencies.is_dependency_installed("tokencost")
	local tiktoken_installed = dependencies.is_dependency_installed("tiktoken")
	local deepseek_installed = dependencies.is_dependency_installed("deepseek_tokenizer")
	
	if tokencost_installed and tiktoken_installed and deepseek_installed then
		require("token-count.log").info("Virtual environment already set up with core dependencies")
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

			-- Install all dependencies after venv creation
			dependencies.install_all_dependencies(callback)
		end)
	else
		-- Venv exists but dependencies need installation
		dependencies.install_all_dependencies(callback)
	end
end

--- Internal function to actually compute status (may contain blocking calls)
--- This should only be called once during plugin initialization
local function _get_status_impl()
	local python_available, python_info = utils.check_python_available()
	local venv_exists = utils.venv_exists()
	local tiktoken_installed, tiktoken_error = dependencies.is_dependency_installed("tiktoken")
	local tokencost_installed, tokencost_error = dependencies.is_dependency_installed("tokencost")
	local deepseek_installed, deepseek_error = dependencies.is_dependency_installed("deepseek_tokenizer")
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
		tokencost_installed = tokencost_installed,
		tokencost_error = tokencost_error,
		deepseek_installed = deepseek_installed,
		deepseek_error = deepseek_error,
		anthropic_installed = anthropic_installed,
		anthropic_error = anthropic_error,
		gemini_installed = gemini_installed,
		gemini_error = gemini_error,

		-- API Keys
		anthropic_api_key = api_keys.anthropic,
		gemini_api_key = api_keys.gemini,

		-- Overall readiness
		ready = python_available and venv_exists and tokencost_installed,
	}
end

--- Initialize the status cache
--- This should be called once during plugin startup
function M.init_status_cache()
	if not status_cache.checked then
		status_cache.status = _get_status_impl()
		status_cache.checked = true
	end
end

--- Clear the status cache (useful after installations or changes)
function M.clear_status_cache()
	status_cache.checked = false
	status_cache.status = nil
end

function M.get_status()
	-- Initialize cache if not already done (fallback for cases where init wasn't called)
	if not status_cache.checked then
		M.init_status_cache()
	end
	
	return status_cache.status
end

return M