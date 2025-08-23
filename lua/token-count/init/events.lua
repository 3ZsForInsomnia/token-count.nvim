--- Auto commands and event handlers
local M = {}

--- Setup autocommands for the plugin
function M.setup_autocommands()
	-- Register health check
	vim.health = vim.health or {}
	vim.health["token-count"] = require("token-count.health").check

	-- Setup autocommands
	local augroup = vim.api.nvim_create_augroup("TokenCount", { clear = true })

	-- Update token count cache on buffer save
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		callback = function(args)
			-- Only process valid buffer types
			local buffer = require("token-count.buffer")
			local buffer_id, valid = buffer.get_current_buffer_if_valid()

			if valid and buffer_id == args.buf then
				-- Update cache asynchronously (don't block save)
				buffer.count_current_buffer_async(function(result, error)
					if result then
						require("token-count.log").info(
							string.format(
								"Buffer saved - Token count: %d (Model: %s)",
								result.token_count,
								result.model_config.name
							)
						)
					end
					-- Silently ignore errors to avoid disrupting save workflow
				end)
			end
		end,
		desc = "Update token count cache after buffer save",
	})
end

return M