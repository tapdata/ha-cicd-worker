# GitHub Actions Runner Token 生成完整指南

## 📖 目录

- [Token 类型说明](#token-类型说明)
- [方法一：网页界面获取](#方法一网页界面获取推荐用于测试)
- [方法二：GitHub API 生成](#方法二github-api-生成推荐用于生产环境)
- [方法三：GitHub CLI](#方法三使用-github-cli)
- [自动化脚本](#自动化脚本示例)
- [常见问题](#常见问题)

---

## Token 类型说明

### Runner Registration Token

- **用途**：用于注册新的 Self-Hosted Runner
- **有效期**：1 小时
- **特点**：一次性使用，注册成功后 Runner 会获得长期凭证
- **获取方式**：网页界面、API、GitHub CLI

### Personal Access Token (PAT)

- **用途**：用于调用 GitHub API 生成 Runner Token
- **有效期**：可自定义（最长无限期）
- **特点**：可重复使用，用于自动化场景
- **获取方式**：GitHub Settings

---

## 方法一：网页界面获取（推荐用于测试）

### 仓库级别 Runner

#### 步骤 1：进入仓库设置

1. 打开你的 GitHub 仓库：`https://github.com/your-org/your-repo`
2. 点击仓库顶部的 **Settings**（设置）标签
3. 在左侧菜单中找到 **Actions** 部分
4. 点击 **Runners**

#### 步骤 2：创建新 Runner

1. 点击右上角绿色按钮 **New self-hosted runner**
2. 选择操作系统：**Linux**
3. 选择架构：**x64**

#### 步骤 3：获取 Token

在 "Configure" 部分，你会看到配置命令：

```bash
# Download
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure
./config.sh --url https://github.com/your-org/your-repo --token AXXXXXXXXXXXXXXXXXXXXX
```

**复制 `--token` 后面的值**，这就是你的 Runner Token。

#### 步骤 4：使用 Token

将获取的 Token 填入 `docker/.env` 文件：

```bash
RUNNER_TOKEN=AXXXXXXXXXXXXXXXXXXXXX
RUNNER_REPO_URL=https://github.com/your-org/your-repo
```

### 组织级别 Runner

#### 步骤 1：进入组织设置

1. 打开你的 GitHub 组织页面：`https://github.com/your-org`
2. 点击 **Settings**
3. 在左侧菜单中找到 **Actions** -> **Runners**

#### 步骤 2：创建新 Runner

1. 点击 **New runner** -> **New self-hosted runner**
2. 后续步骤与仓库级别相同

#### 步骤 3：使用组织级 Token

```bash
RUNNER_TOKEN=AXXXXXXXXXXXXXXXXXXXXX
RUNNER_REPO_URL=https://github.com/your-org
```

### ⚠️ 注意事项

- **有效期**：网页生成的 Token 有效期为 **1 小时**
- **使用场景**：适合临时测试、手动部署
- **限制**：Token 过期后需要重新生成
- **安全性**：不要将 Token 提交到代码仓库

---

## 方法二：GitHub API 生成（推荐用于生产环境）

### 前置准备：创建 Personal Access Token

#### 步骤 1：访问 Token 设置页面

访问：https://github.com/settings/tokens

或者：
1. 点击右上角头像 -> **Settings**
2. 左侧菜单最下方 -> **Developer settings**
3. 点击 **Personal access tokens** -> **Tokens (classic)**

#### 步骤 2：生成新 Token

1. 点击 **Generate new token** -> **Generate new token (classic)**
2. 填写 Token 描述，例如：`Runner Token Generator`
3. 选择过期时间：
   - 测试环境：30 days
   - 生产环境：No expiration（需要定期轮换）

#### 步骤 3：选择权限范围

**仓库级别 Runner 需要的权限：**
- ✅ `repo` - Full control of private repositories
  - ✅ `repo:status`
  - ✅ `repo_deployment`
  - ✅ `public_repo`
  - ✅ `repo:invite`
  - ✅ `security_events`

**组织级别 Runner 需要的权限：**
- ✅ `admin:org` - Full control of orgs and teams
  - ✅ `write:org`
  - ✅ `read:org`
  - ✅ `manage_runners:org`

#### 步骤 4：生成并保存 Token

1. 点击页面底部的 **Generate token**
2. **立即复制并保存** Token（离开页面后无法再次查看）
3. 建议保存到密码管理器中

### 使用 API 生成 Runner Token

#### 仓库级别

```bash
# 设置变量
export GITHUB_PAT="ghp_xxxxxxxxxxxxxxxxxxxx"  # 你的 Personal Access Token
export REPO_OWNER="your-org"
export REPO_NAME="your-repo"

# 生成 Runner Token
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token
```

#### 组织级别

```bash
# 设置变量
export GITHUB_PAT="ghp_xxxxxxxxxxxxxxxxxxxx"
export ORG_NAME="your-org"

# 生成 Runner Token
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/${ORG_NAME}/actions/runners/registration-token
```

#### 响应示例

```json
{
  "token": "AXXXXXXXXXXXXXXXXXXXXX",
  "expires_at": "2024-01-15T16:00:00.000Z"
}
```

#### 提取 Token

使用 `jq` 工具提取 Token：

```bash
RUNNER_TOKEN=$(curl -s -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token \
  | jq -r '.token')

echo "Runner Token: ${RUNNER_TOKEN}"
```

---

## 方法三：使用 GitHub CLI

### 安装 GitHub CLI

**macOS:**
```bash
brew install gh
```

**Ubuntu/Debian:**
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

**其他系统：**
参考官方文档：https://github.com/cli/cli#installation

### 使用 GitHub CLI 生成 Token

#### 步骤 1：登录

```bash
gh auth login
```

按照提示选择：
1. GitHub.com
2. HTTPS
3. Login with a web browser（或使用 Token）

#### 步骤 2：生成 Runner Token

**仓库级别：**
```bash
gh api -X POST repos/OWNER/REPO/actions/runners/registration-token | jq -r '.token'
```

**组织级别：**
```bash
gh api -X POST orgs/ORG/actions/runners/registration-token | jq -r '.token'
```

#### 步骤 3：直接保存到变量

```bash
# 仓库级别
export RUNNER_TOKEN=$(gh api -X POST repos/your-org/your-repo/actions/runners/registration-token | jq -r '.token')

# 组织级别
export RUNNER_TOKEN=$(gh api -X POST orgs/your-org/actions/runners/registration-token | jq -r '.token')

echo "RUNNER_TOKEN=${RUNNER_TOKEN}"
```

---

## 自动化脚本示例

### 脚本 1：生成并更新 .env 文件

创建文件 `docker/generate-token.sh`：

```bash
#!/bin/bash

set -e

# 配置区域 - 请修改为你的实际值
GITHUB_PAT="ghp_xxxxxxxxxxxxxxxxxxxx"  # 你的 Personal Access Token
REPO_OWNER="your-org"                   # 仓库所有者
REPO_NAME="your-repo"                   # 仓库名称
ENV_FILE=".env"                         # .env 文件路径

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}正在生成 GitHub Runner Token...${NC}"

# 调用 GitHub API 生成 Token
RESPONSE=$(curl -s -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token)

# 检查是否成功
if [ $? -ne 0 ]; then
    echo -e "${RED}错误：API 调用失败${NC}"
    exit 1
fi

# 提取 Token 和过期时间
RUNNER_TOKEN=$(echo $RESPONSE | jq -r '.token')
EXPIRES_AT=$(echo $RESPONSE | jq -r '.expires_at')

# 检查 Token 是否有效
if [ "$RUNNER_TOKEN" == "null" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo -e "${RED}错误：无法获取 Token${NC}"
    echo "响应内容："
    echo $RESPONSE | jq .
    exit 1
fi

echo -e "${GREEN}✓ Token 生成成功${NC}"
echo "Token: ${RUNNER_TOKEN}"
echo "过期时间: ${EXPIRES_AT}"

# 更新 .env 文件
if [ -f "$ENV_FILE" ]; then
    # 备份原文件
    cp "$ENV_FILE" "${ENV_FILE}.bak"
    echo -e "${YELLOW}已备份原 .env 文件到 ${ENV_FILE}.bak${NC}"

    # 更新 RUNNER_TOKEN
    if grep -q "^RUNNER_TOKEN=" "$ENV_FILE"; then
        # 如果存在，则替换
        sed -i.tmp "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
        rm -f "${ENV_FILE}.tmp"
        echo -e "${GREEN}✓ 已更新 ${ENV_FILE} 中的 RUNNER_TOKEN${NC}"
    else
        # 如果不存在，则添加
        echo "RUNNER_TOKEN=${RUNNER_TOKEN}" >> "$ENV_FILE"
        echo -e "${GREEN}✓ 已添加 RUNNER_TOKEN 到 ${ENV_FILE}${NC}"
    fi
else
    # 如果 .env 不存在，从模板创建
    if [ -f ".env.example" ]; then
        cp .env.example "$ENV_FILE"
        sed -i.tmp "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
        rm -f "${ENV_FILE}.tmp"
        echo -e "${GREEN}✓ 已从模板创建 ${ENV_FILE} 并设置 RUNNER_TOKEN${NC}"
    else
        echo -e "${RED}错误：${ENV_FILE} 和 .env.example 都不存在${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ 完成！${NC}"
echo ""
echo "下一步："
echo "1. 检查 ${ENV_FILE} 文件中的其他配置"
echo "2. 运行: docker-compose up -d"
```

使用方法：

```bash
cd docker
chmod +x generate-token.sh
./generate-token.sh
```

### 脚本 2：使用 GitHub CLI 的简化版本

创建文件 `docker/generate-token-cli.sh`：

```bash
#!/bin/bash

set -e

# 配置
REPO="your-org/your-repo"  # 格式: owner/repo
ENV_FILE=".env"

echo "正在生成 Runner Token..."

# 使用 GitHub CLI 生成 Token
RUNNER_TOKEN=$(gh api -X POST repos/${REPO}/actions/runners/registration-token | jq -r '.token')

if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" == "null" ]; then
    echo "错误：无法生成 Token"
    echo "请确保："
    echo "1. 已安装并登录 GitHub CLI (gh auth login)"
    echo "2. 有权限访问仓库"
    exit 1
fi

echo "✓ Token 生成成功: ${RUNNER_TOKEN}"

# 更新 .env 文件
if [ -f "$ENV_FILE" ]; then
    sed -i.bak "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
    echo "✓ 已更新 ${ENV_FILE}"
else
    cp .env.example "$ENV_FILE"
    sed -i.bak "s|^RUNNER_TOKEN=.*|RUNNER_TOKEN=${RUNNER_TOKEN}|" "$ENV_FILE"
    echo "✓ 已创建 ${ENV_FILE}"
fi

echo "完成！现在可以运行: docker-compose up -d"
```

### 脚本 3：定时刷新 Token（用于长期运行）

创建文件 `docker/refresh-token-cron.sh`：

```bash
#!/bin/bash

# 此脚本用于定时刷新 Runner Token
# 建议每 30 分钟运行一次（Token 有效期 1 小时）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 生成新 Token
./generate-token.sh

# 重启 Docker 容器以使用新 Token
if docker-compose ps | grep -q "github-actions-runner"; then
    echo "重启 Runner 容器..."
    docker-compose restart
    echo "✓ Runner 已重启"
fi
```

添加到 crontab：

```bash
# 编辑 crontab
crontab -e

# 添加以下行（每 30 分钟执行一次）
*/30 * * * * /path/to/ha-cicd-worker/docker/refresh-token-cron.sh >> /var/log/runner-token-refresh.log 2>&1
```

---

## 常见问题

### Q1: Token 过期了怎么办？

**A:** Runner Token 有效期为 1 小时，但有以下几种情况：

1. **Runner 已成功注册**：即使 Token 过期，已注册的 Runner 仍然可以正常工作
2. **需要注册新 Runner**：重新生成一个新的 Token
3. **自动化场景**：使用上面的定时刷新脚本

### Q2: 如何验证 Token 是否有效？

**A:** 可以尝试使用 Token 注册 Runner：

```bash
cd docker
docker-compose up
```

查看日志，如果看到 "Successfully added the runner" 说明 Token 有效。

### Q3: Personal Access Token 和 Runner Token 有什么区别？

**A:**

| 特性 | Personal Access Token | Runner Token |
|------|----------------------|--------------|
| 用途 | 调用 GitHub API | 注册 Runner |
| 有效期 | 可自定义（最长无限期） | 固定 1 小时 |
| 权限范围 | 可精细控制 | 仅用于 Runner 注册 |
| 使用次数 | 可重复使用 | 一次性使用 |

### Q4: 如何在 CI/CD 中安全地使用 Token？

**A:** 使用 GitHub Secrets：

1. 在仓库设置中添加 Secret：`Settings` -> `Secrets and variables` -> `Actions`
2. 添加 `RUNNER_TOKEN_PAT`（存储 Personal Access Token）
3. 在 Workflow 中使用：

```yaml
- name: Generate Runner Token
  run: |
    RUNNER_TOKEN=$(curl -s -L \
      -X POST \
      -H "Authorization: Bearer ${{ secrets.RUNNER_TOKEN_PAT }}" \
      https://api.github.com/repos/${{ github.repository }}/actions/runners/registration-token \
      | jq -r '.token')
    echo "RUNNER_TOKEN=${RUNNER_TOKEN}" >> $GITHUB_ENV
```

### Q5: 组织级别和仓库级别 Runner 如何选择？

**A:**

**仓库级别 Runner：**
- ✅ 适合单个项目
- ✅ 权限隔离更好
- ✅ 配置简单
- ❌ 需要为每个仓库单独配置

**组织级别 Runner：**
- ✅ 可被组织内多个仓库共享
- ✅ 统一管理
- ✅ 资源利用率高
- ❌ 需要组织管理员权限

### Q6: Token 泄露了怎么办？

**A:**

1. **立即删除 Runner**：在 GitHub Settings -> Actions -> Runners 中删除
2. **撤销 Personal Access Token**：在 https://github.com/settings/tokens 中删除
3. **生成新的 Token**：按照本文档重新生成
4. **检查日志**：查看是否有异常活动
5. **更新密钥**：如果使用了 GitHub Secrets，更新相关密钥

### Q7: 如何批量部署多个 Runner？

**A:** 使用脚本循环生成：

```bash
#!/bin/bash

for i in {1..5}; do
    RUNNER_TOKEN=$(gh api -X POST repos/your-org/your-repo/actions/runners/registration-token | jq -r '.token')

    docker run -d \
      --name "runner-${i}" \
      -e RUNNER_TOKEN="${RUNNER_TOKEN}" \
      -e RUNNER_NAME="runner-${i}" \
      -e RUNNER_REPO_URL="https://github.com/your-org/your-repo" \
      github-runner

    echo "✓ Runner ${i} 已启动"
    sleep 2
done
```

---

## 参考资料

- [GitHub Actions Self-Hosted Runners 官方文档](https://docs.github.com/en/actions/hosting-your-own-runners)
- [GitHub REST API - Actions Runners](https://docs.github.com/en/rest/actions/self-hosted-runners)
- [GitHub CLI 官方文档](https://cli.github.com/manual/)
- [Personal Access Tokens 管理](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

---

## 总结

| 方法 | 难度 | 适用场景 | 推荐指数 |
|------|------|---------|---------|
| 网页界面 | ⭐ | 测试、临时使用 | ⭐⭐⭐ |
| GitHub API | ⭐⭐⭐ | 生产环境、自动化 | ⭐⭐⭐⭐⭐ |
| GitHub CLI | ⭐⭐ | 命令行操作、脚本 | ⭐⭐⭐⭐ |

**建议：**
- 🧪 **测试环境**：使用网页界面快速获取
- 🚀 **生产环境**：使用 API + 自动化脚本
- 🔄 **长期运行**：配置定时刷新脚本
- 🔒 **安全第一**：使用 GitHub Secrets 存储敏感信息

