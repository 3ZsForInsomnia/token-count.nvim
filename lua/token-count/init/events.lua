local M = {}
local _autocommands_setup = false

local function get_cleanup()
	local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
	return cleanup_ok and cleanup or nil
end

function M.setup_autocommands()
	-- Prevent double setup
	if _autocommands_setup then
		return
	end
	_autocommands_setup = true

	-- Register health check
	vim.health = vim.health or {}
	vim.health["token-count"] = require("token-count.health").check
	
	-- Setup autocommands
	local augroup = vim.api.nvim_create_augroup("TokenCount", { clear = true })
	
	-- Register autocommand group for cleanup tracking
	local cleanup = get_cleanup()
	if cleanup then
		cleanup.register_autocommand_group(augroup, "token_count_main")
	end

	-- Process files immediately on save for instant lualine updates
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		callback = function(args)
			-- Only process valid buffer types
			local buffer_validation = require("token-count.buffer.validation")
			if buffer_validation.is_buffer_valid_for_counting(args.buf) then
				-- Force immediate processing for file save events
				local current_file = vim.api.nvim_buf_get_name(args.buf)
				if current_file and current_file ~= "" then
					local cache_manager = require("token-count.cache")
					cache_manager.count_file_immediate(current_file, function(result, error)
						-- Cache notification sent automatically on completion
					end)
				end
			end
		end,
		desc = "Invalidate token count cache after buffer save",
	})
end

return M
