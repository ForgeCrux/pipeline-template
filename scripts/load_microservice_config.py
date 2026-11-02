#!/usr/bin/env python3
"""
Load ForgeSphere Microservice CI/CD Configuration (v2 effective-config).

Outputs (to $GITHUB_OUTPUT):
    registry_url, registry_username, registry_password
    sonar_host_url, sonar_token, sonar_project_key
    nexus_url, nexus_username, nexus_password, nexus_repository
    workload_identity_provider, service_account, gke_location
    gitops_repo_url, gitops_repo_branch
    argocd_server, argocd_project
    merge_branch
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def fail(m):
    print(f"ERROR: {m}", file=sys.stderr)
    sys.exit(1)


def mask(v):
    if v:
        print(f"::add-mask::{v}")


def base_url(v):
    v = v.strip().rstrip("/")
    return v.split("/v1/api")[0] if "/v1/api" in v else v


def fetch(config_url, app_id, token, resource_type, env_group):
    params = {"resourceType": resource_type, "environmentGroup": env_group}
    url = (
        f"{base_url(config_url)}/internal/v2/cicd/applications/"
        f"{urllib.parse.quote(app_id, safe='')}/effective-config?"
        f"{urllib.parse.urlencode(params)}"
    )
    print(f"GET {url}")
    req = urllib.request.Request(
        url, method="GET",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            body = r.read()
    except urllib.error.HTTPError as exc:
        rb = ""
        try:
            rb = exc.read().decode("utf-8", errors="replace")
        except Exception:
            pass
        print(rb)
        fail(f"ForgeSphere CI/CD configuration request failed (HTTP {exc.code})")
    except Exception as exc:
        fail(f"Unexpected error: {exc}")

    payload = json.loads(body)
    cfg = payload.get("data", payload) if isinstance(payload, dict) else None
    if not isinstance(cfg, dict):
        fail("ForgeSphere CI/CD configuration must be a JSON object")
    return cfg


def write_outputs(outputs, github_output):
    if not github_output:
        print("WARNING: GITHUB_OUTPUT not set")
        for k, v in outputs.items():
            if k in {"registry_password", "sonar_token", "nexus_password"}:
                continue
            print(f"{k}={v}")
        return
    with open(github_output, "a", encoding="utf-8") as f:
        for k, v in outputs.items():
            f.write(f"{k}={'' if v is None else v}\n")


def main():
    config_url = os.environ.get("CICD_CONFIG_URL", "").strip()
    config_id = os.environ.get("CICD_CONFIG_ID", "").strip()
    token = os.environ.get("SERVICE_ACCESS_TOKEN", "").strip()
    env = os.environ.get("ENVIRONMENT", "dev").strip().upper()
    service = os.environ.get("SERVICE_NAME", "").strip()
    github_output = os.environ.get("GITHUB_OUTPUT")

    for name, val in (("CICD_CONFIG_URL", config_url), ("CICD_CONFIG_ID", config_id),
                      ("SERVICE_ACCESS_TOKEN", token), ("SERVICE_NAME", service)):
        if not val:
            fail(f"{name} must be set")

    mask(token)
    cfg = fetch(config_url, config_id, token, "microservice", env)

    tools = cfg.get("tools") or {}

    # Registry
    artifact = tools.get("artifact") or {}
    registry_conf = (artifact.get("configuration") or {})
    registry_creds = (artifact.get("credentials") or {})
    registry_url = registry_conf.get("baseUrl") or ""
    registry_username = registry_conf.get("username") or ""
    registry_password = registry_creds.get("password") or ""

    # Sonar
    sonar = (tools.get("security") or {}).get("SONARQUBE") or {}
    sonar_host_url = (sonar.get("configuration") or {}).get("baseUrl") or ""
    sonar_token = (sonar.get("credentials") or {}).get("token") or ""
    sonar_project_key = service

    # Nexus (may be same as registry or separate)
    nexus_url = registry_url
    nexus_username = registry_username
    nexus_password = registry_password
    nexus_repository = registry_conf.get("repository") or ""

    # GCP / GKE
    deployment_target = cfg.get("deploymentTarget") or {}
    dt_conf = deployment_target.get("configuration") or {}
    workload_identity_provider = dt_conf.get("workloadIdentityProvider") or ""
    service_account = dt_conf.get("serviceAccountEmail") or ""
    gke_location = dt_conf.get("location") or dt_conf.get("region") or "us-central1"

    # GitOps
    gitops = cfg.get("gitops") or {}
    gitops_repo_url = gitops.get("repoUrl") or ""
    gitops_repo_branch = gitops.get("branch") or "main"

    # ArgoCD
    argocd = cfg.get("argocd") or {}
    argocd_server = argocd.get("server") or ""
    argocd_project = argocd.get("project") or "default"

    # Branch strategy
    branches = (cfg.get("branchingStrategy") or {}).get("branches") or []
    merge_branch = next((b["name"] for b in branches if b.get("tag") == "merge"), "")

    mask(registry_password)
    mask(sonar_token)
    mask(nexus_password)

    write_outputs({
        "registry_url": registry_url,
        "registry_username": registry_username,
        "registry_password": registry_password,
        "sonar_host_url": sonar_host_url,
        "sonar_token": sonar_token,
        "sonar_project_key": sonar_project_key,
        "nexus_url": nexus_url,
        "nexus_username": nexus_username,
        "nexus_password": nexus_password,
        "nexus_repository": nexus_repository,
        "workload_identity_provider": workload_identity_provider,
        "service_account": service_account,
        "gke_location": gke_location,
        "gitops_repo_url": gitops_repo_url,
        "gitops_repo_branch": gitops_repo_branch,
        "argocd_server": argocd_server,
        "argocd_project": argocd_project,
        "merge_branch": merge_branch,
    }, github_output)

    print("==========================================")
    print("MICROSERVICE CONFIG LOADED")
    print("==========================================")
    print(f"registry_url    : {registry_url or '<empty>'}")
    print(f"sonar_host_url  : {sonar_host_url or '<empty>'}")
    print(f"gitops_repo_url : {gitops_repo_url or '<empty — will be created>'}")
    print(f"argocd_server   : {argocd_server or '<empty>'}")
    print(f"gke_location    : {gke_location}")
    print(f"merge_branch    : {merge_branch or '<empty>'}")
    print("==========================================")


if __name__ == "__main__":
    main()