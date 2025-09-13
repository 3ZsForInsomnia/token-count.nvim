-- Lualine component for token-count.nvim
-- Usage:
--   require('lualine').setup({
--     sections = {
--       lualine_c = { require('token-count.integrations.lualine').current_buffer }
--     },
--     winbar = {
--       lualine_c = { require('token-count.integrations.lualine').all_buffers }
--     }
--   })

local M = {}

local initialized = false

local function ensure_initialized()
	if not initialized then
		M.init()
		initialized = true
	end
end

--- Get cache manager (lazy loaded)
local function get_cache_manager()
	return require("token-count.cache")
end

local function get_current_buffer_display()
	ensure_initialized()

	local current_buf = vim.api.nvim_get_current_buf()

	-- Don't count during UI operations that might be sensitive
	local mode = vim.fn.mode()
	if mode == "c" then -- Command-line mode
		return ""
	end

	-- Check if we're in a floating window
	local win_config = vim.api.nvim_win_get_config(0)
	if win_config.relative ~= "" then
		return ""
	end

	-- Double-check buffer validity at display time
	local buffer_ok, buffer = pcall(require, "token-count.buffer")
	if not buffer_ok then
		return ""
	end

	local _, valid = buffer.get_current_buffer_if_valid()
	if not valid then
		return ""
	end

	-- Get current buffer file path and request token count
	local buffer_path = vim.api.nvim_buf_get_name(current_buf)
	if not buffer_path or buffer_path == "" then
		return ""
	end

	-- Request token count from unified cache
	local cache_manager = get_cache_manager()
	local count = cache_manager.get_file_token_count(buffer_path)
	if count and count ~= cache_manager.get_config().placeholder_text then
		return "🪙 " .. count
	else
		return ""
	end
end

--- Get all buffers token count display (simplified)
--- @return string display_text Text to show in lualine
local function get_all_buffers_display()
	ensure_initialized()

	-- Don't count during UI operations that might be sensitive
	local mode = vim.fn.mode()
	if mode == "c" then -- Command-line mode
		return ""
	end

	-- Check if we're in a floating window
	local win_config = vim.api.nvim_win_get_config(0)
	if win_config.relative ~= "" then
		return ""
	end

	-- Get valid buffers count
	local buffer_ops_ok, buffer_ops = pcall(require, "token-count.utils.buffer_ops")
	if not buffer_ops_ok then
		return ""
	end

	local valid_buffers = buffer_ops.get_valid_buffers()
	if #valid_buffers == 0 then
		return "🪙 0 buffers"
	end

	return string.format("🪙 %d buffers", #valid_buffers)
end

function M.init()
	local cache_manager = get_cache_manager()

	-- Register callback for cache updates to trigger lualine refresh
	cache_manager.register_update_callback(function(path, path_type)
		-- Cache updates automatically trigger lualine refresh via the unified cache
		-- No additional action needed since we're using the unified cache directly
	end)

	-- Set up buffer change detection for current buffer invalidation
	local augroup = vim.api.nvim_create_augroup("TokenCountLualine", { clear = true })

	-- Register autocommand group for cleanup tracking
	local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
	if cleanup_ok then
		cleanup.register_autocommand_group(augroup, "token_count_lualine")
	end

end

--- Lualine component for current buffer token count
M.current_buffer = {
	function()
		return get_current_buffer_display()
	end,
	cond = function()
		-- Only show if buffer is valid for token counting
		local buffer_ok, buffer = pcall(require, "token-count.buffer")
		if not buffer_ok then
			return false
		end

		local _, valid = buffer.get_current_buffer_if_valid()
		return valid
	end,
	color = { fg = "#98c379" }, -- Nice green color
}

--- Lualine component for all buffers token count
M.all_buffers = {
	function()
		return get_all_buffers_display()
	end,
	cond = function()
		-- Only show if plugin is loaded and there are valid buffers
		local buffer_ops_ok, buffer_ops = pcall(require, "token-count.utils.buffer_ops")
		if not buffer_ops_ok then
			return false
		end

		local valid_buffers = buffer_ops.get_valid_buffers()
		return #valid_buffers > 0
	end,
	color = { fg = "#61afef" }, -- Blue for normal
}

function M.clear_cache()
	get_cache_manager().clear_cache()
end

return M
