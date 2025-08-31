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
    # The tokencost library sometimes warns about unsupported methods for Anthropic models
    # but should still provide estimates. Let's suppress warnings and handle any exceptions
    import warnings
    import sys
    import io
    
    # Capture and filter stderr to avoid tokencost warnings from being treated as errors
    old_stderr = sys.stderr
    sys.stderr = captured_stderr = io.StringIO()
    
    try:
        # Suppress warnings at both Python and tokencost level
        with warnings.catch_warnings():
            warnings.filterwarnings("ignore")
            
            try:
                result = tokencost.count_string_tokens(text, model)
                return result
            except Exception as e:
                # If count_string_tokens fails for Anthropic models, try count_message_tokens
                if model.startswith("claude") and hasattr(tokencost, 'count_message_tokens'):
                    try:
                        messages = [{"role": "user", "content": text}]
                        return tokencost.count_message_tokens(messages, model)
                    except Exception:
                        # If both methods fail, provide a rough estimate
                        # Using ~4 chars per token as a rough estimate for Claude models
                        return len(text) // 4
                else:
                    # Re-raise for non-Claude models
                    raise e
    finally:
        # Restore stderr but check if there were any real errors (not warnings)
        sys.stderr = old_stderr
        captured_output = captured_stderr.getvalue()
        
        # Only output stderr if it contains actual errors, not warnings
        if captured_output and not ("Warning:" in captured_output and "does not support this method" in captured_output):
            print(captured_output, file=sys.stderr, end="")


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
        # Only print actual errors to stderr, not warnings
        error_msg = str(e)
        if not error_msg.startswith("Warning:"):
            print(f"Error during tokenization: {error_msg}", file=sys.stderr)
        else:
            # For warnings, still try to provide an estimate
            estimated_tokens = len(text) // 4  # Rough estimate
            print(estimated_tokens)
            return
        sys.exit(1)


if __name__ == "__main__":
    main()