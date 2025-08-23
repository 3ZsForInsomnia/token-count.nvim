--- Buffer validation and filetype checking
local M = {}

--- Check if a filetype is valid/acceptable for token counting
--- @param filetype string The filetype to check
--- @return boolean valid Whether the filetype is acceptable
function M.is_valid_filetype(filetype)
	-- List of acceptable filetypes (text-based files)
	local valid_types = {
		-- Programming languages
		"lua", "python", "javascript", "typescript", "java", "c", "cpp", "rust",
		"go", "ruby", "php", "swift", "kotlin", "scala", "clojure", "haskell",
		"vim", "viml", "bash", "sh", "zsh", "fish", "powershell",

		-- Web technologies
		"html", "css", "scss", "sass", "less", "vue", "svelte", "jsx", "tsx",
		"json", "xml", "yaml", "yml", "toml",

		-- Documentation and text
		"markdown", "md", "txt", "text", "rst", "org", "tex", "latex",

		-- Configuration files
		"conf", "config", "ini", "cfg", "properties", "gitignore", "gitconfig",
		"dockerfile", "docker", "makefile", "cmake",

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

--- Check if a buffer is safe to work with (not floating, not special)
--- @param buffer_id number Buffer ID to check
--- @return boolean safe Whether the buffer is safe to work with
function M.is_safe_buffer(buffer_id)
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
	if
		bufname:match("telescope://")
		or bufname:match("^%[.*%]$") -- Buffers like [Command Line], [Prompt]
		or bufname:match("neo%-tree")
		or bufname:match("NvimTree")
		or bufname:match("^term://")
	then
		return false
	end

	return true
end

--- Check if a buffer is valid for token counting without switching to it
--- @param buffer_id number Buffer ID to check
--- @return boolean valid Whether the buffer is valid for token counting
function M.is_buffer_valid_for_counting(buffer_id)
	-- First check if buffer is safe to work with
	if not M.is_safe_buffer(buffer_id) then
		return false
	end

	-- Get filetype without switching buffers
	local filetype = vim.api.nvim_buf_get_option(buffer_id, "filetype")
	return M.is_valid_filetype(filetype)
end

return M