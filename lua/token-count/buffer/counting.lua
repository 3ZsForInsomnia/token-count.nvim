--- Token counting operations for buffers
local M = {}

--- Count tokens for the current buffer
--- @param callback function Callback function that receives (result, error)
---   result = {token_count: number, model_name: string, model_config: table, buffer_id: number}
---   error = string error message
function M.count_current_buffer_async(callback)
	local log = require("token-count.log")
	local content = require("token-count.buffer.content")

	local buffer_id, valid = content.get_current_buffer_if_valid()
	if not valid then
		local error_msg = "Current buffer has invalid filetype for token counting"
		log.warn(error_msg)
		callback(nil, error_msg)
		return
	end

	local buffer_content = content.get_buffer_contents(buffer_id)
	if not buffer_content or buffer_content == "" then
		local error_msg = "Buffer is empty"
		log.info(error_msg)
		callback(nil, error_msg)
		return
	end

	local config = require("token-count.config").get()
	local model_name = config.model

	local models = require("token-count.models.utils")
	local model_config = models.get_model(model_name)
	if not model_config then
		local error_msg = "Unknown model: " .. model_name
		log.error(error_msg)
		callback(nil, error_msg)
		return
	end

	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		local error_msg = "Failed to load provider: " .. model_config.provider
		log.error(error_msg)
		callback(nil, error_msg)
		return
	end

	log.info("Counting tokens for model: " .. model_name .. " (provider: " .. model_config.provider .. ")")

	provider.count_tokens_async(buffer_content, model_config.encoding, function(token_count, error)
		if error then
			log.error("Token counting failed: " .. error)
			callback(nil, error)
		else
			local result = {
				token_count = token_count,
				model_name = model_name,
				model_config = model_config,
				buffer_id = buffer_id,
			}
			log.info("Token count successful: " .. token_count .. " tokens")
			callback(result, nil)
		end
	end)
end

return M