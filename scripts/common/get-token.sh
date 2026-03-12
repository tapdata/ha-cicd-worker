#!/usr/bin/env bash
# Get TapData access token via authentication API
# Required env vars: TARGET_ENV, TAPDATA_ACCESSCODE
# Output: tapdata_token (via GITHUB_OUTPUT)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CONF="${SCRIPT_DIR}/../../conf/env.conf"

echo "=== Getting TapData Token ==="

# Validate required env vars
if [[ -z "${TARGET_ENV:-}" ]]; then
  echo "::error::TARGET_ENV is not set or empty"
  exit 1
fi

if [[ -z "${TAPDATA_ACCESSCODE:-}" ]]; then
  echo "::error::TAPDATA_ACCESSCODE is not set or empty"
  exit 1
fi

# Read base URL from conf/env.conf
if [[ ! -f "${ENV_CONF}" ]]; then
  echo "::error::env.conf not found at ${ENV_CONF}"
  exit 1
fi

BASE_URL=$(grep "^${TARGET_ENV}=" "${ENV_CONF}" | cut -d'=' -f2-)

if [[ -z "${BASE_URL}" ]]; then
  echo "::error::No base URL configured for environment '${TARGET_ENV}' in env.conf"
  exit 1
fi

# Build full API URL
API_URL="${BASE_URL%/}/api/users/generatetoken"

echo "Target environment: ${TARGET_ENV}"
echo "API URL: ${API_URL}"

# Build request body
REQUEST_BODY=$(jq -n --arg code "${TAPDATA_ACCESSCODE}" '{accesscode: $code}')

# Call token API
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}" \
  -H "Content-Type: application/json" \
  -d "${REQUEST_BODY}")

HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
BODY=$(echo "${RESPONSE}" | sed '$d')

if [[ "${HTTP_CODE}" -ne 200 ]]; then
  echo "::error::Token API returned HTTP ${HTTP_CODE}: ${BODY}"
  exit 1
fi

# Extract token from response
TOKEN=$(echo "${BODY}" | jq -r '.id // empty')

if [[ -z "${TOKEN}" ]]; then
  echo "::error::Failed to extract token from response: ${BODY}"
  exit 1
fi

# Mask token in logs and set output
echo "::add-mask::${TOKEN}"
echo "tapdata_token=${TOKEN}" >> "${GITHUB_OUTPUT}"
echo "=== Token Retrieved Successfully ==="

