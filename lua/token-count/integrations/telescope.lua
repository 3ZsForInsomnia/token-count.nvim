local M = {}

function M.is_available()
	local ok = pcall(require, "telescope")
	if ok then
		-- Auto-load the token_count telescope extension
		pcall(function()
			require("telescope").load_extension("token_count")
		end)
	end
	return ok
end

function M.show_model_picker(callback)
	if not M.is_available() then
		-- Fallback to vim.ui.select
		require("token-count.utils.ui").show_model_selection(callback)
		return
	end

	-- Use the telescope extension
	local telescope = require("telescope")
	local extension = telescope.extensions.token_count

	if extension and extension.models then
		extension.models(callback)
	else
		-- Fallback if extension failed to load
		require("token-count.utils.ui").show_model_selection(callback)
	end
end

return M
