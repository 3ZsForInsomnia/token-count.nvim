--- Main Plugin Entry Point
--- This module provides the public API for token-count.nvim
local M = {}

-- Import submodules
local commands = require("token-count.init.commands")
local events = require("token-count.init.events")
local setup = require("token-count.init.setup")

function M.setup(opts)
	-- Setup configuration
	local config = require("token-count.config")
	config.setup(opts)

	-- Initialize cache manager if enabled
	local current_config = config.get()
	if current_config.cache and current_config.cache.enabled then
		local cache_manager = require("token-count.cache")
		cache_manager.setup(current_config.cache)
	end

	-- Create user commands
	commands.create_commands()
	commands.create_venv_commands()

	-- Setup autocommands and events
	events.setup_autocommands()

	-- Initialize plugin environment
	setup.initialize_plugin(opts)
end

--- Get current buffer token count (for integrations like lualine)
--- @param callback function Callback function that receives (result, error)
function M.get_current_buffer_count(callback)
	require("token-count.buffer").count_current_buffer_async(callback)
end

--- Get current buffer token count synchronously (may block)
--- @return number|nil token_count
--- @return string|nil error
function M.get_current_buffer_count_sync()
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

--- Get current model configuration
--- @return table model_config Current model configuration
function M.get_current_model()
	local config = require("token-count.config").get()
	return require("token-count.models.utils").get_model(config.model)
end

return M