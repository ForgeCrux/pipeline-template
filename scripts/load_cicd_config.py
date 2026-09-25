#!/usr/bin/env python3
"""
Load ForgeSphere CI/CD Configuration.

Fetches the CI/CD configuration using the ForgeSphere service access token,
extracts the APIGEE_PROXY pipeline configuration, validates required fields,
masks secrets in GitHub Actions logs, and writes outputs to $GITHUB_OUTPUT.

Environment variables:
    CICD_CONFIG_URL       Base ForgeSphere configuration API URL
    CICD_CONFIG_ID       CI/CD configuration/profile ID
    SERVICE_ACCESS_TOKEN ForgeSphere Bearer access token
    DEPLOY_PROXY         Apigee proxy name / Sonar project key
    GITHUB_OUTPUT        GitHub Actions output file
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
    """Mask a secret in GitHub Actions logs."""
    if value:
        print(f"::add-mask::{value}")


def get(d: dict, path: str):
    """Safely retrieve a nested dictionary value using dotted notation."""
    cur = d

    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None

        cur = cur[part]

    return cur


def fetch_config(
    config_url: str,
    config_id: str,
    service_access_token: str,
) -> dict:
    """
    Fetch ForgeSphere CI/CD configuration.

    Equivalent to:

        curl \
          --silent \
          --show-error \
          --location \
          --fail-with-body \
          --header "Authorization: Bearer ${SERVICE_ACCESS_TOKEN}" \
          --header "Accept: application/json" \
          "${CONFIG_URL}"
    """

    url = (
        f"{config_url.rstrip('/')}/"
        f"{config_id}/all?filtered=true"
    )

    print("==========================================")
    print("FORGESPHERE CI/CD CONFIG")
    print("==========================================")
    print(f"Config ID : {config_id}")
    print(f"Config URL: {config_url}")
    print("Authorization: Bearer ********")
    print("==========================================")

    request = urllib.request.Request(
        url,
        method="GET",
        headers={
            "Authorization": f"Bearer {service_access_token}",
            "Accept": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            status = response.status
            body = response.read()

    except urllib.error.HTTPError as exc:
        # HTTPError is also a response, so read the response body.
        try:
            response_body = exc.read().decode("utf-8", errors="replace")
        except Exception:
            response_body = ""

        print(f"CI/CD Config HTTP Status: {exc.code}")
        print("ERROR: Failed to call ForgeSphere CI/CD configuration API")

        if response_body:
            print("Response:")
            print(response_body)

        fail(
            f"ForgeSphere CI/CD configuration request failed "
            f"(HTTP {exc.code})"
        )

    except urllib.error.URLError as exc:
        fail(
            "Failed to call ForgeSphere CI/CD configuration API "
            f"(network error: {exc.reason})"
        )

    except TimeoutError:
        fail(
            "Failed to call ForgeSphere CI/CD configuration API "
            "(request timed out)"
        )

    except Exception as exc:
        fail(
            "Unexpected error while calling ForgeSphere CI/CD "
            f"configuration API: {exc}"
        )

    print(f"CI/CD Config HTTP Status: {status}")

    if status < 200 or status >= 300:
        fail(
            "ForgeSphere CI/CD configuration request failed "
            f"(HTTP {status})"
        )

    if not body:
        fail("ForgeSphere returned an empty CI/CD configuration")

    print("Validating CI/CD configuration JSON...")

    try:
        config = json.loads(body)
    except json.JSONDecodeError as exc:
        print("ERROR: ForgeSphere returned invalid JSON")
        print("Response:")
        print(body.decode("utf-8", errors="replace"))

        fail(f"Invalid JSON: {exc}")

    if not isinstance(config, dict):
        fail("ForgeSphere CI/CD configuration must be a JSON object")

    print("CI/CD configuration loaded successfully")

    return config


def write_outputs(outputs: dict, github_output: str | None) -> None:
    """
    Write values to GitHub Actions GITHUB_OUTPUT.

    If GITHUB_OUTPUT is not available, print non-secret values only.
    """

    if github_output:
        try:
            with open(github_output, "a", encoding="utf-8") as output_file:
                for key, value in outputs.items():
                    if value is None:
                        value = ""

                    output_file.write(
                        f"{key}={value}\n"
                    )

        except OSError as exc:
            fail(f"Unable to write GitHub outputs: {exc}")

        return

    # Local execution fallback.
    # Do NOT print secrets.
    print(
        "WARNING: GITHUB_OUTPUT is not set; "
        "outputs will not be exported."
    )

    safe_outputs = {
        key: value
        for key, value in outputs.items()
        if key not in {
            "sonar_token",
            "nexus_password",
        }
    }

    for key, value in safe_outputs.items():
        print(f"{key}={value}")


def main() -> None:
    # ------------------------------------------------
    # ENVIRONMENT
    # ------------------------------------------------

    config_url = os.environ.get("CICD_CONFIG_URL", "").strip()
    config_id = os.environ.get("CICD_CONFIG_ID", "").strip()
    service_access_token = os.environ.get(
        "SERVICE_ACCESS_TOKEN",
        "",
    ).strip()
    deploy_proxy = os.environ.get("DEPLOY_PROXY", "").strip()
    github_output = os.environ.get("GITHUB_OUTPUT")

    # ------------------------------------------------
    # VALIDATION
    # ------------------------------------------------

    if not config_url:
        fail("CICD_CONFIG_URL must be set")

    if not config_id:
        fail("CICD_CONFIG_ID must be set")

    if not service_access_token:
        fail("ForgeSphere service token is empty")

    if not deploy_proxy:
        fail("DEPLOY_PROXY must be set")

    # Mask the service token immediately.
    mask(service_access_token)

    # ------------------------------------------------
    # FETCH CONFIGURATION
    # ------------------------------------------------

    raw_config = fetch_config(
        config_url=config_url,
        config_id=config_id,
        service_access_token=service_access_token,
    )

    # ------------------------------------------------
    # CONFIGURATION ROOT
    # ------------------------------------------------

    strategies = raw_config.get("strategies", [])

    if strategies is None:
        strategies = []

    pipeline_config = (
        get(
            raw_config,
            "pipelineConfigs.APIGEE_PROXY",
        )
        or {}
    )

    if not isinstance(pipeline_config, dict):
        fail(
            "pipelineConfigs.APIGEE_PROXY "
            "must be a JSON object"
        )

    # ------------------------------------------------
    # BRANCH STRATEGY
    # ------------------------------------------------

    merge_branch = None
    merge_tag = None

    for strategy in strategies:

        if not isinstance(strategy, dict):
            continue

        branches = strategy.get("branches", [])

        if not isinstance(branches, list):
            continue

        for branch in branches:

            if not isinstance(branch, dict):
                continue

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

    sonar_host_url = get(
        pipeline_config,
        "securityToolConfigs.sonarscanner.SONAR_HOST_URL",
    )

    sonar_token = get(
        pipeline_config,
        "securityToolConfigs.sonarscanner.SONAR_TOKEN",
    )

    # Deploy proxy is used as the Sonar project key.
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

    nexus_url = (
        get(
            pipeline_config,
            "artifactToolConfigs.nexus.NEXUS_URL",
        )
        or ""
    )

    nexus_username = (
        get(
            pipeline_config,
            "artifactToolConfigs.nexus.NEXUS_USERNAME",
        )
        or ""
    )

    nexus_password = (
        get(
            pipeline_config,
            "artifactToolConfigs.nexus.NEXUS_PASSWORD",
        )
        or ""
    )

    nexus_repository = (
        get(
            pipeline_config,
            "artifactToolConfigs.nexus.NEXUS_REPOSITORY",
        )
        or ""
    )

    # ------------------------------------------------
    # APIGEE SERVICE ACCOUNT
    # ------------------------------------------------
    
    apigee_serviceAccountJson = (
        get(
            pipeline_config,
            "apigeeDetails.serviceAccountJson",
        )
        or ""
    )
    
    if not apigee_serviceAccountJson:
        fail(
            "apigeeDetails.serviceAccountJson "
            "is not configured"
        )
    
    try:
        # ForgeSphere may return this either as an object
        # or as a JSON string.
        if isinstance(apigee_serviceAccountJson, dict):
            apigee_service_account_data = apigee_serviceAccountJson
    
        elif isinstance(apigee_serviceAccountJson, str):
            apigee_service_account_data = json.loads(
                apigee_serviceAccountJson
            )
    
        else:
            fail(
                "apigeeDetails.serviceAccountJson "
                "must be a JSON object or JSON string"
            )
    
    except json.JSONDecodeError as exc:
        fail(
            "Invalid apigeeDetails.serviceAccountJson JSON: "
            f"{exc}"
        )
    
    if not isinstance(apigee_service_account_data, dict):
        fail(
            "apigeDetails.serviceAccountJson "
            "must contain a JSON object"
        )
    
    # Validate the fields required for a Google service account.
    required_fields = [
        "type",
        "project_id",
        "private_key",
        "client_email",
    ]
    
    missing_fields = [
        field
        for field in required_fields
        if not apigee_service_account_data.get(field)
    ]
    
    if missing_fields:
        fail(
            "Invalid Apigee service account JSON. "
            f"Missing fields: {', '.join(missing_fields)}"
        )
    
    apigee_service_account_email = apigee_service_account_data["client_email"]
    
    # RUNNER_TEMP is provided by GitHub Actions.
    # Fall back to the system temp directory for local execution.
    runner_temp = os.environ.get(
        "RUNNER_TEMP",
        "/tmp",
    )
    
    apigee_service_account_file = os.path.join(
        runner_temp,
        "apigee-service-account.json",
    )
    
    try:
        with open(
            apigee_service_account_file,
            "w",
            encoding="utf-8",
        ) as file:
            json.dump(
                apigee_service_account_data,
                file,
                indent=2,
            )
    
        # Private-key file must not be world-readable.
        os.chmod(
            apigee_service_account_file,
            0o600,
        )
    
    except OSError as exc:
        fail(
            "Unable to create Apigee service account file: "
            f"{exc}"
        )
    
    print(
        "Apigee service account configured: "
        f"{apigee_service_account_email}"
    )

    # ------------------------------------------------
    # MASK SECRETS
    # ------------------------------------------------

    mask(sonar_token)
    mask(nexus_password)

    # ------------------------------------------------
    # GITHUB OUTPUTS
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
        "apigee_serviceAccountFile": apigee_service_account_file,
        "apigee_serviceAccountEmail": apigee_service_account_email,
    }

    write_outputs(
        outputs=outputs,
        github_output=github_output,
    )

    # ------------------------------------------------
    # SUMMARY
    # ------------------------------------------------

    print("==========================================")
    print("ForgeSphere configuration loaded")
    print("==========================================")
    print(f"Merge branch : {merge_branch}")
    print(f"Merge tag    : {merge_tag}")
    print(f"Sonar URL    : {sonar_host_url}")
    print(f"Sonar Project: {sonar_project_key}")
    print(
        f"Nexus Config : "
        f"{'configured' if nexus_url else 'not configured'}"
    )
    print(
        "Apigee Service Account: " 
        f"{service_account_email}"
    )
    
    print(
        "Apigee Service Account File: "
        f"{service_account_file}"
    )
    print("==========================================")


if __name__ == "__main__":
    main()
