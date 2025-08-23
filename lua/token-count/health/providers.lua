--- Virtual environment and provider checks
local M = {}

local utils = require("token-count.health.utils")

--- Run virtual environment checks
function M.run_venv_checks()
	-- Check virtual environment setup
	local venv_ok, venv = pcall(require, "token-count.venv")
	if venv_ok then
		local status = venv.get_status()

		-- Check Python availability
		utils.report_check("Python 3 available", status.python_available, status.python_info)

		-- Check virtual environment
		if status.venv_exists then
			utils.report_check("Plugin virtual environment", true, nil, status.venv_path)
		else
			vim.health.warn("Plugin virtual environment", "Not found - will be created automatically")
		end

		-- Check tiktoken in venv
		if status.tiktoken_installed then
			utils.report_check("tiktoken in venv", true)
		else
			vim.health.warn(
				"tiktoken in venv",
				status.tiktoken_error or "Not installed - will be installed automatically"
			)
		end

		-- Overall venv status
		if status.ready then
			vim.health.ok("Virtual environment ready")
		else
			vim.health.info("Virtual environment will be set up automatically on first use")
		end
	else
		vim.health.error("Virtual environment module", "Failed to load venv module")
	end
end

--- Run provider library checks
function M.run_provider_checks()
	-- Check tokencost library (primary)
	local tokencost_ok, tokencost_err = utils.check_python_library("tokencost")
	if tokencost_ok then
		utils.report_check("tokencost library", true, nil, "Primary token counting library available")
	else
		vim.health.warn("tokencost library", tokencost_err .. " (will be installed automatically)")
	end

	-- Check deepseek_tokenizer library
	local deepseek_ok, deepseek_err = utils.check_python_library("deepseek_tokenizer")
	if deepseek_ok then
		utils.report_check("deepseek_tokenizer library", true, nil, "Available for DeepSeek models")
	else
		vim.health.warn("deepseek_tokenizer library", deepseek_err .. " (will be installed automatically)")
	end

	-- Check anthropic library (optional)
	local anthropic_ok, anthropic_err = utils.check_python_library("anthropic")
	if anthropic_ok then
		utils.report_check("anthropic library", true, nil, "Available for future use")
	else
		vim.health.warn("anthropic library", anthropic_err .. " (optional - only needed for Anthropic models)")
	end

	-- Check google-genai library (optional)
	local gemini_ok, gemini_err = utils.check_python_library("google.genai")
	if gemini_ok then
		utils.report_check("google-genai library", true, nil, "Available for future use")
	else
		vim.health.warn("google-genai library", gemini_err .. " (optional - only needed for Google GenAI models)")
	end

	-- Check provider API keys
	local anthropic_api_key = vim.fn.getenv("ANTHROPIC_API_KEY")
	if anthropic_api_key and anthropic_api_key ~= vim.NIL and anthropic_api_key ~= "" then
		utils.report_check("Anthropic API key", true, nil, "ANTHROPIC_API_KEY configured")
	else
		vim.health.warn("Anthropic API key", "ANTHROPIC_API_KEY environment variable not set (required for Anthropic models)")
	end

	local google_api_key = vim.fn.getenv("GOOGLE_API_KEY")
	if google_api_key and google_api_key ~= vim.NIL and google_api_key ~= "" then
		utils.report_check("Google API key", true, nil, "GOOGLE_API_KEY configured")
	else
		vim.health.warn("Google API key", "GOOGLE_API_KEY environment variable not set (required for Google GenAI models)")
	end

	-- Check provider availability
	local providers = {
		{ name = "tokencost", module = "token-count.providers.tokencost", required = true },
		{ name = "deepseek", module = "token-count.providers.deepseek", required = false },
		{ name = "tiktoken", module = "token-count.providers.tiktoken", required = false },
		{ name = "anthropic", module = "token-count.providers.anthropic", required = false },
		{ name = "gemini", module = "token-count.providers.gemini", required = false },
	}

	for _, provider in ipairs(providers) do
		local provider_ok, provider_module = pcall(require, provider.module)
		if provider_ok and provider_module.check_availability then
			local available, error_msg = provider_module.check_availability()
			if available then
				utils.report_check(provider.name .. " provider", true, nil, "Ready")
			else
				if provider.required then
					vim.health.error(provider.name .. " provider", error_msg)
				else
					vim.health.warn(provider.name .. " provider", error_msg)
				end
			end
		else
			if provider.required then
				vim.health.error(provider.name .. " provider", "Failed to load provider module")
			else
				vim.health.warn(provider.name .. " provider", "Failed to load provider module")
			end
		end
	end
end

return M