#!/usr/bin/env bash
set -euo pipefail

RAW="${RAW_FLOW_CHANGE_ID:-}"
CURRENT_SHA="${GITHUB_SHA:-}"
CURRENT_BRANCH="${GITHUB_REF_NAME:-}"

UUID_RE='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
RESOLVED=""

if [[ "$RAW" =~ ^([0-9a-fA-F-]{36}):([0-9a-fA-F]+):(.+)$ ]]; then
  UUID="${BASH_REMATCH[1]}"
  SHA="${BASH_REMATCH[2]}"
  BRANCH="${BASH_REMATCH[3]}"
  SHA_OK=0
  [[ "$SHA" == "$CURRENT_SHA" ]]  && SHA_OK=1
  [[ "$CURRENT_SHA" == "$SHA"* ]] && SHA_OK=1
  if [[ "$SHA_OK" == "1" && "$BRANCH" == "$CURRENT_BRANCH" ]]; then
    RESOLVED="$UUID"
    echo "Reusing flow change ID (sha + branch match)"
  else
    echo "SHA/branch mismatch; generating new flow change ID"
  fi
elif [[ "$RAW" =~ $UUID_RE ]]; then
  RESOLVED="$RAW"
  echo "Using supplied bare UUID"
else
  echo "No reusable flow change ID; generating new one"
fi

if [[ -z "$RESOLVED" ]]; then
  if command -v uuidgen >/dev/null 2>&1; then
    RESOLVED="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  else
    RESOLVED="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  fi
fi

echo "Resolved FLOW_CHANGE_ID=$RESOLVED"
echo "FLOW_CHANGE_ID=$RESOLVED" >> "$GITHUB_ENV"