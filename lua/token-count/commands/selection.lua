--- Visual selection operations
local M = {}

function M.count_visual_selection()
	local visual_selection = require("token-count.utils.visual_selection")
	local selection_text = visual_selection.get_visual_selection_text()

	if not selection_text or selection_text == "" then
		vim.notify("No visual selection found", vim.log.levels.WARN)
		return
	end

	local models_ok, models = pcall(require, "token-count.models.utils")
	local config_ok, config = pcall(require, "token-count.config")

	if not (models_ok and config_ok) then
		vim.notify("Token counting modules not available", vim.log.levels.ERROR)
		return
	end

	local current_config = config.get()
	local model_config = models.get_model(current_config.model)
	if not model_config then
		vim.notify("Invalid model configuration: " .. current_config.model, vim.log.levels.ERROR)
		return
	end

	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		vim.notify("Failed to load provider: " .. model_config.provider, vim.log.levels.ERROR)
		return
	end

	vim.notify("Counting tokens for visual selection...", vim.log.levels.INFO)

	provider.count_tokens_async(selection_text, model_config.encoding, function(count, error)
		if error then
			vim.notify("Token counting failed: " .. error, vim.log.levels.ERROR)
			return
		end

		if count then
			local percentage = (count / model_config.context_window) * 100
			local formatting = require("token-count.utils.formatting")
			local percentage_str = formatting.format_percentage(percentage / 100)

			local message = string.format(
				"Visual Selection: %d tokens (%s of context window) - Model: %s",
				count,
				percentage_str,
				model_config.name
			)

			vim.notify(message, vim.log.levels.INFO)

			require("token-count.log").info(
				string.format(
					"Visual selection token count: %d tokens (%.1f%%) with model %s",
					count,
					percentage,
					current_config.model
				)
			)
		else
			vim.notify("Unable to count tokens for selection", vim.log.levels.ERROR)
		end
	end)
end

return M