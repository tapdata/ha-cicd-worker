#!/usr/bin/env bash
# Collect deployment results and generate deployment report for ops workflow (AAT + Prod)
# Required env vars: DEPLOY_DIR, DEPLOYMENT_REF, PROJECT, GITHUB_ACTOR,
#   AAT_CHANGED_CONNECTIONS, AAT_CHANGED_TASKS, AAT_CHANGED_APIS, AAT_CHANGED_GROUP_INFO,
#   PROD_CHANGED_CONNECTIONS, PROD_CHANGED_TASKS, PROD_CHANGED_APIS, PROD_CHANGED_GROUP_INFO,
#   PREPARATION_RESULT, AAT_CONNECTIONS_RESULT, AAT_TASKS_RESULT, AAT_APIS_RESULT, AAT_GROUP_INFO_RESULT,
#   PROD_RESULT
set -euo pipefail

echo "=== Generating Ops Deployment Report ==="

mkdir -p "${DEPLOY_DIR}"

# --- Map job result to emoji ---
result_icon() {
  case "${1}" in
    success)  echo "✅" ;;
    failure)  echo "❌" ;;
    cancelled) echo "⚠️" ;;
    skipped)  echo "⏭️" ;;
    *)        echo "❓" ;;
  esac
}

# --- Determine overall result ---
determine_env_result() {
  local conns="$1" tasks="$2" apis="$3" group="$4"
  if [[ "${conns}" == "success" && "${tasks}" == "success" && "${apis}" == "success" && "${group}" == "success" ]]; then
    echo "✅ SUCCESS"
  elif [[ "${conns}" == "failure" || "${tasks}" == "failure" || "${apis}" == "failure" || "${group}" == "failure" ]]; then
    echo "❌ FAILURE"
  else
    echo "⚠️ PARTIAL"
  fi
}

AAT_OVERALL=$(determine_env_result "${AAT_CONNECTIONS_RESULT}" "${AAT_TASKS_RESULT}" "${AAT_APIS_RESULT}" "${AAT_GROUP_INFO_RESULT}")
PROD_OVERALL="$(result_icon "${PROD_RESULT}") ${PROD_RESULT}"

# --- Count changes from import responses ---
count_changes() {
  local json="${1:-}"
  if [[ -z "${json}" || "${json}" == "null" ]]; then
    echo "0"
    return
  fi
  local count
  count=$(echo "${json}" | jq 'if type == "array" then length elif .data? then (.data | if type == "array" then length else 1 end) else 1 end' 2>/dev/null || echo "0")
  echo "${count}"
}

