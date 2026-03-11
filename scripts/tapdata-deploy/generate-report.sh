#!/usr/bin/env bash
# Collect deployment results and generate deployment report
# Required env vars: DEPLOY_DIR, DEPLOYMENT_REF, TARGET_ENV, PROJECT,
#   GITHUB_ACTOR, LAST_STABLE_TAG,
#   CHANGED_CONNECTIONS, CHANGED_TASKS, CHANGED_APIS,
#   PREPARATION_RESULT, CONNECTIONS_RESULT, TASKS_RESULT, APIS_RESULT,
#   ROLLBACK_RESULT
set -euo pipefail

echo "=== Generating Deployment Report ==="

mkdir -p "${DEPLOY_DIR}"

# --- Determine overall result ---
if [[ "${CONNECTIONS_RESULT}" == "success" && "${TASKS_RESULT}" == "success" && "${APIS_RESULT}" == "success" ]]; then
  OVERALL_RESULT="SUCCESS"
else
  OVERALL_RESULT="FAILURE"
fi

# --- Rollback info ---
APPROVAL_RESULT="${ROLLBACK_APPROVAL_RESULT:-skipped}"

if [[ "${APPROVAL_RESULT}" == "skipped" ]]; then
  ROLLBACK_TRIGGERED="No"
  ROLLBACK_APPROVAL="Not required"
  ROLLBACK_STATUS="-"
elif [[ "${APPROVAL_RESULT}" == "cancelled" ]]; then
  ROLLBACK_TRIGGERED="Yes (rejected)"
  ROLLBACK_APPROVAL="Rejected"
  ROLLBACK_STATUS="Cancelled"
else
  ROLLBACK_TRIGGERED="Yes"
  ROLLBACK_APPROVAL="Approved"
  if [[ "${ROLLBACK_RESULT}" == "success" ]]; then
    ROLLBACK_STATUS="SUCCESS"
  elif [[ "${ROLLBACK_RESULT}" == "skipped" ]]; then
    ROLLBACK_STATUS="Skipped"
  else
    ROLLBACK_STATUS="FAILURE"
  fi
fi

# --- Count changes from import responses ---
count_changes() {
  local json="${1:-}"
  if [[ -z "${json}" || "${json}" == "null" ]]; then
    echo "0"
    return
  fi
  # Try to count array length, fallback to 0
  local count
  count=$(echo "${json}" | jq 'if type == "array" then length elif .data? then (.data | if type == "array" then length else 1 end) else 1 end' 2>/dev/null || echo "0")
  echo "${count}"
}

CONNECTIONS_COUNT=$(count_changes "${CHANGED_CONNECTIONS:-}")
TASKS_COUNT=$(count_changes "${CHANGED_TASKS:-}")
APIS_COUNT=$(count_changes "${CHANGED_APIS:-}")

# --- Commits between last stable tag and current ref ---
COMMIT_COUNT=0
COMMIT_IDS="-"

if [[ -n "${LAST_STABLE_TAG:-}" ]]; then
  # Check if tag exists in local repo
  if git rev-parse "${LAST_STABLE_TAG}" >/dev/null 2>&1; then
    COMMIT_LOG=$(git log --oneline "${LAST_STABLE_TAG}..HEAD" 2>/dev/null || true)
    if [[ -n "${COMMIT_LOG}" ]]; then
      COMMIT_COUNT=$(echo "${COMMIT_LOG}" | wc -l | tr -d ' ')
      COMMIT_IDS=$(git log --format="%H" "${LAST_STABLE_TAG}..HEAD" 2>/dev/null | paste -sd ',' -)
    fi
  else
    COMMIT_IDS="(tag ${LAST_STABLE_TAG} not found locally)"
  fi
else
  COMMIT_IDS="(no stable tag available)"
fi

# --- Timestamp ---
REPORT_TIME=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# --- Generate report ---
REPORT_FILE="${DEPLOY_DIR}/deployment-summary.md"

cat > "${REPORT_FILE}" <<EOF
## TapData Deployment Report

| Item | Value |
| --- | --- |
| Report Time | ${REPORT_TIME} |
| Operator | ${GITHUB_ACTOR} |
| Target Environment | ${TARGET_ENV} |
| Project | ${PROJECT} |
| Deployment Ref | ${DEPLOYMENT_REF} |
| Last Stable Tag | ${LAST_STABLE_TAG:-"(none)"} |
| Overall Result | ${OVERALL_RESULT} |

### Change Summary

| Resource | Count |
| --- | ---: |
| Connections | ${CONNECTIONS_COUNT} |
| Tasks | ${TASKS_COUNT} |
| APIs | ${APIS_COUNT} |

### Commit Details

- Commit Count: ${COMMIT_COUNT}
- Commit IDs: ${COMMIT_IDS}

### Job Results

| Job | Result |
| --- | --- |
| Preparation | ${PREPARATION_RESULT} |
| Deploy Connections | ${CONNECTIONS_RESULT} |
| Deploy Tasks | ${TASKS_RESULT} |
| Deploy APIs | ${APIS_RESULT} |

### Rollback

| Item | Value |
| --- | --- |
| Rollback Triggered | ${ROLLBACK_TRIGGERED} |
| Rollback Approval | ${ROLLBACK_APPROVAL} |
| Rollback Result | ${ROLLBACK_STATUS} |
EOF

echo "Report saved to ${REPORT_FILE}"
cat "${REPORT_FILE}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat "${REPORT_FILE}" >> "${GITHUB_STEP_SUMMARY}"
  echo "Report appended to step summary"
fi

echo "=== Report Generated ==="
