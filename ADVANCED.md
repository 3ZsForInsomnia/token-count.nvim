# Advanced Usage and Virtual Environment Management

This document covers advanced usage patterns, virtual environment management, and detailed configuration options for token-count.nvim.

## Virtual Environment Management

The plugin creates and manages its own Python virtual environment with the following dependencies:

- **tokencost**: Primary token counting library with support for 50+ models
- **tiktoken**: OpenAI's official tokenizer (used directly and by tokencost)
- **deepseek_tokenizer**: Official DeepSeek tokenizer for accurate DeepSeek model support
- **anthropic**: Official Anthropic SDK (optional, for accurate Claude token counting)
- **google-genai**: Official Google GenAI SDK (optional, for accurate Gemini token counting)

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

- Python availability and version
- Virtual environment status and location
- Installation status of each dependency
- API key configuration for optional providers
- Overall readiness assessment

### Dependency Management

The plugin automatically installs required dependencies when needed. You can also manually trigger installation:

```lua
local venv = require("token-count.venv")

-- Check specific dependencies
local tiktoken_ok = venv.tiktoken_installed()
local tokencost_ok = venv.tokencost_installed()
local deepseek_ok = venv.deepseek_tokenizer_installed()

-- Install specific dependencies
venv.install_tiktoken(function(success, error) end)
venv.install_tokencost(function(success, error) end)
venv.install_deepseek_tokenizer(function(success, error) end)

-- Install all dependencies at once
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
- Network connectivity problems during pip install
- Insufficient disk space
- Permission issues in the data directory

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

-- Get current model
local current_config = config.get()
print("Current model:", current_config.model)

-- Change model programmatically
current_config.model = "claude-3.5-sonnet"  -- Any name type works

-- Validate model exists
local model_config = models.get_model("gpt-4o")
if model_config then
  print("Model found:", model_config.name)
  print("Context window:", model_config.context_window)
  print("Max output:", model_config.max_output_tokens)
end

-- Get all available models
local available = models.get_available_models()
print("Available models:", #available)
```

#### Model Resolution

The plugin supports three naming conventions that are automatically resolved:

```lua
local models = require("token-count.models.utils")

-- These all resolve to the same model:
local gpt4_1 = models.resolve_model_name("gpt-4")           -- technical
local gpt4_2 = models.resolve_model_name("GPT-4")          -- nice name
local gpt4_3 = models.resolve_model_name("openai/gpt-4")   -- legacy

assert(gpt4_1 == gpt4_2 and gpt4_2 == gpt4_3) -- All return "gpt-4"
```

## Advanced API Usage

### Telescope Extension Usage

The plugin includes a Telescope extension that auto-loads when Telescope is available. You can use it in several ways:

```lua
-- Through the normal model selection command (automatic)
vim.cmd("TokenCountModel")

-- Directly via Telescope
vim.cmd("Telescope token_count models")
-- or
require("telescope").extensions.token_count.models(function(technical_name, model_config)
  print("Selected:", technical_name)
end)

-- Check if telescope integration is available
local telescope_integration = require("token-count.integrations.telescope")
if telescope_integration.is_available() then
  print("Telescope integration active")
end
```

The extension provides:
- Enhanced fuzzy search across all model name types
- Preview panel with detailed model information  
- Token limits and accuracy information
- Consistent UI with other Telescope pickers

### Direct Token Counting

```lua
local token_count = require("token-count")

-- Asynchronous counting (recommended)
token_count.get_current_buffer_count(function(result, error)
  if result then
    print("Tokens:", result.token_count)
    print("Model:", result.model_config.name)
    print("Context usage:", (result.token_count / result.model_config.context_window) * 100 .. "%")
  end
end)

-- Synchronous counting (may block UI)
local count, error = token_count.get_current_buffer_count_sync()
if count then
  print("Token count:", count)
end
```

### Cache Management API

```lua
local cache_manager = require("token-count.cache")

-- Get token counts (returns immediately with placeholder or cached value)
local file_tokens = cache_manager.get_file_token_count("/path/to/file.lua")
local dir_tokens = cache_manager.get_directory_token_count("/path/to/directory")

-- Unified API (auto-detects file vs directory)
local tokens = cache_manager.get_token_count("/path/to/item")

-- Force immediate processing (async)
cache_manager.process_immediate("/path/to/file.lua", function(result)
  if result then
    print("Tokens:", result.count, "Formatted:", result.formatted)
  end
end)

-- Register for cache updates
cache_manager.register_update_callback(function(path, path_type)
  print("Cache updated:", path_type, path)
end)

-- Cache management
cache_manager.clear_cache()
local stats = cache_manager.get_stats()
cache_manager.queue_directory_files("/path", recursive)

-- Manual invalidation (for integrations)
cache_manager.invalidate_file("/path/to/file.lua", true) -- invalidate and reprocess

-- Update cache with known count (used by commands)
cache_manager.update_cache_with_count("/path/to/file.lua", 1234)
```

### Provider API

For advanced use cases, you can access providers directly:

```lua
local models = require("token-count.models.utils")

-- Get provider for a model
local model_config = models.get_model("gpt-4")
local provider = models.get_provider_handler(model_config.provider)

-- Count tokens directly with provider
provider.count_tokens_async("Hello world", model_config.encoding, function(count, error)
  if count then
    print("Direct count:", count)
  end
end)

-- Check provider availability
local available, error_msg = provider.check_availability()
```

## Performance Considerations

### Cache Optimization

The cache system is designed for optimal performance:

- **Background Processing**: Files are processed asynchronously without blocking UI
- **Smart Invalidation**: Only changed files are reprocessed
- **Batch Processing**: Multiple files processed efficiently in batches
- **TTL Management**: Cached results expire automatically to stay fresh

### Large Directory Handling

For large directories:

```lua
-- Adjust cache settings for better performance
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
- Limiting cache size through TTL
- Processing files in small batches
- Using lazy loading for provider modules

## Health Checks

### Built-in Health Check

```vim
:checkhealth token-count
```

Provides comprehensive status including:
- Python and virtual environment status
- All dependency installation status
- Provider availability
- API key configuration
- Model validation

### Custom Health Checks

```lua
local health = require("token-count.health")

-- Run specific checks programmatically
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