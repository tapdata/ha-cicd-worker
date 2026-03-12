#!/usr/bin/env bash
# Validate rollback input parameters
# Required env vars: TARGET_ENV
# Optional env vars: LAST_STABLE_TAG
set -euo pipefail

VALID_ENVS=("dev" "sit" "lpt" "aat" "prod")

echo "=== Validating Rollback Input Parameters ==="

# Validate TARGET_ENV
if [[ -z "${TARGET_ENV:-}" ]]; then
  echo "::error::TARGET_ENV is not set or empty"
  exit 1
fi

# Check TARGET_ENV is a valid environment
valid=false
for env in "${VALID_ENVS[@]}"; do
  if [[ "${TARGET_ENV}" == "${env}" ]]; then
    valid=true
    break
  fi
done

if [[ "${valid}" != "true" ]]; then
  echo "::error::TARGET_ENV '${TARGET_ENV}' is not valid. Allowed values: ${VALID_ENVS[*]}"
  exit 1
fi

# Validate LAST_STABLE_TAG format if provided
if [[ -n "${LAST_STABLE_TAG:-}" ]]; then
  # Tag should match semver-like pattern, e.g. v1.0.0 or 1.0.0
  if [[ ! "${LAST_STABLE_TAG}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "::error::LAST_STABLE_TAG '${LAST_STABLE_TAG}' does not match expected tag format (e.g. v1.0.0)"
    exit 1
  fi
  echo "LAST_STABLE_TAG: ${LAST_STABLE_TAG}"
else
  echo "LAST_STABLE_TAG: (not provided, will auto-detect)"
fi

echo "TARGET_ENV:      ${TARGET_ENV}"
echo "=== Validation Passed ==="

