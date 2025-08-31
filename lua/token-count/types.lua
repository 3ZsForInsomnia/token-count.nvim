--- Type definitions for token-count.nvim
--- This file provides comprehensive type documentation for better development experience

--- @class TokenCountResult
--- @field token_count number The calculated token count
--- @field model_name string The model identifier that was used
--- @field model_config ModelConfig The model configuration object
--- @field buffer_id number? The buffer ID if counting was done on a buffer
--- @field estimated boolean? Whether this count is estimated (true) or exact (false/nil)
--- @field method string? The counting method used ("tiktoken", "deepseek", "tokencost", "estimated")
--- @field original_error string? Original error message if this is a fallback result

--- @class ModelConfig
--- @field name string Human-readable model name
--- @field provider string Provider name ("tiktoken", "deepseek", "tokencost", etc.)
--- @field encoding string Encoding identifier for the tokenizer
--- @field context_window number Maximum input tokens for the model
--- @field max_output_tokens number Maximum output tokens for the model
--- @field tokencost_name string? Name used by tokencost library
--- @field technical_name string Technical identifier for the model

--- @class CacheConfig
--- @field enabled boolean Whether background caching is enabled
--- @field interval number Background processing interval in milliseconds
--- @field max_files_per_batch number Maximum files to process per batch
--- @field cache_ttl number File cache time-to-live in milliseconds
--- @field directory_cache_ttl number Directory cache time-to-live in milliseconds
--- @field placeholder_text string Text to show while processing
--- @field enable_directory_caching boolean Whether to cache directory token counts
--- @field enable_file_caching boolean Whether to cache file token counts
--- @field request_debounce number Debounce time for immediate requests in milliseconds
--- @field lazy_start boolean Whether to start cache timer only on first request

--- @class PluginConfig
--- @field model string Default model identifier
--- @field log_level "info"|"warn"|"error" Logging verbosity level
--- @field context_warning_threshold number Threshold for context usage warnings (0-1)
--- @field enable_official_anthropic_counter boolean Use Anthropic API for exact counts
--- @field enable_official_gemini_counter boolean Use Gemini API for exact counts
--- @field cache CacheConfig Cache system configuration
--- @field lazy_loading table? Lazy loading options (internal)

--- @class BufferResult
--- @field buffer_id number Buffer identifier
--- @field name string Display name for the buffer
--- @field tokens number Token count for this buffer

--- @class VenvStatus
--- @field python_available boolean Whether Python 3 is available
--- @field python_info string? Python version information
--- @field venv_exists boolean Whether virtual environment exists
--- @field venv_path string Path to virtual environment
--- @field python_path string Path to Python executable in venv
--- @field tiktoken_installed boolean Whether tiktoken is installed
--- @field tokencost_installed boolean Whether tokencost is installed
--- @field deepseek_installed boolean Whether deepseek_tokenizer is installed
--- @field anthropic_installed boolean Whether anthropic is installed
--- @field gemini_installed boolean Whether google-genai is installed
--- @field anthropic_api_key boolean Whether ANTHROPIC_API_KEY is set
--- @field gemini_api_key boolean Whether GOOGLE_API_KEY is set
--- @field ready boolean Whether the environment is ready for token counting

--- @class CacheStats
--- @field cached_files number Number of files in cache
--- @field cached_directories number Number of directories in cache
--- @field processing_items number Number of items currently being processed
--- @field queued_items number Number of items in processing queue
--- @field timer_active boolean Whether background timer is running
--- @field config CacheConfig Current cache configuration

--- @class ErrorObject
--- @field type string Error type identifier
--- @field message string Human-readable error message
--- @field context table Additional context information
--- @field timestamp number Error occurrence timestamp
--- @field recoverable boolean Whether error can be automatically recovered
--- @field recovery_suggestion string Suggested recovery action

--- Provider interface that all token counting providers must implement
--- @class TokenProvider
--- @field count_tokens_async fun(text: string, encoding: string, callback: fun(count: number?, error: string?)) Asynchronous token counting
--- @field count_tokens_sync fun(text: string, encoding: string): number?, string? Synchronous token counting (may block)
--- @field check_availability fun(): boolean, string? Check if provider is available

--- Callback type for asynchronous token counting operations
--- @alias TokenCountCallback fun(result: TokenCountResult?, error: string?)

--- Callback type for buffer token counting operations
--- @alias BufferCountCallback fun(total_tokens: number, buffer_results: BufferResult[], error: string?)

--- Callback type for virtual environment operations
--- @alias VenvCallback fun(success: boolean, error: string?)

--- Callback type for dependency installation
--- @alias DependencyCallback fun(success: boolean, warnings: string?)

--- Callback type for cache update notifications
--- @alias CacheUpdateCallback fun(path: string, path_type: "file"|"directory")

local M = {}

--- Documentation for main plugin functions
--- These are the primary entry points that users will interact with

--- Main plugin setup function
--- @param opts PluginConfig? User configuration options
function M.setup(opts) end

--- Get current buffer token count asynchronously
--- @param callback TokenCountCallback Function called with results
function M.get_current_buffer_count(callback) end

--- Get current buffer token count synchronously (may block UI)
--- @return number? token_count Token count or nil on error
--- @return string? error Error message if counting failed
function M.get_current_buffer_count_sync() end

--- Get list of all available models
--- @return string[] model_names Array of technical model names
function M.get_available_models() end

--- Get current model configuration
--- @return ModelConfig? model_config Current model config or nil if invalid
function M.get_current_model() end

return M