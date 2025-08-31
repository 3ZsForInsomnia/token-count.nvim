local M = {}

-- Plugin state
local _setup_complete = false
local _deferred_setup = nil

function M.setup(opts)
	-- Check system compatibility first
	local version = require("token-count.version")
	version.initialize()
	
	-- Setup configuration
	local config = require("token-count.config")
	config.setup(opts)

	-- Create user commands (lazy loading on execution)
	require("token-count.init.commands").create_commands()
	require("token-count.init.commands").create_venv_commands()

	-- Store options for deferred setup
	_deferred_setup = opts
	_setup_complete = true
	
	-- Defer heavy initialization until first actual use
	-- This allows the plugin to load fast but initialize properly when needed
end

--- Ensure full plugin initialization (called on first real use)
local function ensure_initialized()
	if not _setup_complete then
		error("Plugin not setup - call require('token-count').setup() first")
	end
	
	-- Only run deferred setup once
	if _deferred_setup ~= nil then
		local opts = _deferred_setup
		_deferred_setup = nil -- Mark as completed
		
		-- Now do the heavy initialization
		local config = require("token-count.config").get()
		
		-- Initialize cache manager if enabled (deferred)
		if config.cache and config.cache.enabled then
			local cache_manager = require("token-count.cache")
			cache_manager.setup(config.cache)
		end
		
		-- Setup autocommands and events (deferred)
		require("token-count.init.events").setup_autocommands()
		
		-- Initialize plugin environment (deferred)
		require("token-count.init.setup").initialize_plugin(opts)
		
		-- Initialize cleanup system
		local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
		if cleanup_ok then
			cleanup.initialize()
		end
	end
end

--- Get current buffer token count (for integrations like lualine)
--- @param callback function Callback function that receives (result, error)
function M.get_current_buffer_count(callback)
	ensure_initialized()
	require("token-count.buffer").count_current_buffer_async(callback)
end

--- Get current buffer token count synchronously (may block)
--- @return number|nil token_count
--- @return string|nil error
function M.get_current_buffer_count_sync()
	ensure_initialized()
	local config = require("token-count.config").get()
	local models = require("token-count.models.utils")
	local buffer = require("token-count.buffer")

	-- Validate current buffer
	local buffer_id, valid = buffer.get_current_buffer_if_valid()
	if not valid then
		return nil, "Invalid buffer filetype"
	end

	-- Get content and model config
	local content = buffer.get_buffer_contents(buffer_id)
	local model_config = models.get_model(config.model)
	if not model_config then
		return nil, "Invalid model: " .. config.model
	end

	-- Get provider and count
	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		return nil, "Failed to load provider: " .. model_config.provider
	end

	return provider.count_tokens_sync(content, model_config.encoding)
end

--- Get available models (for external integrations)
--- @return string[] model_names List of available model names
function M.get_available_models()
	return require("token-count.models.utils").get_available_models()
end

function M.get_current_model()
	local config = require("token-count.config").get()
	return require("token-count.models.utils").get_model(config.model)
end

--- Cleanup function to be called on plugin unload/nvim exit
function M.cleanup()
    require("token-count.log").info("Starting plugin cleanup...")
    
    -- Stop and cleanup cache system
    local cache_ok, cache = pcall(require, "token-count.cache")
    if cache_ok and cache.cleanup then
        cache.cleanup()
    end
    
    -- Reset plugin state
    _setup_complete = false
    _deferred_setup = nil
    
    require("token-count.log").info("Plugin cleanup completed")
end
return M