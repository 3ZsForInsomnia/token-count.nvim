#!/usr/bin/env python3
"""
Token counting script for token-count.nvim using Anthropic API
Accepts text via stdin and model name as argument, returns token count.
"""

import sys
import os
from anthropic import Anthropic


def main():
    if len(sys.argv) != 3:
        print("Usage: anthropic_counter.py <model_name> <text>", file=sys.stderr)
        print("Available models: claude-3-haiku-20240307, claude-3-sonnet-20240229, claude-3-opus-20240229, claude-3-5-sonnet-20240620", file=sys.stderr)
        sys.exit(1)
    
    model_name = sys.argv[1]
    text = sys.argv[2]
    
    # Check for API key
    api_key = os.getenv('ANTHROPIC_API_KEY')
    if not api_key:
        print("Error: ANTHROPIC_API_KEY environment variable not set", file=sys.stderr)
        sys.exit(1)
    
    # Initialize Anthropic client
    try:
        client = Anthropic(api_key=api_key)
    except Exception as e:
        print(f"Error initializing Anthropic client: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Count tokens using Anthropic's API
    try:
        # Use the beta token counting feature
        response = client.beta.messages.count_tokens(
            model=model_name,
            messages=[
                {
                    "role": "user",
                    "content": text
                }
            ]
        )
        
        # Extract token count from response
        token_count = response.input_tokens
        
        # Output just the number (for easy parsing in Lua)
        print(token_count)
        
    except Exception as e:
        print(f"Error during token counting: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()