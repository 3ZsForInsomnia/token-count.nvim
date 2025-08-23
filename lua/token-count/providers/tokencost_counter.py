#!/usr/bin/env python3
"""
Token counting script for token-count.nvim using tokencost with fallback support
Accepts model name and configuration flags, returns token count.
"""

import os
import sys
from typing import Optional

import tokencost


def count_with_official_anthropic(text: str, model: str) -> Optional[int]:
    """Try to count tokens using official Anthropic API if enabled and available."""
    try:
        import anthropic
        
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            return None
            
        client = anthropic.Anthropic(api_key=api_key)
        response = client.beta.messages.count_tokens(
            betas=["token-counting-2024-11-01"],
            model=model,
            messages=[{"role": "user", "content": text}]
        )
        return response.input_tokens
    except Exception:
        return None


def count_with_official_gemini(text: str, model: str) -> Optional[int]:
    """Try to count tokens using official Gemini API if enabled and available."""
    try:
        import google.genai
        
        api_key = os.getenv("GOOGLE_API_KEY")
        if not api_key:
            return None
            
        client = google.genai.Client(api_key=api_key)
        response = client.models.count_tokens(
            model=model,
            contents=[{"parts": [{"text": text}]}]
        )
        return response.total_tokens
    except Exception:
        return None


def count_with_tokencost(text: str, model: str) -> int:
    """Count tokens using tokencost library (estimates for most models)."""
    return tokencost.count_string_tokens(text, model)


def main():
    if len(sys.argv) != 5:
        print("Usage: tokencost_counter.py <model> <enable_anthropic> <enable_gemini> <text>", file=sys.stderr)
        sys.exit(1)

    model = sys.argv[1]
    enable_anthropic = sys.argv[2].lower() == "true"
    enable_gemini = sys.argv[3].lower() == "true"
    text = sys.argv[4]

    try:
        token_count = None
        
        # Try official Anthropic API if enabled and model is Anthropic
        if enable_anthropic and model.startswith("claude"):
            token_count = count_with_official_anthropic(text, model)
            
        # Try official Gemini API if enabled and model is Gemini
        if token_count is None and enable_gemini and model.startswith("gemini"):
            token_count = count_with_official_gemini(text, model)
            
        # Fallback to tokencost for all models
        if token_count is None:
            token_count = count_with_tokencost(text, model)

        print(token_count)

    except Exception as e:
        print(f"Error during tokenization: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()