# --- Format diff details as markdown list ---
format_diff_details() {
  local json="${1:-}"
  if [[ -z "${json}" || "${json}" == "null" ]]; then
    echo "_No changes_"
    return
  fi
  local details
  details=$(echo "${json}" | jq -r '
    if type == "array" then
      .[] | "- \(.name // .id // "(unknown)")"
    elif type == "object" then
      "- \(.name // .id // "(unknown)")"
    else
      "- (raw: \(.))"
    end
  ' 2>/dev/null || echo "- _(unable to parse diff)_")
  if [[ -z "${details}" ]]; then
    echo "_No changes_"
  else
    echo "${details}"
  fi
}

# AAT counts
AAT_CONN_COUNT=$(count_changes "${AAT_CHANGED_CONNECTIONS:-}")
AAT_TASK_COUNT=$(count_changes "${AAT_CHANGED_TASKS:-}")
AAT_API_COUNT=$(count_changes "${AAT_CHANGED_APIS:-}")
AAT_GROUP_COUNT=$(count_changes "${AAT_CHANGED_GROUP_INFO:-}")

# Prod counts
PROD_CONN_COUNT=$(count_changes "${PROD_CHANGED_CONNECTIONS:-}")
PROD_TASK_COUNT=$(count_changes "${PROD_CHANGED_TASKS:-}")
PROD_API_COUNT=$(count_changes "${PROD_CHANGED_APIS:-}")
PROD_GROUP_COUNT=$(count_changes "${PROD_CHANGED_GROUP_INFO:-}")

# AAT details
AAT_CONN_DETAILS=$(format_diff_details "${AAT_CHANGED_CONNECTIONS:-}")
AAT_TASK_DETAILS=$(format_diff_details "${AAT_CHANGED_TASKS:-}")
AAT_API_DETAILS=$(format_diff_details "${AAT_CHANGED_APIS:-}")
AAT_GROUP_DETAILS=$(format_diff_details "${AAT_CHANGED_GROUP_INFO:-}")

# Prod details
PROD_CONN_DETAILS=$(format_diff_details "${PROD_CHANGED_CONNECTIONS:-}")
PROD_TASK_DETAILS=$(format_diff_details "${PROD_CHANGED_TASKS:-}")
PROD_API_DETAILS=$(format_diff_details "${PROD_CHANGED_APIS:-}")
PROD_GROUP_DETAILS=$(format_diff_details "${PROD_CHANGED_GROUP_INFO:-}")

# --- Timestamp ---
REPORT_TIME=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# --- Generate report ---
REPORT_FILE="${DEPLOY_DIR}/deployment-summary.md"

cat > "${REPORT_FILE}" <<EOF
## TapData Ops Deployment Report

| Item | Value |
| --- | --- |
| Report Time | ${REPORT_TIME} |
| Operator | ${GITHUB_ACTOR} |
| Project | ${PROJECT} |
| Deployment Ref | ${DEPLOYMENT_REF} |

### Job Results

| Job | Result | Status |
| --- | --- | --- |
| Preparation | $(result_icon "${PREPARATION_RESULT}") ${PREPARATION_RESULT} | - |
| Deploy AAT Connections | $(result_icon "${AAT_CONNECTIONS_RESULT}") ${AAT_CONNECTIONS_RESULT} | ${AAT_CONN_COUNT} changed |
| Deploy AAT Tasks | $(result_icon "${AAT_TASKS_RESULT}") ${AAT_TASKS_RESULT} | ${AAT_TASK_COUNT} changed |
| Deploy AAT APIs | $(result_icon "${AAT_APIS_RESULT}") ${AAT_APIS_RESULT} | ${AAT_API_COUNT} changed |
| Deploy AAT Group Info | $(result_icon "${AAT_GROUP_INFO_RESULT}") ${AAT_GROUP_INFO_RESULT} | ${AAT_GROUP_COUNT} changed |
| **AAT Overall** | **${AAT_OVERALL}** | - |
| Deploy Prod | $(result_icon "${PROD_RESULT}") ${PROD_RESULT} | Conn: ${PROD_CONN_COUNT}, Task: ${PROD_TASK_COUNT}, API: ${PROD_API_COUNT}, Group: ${PROD_GROUP_COUNT} |

### AAT Deploy Details

#### Connections (${AAT_CONN_COUNT} changed)
${AAT_CONN_DETAILS}

#### Tasks (${AAT_TASK_COUNT} changed)
${AAT_TASK_DETAILS}

#### APIs (${AAT_API_COUNT} changed)
${AAT_API_DETAILS}

#### Group Info (${AAT_GROUP_COUNT} changed)
${AAT_GROUP_DETAILS}

### Prod Deploy Details

#### Connections (${PROD_CONN_COUNT} changed)
${PROD_CONN_DETAILS}

#### Tasks (${PROD_TASK_COUNT} changed)
${PROD_TASK_DETAILS}

#### APIs (${PROD_API_COUNT} changed)
${PROD_API_DETAILS}

#### Group Info (${PROD_GROUP_COUNT} changed)
${PROD_GROUP_DETAILS}
EOF

echo "Report saved to ${REPORT_FILE}"
cat "${REPORT_FILE}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat "${REPORT_FILE}" >> "${GITHUB_STEP_SUMMARY}"
  echo "Report appended to step summary"
fi

echo "=== Report Generated ==="

