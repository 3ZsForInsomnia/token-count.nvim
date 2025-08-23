# Token-count.nvim

A Neovim plugin for counting tokens in text files using various AI model tokenizers. Features background caching for optimal performance with file explorers and status lines.

## Features

- Token counting for OpenAI models (GPT-4, GPT-3.5, etc.) using tiktoken
- Support for Anthropic Claude models
- **Background caching** - Async token counting with configurable intervals
- **File & directory support** - Count tokens for individual files or entire directories
- **Unified cache** - Single cache shared across all integrations (neotree, lualine)
- Visual selection token counting with keybinding support
- Automatic virtual environment management
- Integration with CodeCompanion for context analysis
- Lualine integration for real-time token display
- Neo-tree integration for file token counts
- Health checks to verify setup

## Installation

### Prerequisites

- Neovim 0.9.0 or later
- Python 3.7 or later

### Using lazy.nvim

```lua
{
  "zacharylevinw/token-count.nvim",
  dependencies = {
    -- Optional: for CodeCompanion integration
    "olimorris/codecompanion.nvim",
  },
  config = function()
    require("token-count").setup({
      model = "openai/gpt-4", -- Default model
      log_level = "warn",     -- "info", "warn", "error"
    })
  end,
}
```

### First-time Setup

The plugin will automatically create a virtual environment and install tiktoken when first used. You can also manually trigger setup:

```vim
:TokenCountVenvSetup
```

Check the virtual environment status:

```vim
:TokenCountVenvStatus
:checkhealth token-count
```

## Configuration

```lua
require("token-count").setup({
  model = "openai/gpt-4",           -- Default model for counting
  log_level = "warn",               -- Logging verbosity
  context_warning_threshold = 0.4,  -- Warn at 40% context usage
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

### Supported Models

- `openai/gpt-4` - GPT-4 (8K context)
- `openai/gpt-4-32k` - GPT-4 32K
- `openai/gpt-4-turbo` - GPT-4 Turbo (128K)
- `openai/gpt-4o` - GPT-4o (128K)
- `openai/gpt-4o-mini` - GPT-4o Mini (128K)
- `openai/gpt-3.5-turbo` - GPT-3.5 Turbo (16K)
- `anthropic/claude-3-haiku` - Claude 3 Haiku (200K)
- `anthropic/claude-3-sonnet` - Claude 3 Sonnet (200K)
- `anthropic/claude-3-opus` - Claude 3 Opus (200K)
- `anthropic/claude-3.5-sonnet` - Claude 3.5 Sonnet (200K)
- `generic` - Generic GPT-4 compatible (default)

## Usage

### Basic Commands

```vim
:TokenCount       " Count tokens in current buffer
:TokenCountModel  " Change the active model
:TokenCountAll    " Count tokens across all open buffers
:TokenCountSelection " Count tokens in current visual selection

# Cache Management
:TokenCountCacheStats   " Show cache statistics
:TokenCountCacheClear   " Clear all cached data  
:TokenCountCacheRefresh " Clear cache and re-queue current directory
```

### Visual Selection Token Counting

Select text in visual mode and use `:TokenCountSelection` to count tokens in the selection.

**Keybinding Example:**
```lua
-- Bind to <leader>tc in visual mode
vim.keymap.set("v", "<leader>tc", ":TokenCountSelection<CR>", {
    desc = "Count tokens in visual selection",
    silent = true
})

-- Or use a shorter binding
vim.keymap.set("v", "gt", ":TokenCountSelection<CR>", {
    desc = "Count tokens in selection",
    silent = true
})
```

The command works with all visual modes (`v`, `V`, `<C-v>`) and provides detailed feedback including the token count and percentage of the context window.

### Cache System

The plugin features a unified background cache that processes files asynchronously. This eliminates UI blocking when opening directories in neotree or displaying token counts in lualine.

**Key Benefits:**
- **No UI blocking** - File explorers open instantly with placeholders
- **Shared cache** - Single cache used by all integrations 
- **Directory support** - Token counts for entire directories
- **Background processing** - Configurable async intervals
- **Smart invalidation** - Active buffers update immediately when changed
- **Dynamic discovery** - Folders scanned when expanded in neotree

**Cache API:**
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

cache_manager.register_update_callback(function(path, path_type)
  print("Cache updated:", path_type, path)
end)

cache_manager.clear_cache()
cache_manager.get_stats()
cache_manager.queue_directory_files("/path", recursive)

-- Manual invalidation (for integrations)
cache_manager.invalidate_file("/path/to/file.lua", true) -- invalidate and reprocess
```

### Virtual Environment Management

```vim
:TokenCountVenvStatus  " Show venv status
:TokenCountVenvSetup   " Set up or repair venv
:TokenCountVenvClean   " Remove venv (with confirmation)
```

### Health Check

```vim
:checkhealth token-count
```

## Integrations

### CodeCompanion

When CodeCompanion is available, the plugin automatically adds token counting for chat context:

- Press `gt` in a CodeCompanion chat to see context token counts
- Use `:TokenCountCodeCompanion` command

### Lualine

Shows token counts for current buffer and all buffers with percentage of context window. Automatically uses the unified cache for optimal performance.

```lua
require('lualine').setup({
  sections = {
    lualine_c = { require('token-count.integrations.lualine').current_buffer }
  },
  winbar = {
    lualine_c = { require('token-count.integrations.lualine').all_buffers }
  }
})
```

### Neo-tree

Displays token counts next to files and directories in the file explorer. Shows placeholders initially, then updates with actual counts as background processing completes. Automatically scans folders when expanded.

```lua
require("token-count.integrations.neo-tree").setup({
  component = {
    enabled = true,
    show_icon = true,
    icon = "🪙",
  }
})
```

## Virtual Environment

The plugin creates and manages its own Python virtual environment at:

```
{vim.fn.stdpath("data")}/token-count.nvim/venv/
```

This ensures tiktoken is always available without requiring user Python environment setup. The virtual environment is created automatically on first use and can be managed via the provided commands.

## Troubleshooting

1. **"Python 3 not found"**: Ensure Python 3.7+ is installed and available as `python3`
2. **Virtual environment issues**: Run `:TokenCountVenvClean` then `:TokenCountVenvSetup`
3. **Token counting fails**: Check `:checkhealth token-count` for detailed diagnostics
4. **Log files**: Check logs at `{vim.fn.stdpath("state")}/token-count.nvim/log.txt`

## Roadmap

- [x] Add proper support for Anthropic models
- [x] Add support for Gemini
- [ ] Add documentation about token counters vs estimators, API keys
- [ ] Add support to default to token estimators when API key is not present for Gemini/Anthropic
- [ ] Test/fix CodeCompanion integration
- [ ] Add support for other models (DeekSeek, Ollama)
