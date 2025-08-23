--- Single buffer operations
local M = {}

function M.count_current_buffer()
	local ui = require("token-count.utils.ui")
	local formatting = require("token-count.utils.formatting")
	local buffer = require("token-count.buffer")

	buffer.count_current_buffer_async(function(result, error)
		if error then
			vim.notify("Token counting failed: " .. error, vim.log.levels.ERROR)
		else
			ui.notify_token_count_result(result)

			require("token-count.log").info("Token count result: " .. formatting.format_result_json(result))
		end
	end)
end

function M.change_model()
	local ui = require("token-count.utils.ui")
	local config = require("token-count.config")
	local formatting = require("token-count.utils.formatting")

	ui.show_model_selection(function(selected_model, model_config)
		if selected_model and model_config then
			local previous_model = config.get().model

			local current_config = config.get()
			current_config.model = selected_model

			local context_window_formatted = formatting.format_number_with_commas(model_config.context_window)

			local lines = {}

			if previous_model and previous_model ~= selected_model then
				table.insert(lines, "═══ Model Changed ═══")
				table.insert(lines, "From: " .. previous_model)
				table.insert(lines, "To:   " .. selected_model)
				table.insert(lines, "")
			else
				table.insert(lines, "═══ Model Selected ═══")
			end

			table.insert(lines, "Name:           " .. model_config.name)
			table.insert(lines, "Provider:       " .. model_config.provider)
			table.insert(lines, "Context Window: " .. context_window_formatted .. " tokens")
			table.insert(lines, "Model ID:       " .. selected_model)

			ui.display_lines(lines)

			local simple_message =
				string.format("Model changed to %s (%s tokens)", model_config.name, context_window_formatted)
			vim.notify(simple_message, vim.log.levels.INFO)

			require("token-count.log").info("Model changed to: " .. selected_model)
		end
	end)
end

return M