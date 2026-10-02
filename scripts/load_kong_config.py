#!/usr/bin/env python3

"""
Load ForgeSphere Kong/Konnect CI/CD Configuration.

Reads:

    pipelineConfigs.KONG_GATEWAY_SERVICE

and then selects:

    environmentConfigs.<ENVIRONMENT>

Example:

    ENVIRONMENT=dev
    -> environmentConfigs.dev

Environment variables:

    CICD_CONFIG_URL
    CICD_CONFIG_ID
    SERVICE_ACCESS_TOKEN
    ENVIRONMENT
    GITHUB_OUTPUT

Outputs:

    kong_provider
    kong_runner_type
    kong_runner_tag

    kong_security_tools
    kong_artifact_tools

    kong_sonar_host_url
    kong_sonar_project_key
    kong_sonar_token

    nexus_url
    nexus_repository
    nexus_username
    nexus_password

    kong_environment_label
    kong_cr_required
    kong_environment_provider

    kong_pat_token
    kong_control_plane
    kong_host_url
    kong_deck_mode

    kong_region
    kong_control_plane_id
    kong_pat
"""

import json
import os
import sys
import urllib.error
import urllib.request


# ============================================================
# HELPERS
# ============================================================

def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def mask(value: str) -> None:
    """
    Mask a secret in GitHub Actions logs.
    """
    if value:
        print(f"::add-mask::{value}")


def get(d: dict, path: str):
    """
    Safely retrieve nested dictionary value using dotted notation.
    """
    cur = d

    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None

        cur = cur[part]

    return cur


# ============================================================
# FETCH FORGESPHERE CONFIG
# ============================================================

