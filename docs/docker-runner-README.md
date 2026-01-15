# GitHub Actions Self-Hosted Runner Docker 部署指南

## 📖 简介

这是一个基于 Ubuntu 的 GitHub Actions Self-Hosted Runner Docker 镜像，包含 Python3 环境，可以快速部署自托管的 GitHub Actions 运行器。

## 🚀 快速开始

### 1. 获取 Runner Token

详细的 Token 生成方法请参考 [docker/README.md](../docker/README.md#-如何生成-runner-token)

**快速方法（网页界面）：**

1. 访问你的 GitHub 仓库
2. 进入 `Settings` -> `Actions` -> `Runners`
3. 点击 `New self-hosted runner`
4. 选择 `Linux` 平台
5. 复制显示的 Token（以 `A` 开头的长字符串）

**注意**：网页生成的 Token 有效期为 1 小时，适合测试使用。生产环境建议使用 API 方式。

### 2. 配置环境变量

进入 docker 目录并复制环境变量模板文件：

```bash
cd docker
cp .env.example .env
```

编辑 `.env` 文件，填写实际值：

```bash
# 必需参数
RUNNER_TOKEN=AXXXXXXXXXXXXXXXXXXXXX
RUNNER_REPO_URL=https://github.com/your-org/your-repo

# 可选参数
RUNNER_NAME=my-docker-runner
RUNNER_LABELS=self-hosted,Linux,X64,docker
```

### 3. 启动 Runner

使用 Docker Compose 启动：

```bash
docker-compose up -d
```

或者使用 Docker 命令直接启动：

```bash
cd docker
docker build -t github-runner -f Dockerfile ..

docker run -d \
  --name github-actions-runner \
  -e RUNNER_TOKEN="your_token_here" \
  -e RUNNER_REPO_URL="https://github.com/your-org/your-repo" \
  -e RUNNER_NAME="docker-runner" \
  -e RUNNER_LABELS="self-hosted,Linux,X64,docker" \
  github-runner
```

### 4. 验证运行状态

查看容器日志：

```bash
docker-compose logs -f
```

或者：

```bash
docker logs -f github-actions-runner
```

在 GitHub 仓库的 `Settings` -> `Actions` -> `Runners` 页面，应该能看到新注册的 Runner，状态为 `Idle`。

## 🔧 配置说明

### 环境变量

| 变量名 | 必需 | 默认值 | 说明 |
|--------|------|--------|------|
| `RUNNER_TOKEN` | ✅ | - | GitHub Runner 注册 Token |
| `RUNNER_REPO_URL` | ✅ | - | GitHub 仓库 URL |
| `RUNNER_NAME` | ❌ | `docker-runner-{hostname}` | Runner 名称 |
| `RUNNER_LABELS` | ❌ | `self-hosted,Linux,X64` | Runner 标签（逗号分隔） |
| `RUNNER_WORK_DIR` | ❌ | `_work` | 工作目录名称 |

### Dockerfile 特性

- **基础镜像**: Ubuntu 22.04
- **Runner 版本**: 2.311.0（可在 Dockerfile 中修改）
- **Python 版本**: Python 3.10+
- **预装工具**: git, curl, wget, jq, pip
- **自动安装**: 项目的 requirements.txt 依赖

## 📝 使用示例

### 在 Workflow 中使用

创建 `.github/workflows/test.yml`：

```yaml
name: Test Self-Hosted Runner

on: [push]

jobs:
  test:
    runs-on: [self-hosted, Linux, X64, docker]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: 测试 Python 环境
        run: |
          python3 --version
          pip3 --version
      
      - name: 运行 Python 脚本
        run: |
          python3 scripts/tapdata-get-token.py
```

## 🛠️ 高级配置

### 启用 Docker-in-Docker

如果你的 Workflow 需要使用 Docker，需要修改 `docker-compose.yml`：

```yaml
services:
  github-runner:
    # ... 其他配置
    volumes:
      - runner-work:/home/runner/_work
      - /var/run/docker.sock:/var/run/docker.sock  # 挂载 Docker socket
    
    # 可选：如果需要完全的 Docker 权限
    privileged: true
```

然后在 Dockerfile 中添加 Docker 安装：

```dockerfile
# 在 apt-get install 部分添加
RUN apt-get update && apt-get install -y \
    # ... 其他包
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# 将 runner 用户添加到 docker 组
RUN usermod -aG docker runner
```

### 更新 Runner 版本

修改 Dockerfile 中的 `RUNNER_VERSION` 环境变量：

```dockerfile
ENV RUNNER_VERSION=2.311.0
```

查看最新版本：https://github.com/actions/runner/releases

### 多个 Runner 实例

使用 Docker Compose 的 scale 功能：

```bash
docker-compose up -d --scale github-runner=3
```

或者手动启动多个容器：

```bash
docker run -d --name runner-1 -e RUNNER_TOKEN="..." -e RUNNER_NAME="runner-1" github-runner
docker run -d --name runner-2 -e RUNNER_TOKEN="..." -e RUNNER_NAME="runner-2" github-runner
docker run -d --name runner-3 -e RUNNER_TOKEN="..." -e RUNNER_NAME="runner-3" github-runner
```

## 🔍 故障排查

### Runner 无法注册

1. 检查 Token 是否正确且未过期
2. 检查仓库 URL 是否正确
3. 查看容器日志：`docker logs github-actions-runner`

### Runner 频繁重启

1. 检查 Token 是否有效
2. 确认网络连接正常
3. 查看 GitHub 仓库的 Runner 设置

### Python 依赖安装失败

1. 检查 requirements.txt 文件是否存在
2. 确认依赖包名称和版本正确
3. 可能需要添加系统级依赖到 Dockerfile

## 🧹 清理

停止并删除容器：

```bash
docker-compose down
```

删除数据卷：

```bash
docker-compose down -v
```

删除镜像：

```bash
docker rmi github-runner
```

## 📚 参考资料

- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [GitHub Actions Runner Releases](https://github.com/actions/runner/releases)
- [Docker Documentation](https://docs.docker.com/)

