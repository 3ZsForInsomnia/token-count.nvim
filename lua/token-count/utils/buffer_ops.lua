local M = {}

--- Check if a buffer is safe and valid for token counting
--- @param buffer_id number Buffer ID to check
--- @return boolean valid Whether the buffer is valid for token counting
function M.is_buffer_safe_for_counting(buffer_id)
	-- Check if buffer exists and is loaded
	if not vim.api.nvim_buf_is_valid(buffer_id) or not vim.api.nvim_buf_is_loaded(buffer_id) then
		return false
	end
	
	-- Check buffer type - skip special buffers
	local buftype = vim.api.nvim_buf_get_option(buffer_id, "buftype")
	if buftype ~= "" then
		return false -- Skip quickfix, help, terminal, etc.
	end
	
	-- Check if buffer is in a floating window
	local win_ids = vim.fn.win_findbuf(buffer_id)
	for _, win_id in ipairs(win_ids) do
		if vim.api.nvim_win_is_valid(win_id) then
			local win_config = vim.api.nvim_win_get_config(win_id)
			if win_config.relative ~= "" then
				return false -- Skip floating windows
			end
		end
	end
	
	-- Check for telescope and other plugin buffers by name patterns
	local bufname = vim.api.nvim_buf_get_name(buffer_id)
	if bufname:match("telescope://") or 
	   bufname:match("^%[.*%]$") or  -- Buffers like [Command Line], [Prompt]
	   bufname:match("neo%-tree") or
	   bufname:match("NvimTree") or
	   bufname:match("^term://") then
		return false
	end
	
	-- Check filetype validity using the existing validation
	local filetype = vim.api.nvim_buf_get_option(buffer_id, "filetype")
	
	-- Replicate the filetype validation logic from buffer.lua
	local valid_types = {
		-- Programming languages
		"lua", "python", "javascript", "typescript", "java", "c", "cpp", "rust", "go", "ruby", "php",
		"swift", "kotlin", "scala", "clojure", "haskell", "vim", "viml", "bash", "sh", "zsh", "fish", "powershell",
		-- Web technologies
		"html", "css", "scss", "sass", "less", "vue", "svelte", "jsx", "tsx", "json", "xml", "yaml", "yml", "toml",
		-- Documentation and text
		"markdown", "md", "txt", "text", "rst", "org", "tex", "latex",
		-- Configuration files
		"conf", "config", "ini", "cfg", "properties", "gitignore", "gitconfig", "dockerfile", "docker", "makefile", "cmake",
		-- Data formats
		"csv", "tsv", "sql", "graphql", "proto",
		-- Other common text formats
		"log", "diff", "patch",
	}
	
	-- Handle empty or nil filetype
	if not filetype or filetype == "" then
		return false
	end
	
	-- Check if filetype is in our valid list
	for _, valid_type in ipairs(valid_types) do
		if filetype == valid_type then
			return true
		end
	end
	
	return false
end

--- Get all valid buffers for token counting
--- @return number[] buffer_ids Array of valid buffer IDs
function M.get_valid_buffers()
	local all_buffers = vim.api.nvim_list_bufs()
	local valid_buffers = {}

	-- Filter to valid, loaded buffers without switching to them
	for _, buf_id in ipairs(all_buffers) do
		if vim.api.nvim_buf_is_loaded(buf_id) then
			-- Check validity without switching buffers - safer approach
			if M.is_buffer_safe_for_counting(buf_id) then
				table.insert(valid_buffers, buf_id)
			end
		end
	end

	return valid_buffers
end

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