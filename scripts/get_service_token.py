#!/usr/bin/env python3

import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

def get_required_env(name: str) -> str:
    """Read a required environment variable."""
    value = os.getenv(name)

    if not value:
        print(f"ERROR: Required environment variable '{name}' is missing.")
        sys.exit(1)

    return value

def main() -> None:
    # ============================================================
    # GITHUB ORGANIZATION SECRET VALUES
    # ============================================================
    token_url = get_required_env("PROB_SERVICE_TOKEN_URL")
    client_id = get_required_env("PROB_SERVICE_TOKEN_CLIENT_ID")
    client_secret = get_required_env("PROB_SERVICE_TOKEN_CLIENT_SECRET")
    tenant_id = get_required_env("PROB_SERVICE_TOKEN_TENANT_ID")

    # These can remain fixed/default unless your token API
    # requires different values.
    audience = os.getenv(
        "PROB_SERVICE_TOKEN_AUDIENCE",
        "probestack-api",
    )

    scope = os.getenv(
        "PROB_SERVICE_TOKEN_SCOPE",
        "cicd:config:read",
    )

    # ============================================================
    # BASIC AUTH
    # client_id:client_secret
    # ============================================================
    credentials = f"{client_id}:{client_secret}"

    basic_auth = base64.b64encode(
        credentials.encode("utf-8")
    ).decode("ascii")

    # ============================================================
    # TOKEN REQUEST
    # ============================================================
    form_data = {
        "grant_type": "client_credentials",
        "audience": audience,
        "organization_id": tenant_id,
        "scope": scope,
    }

    request_body = urllib.parse.urlencode(form_data).encode("utf-8")

    request = urllib.request.Request(
        token_url,
        data=request_body,
        method="POST",
        headers={
            "Authorization": f"Basic {basic_auth}",
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
        },
    )

    print("==========================================")
    print("FORGESPHERE SERVICE TOKEN")
    print("==========================================")
    print(f"Token URL       : {token_url}")
    print(f"Client ID       : {client_id}")
    print(f"Tenant ID       : {tenant_id}")
    print(f"Audience        : {audience}")
    print(f"Scope           : {scope}")
    print("==========================================")

    # ============================================================
    # CALL TOKEN API
    # ============================================================
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            http_status = response.status
            response_body = response.read().decode("utf-8")

    except urllib.error.HTTPError as exc:
        response_body = exc.read().decode(
            "utf-8",
            errors="replace",
        )

        print(
            f"ERROR: Service token API returned HTTP {exc.code}"
        )

        try:
            error_response = json.loads(response_body)
            print(json.dumps(error_response, indent=2))
        except json.JSONDecodeError:
            print(response_body)

        sys.exit(1)

    except urllib.error.URLError as exc:
        print(f"ERROR: Unable to connect to token service: {exc}")
        sys.exit(1)

    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}")
        sys.exit(1)

    print(f"Service Token HTTP Status: {http_status}")

    # ============================================================
    # VALIDATE HTTP RESPONSE
    # ============================================================
    if http_status < 200 or http_status >= 300:
        print("ERROR: Failed to obtain ForgeSphere service token")
        print(response_body)
        sys.exit(1)

    # ============================================================
    # PARSE RESPONSE
    # ============================================================
    try:
        token_response = json.loads(response_body)

    except json.JSONDecodeError:
        print("ERROR: Token service returned invalid JSON")
        print(response_body)
        sys.exit(1)

    access_token = token_response.get("access_token")

    if not access_token:
        print(
            "ERROR: 'access_token' is missing "
            "from token service response"
        )

        print(
            json.dumps(
                token_response,
                indent=2,
            )
        )

        sys.exit(1)

    # ============================================================
    # MASK TOKEN IN GITHUB ACTIONS
    # ============================================================
    print(f"::add-mask::{access_token}")

    # ============================================================
    # EXPORT TOKEN TO GITHUB ACTIONS
    # ============================================================
    github_output = os.getenv("GITHUB_OUTPUT")

    if not github_output:
        print("ERROR: GITHUB_OUTPUT environment variable is missing.")
        sys.exit(1)

    with open(
        github_output,
        "a",
        encoding="utf-8",
    ) as output:

        output.write(
            f"access_token={access_token}\n"
        )

    print("ForgeSphere service token obtained successfully.")

    # ============================================================
    # OPTIONAL RESPONSE INFORMATION
    # ============================================================
    token_type = token_response.get(
        "token_type",
        "Bearer",
    )

    expires_in = token_response.get("expires_in")

    print(f"Token Type      : {token_type}")

    if expires_in is not None:
        print(f"Expires In      : {expires_in} seconds")


if __name__ == "__main__":
    main()
