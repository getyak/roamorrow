"""Capture a bounded stack sample after an owned CI app stops reporting idle."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time
import uuid


def app_pid(listing):
    for line in listing.splitlines():
        fields = line.split()
        if len(fields) >= 3 and fields[0].isdigit() and fields[2].startswith("UIKitApplication:com.solocompass.app["):
            return int(fields[0]) if int(fields[0]) > 0 else None
    return None


def idle_timeout(log):
    return "App event loop idle notification not received" in log


def watch(device, log, output):
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Hang capture is restricted to an owned CI runner")
    uuid.UUID(device)
    runner = Path(os.environ["RUNNER_TEMP"]).resolve(strict=True)
    workspace = Path(os.environ["GITHUB_WORKSPACE"]).resolve(strict=True)
    output = output.resolve()
    log = log.resolve()
    if not output.is_relative_to(runner) or not log.is_relative_to(workspace):
        raise ValueError("Diagnostics must stay within this runner and checkout")
    output.mkdir(parents=True, exist_ok=True)
    active = None

    def stop(*_):
        if active is not None and active.poll() is None:
            os.killpg(active.pid, signal.SIGTERM)
            try:
                active.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(active.pid, signal.SIGKILL)
                active.wait()
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    captured = False
    deadline = time.monotonic() + 1800
    while time.monotonic() < deadline:
        if not captured and log.exists() and idle_timeout(log.read_text(errors="replace")[-262144:]):
            listing = subprocess.run(["xcrun", "simctl", "spawn", device, "launchctl", "list"],
                                     capture_output=True, text=True, timeout=10, check=True).stdout
            pid = app_pid(listing)
            if pid is not None:
                command = subprocess.run(["ps", "-p", str(pid), "-o", "command="],
                                         capture_output=True, text=True, timeout=5, check=True).stdout.strip()
                expected = f"/CoreSimulator/Devices/{device}/"
                if expected not in command or not re.search(r"/SoloCompass\.app/SoloCompass(?:\s|$)", command):
                    raise ValueError("Refusing to sample a process outside the selected CI app")
                with (output / "sample-command.log").open("w") as stream:
                    active = subprocess.Popen(["sample", str(pid), "1", "10", "-file", str(output / "app-main-thread.txt")],
                                              stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
                    try:
                        # Sampling completes quickly; cold SDK symbol processing
                        # can take longer than the original 15-second budget.
                        status = active.wait(timeout=45)
                    except subprocess.TimeoutExpired:
                        os.killpg(active.pid, signal.SIGKILL)
                        active.wait()
                        status = -9
                (output / "capture.json").write_text(json.dumps({"pid": pid, "device": device,
                    "head": os.environ.get("CHAT_PR_HEAD_SHA"), "sample_exit": status,
                    "sample_seconds": 1, "symbolication_timeout_seconds": 45,
                    "trigger": "XCTest reported missing app-idle notification",
                    "scope": "CI app stack symbols only; no message content or memory dump"}, indent=2) + "\n")
                captured = True
                active = None
        time.sleep(2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    watch(args.device, args.log, args.output)
