--- Standardized error handling and graceful degradation
local M = {}

M.ErrorTypes = {
	VENV_NOT_READY = "VENV_NOT_READY",
	PYTHON_NOT_FOUND = "PYTHON_NOT_FOUND",
	INVALID_MODEL = "INVALID_MODEL",
	PROVIDER_UNAVAILABLE = "PROVIDER_UNAVAILABLE",
	FILE_TOO_LARGE = "FILE_TOO_LARGE",
	BUFFER_INVALID = "BUFFER_INVALID",
	DEPENDENCY_MISSING = "DEPENDENCY_MISSING",
	API_KEY_MISSING = "API_KEY_MISSING",
	NETWORK_ERROR = "NETWORK_ERROR",
}

--- Create structured error with recovery suggestions
--- @param error_type string Error type from ErrorTypes
--- @param message string Human readable message
--- @param context table? Additional context
--- @return table error Structured error object
function M.create_error(error_type, message, context)
	return {
		type = error_type,
		message = message,
		context = context or {},
		timestamp = os.time(),
		recoverable = M._is_recoverable(error_type),
		recovery_suggestion = M._get_recovery_suggestion(error_type),
	}
end

--- Check if error type is recoverable
--- @param error_type string Error type
--- @return boolean recoverable Whether this error can be automatically recovered from
function M._is_recoverable(error_type)
	local recoverable_types = {
		[M.ErrorTypes.VENV_NOT_READY] = true,
		[M.ErrorTypes.PROVIDER_UNAVAILABLE] = true,
		[M.ErrorTypes.DEPENDENCY_MISSING] = true,
		[M.ErrorTypes.FILE_TOO_LARGE] = true, -- Can provide estimate
	}
	return recoverable_types[error_type] or false
end

--- Get recovery suggestion for error type
--- @param error_type string Error type
--- @return string suggestion Human readable recovery suggestion
function M._get_recovery_suggestion(error_type)
	local suggestions = {
		[M.ErrorTypes.VENV_NOT_READY] = "Virtual environment will be set up automatically. Please wait...",
		[M.ErrorTypes.PYTHON_NOT_FOUND] = "Please install Python 3.7+ and ensure it's in your PATH",
		[M.ErrorTypes.INVALID_MODEL] = "Run :TokenCountModel to select a valid model",
		[M.ErrorTypes.PROVIDER_UNAVAILABLE] = "Falling back to estimation mode",
		[M.ErrorTypes.FILE_TOO_LARGE] = "Using character-based estimation for large files",
		[M.ErrorTypes.BUFFER_INVALID] = "This buffer type is not supported for token counting",
		[M.ErrorTypes.DEPENDENCY_MISSING] = "Dependencies will be installed automatically",
		[M.ErrorTypes.API_KEY_MISSING] = "Set the appropriate API key environment variable for exact counts",
		[M.ErrorTypes.NETWORK_ERROR] = "Check your internet connection for API-based counting",
	}
	return suggestions[error_type] or "Please check the logs for more information"
end

--- Provide fallback token estimation when providers fail
--- @param text string Text content to estimate
--- @return number estimated_tokens Rough token estimate
--- @return string method Description of estimation method
function M.get_fallback_estimate(text)
	if not text or text == "" then
		return 0, "empty"
	end

	-- Simple character-based estimation (roughly 4 chars per token for most text)
	local char_estimate = math.floor(#text / 4)

	-- Slightly more sophisticated: count words and adjust
	local word_count = 0
	for _ in text:gmatch("%S+") do
		word_count = word_count + 1
	end

	-- Average of ~1.3 tokens per word for natural text
	local word_estimate = math.floor(word_count * 1.3)

	-- Use the higher of the two estimates as a conservative approach
	local estimate = math.max(char_estimate, word_estimate)

	return estimate, "estimated"
end

--- Handle error with automatic recovery attempt
--- @param error_obj table Structured error object
--- @param callback function Callback to retry with
--- @param retry_fn function? Optional function to call for retry
function M.handle_with_recovery(error_obj, callback, retry_fn)
	local log = require("token-count.log")

	if error_obj.recoverable then
		log.info("Attempting automatic recovery: " .. error_obj.recovery_suggestion)

		if error_obj.type == M.ErrorTypes.VENV_NOT_READY and retry_fn then
			-- Attempt venv setup and retry
			local venv = require("token-count.venv")
			venv.setup_venv(function(success, setup_error)
				if success then
					log.info("Virtual environment setup successful, retrying...")
					retry_fn()
				else
					-- Fall back to estimation
					log.warn("Setup failed, using estimation: " .. (setup_error or "unknown error"))
					callback(nil, M.create_error(M.ErrorTypes.PROVIDER_UNAVAILABLE, "Setup failed, using estimation"))
				end
			end)
			return
		end

		if error_obj.type == M.ErrorTypes.PROVIDER_UNAVAILABLE or error_obj.type == M.ErrorTypes.FILE_TOO_LARGE then
			-- Provide fallback estimate
			local context = error_obj.context
			if context and context.text then
				local estimate, method = M.get_fallback_estimate(context.text)
				log.info(string.format("Using fallback estimation: %d tokens (%s)", estimate, method))

				-- Create result that indicates estimation
				-- For provider compatibility, just return the number with a note
				callback(estimate, nil)
				return
			end
		end
	end

	-- If no recovery possible, pass error through
	log.error("Unrecoverable error: " .. error_obj.message)
	callback(nil, error_obj.message)
end

--- Wrap provider calls with error handling and fallback
--- @param provider_fn function Function to call provider
--- @param text string Text content for fallback
--- @param callback function Result callback
function M.with_fallback(provider_fn, text, callback)
	provider_fn(function(result, error)
		if result then
			callback(result, nil)
		else
			-- Create error object and attempt recovery
			local error_obj =
				M.create_error(M.ErrorTypes.PROVIDER_UNAVAILABLE, error or "Provider failed", { text = text })
			M.handle_with_recovery(error_obj, callback)
		end
	end)
end

return M