def fetch_config(
    config_url: str,
    config_id: str,
    service_access_token: str,
) -> dict:

    url = (
        f"{config_url.rstrip('/')}/"
        f"{config_id}/all?filtered=true"
    )

    print("==========================================")
    print("FORGESPHERE KONG CONFIG")
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

        try:
            response_body = exc.read().decode(
                "utf-8",
                errors="replace",
            )
        except Exception:
            response_body = ""

        print(f"CI/CD Config HTTP Status: {exc.code}")

        if response_body:
            print("Response:")
            print(response_body)

        fail(
            "ForgeSphere CI/CD configuration request failed "
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

    try:

        config = json.loads(body)

    except json.JSONDecodeError as exc:

        print("ERROR: ForgeSphere returned invalid JSON")
        print(body.decode("utf-8", errors="replace"))

        fail(f"Invalid JSON: {exc}")

    if not isinstance(config, dict):
        fail(
            "ForgeSphere CI/CD configuration "
            "must be a JSON object"
        )

    print("CI/CD configuration loaded successfully")

    return config


# ============================================================
# GITHUB OUTPUT
# ============================================================

def write_outputs(
    outputs: dict,
    github_output: str | None,
) -> None:

    if github_output:

        try:

            with open(
                github_output,
                "a",
                encoding="utf-8",
            ) as output_file:

                for key, value in outputs.items():

                    if value is None:
                        value = ""

                    # Convert lists/dicts to JSON
                    if isinstance(value, (dict, list)):
                        value = json.dumps(value)

                    output_file.write(
                        f"{key}={value}\n"
                    )

        except OSError as exc:

            fail(
                f"Unable to write GitHub outputs: {exc}"
            )

        return

    # Local execution fallback

    print(
        "WARNING: GITHUB_OUTPUT is not set; "
        "outputs will not be exported."
    )

    secret_keys = {
        "kong_pat_token",
        "kong_pat",
        "sonar_token",
        "nexus_password",
    }

    for key, value in outputs.items():

        if key in secret_keys:
            continue

        if isinstance(value, (dict, list)):
            value = json.dumps(value)

        print(f"{key}={value}")


# ============================================================
# MAIN
# ============================================================

def main() -> None:

    # --------------------------------------------------------
    # ENVIRONMENT
    # --------------------------------------------------------

    config_url = os.environ.get(
        "CICD_CONFIG_URL",
        "",
    ).strip()

    config_id = os.environ.get(
        "CICD_CONFIG_ID",
        "",
    ).strip()

    service_access_token = os.environ.get(
        "SERVICE_ACCESS_TOKEN",
        "",
    ).strip()

    environment = os.environ.get(
        "ENVIRONMENT",
        "",
    ).strip().lower()

    github_output = os.environ.get(
        "GITHUB_OUTPUT"
    )

    # --------------------------------------------------------
    # VALIDATION
    # --------------------------------------------------------

    if not config_url:
        fail("CICD_CONFIG_URL must be set")

    if not config_id:
        fail("CICD_CONFIG_ID must be set")

    if not service_access_token:
        fail("ForgeSphere service token is empty")

    if not environment:
        fail("ENVIRONMENT must be set")

    # Mask service token immediately
    mask(service_access_token)

    # --------------------------------------------------------
    # FETCH CONFIG
    # --------------------------------------------------------

    raw_config = fetch_config(
        config_url=config_url,
        config_id=config_id,
        service_access_token=service_access_token,
    )

    # --------------------------------------------------------
    # KONG PIPELINE CONFIG
    # --------------------------------------------------------

    kong_config = get(
        raw_config,
        "pipelineConfigs.KONG_GATEWAY_SERVICE",
    )

    if not kong_config:
        fail(
            "pipelineConfigs.KONG_GATEWAY_SERVICE "
            "is not configured"
        )

    if not isinstance(kong_config, dict):
        fail(
            "pipelineConfigs.KONG_GATEWAY_SERVICE "
            "must be a JSON object"
        )

    print(
        "Kong pipeline configuration found"
    )

    # --------------------------------------------------------
    # BASIC KONG CONFIG
    # --------------------------------------------------------

    runner_type = kong_config.get(
        "runnerType",
        "",
    )

    runner_tag = kong_config.get(
        "runnerTag",
        "",
    )

    oidc = kong_config.get(
        "oidc",
        "",
    )

    security_tools = kong_config.get(
        "securityTools",
        [],
    )

    artifact_tools = kong_config.get(
        "artifactTools",
        [],
    )

    # --------------------------------------------------------
    # SCM CONFIGURATION
    # --------------------------------------------------------

    scm = kong_config.get(
        "scm",
        {},
    )

    scm_provider = scm.get(
        "provider",
        "",
    )

    scm_org_user = scm.get(
        "orgUser",
        "",
    )

    scm_visibility = scm.get(
        "visibility",
        "",
    )

    scm_min_approvals = scm.get(
        "minApprovals",
        0,
    )

    repo_access_teams = scm.get(
        "repoAccessTeams",
        [],
    )

    review_teams = scm.get(
        "reviewTeams",
        [],
    )

    # --------------------------------------------------------
    # SONAR CONFIGURATION
    # --------------------------------------------------------

    sonar_host_url = get(
        kong_config,
        "securityToolConfigs.sonarscanner.SONAR_HOST_URL",
    )

    sonar_token = get(
        kong_config,
        "securityToolConfigs.sonarscanner.SONAR_TOKEN",
    )

    sonar_project_key = get(
        kong_config,
        "securityToolConfigs.sonarscanner.SONAR_PROJECT_KEY",
    )

    # --------------------------------------------------------
    # NEXUS CONFIGURATION
    # --------------------------------------------------------

    nexus_url = get(
        kong_config,
        "artifactToolConfigs.nexus.NEXUS_URL",
    ) or ""

    nexus_repository = get(
        kong_config,
        "artifactToolConfigs.nexus.NEXUS_REPOSITORY",
    ) or ""

    nexus_username = get(
        kong_config,
        "artifactToolConfigs.nexus.NEXUS_USERNAME",
    ) or ""

    nexus_password = get(
        kong_config,
        "artifactToolConfigs.nexus.NEXUS_PASSWORD",
    ) or ""

    # --------------------------------------------------------
    # ENVIRONMENT CONFIG
    # --------------------------------------------------------

    environment_config = get(
        kong_config,
        f"environmentConfigs.{environment}",
    )

    if not environment_config:
        fail(
            f"Kong environment '{environment}' "
            "is not configured"
        )

    if not isinstance(environment_config, dict):
        fail(
            f"environmentConfigs.{environment} "
            "must be a JSON object"
        )

    environment_label = environment_config.get(
        "label",
        "",
    )

    cr_required = environment_config.get(
        "crRequired",
        False,
    )

    environment_provider = environment_config.get(
        "provider",
        "",
    )

    environment_instances = environment_config.get(
        "instances",
        [],
    )

    # --------------------------------------------------------
    # KONG / KONNECT CONFIG
    # --------------------------------------------------------

    kong_environment_config = environment_config.get(
        "config",
        {},
    )

    if not isinstance(
        kong_environment_config,
        dict,
    ):
        fail(
            f"environmentConfigs.{environment}.config "
            "must be a JSON object"
        )

    kong_pat_token = kong_environment_config.get(
        "patToken",
        "",
    )

    kong_control_plane = kong_environment_config.get(
        "controlPlane",
        "",
    )

    kong_host_url = kong_environment_config.get(
        "hostUrl",
        "",
    )

    kong_deck_mode = kong_environment_config.get(
        "deckMode",
        "apply",
    )

    # --------------------------------------------------------
    # KONG DETAILS
    # --------------------------------------------------------

    kong_details = kong_config.get(
        "kongDetails",
        {},
    )

    kong_region = kong_details.get(
        "region",
        "",
    )

    kong_control_plane_id = kong_details.get(
        "controlPlaneId",
        "",
    )

    kong_pat = kong_details.get(
        "pat",
        "",
    )

    # --------------------------------------------------------
    # MASK SECRETS
    # --------------------------------------------------------

    #mask(kong_pat_token)
    mask(kong_pat)
    mask(sonar_token)
    mask(nexus_password)

    # --------------------------------------------------------
    # GITHUB OUTPUTS
    # --------------------------------------------------------

    outputs = {

        # Environment
        "environment": environment,
        "environment_label": environment_label,
        "cr_required": str(cr_required).lower(),
        "environment_provider": environment_provider,
        "environment_instances": environment_instances,

        # Runner
        "kong_runner_type": runner_type,
        "kong_runner_tag": runner_tag,
        "kong_oidc": oidc,

        # SCM
        "scm_provider": scm_provider,
        "scm_org_user": scm_org_user,
        "scm_visibility": scm_visibility,
        "scm_min_approvals": scm_min_approvals,
        "repo_access_teams": repo_access_teams,
        "review_teams": review_teams,

        # Security / artifacts
        "kong_security_tools": security_tools,
        "kong_artifact_tools": artifact_tools,

        # Sonar
        "sonar_host_url": sonar_host_url,
        "sonar_project_key": sonar_project_key,
        "sonar_token": sonar_token,

        # Nexus
        "nexus_url": nexus_url,
        "nexus_repository": nexus_repository,
        "nexus_username": nexus_username,
        "nexus_password": nexus_password,

        # Kong / Konnect
        "kong_pat_token": kong_pat_token,
        "kong_control_plane": kong_control_plane,
        "kong_host_url": kong_host_url,
        "kong_deck_mode": kong_deck_mode,

        # Kong details
        "kong_region": kong_region,
        "kong_control_plane_id": kong_control_plane_id,
        "kong_pat": kong_pat,
    }

    write_outputs(
        outputs=outputs,
        github_output=github_output,
    )

    # --------------------------------------------------------
    # SUMMARY
    # --------------------------------------------------------

    print("")
    print("==========================================")
    print("KONG CONFIGURATION LOADED")
    print("==========================================")

    print(f"Environment       : {environment}")
    print(f"Environment Label : {environment_label}")
    print(f"Provider           : {environment_provider}")
    print(f"CR Required        : {cr_required}")

    print("")
    print("Kong Configuration")
    print(f"Control Plane      : {kong_control_plane}")
    print(f"Host URL            : {kong_host_url}")
    print(f"Deck Mode           : {kong_deck_mode}")
    print(f"kong pat token      : {kong_pat_token}")

    print("")
    print("Runner")
    print(f"Runner Type         : {runner_type}")
    print(f"Runner Tag          : {runner_tag}")

    print("")
    print("Security")
    print(
        f"Security Tools      : "
        f"{', '.join(security_tools)}"
    )

    print("")
    print("Artifacts")
    print(
        f"Artifact Tools      : "
        f"{', '.join(artifact_tools)}"
    )

    print("")
    print("Sonar")
    print(f"Sonar URL            : {sonar_host_url}")
    print(f"Sonar Project       : {sonar_project_key}")
    print("Sonar Token         : ********")

    print("")
    print("Nexus")
    print(
        f"Nexus                : "
        f"{'configured' if nexus_url else 'not configured'}"
    )
    print(f"Nexus Repository     : {nexus_repository}")

    print("")
    print("SCM")
    print(f"SCM Provider         : {scm_provider}")
    print(f"SCM Organization     : {scm_org_user}")
    print(f"SCM Visibility      : {scm_visibility}")
    print(f"Minimum Approvals   : {scm_min_approvals}")

    print("==========================================")


if __name__ == "__main__":
    main()
