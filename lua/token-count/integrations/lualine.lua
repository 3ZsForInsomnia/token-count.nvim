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

local cache = {
	current_buffer = {
		buffer_id = nil,
		token_count = nil,
		timestamp = 0,
		cache_duration = 10000, -- 10 seconds
	},
	visual_selection = {
		buffer_id = nil,
		selection_text = nil,
		token_count = nil,
		timestamp = 0,
		cache_duration = 2000, -- 2 seconds (shorter for visual selection)
	},
	all_buffers = {
		token_count = nil,
		percentage = nil,
		timestamp = 0,
		cache_duration = 60000, -- 60 seconds
	},
}

--- Visual selection polling timer
local visual_poll_timer = nil
local visual_mode_active = false

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

--- Get visual selection text
--- @return string|nil selection_text The selected text, or nil if no selection
local function get_visual_selection_text()
	local mode = vim.fn.mode()
	if not (mode == "v" or mode == "V" or mode == "\22") then -- visual modes
		return nil
	end

	-- Get the selection range
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	if start_pos[1] == 0 or end_pos[1] == 0 then
		return nil -- No valid selection
	end

	-- Get the selected lines
	local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
	if #lines == 0 then
		return nil
	end

	-- Handle single line selection
	if #lines == 1 then
		local line = lines[1]
		if mode == "v" then -- character-wise
			local start_col = start_pos[3]
			local end_col = end_pos[3]
			return line:sub(start_col, end_col)
		else
			return line
		end
	end

	-- Handle multi-line selection
	if mode == "v" then -- character-wise visual
		lines[1] = lines[1]:sub(start_pos[3])
		lines[#lines] = lines[#lines]:sub(1, end_pos[3])
	end

	return table.concat(lines, "\n")
end

--- Count tokens for visual selection (cached)
--- @return number|nil token_count Token count for selection, or nil if no selection/error
local function get_visual_selection_count()
	local selection_text = get_visual_selection_text()
	if not selection_text or selection_text == "" then
		return nil
	end

	local current_buf = vim.api.nvim_get_current_buf()

	-- Check cache validity
	if
		cache.visual_selection.buffer_id == current_buf
		and cache.visual_selection.selection_text == selection_text
		and is_cache_valid(cache.visual_selection)
	then
		return cache.visual_selection.token_count
	end

	-- Cache is invalid or missing - trigger async count
	local token_count_ok, token_count_module = pcall(require, "token-count")
	if not token_count_ok then
		return nil
	end

	-- Use the same logic as current buffer but with selection text
	local models_ok, models = pcall(require, "token-count.models.utils")
	local config_ok, config = pcall(require, "token-count.config")

	if not (models_ok and config_ok) then
		return nil
	end

	local current_config = config.get()
	local model_config = models.get_model(current_config.model)
	if not model_config then
		return nil
	end

	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		return nil
	end

	-- Use async counting to avoid blocking
	provider.count_tokens_async(selection_text, model_config.encoding, function(count, error)
		if count then
			update_cache(cache.visual_selection, {
				buffer_id = current_buf,
				selection_text = selection_text,
				token_count = count,
			})
		end
	end)

	-- Return cached value if we have one for this selection, even if expired
	if
		cache.visual_selection.buffer_id == current_buf
		and cache.visual_selection.selection_text == selection_text
		and cache.visual_selection.token_count
	then
		return cache.visual_selection.token_count
	else
		return nil
	end
end

--- Start visual selection polling
local function start_visual_polling()
	if visual_poll_timer then
		return -- Already polling
	end

	visual_poll_timer = vim.loop.new_timer()
	visual_poll_timer:start(
		0,
		500,
		vim.schedule_wrap(function() -- Every 500ms
			local mode = vim.fn.mode()
			local in_visual = (mode == "v" or mode == "V" or mode == "\22")

			if not in_visual and visual_mode_active then
				-- Left visual mode, stop polling
				stop_visual_polling()
			end

			visual_mode_active = in_visual
		end)
	)
end

--- Stop visual selection polling
local function stop_visual_polling()
	if visual_poll_timer then
		visual_poll_timer:stop()
		visual_poll_timer:close()
		visual_poll_timer = nil
	end
	visual_mode_active = false
end

local function get_current_buffer_display()
	local current_buf = vim.api.nvim_get_current_buf()

	-- Double-check buffer validity at display time
	local buffer_ok, buffer = pcall(require, "token-count.buffer")
	if not buffer_ok then
		return ""
	end

	local _, valid = buffer.get_current_buffer_if_valid()
	if not valid then
		return ""
	end

	-- Check if we're in visual mode and have a selection
	local mode = vim.fn.mode()
	local in_visual = (mode == "v" or mode == "V" or mode == "\22")

	if in_visual then
		start_visual_polling()
		local selection_count = get_visual_selection_count()
		if selection_count then
			-- Get total buffer count for context
			local buffer_count = nil
			if cache.current_buffer.buffer_id == current_buf and is_cache_valid(cache.current_buffer) then
				buffer_count = cache.current_buffer.token_count
			else
				-- Don't block - just use cached value or trigger async update
				local token_count_ok, token_count_module = pcall(require, "token-count")
				if token_count_ok then
					-- Trigger async update for next time
					token_count_module.get_current_buffer_count(function(result, error)
						if result and result.token_count then
							update_cache(cache.current_buffer, {
								buffer_id = current_buf,
								token_count = result.token_count,
							})
						end
					end)
				end
				-- Use nil for now, will show "selection only" format
				buffer_count = nil
			end

			if buffer_count then
				return string.format("🪙 %d/%d", selection_count, buffer_count)
			else
				return "🪙 " .. selection_count .. " (sel)"
			end
		end
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
		cache_duration = 5000,
	}
	cache.visual_selection = {
		buffer_id = nil,
		selection_text = nil,
		token_count = nil,
		timestamp = 0,
		cache_duration = 1500,
	}
	cache.all_buffers = {
		token_count = nil,
		percentage = nil,
		timestamp = 0,
		cache_duration = 60000,
	}

	-- Stop polling when clearing cache
	stop_visual_polling()
end

--- @param visual_duration number Cache duration for visual selection (ms)
function M.configure_cache(current_duration, visual_duration, all_duration)
	if current_duration then
		cache.current_buffer.cache_duration = current_duration
	end
	if visual_duration then
		cache.visual_selection.cache_duration = visual_duration
	end
	if all_duration then
		cache.all_buffers.cache_duration = all_duration
	end
end

--- Create a command for detailed visual selection info
function M.create_selection_command()
	vim.api.nvim_create_user_command("TokenCountSelection", function()
		local selection_count = get_visual_selection_count()
		if not selection_count then
			vim.notify("No visual selection or unable to count tokens", vim.log.levels.WARN)
			return
		end

		-- Get model info for context
		local config_ok, config = pcall(require, "token-count.config")
		local models_ok, models = pcall(require, "token-count.models.utils")

		if config_ok and models_ok then
			local current_config = config.get()
			local model_config = models.get_model(current_config.model)
			if model_config then
				local percentage = (selection_count / model_config.context_window) * 100
				vim.notify(
					string.format(
						"Selection: %d tokens (%.1f%% of context window) - Model: %s",
						selection_count,
						percentage,
						model_config.name
					),
					vim.log.levels.INFO
				)
				return
			end
		end

		vim.notify("Selection: " .. selection_count .. " tokens", vim.log.levels.INFO)
	end, {
		desc = "Show detailed token count for visual selection",
	})
end

return M
