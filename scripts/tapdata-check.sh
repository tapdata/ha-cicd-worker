#!/usr/bin/env bash
set -euo pipefail

# 参数
BASE_URL="$1"
RECORD_ID="$2"

echo "=========================================="
echo "Tapdata 导入状态检查脚本"
echo "=========================================="
echo "Base URL: $BASE_URL"
echo "Record ID: $RECORD_ID"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查参数
if [ -z "$BASE_URL" ]; then
    echo "❌ 错误：BASE_URL 参数为空"
    exit 1
fi

if [ -z "$RECORD_ID" ]; then
    echo "❌ 错误：RECORD_ID 参数为空"
    exit 1
fi

# 检查状态的最大次数（5秒间隔，最多检查60次 = 5分钟）
MAX_ATTEMPTS=60
ATTEMPT=0
START_TIME=$(date +%s)

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "检查次数: $ATTEMPT/$MAX_ATTEMPTS ($(date '+%H:%M:%S'))"

    # 调用状态检查接口
    CHECK_URL="${BASE_URL}/api/groupInfo/batch/import/${RECORD_ID}"
    HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/check_response.json -X GET "$CHECK_URL")
    RESPONSE=$(cat /tmp/check_response.json)

    echo "HTTP 状态码: $HTTP_CODE"
    echo "响应: $RESPONSE"

    # 检查 HTTP 状态码
    if [ "$HTTP_CODE" != "200" ]; then
        echo "⚠️  警告：API 返回非 200 状态码: $HTTP_CODE，将在5秒后重试..."
        rm -f /tmp/check_response.json
        sleep 5
        continue
    fi

    # 提取状态
    STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$STATUS" ]; then
        echo "⚠️  警告：无法从响应中提取状态，将在5秒后重试..."
        rm -f /tmp/check_response.json
        sleep 5
        continue
    fi

    echo "当前状态: $STATUS"

    case "$STATUS" in
        "importing")
            echo "⏳ 导入中，等待5秒后继续检查..."
            rm -f /tmp/check_response.json
            sleep 5
            ;;
        "completed")
            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))
            echo ""
            echo "=========================================="
            echo "✅ 导入成功完成！"
            echo "=========================================="
            echo "总耗时: ${DURATION} 秒"
            echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "=========================================="
            rm -f /tmp/check_response.json
            exit 0
            ;;
        "failed")
            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))
            echo ""
            echo "=========================================="
            echo "❌ 导入失败！"
            echo "=========================================="

            # 提取错误信息
            MESSAGE=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            if [ -n "$MESSAGE" ]; then
                echo "错误信息: $MESSAGE"
            fi

            # 提取并格式化 recordDetails
            DETAILS=$(echo "$RESPONSE" | grep -o '"recordDetails":\[.*\]' | sed 's/"recordDetails"://')
            if [ -n "$DETAILS" ]; then
                echo ""
                echo "详细信息:"
                # 使用 python 格式化 JSON（如果可用）
                if command -v python3 &> /dev/null; then
                    echo "$DETAILS" | python3 -m json.tool 2>/dev/null || echo "$DETAILS"
                else
                    echo "$DETAILS"
                fi
            fi

            echo ""
            echo "总耗时: ${DURATION} 秒"
            echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "=========================================="
            rm -f /tmp/check_response.json
            exit 1
            ;;
        *)
            echo "⚠️  未知状态: $STATUS，将在5秒后重试..."
            rm -f /tmp/check_response.json
            sleep 5
            ;;
    esac
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo ""
echo "=========================================="
echo "❌ 检查超时！"
echo "=========================================="
echo "已检查 $MAX_ATTEMPTS 次，导入仍未完成"
echo "总耗时: ${DURATION} 秒"
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
rm -f /tmp/check_response.json
exit 1

