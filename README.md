# Token-count.nvim

A Neovim plugin for counting tokens in text files using various AI model tokenizers. Features background caching for optimal performance with file explorers and status lines.

## Features

- **Multi-provider token counting** with 60+ supported models
- **High accuracy** for OpenAI (tiktoken) and DeepSeek (official tokenizer) models
- **Background caching** for optimal performance with file/directory explorers
- **Multiple interfaces** - Commands, visual selection, Telescope integration
- **Auto-managed dependencies** - Python virtual environment handled automatically
- **Integrations** - Lualine, Neo-tree, CodeCompanion support

## Installation

### Prerequisites

- Neovim 0.9.0 or later
- Python 3.7 or later

### Using lazy.nvim

```lua
{
  "zacharylevinw/token-count.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim", -- Optional: for enhanced model selection
    "olimorris/codecompanion.nvim",  -- Optional: for CodeCompanion integration
  },
  config = function()
    require("token-count").setup({
      model = "gpt-4",      -- Default model for counting
      log_level = "warn",   -- "info", "warn", "error"
    })
  end,
}
```

### First-time Setup

The plugin automatically creates a virtual environment and installs required Python libraries when first used:

```vim
:TokenCount  " Triggers automatic setup on first use
```

Check setup status:
```vim
:checkhealth token-count
```

## Quick Start

### Basic Commands

```vim
:TokenCount       " Count tokens in current buffer
:TokenCountModel  " Change the active model
:TokenCountAll    " Count tokens across all open buffers
:TokenCountSelection " Count tokens in visual selection (in visual mode)
```

### Configuration

```lua
require("token-count").setup({
  model = "gpt-4",                  -- Default model (see MODELS.md for all options)
  log_level = "warn",               -- Logging verbosity
  context_warning_threshold = 0.4,  -- Warn at 40% context usage
  
  -- Optional: Enable official API token counting (requires API keys)
  enable_official_anthropic_counter = false, -- Requires ANTHROPIC_API_KEY
  enable_official_gemini_counter = false,    -- Requires GOOGLE_API_KEY
})
```

## Supported Models

📋 **[View Complete Models List →](MODELS.md)**

The plugin supports 60+ models including GPT-4/5, Claude, Gemini, Llama, Grok, and more. Token counting accuracy varies by provider:

- **Exact counts**: OpenAI (tiktoken), DeepSeek (official tokenizer)
- **Official API**: Anthropic, Google (with API keys)
- **Estimates**: All other models via tokencost

## Integrations

### Telescope (Enhanced Model Selection)

If Telescope is installed, you get an enhanced model picker with fuzzy search and preview:

```vim
:TokenCountModel  " Opens Telescope picker automatically
```

Or use directly:
```vim
:Telescope token_count models
```

The picker shows:
- Fuzzy search across all model name types
- Preview with detailed model information
- Input/output token limits
- Accuracy information

### Lualine (Status Line)

```lua
require('lualine').setup({
  sections = {
    lualine_c = { 
      require('token-count.integrations.lualine').current_buffer 
    }
  },
  winbar = {
    lualine_c = { 
      require('token-count.integrations.lualine').all_buffers 
    }
  }
})
```

### Neo-tree (File Explorer)

```lua
require("token-count.integrations.neo-tree").setup({
  component = {
    enabled = true,
    show_icon = true,
    icon = "🪙",
  }
})
```

Shows token counts next to files and directories with background processing.

### CodeCompanion

When CodeCompanion is available, token counting is automatically integrated:

- Press `gt` in a CodeCompanion chat to see context token counts
- Use `:TokenCountCodeCompanion` command

## Visual Selection Token Counting

Select text in visual mode and use `:TokenCountSelection`:

```lua
-- Recommended keybinding
vim.keymap.set("v", "<leader>tc", ":TokenCountSelection<CR>", {
    desc = "Count tokens in visual selection",
    silent = true
})
```

## API Usage

### Basic API

```lua
-- Get current buffer token count (async)
require("token-count").get_current_buffer_count(function(result, error)
  if result then
    print("Tokens:", result.token_count)
    print("Model:", result.model_config.name)
  end
end)

-- Get available models
local models = require("token-count").get_available_models()

-- Get current model info
local model_config = require("token-count").get_current_model()
```

### Cache API

```lua
local cache = require("token-count.cache")

-- Get token counts for files/directories
local file_tokens = cache.get_file_token_count("/path/to/file.lua")
local dir_tokens = cache.get_directory_token_count("/path/to/directory")

-- Cache management
cache.clear_cache()
local stats = cache.get_stats()
```

## Documentation

- 📋 **[MODELS.md](MODELS.md)** - Complete list of supported models with accuracy details
- 🔧 **[ADVANCED.md](ADVANCED.md)** - Advanced usage, virtual environment management, and detailed API

## Health Check

```vim
:checkhealth token-count
```

Provides comprehensive status of:
- Python and virtual environment
- Dependency installation
- API key configuration
- Provider availability

## Cache System

The plugin features a unified background cache that:
- Processes files asynchronously without blocking UI
- Shares cached results across all integrations
- Handles both individual files and entire directories
- Updates automatically when files change

Cache is enabled by default with sensible settings. See [ADVANCED.md](ADVANCED.md) for detailed configuration.

## Troubleshooting

### Virtual Environment Issues
```vim
:TokenCountVenvStatus  " Check detailed status
:TokenCountVenvSetup   " Recreate if needed
```

### Dependencies Not Installing
Ensure Python 3.7+ is available:
```bash
python3 --version
```

### Model Not Found
Check available models:
```vim
:TokenCountModel  " Browse and select models
```

## License

MIT License - see LICENSE file for details.