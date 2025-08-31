# Supported Models

This document lists all models supported by token-count.nvim, organized by company and accuracy method.

## Token Counting Accuracy Legend

 # Supported Models
 
 This document lists all models supported by token-count.nvim and how accurately we can count their tokens.
 
 ## Accuracy Types
 
 - ✅ **Exact Local Counting** - Uses official tokenizers, works offline, 100% accurate
 - 🌐 **Exact API Counting** - Uses official APIs, requires internet + API keys, 100% accurate  
 - 📊 **Smart Estimates** - Uses tokencost library, ~95% accurate estimates
 
 **Note:** Large files (>512KB) shown in file explorers get estimates marked with * for performance.

---

## OpenAI

### 🎯 Official Tokenizer (tiktoken - local, no API required)

All OpenAI models use tiktoken directly for exact token counts with no API calls required.

| Model | Nice Name | Context Window | Max Output | Encoding |
|-------|-----------|----------------|------------|----------|
| `gpt-4` | GPT-4 | 8,192 | 4,096 | cl100k_base |
| `gpt-4-32k` | GPT-4 32K | 32,768 | 4,096 | cl100k_base |
| `gpt-4-turbo` | GPT-4 Turbo | 128,000 | 4,096 | cl100k_base |
| `gpt-3.5-turbo` | GPT-3.5 Turbo | 16,385 | 4,096 | cl100k_base |
| `gpt-4o` | GPT-4o | 128,000 | 16,384 | o200k_base |
| `gpt-4o-mini` | GPT-4o Mini | 128,000 | 16,384 | o200k_base |
| `chatgpt-4o-latest` | ChatGPT-4o Latest | 128,000 | 4,096 | o200k_base |
| `o1-preview` | OpenAI o1 Preview | 128,000 | 32,768 | o200k_base |
| `o1-mini` | OpenAI o1 Mini | 128,000 | 65,536 | o200k_base |
| `o3` | OpenAI o3 | 200,000 | 100,000 | o200k_base |
| `o4-mini` | OpenAI o4 Mini | 200,000 | 100,000 | o200k_base |
| `gpt-4.1` | GPT-4.1 | 1,047,576 | 32,768 | o200k_base |
| `gpt-4.1-mini` | GPT-4.1 Mini | 1,047,576 | 32,768 | o200k_base |
| `gpt-4.1-nano` | GPT-4.1 Nano | 1,047,576 | 32,768 | o200k_base |
| `gpt-5` | GPT-5 | 400,000 | 128,000 | o200k_base |
| `gpt-5-mini` | GPT-5 Mini | 400,000 | 128,000 | o200k_base |
| `gpt-5-nano` | GPT-5 Nano | 400,000 | 128,000 | o200k_base |
## OpenAI

### ✅ Exact Local Counting (tiktoken)

All OpenAI models use tiktoken directly for exact token counts with no API calls required.

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `gpt-4` | GPT-4 | 8,192 | 4,096 |
| `gpt-4-32k` | GPT-4 32K | 32,768 | 4,096 |
| `gpt-4-turbo` | GPT-4 Turbo | 128,000 | 4,096 |
| `gpt-3.5-turbo` | GPT-3.5 Turbo | 16,385 | 4,096 |
| `gpt-4o` | GPT-4o | 128,000 | 16,384 |
| `gpt-4o-mini` | GPT-4o Mini | 128,000 | 16,384 |
| `chatgpt-4o-latest` | ChatGPT-4o Latest | 128,000 | 4,096 |
| `o1-preview` | OpenAI o1 Preview | 128,000 | 32,768 |
| `o1-mini` | OpenAI o1 Mini | 128,000 | 65,536 |
| `o3` | OpenAI o3 | 200,000 | 100,000 |
| `o4-mini` | OpenAI o4 Mini | 200,000 | 100,000 |
| `gpt-4.1` | GPT-4.1 | 1,047,576 | 32,768 |
| `gpt-4.1-mini` | GPT-4.1 Mini | 1,047,576 | 32,768 |
| `gpt-4.1-nano` | GPT-4.1 Nano | 1,047,576 | 32,768 |
| `gpt-5` | GPT-5 | 400,000 | 128,000 |
| `gpt-5-mini` | GPT-5 Mini | 400,000 | 128,000 |
| `gpt-5-nano` | GPT-5 Nano | 400,000 | 128,000 |

---

## DeepSeek

### 🛠️ Dedicated Tokenizer (deepseek_tokenizer - local, exact counts)

DeepSeek models that use the official DeepSeek tokenizer for accurate counts.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `deepseek-chat` | DeepSeek Chat | 128,000 | 4,096 | deepseek_tokenizer |
| `deepseek-coder` | DeepSeek Coder | 128,000 | 4,096 | deepseek_tokenizer |

### 📊 Approximation (tokencost estimates)

