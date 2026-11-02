#!/usr/bin/env python3
"""
Load ForgeSphere Kong/Konnect CI/CD Configuration.

Reads the effective configuration of the application's KONG_GATEWAY_SERVICE
resource type for one environment:

    ENVIRONMENT=dev
    -> environment group DEV

Environment variables:
    CICD_CONFIG_URL       ForgeSphere CI/CD base URL
    CICD_CONFIG_ID        cicd_profile_id: the application's id
    SERVICE_ACCESS_TOKEN
    ENVIRONMENT
    DEPLOY_PROXY          Name of what is deployed (the Sonar project key)
    GITHUB_OUTPUT

Outputs (written to $GITHUB_OUTPUT):
    environment
    environment_label
    cr_required

    sonar_host_url
    sonar_project_key
    sonar_token

    nexus_url
    nexus_repository
    nexus_username
    nexus_password

    kong_pat_token
    kong_control_plane
    kong_host_url
    kong_deck_mode
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
    if value:
        print(f"::add-mask::{value}")


def text(value) -> str:
    return "" if value is None else str(value)


def base_url(value: str) -> str:
    value = value.strip().rstrip("/")
    return value.split("/v1/api")[0] if "/v1/api" in value else value


def fetch_config(
    config_url: str,
    application_id: str,
    service_access_token: str,
    environment_group: str,
) -> dict:
    url = (
        f"{base_url(config_url)}/internal/v2/cicd/applications/"
        f"{urllib.parse.quote(application_id, safe='')}/effective-config?"
        + urllib.parse.urlencode(
            {
                "resourceType": "KONG_GATEWAY_SERVICE",
                "environmentGroup": environment_group,
            }
        )
    )

    print("==========================================")
    print("FORGESPHERE KONG CONFIG")
    print("==========================================")
    print(f"Application: {application_id}")
    print(f"Environment: {environment_group}")
    print(f"Config URL : {base_url(config_url)}")
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
        try:
            response_body = exc.read().decode("utf-8", errors="replace")
        except Exception:
            response_body = ""
        print(f"CI/CD Config HTTP Status: {exc.code}")
        if response_body:
            print("Response:")
            print(response_body)
        fail(f"ForgeSphere CI/CD configuration request failed (HTTP {exc.code})")
    except urllib.error.URLError as exc:
        fail(f"Failed to call ForgeSphere CI/CD configuration API (network error: {exc.reason})")
    except TimeoutError:
        fail("Failed to call ForgeSphere CI/CD configuration API (request timed out)")
    except Exception as exc:
        fail(f"Unexpected error while calling ForgeSphere CI/CD configuration API: {exc}")

    print(f"CI/CD Config HTTP Status: {status}")

    if status < 200 or status >= 300:
        fail(f"ForgeSphere CI/CD configuration request failed (HTTP {status})")

    if not body:
        fail("ForgeSphere returned an empty CI/CD configuration")

    try:
        payload = json.loads(body)
    except json.JSONDecodeError as exc:
        print(body.decode("utf-8", errors="replace"))
        fail(f"Invalid JSON: {exc}")

    config = payload.get("data", payload) if isinstance(payload, dict) else None
    if not isinstance(config, dict):
        fail("ForgeSphere CI/CD configuration must be a JSON object")

    print("CI/CD configuration loaded successfully")
    return config


def write_outputs(outputs: dict, github_output: str | None) -> None:
    if github_output:
        try:
            with open(github_output, "a", encoding="utf-8") as output_file:
                for key, value in outputs.items():
                    if value is None:
                        value = ""
                    if isinstance(value, (dict, list)):
                        value = json.dumps(value)
                    output_file.write(f"{key}={value}\n")
        except OSError as exc:
            fail(f"Unable to write GitHub outputs: {exc}")
        return

    print("WARNING: GITHUB_OUTPUT is not set; outputs will not be exported.")
    for key, value in outputs.items():
        if key in {"kong_pat_token", "sonar_token", "nexus_password"}:
            continue
        print(f"{key}={value}")


def main() -> None:
    config_url = os.environ.get("CICD_CONFIG_URL", "").strip()
    config_id = os.environ.get("CICD_CONFIG_ID", "").strip()
    service_access_token = os.environ.get("SERVICE_ACCESS_TOKEN", "").strip()
    environment = os.environ.get("ENVIRONMENT", "").strip().lower()
    deploy_proxy = os.environ.get("DEPLOY_PROXY", "").strip()
    github_output = os.environ.get("GITHUB_OUTPUT")

    if not config_url:
        fail("CICD_CONFIG_URL must be set")
    if not config_id:
        fail("CICD_CONFIG_ID must be set")
    if not service_access_token:
        fail("ForgeSphere service token is empty")
    if not environment:
        fail("ENVIRONMENT must be set")

    mask(service_access_token)

    config = fetch_config(
        config_url=config_url,
        application_id=config_id,
        service_access_token=service_access_token,
        environment_group=environment.upper(),
    )

    tools = config.get("tools") or {}

    # --- Sonar ---
    sonar = (tools.get("security") or {}).get("SONARQUBE") or {}
    sonar_host_url = (sonar.get("configuration") or {}).get("baseUrl")
    sonar_token = (sonar.get("credentials") or {}).get("token")
    sonar_project_key = deploy_proxy

    # --- Nexus ---
    artifact = tools.get("artifact") or {}
    if text(artifact.get("providerType")).upper() != "NEXUS":
        artifact = {}
    nexus_configuration = artifact.get("configuration") or {}
    nexus_url = nexus_configuration.get("baseUrl") or ""
    nexus_repository = nexus_configuration.get("repository") or ""
    nexus_username = nexus_configuration.get("username") or ""
    nexus_password = (artifact.get("credentials") or {}).get("password") or ""

    # --- Environment ---
    environment_config = config.get("environment") or {}
    environment_label = environment_config.get("displayName", "")
    cr_required = environment_config.get("changeRequestRequired", False)

    # --- Kong deployment target ---
    deployment_target = config.get("deploymentTarget")
    if not isinstance(deployment_target, dict):
        fail(f"Kong environment '{environment}' is not configured (no deploymentTarget)")

    kong_environment_config = deployment_target.get("configuration") or {}
    kong_pat_token = (deployment_target.get("credentials") or {}).get("pat", "")
    kong_control_plane = (
        kong_environment_config.get("controlPlane")
        or deployment_target.get("name")
        or ""
    )
    kong_host_url = kong_environment_config.get("hostUrl", "")
    kong_deck_mode = kong_environment_config.get("deckMode", "apply")

    # Explicit diagnostics so the operator can see exactly what the profile has.
    print("------------------------------------------")
    print("Kong deployment target fields:")
    print(f"  controlPlane : {kong_control_plane or '<empty>'}")
    print(f"  hostUrl      : {kong_host_url or '<empty>'}")
    print(f"  deckMode     : {kong_deck_mode or '<empty>'}")
    print(f"  pat present  : {'yes' if kong_pat_token else 'NO — deploymentTarget.credentials.pat is missing'}")
    print("------------------------------------------")

    mask(kong_pat_token)
    mask(sonar_token)
    mask(nexus_password)

    outputs = {
        "environment": environment,
        "environment_label": environment_label,
        "cr_required": str(cr_required).lower(),
        "sonar_host_url": sonar_host_url,
        "sonar_project_key": sonar_project_key,
        "sonar_token": sonar_token,
        "nexus_url": nexus_url,
        "nexus_repository": nexus_repository,
        "nexus_username": nexus_username,
        "nexus_password": nexus_password,
        "kong_pat_token": kong_pat_token,
        "kong_control_plane": kong_control_plane,
        "kong_host_url": kong_host_url,
        "kong_deck_mode": kong_deck_mode,
    }

    write_outputs(outputs=outputs, github_output=github_output)

    print("")
    print("==========================================")
    print("KONG CONFIGURATION LOADED")
    print("==========================================")
    print(f"Environment        : {environment}")
    print(f"Control Plane      : {kong_control_plane or '<empty>'}")
    print(f"Host URL           : {kong_host_url or '<empty>'}")
    print(f"Deck Mode          : {kong_deck_mode or '<empty>'}")
    print(f"Kong PAT token     : {'set' if kong_pat_token else '<MISSING>'}")
    print(f"Sonar URL          : {sonar_host_url or '<unset>'}")
    print(f"Nexus config       : {'configured' if nexus_url else 'not configured'}")
    print("==========================================")


if __name__ == "__main__":
    main()