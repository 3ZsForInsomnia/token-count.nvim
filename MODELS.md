# Supported Models

This document lists all models supported by token-count.nvim, organized by company and accuracy method.

## Token Counting Accuracy Legend

- 🎯 **Official Tokenizer**: Uses the company's official tokenizer for exact counts (local-only)
- 🔑 **Official API**: Uses official API for exact counts (requires API key)
- 🛠️ **Dedicated Tool**: Uses specialized tokenizer library for accurate counts
- 📊 **Approximation**: Uses tiktoken or tokencost for estimated counts

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

---

## xAI

### 📊 Approximation (tokencost estimates)

All xAI Grok models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `grok-beta` | Grok Beta | 131,072 | 131,072 | tokencost |
| `grok-4` | Grok 4 | 256,000 | 256,000 | tokencost |

---

## Mistral AI

### 📊 Approximation (tokencost estimates)

All Mistral models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `mistral-large` | Mistral Large | 128,000 | 128,000 | tokencost |
| `mistral-small` | Mistral Small | 32,000 | 8,191 | tokencost |
| `codestral` | Codestral | 32,000 | 8,191 | tokencost |

---

## Perplexity AI

### 📊 Approximation (tokencost estimates)

All Perplexity models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `perplexity-sonar-small` | Perplexity Sonar Small | 127,072 | 127,072 | tokencost |
| `perplexity-sonar-large` | Perplexity Sonar Large | 127,072 | 127,072 | tokencost |

---

## Cohere

### 📊 Approximation (tokencost estimates)

All Cohere models use tokencost for estimation.

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `command-r-plus` | Command R+ | 128,000 | 4,096 | tokencost |
| `command-r` | Command R | 128,000 | 4,096 | tokencost |

---

## Other Providers

### 📊 Approximation (tokencost estimates)

| Model | Nice Name | Context Window | Max Output | Method |
|-------|-----------|----------------|------------|---------|
| `github-copilot` | GitHub Copilot | 8,192 | 4,096 | tokencost |
| `generic` | Generic (GPT-4 compatible) | 8,192 | 4,096 | tokencost |

---

## Model Naming System

Each model can be referenced using any of three naming conventions:

1. **Technical Name** (recommended): `gpt-4`, `claude-3.5-sonnet`, `llama-3.1-70b`
2. **Nice Name** (human-friendly): `"GPT-4"`, `"Claude 3.5 Sonnet"`, `"Llama 3.1 70B"`
3. **Tokencost Name** (legacy): varies by model, used internally

The plugin automatically resolves any of these name types for configuration and selection.

## Accuracy Summary

- **Most Accurate**: OpenAI models (tiktoken) and DeepSeek models (official tokenizer)
- **Conditionally Accurate**: Anthropic and Google models (with API keys)
- **Good Estimates**: All other models via tokencost library
- **Local-Only**: OpenAI and DeepSeek models require no internet connectivity