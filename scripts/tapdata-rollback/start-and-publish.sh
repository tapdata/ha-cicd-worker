#!/usr/bin/env bash
# Restore task attrs, start previously-running tasks, and publish previously-active APIs after rollback
# Required env vars: TAPDATA_TOKEN, TARGET_ENV
# Optional env vars: STOPPED_TASKS_FILE (JSON with id, attrs, status)
#                    UNPUBLISHED_APIS_FILE (JSON with id, status, tableName)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CONF="${SCRIPT_DIR}/../../conf/env.conf"

echo "=== Starting Tasks and Publishing APIs ==="

# Read base URL from env.conf
BASE_URL=$(grep "^${TARGET_ENV}=" "${ENV_CONF}" | cut -d'=' -f2-)
if [[ -z "${BASE_URL}" ]]; then
  echo "::error::No base URL configured for environment '${TARGET_ENV}' in env.conf"
  exit 1
fi

API_BASE="${BASE_URL%/}/api"

# ── Step 1: Restore task attrs ──
if [[ -n "${STOPPED_TASKS_FILE:-}" && -f "${STOPPED_TASKS_FILE}" ]]; then
  TASK_COUNT=$(jq 'length' "${STOPPED_TASKS_FILE}")
  echo "Restoring attrs for ${TASK_COUNT} task(s)..."

  while IFS= read -r item; do
    TASK_ID=$(echo "${item}" | jq -r '.id')
    ATTRS=$(echo "${item}" | jq -c '.attrs')

    echo "  Updating attrs for task: ${TASK_ID}..."

    PAYLOAD=$(jq -n -c --argjson attrs "${ATTRS}" '{attrs: $attrs}')
    PATCH_URL="${API_BASE}/task/${TASK_ID}?access_token=${TAPDATA_TOKEN}"

    RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${PATCH_URL}" \
      -H "Content-Type: application/json" \
      -d "${PAYLOAD}")

    HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
    BODY=$(echo "${RESPONSE}" | sed '$d')

    if [[ "${HTTP_CODE}" -ne 200 ]]; then
      echo "::error::Failed to update attrs for task '${TASK_ID}': HTTP ${HTTP_CODE} - ${BODY}"
      exit 1
    fi

    echo "  Task '${TASK_ID}' attrs updated successfully"
  done < <(jq -c '.[]' "${STOPPED_TASKS_FILE}")

  echo "All task attrs restored successfully"
else
  echo "No stopped tasks file provided or file not found, skipping attrs restore"
fi

# ── Step 2: Start previously-running tasks ──
if [[ -n "${STOPPED_TASKS_FILE:-}" && -f "${STOPPED_TASKS_FILE}" ]]; then
  RUNNING_IDS=$(jq -r '[.[] | select(.status == "running") | .id] | join("\n")' "${STOPPED_TASKS_FILE}")
  RUNNING_COUNT=$(jq '[.[] | select(.status == "running")] | length' "${STOPPED_TASKS_FILE}")

  if [[ "${RUNNING_COUNT}" -eq 0 ]]; then
    echo "No previously-running tasks found, skipping batch start"
  else
    echo "Starting ${RUNNING_COUNT} previously-running task(s)..."

    TASK_IDS_PARAMS=""
    while IFS= read -r tid; do
      if [[ -z "${tid}" ]]; then continue; fi
      if [[ -n "${TASK_IDS_PARAMS}" ]]; then
        TASK_IDS_PARAMS="${TASK_IDS_PARAMS}&taskIds=${tid}"
      else
        TASK_IDS_PARAMS="taskIds=${tid}"
      fi
    done <<< "${RUNNING_IDS}"

    START_URL="${API_BASE}/task/batchStart?access_token=${TAPDATA_TOKEN}&${TASK_IDS_PARAMS}"

    RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${START_URL}")
    HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
    BODY=$(echo "${RESPONSE}" | sed '$d')

    if [[ "${HTTP_CODE}" -ne 200 ]]; then
      echo "::error::Failed to batch start tasks: HTTP ${HTTP_CODE} - ${BODY}"
      exit 1
    fi

    echo "All ${RUNNING_COUNT} task(s) started successfully"
  fi
else
  echo "No stopped tasks file provided or file not found, skipping task start"
fi

# ── Step 3: Publish previously-active APIs ──
if [[ -n "${UNPUBLISHED_APIS_FILE:-}" && -f "${UNPUBLISHED_APIS_FILE}" ]]; then
  ACTIVE_APIS=$(jq -c '[.[] | select(.status == "active")]' "${UNPUBLISHED_APIS_FILE}")
  ACTIVE_COUNT=$(echo "${ACTIVE_APIS}" | jq 'length')

  if [[ "${ACTIVE_COUNT}" -eq 0 ]]; then
    echo "No previously-active APIs found, skipping publish"
  else
    echo "Publishing ${ACTIVE_COUNT} previously-active API(s)..."
    PATCH_URL="${API_BASE}/Modules/batchUpdate?access_token=${TAPDATA_TOKEN}"

    while IFS= read -r item; do
      API_ID=$(echo "${item}" | jq -r '.id')
      TABLE_NAME=$(echo "${item}" | jq -r '.tableName')

      echo "  Publishing API: ${TABLE_NAME} (id: ${API_ID})..."

      PAYLOAD=$(jq -n -c \
        --arg id "${API_ID}" \
        --arg tableName "${TABLE_NAME}" \
        '{id: $id, status: "active", tableName: $tableName}')

      RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${PATCH_URL}" \
        -H "Content-Type: application/json" \
        -d "${PAYLOAD}")

      HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
      BODY=$(echo "${RESPONSE}" | sed '$d')

      if [[ "${HTTP_CODE}" -ne 200 ]]; then
        echo "::error::Failed to publish API '${TABLE_NAME}': HTTP ${HTTP_CODE} - ${BODY}"
        exit 1
      fi

      RESP_CODE=$(echo "${BODY}" | jq -r '.code // empty')
      if [[ -n "${RESP_CODE}" && "${RESP_CODE}" != "ok" ]]; then
        echo "::error::Failed to publish API '${TABLE_NAME}': response code '${RESP_CODE}' - ${BODY}"
        exit 1
      fi

      echo "  API '${TABLE_NAME}' published successfully"
    done < <(echo "${ACTIVE_APIS}" | jq -c '.[]')

    echo "All ${ACTIVE_COUNT} API(s) published successfully"
  fi
else
  echo "No unpublished APIs file provided or file not found, skipping API publish"
fi

echo "=== Start and Publish Complete ==="

