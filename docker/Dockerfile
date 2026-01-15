FROM ubuntu:22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_VERSION=2.311.0 \
    RUNNER_HOME=/home/runner \
    RUNNER_WORK=/home/runner/_work

# 安装必要的依赖
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    jq \
    tar \
    sudo \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    libicu70 \
    liblttng-ust1 \
    libkrb5-3 \
    zlib1g \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# 创建 runner 用户
RUN useradd -m -s /bin/bash runner && \
    usermod -aG sudo runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 切换到 runner 用户
USER runner
WORKDIR ${RUNNER_HOME}

# 下载并安装 GitHub Actions Runner
RUN curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# 安装 Python 依赖（如果项目有 requirements.txt）
COPY --chown=runner:runner ../requirements.txt ${RUNNER_HOME}/requirements.txt
RUN pip3 install --user -r ${RUNNER_HOME}/requirements.txt

# 创建启动脚本
COPY --chown=runner:runner <<'EOF' ${RUNNER_HOME}/start.sh
#!/bin/bash
set -e

# 检查必需的环境变量
if [ -z "${RUNNER_TOKEN}" ]; then
    echo "错误: RUNNER_TOKEN 环境变量未设置"
    exit 1
fi

if [ -z "${RUNNER_REPO_URL}" ]; then
    echo "错误: RUNNER_REPO_URL 环境变量未设置"
    echo "示例: https://github.com/your-org/your-repo"
    exit 1
fi

# 设置默认值
RUNNER_NAME=${RUNNER_NAME:-"docker-runner-$(hostname)"}
RUNNER_LABELS=${RUNNER_LABELS:-"self-hosted,Linux,X64"}
RUNNER_WORK_DIR=${RUNNER_WORK_DIR:-"_work"}

echo "配置 GitHub Actions Runner..."
echo "仓库: ${RUNNER_REPO_URL}"
echo "名称: ${RUNNER_NAME}"
echo "标签: ${RUNNER_LABELS}"

# 配置 runner
./config.sh \
    --url "${RUNNER_REPO_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --work "${RUNNER_WORK_DIR}" \
    --unattended \
    --replace

# 清理函数
cleanup() {
    echo "正在移除 runner..."
    ./config.sh remove --token "${RUNNER_TOKEN}"
}

# 捕获退出信号
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# 启动 runner
echo "启动 GitHub Actions Runner..."
./run.sh & wait $!
EOF

RUN chmod +x ${RUNNER_HOME}/start.sh

# 暴露工作目录
VOLUME ${RUNNER_WORK}

# 启动命令
CMD ["./start.sh"]

