local M = {}

--- Get the contents of a buffer by ID
--- @param buffer_id number Buffer ID
--- @return string content The full buffer content as a string
function M.get_buffer_contents(buffer_id)
	local lines = vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false)
	return table.concat(lines, "\n")
end

--- Check if a filetype is valid/acceptable for token counting
--- @param filetype string The filetype to check
--- @return boolean valid Whether the filetype is acceptable
local function is_valid_filetype(filetype)
	-- List of acceptable filetypes (text-based files)
	local valid_types = {
		-- Programming languages
		"lua",
		"python",
		"javascript",
		"typescript",
		"java",
		"c",
		"cpp",
		"rust",
		"go",
		"ruby",
		"php",
		"swift",
		"kotlin",
		"scala",
		"clojure",
		"haskell",
		"vim",
		"viml",
		"bash",
		"sh",
		"zsh",
		"fish",
		"powershell",

		-- Web technologies
		"html",
		"css",
		"scss",
		"sass",
		"less",
		"vue",
		"svelte",
		"jsx",
		"tsx",
		"json",
		"xml",
		"yaml",
		"yml",
		"toml",

		-- Documentation and text
		"markdown",
		"md",
		"txt",
		"text",
		"rst",
		"org",
		"tex",
		"latex",

		-- Configuration files
		"conf",
		"config",
		"ini",
		"cfg",
		"properties",
		"gitignore",
		"gitconfig",
		"dockerfile",
		"docker",
		"makefile",
		"cmake",

		-- Data formats
		"csv",
		"tsv",
		"sql",
		"graphql",
		"proto",

		-- Other common text formats
		"log",
		"diff",
		"patch",
	}

	-- Handle empty or nil filetype
	if not filetype or filetype == "" then
		return true -- Allow files without specific filetype
	end

	-- Check if filetype is in our valid list
	for _, valid_type in ipairs(valid_types) do
		if filetype == valid_type then
			return true
		end
	end

	return false
end

--- Get current active buffer and check if it's valid for token counting
--- @return number|nil buffer_id The buffer ID if valid, nil if invalid
--- @return boolean valid Whether the buffer is valid for token counting
function M.get_current_buffer_if_valid()
	local buffer_id = vim.api.nvim_get_current_buf()
	local filetype = vim.api.nvim_buf_get_option(buffer_id, "filetype")

	local valid = is_valid_filetype(filetype)

	if valid then
		return buffer_id, true
	else
		return nil, false
	end
end

--- Count tokens for the current buffer
--- @param callback function Callback function that receives (result, error)
---   result = {token_count: number, model_name: string, model_config: table, buffer_id: number}
---   error = string error message
function M.count_current_buffer_async(callback)
	local log = require("token-count.log")

	-- Get current buffer and validate
	local buffer_id, valid = M.get_current_buffer_if_valid()
	if not valid then
		local error_msg = "Current buffer has invalid filetype for token counting"
		log.warn(error_msg)
		callback(nil, error_msg)
		return
	end

	-- Get buffer contents
	local content = M.get_buffer_contents(buffer_id)
	if not content or content == "" then
		local error_msg = "Buffer is empty"
		log.info(error_msg)
		callback(nil, error_msg)
		return
	end

	-- Get current configuration
	local config = require("token-count.config").get()
	local model_name = config.model

	-- Get model configuration
	local models = require("token-count.models.utils")
	local model_config = models.get_model(model_name)
	if not model_config then
		local error_msg = "Unknown model: " .. model_name
		log.error(error_msg)
		callback(nil, error_msg)
		return
	end

	-- Get provider handler
	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		local error_msg = "Failed to load provider: " .. model_config.provider
		log.error(error_msg)
		callback(nil, error_msg)
		return
	end

	-- Count tokens using the appropriate provider
	log.info("Counting tokens for model: " .. model_name .. " (provider: " .. model_config.provider .. ")")

	provider.count_tokens_async(content, model_config.encoding, function(token_count, error)
		if error then
			log.error("Token counting failed: " .. error)
			callback(nil, error)
		else
			local result = {
				token_count = token_count,
				model_name = model_name,
				model_config = model_config,
				buffer_id = buffer_id,
			}
			log.info("Token count successful: " .. token_count .. " tokens")
			callback(result, nil)
		end
	end)
end

return M
