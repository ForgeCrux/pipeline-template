#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_validate_strategy() {
  case "$DEPLOY_STRATEGY" in
    helm|kustomize) echo "Strategy: $DEPLOY_STRATEGY" ;;
    *) echo "ERROR: deploy_strategy must be helm or kustomize" >&2; return 1 ;;
  esac
}

_validate_build_file() {
  case "$BUILD_TOOL" in
    maven)  [ -f "pom.xml" ]       || { echo "ERROR: pom.xml not found" >&2; return 1; } ;;
    gradle) [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] \
              || { echo "ERROR: build.gradle(.kts) not found" >&2; return 1; } ;;
    *)      echo "ERROR: build_tool must be maven or gradle" >&2; return 1 ;;
  esac
  echo "Build file OK ($BUILD_TOOL)"
}

_validate_dockerfile() {
  [ -f "$DOCKERFILE_PATH" ] || { echo "ERROR: Dockerfile not found at $DOCKERFILE_PATH" >&2; return 1; }
  echo "Dockerfile: $DOCKERFILE_PATH"
}

_validate_manifests() {
  if [ "$DEPLOY_STRATEGY" = "helm" ]; then
    [ -f "$HELM_CHART_PATH/Chart.yaml" ] || { echo "ERROR: Chart.yaml missing" >&2; return 1; }
    echo "Helm chart: $HELM_CHART_PATH"
  else
    [ -f "$KUSTOMIZE_PATH/kustomization.yaml" ] || { echo "ERROR: kustomization.yaml missing" >&2; return 1; }
    echo "Kustomize: $KUSTOMIZE_PATH"
  fi
}

_validate_mcp_manifest() {
  # Optional for Java — tools are usually annotated, not declared in JSON.
  if [ ! -f "$MCP_MANIFEST_PATH" ]; then
    echo "INFO: $MCP_MANIFEST_PATH not found; relying on Spring AI annotations for tool discovery."
    echo "      The verify stage will compare live tools/list output against a generated manifest."
    return 0
  fi

  local name version transport
  name="$(jq -r '.name // empty' "$MCP_MANIFEST_PATH")"
  version="$(jq -r '.version // empty' "$MCP_MANIFEST_PATH")"
  transport="$(jq -r '.transport.type // "sse"' "$MCP_MANIFEST_PATH")"

  [ -n "$name" ]    || { echo "ERROR: mcp.json missing 'name'" >&2; return 1; }
  [ -n "$version" ] || { echo "ERROR: mcp.json missing 'version'" >&2; return 1; }
  case "$transport" in
    sse|http|streamable-http) echo "Transport: $transport" ;;
    *) echo "ERROR: transport '$transport' not supported for remote servers" >&2; return 1 ;;
  esac

  jq -e '.capabilities' "$MCP_MANIFEST_PATH" >/dev/null \
    || { echo "ERROR: mcp.json missing 'capabilities'" >&2; return 1; }

  # Tool schemas (only if present)
  local count; count="$(jq '.tools | length // 0' "$MCP_MANIFEST_PATH")"
  if [ "$count" -gt 0 ]; then
    local i
    for i in $(seq 0 $((count - 1))); do
      local tool_name
      tool_name="$(jq -r ".tools[$i].name // empty" "$MCP_MANIFEST_PATH")"
      [ -n "$tool_name" ] || { echo "ERROR: tools[$i] missing name" >&2; return 1; }
      echo "  ✓ tool schema present: $tool_name"
    done
  fi
}

_validation_body() {
  run_step VALIDATION VALIDATE_STRATEGY       _validate_strategy
  run_step VALIDATION VALIDATE_BUILD_FILE     _validate_build_file
  run_step VALIDATION VALIDATE_DOCKERFILE     _validate_dockerfile
  run_step VALIDATION VALIDATE_MANIFESTS      _validate_manifests
  run_step VALIDATION VALIDATE_MCP_MANIFEST   _validate_mcp_manifest
}

stage_run VALIDATION "Validation" _validation_body
