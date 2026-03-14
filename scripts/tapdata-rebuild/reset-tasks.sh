#!/usr/bin/env bash
# Reset rebuild task state data via TapData API
# Required env vars: TAPDATA_TOKEN, TARGET_ENV, TASK_NAMES, NEED_DROP_TABLE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CONF="${SCRIPT_DIR}/../../conf/env.conf"

echo "=== Resetting Rebuild Tasks ==="

# Read base URL from env.conf
BASE_URL=$(grep "^${TARGET_ENV}=" "${ENV_CONF}" | cut -d'=' -f2-)
if [[ -z "${BASE_URL}" ]]; then
  echo "::error::No base URL configured for environment '${TARGET_ENV}' in env.conf"
  exit 1
fi

# TODO: Replace with actual TapData API endpoint for resetting tasks
API_URL="${BASE_URL%/}/api/"  # TODO: complete the API path

NEED_DROP="${NEED_DROP_TABLE:-false}"
echo "Need drop table: ${NEED_DROP}"

# Parse task names
IFS=',' read -ra TASKS <<< "${TASK_NAMES}"

for task in "${TASKS[@]}"; do
  task=$(echo "${task}" | xargs)
  if [[ -z "${task}" ]]; then
    continue
  fi

  echo "Resetting task: ${task} (drop_table=${NEED_DROP})"

  # TODO: Complete the API call to reset task state data
  # Example:
  # RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${API_URL}" \
  #   -H "Content-Type: application/json" \
  #   -H "access_token: ${TAPDATA_TOKEN}" \
  #   -d "{\"name\": \"${task}\", \"dropTable\": ${NEED_DROP}}")
  #
  # HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
  # BODY=$(echo "${RESPONSE}" | sed '$d')
  #
  # if [[ "${HTTP_CODE}" -ne 200 ]]; then
  #   echo "::error::Failed to reset task '${task}': HTTP ${HTTP_CODE} - ${BODY}"
  #   exit 1
  # fi
  #
  # echo "Task '${task}' reset successfully"

  echo "TODO: Implement reset task API call for '${task}'"
done

echo "=== Reset Tasks Complete ==="

