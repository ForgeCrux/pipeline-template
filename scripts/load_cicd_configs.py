#!/usr/bin/env python3
"""
Load ForgeSphere CI/CD Configuration.

Fetches the effective CI/CD configuration of the application for one resource
type and environment using the ForgeSphere service access token, validates
required fields, masks secrets in GitHub Actions logs, and writes outputs to
$GITHUB_OUTPUT.

Environment variables:
    CICD_CONFIG_URL       ForgeSphere CI/CD base URL (https://forgesphere.probestack.io/cicd-automation)
    CICD_CONFIG_ID        cicd_profile_id: the application's id
    SERVICE_ACCESS_TOKEN  ForgeSphere Bearer access token
    DEPLOY_PROXY          Apigee proxy name / Sonar project key
    RESOURCE_TYPE         apis or sharedflows
    ENVIRONMENT           ForgeSphere environment the workflow is for (dev, qa, ...)
    APIGEE_ENV            Apigee environment, to pick that environment's deployment target (optional)
    GITHUB_OUTPUT         GitHub Actions output file
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def mask(value: str) -> None:
    """Mask a secret in GitHub Actions logs."""
    if value:
        print(f"::add-mask::{value}")


def base_url(value: str) -> str:
    """
    The service's base URL. The old configuration address
    (.../v1/api/cicd-config) is understood too.
    """
    value = value.strip().rstrip("/")
    return value.split("/v1/api")[0] if "/v1/api" in value else value


def fetch_config(
    config_url: str,
    application_id: str,
    service_access_token: str,
    resource_type: str,
    environment_group: str,
    target: str,
) -> dict:
    """
    Fetch the effective configuration.

    Equivalent to:

        curl --silent --show-error --location --fail-with-body \
          --header "Authorization: Bearer ${SERVICE_ACCESS_TOKEN}" \
          --header "Accept: application/json" \
          "${CONFIG_URL}/internal/v2/cicd/applications/${ID}/effective-config?resourceType=...&environmentGroup=...&target=..."
    """

    params = {"resourceType": resource_type, "environmentGroup": environment_group}
    if target:
        params["target"] = target

    url = (
        f"{base_url(config_url)}/internal/v2/cicd/applications/"
        f"{urllib.parse.quote(application_id, safe='')}/effective-config?"
        f"{urllib.parse.urlencode(params)}"
    )

    print("==========================================")
    print("FORGESPHERE CI/CD CONFIG")
    print("==========================================")
    print(f"Application   : {application_id}")
    print(f"Resource type : {resource_type}")
    print(f"Environment   : {environment_group}")
    print(f"Target        : {target or '-'}")
    print(f"Config URL    : {base_url(config_url)}")
    print("Authorization : Bearer ********")
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
        payload = json.loads(body)
    except json.JSONDecodeError as exc:
        print("ERROR: ForgeSphere returned invalid JSON")
        print("Response:")
        print(body.decode("utf-8", errors="replace"))
        fail(f"Invalid JSON: {exc}")

    # The configuration is inside {"success", "data", "timestamp"}.
    config = payload.get("data", payload) if isinstance(payload, dict) else None

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
                    output_file.write(f"{key}={value}\n")
        except OSError as exc:
            fail(f"Unable to write GitHub outputs: {exc}")
        return

    print(
        "WARNING: GITHUB_OUTPUT is not set; outputs will not be exported."
    )

    safe_outputs = {
        key: value
        for key, value in outputs.items()
        if key not in {"sonar_token", "nexus_password"}
    }

    for key, value in safe_outputs.items():
        print(f"{key}={value}")


def main() -> None:
    # ------------------------------------------------
    # ENVIRONMENT
    # ------------------------------------------------

    config_url = os.environ.get("CICD_CONFIG_URL", "").strip()
    config_id = os.environ.get("CICD_CONFIG_ID", "").strip()
    service_access_token = os.environ.get("SERVICE_ACCESS_TOKEN", "").strip()
    deploy_proxy = os.environ.get("DEPLOY_PROXY", "").strip()
    resource_type = os.environ.get("RESOURCE_TYPE", "").strip()
    environment_group = os.environ.get("ENVIRONMENT", "").strip().upper()
    apigee_env = os.environ.get("APIGEE_ENV", "").strip()
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
    if not resource_type:
        fail("RESOURCE_TYPE must be set (apis or sharedflows)")
    if not environment_group:
        fail(
            "ENVIRONMENT must be set "
            "(the ForgeSphere environment this workflow is for, e.g. dev)"
        )

    # Mask the service token immediately.
    mask(service_access_token)

    # ------------------------------------------------
    # FETCH CONFIGURATION
    # ------------------------------------------------

    config = fetch_config(
        config_url=config_url,
        application_id=config_id,
        service_access_token=service_access_token,
        resource_type=resource_type,
        environment_group=environment_group,
        target=apigee_env,
    )

    # ------------------------------------------------
    # BRANCH STRATEGY
    # ------------------------------------------------

    merge_branch = None
    merge_tag = None

    branches = (config.get("branchingStrategy") or {}).get("branches") or []

    for branch in branches:
        if not isinstance(branch, dict):
            continue
        if branch.get("tag") == "merge":
            merge_branch = branch.get("name")
            merge_tag = branch.get("tag")
            break

    if not merge_branch:
        fail("merge branch not configured")

    # ------------------------------------------------
    # SONAR CONFIGURATION
    # ------------------------------------------------

    sonar = (
        ((config.get("tools") or {}).get("security") or {}).get("SONARQUBE")
        or {}
    )
    sonar_configuration = sonar.get("configuration") or {}
    sonar_credentials = sonar.get("credentials") or {}

    sonar_host_url = sonar_configuration.get("baseUrl")
    sonar_token = sonar_credentials.get("token")
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

    artifact = (config.get("tools") or {}).get("artifact") or {}

    if str(artifact.get("providerType") or "").upper() != "NEXUS":
        artifact = {}

    nexus_configuration = artifact.get("configuration") or {}
    nexus_credentials = artifact.get("credentials") or {}

    nexus_url = nexus_configuration.get("baseUrl") or ""
    nexus_username = nexus_configuration.get("username") or ""
    nexus_password = nexus_credentials.get("password") or ""
    nexus_repository = nexus_configuration.get("repository") or ""

    # ------------------------------------------------
    # APIGEE SERVICE ACCOUNT
    # ------------------------------------------------

    deployment_target = config.get("deploymentTarget")

    if not isinstance(deployment_target, dict):
        fail(
            "No Apigee deployment target is configured "
            f"for environment {environment_group}"
        )

    target_configuration = deployment_target.get("configuration") or {}
    target_credentials = deployment_target.get("credentials") or {}

    apigee_service_account_email = str(
        target_configuration.get("serviceAccountEmail") or ""
    )
    apigee_workload_identity_provider = str(
        target_configuration.get("workloadIdentityProvider") or ""
    )

    missing_fields = [
        name
        for name, value in (
            ("serviceAccountEmail", apigee_service_account_email),
            ("workloadIdentityProvider", apigee_workload_identity_provider),
        )
        if not value
    ]

    if missing_fields:
        fail(
            "Invalid Apigee connection. "
            f"Missing fields: {', '.join(missing_fields)}"
        )

    # The workflow reads client_email from this file, so it has the same shape as before.
    apigee_service_account_data = {}

    raw_service_account = target_credentials.get("serviceAccountJson")

    if raw_service_account:
        try:
            apigee_service_account_data = (
                raw_service_account
                if isinstance(raw_service_account, dict)
                else json.loads(raw_service_account)
            )
        except json.JSONDecodeError as exc:
            fail(f"Invalid Apigee service account JSON: {exc}")

    if not isinstance(apigee_service_account_data, dict):
        fail("Apigee service account JSON must contain a JSON object")

    apigee_service_account_data.setdefault(
        "client_email",
        apigee_service_account_email,
    )
    apigee_service_account_data["workload_identity_provider"] = (
        apigee_workload_identity_provider
    )

    runner_temp = os.environ.get("RUNNER_TEMP", "/tmp")
    apigee_service_account_file = os.path.join(
        runner_temp,
        "apigee-service-account.json",
    )

    try:
        with open(apigee_service_account_file, "w", encoding="utf-8") as file:
            json.dump(apigee_service_account_data, file, indent=2)

        # Private-key file must not be world-readable.
        os.chmod(apigee_service_account_file, 0o600)
    except OSError as exc:
        fail(f"Unable to create Apigee service account file: {exc}")

    print(f"Apigee service account configured: {apigee_service_account_email}")

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
        "apigee_workload_identity_provider": apigee_workload_identity_provider,
    }

    write_outputs(outputs=outputs, github_output=github_output)

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
    print(f"Apigee Service Account: {apigee_service_account_email}")
    print(f"Apigee Service Account File: {apigee_service_account_file}")
    print("==========================================")


if __name__ == "__main__":
    main()