#!/usr/bin/env bash
# Validate that the provided rollback tag exists in the repository
# Required env vars: LAST_STABLE_TAG
# Output: last_stable_tag (via GITHUB_OUTPUT)
set -euo pipefail

echo "=== Validating Rollback Tag ==="

if [[ -z "${LAST_STABLE_TAG:-}" ]]; then
  echo "::error::LAST_STABLE_TAG is not set or empty. A rollback tag must be provided."
  exit 1
fi

# Check if the tag exists in the local git repository
if ! git rev-parse "refs/tags/${LAST_STABLE_TAG}" >/dev/null 2>&1; then
  echo "::error::Tag '${LAST_STABLE_TAG}' does not exist in the repository."
  exit 1
fi

echo "Tag '${LAST_STABLE_TAG}' exists, using it for rollback."
echo "last_stable_tag=${LAST_STABLE_TAG}" >> "${GITHUB_OUTPUT}"
echo "=== Tag Validation Complete ==="

