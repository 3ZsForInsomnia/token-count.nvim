local M = {}

--- Generate ASCII progress bar
--- @param percentage number Percentage (0-1)
--- @param width number Width of the bar (default 20)
--- @return string progress_bar ASCII progress bar
function M.generate_progress_bar(percentage, width)
    width = width or 20
    local filled = math.floor(percentage * width)
    local empty = width - filled
    
    local bar = "["
    for i = 1, filled do
        bar = bar .. "█"
    end
    for i = 1, empty do
        bar = bar .. "░"
    end
    bar = bar .. "]"
    
    return bar
end

--- Format token count result as JSON
--- @param result table Token count result
--- @return string json_string Formatted JSON string
function M.format_result_json(result)
    local json = {
        token_count = result.token_count,
        model_name = result.model_name,
        model_display_name = result.model_config.name,
        context_window = result.model_config.context_window,
        percentage = result.token_count / result.model_config.context_window,
        buffer_id = result.buffer_id
    }
    
    return vim.fn.json_encode(json)
end

function M.format_percentage(percentage, decimals)
    decimals = decimals or 1
    local format_str = "%." .. decimals .. "f%%"
    return string.format(format_str, percentage * 100)
end

 --- Format number with comma separators
 --- @param number number The number to format
 --- @return string formatted_number Number with comma separators
 function M.format_number_with_commas(number)
     local formatted = tostring(number)
     local k
     while true do
         formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
         if k == 0 then
             break
         end
     end
     return formatted
 end
 
function M.format_all_buffers_summary(total_tokens, context_window, model_name, progress_bar)
    local percentage = total_tokens / context_window
    local percentage_str = M.format_percentage(percentage)
    
    return {
        "=== All Buffers Token Count ===",
        string.format("Total Tokens: %d / %d (%s)", total_tokens, context_window, percentage_str),
        string.format("Model: %s", model_name),
        string.format("Progress: %s %s", progress_bar, percentage_str),
        ""
    }
end

--- Add buffer breakdown to message
--- @param message string[] Existing message lines
--- @param buffer_results table[] Array of buffer results
function M.add_buffer_breakdown(message, buffer_results)
    table.insert(message, "Buffer Breakdown:")
    for _, buf_result in ipairs(buffer_results) do
        table.insert(message, string.format("  %s: %d tokens", buf_result.name, buf_result.tokens))
    end
end

--- Add warning message if over threshold
--- @param message string[] Existing message lines
--- @param percentage number Current percentage (0-1)
--- @param threshold number Warning threshold (0-1)
function M.add_threshold_warning(message, percentage, threshold)
    if percentage > threshold then
        table.insert(message, "")
        table.insert(message, string.format("⚠️  WARNING: Using %s of context window (threshold: %s)", 
            M.format_percentage(percentage), M.format_percentage(threshold)))
    end
end

return M