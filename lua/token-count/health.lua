--- Health Check System
--- This module provides comprehensive health checking for token-count.nvim
local M = {}

-- Import submodules
local providers = require("token-count.health.providers")
local config = require("token-count.health.config")

function M.check()
	vim.health.start("token-count.nvim")

	-- Run virtual environment and provider checks
	providers.run_venv_checks()
	providers.run_provider_checks()

	-- Run configuration checks
	config.run_config_checks()

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

return M