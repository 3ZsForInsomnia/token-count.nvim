local M = {}

-- Plugin state
local _setup_complete = false

function M.setup(opts)
	-- Initialize system components
	local version = require("token-count.version")
	version.initialize()

	require("token-count.log").setup_log_rotation()


	local config = require("token-count.config")
	config.setup(opts)

	-- Proactively initialize caches asynchronously to prepare for future use
	vim.schedule(function()
		local venv_utils = require("token-count.venv.utils")
		venv_utils.init_python_cache_async()
		
		local dependencies = require("token-count.venv.dependencies")
		for dep_name, _ in pairs(venv_utils.DEPENDENCIES) do
			dependencies.init_dependency_cache_async(dep_name)
		end
		
		-- After all async dependency checks complete, initialize status cache
		-- This is done last to ensure all dependency caches are populated first
		vim.defer_fn(function()
			local venv_setup = require("token-count.venv.setup")
			pcall(venv_setup.init_status_cache) -- Use pcall for safety
		end, 100) -- Small delay to let dependency checks complete
	end)

	-- Setup commands and autocommands
	require("token-count.init.commands").create_commands()
	require("token-count.init.commands").create_venv_commands()

	local current_config = config.get()

	if current_config.cache and current_config.cache.enabled then
		local cache_manager = require("token-count.cache")
		cache_manager.setup(current_config.cache)

		-- Register lualine refresh callback
		cache_manager.register_update_callback(function(path, path_type)
			vim.schedule(function()
				if vim.g.loaded_lualine then
					require("lualine").refresh()
				end
			end)
		end)
	end

	require("token-count.init.setup").initialize_plugin(opts)

	require("token-count.init.events").setup_autocommands()

	local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
	if cleanup_ok then
		cleanup.initialize()
	end

	_setup_complete = true
end

--- Ensure plugin is initialized (simplified check)
local function ensure_initialized()
	if not _setup_complete then
		error("Plugin not setup - call require('token-count').setup() first")
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

--- Count tokens for a file immediately (bypasses queue)
--- @param file_path string Path to the file
--- @param callback function Callback function(result, error)
function M.count_file_immediate(file_path, callback)
	ensure_initialized()
	local cache_manager = require("token-count.cache")
	cache_manager.count_file_immediate(file_path, callback)
end

--- Count tokens for a file in background queue
--- @param file_path string Path to the file
--- @param callback function|nil Optional callback function(result, error)
function M.count_file_background(file_path, callback)
	ensure_initialized()
	local cache_manager = require("token-count.cache")
	cache_manager.count_file_background(file_path, callback)
end

--- Get cached token count for a file
--- @param file_path string Path to the file
--- @return string|nil token_display Formatted token count or nil
function M.get_cached_count(file_path)
	ensure_initialized()
	local cache_manager = require("token-count.cache")
	return cache_manager.get_file_token_count(file_path)
end

--- Invalidate cache for a specific file
--- @param file_path string Path to the file
function M.invalidate_cache(file_path)
	ensure_initialized()
	local cache_manager = require("token-count.cache")
	cache_manager.invalidate_file(file_path, false)
end

function M.cleanup()
	require("token-count.log").info("Starting plugin cleanup...")

	-- Stop and cleanup cache system
	local cache_ok, cache = pcall(require, "token-count.cache")
	if cache_ok and cache.cleanup then
		cache.cleanup()
	end

	-- Reset plugin state
	_setup_complete = false

	require("token-count.log").info("Plugin cleanup completed")
end
return M
