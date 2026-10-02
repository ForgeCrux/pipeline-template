#!/usr/bin/env python3

import json
import os
import sys
import time
import threading
import queue
import urllib.request
import urllib.error


EXECUTION_ID = os.getenv("EXECUTION_ID", "")
API_URL = os.getenv("EXECUTION_LOG_API_URL", "")
API_TOKEN = os.getenv("EXECUTION_LOG_API_TOKEN", "")

STAGE = os.getenv("LOG_STAGE", "UNKNOWN")
STEP = os.getenv("LOG_STEP", "UNKNOWN")

BUFFER_SIZE = int(os.getenv("LOG_BUFFER_SIZE", "50"))
FLUSH_INTERVAL = float(os.getenv("LOG_FLUSH_INTERVAL", "2"))

LOG_QUEUE = queue.Queue()
STOP_EVENT = threading.Event()


def build_payload(logs, sequence):
    return {
        "execution_id": EXECUTION_ID,
        "stage": STAGE,
        "step": STEP,
        "stream": "stdout_stderr",
        "logs": logs,
        "log_sequence": sequence,

        "repository": os.getenv("GITHUB_REPOSITORY", ""),
        "workflow": os.getenv("GITHUB_WORKFLOW", ""),
        "run_id": os.getenv("GITHUB_RUN_ID", ""),
        "run_attempt": os.getenv("GITHUB_RUN_ATTEMPT", ""),
        "commit_sha": os.getenv("GITHUB_SHA", ""),
        "branch": os.getenv("GITHUB_REF_NAME", ""),
    }


def send_to_api(payload):
    if not API_URL or not EXECUTION_ID:
        return

    body = json.dumps(payload).encode("utf-8")

    request = urllib.request.Request(
        API_URL,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {API_TOKEN}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            response.read()

    except Exception:
        # Never fail the GitHub workflow because logging failed.
        pass


def uploader():
    sequence = 0

    while not STOP_EVENT.is_set() or not LOG_QUEUE.empty():

        try:
            batch = LOG_QUEUE.get(timeout=0.5)
        except queue.Empty:
            continue

        if not batch:
            continue

        sequence += 1

        payload = build_payload(
            logs=batch,
            sequence=sequence,
        )

        send_to_api(payload)


def main():

    if not API_URL or not EXECUTION_ID:
        # Logger disabled - simply forward stdin to stdout.
        for line in sys.stdin:
            print(line, end="", flush=True)

        return 0

    worker = threading.Thread(
        target=uploader,
        daemon=True,
    )

    worker.start()

    buffer = []
    last_flush = time.monotonic()

    try:

        for line in sys.stdin:

            # Always preserve GitHub Actions console output.
            print(line, end="", flush=True)

            buffer.append(line)

            elapsed = time.monotonic() - last_flush

            if (
                len(buffer) >= BUFFER_SIZE
                or elapsed >= FLUSH_INTERVAL
            ):
                LOG_QUEUE.put("".join(buffer))

                buffer.clear()
                last_flush = time.monotonic()

    finally:

        # Send remaining logs.
        if buffer:
            LOG_QUEUE.put("".join(buffer))

        STOP_EVENT.set()

        # Small grace period for queued HTTP requests.
        worker.join(timeout=5)

    return 0


if __name__ == "__main__":
    sys.exit(main())
