#!/usr/bin/env bash
# Generate vault.json with connection secrets from GitHub Secrets
# Required env vars: PROJECT, ALL_SECRETS
# ALL_SECRETS comes from ${{ toJSON(secrets) }}
# Naming convention in GitHub Secrets:
#   preferred: {CONNECTION_NAME}_URI
#   fallback:  {CONNECTION_NAME}_HOST, {CONNECTION_NAME}_PORT,
#              {CONNECTION_NAME}_USER, {CONNECTION_NAME}_PASSWORD
# vault.json keeps the same uppercase keys, for example:
#   MYSQL_URI
#   MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD
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

# Build vault.json from secrets
# For each uppercase connection name, prefer {NAME}_URI; if absent,
# fallback to {NAME}_HOST, {NAME}_PORT, {NAME}_USER, {NAME}_PASSWORD
VAULT_JSON="{}"

for conn_name in "${CONNECTION_NAMES[@]}"; do
  URI_SECRET_KEY="${conn_name}_URI"
  HOST_SECRET_KEY="${conn_name}_HOST"
  PORT_SECRET_KEY="${conn_name}_PORT"
  USER_SECRET_KEY="${conn_name}_USER"
  PASSWORD_SECRET_KEY="${conn_name}_PASSWORD"

  URI=$(echo "${ALL_SECRETS}" | jq -r --arg k "${URI_SECRET_KEY}" '.[$k] // empty')

  if [[ -n "${URI}" ]]; then
    VAULT_JSON=$(echo "${VAULT_JSON}" | jq \
      --arg uri_key "${URI_SECRET_KEY}" --arg uri_val "${URI}" \
      '. + {($uri_key): $uri_val}')

    echo "Added secrets for connection: ${conn_name} (using ${URI_SECRET_KEY})"
    continue
  fi

  HOST=$(echo "${ALL_SECRETS}" | jq -r --arg k "${HOST_SECRET_KEY}" '.[$k] // empty')
  PORT=$(echo "${ALL_SECRETS}" | jq -r --arg k "${PORT_SECRET_KEY}" '.[$k] // empty')
  USER=$(echo "${ALL_SECRETS}" | jq -r --arg k "${USER_SECRET_KEY}" '.[$k] // empty')
  PASSWORD=$(echo "${ALL_SECRETS}" | jq -r --arg k "${PASSWORD_SECRET_KEY}" '.[$k] // empty')

  MISSING=()
  [[ -z "${HOST}" ]] && MISSING+=("${HOST_SECRET_KEY}")
  [[ -z "${PORT}" ]] && MISSING+=("${PORT_SECRET_KEY}")
  [[ -z "${USER}" ]] && MISSING+=("${USER_SECRET_KEY}")
  [[ -z "${PASSWORD}" ]] && MISSING+=("${PASSWORD_SECRET_KEY}")

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "::error::Missing secrets for connection '${conn_name}': ${MISSING[*]}"
    exit 1
  fi

  VAULT_JSON=$(echo "${VAULT_JSON}" | jq \
    --arg host_key "${HOST_SECRET_KEY}" --arg host_val "${HOST}" \
    --arg port_key "${PORT_SECRET_KEY}" --arg port_val "${PORT}" \
    --arg user_key "${USER_SECRET_KEY}" --arg user_val "${USER}" \
    --arg pass_key "${PASSWORD_SECRET_KEY}" --arg pass_val "${PASSWORD}" \
    '. + {($host_key): $host_val, ($port_key): $port_val, ($user_key): $user_val, ($pass_key): $pass_val}')

  echo "Added secrets for connection: ${conn_name} (host=${HOST}, port=${PORT}, user=${USER})"
done

# Write vault.json
VAULT_FILE="${EXPORT_DIR}/vault.json"
echo "${VAULT_JSON}" | jq '.' > "${VAULT_FILE}"

echo "vault.json written to ${VAULT_FILE}"
echo "Total connections: ${#CONNECTION_NAMES[@]}"
echo "=== vault.json Generated Successfully ==="
