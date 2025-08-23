#!/usr/bin/env python3
"""
Token counting script for token-count.nvim using DeepSeek tokenizer
Accepts text and returns token count using DeepSeek's official tokenizer.
"""

import sys

from deepseek_tokenizer import ds_token


def main():
    if len(sys.argv) != 2:
        print("Usage: deepseek_counter.py <text>", file=sys.stderr)
        sys.exit(1)

    text = sys.argv[1]

    try:
        # Encode text using DeepSeek tokenizer
        tokens = ds_token.encode(text)
        token_count = len(tokens)

        print(token_count)

    except Exception as e:
        print(f"Error during tokenization: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()