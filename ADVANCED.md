# Advanced Usage and Virtual Environment Management

This document covers advanced usage patterns, virtual environment management, and detailed configuration options for token-count.nvim.

## Virtual Environment Management

The plugin creates and manages its own Python virtual environment with the following dependencies:


### Virtual Environment Location

```
{vim.fn.stdpath("data")}/token-count.nvim/venv/
```

This ensures all tokenizers are available without requiring user Python environment setup. The virtual environment is created automatically on first use.

### Virtual Environment Commands

```vim
:TokenCountVenvStatus  " Show comprehensive venv and dependency status
:TokenCountVenvSetup   " Set up or repair the virtual environment
:TokenCountVenvClean   " Remove venv (with confirmation)
```

#### Detailed Status Information

The `:TokenCountVenvStatus` command provides comprehensive information about:


### Dependency Management

The plugin automatically installs required dependencies when needed. You can also manually trigger installation:

```lua
local venv = require("token-count.venv")

local tiktoken_ok = venv.tiktoken_installed()
local tokencost_ok = venv.tokencost_installed()
local deepseek_ok = venv.deepseek_tokenizer_installed()

venv.install_tiktoken(function(success, error) end)
venv.install_tokencost(function(success, error) end)
venv.install_deepseek_tokenizer(function(success, error) end)

venv.install_all_dependencies(function(success, warnings) end)
```

### Troubleshooting Virtual Environment Issues

#### Python Not Found
Ensure Python 3.7+ is installed and available in your PATH:
```bash
python3 --version
# or
python --version  # Should show Python 3.x
```

#### Virtual Environment Creation Failed
Try manually cleaning and recreating:
```vim
:TokenCountVenvClean
:TokenCountVenvSetup
```

#### Dependencies Installation Failed
Check the virtual environment status for specific error messages:
```vim
:TokenCountVenvStatus
```

Common issues:

## Advanced Configuration

### Complete Configuration Options

```lua
require("token-count").setup({
  -- Model configuration
  model = "gpt-4",                  -- Default model (technical, nice, or tokencost name)
  
  -- Logging
  log_level = "warn",               -- "info", "warn", "error"
  
  -- Context analysis
  context_warning_threshold = 0.4,  -- Warn at 40% context usage
  
  -- Official API token counting (requires API keys)
  enable_official_anthropic_counter = false, -- Requires ANTHROPIC_API_KEY
  enable_official_gemini_counter = false,    -- Requires GOOGLE_API_KEY
  
  -- Cache system configuration
  cache = {
    enabled = true,                 -- Enable background caching
    interval = 30000,               -- Background processing interval (30s)
    max_files_per_batch = 10,       -- Process max files per cycle
    cache_ttl = 300000,             -- File cache TTL (5 minutes)
    directory_cache_ttl = 600000,   -- Directory cache TTL (10 minutes)
    placeholder_text = "⋯",         -- Placeholder while processing
    enable_directory_caching = true, -- Enable directory token counts
    enable_file_caching = true,     -- Enable file token counts
    request_debounce = 100,         -- Debounce immediate requests (100ms)
  },
})
```

### Model Selection and Management

#### Programmatic Model Changes

```lua
local config = require("token-count.config")
local models = require("token-count.models.utils")

local current_config = config.get()
print("Current model:", current_config.model)

current_config.model = "claude-3.5-sonnet"  -- Any name type works

local model_config = models.get_model("gpt-4o")
if model_config then
  print("Model found:", model_config.name)
  print("Context window:", model_config.context_window)
  print("Max output:", model_config.max_output_tokens)
end

local available = models.get_available_models()
print("Available models:", #available)
```

#### Model Resolution

The plugin supports three naming conventions that are automatically resolved:

```lua
local models = require("token-count.models.utils")

local gpt4_1 = models.resolve_model_name("gpt-4")           -- technical
local gpt4_2 = models.resolve_model_name("GPT-4")          -- nice name
local gpt4_3 = models.resolve_model_name("openai/gpt-4")   -- legacy

assert(gpt4_1 == gpt4_2 and gpt4_2 == gpt4_3) -- All return "gpt-4"
```

## Advanced API Usage

### Telescope Extension Usage

The plugin includes a Telescope extension that auto-loads when Telescope is available. You can use it in several ways:

