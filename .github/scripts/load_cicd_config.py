#!/usr/bin/env python3
"""
Load ForgeSphere CI/CD Configuration.

Fetches the CI/CD config for a given config ID, extracts the APIGEE_PROXY
pipeline configuration, validates required fields, masks secrets in the
GitHub Actions log, and writes outputs to $GITHUB_OUTPUT.

Environment variables expected:
    CICD_CONFIG_URL   - base URL (e.g. https://forgesphere.example.com/api/configs)
    CICD_CONFIG_ID    - the config id to fetch
    DEPLOY_PROXY      - value used as the Sonar project key
    GITHUB_OUTPUT     - path to the GitHub Actions output file (set by the runner)

Exit codes:
    0  success
    1  any validation / fetch failure (mirrors `exit 1` in the bash version)
"""

import json
import os
import sys
import urllib.error
import urllib.request


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def mask(value: str) -> None:
    """Emit a GitHub Actions log-masking command for a secret value."""
    if value:
        print(f"::add-mask::{value}")


def fetch_config(config_url: str, config_id: str) -> dict:
    url = f"{config_url.rstrip('/')}/{config_id}/all?filtered=true"
    print(f"Fetching ForgeSphere CI/CD configuration... {url}")

    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req) as resp:
            status = resp.status
            body = resp.read()
    except urllib.error.HTTPError as e:
        fail(f"Failed to retrieve CI/CD configuration (HTTP status: {e.code})")
    except urllib.error.URLError as e:
        fail(f"Failed to retrieve CI/CD configuration (network error: {e.reason})")

    if status != 200:
        fail(f"Failed to retrieve CI/CD configuration\nHTTP status: {status}")

    if not body:
        fail("Empty CI/CD configuration")

    try:
        return json.loads(body)
    except json.JSONDecodeError as e:
        fail(f"CI/CD configuration is not valid JSON: {e}")


def get(d: dict, path: str):
    """Dotted-path getter, returns None if any segment is missing."""
    cur = d
    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def main() -> None:
    config_url = os.environ.get("CICD_CONFIG_URL", "")
    config_id = os.environ.get("CICD_CONFIG_ID", "")
    deploy_proxy = os.environ.get("DEPLOY_PROXY", "")
    github_output = os.environ.get("GITHUB_OUTPUT")

    if not config_url or not config_id:
        fail("CICD_CONFIG_URL and CICD_CONFIG_ID must be set")

    raw_config = fetch_config(config_url, config_id)

    strategies = raw_config.get("strategies", [])
    pipeline_config = get(raw_config, "pipelineConfigs.APIGEE_PROXY") or {}

    apigee_config = {
        "strategies": strategies,
        "pipelineConfig": pipeline_config,
    }

    # ------------------------------------------------
    # BRANCH STRATEGY
    # ------------------------------------------------
    merge_branch = None
    merge_tag = None
    for strategy in apigee_config["strategies"] or []:
        for branch in strategy.get("branches", []):
            if branch.get("tag") == "merge":
                merge_branch = branch.get("name")
                merge_tag = branch.get("tag")
                break
        if merge_branch:
            break

    if not merge_branch:
        fail("merge branch not configured")

    # ------------------------------------------------
    # SONAR CONFIGURATION
    # ------------------------------------------------
    sonar_host_url = get(pipeline_config, "securityToolConfigs.sonarscanner.SONAR_HOST_URL")
    sonar_token = get(pipeline_config, "securityToolConfigs.sonarscanner.SONAR_TOKEN")
    sonar_project_key = deploy_proxy

    if not sonar_host_url:
        fail("SONAR_HOST_URL not configured")
    if not sonar_token:
        fail("SONAR_TOKEN not configured")
    if not sonar_project_key:
        fail("SONAR_PROJECT_KEY not configured")

    # ------------------------------------------------
    # NEXUS CONFIGURATION
    # ------------------------------------------------
    nexus_url = get(pipeline_config, "artifactToolConfigs.nexus.NEXUS_URL") or ""
    nexus_username = get(pipeline_config, "artifactToolConfigs.nexus.NEXUS_USERNAME") or ""
    nexus_password = get(pipeline_config, "artifactToolConfigs.nexus.NEXUS_PASSWORD") or ""
    nexus_repository = get(pipeline_config, "artifactToolConfigs.nexus.NEXUS_REPOSITORY") or ""

    # ------------------------------------------------
    # MASK SECRETS
    # ------------------------------------------------
    mask(sonar_token)
    mask(nexus_password)

    # ------------------------------------------------
    # OUTPUTS
    # ------------------------------------------------
    outputs = {
        "merge_branch": merge_branch,
        "merge_tag": merge_tag,
        "sonar_host_url": sonar_host_url,
        "sonar_project_key": sonar_project_key,
        "sonar_token": sonar_token,
        "nexus_url": nexus_url,
        "nexus_username": nexus_username,
        "nexus_password": nexus_password,
        "nexus_repository": nexus_repository,
    }

    if github_output:
        with open(github_output, "a", encoding="utf-8") as f:
            for key, value in outputs.items():
                f.write(f"{key}={value}\n")
    else:
        print("WARNING: GITHUB_OUTPUT not set; printing outputs instead", file=sys.stderr)
        for key, value in outputs.items():
            print(f"{key}={value}")

    print("========================================")
    print("ForgeSphere configuration loaded")
    print(f"Merge branch : {merge_branch}")
    print(f"Merge tag    : {merge_tag}")
    print(f"Sonar URL    : {sonar_host_url}")
    print(f"Sonar Project: {sonar_project_key}")
    print(f"Nexus Config : {'configured' if nexus_url else 'not configured'}")
    print("========================================")


if __name__ == "__main__":
    main()
