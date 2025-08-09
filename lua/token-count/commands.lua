local M = {}

--- Count tokens in current buffer
function M.count_current_buffer()
	local ui = require("token-count.utils.ui")
	local formatting = require("token-count.utils.formatting")
	local buffer = require("token-count.buffer")

	buffer.count_current_buffer_async(function(result, error)
		if error then
			vim.notify("Token counting failed: " .. error, vim.log.levels.ERROR)
		else
			ui.notify_token_count_result(result)

			-- Also log detailed JSON
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

			-- Update config
			local current_config = config.get()
			current_config.model = selected_model

			-- Format context window with commas for readability
			local context_window_formatted = formatting.format_number_with_commas(model_config.context_window)
			
			-- Build a nicely formatted message
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
			
			-- Display the formatted message
			ui.display_lines(lines)
			
			-- Also send a simple notification
			local simple_message = string.format(
				"Model changed to %s (%s tokens)",
				model_config.name,
				context_window_formatted
			)
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

	-- Build message
	local message = formatting.format_all_buffers_summary(
		total_tokens,
		model_config.context_window,
		model_config.name,
		progress_bar
	)
	formatting.add_buffer_breakdown(message, buffer_results)
	formatting.add_threshold_warning(message, percentage, config.context_warning_threshold)

	-- Display results
	ui.display_lines(message)

	-- Log summary
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

--- Count tokens in all valid buffers
function M.count_all_buffers()
	local buffer_ops = require("token-count.utils.buffer_ops")
	local config = require("token-count.config").get()
	local models = require("token-count.models.utils")

	-- Get valid buffers
	local valid_buffers = buffer_ops.get_valid_buffers()

	if #valid_buffers == 0 then
		vim.notify("No valid buffers found for token counting", vim.log.levels.WARN)
		return
	end

	-- Get model configuration
	local model_config = models.get_model(config.model)
	if not model_config then
		vim.notify("Invalid model configuration: " .. config.model, vim.log.levels.ERROR)
		return
	end

	-- Count tokens for all buffers
	buffer_ops.count_multiple_buffers_async(valid_buffers, model_config, function(total_tokens, buffer_results, error)
		if error then
			vim.notify("Token counting failed: " .. error, vim.log.levels.ERROR)
		else
			handle_all_buffers_completion(total_tokens, buffer_results, model_config)
		end
	end)
end

return M