```lua
vim.cmd("TokenCountModel")

vim.cmd("Telescope token_count models")
require("telescope").extensions.token_count.models(function(technical_name, model_config)
  print("Selected:", technical_name)
end)

local telescope_integration = require("token-count.integrations.telescope")
if telescope_integration.is_available() then
  print("Telescope integration active")
end
```

The extension provides:

### Direct Token Counting

```lua
local token_count = require("token-count")

token_count.get_current_buffer_count(function(result, error)
  if result then
    print("Tokens:", result.token_count)
    print("Model:", result.model_config.name)
    print("Context usage:", (result.token_count / result.model_config.context_window) * 100 .. "%")
  end
end)

local count, error = token_count.get_current_buffer_count_sync()
if count then
  print("Token count:", count)
end
```

### Cache Management API

```lua
local cache_manager = require("token-count.cache")

local file_tokens = cache_manager.get_file_token_count("/path/to/file.lua")
local dir_tokens = cache_manager.get_directory_token_count("/path/to/directory")

local tokens = cache_manager.get_token_count("/path/to/item")

cache_manager.process_immediate("/path/to/file.lua", function(result)
  if result then
    print("Tokens:", result.count, "Formatted:", result.formatted)
  end
end)

cache_manager.register_update_callback(function(path, path_type)
  print("Cache updated:", path_type, path)
end)

cache_manager.clear_cache()
local stats = cache_manager.get_stats()
cache_manager.queue_directory_files("/path", recursive)

cache_manager.invalidate_file("/path/to/file.lua", true) -- invalidate and reprocess

cache_manager.update_cache_with_count("/path/to/file.lua", 1234)
```

### Provider API

For advanced use cases, you can access providers directly:

```lua
local models = require("token-count.models.utils")

local model_config = models.get_model("gpt-4")
local provider = models.get_provider_handler(model_config.provider)

provider.count_tokens_async("Hello world", model_config.encoding, function(count, error)
  if count then
    print("Direct count:", count)
  end
end)

local available, error_msg = provider.check_availability()
```

## Performance Considerations

### Cache Optimization

The cache system is designed for optimal performance:


### Large Directory Handling

For large directories:

```lua
require("token-count").setup({
  cache = {
    interval = 60000,        -- Slower background processing
    max_files_per_batch = 5, -- Smaller batches
    cache_ttl = 600000,      -- Longer cache lifetime
  }
})
```

### Memory Management

The plugin automatically manages memory by:

## Health Checks

### Built-in Health Check

```vim
:checkhealth token-count
```

Provides comprehensive status including:

### Custom Health Checks

```lua
local health = require("token-count.health")

local venv = require("token-count.venv")
local status = venv.get_status()

if status.ready then
  print("✓ Plugin ready")
else
  print("✗ Setup required:", status.python_info or "Check :TokenCountVenvStatus")
end
```

## Debugging and Logging

### Enable Debug Logging

```lua
require("token-count").setup({
  log_level = "info", -- Show detailed operation info
})
```

### Access Logs

```lua
local log = require("token-count.log")

log.info("Custom info message")
log.warn("Custom warning")
log.error("Custom error")
```

### Common Debug Commands

```vim
:TokenCount           " Test basic functionality
:TokenCountVenvStatus " Check all dependencies
:TokenCountCacheStats " Check cache status
:checkhealth token-count " Comprehensive health check
```
# Advanced Usage and API Reference

This document covers the public API for custom integrations and advanced usage beyond the basic commands and built-in integrations.

## Public API

### Basic Token Counting

```lua
-- Get current buffer token count (async - recommended)
require("token-count").get_current_buffer_count(function(result, error)
  if result then
    print("Tokens:", result.token_count)
    print("Model:", result.model_config.name)
    print("Context usage:", (result.token_count / result.model_config.context_window) * 100 .. "%")
  else
    print("Error:", error)
  end
end)

-- Synchronous version (may block UI)
local count, error = require("token-count").get_current_buffer_count_sync()
if count then
  print("Token count:", count)
end
```

### File and Directory Token Counts

```lua
local cache = require("token-count.cache")

-- Get token count for any file (returns immediately)
local file_tokens = cache.get_file_token_count("/path/to/file.lua")
-- Returns: "1.2k", "⋯" (processing), or nil (not processable)

-- Get token count for directory (sum of all files)
local dir_tokens = cache.get_directory_token_count("/path/to/directory")

-- Unified API (auto-detects file vs directory)
local tokens = cache.get_token_count("/path/to/item")
```

### Multiple Buffer Token Counting

