--- Buffer content operations
local M = {}

--- Get the contents of a buffer by ID
--- @param buffer_id number Buffer ID
--- @return string content The full buffer content as a string
function M.get_buffer_contents(buffer_id)
	local lines = vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false)
	return table.concat(lines, "\n")
end

--- Get current active buffer and check if it's valid for token counting
--- @return number|nil buffer_id The buffer ID if valid, nil if invalid
--- @return boolean valid Whether the buffer is valid for token counting
function M.get_current_buffer_if_valid()
	local validation = require("token-count.buffer.validation")
	local buffer_id = vim.api.nvim_get_current_buf()

	-- Use the safer validation function
	local valid = validation.is_buffer_valid_for_counting(buffer_id)

	if valid then
		return buffer_id, true
	else
		return nil, false
	end
end

return M