DeepSeek models using tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `deepseek-r1` | DeepSeek R1 | 65,536 | 8,192 | tokencost |
| `deepseek-v3` | DeepSeek V3 | 65,536 | 8,192 | tokencost |
## DeepSeek

### ✅ Exact Local Counting (official tokenizer)

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `deepseek-chat` | DeepSeek Chat | 128,000 | 4,096 |
| `deepseek-coder` | DeepSeek Coder | 128,000 | 4,096 |

### 📊 Smart Estimates (tokencost)

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `deepseek-r1` | DeepSeek R1 | 65,536 | 8,192 |
| `deepseek-v3` | DeepSeek V3 | 65,536 | 8,192 |

---

## Anthropic

### 🔑 Official API (requires ANTHROPIC_API_KEY + enable_official_anthropic_counter)

When configured with API access, these models use Anthropic's official token counting API.

### 📊 Approximation (tokencost estimates - default)

By default, all Anthropic models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `claude-3-haiku` | Claude 3 Haiku | 200,000 | 4,096 | tokencost/official API |
| `claude-3-sonnet` | Claude 3 Sonnet | 200,000 | 4,096 | tokencost/official API |
| `claude-3-opus` | Claude 3 Opus | 200,000 | 4,096 | tokencost/official API |
| `claude-3.5-sonnet` | Claude 3.5 Sonnet | 200,000 | 8,192 | tokencost/official API |
| `claude-3.5-haiku` | Claude 3.5 Haiku | 200,000 | 8,192 | tokencost/official API |
| `claude-4-sonnet` | Claude 4 Sonnet | 1,000,000 | 1,000,000 | tokencost/official API |
| `claude-4-opus` | Claude 4 Opus | 200,000 | 32,000 | tokencost/official API |

**Configuration for official API:**
```lua
require("token-count").setup({
  enable_official_anthropic_counter = true,
  -- Requires ANTHROPIC_API_KEY environment variable
})
```
## Anthropic

### 📊 Smart Estimates (default)

All Anthropic models use tokencost for estimation by default.

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `claude-3-haiku` | Claude 3 Haiku | 200,000 | 4,096 |
| `claude-3-sonnet` | Claude 3 Sonnet | 200,000 | 4,096 |
| `claude-3-opus` | Claude 3 Opus | 200,000 | 4,096 |
| `claude-3.5-sonnet` | Claude 3.5 Sonnet | 200,000 | 8,192 |
| `claude-3.5-haiku` | Claude 3.5 Haiku | 200,000 | 8,192 |
| `claude-4-sonnet` | Claude 4 Sonnet | 1,000,000 | 1,000,000 |
| `claude-4-opus` | Claude 4 Opus | 200,000 | 32,000 |

### 🌐 Exact API Counting (optional)

For exact counts, set `ANTHROPIC_API_KEY` and enable in config:

```lua
require("token-count").setup({
  enable_official_anthropic_counter = true,
})
```

**Note:** API counting requires internet access and uses your API quota. Local estimates are usually sufficient.

---

## Google

### 🔑 Official API (requires GOOGLE_API_KEY + enable_official_gemini_counter)

When configured with API access, these models use Google's official token counting API.

### 📊 Approximation (tokencost estimates - default)

By default, all Google models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `gemini-2.0-flash` | Gemini 2.0 Flash | 1,048,576 | 8,192 | tokencost/official API |
| `gemini-1.5-pro` | Gemini 1.5 Pro | 2,097,152 | 8,192 | tokencost/official API |
| `gemini-1.5-flash` | Gemini 1.5 Flash | 1,048,576 | 8,192 | tokencost/official API |
| `gemini-pro` | Gemini Pro | 32,760 | 8,192 | tokencost/official API |

**Configuration for official API:**
```lua
require("token-count").setup({
  enable_official_gemini_counter = true,
  -- Requires GOOGLE_API_KEY environment variable
})
```
## Google

### 📊 Smart Estimates (default)

All Google models use tokencost for estimation by default.

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `gemini-2.0-flash` | Gemini 2.0 Flash | 1,048,576 | 8,192 |
| `gemini-1.5-pro` | Gemini 1.5 Pro | 2,097,152 | 8,192 |
| `gemini-1.5-flash` | Gemini 1.5 Flash | 1,048,576 | 8,192 |
| `gemini-pro` | Gemini Pro | 32,760 | 8,192 |

### 🌐 Exact API Counting (optional)

For exact counts, set `GOOGLE_API_KEY` and enable in config:

```lua
require("token-count").setup({
  enable_official_gemini_counter = true,
})
```

**Note:** API counting requires internet access and uses your API quota. Local estimates are usually sufficient.

---

## Meta

### 📊 Approximation (tokencost estimates)

