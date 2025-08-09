local M = {}

--- Model configuration mapping
--- @type table<string, {name: string, provider: string, encoding: string, context_window: number}>
M.models = {
    -- OpenAI Models
    ["openai/gpt-4"] = {
        name = "GPT-4",
        provider = "tiktoken",
        encoding = "cl100k_base",
        context_window = 8192
    },
    ["openai/gpt-4-32k"] = {
        name = "GPT-4 32K",
        provider = "tiktoken", 
        encoding = "cl100k_base",
        context_window = 32768
    },
    ["openai/gpt-4-turbo"] = {
        name = "GPT-4 Turbo",
        provider = "tiktoken",
        encoding = "cl100k_base", 
        context_window = 128000
    },
    ["openai/gpt-4o"] = {
        name = "GPT-4o",
        provider = "tiktoken",
        encoding = "cl100k_base",
        context_window = 128000
    },
    ["openai/gpt-4o-mini"] = {
        name = "GPT-4o Mini",
        provider = "tiktoken",
        encoding = "cl100k_base",
        context_window = 128000
    },
    ["openai/gpt-3.5-turbo"] = {
        name = "GPT-3.5 Turbo", 
        provider = "tiktoken",
        encoding = "cl100k_base",
        context_window = 16385
    },
    ["openai/gpt-3.5-turbo-16k"] = {
        name = "GPT-3.5 Turbo 16K",
        provider = "tiktoken",
        encoding = "cl100k_base",
        context_window = 16385
    },
    
    -- GitHub Copilot (approximated with tiktoken)
    ["github/copilot"] = {
        name = "GitHub Copilot",
        provider = "tiktoken",
        encoding = "cl100k_base",
        context_window = 8192
    },
    
    -- Generic fallback option (default)
    ["generic"] = {
        name = "Generic (GPT-4 compatible)",
        provider = "tiktoken",
        encoding = "cl100k_base",
        context_window = 8192
    },
    
    -- Anthropic Models
    ["anthropic/claude-3-haiku"] = {
        name = "Claude 3 Haiku",
        provider = "anthropic",
        encoding = "claude-3-haiku-20240307",
        context_window = 200000
    },
    ["anthropic/claude-3-sonnet"] = {
        name = "Claude 3 Sonnet", 
        provider = "anthropic",
        encoding = "claude-3-sonnet-20240229",
        context_window = 200000
    },
    ["anthropic/claude-3-opus"] = {
        name = "Claude 3 Opus",
        provider = "anthropic", 
        encoding = "claude-3-opus-20240229",
        context_window = 200000
    },
    ["anthropic/claude-3.5-sonnet"] = {
        name = "Claude 3.5 Sonnet",
        provider = "anthropic",
        encoding = "claude-3-5-sonnet-20240620", 
        context_window = 200000
    }
}

return M