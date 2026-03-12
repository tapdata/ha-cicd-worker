#!/usr/bin/env bash
# Resolve rollback tag: use provided tag or auto-detect latest stable tag
# Required env vars: GITHUB_TOKEN, REPO
# Optional env vars: LAST_STABLE_TAG
# Output: last_stable_tag (via GITHUB_OUTPUT)
set -euo pipefail

echo "=== Resolving Rollback Tag ==="

# If tag is already provided, use it directly
if [[ -n "${LAST_STABLE_TAG:-}" ]]; then
  echo "Using provided tag: ${LAST_STABLE_TAG}"
  echo "last_stable_tag=${LAST_STABLE_TAG}" >> "${GITHUB_OUTPUT}"
  echo "=== Tag Resolution Complete ==="
  exit 0
fi

# Otherwise, auto-detect latest stable tag from GitHub API
echo "No tag provided, auto-detecting latest stable tag..."

# Validate required env vars for auto-detection
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "::error::GITHUB_TOKEN is not set or empty (required for auto-detection)"
  exit 1
fi

if [[ -z "${REPO:-}" ]]; then
  echo "::error::REPO is not set or empty (required for auto-detection)"
  exit 1
fi

# Fetch the latest tag via GitHub API
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/tags?per_page=1")

HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
BODY=$(echo "${RESPONSE}" | sed '$d')

if [[ "${HTTP_CODE}" -ne 200 ]]; then
  echo "::error::GitHub API returned HTTP ${HTTP_CODE}: ${BODY}"
  exit 1
fi

LAST_TAG=$(echo "${BODY}" | jq -r '.[0].name // empty')

if [[ -z "${LAST_TAG}" ]]; then
  echo "::error::No tags found in repository ${REPO}, cannot determine rollback target"
  exit 1
fi

echo "Auto-detected latest stable tag: ${LAST_TAG}"
echo "last_stable_tag=${LAST_TAG}" >> "${GITHUB_OUTPUT}"
echo "=== Tag Resolution Complete ==="

