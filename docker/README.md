# GitHub Actions Self-Hosted Runner Docker

## 📁 目录说明

此目录包含用于构建和运行 GitHub Actions Self-Hosted Runner 的 Docker 相关文件。

## 📦 文件列表

- `Dockerfile` - Docker 镜像构建文件
- `docker-compose.yml` - Docker Compose 配置文件
- `.env.example` - 环境变量配置模板
- `README.md` - 本文档

## 🚀 快速开始

### 1. 配置环境变量

```bash
cd docker
cp .env.example .env
```

编辑 `.env` 文件，填写你的配置：

```bash
RUNNER_TOKEN=你的GitHub_Runner_Token
RUNNER_REPO_URL=https://github.com/your-org/your-repo
RUNNER_NAME=docker-runner
```

### 2. 启动 Runner

```bash
docker-compose up -d
```

### 3. 查看日志

```bash
docker-compose logs -f
```

### 4. 停止 Runner

```bash
docker-compose down
```

## 📚 详细文档

完整的使用文档请参考：[Docker Runner 详细文档](../docs/docker-runner-README.md)

## 🔧 配置说明

### 必需环境变量

- `RUNNER_TOKEN` - GitHub Runner 注册 Token
- `RUNNER_REPO_URL` - GitHub 仓库 URL

### 可选环境变量

- `RUNNER_NAME` - Runner 名称（默认: docker-runner）
- `RUNNER_LABELS` - Runner 标签（默认: self-hosted,Linux,X64,docker）
- `RUNNER_WORK_DIR` - 工作目录（默认: _work）

## 🛠️ 镜像特性

- **基础镜像**: Ubuntu 22.04
- **Runner 版本**: 2.311.0
- **Python**: Python 3.10+
- **预装工具**: git, curl, wget, jq, pip
- **自动安装**: 项目 requirements.txt 依赖

## 📖 如何生成 Runner Token

### 方法一：通过 GitHub 网页界面获取（推荐用于测试）

#### 仓库级别的 Runner Token

1. 打开你的 GitHub 仓库页面
2. 点击仓库顶部的 `Settings`（设置）标签
3. 在左侧菜单中找到 `Actions` -> `Runners`
4. 点击右上角的 `New self-hosted runner` 按钮
5. 选择操作系统：`Linux`
6. 选择架构：`x64`
7. 在 "Configure" 部分，你会看到类似这样的命令：
   ```bash
   ./config.sh --url https://github.com/your-org/your-repo --token AXXXXXXXXXXXXXXXXXXXXX
   ```
8. 复制 `--token` 后面的 Token（以 `A` 开头的长字符串）

**注意**：这个 Token 有效期为 **1 小时**，适合临时测试使用。

#### 组织级别的 Runner Token

1. 打开你的 GitHub 组织页面
2. 点击 `Settings`
3. 在左侧菜单中找到 `Actions` -> `Runners`
4. 点击 `New runner` -> `New self-hosted runner`
5. 后续步骤同上

### 方法二：通过 GitHub API 生成（推荐用于生产环境）

使用 GitHub API 可以生成长期有效的 Runner Token，适合自动化部署。

#### 前置条件

需要创建一个 GitHub Personal Access Token (PAT)：

1. 访问 GitHub 设置：https://github.com/settings/tokens
2. 点击 `Generate new token` -> `Generate new token (classic)`
3. 设置 Token 名称，例如：`runner-token-generator`
4. 选择过期时间（建议选择较长时间或 `No expiration`）
5. 勾选以下权限：
   - 仓库级别：`repo` (Full control of private repositories)
   - 组织级别：`admin:org` -> `manage_runners:org`
6. 点击 `Generate token` 并保存生成的 Token

#### 使用 API 生成 Runner Token

**仓库级别：**

```bash
# 设置变量
GITHUB_TOKEN="your_personal_access_token"
REPO_OWNER="your-org"
REPO_NAME="your-repo"

# 生成 Runner Token
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token
```

**组织级别：**

```bash
# 设置变量
GITHUB_TOKEN="your_personal_access_token"
ORG_NAME="your-org"

# 生成 Runner Token
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/${ORG_NAME}/actions/runners/registration-token
```

**响应示例：**

```json
{
  "token": "AXXXXXXXXXXXXXXXXXXXXX",
  "expires_at": "2024-01-15T16:00:00.000Z"
}
```

#### 创建自动化脚本

创建一个脚本 `generate-runner-token.sh`：

```bash
#!/bin/bash

# 配置
GITHUB_TOKEN="your_personal_access_token"
REPO_OWNER="your-org"
REPO_NAME="your-repo"

# 生成 Token
RESPONSE=$(curl -s -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token)

# 提取 Token
RUNNER_TOKEN=$(echo $RESPONSE | jq -r '.token')
EXPIRES_AT=$(echo $RESPONSE | jq -r '.expires_at')

echo "Runner Token: ${RUNNER_TOKEN}"
echo "Expires At: ${EXPIRES_AT}"

# 自动更新 .env 文件
sed -i.bak "s/RUNNER_TOKEN=.*/RUNNER_TOKEN=${RUNNER_TOKEN}/" .env
echo ".env 文件已更新"
```

使用方法：

```bash
chmod +x generate-runner-token.sh
./generate-runner-token.sh
```

### 方法三：使用 GitHub CLI (gh)

如果你安装了 GitHub CLI：

```bash
# 安装 GitHub CLI (如果未安装)
# macOS: brew install gh
# Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md

# 登录
gh auth login

# 生成 Runner Token (仓库级别)
gh api -X POST repos/OWNER/REPO/actions/runners/registration-token | jq -r '.token'

# 生成 Runner Token (组织级别)
gh api -X POST orgs/ORG/actions/runners/registration-token | jq -r '.token'
```

### Token 有效期说明

| 获取方式 | 有效期 | 适用场景 |
|---------|--------|---------|
| 网页界面 | 1 小时 | 临时测试、手动部署 |
| GitHub API | 1 小时 | 自动化脚本、定期刷新 |
| GitHub CLI | 1 小时 | 命令行操作、脚本集成 |

**重要提示**：
- Runner Token 有效期为 1 小时，但 Runner 注册后会获得长期凭证
- 一旦 Runner 成功注册，即使 Token 过期也不影响已注册的 Runner
- 如需添加新的 Runner，需要重新生成 Token
- 建议在生产环境中使用自动化脚本定期刷新 Token

## 🔍 故障排查

查看容器日志：
```bash
docker-compose logs -f
```

重启容器：
```bash
docker-compose restart
```

重新构建镜像：
```bash
docker-compose build --no-cache
docker-compose up -d
```

