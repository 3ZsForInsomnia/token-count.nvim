#!/usr/bin/env python3
"""
Token counting script for token-count.nvim using tiktoken
Accepts text via stdin and model encoding as argument, returns token count.
"""

import sys

import tiktoken


def main():
    if len(sys.argv) != 3:
        print("Usage: tiktoken_counter.py <encoding_name> <text>", file=sys.stderr)
        print(
            "Available encodings: o200k_base, cl100k_base, p50k_base, p50k_edit, r50k_base, gpt2",
            file=sys.stderr,
        )
        sys.exit(1)

    encoding_name = sys.argv[1]
    text = sys.argv[2]

    try:
        encoding = tiktoken.get_encoding(encoding_name)
        tokens = encoding.encode(text)
        token_count = len(tokens)

        print(token_count)

    except ValueError as e:
        print(f"Error: Invalid encoding '{encoding_name}'. {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error during tokenization: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
