# Token-count.nvim

A Neovim plugin for counting tokens in text files using various AI model tokenizers. Features background caching for optimal performance with file explorers and status lines.

## Features


## Installation

### Prerequisites


### Using lazy.nvim

```lua
{
  "3ZsForInsomnia/token-count.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim", -- Optional: for enhanced model selection
    "olimorris/codecompanion.nvim",  -- Optional: for CodeCompanion integration
  },
  opts = {
    model = "gpt-5",      -- Default model for counting
  },
  config = true,
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


## Visual Selection Token Counting

Select text in visual mode and use `:TokenCountSelection`:

```lua
vim.keymap.set("v", "<leader>tc", ":TokenCountSelection<CR>", {
    desc = "Count tokens in visual selection",
    silent = true
})
```

## API Usage

### Basic API

```lua
require("token-count").get_current_buffer_count(function(result, error)
  if result then
    print("Tokens:", result.token_count)
    print("Model:", result.model_config.name)
  end
end)

local models = require("token-count").get_available_models()

local model_config = require("token-count").get_current_model()
```

### Cache API

```lua
local cache = require("token-count.cache")

local file_tokens = cache.get_file_token_count("/path/to/file.lua")
local dir_tokens = cache.get_directory_token_count("/path/to/directory")

cache.clear_cache()
local stats = cache.get_stats()
```

## Documentation


## Health Check

```vim
:checkhealth token-count
```

Provides comprehensive status of:

## Cache System

The plugin features a unified background cache that:

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
# Token-count.nvim

Count AI model tokens in your files. Works locally for most models, with smart background caching that stays out of your way.

## Why Use This?

- **Know if your code fits** in model context windows before you hit limits
- **Background counting** doesn't slow down your editor - processes files when you're not typing
- **Exact counts** for OpenAI and DeepSeek models, smart estimates for everything else
- **Seamless integrations** with lualine and neo-tree show counts without extra commands
- **Large file handling** - estimates large background files (marked with *), full counts for active files

## Installation & Setup

### Using lazy.nvim

```lua
{
  "zacharylevinw/token-count.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim", -- Optional: enhanced model selection
  },
  config = function()
    require("token-count").setup({
      model = "gpt-4o", -- Default model
    })
  end,
}
```

**Prerequisites:** Neovim 0.9.0+, Python 3.7+

The plugin automatically sets up its Python environment and dependencies on first use. Just run `:TokenCount` and it handles the rest.

## Basic Usage

```vim
:TokenCount        " Count tokens in current file
:TokenCountModel   " Switch between models
:TokenCountAll     " Count all open files
```

## Integrations

### Lualine Status Line

```lua
require('lualine').setup({
  sections = {
    lualine_c = { 
      require('token-count.integrations.lualine').current_buffer 
    }
  }
})
```

### Neo-tree File Explorer

```lua
require("token-count.integrations.neo-tree").setup({
  component = {
    enabled = true,
    show_icon = true,
    icon = "🪙",
  }
})
```

Shows token counts next to files and directories. Large files in the background get estimated counts (marked with *).

## How It Works

- **Active/small files**: Full accurate counting using the best available method
- **Large background files** (>512KB): Smart estimation to keep things fast
- **Exact counting**: OpenAI models (via tiktoken), DeepSeek models (via official tokenizer)
- **Smart estimates**: All other models via tokencost library
- **Optional API counting**: Set `ANTHROPIC_API_KEY` or `GOOGLE_API_KEY` for exact Anthropic/Google counts (not recommended - prefer local)

## Models

Supports 60+ models including GPT-4/5, Claude, Gemini, Llama, and more. See [MODELS.md](MODELS.md) for the complete list.

Switch models anytime with `:TokenCountModel` (uses Telescope if available for better search).

## Advanced Usage

See [ADVANCED.md](ADVANCED.md) for:
- Public API for custom integrations
- Using with other status line plugins  
- Programmatic access to token counts
- Virtual environment management

## Troubleshooting

- **Setup issues**: `:checkhealth token-count`
- **Dependencies**: `:TokenCountVenvStatus`
- **Python not found**: Ensure Python 3.7+ is in your PATH

## License

MIT License
