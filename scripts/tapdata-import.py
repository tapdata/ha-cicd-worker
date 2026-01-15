#!/usr/bin/env python3
"""
Tapdata 配置导入脚本
"""
import sys
import os
import json
import requests
from datetime import datetime
from pathlib import Path


def print_header():
    """打印脚本头部信息"""
    print("=" * 42)
    print("Tapdata 配置导入脚本")
    print("=" * 42)


def print_footer(record_id):
    """打印脚本尾部信息"""
    print("=" * 42)
    print(f"✅ 导入任务已提交")
    print(f"Record ID: {record_id}")
    print(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 42)


def validate_arguments(base_url, access_token, tar_file):
    """验证输入参数"""
    if not base_url:
        print("❌ 错误：BASE_URL 参数为空")
        sys.exit(1)

    if not access_token:
        print("❌ 错误：ACCESS_TOKEN 参数为空")
        sys.exit(1)

    if not tar_file:
        print("❌ 错误：TAR_FILE 参数为空")
        sys.exit(1)
    
    tar_path = Path(tar_file)
    if not tar_path.exists():
        print(f"❌ 错误：TAR 文件不存在: {tar_file}")
        sys.exit(1)
    
    # 获取文件大小
    file_size = tar_path.stat().st_size
    if file_size < 1024:
        size_str = f"{file_size}B"
    elif file_size < 1024 * 1024:
        size_str = f"{file_size / 1024:.1f}K"
    else:
        size_str = f"{file_size / (1024 * 1024):.1f}M"
    
    print(f"✓ TAR 文件检查通过，大小: {size_str}")
    print()


def import_tar_file(base_url, access_token, tar_file):
    """上传 TAR 文件并导入配置"""
    print("上传 TAR 文件并导入配置...")

    url = f"{base_url}/api/groupInfo/batch/import?access_token={access_token}"
    file_name = Path(tar_file).name

    print(f"请求 URL: {url}")
    print(f"请求方法: POST")
    print(f"请求类型: multipart/form-data")
    print(f"上传文件名: {file_name}")
    print(f"文件路径: {tar_file}")
    print()

    try:
        # 使用 multipart/form-data 上传文件
        with open(tar_file, 'rb') as f:
            files = {'file': (file_name, f, 'application/octet-stream')}
            response = requests.post(url, files=files)

        http_code = response.status_code

        print(f"HTTP 状态码: {http_code}")
        print(f"响应 Headers: {dict(response.headers)}")
        print(f"导入响应: {response.text}")

        if http_code != 200:
            print(f"❌ 错误：导入失败，HTTP 状态码: {http_code}")
            print(f"响应内容: {response.text}")
            sys.exit(1)

        response_json = response.json()
        record_id = response_json.get("data", {}).get("recordId")

        if not record_id:
            print("❌ 错误：无法从响应中提取 recordId")
            print(f"响应内容: {response.text}")
            sys.exit(1)

        print("✓ 成功提交导入任务")
        print(f"Record ID: {record_id}")
        print()

        return record_id

    except requests.exceptions.RequestException as e:
        print(f"❌ 错误：请求失败: {e}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ 错误：解析 JSON 响应失败: {e}")
        sys.exit(1)
    except IOError as e:
        print(f"❌ 错误：读取文件失败: {e}")
        sys.exit(1)


def write_github_output(record_id):
    """输出到 GitHub Actions"""
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, 'a') as f:
            f.write(f"record_id={record_id}\n")


def main():
    """主函数"""
    if len(sys.argv) != 4:
        print("用法: tapdata-import.py <BASE_URL> <ACCESS_TOKEN> <TAR_FILE>")
        sys.exit(1)

    base_url = sys.argv[1]
    access_token = sys.argv[2]
    tar_file = sys.argv[3]

    print_header()
    print(f"Base URL: {base_url}")
    print(f"TAR 文件: {tar_file}")
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    # 验证参数
    validate_arguments(base_url, access_token, tar_file)

    # 导入 TAR 文件
    record_id = import_tar_file(base_url, access_token, tar_file)
    
    # 输出到 GitHub Actions
    write_github_output(record_id)
    
    # 打印完成信息
    print_footer(record_id)


if __name__ == "__main__":
    main()

