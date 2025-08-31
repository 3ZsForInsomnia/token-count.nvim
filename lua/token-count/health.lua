--- Health Check System
--- This module provides comprehensive health checking for token-count.nvim
local M = {}

-- Import submodules
local providers = require("token-count.health.providers")
local config = require("token-count.health.config")

function M.check()
	vim.health.start("token-count.nvim")
	
	-- Version and compatibility checks
	M.run_compatibility_checks()

	-- Run virtual environment and provider checks
	providers.run_venv_checks()
	providers.run_provider_checks()

	-- Run configuration checks
	config.run_config_checks()
	
	-- Run functional validation tests
	M.run_functional_tests()

	-- Summary
	vim.health.info("Run ':TokenCount' to test token counting on current buffer")
	vim.health.info("Run ':TokenCountModel' to change the active model")
	vim.health.info("Run ':TokenCountAll' to count tokens across all buffers")
	vim.health.info("Run ':TokenCountVenvStatus' for detailed provider and dependency status")
	vim.health.info("")
	vim.health.info("To enable additional providers:")
	vim.health.info("  - Anthropic accurate counting: Set ANTHROPIC_API_KEY and enable_official_anthropic_counter = true")
	vim.health.info("  - Gemini accurate counting: Set GOOGLE_API_KEY and enable_official_gemini_counter = true")
	vim.health.info("  - Note: All models provide token estimates by default via tokencost")
end

--- Run compatibility checks
function M.run_compatibility_checks()
	local version = require("token-count.version")
	local compatible, report = version.check_system_compatibility()
	
	-- Report Neovim compatibility
	if report.nvim_compatible then
		vim.health.ok("Neovim version: " .. report.nvim_version)
	else
		vim.health.error("Neovim version incompatible", "Requires 0.9.0+, found " .. report.nvim_version)
	end
	
	-- Report Python compatibility
	if report.python_compatible then
		local status = report.python_recommended and "recommended version" or "minimum version"
		vim.health.ok("Python version: " .. report.python_version .. " (" .. status .. ")")
	else
		vim.health.error("Python version incompatible", "Requires 3.7+, found " .. report.python_version)
	end
	
	-- Show warnings
	for _, warning in ipairs(report.warnings) do
		vim.health.warn("Compatibility", warning)
	end
end

--- Run functional validation tests
function M.run_functional_tests()
	-- Test basic token counting functionality
	local test_text = "Hello, this is a test message for token counting."
	local models_ok, models = pcall(require, "token-count.models.utils")
	local config_ok, config_module = pcall(require, "token-count.config")
	
	if not (models_ok and config_ok) then
		vim.health.error("Core modules", "Failed to load essential modules")
		return
	end
	
	local config = config_module.get()
	local model_config = models.get_model(config.model)
	
	if not model_config then
		vim.health.error("Model configuration", "Default model '" .. config.model .. "' not found")
		return
	end
	
	vim.health.ok("Model configuration: " .. model_config.name)
	
	-- Test provider functionality
	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		vim.health.error("Provider", "Failed to load provider: " .. model_config.provider)
		return
	end
	
	-- Test token counting (sync to avoid complexity in health check)
	local count, error = provider.count_tokens_sync(test_text, model_config.encoding)
	if count and count > 0 and count < 100 then
		vim.health.ok("Token counting: " .. count .. " tokens (provider: " .. model_config.provider .. ")")
	else
		-- Try fallback estimation
		local errors_ok, errors = pcall(require, "token-count.utils.errors")
		if errors_ok then
			local estimate, method = errors.get_fallback_estimate(test_text)
			if estimate > 0 then
				vim.health.warn("Token counting", "Primary provider failed, fallback estimation working: " .. estimate .. " tokens")
			else
				vim.health.error("Token counting", "Both primary provider and fallback failed")
			end
		else
			vim.health.error("Token counting", error or "Provider test failed")
		end
	end
	
	-- Test cache functionality
	local cache_ok, cache = pcall(require, "token-count.cache")
	if cache_ok then
		local stats = cache.get_stats()
		if stats then
			vim.health.ok("Cache system: operational")
		else
			vim.health.warn("Cache system", "Stats not available")
		end
	else
		vim.health.error("Cache system", "Failed to load cache module")
	end
	
	-- Test error handling system
	local errors_ok, errors = pcall(require, "token-count.utils.errors")
	if errors_ok then
		local estimate, method = errors.get_fallback_estimate("Test string for error handling.")
		if estimate > 0 and method then
			vim.health.ok("Error handling: fallback estimation working")
		else
			vim.health.warn("Error handling", "Fallback estimation may not be working properly")
		end
	else
		vim.health.warn("Error handling", "Enhanced error handling not available")
	end
end

return M