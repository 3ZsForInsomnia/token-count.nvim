local M = {}

--- Get model configuration by model name
--- @param model_name string The model identifier (e.g., "openai/gpt-4")
--- @return table|nil model_config The model configuration, or nil if not found
function M.get_model(model_name)
    local definitions = require('token-count.models.definitions')
    return definitions.models[model_name]
end

--- Check if a model is supported
--- @param model_name string The model identifier
--- @return boolean supported Whether the model is supported
function M.is_supported(model_name)
    return M.get_model(model_name) ~= nil
end

--- Get all available model names
--- @return string[] model_names List of all supported model identifiers
function M.get_available_models()
    local definitions = require('token-count.models.definitions')
    local models = {}
    for model_name, _ in pairs(definitions.models) do
        table.insert(models, model_name)
    end
    table.sort(models)
    return models
end

--- Get models by provider
--- @param provider_name string The provider name ("tiktoken", "anthropic")
--- @return table<string, table> models Map of model names to configurations for the provider
function M.get_models_by_provider(provider_name)
    local definitions = require('token-count.models.definitions')
    local provider_models = {}
    for model_name, config in pairs(definitions.models) do
        if config.provider == provider_name then
            provider_models[model_name] = config
        end
    end
    return provider_models
end

--- Get provider handler module by provider name
--- @param provider_name string The provider name ("tiktoken", "anthropic")
--- @return table|nil provider The provider module, or nil if not found
function M.get_provider_handler(provider_name)
    local success, provider = pcall(require, "token-count.providers." .. provider_name)
    if success then
        return provider
    else
        require('token-count.log').error("Failed to load provider: " .. provider_name .. " - " .. tostring(provider))
        return nil
    end
end

return M