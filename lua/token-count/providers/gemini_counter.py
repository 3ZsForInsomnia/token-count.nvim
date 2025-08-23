#!/usr/bin/env python3
"""
Token counting script for token-count.nvim using Google GenAI
Accepts text via stdin and model name as argument, returns token count.
"""

import os
import sys

from google import genai


def main():
    if len(sys.argv) != 3:
        print("Usage: gemini_counter.py <model_name> <text>", file=sys.stderr)
        print(
            "Available models: gemini-2.0-flash, gemini-1.5-pro, gemini-1.5-flash",
            file=sys.stderr,
        )
        sys.exit(1)

    model_name = sys.argv[1]
    text = sys.argv[2]

    # Check for API key
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        print("Error: GOOGLE_API_KEY environment variable not set", file=sys.stderr)
        sys.exit(1)

    # Initialize Google GenAI client
    try:
        client = genai.Client(api_key=api_key)
    except Exception as e:
        print(f"Error initializing Google GenAI client: {e}", file=sys.stderr)
        sys.exit(1)

    # Count tokens using Google GenAI's count_tokens function
    try:
        # Use the count_tokens method on the client
        response = client.models.count_tokens(
            model=model_name, contents=[{"parts": [{"text": text}]}]
        )

        # Extract token count from response
        token_count = response.total_tokens

        # Output just the number (for easy parsing in Lua)
        print(token_count)

    except Exception as e:
        print(f"Error during token counting: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
