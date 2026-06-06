-- CodeCompanion integration for token-count.nvim
-- Usage in your codecompanion config:
--
--   local cc_integration = require("token-count.integrations.codecompanion")
--   cc_integration.setup()
--
--   -- Then in your codecompanion opts:
--   interactions = {
--     chat = {
--       roles = {
--         llm = function(adapter)
--           local token_str = cc_integration.get_display(vim.api.nvim_get_current_buf())
--           -- build and return your header string using token_str
--         end,
--       },
--     },
--   },

local M = {}

local estimated_tokens_by_bufnr = {}
local setup_complete = false

function M.clear(bufnr)
	if not bufnr then
		return
	end

	estimated_tokens_by_bufnr[bufnr] = nil
end

function M.get_estimated_tokens(bufnr)
	if not bufnr then
		return nil
	end

	return estimated_tokens_by_bufnr[bufnr]
end

function M.get_display(bufnr)
	local tokens = M.get_estimated_tokens(bufnr)
	if not tokens then
		return ""
	end

	return string.format("~%st", tokens)
end

function M.setup()
	if setup_complete then
		return
	end

	setup_complete = true

	vim.api.nvim_create_autocmd("User", {
		pattern = "CodeCompanionChatCreated",
		callback = function(args)
			local ok, codecompanion = pcall(require, "codecompanion")
			if not ok or type(codecompanion.buf_get_chat) ~= "function" then
				return
			end

			local bufnr = args and args.data and args.data.bufnr
			if not bufnr then
				return
			end

			local chat = codecompanion.buf_get_chat(bufnr)
			if not chat or type(chat.add_callback) ~= "function" then
				return
			end

			chat:add_callback("on_checkpoint", function(c, data)
				if not c or not c.bufnr or not c.adapter or c.adapter.type ~= "acp" then
					return
				end

				if data and data.estimated_tokens ~= nil then
					estimated_tokens_by_bufnr[c.bufnr] = data.estimated_tokens
				end
			end)
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "CodeCompanionChatClosed",
		callback = function(args)
			local bufnr = args and args.data and args.data.bufnr
			if not bufnr then
				bufnr = args and args.buf
			end

			M.clear(bufnr)
		end,
	})
end

return M
