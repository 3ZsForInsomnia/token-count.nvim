local M = {}

 --- Parse formatted token count back to approximate number
 --- @param formatted_count string Formatted count like "1.2k", "500", "LARGE"
 --- @return number|nil Approximate token count
 function M._parse_formatted_count(formatted_count)
 	if not formatted_count or formatted_count == "" then
 		return nil
 	end
 	
 	-- Handle special cases
 	if formatted_count == "LARGE" then
 		return 999999
 	end
 	if formatted_count:match("~$") then
 		-- Remove tilde and parse the number part
 		formatted_count = formatted_count:gsub("~$", "")
 	end
 	
 	-- Handle "k" suffix (e.g., "1.2k" -> 1200)
 	local k_match = formatted_count:match("^([%d%.]+)k$")
 	if k_match then
 		return math.floor(tonumber(k_match) * 1000)
 	end
 	
 	-- Handle "M" suffix (e.g., "1.5M" -> 1500000)
 	local m_match = formatted_count:match("^([%d%.]+)M$")
 	if m_match then
 		return math.floor(tonumber(m_match) * 1000000)
 	end
 	
 	-- Handle plain numbers
 	local number = tonumber(formatted_count)
 	if number then
 		return number
 	end
 	
 	return nil
 end
 
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

	-- Use cached values for fast summary
	local buffer_results = {}
	local total_tokens = 0
	local cached_files = 0
	
	for _, buffer_id in ipairs(valid_buffers) do
		local buffer_name = vim.api.nvim_buf_get_name(buffer_id)
		local token_count = 0
		
		if buffer_name and buffer_name ~= "" then
			-- Try to get cached token count
			local cached_count = cache_manager.get_file_token_count(buffer_name)
			if cached_count and cached_count ~= cache_manager.get_config().placeholder_text then
				-- Parse the formatted count back to number (e.g., "1.2k" -> 1200)
				token_count = M._parse_formatted_count(cached_count) or 0
				cached_files = cached_files + 1
			end
		end
		
		table.insert(buffer_results, {
			buffer_id = buffer_id,
			token_count = token_count,
		})
		
		total_tokens = total_tokens + token_count
	end
	
	-- Show immediate results using cached values
	handle_all_buffers_completion(total_tokens, buffer_results, model_config)
	
	require("token-count.log").info(
		string.format(
			"All buffers summary from cache: %d tokens (%d/%d files cached)",
			total_tokens,
			cached_files,
			#valid_buffers
		)
	)
end

return M