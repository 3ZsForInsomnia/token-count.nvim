local M = {}

--- Get visual selection text
--- @return string|nil selection_text The selected text, or nil if no selection
function M.get_visual_selection_text()
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

return M