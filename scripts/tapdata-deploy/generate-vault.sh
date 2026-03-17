#!/usr/bin/env bash
# Generate vault.json with connection secrets from GitHub Secrets and Variables
# Required env vars: PROJECT, ALL_SECRETS, ALL_VARS
# ALL_SECRETS comes from ${{ toJSON(secrets) }}
# ALL_VARS comes from ${{ toJSON(vars) }}
# Naming convention:
#   URI:      {CONNECTION_NAME}_URI in Variables (ALL_VARS)
#   Password: {CONNECTION_NAME}_PASSWORD in Secrets (ALL_SECRETS)
# Fallback: if not found, truncate connection name to prefix before the second underscore
#   e.g. A_B_C_D -> A_B, then retry {PREFIX}_URI and {PREFIX}_PASSWORD
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../.."

echo "=== Generating vault.json ==="

# Validate required env vars
if [[ -z "${PROJECT:-}" ]]; then
  echo "::error::PROJECT is not set or empty"
  exit 1
fi

if [[ -z "${ALL_SECRETS:-}" ]]; then
  echo "::error::ALL_SECRETS is not set or empty"
  exit 1
fi

if [[ -z "${ALL_VARS:-}" ]]; then
  echo "::error::ALL_VARS is not set or empty"
  exit 1
fi

# Locate connection files directory
EXPORT_DIR="${REPO_ROOT}/${PROJECT}_tapdata_export"
CONNECTIONS_DIR="${EXPORT_DIR}/Connection"

if [[ ! -d "${CONNECTIONS_DIR}" ]]; then
  echo "::error::Connections directory not found: ${CONNECTIONS_DIR}"
  exit 1
fi

# Scan all *Connection_Config.json files and extract connection names
# Each file is a JSON array; extract name where collectionName == "Connections"
CONNECTION_NAMES=()
while IFS= read -r file; do
  while IFS= read -r name; do
    if [[ -n "${name}" ]]; then
      CONN_NAME_UPPER=$(printf '%s' "${name}" | tr '[:lower:]' '[:upper:]')
      CONNECTION_NAMES+=("${CONN_NAME_UPPER}")
      echo "Found connection: ${name} -> ${CONN_NAME_UPPER} (from ${file})"
    fi
  done < <(jq -r '.[] | select(.collectionName == "Connections") | if (.json | type) == "string" then (.json | fromjson | .name // empty) else (.json | .name // empty) end' "${file}")
done < <(find "${CONNECTIONS_DIR}" -name "*Connection_Config.json" -type f)

if [[ ${#CONNECTION_NAMES[@]} -eq 0 ]]; then
  echo "::warning::No connection files found in ${CONNECTIONS_DIR}"
  echo "{}" > "${EXPORT_DIR}/vault.json"
  echo "=== Generated empty vault.json ==="
  exit 0
fi

# Build vault.json from variables and secrets
# For each uppercase connection name:
#   1. Look up {NAME}_URI in Variables, {NAME}_PASSWORD in Secrets
#   2. If not found, truncate name to prefix before the 2nd underscore (e.g. A_B_C_D -> A_B)
#      then retry {PREFIX}_URI in Variables, {PREFIX}_PASSWORD in Secrets
VAULT_JSON="{}"

# Extract prefix before the second underscore: A_B_C_D -> A_B
get_prefix() {
  local name="$1"
  # Split by underscore, take first two parts
  local part1 part2
  part1=$(echo "${name}" | cut -d'_' -f1)
  part2=$(echo "${name}" | cut -d'_' -f2)
  local parts_count
  parts_count=$(echo "${name}" | awk -F'_' '{print NF}')
  if [[ "${parts_count}" -ge 3 && -n "${part1}" && -n "${part2}" ]]; then
    echo "${part1}_${part2}"
  else
    echo ""
  fi
}

# Try to find URI (from Variables) and PASSWORD (from Secrets) for a given lookup key
# Returns: sets FOUND_URI, FOUND_PASSWORD, FOUND_LOOKUP_KEY
try_lookup() {
  local lookup_key="$1"
  FOUND_URI=$(echo "${ALL_VARS}" | jq -r --arg k "${lookup_key}_URI" '.[$k] // empty')
  FOUND_PASSWORD=$(echo "${ALL_SECRETS}" | jq -r --arg k "${lookup_key}_PASSWORD" '.[$k] // empty')
  FOUND_LOOKUP_KEY="${lookup_key}"
}

for conn_name in "${CONNECTION_NAMES[@]}"; do
  FOUND_URI=""
  FOUND_PASSWORD=""
  FOUND_LOOKUP_KEY=""

  # Step 1: Try with full connection name
  try_lookup "${conn_name}"

  # Step 2: If not found, try with truncated prefix
  if [[ -z "${FOUND_URI}" || -z "${FOUND_PASSWORD}" ]]; then
    PREFIX=$(get_prefix "${conn_name}")
    if [[ -n "${PREFIX}" && "${PREFIX}" != "${conn_name}" ]]; then
      echo "Retrying lookup with prefix: ${PREFIX} (original: ${conn_name})"
      try_lookup "${PREFIX}"
    fi
  fi

  # Validate results
  MISSING=()
  [[ -z "${FOUND_URI}" ]] && MISSING+=("${FOUND_LOOKUP_KEY}_URI (in Variables)")
  [[ -z "${FOUND_PASSWORD}" ]] && MISSING+=("${FOUND_LOOKUP_KEY}_PASSWORD (in Secrets)")

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "::error::Missing config for connection '${conn_name}': ${MISSING[*]}"
    exit 1
  fi

  # Add to vault using the original connection name as key prefix
  VAULT_JSON=$(echo "${VAULT_JSON}" | jq \
    --arg uri_key "${conn_name}_URI" --arg uri_val "${FOUND_URI}" \
    --arg pass_key "${conn_name}_PASSWORD" --arg pass_val "${FOUND_PASSWORD}" \
    '. + {($uri_key): $uri_val, ($pass_key): $pass_val}')

  if [[ "${FOUND_LOOKUP_KEY}" != "${conn_name}" ]]; then
    echo "Added vault for connection: ${conn_name} (matched via prefix ${FOUND_LOOKUP_KEY})"
  else
    echo "Added vault for connection: ${conn_name}"
  fi
done

# Write vault.json
VAULT_FILE="${EXPORT_DIR}/vault.json"
echo "${VAULT_JSON}" | jq '.' > "${VAULT_FILE}"

echo "vault.json written to ${VAULT_FILE}"
echo "Total connections: ${#CONNECTION_NAMES[@]}"
echo "=== vault.json Generated Successfully ==="
