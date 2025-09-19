--- Multiple buffer operations
local M = {}

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
	local cache_manager = require("token-count.cache")

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
		-- Schedule to avoid fast event context restrictions
		vim.schedule(function()
			if error then
				vim.notify("Token counting failed: " .. error, vim.log.levels.ERROR)
			else
				handle_all_buffers_completion(total_tokens, buffer_results, model_config)
				
				-- Update cache for all processed buffers
				local updated_files = 0
				
				for _, result in ipairs(buffer_results) do
					local buffer_name = vim.api.nvim_buf_get_name(result.buffer_id)
					if buffer_name and buffer_name ~= "" then
						cache_manager.update_cache_with_count(buffer_name, result.token_count, false) -- Don't notify for each file
						updated_files = updated_files + 1
					end
				end
				
				if updated_files > 0 then
					require("token-count.log").info("Updated cache for " .. updated_files .. " buffers")
					-- Send a single notification for all updates
					vim.cmd("redraw") -- Refresh UI components like neo-tree
				end
			end
		end)
	end)
end

return M