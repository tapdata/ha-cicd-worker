#!/usr/bin/env bash
# Unpublish TapData APIs for rollback
# 1. Query API ids and tableNames via GET /api/Modules
# 2. Unpublish each API via PATCH /api/Modules
# Required env vars: TAPDATA_TOKEN, TARGET_ENV
# Optional env vars: API_NAMES (comma separated, if empty unpublishes all APIs)
# Output: unpublished_api_ids (comma separated, via GITHUB_OUTPUT)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CONF="${SCRIPT_DIR}/../../conf/env.conf"

echo "=== Unpublishing APIs ==="

# Read base URL from env.conf
BASE_URL=$(grep "^${TARGET_ENV}=" "${ENV_CONF}" | cut -d'=' -f2-)
if [[ -z "${BASE_URL}" ]]; then
  echo "::error::No base URL configured for environment '${TARGET_ENV}' in env.conf"
  exit 1
fi

API_BASE="${BASE_URL%/}/api"

# ── Step 1: Build filter and query API ids and tableNames ──
if [[ -n "${API_NAMES:-}" ]]; then
  echo "Mode: unpublish specified APIs"

  IFS=',' read -ra RAW_APIS <<< "${API_NAMES}"
  TRIMMED_APIS=()
  for api in "${RAW_APIS[@]}"; do
    trimmed=$(echo "${api}" | xargs)
    if [[ -n "${trimmed}" ]]; then
      TRIMMED_APIS+=("${trimmed}")
    fi
  done

  if [[ ${#TRIMMED_APIS[@]} -eq 0 ]]; then
    echo "::error::No valid API names provided"
    exit 1
  fi

  INQ_ARRAY=$(printf '%s\n' "${TRIMMED_APIS[@]}" | jq -R . | jq -s .)
  FILTER=$(jq -n -c --argjson inq "${INQ_ARRAY}" '{
    "fields": {"id": true, "tableName": true},
    "where": {"name": {"$inq": $inq}}
  }')

  echo "Querying API IDs for: ${TRIMMED_APIS[*]}"
else
  echo "Mode: unpublish all APIs"
  FILTER=$(jq -n -c '{"fields": {"id": true, "tableName": true}}')
  echo "Querying all APIs..."
fi

ENCODED_FILTER=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "${FILTER}")
QUERY_URL="${API_BASE}/Modules?access_token=${TAPDATA_TOKEN}&filter=${ENCODED_FILTER}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${QUERY_URL}")
HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
BODY=$(echo "${RESPONSE}" | sed '$d')

if [[ "${HTTP_CODE}" -ne 200 ]]; then
  echo "::error::Failed to query APIs: HTTP ${HTTP_CODE} - ${BODY}"
  exit 1
fi

API_COUNT=$(echo "${BODY}" | jq '.data.items | length')

if [[ "${API_COUNT}" -eq 0 ]]; then
  echo "No APIs found, skipping unpublish"
  echo "unpublished_api_ids=" >> "${GITHUB_OUTPUT}"
  echo "=== Unpublish APIs Complete ==="
  exit 0
fi

echo "Found ${API_COUNT} API(s):"
echo "${BODY}" | jq -r '.data.items[] | "  - \(.tableName) (id: \(.id))"'

# ── Step 2: Unpublish each API ──
PATCH_URL="${API_BASE}/Modules?access_token=${TAPDATA_TOKEN}"

while IFS= read -r item; do
  API_ID=$(echo "${item}" | jq -r '.id')
  TABLE_NAME=$(echo "${item}" | jq -r '.tableName')

  echo "Unpublishing API: ${TABLE_NAME} (id: ${API_ID})..."

  PAYLOAD=$(jq -n -c \
    --arg id "${API_ID}" \
    --arg tableName "${TABLE_NAME}" \
    '{id: $id, tableName: $tableName, status: "pending"}')

  PATCH_RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${PATCH_URL}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}")

  PATCH_HTTP_CODE=$(echo "${PATCH_RESPONSE}" | tail -n1)
  PATCH_BODY=$(echo "${PATCH_RESPONSE}" | sed '$d')

  if [[ "${PATCH_HTTP_CODE}" -ne 200 ]]; then
    echo "::error::Failed to unpublish API '${TABLE_NAME}': HTTP ${PATCH_HTTP_CODE} - ${PATCH_BODY}"
    exit 1
  fi

  RESP_CODE=$(echo "${PATCH_BODY}" | jq -r '.code // empty')
  if [[ "${RESP_CODE}" != "ok" ]]; then
    echo "::error::Failed to unpublish API '${TABLE_NAME}': response code '${RESP_CODE}' - ${PATCH_BODY}"
    exit 1
  fi

  echo "  API '${TABLE_NAME}' unpublished successfully"
done < <(echo "${BODY}" | jq -c '.data.items[]')

# Output unpublished API IDs
UNPUBLISHED_IDS=$(echo "${BODY}" | jq -r '[.data.items[].id] | join(",")')
echo "unpublished_api_ids=${UNPUBLISHED_IDS}" >> "${GITHUB_OUTPUT}"

echo "All ${API_COUNT} API(s) unpublished successfully"
echo "=== Unpublish APIs Complete ==="
