# Token-count.nvim

A Neovim plugin for counting tokens in text files using various AI model tokenizers. The plugin automatically manages its own Python virtual environment to ensure tiktoken is always available.

## Features

- Token counting for OpenAI models (GPT-4, GPT-3.5, etc.) using tiktoken
- Support for Anthropic Claude models
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

## Anthropic Models

For Anthropic models, set the `ANTHROPIC_API_KEY` environment variable and install the anthropic library:

```bash
pip install anthropic
```

## Troubleshooting

1. **"Python 3 not found"**: Ensure Python 3.7+ is installed and available as `python3`
2. **Virtual environment issues**: Run `:TokenCountVenvClean` then `:TokenCountVenvSetup`
3. **Token counting fails**: Check `:checkhealth token-count` for detailed diagnostics
4. **Log files**: Check logs at `{vim.fn.stdpath("state")}/token-count.nvim/log.txt`

## To Do before release

- [ ] Fix lualine all_buffers integration
- [ ] Fix issue with Neo-tree on change?
- [ ] Double check readme and healthcheck
- [ ] Add some images of the token counter

## Roadmap

- [ ] Test/fix CodeCompanion integration
- [ ] Add proper support for Anthropic models
- [ ] Add support for Gemini
- [ ] Add support for other models (DeekSeek, Ollama)
