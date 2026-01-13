#!/usr/bin/env bash
set -euo pipefail

# 参数
BASE_URL="$1"
TAR_FILE="$2"

echo "=========================================="
echo "Tapdata 配置导入脚本"
echo "=========================================="
echo "Base URL: $BASE_URL"
echo "TAR 文件: $TAR_FILE"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查参数
if [ -z "$BASE_URL" ]; then
    echo "❌ 错误：BASE_URL 参数为空"
    exit 1
fi

if [ -z "$TAR_FILE" ]; then
    echo "❌ 错误：TAR_FILE 参数为空"
    exit 1
fi

# 检查文件是否存在
if [ ! -f "$TAR_FILE" ]; then
    echo "❌ 错误：TAR 文件不存在: $TAR_FILE"
    exit 1
fi

echo "✓ TAR 文件检查通过，大小: $(du -h "$TAR_FILE" | cut -f1)"
echo ""

# 步骤1: 获取 access_token
echo "步骤1: 获取 access_token..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/token_response.json -X POST \
    -H "Content-Type: application/json" \
    -d '{"accesscode": "3324cfdf-7d3e-4792-bd32-571638d4562f"}' \
    "${BASE_URL}/api/users/generatetoken")

TOKEN_RESPONSE=$(cat /tmp/token_response.json)
echo "HTTP 状态码: $HTTP_CODE"
echo "Token 响应: $TOKEN_RESPONSE"

# 检查 HTTP 状态码
if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ 错误：获取 token 失败，HTTP 状态码: $HTTP_CODE"
    echo "响应内容: $TOKEN_RESPONSE"
    rm -f /tmp/token_response.json
    exit 1
fi

# 提取 access_token
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ 错误：无法从响应中提取 access_token"
    echo "响应内容: $TOKEN_RESPONSE"
    rm -f /tmp/token_response.json
    exit 1
fi

echo "✓ 成功获取 access_token: ${ACCESS_TOKEN:0:20}..."
rm -f /tmp/token_response.json
echo ""

# 步骤2: 上传 TAR 文件并导入
echo "步骤2: 上传 TAR 文件并导入配置..."
IMPORT_URL="${BASE_URL}/api/groupInfo/batch/import?access_token=${ACCESS_TOKEN}"

HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/import_response.json -X POST \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@${TAR_FILE}" \
    "$IMPORT_URL")

IMPORT_RESPONSE=$(cat /tmp/import_response.json)
echo "HTTP 状态码: $HTTP_CODE"
echo "导入响应: $IMPORT_RESPONSE"

# 检查 HTTP 状态码
if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ 错误：导入失败，HTTP 状态码: $HTTP_CODE"
    echo "响应内容: $IMPORT_RESPONSE"
    rm -f /tmp/import_response.json
    exit 1
fi

# 提取 recordId
RECORD_ID=$(echo "$IMPORT_RESPONSE" | grep -o '"recordId":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RECORD_ID" ]; then
    echo "❌ 错误：无法从响应中提取 recordId"
    echo "响应内容: $IMPORT_RESPONSE"
    rm -f /tmp/import_response.json
    exit 1
fi

echo "✓ 成功提交导入任务"
echo "Record ID: $RECORD_ID"
rm -f /tmp/import_response.json
echo ""

# 输出到 GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "record_id=$RECORD_ID" >> "$GITHUB_OUTPUT"
fi

echo "=========================================="
echo "✅ 导入任务已提交"
echo "Record ID: $RECORD_ID"
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

