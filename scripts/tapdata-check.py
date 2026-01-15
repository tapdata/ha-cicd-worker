#!/usr/bin/env python3
"""
Tapdata Import Status Check Script
"""
import sys
import time
import json
import requests
from datetime import datetime


def print_header(base_url, record_id):
    """Print script header"""
    print("=" * 42)
    print("Tapdata Import Status Check Script")
    print("=" * 42)
    print(f"Base URL: {base_url}")
    print(f"Record ID: {record_id}")
    print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()


def print_success_footer(duration):
    """Print success completion info"""
    print()
    print("=" * 42)
    print("✅ Import completed successfully!")
    print("=" * 42)
    print(f"Total duration: {duration} seconds")
    print(f"End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 42)


def print_failure_footer(duration, response_data):
    """Print failure info"""
    print()
    print("=" * 42)
    print("❌ Import failed!")
    print("=" * 42)

    # Extract error message
    message = response_data.get("data", {}).get("message")
    if message:
        print(f"Error message: {message}")

    # Extract and format recordDetails
    details = response_data.get("data", {}).get("details", [])
    if details:
        print()
        print("Details:")
        for detail in details:
            group_name = detail.get("groupName", "Unknown")
            group_message = detail.get("message", "")
            print(f"\nGroup name: {group_name}")
            if group_message:
                print(f"Message: {group_message}")

            record_details = detail.get("recordDetails", [])
            if record_details:
                print("Resource details:")
                for record in record_details:
                    resource_name = record.get("resourceName", "Unknown")
                    resource_type = record.get("resourceType", "Unknown")
                    action = record.get("action", "Unknown")
                    record_message = record.get("message", "")
                    print(f"  - {resource_name} ({resource_type})")
                    print(f"    Action: {action}")
                    if record_message:
                        print(f"    Message: {record_message}")

    print()
    print(f"Total duration: {duration} seconds")
    print(f"End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 42)


def print_timeout_footer(duration, max_attempts):
    """Print timeout info"""
    print()
    print("=" * 42)
    print("❌ Check timeout!")
    print("=" * 42)
    print(f"Checked {max_attempts} times, import still not completed")
    print(f"Total duration: {duration} seconds")
    print(f"End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 42)


def validate_arguments(base_url, access_token, record_id):
    """Validate input arguments"""
    if not base_url:
        print("❌ Error: BASE_URL parameter is empty")
        sys.exit(1)

    if not access_token:
        print("❌ Error: ACCESS_TOKEN parameter is empty")
        sys.exit(1)

    if not record_id:
        print("❌ Error: RECORD_ID parameter is empty")
        sys.exit(1)


def mask_token(url, token):
    """Mask access_token in URL"""
    if token and token in url:
        masked = token[:8] + "..." + token[-4:] if len(token) > 12 else "***"
        return url.replace(token, masked)
    return url


def check_import_status(base_url, access_token, record_id):
    """Check import status"""

    # Maximum number of status checks (5 second interval, max 60 times = 5 minutes)
    max_attempts = 60
    attempt = 0
    start_time = time.time()

    while attempt < max_attempts:
        attempt += 1
        current_time = datetime.now().strftime('%H:%M:%S')
        print(f"\n{'='*60}")
        print(f"Check attempt: {attempt}/{max_attempts} ({current_time})")
        print(f"{'='*60}")

        # Call status check API with access_token parameter
        check_url = f"{base_url}/api/groupInfo/getGroupImportStatus/{record_id}?access_token={access_token}"

        # Print request details
        print(f"\n📤 Sending request:")
        print(f"  Method: GET")
        print(f"  URL: {mask_token(check_url, access_token)}")
        print(f"  Full path: /api/groupInfo/getGroupImportStatus/{record_id}")

        try:
            response = requests.get(check_url)
            http_code = response.status_code

            # Print response details
            print(f"\n📥 Received response:")
            print(f"  HTTP Status Code: {http_code}")
            print(f"  Response Headers:")
            for header, value in response.headers.items():
                print(f"    {header}: {value}")
            print(f"  Response Body Length: {len(response.text)} bytes")
            print(f"  Response Content: {response.text}")

            # Check HTTP status code
            if http_code != 200:
                print(f"\n⚠️  Warning: API returned non-200 status code")
                print(f"  Status code: {http_code}")
                print(f"  Status description: {response.reason}")
                print(f"  Will retry in 5 seconds...")
                time.sleep(5)
                continue

            # Parse response
            try:
                response_data = response.json()
                print(f"\n✅ JSON parsing successful")
            except json.JSONDecodeError as e:
                print(f"\n⚠️  Warning: Unable to parse JSON response")
                print(f"  Error: {e}")
                print(f"  Will retry in 5 seconds...")
                time.sleep(5)
                continue

            # Extract status
            status = response_data.get("data", {}).get("status")

            if not status:
                print(f"\n⚠️  Warning: Unable to extract status from response")
                print(f"  Response data structure: {json.dumps(response_data, indent=2, ensure_ascii=False)}")
                print(f"  Will retry in 5 seconds...")
                time.sleep(5)
                continue

            print(f"\n📊 Status information:")
            print(f"  Current status: {status}")

            # Handle different statuses
            if status == "importing":
                print(f"  ⏳ Importing, waiting 5 seconds before next check...")
                time.sleep(5)
            elif status == "completed":
                print(f"  ✅ Import completed")
                duration = int(time.time() - start_time)
                print_success_footer(duration)
                sys.exit(0)
            elif status == "failed":
                print(f"  ❌ Import failed")
                duration = int(time.time() - start_time)
                print_failure_footer(duration, response_data)
                sys.exit(1)
            else:
                print(f"  ⚠️  Unknown status: {status}")
                print(f"  Will retry in 5 seconds...")
                time.sleep(5)

        except requests.exceptions.RequestException as e:
            print(f"\n⚠️  Warning: Request exception")
            print(f"  Exception type: {type(e).__name__}")
            print(f"  Exception message: {e}")
            print(f"  Request URL: {mask_token(check_url, access_token)}")
            print(f"  Will retry in 5 seconds...")
            time.sleep(5)
            continue

    # Timeout
    duration = int(time.time() - start_time)
    print_timeout_footer(duration, max_attempts)
    sys.exit(1)


def main():
    """Main function"""
    if len(sys.argv) != 4:
        print("Usage: tapdata-check.py <BASE_URL> <ACCESS_TOKEN> <RECORD_ID>")
        sys.exit(1)

    base_url = sys.argv[1]
    access_token = sys.argv[2]
    record_id = sys.argv[3]

    # Print header
    print_header(base_url, record_id)

    # Validate arguments
    validate_arguments(base_url, access_token, record_id)

    # Check import status
    check_import_status(base_url, access_token, record_id)


if __name__ == "__main__":
    main()

