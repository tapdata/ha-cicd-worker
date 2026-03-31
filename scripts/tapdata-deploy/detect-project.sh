#!/usr/bin/env bash
set -euo pipefail

# 检测 PROJECT 参数
# 输入环境变量：EVENT_NAME, INPUT_PROJECT, GITHUB_OUTPUT, GITHUB_ENV, GITHUB_STEP_SUMMARY
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

# 输出到 Job Summary
echo "### 🔍 Project Detection" >> "$GITHUB_STEP_SUMMARY"
echo "| Key | Value |" >> "$GITHUB_STEP_SUMMARY"
echo "|-----|-------|" >> "$GITHUB_STEP_SUMMARY"
echo "| **Trigger** | \`${EVENT_NAME}\` |" >> "$GITHUB_STEP_SUMMARY"
echo "| **Detected Project** | \`${PROJECT}\` |" >> "$GITHUB_STEP_SUMMARY"
