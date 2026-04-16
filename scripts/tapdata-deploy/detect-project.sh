#!/usr/bin/env bash
set -euo pipefail

# 检测 PROJECT 参数
# 输入环境变量：EVENT_NAME, INPUT_PROJECT, GITHUB_OUTPUT, GITHUB_ENV
# 逻辑：
#   - workflow_dispatch: 使用手动输入的 project
#   - push: 从 git diff 变更文件路径中提取 {project}_tapdata_export 前缀
#   - 兜底默认: dmp

if [[ "${EVENT_NAME}" == "workflow_dispatch" ]]; then
  PROJECT="${INPUT_PROJECT}"
elif [[ "${EVENT_NAME}" == "push" ]]; then
  PROJECT=$(git diff HEAD~1 --name-only | grep '_tapdata_export/' | head -1 | sed 's/_tapdata_export\/.*//' | sed 's|.*/||')
fi

PROJECT="${PROJECT:-dmp}"

echo "Detected PROJECT: $PROJECT"
echo "project=$PROJECT" >> "$GITHUB_OUTPUT"
echo "PROJECT=$PROJECT" >> "$GITHUB_ENV"
