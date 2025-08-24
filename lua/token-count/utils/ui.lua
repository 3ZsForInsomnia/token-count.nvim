local M = {}

function M.show_model_selection(callback)
	-- Try to use Telescope if available for better experience
	local telescope_ok, telescope_picker = pcall(require, "token-count.integrations.telescope")
	if telescope_ok and telescope_picker.is_available() then
		telescope_picker.show_model_picker(callback)
		return
	end

	-- Fallback to vim.ui.select
	local models = require("token-count.models.utils")
	local formatting = require("token-count.utils.formatting")
	local config = require("token-count.config").get()
	local current_model = config.model

	local searchable_models = models.get_searchable_models()
	local technical_names = {}
	local model_display = {}

	for _, model_entry in ipairs(searchable_models) do
		local context_window_formatted = formatting.format_number_with_commas(model_entry.context_window)
		local max_output_formatted = formatting.format_number_with_commas(model_entry.max_output_tokens)

		table.insert(technical_names, model_entry.technical_name)

		-- Check if this is the current model and add indicator
		local is_current = model_entry.technical_name == current_model
		local current_indicator = is_current and "● " or "  "

		-- Create rich display format: "Model Name │ Provider │ Input: 128,000 │ Output: 16,384 │ technical-name"
		local display_line = string.format(
			"%s%s │ %s │ In: %s │ Out: %s │ %s",
			current_indicator,
			model_entry.nice_name,
			model_entry.provider,
			context_window_formatted,
			max_output_formatted,
			model_entry.technical_name
		)
		table.insert(model_display, display_line)
	end

	vim.ui.select(model_display, {
		prompt = "Select model (● = current, Name │ Provider │ Input │ Output │ ID):",
		format_item = function(item)
			return item
		end,
	}, function(choice, idx)
		if choice and idx then
			local selected_model = technical_names[idx]
			local model_config = models.get_model(selected_model)
			callback(selected_model, model_config)
		else
			callback(nil, nil)
		end
	end)
end

--- Display lines to user via print
--- @param lines string[] Array of lines to display
function M.display_lines(lines)
	for _, line in ipairs(lines) do
		print(line)
	end
end

--- Notify user with token count result
--- @param result table Token count result
function M.notify_token_count_result(result)
	local formatting = require("token-count.utils.formatting")
	local percentage = result.token_count / result.model_config.context_window
	local percentage_str = formatting.format_percentage(percentage)

	local message = string.format(
		"Token Count: %d / %d (%s) - Model: %s",
		result.token_count,
		result.model_config.context_window,
		percentage_str,
		result.model_config.name
	)

	vim.notify(message, vim.log.levels.INFO)
end

--- Notify user with model change result
--- @param previous_model string|nil Previous model name
--- @param new_model string New model name
--- @param model_config table New model configuration
function M.notify_model_change(previous_model, new_model, model_config)
	local result = {
		previous_model = previous_model,
		new_model = new_model,
		model_name = model_config.name,
		provider = model_config.provider,
		context_window = model_config.context_window,
	}

	vim.notify("Model changed: " .. vim.fn.json_encode(result), vim.log.levels.INFO)
end

return M
