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


def validate_arguments(base_url, record_id):
    """验证输入参数"""
    if not base_url:
        print("❌ 错误：BASE_URL 参数为空")
        sys.exit(1)
    
    if not record_id:
        print("❌ 错误：RECORD_ID 参数为空")
        sys.exit(1)


def check_import_status(base_url, record_id):
    """检查导入状态"""
    # 检查状态的最大次数（5秒间隔，最多检查60次 = 5分钟）
    max_attempts = 60
    attempt = 0
    start_time = time.time()
    
    while attempt < max_attempts:
        attempt += 1
        current_time = datetime.now().strftime('%H:%M:%S')
        print(f"检查次数: {attempt}/{max_attempts} ({current_time})")
        
        # 调用状态检查接口
        check_url = f"{base_url}/api/groupInfo/getGroupImportStatus/{record_id}"
        
        try:
            response = requests.get(check_url)
            http_code = response.status_code
            
            print(f"HTTP 状态码: {http_code}")
            print(f"响应: {response.text}")
            
            # 检查 HTTP 状态码
            if http_code != 200:
                print(f"⚠️  警告：API 返回非 200 状态码: {http_code}，将在5秒后重试...")
                time.sleep(5)
                continue
            
            # 解析响应
            try:
                response_data = response.json()
            except json.JSONDecodeError:
                print("⚠️  警告：无法解析 JSON 响应，将在5秒后重试...")
                time.sleep(5)
                continue
            
            # 提取状态
            status = response_data.get("data", {}).get("status")
            
            if not status:
                print("⚠️  警告：无法从响应中提取状态，将在5秒后重试...")
                time.sleep(5)
                continue
            
            print(f"当前状态: {status}")
            
            # 处理不同状态
            if status == "importing":
                print("⏳ 导入中，等待5秒后继续检查...")
                time.sleep(5)
            elif status == "completed":
                duration = int(time.time() - start_time)
                print_success_footer(duration)
                sys.exit(0)
            elif status == "failed":
                duration = int(time.time() - start_time)
                print_failure_footer(duration, response_data)
                sys.exit(1)
            else:
                print(f"⚠️  未知状态: {status}，将在5秒后重试...")
                time.sleep(5)
                
        except requests.exceptions.RequestException as e:
            print(f"⚠️  警告：请求失败: {e}，将在5秒后重试...")
            time.sleep(5)
            continue
    
    # 超时
    duration = int(time.time() - start_time)
    print_timeout_footer(duration, max_attempts)
    sys.exit(1)


def main():
    """主函数"""
    if len(sys.argv) != 3:
        print("用法: tapdata-check.py <BASE_URL> <RECORD_ID>")
        sys.exit(1)
    
    base_url = sys.argv[1]
    record_id = sys.argv[2]
    
    # 打印头部信息
    print_header(base_url, record_id)
    
    # 验证参数
    validate_arguments(base_url, record_id)
    
    # 检查导入状态
    check_import_status(base_url, record_id)


if __name__ == "__main__":
    main()

