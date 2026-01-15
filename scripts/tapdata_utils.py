#!/usr/bin/env python3
"""
Tapdata 工具模块
提供通用的工具函数供其他脚本使用
"""
import sys
import json
import requests


def get_access_token(base_url):
    """
    获取 Tapdata access_token
    
    Args:
        base_url: Tapdata 服务地址
        
    Returns:
        str: access_token
        
    Raises:
        SystemExit: 当获取 token 失败时退出程序
    """
    print("获取 access_token...")

    url = f"{base_url}/api/users/generatetoken"
    headers = {"Content-Type": "application/json"}
    data = {"accesscode": "3324cfdf-7d3e-4792-bd32-571638d4562f"}

    print(f"请求 URL: {url}")
    print(f"请求 Headers: {json.dumps(headers, indent=2)}")
    print(f"请求 Body: {json.dumps(data, indent=2)}")
    print()

    try:
        response = requests.post(url, headers=headers, json=data)
        http_code = response.status_code

        print(f"HTTP 状态码: {http_code}")
        print(f"响应 Headers: {dict(response.headers)}")
        print(f"Token 响应: {response.text}")

        if http_code != 200:
            print(f"❌ 错误：获取 token 失败，HTTP 状态码: {http_code}")
            print(f"响应内容: {response.text}")
            sys.exit(1)

        response_json = response.json()
        access_token = response_json.get("data", {}).get("id")

        if not access_token:
            print("❌ 错误：无法从响应中提取 access_token")
            print(f"响应内容: {response.text}")
            sys.exit(1)

        print(f"✓ 成功获取 access_token: {access_token[:20]}...")
        print()

        return access_token

    except requests.exceptions.RequestException as e:
        print(f"❌ 错误：请求失败: {e}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ 错误：解析 JSON 响应失败: {e}")
        sys.exit(1)

