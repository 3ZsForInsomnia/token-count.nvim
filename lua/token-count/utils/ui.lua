local M = {}

function M.show_model_selection(callback)
    local models = require('token-count.models.utils')
    local formatting = require('token-count.utils.formatting')
    
    local available_models = models.get_available_models()
    local model_names = {}
    local model_display = {}
    
    -- Create display names for selection
    for _, model_name in ipairs(available_models) do
        local model_config = models.get_model(model_name)
        local context_window_formatted = formatting.format_number_with_commas(model_config.context_window)
        
        table.insert(model_names, model_name)
        
        -- Create rich display format: "Model Name | Provider | 128,000 tokens | model/id"
        local display_line = string.format(
            "%s │ %s │ %s tokens │ %s",
            model_config.name,
            model_config.provider,
            context_window_formatted,
            model_name
        )
        table.insert(model_display, display_line)
    end
    
    vim.ui.select(model_display, {
        prompt = "Select model (Name │ Provider │ Context Window │ ID):",
        format_item = function(item)
            return item
        end
    }, function(choice, idx)
        if choice and idx then
            local selected_model = model_names[idx]
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
    local formatting = require('token-count.utils.formatting')
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
        context_window = model_config.context_window
    }
    
    vim.notify("Model changed: " .. vim.fn.json_encode(result), vim.log.levels.INFO)
end

return M