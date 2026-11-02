#!/usr/bin/env python3
"""
Load ForgeSphere Kong/Konnect CI/CD Configuration.

Reads the effective configuration of the application's KONG_GATEWAY_SERVICE
resource type for one environment.

Environment variables:
    CICD_CONFIG_URL       ForgeSphere CI/CD base URL
    CICD_CONFIG_ID        cicd_profile_id: the application's id
    SERVICE_ACCESS_TOKEN
    ENVIRONMENT
    DEPLOY_PROXY          Name of what is deployed (the Sonar project key)
    GITHUB_OUTPUT

Outputs (written to $GITHUB_OUTPUT):
    kong_pat_token, kong_control_plane, kong_host_url, kong_deck_mode
    sonar_*, nexus_*, environment_*
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
        + urllib.parse.urlencode({
            "resourceType": "KONG_GATEWAY_SERVICE",
            "environmentGroup": environment_group,
        })
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
        url, method="GET",
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
            rb = exc.read().decode("utf-8", errors="replace")
        except Exception:
            rb = ""
        print(f"CI/CD Config HTTP Status: {exc.code}")
        if rb:
            print("Response:")
            print(rb)
        fail(f"ForgeSphere CI/CD configuration request failed (HTTP {exc.code})")
    except urllib.error.URLError as exc:
        fail(f"Failed to call ForgeSphere CI/CD configuration API (network error: {exc.reason})")
    except TimeoutError:
        fail("Failed to call ForgeSphere CI/CD configuration API (request timed out)")
    except Exception as exc:
        fail(f"Unexpected error: {exc}")

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


def write_outputs(outputs: dict, github_output) -> None:
    if github_output:
        with open(github_output, "a", encoding="utf-8") as f:
            for key, value in outputs.items():
                if value is None:
                    value = ""
                if isinstance(value, (dict, list)):
                    value = json.dumps(value)
                f.write(f"{key}={value}\n")
        return
    print("WARNING: GITHUB_OUTPUT not set; outputs will not be exported.")
    for k, v in outputs.items():
        if k in {"kong_pat_token", "sonar_token", "nexus_password"}:
            continue
        print(f"{k}={v}")


def main() -> None:
    config_url = os.environ.get("CICD_CONFIG_URL", "").strip()
    config_id = os.environ.get("CICD_CONFIG_ID", "").strip()
    token = os.environ.get("SERVICE_ACCESS_TOKEN", "").strip()
    environment = os.environ.get("ENVIRONMENT", "").strip().lower()
    deploy_proxy = os.environ.get("DEPLOY_PROXY", "").strip()
    github_output = os.environ.get("GITHUB_OUTPUT")

    if not config_url:    fail("CICD_CONFIG_URL must be set")
    if not config_id:     fail("CICD_CONFIG_ID must be set")
    if not token:         fail("ForgeSphere service token is empty")
    if not environment:   fail("ENVIRONMENT must be set")

    mask(token)

    config = fetch_config(config_url, config_id, token, environment.upper())
    tools = config.get("tools") or {}

    # Sonar
    sonar = (tools.get("security") or {}).get("SONARQUBE") or {}
    sonar_host_url = (sonar.get("configuration") or {}).get("baseUrl")
    sonar_token = (sonar.get("credentials") or {}).get("token")
    sonar_project_key = deploy_proxy

    # Nexus
    artifact = tools.get("artifact") or {}
    if text(artifact.get("providerType")).upper() != "NEXUS":
        artifact = {}
    nconf = artifact.get("configuration") or {}
    nexus_url = nconf.get("baseUrl") or ""
    nexus_repository = nconf.get("repository") or ""
    nexus_username = nconf.get("username") or ""
    nexus_password = (artifact.get("credentials") or {}).get("password") or ""

    # Environment
    ec = config.get("environment") or {}
    environment_label = ec.get("displayName", "")
    cr_required = ec.get("changeRequestRequired", False)

    # Kong
    deployment_target = config.get("deploymentTarget")
    if not isinstance(deployment_target, dict):
        fail(f"Kong environment '{environment}' has no deploymentTarget")

    kong_conf = deployment_target.get("configuration") or {}
    kong_pat_token = (deployment_target.get("credentials") or {}).get("pat", "")
    kong_control_plane = (
        kong_conf.get("controlPlane")
        or deployment_target.get("name")
        or ""
    )
    kong_host_url = kong_conf.get("hostUrl", "")
    kong_deck_mode = kong_conf.get("deckMode", "apply")

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

    write_outputs({
        "environment":        environment,
        "environment_label":  environment_label,
        "cr_required":        str(cr_required).lower(),
        "sonar_host_url":     sonar_host_url,
        "sonar_project_key":  sonar_project_key,
        "sonar_token":        sonar_token,
        "nexus_url":          nexus_url,
        "nexus_repository":   nexus_repository,
        "nexus_username":     nexus_username,
        "nexus_password":     nexus_password,
        "kong_pat_token":     kong_pat_token,
        "kong_control_plane": kong_control_plane,
        "kong_host_url":      kong_host_url,
        "kong_deck_mode":     kong_deck_mode,
    }, github_output)

    print("")
    print("==========================================")
    print("KONG CONFIGURATION LOADED")
    print("==========================================")
    print(f"Environment    : {environment}")
    print(f"Control Plane  : {kong_control_plane or '<empty>'}")
    print(f"Host URL       : {kong_host_url or '<empty>'}")
    print(f"Deck Mode      : {kong_deck_mode or '<empty>'}")
    print(f"Kong PAT       : {'set' if kong_pat_token else '<MISSING>'}")
    print("==========================================")


if __name__ == "__main__":
    main()