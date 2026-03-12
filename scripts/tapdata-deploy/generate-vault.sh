#!/usr/bin/env bash
# Generate vault.json with connection secrets from GitHub Secrets
# Required env vars: PROJECT, ALL_SECRETS
# ALL_SECRETS comes from ${{ toJSON(secrets) }}
# Naming convention in GitHub Secrets: {CONNECTION_NAME}_HOST, {CONNECTION_NAME}_PORT,
#                                      {CONNECTION_NAME}_USER, {CONNECTION_NAME}_PASSWORD
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
      CONNECTION_NAMES+=("${name}")
      echo "Found connection: ${name} (from ${file})"
    fi
  done < <(jq -r '.[] | select(.collectionName == "Connections") | .name // empty' "${file}")
done < <(find "${CONNECTIONS_DIR}" -name "*Connection_Config.json" -type f)

if [[ ${#CONNECTION_NAMES[@]} -eq 0 ]]; then
  echo "::warning::No connection files found in ${CONNECTIONS_DIR}"
  echo "{}" > "${EXPORT_DIR}/vault.json"
  echo "=== Generated empty vault.json ==="
  exit 0
fi

# Build vault.json from secrets
# For each connection name, extract {NAME}_HOST, {NAME}_PORT, {NAME}_USER, {NAME}_PASSWORD
VAULT_JSON="{}"

for conn_name in "${CONNECTION_NAMES[@]}"; do
  HOST=$(echo "${ALL_SECRETS}" | jq -r --arg k "${conn_name}_host" '.[$k] // empty')
  PORT=$(echo "${ALL_SECRETS}" | jq -r --arg k "${conn_name}_port" '.[$k] // empty')
  USER=$(echo "${ALL_SECRETS}" | jq -r --arg k "${conn_name}_user" '.[$k] // empty')
  PASSWORD=$(echo "${ALL_SECRETS}" | jq -r --arg k "${conn_name}_password" '.[$k] // empty')

  MISSING=()
  [[ -z "${HOST}" ]] && MISSING+=("${conn_name}_host")
  [[ -z "${PORT}" ]] && MISSING+=("${conn_name}_port")
  [[ -z "${USER}" ]] && MISSING+=("${conn_name}_user")
  [[ -z "${PASSWORD}" ]] && MISSING+=("${conn_name}_password")

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "::error::Missing secrets for connection '${conn_name}': ${MISSING[*]}"
    exit 1
  fi

  VAULT_JSON=$(echo "${VAULT_JSON}" | jq \
    --arg host_key "${conn_name}_host" --arg host_val "${HOST}" \
    --arg port_key "${conn_name}_port" --arg port_val "${PORT}" \
    --arg user_key "${conn_name}_user" --arg user_val "${USER}" \
    --arg pass_key "${conn_name}_password" --arg pass_val "${PASSWORD}" \
    '. + {($host_key): $host_val, ($port_key): $port_val, ($user_key): $user_val, ($pass_key): $pass_val}')

  echo "Added secrets for connection: ${conn_name}"
done

# Write vault.json
VAULT_FILE="${EXPORT_DIR}/vault.json"
echo "${VAULT_JSON}" | jq '.' > "${VAULT_FILE}"

echo "vault.json written to ${VAULT_FILE}"
echo "Total connections: ${#CONNECTION_NAMES[@]}"
echo "=== vault.json Generated Successfully ==="
