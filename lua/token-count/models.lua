local M = {}

--- Model configuration mapping
--- @type table<string, {name: string, provider: string, encoding: string, context_window: number}>
M.models = {
	-- OpenAI Models
	["openai/gpt-4"] = {
		name = "GPT-4",
		provider = "tiktoken",
		encoding = "cl100k_base",
		context_window = 8192,
	},
	["openai/gpt-4-32k"] = {
		name = "GPT-4 32K",
		provider = "tiktoken",
		encoding = "cl100k_base",
		context_window = 32768,
	},
	["openai/gpt-4-turbo"] = {
		name = "GPT-4 Turbo",
		provider = "tiktoken",
		encoding = "cl100k_base",
		context_window = 128000,
	},
	["openai/gpt-4o"] = {
		name = "GPT-4o",
		provider = "tiktoken",
		encoding = "cl100k_base",
		context_window = 128000,
	},
	["openai/gpt-4o-mini"] = {
		name = "GPT-4o Mini",
		provider = "tiktoken",
		encoding = "cl100k_base",
		context_window = 128000,
	},
	["openai/gpt-3.5-turbo"] = {
		name = "GPT-3.5 Turbo",
		provider = "tiktoken",
		encoding = "cl100k_base",
		context_window = 16385,
	},
	["openai/gpt-3.5-turbo-16k"] = {
		name = "GPT-3.5 Turbo 16K",
		provider = "tiktoken",
		encoding = "cl100k_base",
		context_window = 16385,
	},

	-- GitHub Copilot (approximated with tiktoken)
	["github/copilot"] = {
		name = "GitHub Copilot",
		provider = "tiktoken",
		encoding = "cl100k_base",
		context_window = 8192,
	},

	-- Generic fallback option (default)
	["generic"] = {
		name = "Generic (GPT-4 compatible)",
		provider = "tiktoken",
		encoding = "cl100k_base",
		context_window = 8192,
	},

	-- Anthropic Models
	["anthropic/claude-3-haiku"] = {
		name = "Claude 3 Haiku",
		provider = "anthropic",
		encoding = "claude-3-haiku-20240307",
		context_window = 200000,
	},
	["anthropic/claude-3-sonnet"] = {
		name = "Claude 3 Sonnet",
		provider = "anthropic",
		encoding = "claude-3-sonnet-20240229",
		context_window = 200000,
	},
	["anthropic/claude-3-opus"] = {
		name = "Claude 3 Opus",
		provider = "anthropic",
		encoding = "claude-3-opus-20240229",
		context_window = 200000,
	},
	["anthropic/claude-3.5-sonnet"] = {
		name = "Claude 3.5 Sonnet",
		provider = "anthropic",
		encoding = "claude-3-5-sonnet-20240620",
		context_window = 200000,
	},
}

--- Get model configuration by model name
--- @param model_name string The model identifier (e.g., "openai/gpt-4")
--- @return table|nil model_config The model configuration, or nil if not found
function M.get_model(model_name)
	return M.models[model_name]
end

--- Check if a model is supported
--- @param model_name string The model identifier
--- @return boolean supported Whether the model is supported
function M.is_supported(model_name)
	return M.models[model_name] ~= nil
end

--- Get all available model names
--- @return string[] model_names List of all supported model identifiers
function M.get_available_models()
	local models = {}
	for model_name, _ in pairs(M.models) do
		table.insert(models, model_name)
	end
	table.sort(models)
	return models
end

--- Get models by provider
--- @param provider_name string The provider name ("tiktoken", "anthropic")
--- @return table<string, table> models Map of model names to configurations for the provider
function M.get_models_by_provider(provider_name)
	local provider_models = {}
	for model_name, config in pairs(M.models) do
		if config.provider == provider_name then
			provider_models[model_name] = config
		end
	end
	return provider_models
end

return M
