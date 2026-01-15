#!/usr/bin/env python3
"""
Tapdata 导入状态检查脚本
"""
import sys
import time
import json
import requests
from datetime import datetime


def print_header(base_url, record_id):
    """打印脚本头部信息"""
    print("=" * 42)
    print("Tapdata 导入状态检查脚本")
    print("=" * 42)
    print(f"Base URL: {base_url}")
    print(f"Record ID: {record_id}")
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()


def print_success_footer(duration):
    """打印成功完成信息"""
    print()
    print("=" * 42)
    print("✅ 导入成功完成！")
    print("=" * 42)
    print(f"总耗时: {duration} 秒")
    print(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 42)


def print_failure_footer(duration, response_data):
    """打印失败信息"""
    print()
    print("=" * 42)
    print("❌ 导入失败！")
    print("=" * 42)
    
    # 提取错误信息
    message = response_data.get("data", {}).get("message")
    if message:
        print(f"错误信息: {message}")

    # 提取并格式化 recordDetails
    details = response_data.get("data", {}).get("details", [])
    if details:
        print()
        print("详细信息:")
        for detail in details:
            group_name = detail.get("groupName", "Unknown")
            group_message = detail.get("message", "")
            print(f"\n组名: {group_name}")
            if group_message:
                print(f"消息: {group_message}")

            record_details = detail.get("recordDetails", [])
            if record_details:
                print("资源详情:")
                for record in record_details:
                    resource_name = record.get("resourceName", "Unknown")
                    resource_type = record.get("resourceType", "Unknown")
                    action = record.get("action", "Unknown")
                    record_message = record.get("message", "")
                    print(f"  - {resource_name} ({resource_type})")
                    print(f"    操作: {action}")
                    if record_message:
                        print(f"    消息: {record_message}")
    
    print()
    print(f"总耗时: {duration} 秒")
    print(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 42)


def print_timeout_footer(duration, max_attempts):
    """打印超时信息"""
    print()
    print("=" * 42)
    print("❌ 检查超时！")
    print("=" * 42)
    print(f"已检查 {max_attempts} 次，导入仍未完成")
    print(f"总耗时: {duration} 秒")
    print(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 42)


def validate_arguments(base_url, access_token, record_id):
    """验证输入参数"""
    if not base_url:
        print("❌ 错误：BASE_URL 参数为空")
        sys.exit(1)

    if not access_token:
        print("❌ 错误：ACCESS_TOKEN 参数为空")
        sys.exit(1)

    if not record_id:
        print("❌ 错误：RECORD_ID 参数为空")
        sys.exit(1)


def mask_token(url, token):
    """隐藏 URL 中的 access_token"""
    if token and token in url:
        masked = token[:8] + "..." + token[-4:] if len(token) > 12 else "***"
        return url.replace(token, masked)
    return url


def check_import_status(base_url, access_token, record_id):
    """检查导入状态"""

    # 检查状态的最大次数（5秒间隔，最多检查60次 = 5分钟）
    max_attempts = 60
    attempt = 0
    start_time = time.time()

    while attempt < max_attempts:
        attempt += 1
        current_time = datetime.now().strftime('%H:%M:%S')
        print(f"\n{'='*60}")
        print(f"检查次数: {attempt}/{max_attempts} ({current_time})")
        print(f"{'='*60}")

        # 调用状态检查接口，添加 access_token 参数
        check_url = f"{base_url}/api/groupInfo/getGroupImportStatus/{record_id}?access_token={access_token}"

        # 打印请求详情
        print(f"\n📤 发送请求:")
        print(f"  方法: GET")
        print(f"  URL: {mask_token(check_url, access_token)}")
        print(f"  完整路径: /api/groupInfo/getGroupImportStatus/{record_id}")

        try:
            response = requests.get(check_url)
            http_code = response.status_code

            # 打印响应详情
            print(f"\n📥 收到响应:")
            print(f"  HTTP 状态码: {http_code}")
            print(f"  响应头:")
            for header, value in response.headers.items():
                print(f"    {header}: {value}")
            print(f"  响应体长度: {len(response.text)} 字节")
            print(f"  响应内容: {response.text}")

            # 检查 HTTP 状态码
            if http_code != 200:
                print(f"\n⚠️  警告：API 返回非 200 状态码")
                print(f"  状态码: {http_code}")
                print(f"  状态描述: {response.reason}")
                print(f"  将在5秒后重试...")
                time.sleep(5)
                continue

            # 解析响应
            try:
                response_data = response.json()
                print(f"\n✅ JSON 解析成功")
            except json.JSONDecodeError as e:
                print(f"\n⚠️  警告：无法解析 JSON 响应")
                print(f"  错误: {e}")
                print(f"  将在5秒后重试...")
                time.sleep(5)
                continue

            # 提取状态
            status = response_data.get("data", {}).get("status")

            if not status:
                print(f"\n⚠️  警告：无法从响应中提取状态")
                print(f"  响应数据结构: {json.dumps(response_data, indent=2, ensure_ascii=False)}")
                print(f"  将在5秒后重试...")
                time.sleep(5)
                continue

            print(f"\n📊 状态信息:")
            print(f"  当前状态: {status}")

            # 处理不同状态
            if status == "importing":
                print(f"  ⏳ 导入中，等待5秒后继续检查...")
                time.sleep(5)
            elif status == "completed":
                print(f"  ✅ 导入已完成")
                duration = int(time.time() - start_time)
                print_success_footer(duration)
                sys.exit(0)
            elif status == "failed":
                print(f"  ❌ 导入失败")
                duration = int(time.time() - start_time)
                print_failure_footer(duration, response_data)
                sys.exit(1)
            else:
                print(f"  ⚠️  未知状态: {status}")
                print(f"  将在5秒后重试...")
                time.sleep(5)

        except requests.exceptions.RequestException as e:
            print(f"\n⚠️  警告：请求异常")
            print(f"  异常类型: {type(e).__name__}")
            print(f"  异常信息: {e}")
            print(f"  请求URL: {mask_token(check_url, access_token)}")
            print(f"  将在5秒后重试...")
            time.sleep(5)
            continue
    
    # 超时
    duration = int(time.time() - start_time)
    print_timeout_footer(duration, max_attempts)
    sys.exit(1)


def main():
    """主函数"""
    if len(sys.argv) != 4:
        print("用法: tapdata-check.py <BASE_URL> <ACCESS_TOKEN> <RECORD_ID>")
        sys.exit(1)

    base_url = sys.argv[1]
    access_token = sys.argv[2]
    record_id = sys.argv[3]

    # 打印头部信息
    print_header(base_url, record_id)

    # 验证参数
    validate_arguments(base_url, access_token, record_id)

    # 检查导入状态
    check_import_status(base_url, access_token, record_id)


if __name__ == "__main__":
    main()

