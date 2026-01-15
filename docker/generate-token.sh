#!/bin/bash

set -e

# ============================================
# GitHub Runner Token 生成脚本
# ============================================
# 使用 GitHub API 生成 Runner Registration Token
# 并自动更新 .env 文件
# ============================================

# 配置区域 - 请修改为你的实际值
GITHUB_PAT="${GITHUB_PAT:-}"                # Personal Access Token (可通过环境变量传入)
REPO_OWNER="${REPO_OWNER:-your-org}"        # 仓库所有者
REPO_NAME="${REPO_NAME:-your-repo}"         # 仓库名称
ENV_FILE=".env"                             # .env 文件路径

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

# 检查必需的工具
check_requirements() {
    if ! command -v curl &> /dev/null; then
        print_error "curl 未安装，请先安装 curl"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq 未安装，请先安装 jq"
        echo "安装方法："
        echo "  macOS: brew install jq"
        echo "  Ubuntu: sudo apt-get install jq"
        exit 1
    fi
}

# 检查配置
check_config() {
    if [ -z "$GITHUB_PAT" ]; then
        print_error "GITHUB_PAT 未设置"
        echo ""
        echo "请通过以下方式之一设置 Personal Access Token："
        echo "  1. 环境变量: export GITHUB_PAT='your_token'"
        echo "  2. 修改脚本中的 GITHUB_PAT 变量"
        echo ""
        echo "如何获取 Personal Access Token："
        echo "  访问: https://github.com/settings/tokens"
        echo "  权限: repo (Full control of private repositories)"
        exit 1
    fi
    
    if [ "$REPO_OWNER" == "your-org" ] || [ "$REPO_NAME" == "your-repo" ]; then
        print_error "请先配置 REPO_OWNER 和 REPO_NAME"
        echo ""
        echo "修改方式："
        echo "  1. 环境变量: export REPO_OWNER='your-org' REPO_NAME='your-repo'"
        echo "  2. 修改脚本中的变量"
        exit 1
    fi
}

# 生成 Runner Token
generate_token() {
    print_info "正在生成 GitHub Runner Token..."
    print_info "仓库: ${REPO_OWNER}/${REPO_NAME}"
    
    RESPONSE=$(curl -s -L \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GITHUB_PAT}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token)
    
    # 检查是否成功
    if [ $? -ne 0 ]; then
        print_error "API 调用失败"
        exit 1
    fi
    
    # 提取 Token 和过期时间
    RUNNER_TOKEN=$(echo $RESPONSE | jq -r '.token')
    EXPIRES_AT=$(echo $RESPONSE | jq -r '.expires_at')
    
    # 检查 Token 是否有效
    if [ "$RUNNER_TOKEN" == "null" ] || [ -z "$RUNNER_TOKEN" ]; then
        print_error "无法获取 Token"
        echo ""
        echo "可能的原因："
        echo "  1. Personal Access Token 无效或已过期"
        echo "  2. 没有仓库的访问权限"
        echo "  3. 仓库名称错误"
        echo ""
        echo "API 响应："
        echo $RESPONSE | jq .
        exit 1
    fi
    
    print_success "Token 生成成功"
    echo "  Token: ${RUNNER_TOKEN:0:20}..."
    echo "  过期时间: ${EXPIRES_AT}"
}

# 更新 .env 文件
update_env_file() {
    print_info "更新 .env 文件..."
    
    if [ -f "$ENV_FILE" ]; then
        # 备份原文件
        cp "$ENV_FILE" "${ENV_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        print_info "已备份原文件"
        
        # 更新 RUNNER_TOKEN
        if grep -q "^RUNNER_TOKEN=" "$ENV_FILE"; then
            # 如果存在，则替换
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
            else
                # Linux
                sed -i "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
            fi
            print_success "已更新 ${ENV_FILE} 中的 RUNNER_TOKEN"
        else
            # 如果不存在，则添加
            echo "RUNNER_TOKEN=${RUNNER_TOKEN}" >> "$ENV_FILE"
            print_success "已添加 RUNNER_TOKEN 到 ${ENV_FILE}"
        fi
    else
        # 如果 .env 不存在，从模板创建
        if [ -f ".env.example" ]; then
            cp .env.example "$ENV_FILE"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
            else
                sed -i "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
            fi
            print_success "已从模板创建 ${ENV_FILE} 并设置 RUNNER_TOKEN"
        else
            print_error "${ENV_FILE} 和 .env.example 都不存在"
            exit 1
        fi
    fi
}

# 主函数
main() {
    echo ""
    echo "=========================================="
    echo "  GitHub Runner Token 生成工具"
    echo "=========================================="
    echo ""
    
    check_requirements
    check_config
    generate_token
    update_env_file
    
    echo ""
    print_success "完成！"
    echo ""
    echo "下一步："
    echo "  1. 检查 ${ENV_FILE} 文件中的其他配置"
    echo "  2. 运行: docker-compose up -d"
    echo ""
}

# 运行主函数
main

