--- Multiple buffer token counting operations
local M = {}

--- Get buffer display name
--- @param buffer_id number Buffer ID
--- @return string name Display name for the buffer
function M.get_buffer_display_name(buffer_id)
	local buf_name = vim.api.nvim_buf_get_name(buffer_id)
	if buf_name ~= "" then
		return vim.fn.fnamemodify(buf_name, ":t")
	else
		return "[No Name]"
	end
end

--- Count tokens for multiple buffers asynchronously
--- @param buffer_ids number[] Array of buffer IDs
--- @param model_config table Model configuration
--- @param callback function Callback that receives (total_tokens, buffer_results, error)
function M.count_multiple_buffers_async(buffer_ids, model_config, callback)
	-- Schedule to avoid fast event context restrictions for nvim API calls
	vim.schedule(function()
		M._count_multiple_buffers_impl(buffer_ids, model_config, callback)
	end)
end

--- Internal implementation for counting multiple buffers
--- @param buffer_ids number[] Array of buffer IDs
--- @param model_config table Model configuration
--- @param callback function Callback that receives (total_tokens, buffer_results, error)
function M._count_multiple_buffers_impl(buffer_ids, model_config, callback)
	local buffer = require("token-count.buffer")
	local models = require("token-count.models.utils")

	if #buffer_ids == 0 then
		callback(0, {}, nil)
		return
	end

	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		callback(nil, nil, "Failed to load provider: " .. model_config.provider)
		return
	end

	local total_tokens = 0
	local completed = 0
	local buffer_results = {}
	local has_error = false

	-- Count tokens for each buffer
	for _, buf_id in ipairs(buffer_ids) do
		local content = buffer.get_buffer_contents(buf_id)

		provider.count_tokens_async(content, model_config.encoding, function(token_count, error)
			completed = completed + 1

			if not has_error then
				if error then
					has_error = true
					callback(nil, nil, error)
					return
				end

				if token_count then
					total_tokens = total_tokens + token_count
					table.insert(buffer_results, {
						buffer_id = buf_id,
						name = M.get_buffer_display_name(buf_id),
						tokens = token_count,
					})
				end

				-- When all buffers are processed
				if completed == #buffer_ids then
					callback(total_tokens, buffer_results, nil)
				end
			end
		end)
	end
end

--- Validate current buffer and get content
--- @return string|nil content Buffer content, or nil if invalid
--- @return string|nil error Error message if validation failed
function M.validate_and_get_current_buffer()
	local buffer = require("token-count.buffer")

	-- Validate current buffer
	local buffer_id, valid = buffer.get_current_buffer_if_valid()
	if not valid then
		return nil, "Invalid buffer filetype"
	end

	-- Get content
	local content = buffer.get_buffer_contents(buffer_id)
	if not content or content == "" then
		return nil, "Buffer is empty"
	end

	return content, nil
end

return M