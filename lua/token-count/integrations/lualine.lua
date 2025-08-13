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

-- Simplified cache structure - no visual selection caching
local cache = {
	current_buffer = {
		buffer_id = nil,
		token_count = nil,
		timestamp = 0,
		cache_duration = 10000, -- 10 seconds
	},
	all_buffers = {
		token_count = nil,
		percentage = nil,
		timestamp = 0,
		cache_duration = 60000, -- 60 seconds
	},
}

--- Check if cache is valid
--- @param cache_entry table Cache entry to check
--- @return boolean valid Whether cache is still valid
local function is_cache_valid(cache_entry)
	local now = vim.loop.hrtime() / 1000000 -- Convert to milliseconds
	return (now - cache_entry.timestamp) < cache_entry.cache_duration
end

--- Update cache entry
--- @param cache_entry table Cache entry to update
--- @param data table Data to store in cache
local function update_cache(cache_entry, data)
	cache_entry.timestamp = vim.loop.hrtime() / 1000000
	for key, value in pairs(data) do
		cache_entry[key] = value
	end
end

--- Get current buffer token count display
--- @return string display_text Text to show in lualine
local function get_current_buffer_display()
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

	-- Check cache validity
	local has_cached_data = cache.current_buffer.buffer_id == current_buf
	local cache_is_valid = has_cached_data and is_cache_valid(cache.current_buffer)

	if cache_is_valid then
		if cache.current_buffer.token_count then
			return "🪙 " .. cache.current_buffer.token_count
		else
			return ""
		end
	end

	-- Cache is invalid or missing - trigger async count
	local token_count_ok, token_count_module = pcall(require, "token-count")
	if not token_count_ok then
		return "" -- Plugin not loaded
	end

	-- Use async counting to avoid blocking
	token_count_module.get_current_buffer_count(function(result, error)
		if result and result.token_count then
			update_cache(cache.current_buffer, {
				buffer_id = current_buf,
				token_count = result.token_count,
			})
		else
			update_cache(cache.current_buffer, {
				buffer_id = current_buf,
				token_count = nil,
			})
		end
	end)

	-- Return cached value if we have one for this buffer, even if expired
	if cache.current_buffer.buffer_id == current_buf and cache.current_buffer.token_count then
		return "🪙 " .. cache.current_buffer.token_count
	else
		return ""
	end
end

--- Get all buffers token count and percentage (cached)
--- @return string display_text Text to show in lualine
local function get_all_buffers_display()
	-- Don't count during UI operations that might be sensitive
	local mode = vim.fn.mode()
	if mode == "c" then -- Command-line mode
		return cache.all_buffers.token_count and 
		       string.format("🪙 %d (%.1f%%)", cache.all_buffers.token_count, cache.all_buffers.percentage) or ""
	end
	
	-- Check if we're in a floating window
	local win_config = vim.api.nvim_win_get_config(0)
	if win_config.relative ~= "" then
		return cache.all_buffers.token_count and 
		       string.format("🪙 %d (%.1f%%)", cache.all_buffers.token_count, cache.all_buffers.percentage) or ""
	end
	-- Check cache validity
	if is_cache_valid(cache.all_buffers) then
		if cache.all_buffers.token_count then
			return string.format("🪙 %d (%.1f%%)", cache.all_buffers.token_count, cache.all_buffers.percentage)
		else
			return ""
		end
	end

	-- Get fresh data asynchronously and return cached data for now
	local token_count_ok, buffer_ops = pcall(require, "token-count.utils.buffer_ops")
	local models_ok, models = pcall(require, "token-count.models.utils")
	local config_ok, config = pcall(require, "token-count.config")

	if not (token_count_ok and models_ok and config_ok) then
		vim.notify(
			"Token Count: Unable to load required modules for lualine integration.\nToken-count.nvim is not loaded!",
			vim.log.levels.WARN
		)
		return ""
	end
	--
	-- -- Get configuration
	local current_config = config.get()
	local model_config = models.get_model(current_config.model)

	if not model_config then
		vim.notify("Token Count: Invalid model configuration for lualine integration", vim.log.levels.WARN)
		return ""
	end

	-- Get valid buffers and count asynchronously
	local valid_buffers = buffer_ops.get_valid_buffers()
	if #valid_buffers == 0 then
		update_cache(cache.all_buffers, { token_count = 0, percentage = 0 })
		return "🪙 0 (0.0%)"
	end

	buffer_ops.count_multiple_buffers_async(valid_buffers, model_config, function(total_tokens, buffer_results, error)
		if not error and total_tokens then
			local percentage = (total_tokens / model_config.context_window) * 100
			update_cache(cache.all_buffers, {
				token_count = total_tokens,
				percentage = percentage,
			})
		else
			update_cache(cache.all_buffers, { token_count = nil, percentage = nil })
		end
	end)

	-- -- Return cached value or empty if no cache
	if cache.all_buffers.token_count then
		return string.format("🪙 %d (%.1f%%)", cache.all_buffers.token_count, cache.all_buffers.percentage)
	else
		return "🪙 0 (0.0%)"
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
	color = function()
		-- Change color based on context window usage
		-- Add defensive checks to prevent accessing undefined values
		if cache.all_buffers and cache.all_buffers.percentage and type(cache.all_buffers.percentage) == "number" then
			local config_ok, config = pcall(require, "token-count.config")
			if config_ok then
				local current_config = config.get()
				if current_config and current_config.context_warning_threshold then
					local threshold = current_config.context_warning_threshold * 100
					if cache.all_buffers.percentage > threshold then
						return { fg = "#e06c75" } -- Red for warning
					end
				end
			end
		end
		return { fg = "#61afef" } -- Blue for normal (always return a valid color)
	end,
}

function M.clear_cache()
	cache.current_buffer = {
		buffer_id = nil,
		token_count = nil,
		timestamp = 0,
		cache_duration = 10000,
	}
	cache.all_buffers = {
		token_count = nil,
		percentage = nil,
		timestamp = 0,
		cache_duration = 60000,
	}
end

--- Configure cache durations
--- @param current_duration number Cache duration for current buffer (ms)
--- @param all_duration number Cache duration for all buffers (ms)
function M.configure_cache(current_duration, all_duration)
	if current_duration then
		cache.current_buffer.cache_duration = current_duration
	end
	if all_duration then
		cache.all_buffers.cache_duration = all_duration
	end
end

return M
