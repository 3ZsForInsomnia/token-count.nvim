local M = {}

--- Create lookup tables for different model name types
local function build_lookup_tables()
    local definitions = require('token-count.models.definitions')
    local by_technical = {}
    local by_nice = {}
    local by_tokencost = {}
    
    for technical_name, config in pairs(definitions.models) do
        -- Technical name lookup (this is the primary key)
        by_technical[technical_name] = technical_name
        
        -- Nice name lookup (case-insensitive)
        local nice_lower = config.name:lower()
        by_nice[nice_lower] = technical_name
        
        -- Tokencost name lookup
        if config.tokencost_name then
            by_tokencost[config.tokencost_name] = technical_name
        end
        
        -- Also support legacy openai/ prefixes for backward compatibility
        if technical_name:match("^gpt") or technical_name:match("^o1") then
            by_tokencost["openai/" .. technical_name] = technical_name
        end
        if technical_name:match("^claude") then
            by_tokencost["anthropic/" .. technical_name] = technical_name
        end
        if technical_name:match("^gemini") then
            by_tokencost["google/" .. technical_name] = technical_name
        end
    end
    
    return by_technical, by_nice, by_tokencost
end

--- Resolve a model name to its technical name
--- @param model_name string The model name (technical, nice, or tokencost)
--- @return string|nil technical_name The technical name, or nil if not found
function M.resolve_model_name(model_name)
    if not model_name or model_name == "" then
        return nil
    end
    
    local by_technical, by_nice, by_tokencost = build_lookup_tables()
    
    -- Try technical name first (exact match)
    if by_technical[model_name] then
        return model_name
    end
    
    -- Try tokencost name
    if by_tokencost[model_name] then
        return by_tokencost[model_name]
    end
    
    -- Try nice name (case-insensitive)
    local model_lower = model_name:lower()
    if by_nice[model_lower] then
        return by_nice[model_lower]
    end
    
    -- Try partial matching for nice names
    for nice_name, technical_name in pairs(by_nice) do
        if nice_name:find(model_lower, 1, true) or model_lower:find(nice_name, 1, true) then
            return technical_name
        end
    end
    
    return nil
end

--- Get model configuration by model name
--- @param model_name string The model identifier (technical, nice, or tokencost)
--- @return table|nil model_config The model configuration, or nil if not found
function M.get_model(model_name)
    local technical_name = M.resolve_model_name(model_name)
    if not technical_name then
        return nil
    end
    
    local definitions = require('token-count.models.definitions')
    return definitions.models[technical_name]
end

--- Check if a model is supported
--- @param model_name string The model identifier
--- @return boolean supported Whether the model is supported
function M.is_supported(model_name)
    return M.get_model(model_name) ~= nil
end

--- Get all available model names (returns technical names)
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

--- Get searchable model entries for UI selection
--- @return table[] searchable_models List of models with all searchable names
function M.get_searchable_models()
    local definitions = require('token-count.models.definitions')
    local searchable = {}
    
    for technical_name, config in pairs(definitions.models) do
        local entry = {
            technical_name = technical_name,
            nice_name = config.name,
            tokencost_name = config.tokencost_name,
            provider = config.provider,
            context_window = config.context_window,
            max_output_tokens = config.max_output_tokens,
            config = config,
        }
        table.insert(searchable, entry)
    end
    
    -- Sort by nice name for better user experience
    table.sort(searchable, function(a, b)
        return a.nice_name < b.nice_name
    end)
    
    return searchable
end

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
--- @param provider_name string The provider name ("tokencost", "deepseek", etc.)
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