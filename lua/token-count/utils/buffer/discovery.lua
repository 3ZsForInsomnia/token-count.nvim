--- Buffer discovery and validation for multiple buffer operations
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

return M