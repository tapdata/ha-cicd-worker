#!/usr/bin/env python3
"""
Tapdata Access Token 获取脚本
用于在工作流中获取 access_token 并输出到标准输出
"""
import sys
from tapdata_utils import get_access_token


def main():
    """主函数"""
    if len(sys.argv) != 2:
        print("用法: tapdata-get-token.py <BASE_URL>", file=sys.stderr)
        sys.exit(1)
    
    base_url = sys.argv[1]
    
    if not base_url:
        print("❌ 错误：BASE_URL 参数为空", file=sys.stderr)
        sys.exit(1)
    
    # 获取 access_token（所有日志输出到 stderr，只有 token 输出到 stdout）
    # 重定向 print 到 stderr
    import builtins
    original_print = builtins.print
    builtins.print = lambda *args, **kwargs: original_print(*args, **kwargs, file=sys.stderr)
    
    try:
        access_token = get_access_token(base_url)
        # 恢复原始 print
        builtins.print = original_print
        # 只输出 token 到 stdout
        print(access_token)
    except SystemExit as e:
        # 恢复原始 print
        builtins.print = original_print
        sys.exit(e.code)


if __name__ == "__main__":
    main()

