#!/usr/bin/env python3

"""
Pipeline Logs Service helpers for GitHub Actions stages.

Supports two modes:

  Subcommand mode (used by the reusable Apigee CI/CD workflow):

      python3 pipeline_logs.py stdin <stage_key> -- <step_key>
      python3 pipeline_logs.py event <stage_key> -- <step_key> \
          [--status STATUS] [--message MESSAGE]

  Legacy mode (runs a command and streams its output):

      python3 pipeline_logs.py <stage_key> -- <command> [args...]

Reporting is deliberately non-fatal so logging cannot break onboarding.

Required environment variables:

    PIPELINE_LOGS_URL
    TOKEN_ISSUER_URL
    CLIENT_ID
    CLIENT_SECRET
    ORGANIZATION_ID
    FLOW_CHANGE_ID

Optional:

    PL_PIPELINE_TYPE   Default: ONBOARDING
    FLOW_TYPE          Forwarded to events as flowType
    RESOURCE_ID        Forwarded to events as resourceId
    APIGEE_ORG         Forwarded to events as organizationId

    GITHUB_ACTOR / GITHUB_RUN_ID / GITHUB_SHA / GITHUB_REF_NAME
        Provided by GitHub Actions and forwarded to events as the
        `trigger` block. Read-only; no configuration needed.
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Optional

import requests


TOKEN_REFRESH_SECONDS = 240
HTTP_TIMEOUT = 10
LOG_CHUNK_SIZE = 200

# GitHub Actions job.status values -> ForgeSphere status values.
JOB_STATUS_MAP = {
    "success": "COMPLETED",
    "failure": "FAILED",
    "cancelled": "CANCELLED",
    "canceled": "CANCELLED",
}


class PipelineLogger:
    def __init__(self) -> None:
        # --- Service configuration ------------------------------------
        self.pipeline_logs_url = os.getenv("PIPELINE_LOGS_URL", "").rstrip("/")
        self.token_issuer_url = os.getenv("TOKEN_ISSUER_URL", "")
        self.client_id = os.getenv("CLIENT_ID", "")
        self.client_secret = os.getenv("CLIENT_SECRET", "")
        self.organization_id = os.getenv("ORGANIZATION_ID", "")
        self.flow_change_id = os.getenv("FLOW_CHANGE_ID", "")

        # Match the Bash script's "${PL_PIPELINE_TYPE:-ONBOARDING}" behavior.
        self.pipeline_type = os.getenv("PL_PIPELINE_TYPE", "") or "ONBOARDING"

        # --- Flow metadata (forwarded on every event) -----------------
        self.flow_type = os.getenv("FLOW_TYPE", "")
        self.resource_id = os.getenv("RESOURCE_ID", "")
        self.apigee_org = os.getenv("APIGEE_ORG", "")

        # --- Trigger metadata (built-in GH Actions env vars) ----------
        self.github_actor = os.getenv("GITHUB_ACTOR", "")
        self.github_run_id = os.getenv("GITHUB_RUN_ID", "")
        self.github_sha = os.getenv("GITHUB_SHA", "")
        self.github_branch = os.getenv("GITHUB_REF_NAME", "")

        self.token: Optional[str] = None
        self.last_token_refresh = 0.0

    # ------------------------------------------------------------------
    # Configuration
    # ------------------------------------------------------------------

    def configuration_available(self) -> bool:
        missing = []

        if not self.pipeline_logs_url:
            missing.append("PIPELINE_LOGS_URL")
        if not self.token_issuer_url:
            missing.append("TOKEN_ISSUER_URL")
        if not self.client_id:
            missing.append("CLIENT_ID")
        if not self.client_secret:
            missing.append("CLIENT_SECRET")
        if not self.organization_id:
            missing.append("ORGANIZATION_ID")
        if not self.flow_change_id:
            missing.append("FLOW_CHANGE_ID")

        if missing:
            print(
                "pipeline-logs disabled; missing configuration: "
                + " ".join(missing),
                file=sys.stderr,
            )
            return False

        return True

    # ------------------------------------------------------------------
    # OAuth token
    # ------------------------------------------------------------------

    def get_token(self) -> bool:
        if not self.configuration_available():
            return False

        try:
            response = requests.post(
                self.token_issuer_url,
                auth=(self.client_id, self.client_secret),
                data={
                    "grant_type": "client_credentials",
                    "audience": "probestack-api",
                    "organization_id": self.organization_id,
                    "scope": "cicd:config:read",
                },
                timeout=HTTP_TIMEOUT,
            )
            response.raise_for_status()

            payload = response.json()
            token = payload.get("access_token")

            if not token:
                print(
                    "pipeline-logs token response did not contain "
                    "access_token (ignored)",
                    file=sys.stderr,
                )
                return False

            self.token = token
            self.last_token_refresh = time.time()
            return True

        except Exception as exc:
            print(
                f"pipeline-logs token request failed (ignored): {exc}",
                file=sys.stderr,
            )
            return False

    # ------------------------------------------------------------------
    # API event
    # ------------------------------------------------------------------

    def event(self, body: dict) -> bool:
        if not self.token:
            return False

        url = f"{self.pipeline_logs_url}/v1/api/events"

        try:
            response = requests.post(
                url,
                headers={
                    "Authorization": f"Bearer {self.token}",
                    "Content-Type": "application/json",
                },
                json=body,
                timeout=HTTP_TIMEOUT,
            )
            response.raise_for_status()
            return True

        except requests.HTTPError as exc:
            # Print the API's response body so schema errors are visible.
            print(
                f"pipeline-logs call failed (ignored): {exc}",
                file=sys.stderr,
            )
            if exc.response is not None:
                print(
                    f"pipeline-logs response body: {exc.response.text}",
                    file=sys.stderr,
                )
            return False

        except Exception as exc:
            print(
                f"pipeline-logs call failed (ignored): {exc}",
                file=sys.stderr,
            )
            return False

    # ------------------------------------------------------------------
    # Common event envelope
    # ------------------------------------------------------------------

    def _envelope(self) -> dict:
        """
        Fields included on EVERY event, regardless of type.

        The `stepKey` field is deliberately omitted — the Pipeline Logs
        API rejects it with 400 (the Bash reference script never sends
        it either).
        """
        envelope: dict = {
            "flowChangeId": self.flow_change_id,
            "pipelineType": self.pipeline_type,
        }

        # Flow details — only include when actually known.
        if self.flow_type:
            envelope["flowType"] = self.flow_type
        if self.apigee_org:
            envelope["organizationId"] = self.apigee_org
        if self.resource_id:
            envelope["resourceId"] = self.resource_id

        # Trigger details — nested so the schema stays extensible.
        trigger: dict = {}
        if self.github_actor:
            trigger["actor"] = self.github_actor
        if self.github_run_id:
            trigger["runId"] = self.github_run_id
        if self.github_sha:
            trigger["sha"] = self.github_sha
        if self.github_branch:
            trigger["branch"] = self.github_branch

        if trigger:
            envelope["trigger"] = trigger

        return envelope

    # ------------------------------------------------------------------
    # Payload builders
    # ------------------------------------------------------------------

    def _status_payload(
        self,
        stage_key: str,
        status: str,
        message: str = "",
    ) -> dict:
        """
        Mirrors pl_stage_status() in pipeline_logs.sh, plus flow/trigger
        metadata on top.
        """
        body = self._envelope()
        body["stageKey"] = stage_key
        body["status"] = status

        if message:
            body["message"] = message
            if status == "FAILED":
                body["lines"] = [
                    {"level": "ERROR", "message": message}
                ]

        return body

    def _lines_payload(
        self,
        stage_key: str,
        lines: list[str],
    ) -> dict:
        """
        Mirrors the stream_logs() payload in pipeline_logs.sh, plus
        flow/trigger metadata on top.
        """
        body = self._envelope()
        body["stageKey"] = stage_key
        body["lines"] = [
            {"level": "INFO", "message": line}
            for line in lines
        ]
        return body

    # ------------------------------------------------------------------
    # Public senders
    # ------------------------------------------------------------------

    def stage_status(
        self,
        stage_key: str,
        status: str,
        message: str = "",
    ) -> bool:
        return self.event(
            self._status_payload(stage_key, status, message)
        )

    def send_lines(
        self,
        stage_key: str,
        lines: list[str],
    ) -> bool:
        if not lines:
            return True
        return self.event(self._lines_payload(stage_key, lines))

    # ------------------------------------------------------------------
    # Async log streamer (legacy mode)
    # ------------------------------------------------------------------

    def stream_logs(
        self,
        stage_key: str,
        logfile: Path,
        stop_event: threading.Event,
    ) -> None:
        sent = 0

        while True:
            now = time.time()
            if now - self.last_token_refresh >= TOKEN_REFRESH_SECONDS:
                self.get_token()

            try:
                if logfile.exists():
                    with logfile.open(
                        "r", encoding="utf-8", errors="replace"
                    ) as file:
                        lines = file.readlines()

                    total = len(lines)
                    if total > sent:
                        chunk = lines[sent : sent + LOG_CHUNK_SIZE]
                        chunk = [line.rstrip("\r\n") for line in chunk]
                        self.send_lines(stage_key, chunk)
                        sent += len(chunk)
                        continue

            except Exception as exc:
                print(
                    f"pipeline-logs stream failed (ignored): {exc}",
                    file=sys.stderr,
                )

            if stop_event.is_set():
                break

            time.sleep(3)

    # ------------------------------------------------------------------
    # Legacy mode: run a command, echo + stream its output
    # ------------------------------------------------------------------

    def run_logged_stage(
        self,
        stage_key: str,
        command: list[str],
    ) -> int:
        runner_temp = os.getenv("RUNNER_TEMP", "/tmp")
        log_dir = Path(runner_temp) / "pipeline-logs"
        logfile = log_dir / f"{stage_key}.log"

        log_dir.mkdir(parents=True, exist_ok=True)
        logfile.write_text("", encoding="utf-8")

        logging_enabled = self.get_token()

        if logging_enabled:
            self.stage_status(stage_key, "RUNNING")

        stop_event = threading.Event()
        streamer: Optional[threading.Thread] = None

        if logging_enabled:
            streamer = threading.Thread(
                target=self.stream_logs,
                args=(stage_key, logfile, stop_event),
                daemon=True,
            )
            streamer.start()

        result = 0

        try:
            print(f"Running stage: {stage_key}")
            print("Command: " + " ".join(command))

            with logfile.open("a", encoding="utf-8") as log_file:
                process = subprocess.Popen(
                    command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                )

                assert process.stdout is not None

                for line in process.stdout:
                    print(line, end="", flush=True)
                    log_file.write(line)
                    log_file.flush()

                result = process.wait()

        except Exception as exc:
            result = 1
            error_message = f"Stage execution failed: {exc}"
            print(error_message, file=sys.stderr)

            try:
                with logfile.open("a", encoding="utf-8") as log_file:
                    log_file.write(error_message + "\n")
            except Exception:
                pass

        finally:
            if logging_enabled:
                stop_event.set()
                if streamer:
                    streamer.join(timeout=15)

                self.flush_remaining_logs(stage_key, logfile)

                if result == 0:
                    self.get_token()
                    self.stage_status(stage_key, "COMPLETED")
                else:
                    self.get_token()
                    self.stage_status(
                        stage_key,
                        "FAILED",
                        f"Stage command exited with code {result}",
                    )

        return result

    # ------------------------------------------------------------------
    # Flush remaining logs
    # ------------------------------------------------------------------

    def flush_remaining_logs(
        self,
        stage_key: str,
        logfile: Path,
    ) -> None:
        try:
            if not logfile.exists():
                return

            with logfile.open(
                "r", encoding="utf-8", errors="replace"
            ) as file:
                lines = [line.rstrip("\r\n") for line in file]

            for index in range(0, len(lines), LOG_CHUNK_SIZE):
                chunk = lines[index : index + LOG_CHUNK_SIZE]
                self.send_lines(stage_key, chunk)

        except Exception as exc:
            print(
                f"pipeline-logs final flush failed (ignored): {exc}",
                file=sys.stderr,
            )


# ----------------------------------------------------------------------
# Subcommand: stdin
# ----------------------------------------------------------------------

def handle_stdin(
    logger: PipelineLogger,
    stage_key: str,
    step_key: str,
) -> int:
    """
    Reads lines from stdin, echoes them to stdout (so they appear in the
    GitHub Actions console), and batches them to the Pipeline Logs API.

    `step_key` is accepted for CLI compatibility with the reusable
    workflow but is NOT sent to the API — the API rejects it with 400.
    """
    logging_enabled = logger.get_token()

    if not logging_enabled:
        # Drain stdin so upstream writers don't get SIGPIPE.
        for line in sys.stdin:
            sys.stdout.write(line)
            sys.stdout.flush()
        return 0

    batch: list[str] = []
    last_refresh = time.time()

    try:
        for line in sys.stdin:
            sys.stdout.write(line)
            sys.stdout.flush()

            batch.append(line.rstrip("\r\n"))

            if len(batch) >= LOG_CHUNK_SIZE:
                logger.send_lines(stage_key, batch)
                batch = []

            now = time.time()
            if now - last_refresh >= TOKEN_REFRESH_SECONDS:
                logger.get_token()
                last_refresh = now

    except Exception as exc:
        print(
            f"pipeline-logs stdin handler failed (ignored): {exc}",
            file=sys.stderr,
        )

    if batch:
        logger.send_lines(stage_key, batch)

    return 0


# ----------------------------------------------------------------------
# Subcommand: event
# ----------------------------------------------------------------------

def handle_event(
    logger: PipelineLogger,
    stage_key: str,
    step_key: str,
    options: list[str],
) -> int:
    """
    Emits a status event to the Pipeline Logs API.
    `step_key` is accepted for CLI compatibility but not forwarded.
    """
    status = ""
    message = ""

    i = 0
    while i < len(options):
        arg = options[i]
        if arg == "--status" and i + 1 < len(options):
            status = options[i + 1]
            i += 2
        elif arg == "--message" and i + 1 < len(options):
            message = options[i + 1]
            i += 2
        else:
            i += 1

    if not status:
        status = "COMPLETED"

    # Normalise GitHub Actions job.status values (success/failure/...).
    status = JOB_STATUS_MAP.get(status.lower(), status)

    if not logger.get_token():
        return 0

    logger.stage_status(stage_key, status, message)
    return 0


# ----------------------------------------------------------------------
# Argument parsing helpers
# ----------------------------------------------------------------------

def _parse_stage_step(
    argv: list[str],
) -> tuple[Optional[str], Optional[str], list[str]]:
    """
    Parses `<stage_key> -- <step_key> [rest...]`.
    Returns (stage_key, step_key, rest) or (None, None, []) on error.
    """
    if len(argv) < 3:
        return None, None, []

    if argv[1] != "--":
        print(
            "Expected '--' after stage_key",
            file=sys.stderr,
        )
        return None, None, []

    return argv[0], argv[2], argv[3:]


# ----------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------

def _print_usage() -> None:
    print("Usage:", file=sys.stderr)
    print(
        "  python3 pipeline_logs.py stdin <stage_key> -- <step_key>",
        file=sys.stderr,
    )
    print(
        "  python3 pipeline_logs.py event <stage_key> -- <step_key> "
        "[--status STATUS] [--message MESSAGE]",
        file=sys.stderr,
    )
    print(
        "  python3 pipeline_logs.py <stage_key> -- <command> [args...]",
        file=sys.stderr,
    )


def main() -> int:
    if len(sys.argv) < 2:
        _print_usage()
        return 2

    subcommand = sys.argv[1]

    if subcommand == "stdin":
        stage_key, step_key, _ = _parse_stage_step(sys.argv[2:])
        if stage_key is None:
            _print_usage()
            return 2

        logger = PipelineLogger()
        return handle_stdin(logger, stage_key, step_key)

    if subcommand == "event":
        stage_key, step_key, rest = _parse_stage_step(sys.argv[2:])
        if stage_key is None:
            _print_usage()
            return 2

        logger = PipelineLogger()
        return handle_event(logger, stage_key, step_key, rest)

    # ------------------------------------------------------------------
    # Legacy mode: <stage_key> -- <command> [args...]
    # ------------------------------------------------------------------
    stage_key = sys.argv[1]

    if len(sys.argv) < 4:
        _print_usage()
        return 2

    if sys.argv[2] != "--":
        print(
            "Expected '--' after stage_key",
            file=sys.stderr,
        )
        return 2

    command = sys.argv[3:]
    if not command:
        print("No command specified", file=sys.stderr)
        return 2

    logger = PipelineLogger()
    return logger.run_logged_stage(stage_key, command)


if __name__ == "__main__":
    sys.exit(main())