All Meta Llama models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `llama-3.1-405b` | Llama 3.1 405B | 128,000 | 4,096 | tokencost |
| `llama-3.1-70b` | Llama 3.1 70B | 128,000 | 2,048 | tokencost |
| `llama-3.1-8b` | Llama 3.1 8B | 128,000 | 2,048 | tokencost |
| `llama-3.3-70b` | Llama 3.3 70B | 128,000 | 4,096 | tokencost |


## xAI

### 📊 Approximation (tokencost estimates)

All xAI Grok models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `grok-beta` | Grok Beta | 131,072 | 131,072 | tokencost |
| `grok-4` | Grok 4 | 256,000 | 256,000 | tokencost |


## Mistral AI

### 📊 Approximation (tokencost estimates)

All Mistral models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `mistral-large` | Mistral Large | 128,000 | 128,000 | tokencost |
| `mistral-small` | Mistral Small | 32,000 | 8,191 | tokencost |
| `codestral` | Codestral | 32,000 | 8,191 | tokencost |


## Perplexity AI

### 📊 Approximation (tokencost estimates)

All Perplexity models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `perplexity-sonar-small` | Perplexity Sonar Small | 127,072 | 127,072 | tokencost |
| `perplexity-sonar-large` | Perplexity Sonar Large | 127,072 | 127,072 | tokencost |


## Cohere

### 📊 Approximation (tokencost estimates)

All Cohere models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `command-r-plus` | Command R+ | 128,000 | 4,096 | tokencost |
| `command-r` | Command R | 128,000 | 4,096 | tokencost |


## Other Providers

### 📊 Approximation (tokencost estimates)

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `github-copilot` | GitHub Copilot | 8,192 | 4,096 | tokencost |
| `generic` | Generic (GPT-4 compatible) | 8,192 | 4,096 | tokencost |
## All Other Models

### 📊 Smart Estimates

The following providers all use tokencost for smart estimation:

**Meta Llama Models:**

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `llama-3.1-405b` | Llama 3.1 405B | 128,000 | 4,096 |
| `llama-3.1-70b` | Llama 3.1 70B | 128,000 | 2,048 |
| `llama-3.1-8b` | Llama 3.1 8B | 128,000 | 2,048 |
| `llama-3.3-70b` | Llama 3.3 70B | 128,000 | 4,096 |

**xAI Grok Models:**

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `grok-beta` | Grok Beta | 131,072 | 131,072 |
| `grok-4` | Grok 4 | 256,000 | 256,000 |

**Mistral AI Models:**

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `mistral-large` | Mistral Large | 128,000 | 128,000 |
| `mistral-small` | Mistral Small | 32,000 | 8,191 |
| `codestral` | Codestral | 32,000 | 8,191 |

**Perplexity AI Models:**

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `perplexity-sonar-small` | Perplexity Sonar Small | 127,072 | 127,072 |
| `perplexity-sonar-large` | Perplexity Sonar Large | 127,072 | 127,072 |

**Cohere Models:**

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `command-r-plus` | Command R+ | 128,000 | 4,096 |
| `command-r` | Command R | 128,000 | 4,096 |

**Other:**

| Model | Nice Name | Context Window | Max Output |
|-------|-----------|----------------|------------|
| `github-copilot` | GitHub Copilot | 8,192 | 4,096 |
| `generic` | Generic (GPT-4 compatible) | 8,192 | 4,096 |

---

## Model Naming System

Each model can be referenced using any of three naming conventions:

1. **Technical Name** (recommended): `gpt-4`, `claude-3.5-sonnet`, `llama-3.1-70b`
2. **Nice Name** (human-friendly): `"GPT-4"`, `"Claude 3.5 Sonnet"`, `"Llama 3.1 70B"`
3. **Tokencost Name** (legacy): varies by model, used internally

The plugin automatically resolves any of these name types for configuration and selection.

## Accuracy Summary

 ## Quick Reference
 
 **Best Accuracy (Exact, Local):**
 - OpenAI: All GPT models, o1 models, GPT-5 series
 - DeepSeek: deepseek-chat, deepseek-coder
 
 **Smart Estimates (~95% accurate):**
 - Everything else: Claude, Gemini, Llama, Grok, Mistral, etc.
 
 **Optional Exact Counting:**
 - Anthropic: Set `ANTHROPIC_API_KEY` + enable in config  
 - Google: Set `GOOGLE_API_KEY` + enable in config
 
 ## Model Selection
 
 Use `:TokenCountModel` to browse and switch between models. The plugin supports multiple naming formats - you can refer to models by their technical name (`gpt-4o`), nice name (`GPT-4o`), or search by provider.
 
 ## Performance Notes
 
 - **Large files** (>512KB) in file explorers get estimated counts marked with `*` to keep things fast
 - **Active/visible files** always get full accurate counts regardless of size
 - **Background processing** happens when you're not typing to avoid UI lag