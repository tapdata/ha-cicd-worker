#!/usr/bin/env python3
"""
Tapdata Configuration Import Script
"""
import sys
import os
import json
import requests
from datetime import datetime
from pathlib import Path


def print_header():
    """Print script header"""
    print("=" * 42)
    print("Tapdata Configuration Import Script")
    print("=" * 42)


def print_footer(record_id):
    """Print script footer"""
    print("=" * 42)
    print(f"✅ Import task submitted")
    print(f"Record ID: {record_id}")
    print(f"End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 42)


def validate_arguments(base_url, access_token, tar_file):
    """Validate input arguments"""
    if not base_url:
        print("❌ Error: BASE_URL parameter is empty")
        sys.exit(1)

    if not access_token:
        print("❌ Error: ACCESS_TOKEN parameter is empty")
        sys.exit(1)

    if not tar_file:
        print("❌ Error: TAR_FILE parameter is empty")
        sys.exit(1)

    tar_path = Path(tar_file)
    if not tar_path.exists():
        print(f"❌ Error: TAR file does not exist: {tar_file}")
        sys.exit(1)

    # Get file size
    file_size = tar_path.stat().st_size
    if file_size < 1024:
        size_str = f"{file_size}B"
    elif file_size < 1024 * 1024:
        size_str = f"{file_size / 1024:.1f}K"
    else:
        size_str = f"{file_size / (1024 * 1024):.1f}M"

    print(f"✓ TAR file validation passed, size: {size_str}")
    print()


def import_tar_file(base_url, access_token, tar_file):
    """Upload TAR file and import configuration"""
    print("Uploading TAR file and importing configuration...")

    url = f"{base_url}/api/groupInfo/batch/import?access_token={access_token}"
    file_name = Path(tar_file).name

    print(f"Request URL: {url}")
    print(f"Request Method: POST")
    print(f"Request Type: multipart/form-data")
    print(f"Upload File Name: {file_name}")
    print(f"File Path: {tar_file}")
    print()

    try:
        # Upload file using multipart/form-data
        with open(tar_file, 'rb') as f:
            files = {'file': (file_name, f, 'application/octet-stream')}
            response = requests.post(url, files=files)

        http_code = response.status_code

        print(f"HTTP Status Code: {http_code}")
        print(f"Response Headers: {dict(response.headers)}")
        print(f"Import Response: {response.text}")

        if http_code != 200:
            print(f"❌ Error: Import failed, HTTP status code: {http_code}")
            print(f"Response content: {response.text}")
            sys.exit(1)

        response_json = response.json()
        record_id = response_json.get("data", {}).get("recordId")

        if not record_id:
            print("❌ Error: Unable to extract recordId from response")
            print(f"Response content: {response.text}")
            sys.exit(1)

        print("✓ Successfully submitted import task")
        print(f"Record ID: {record_id}")
        print()

        return record_id

    except requests.exceptions.RequestException as e:
        print(f"❌ Error: Request failed: {e}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Error: Failed to parse JSON response: {e}")
        sys.exit(1)
    except IOError as e:
        print(f"❌ Error: Failed to read file: {e}")
        sys.exit(1)


def write_github_output(record_id):
    """Output to GitHub Actions"""
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, 'a') as f:
            f.write(f"record_id={record_id}\n")


def main():
    """Main function"""
    if len(sys.argv) != 4:
        print("Usage: tapdata-import.py <BASE_URL> <ACCESS_TOKEN> <TAR_FILE>")
        sys.exit(1)

    base_url = sys.argv[1]
    access_token = sys.argv[2]
    tar_file = sys.argv[3]

    print_header()
    print(f"Base URL: {base_url}")
    print(f"TAR File: {tar_file}")
    print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    # Validate arguments
    validate_arguments(base_url, access_token, tar_file)

    # Import TAR file
    record_id = import_tar_file(base_url, access_token, tar_file)

    # Output to GitHub Actions
    write_github_output(record_id)

    # Print completion info
    print_footer(record_id)


if __name__ == "__main__":
    main()

