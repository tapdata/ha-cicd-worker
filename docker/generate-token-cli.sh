#!/bin/bash

set -e

# ============================================
# GitHub Runner Token 生成脚本 (GitHub CLI 版本)
# ============================================
# 使用 GitHub CLI 生成 Runner Registration Token
# 并自动更新 .env 文件
# ============================================

# 配置
REPO="${REPO:-your-org/your-repo}"  # 格式: owner/repo
ENV_FILE=".env"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

# 检查 GitHub CLI
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) 未安装"
        echo ""
        echo "安装方法："
        echo "  macOS:   brew install gh"
        echo "  Ubuntu:  参考 https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
        echo ""
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq 未安装"
        echo ""
        echo "安装方法："
        echo "  macOS:   brew install jq"
        echo "  Ubuntu:  sudo apt-get install jq"
        echo ""
        exit 1
    fi
    
    # 检查是否已登录
    if ! gh auth status &> /dev/null; then
        print_error "未登录 GitHub CLI"
        echo ""
        echo "请先运行: gh auth login"
        echo ""
        exit 1
    fi
}

# 检查配置
check_config() {
    if [ "$REPO" == "your-org/your-repo" ]; then
        print_error "请先配置仓库信息"
        echo ""
        echo "修改方式："
        echo "  1. 环境变量: export REPO='your-org/your-repo'"
        echo "  2. 修改脚本中的 REPO 变量"
        echo "  3. 命令行参数: ./generate-token-cli.sh your-org/your-repo"
        echo ""
        exit 1
    fi
}

# 生成 Token
generate_token() {
    print_info "正在生成 Runner Token..."
    print_info "仓库: ${REPO}"
    
    RUNNER_TOKEN=$(gh api -X POST repos/${REPO}/actions/runners/registration-token 2>/dev/null | jq -r '.token')
    
    if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" == "null" ]; then
        print_error "无法生成 Token"
        echo ""
        echo "可能的原因："
        echo "  1. 没有仓库的访问权限"
        echo "  2. 仓库名称格式错误（应为: owner/repo）"
        echo "  3. GitHub CLI 未正确登录"
        echo ""
        echo "请检查："
        echo "  gh auth status"
        echo "  gh repo view ${REPO}"
        echo ""
        exit 1
    fi
    
    print_success "Token 生成成功"
    echo "  Token: ${RUNNER_TOKEN:0:20}..."
}

# 更新 .env 文件
update_env_file() {
    print_info "更新 .env 文件..."
    
    if [ -f "$ENV_FILE" ]; then
        # 备份
        cp "$ENV_FILE" "${ENV_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        
        # 更新
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
        else
            sed -i "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
        fi
        print_success "已更新 ${ENV_FILE}"
    else
        if [ -f ".env.example" ]; then
            cp .env.example "$ENV_FILE"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
            else
                sed -i "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
            fi
            print_success "已创建 ${ENV_FILE}"
        else
            print_error "${ENV_FILE} 和 .env.example 都不存在"
            exit 1
        fi
    fi
}

# 主函数
main() {
    # 如果有命令行参数，使用参数作为仓库名
    if [ $# -eq 1 ]; then
        REPO="$1"
    fi
    
    echo ""
    echo "=========================================="
    echo "  GitHub Runner Token 生成工具 (CLI)"
    echo "=========================================="
    echo ""
    
    check_gh_cli
    check_config
    generate_token
    update_env_file
    
    echo ""
    print_success "完成！"
    echo ""
    echo "下一步："
    echo "  docker-compose up -d"
    echo ""
}

main "$@"