```lua
-- Count tokens across all open buffers
local function count_all_buffers()
  local buffer_ops = require("token-count.utils.buffer_ops")
  local models = require("token-count.models.utils")
  local config = require("token-count.config").get()
  
  local valid_buffers = buffer_ops.get_valid_buffers()
  local model_config = models.get_model(config.model)
  
  buffer_ops.count_multiple_buffers_async(valid_buffers, model_config, function(total_tokens, buffer_results, error)
    if not error then
      print("Total tokens across all buffers:", total_tokens)
      for _, result in ipairs(buffer_results) do
        print(string.format("  %s: %d tokens", result.name, result.tokens))
      end
    end
  end)
end
```

### Model Management

```lua
-- Get list of all available models
local models = require("token-count").get_available_models()

-- Get current model configuration
local current_model = require("token-count").get_current_model()
print("Current model:", current_model.name)
print("Context window:", current_model.context_window)

-- Change model programmatically
local config = require("token-count.config").get()
config.model = "claude-3.5-sonnet"  -- Any name format works
```

## Custom Status Line Integration

### Example: For other status line plugins

```lua
-- Example integration with a custom status line
local function get_token_display()
  local buffer = require("token-count.buffer")
  local cache = require("token-count.cache")
  
  -- Check if current buffer is valid
  local buffer_id, valid = buffer.get_current_buffer_if_valid()
  if not valid then
    return ""
  end
  
  -- Get file path and token count
  local file_path = vim.api.nvim_buf_get_name(buffer_id)
  if not file_path or file_path == "" then
    return ""
  end
  
  local tokens = cache.get_file_token_count(file_path)
  if tokens and tokens ~= "⋯" then
    return "🪙 " .. tokens
  end
  
  return ""
end

-- Use in your status line configuration
-- This will automatically update as files are processed in the background
```

### Real-time Updates

```lua
-- Register for cache updates to refresh your UI
local cache = require("token-count.cache")

cache.register_update_callback(function(path, path_type)
  -- Refresh your status line, sidebar, etc.
  vim.cmd("redraw")  -- or trigger your specific refresh
end)
```

## Advanced Cache Management

```lua
local cache = require("token-count.cache")

-- Force immediate processing of a file
cache.process_immediate("/path/to/file.lua", function(result)
  if result then
    print("Processed:", result.count, "tokens")
  end
end)

-- Update cache with known count (if you computed it elsewhere)
cache.update_cache_with_count("/path/to/file.lua", 1234)

-- Invalidate and reprocess a file
cache.invalidate_file("/path/to/file.lua", true)

-- Get cache statistics
local stats = cache.get_stats()
print("Cached files:", stats.cached_files)
print("Processing queue:", stats.queued_items)
```

## Virtual Environment Management

The plugin automatically manages its Python dependencies, but you can interact with the system:

```vim
" Check status of all dependencies
:TokenCountVenvStatus

" Manually trigger setup/repair
:TokenCountVenvSetup

" Remove and recreate environment
:TokenCountVenvClean
```

```lua
-- Programmatic access to venv status
local venv = require("token-count.venv")
local status = venv.get_status()

if status.ready then
  print("✓ All dependencies ready")
else
  print("✗ Setup needed")
end
```

## Error Handling and Fallbacks

The plugin includes graceful error handling with automatic fallbacks:

```lua
-- The plugin automatically falls back to estimates when:
-- 1. Python environment isn't ready
-- 2. Dependencies are missing  
-- 3. Files are too large for processing
-- 4. Providers fail

-- You can check if a result is estimated:
require("token-count").get_current_buffer_count(function(result, error)
  if result then
    if result.estimated then
      print("Token count is estimated:", result.token_count)
    else
      print("Token count is exact:", result.token_count)
    end
  end
end)
```

## Health Checks and Debugging

```vim
" Comprehensive health check
:checkhealth token-count

" Cache statistics
:TokenCountCacheStats
```

```lua
-- Enable debug logging
require("token-count").setup({
  log_level = "info"  -- More verbose logging
})
```

## Performance Notes

- **Cache lookups** are instant - files are processed in the background
- **Large files** (>512KB) in background get estimates marked with `*` 
- **Active/visible files** always get full processing regardless of size
- **Background processing** pauses when you're actively typing
- **Memory usage** is kept low through automatic cache expiration

The plugin is designed to be completely non-intrusive while providing comprehensive token information across your entire workspace.