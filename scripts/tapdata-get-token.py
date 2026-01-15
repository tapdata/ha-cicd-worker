#!/usr/bin/env python3
"""
Tapdata Access Token Retrieval Script
Used in workflows to get access_token and output to stdout
"""
import sys
from tapdata_utils import get_access_token


def main():
    """Main function"""
    if len(sys.argv) != 2:
        print("Usage: tapdata-get-token.py <BASE_URL>", file=sys.stderr)
        sys.exit(1)

    base_url = sys.argv[1]

    if not base_url:
        print("❌ Error: BASE_URL parameter is empty", file=sys.stderr)
        sys.exit(1)

    # Get access_token (all logs output to stderr, only token output to stdout)
    # Redirect print to stderr
    import builtins
    original_print = builtins.print
    builtins.print = lambda *args, **kwargs: original_print(*args, **kwargs, file=sys.stderr)

    try:
        access_token = get_access_token(base_url)
        # Restore original print
        builtins.print = original_print
        # Only output token to stdout
        print(access_token)
    except SystemExit as e:
        # Restore original print
        builtins.print = original_print
        sys.exit(e.code)


if __name__ == "__main__":
    main()

