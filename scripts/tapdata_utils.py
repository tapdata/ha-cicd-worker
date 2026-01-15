#!/usr/bin/env python3
"""
Tapdata Utility Module
Provides common utility functions for other scripts
"""
import sys
import json
import requests


def get_access_token(base_url):
    """
    Get Tapdata access_token

    Args:
        base_url: Tapdata service URL

    Returns:
        str: access_token

    Raises:
        SystemExit: Exit program when token retrieval fails
    """
    print("Getting access_token...")

    url = f"{base_url}/api/users/generatetoken"
    headers = {"Content-Type": "application/json"}
    data = {"accesscode": "3324cfdf-7d3e-4792-bd32-571638d4562f"}

    print(f"Request URL: {url}")
    print(f"Request Headers: {json.dumps(headers, indent=2)}")
    print(f"Request Body: {json.dumps(data, indent=2)}")
    print()

    try:
        response = requests.post(url, headers=headers, json=data)
        http_code = response.status_code

        print(f"HTTP Status Code: {http_code}")
        print(f"Response Headers: {dict(response.headers)}")
        print(f"Token Response: {response.text}")

        if http_code != 200:
            print(f"❌ Error: Failed to get token, HTTP status code: {http_code}")
            print(f"Response content: {response.text}")
            sys.exit(1)

        response_json = response.json()
        access_token = response_json.get("data", {}).get("id")

        if not access_token:
            print("❌ Error: Unable to extract access_token from response")
            print(f"Response content: {response.text}")
            sys.exit(1)

        print(f"✓ Successfully obtained access_token: {access_token[:20]}...")
        print()

        return access_token

    except requests.exceptions.RequestException as e:
        print(f"❌ Error: Request failed: {e}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Error: Failed to parse JSON response: {e}")
        sys.exit(1)

