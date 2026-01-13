#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/tmp/github_actions_run.log"
NOW="$(date '+%Y-%m-%d %H:%M:%S')"
HOST="$(hostname)"
USER_NAME="$(whoami)"
RUN_ID="${GITHUB_RUN_ID:-unknown}"
REPO="${GITHUB_REPOSITORY:-unknown}"
WORKFLOW="${GITHUB_WORKFLOW:-unknown}"

JOB="${GITHUB_JOB:-unknown}"
ENV_NAME="${1:-unknown}"

echo "[$NOW] host=$HOST user=$USER_NAME repo=$REPO workflow=$WORKFLOW job=$JOB env=$ENV_NAME run_id=$RUN_ID" >> "$LOG_FILE"
