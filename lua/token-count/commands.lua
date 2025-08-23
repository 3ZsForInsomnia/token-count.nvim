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

--- Handle completion of all buffer token counting
--- @param total_tokens number Total tokens across all buffers
--- @param buffer_results table[] Results for each buffer
--- @param model_config table Model configuration
local function handle_all_buffers_completion(total_tokens, buffer_results, model_config)
	local formatting = require("token-count.utils.formatting")
	local ui = require("token-count.utils.ui")
	local config = require("token-count.config").get()

	local percentage = total_tokens / model_config.context_window
	local progress_bar = formatting.generate_progress_bar(percentage, 30)

	local message = formatting.format_all_buffers_summary(
		total_tokens,
		model_config.context_window,
		model_config.name,
		progress_bar
	)
	formatting.add_buffer_breakdown(message, buffer_results)
	formatting.add_threshold_warning(message, percentage, config.context_warning_threshold)

	ui.display_lines(message)

	require("token-count.log").info(
		string.format(
			"All buffers token count: %d/%d (%.1f%%) across %d buffers",
			total_tokens,
			model_config.context_window,
			percentage * 100,
			#buffer_results
		)
	)
end

function M.count_all_buffers()
	local buffer_ops = require("token-count.utils.buffer_ops")
	local config = require("token-count.config").get()
	local models = require("token-count.models.utils")

	local valid_buffers = buffer_ops.get_valid_buffers()

	if #valid_buffers == 0 then
		vim.notify("No valid buffers found for token counting", vim.log.levels.WARN)
		return
	end

	local model_config = models.get_model(config.model)
	if not model_config then
		vim.notify("Invalid model configuration: " .. config.model, vim.log.levels.ERROR)
		return
	end

	buffer_ops.count_multiple_buffers_async(valid_buffers, model_config, function(total_tokens, buffer_results, error)
		if error then
			vim.notify("Token counting failed: " .. error, vim.log.levels.ERROR)
		else
			handle_all_buffers_completion(total_tokens, buffer_results, model_config)
		end
	end)
end

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
