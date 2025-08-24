-- Telescope extension for token-count.nvim
-- Provides enhanced model selection with preview and fuzzy search

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	return
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

-- Extension setup
local function setup(opts)
	opts = opts or {}

	-- No specific setup needed for now
	-- Future: could add custom keybindings, themes, etc.
end

local function model_picker(callback)
	-- Default callback if none provided (for direct telescope usage)
	callback = callback
		or function(technical_name, model_config)
			if technical_name and model_config then
				-- Update the plugin configuration
				local config = require("token-count.config").get()
				config.model = technical_name

				vim.notify(string.format("Model changed to: %s", model_config.name), vim.log.levels.INFO)
			end
		end

	local models = require("token-count.models.utils")
	local formatting = require("token-count.utils.formatting")
	local config = require("token-count.config").get()
	local current_model = config.model
	local searchable_models = models.get_searchable_models()

	-- Prepare entries for telescope
	local entries = {}
	for _, model_entry in ipairs(searchable_models) do
		local context_window_formatted = formatting.format_number_with_commas(model_entry.context_window)
		local max_output_formatted = formatting.format_number_with_commas(model_entry.max_output_tokens)

		-- Check if this is the current model
		local is_current = model_entry.technical_name == current_model
		local current_indicator = is_current and "● " or "  "

		-- Create display text
		local display = string.format(
			"%s%s │ %s │ In: %s │ Out: %s",
			current_indicator,
			model_entry.nice_name,
			model_entry.provider,
			context_window_formatted,
			max_output_formatted
		)

		-- Create searchable ordinal (all three names for fuzzy finding)
		local ordinal = string.format(
			"%s %s %s",
			model_entry.nice_name,
			model_entry.technical_name,
			model_entry.tokencost_name or ""
		)

		table.insert(entries, {
			display = display,
			ordinal = ordinal,
			value = model_entry,
			is_current = is_current,
		})
	end

	-- Sort entries to put current model first, then by nice name
	table.sort(entries, function(a, b)
		if a.is_current and not b.is_current then
			return true
		elseif not a.is_current and b.is_current then
			return false
		else
			return a.value.nice_name < b.value.nice_name
		end
	end)
	pickers
		.new({}, {
			prompt_title = "Select Model (● = current)",
			finder = finders.new_table({
				results = entries,
				entry_maker = function(entry)
					return {
						value = entry.value,
						display = entry.display,
						ordinal = entry.ordinal,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				title = "Model Details",
				define_preview = function(self, entry, status)
					local model = entry.value
					local lines = {
						"Model: " .. model.nice_name,
						"Technical Name: " .. model.technical_name,
						"Provider: " .. model.provider,
						"",
						"Token Limits:",
						"  Input (Context): "
							.. formatting.format_number_with_commas(model.context_window)
							.. " tokens",
						"  Output (Max): "
							.. formatting.format_number_with_commas(model.max_output_tokens)
							.. " tokens",
						"",
						"Tokencost Name: " .. (model.tokencost_name or "N/A"),
						"",
						"Configuration:",
						"  Encoding: " .. model.config.encoding,
					}

					-- Add accuracy information based on provider
					if model.provider == "tiktoken" then
						table.insert(lines, "")
						table.insert(lines, "Accuracy: Exact counts using tiktoken (local-only)")
					elseif model.provider == "deepseek" then
						table.insert(lines, "")
						table.insert(lines, "Accuracy: Exact counts using official DeepSeek tokenizer")
					elseif model.provider == "tokencost" then
						table.insert(lines, "")
						table.insert(lines, "Accuracy: Estimates via tokencost library")
						if model.technical_name:match("^claude") then
							table.insert(lines, "  • Enable official Anthropic API for exact counts")
						elseif model.technical_name:match("^gemini") then
							table.insert(lines, "  • Enable official Gemini API for exact counts")
						end
					end

					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						local model = selection.value
						callback(model.technical_name, model.config)
					else
						callback(nil, nil)
					end
				end)
				return true
			end,
		})
		:find()
end

-- Register the extension
return telescope.register_extension({
	setup = setup,
	exports = {
		models = model_picker,
		token_count_models = model_picker, -- Alternative name
	},
})
