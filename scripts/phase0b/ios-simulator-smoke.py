#!/usr/bin/env python3
"""Build, install, launch, and clean up the disposable iOS simulator shell."""
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "prototypes/host-first/ios-swift-app.xcodeproj"
BUNDLE = "dev.pitv.phase0b.hostfirst"


def run(args, timeout=30):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)


started = time.monotonic()
derived = tempfile.mkdtemp(prefix="pitv-phase0b-ios-")
simulator_id = None
simulator_name = ""
started_here = False
result = "FAILED"
checks = {}
limitations = [
    "This is a SwiftUI shell launch test; Bonjour permission UX, pairing, WSS, QR scanning, and phone hardware were not exercised."
]
try:
    devices = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "--json"]).stdout)
    available = [d for group in devices["devices"].values() for d in group if d.get("isAvailable") and re.match(r"^iPhone", d.get("name", ""))]
    if not available:
        raise RuntimeError("no available iPhone Simulator device")
    selected = next((d for d in available if d.get("state") == "Booted"), available[0])
    simulator_id = selected["udid"]
    simulator_name = selected["name"]
    started_here = selected.get("state") != "Booted"

    build = run([
        "xcodebuild", "-quiet", "-project", str(PROJECT), "-scheme", "HostFirstRemote",
        "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", derived,
        "CODE_SIGNING_ALLOWED=NO", "build",
    ])
    if build.returncode:
        raise RuntimeError("xcodebuild failed; full local build log intentionally omitted")
    app = Path(derived) / "Build/Products/Debug-iphonesimulator/HostFirstRemote.app"
    if not app.is_dir():
        raise RuntimeError("simulator app artifact missing")
    checks["build"] = "PASS"

    if started_here:
        boot = run(["xcrun", "simctl", "boot", simulator_id])
        if boot.returncode and "current state: Booted" not in boot.stderr:
            raise RuntimeError("simulator boot failed")
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            state = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "--json"]).stdout)
            selected_state = next((d["state"] for group in state["devices"].values() for d in group if d.get("udid") == simulator_id), "")
            if selected_state == "Booted":
                break
            time.sleep(1)
        else:
            raise RuntimeError("simulator did not reach Booted state")
    install = run(["xcrun", "simctl", "install", simulator_id, str(app)])
    if install.returncode:
        raise RuntimeError("simulator install failed")
    launch = run(["xcrun", "simctl", "launch", simulator_id, BUNDLE])
    if launch.returncode or BUNDLE not in launch.stdout:
        raise RuntimeError("simulator app launch failed")
    checks["simulator_install_launch"] = "PASS"
    result = "VERIFIED"
except subprocess.TimeoutExpired as error:
    result = "BLOCKED"
    action = error.cmd[2] if isinstance(error.cmd, list) and len(error.cmd) > 2 else "simulator command"
    checks["timeout"] = action
except (KeyError, OSError, RuntimeError, json.JSONDecodeError):
    checks["error"] = "build or simulator operation failed; private command details omitted"
finally:
    if simulator_id:
        try:
            terminate = run(["xcrun", "simctl", "terminate", simulator_id, BUNDLE], timeout=10)
            checks["terminate_cleanup"] = "PASS" if terminate.returncode == 0 else "UNAVAILABLE"
        except subprocess.TimeoutExpired:
            checks["terminate_cleanup"] = "TIMEOUT"
        if started_here:
            try:
                shutdown = run(["xcrun", "simctl", "shutdown", simulator_id], timeout=20)
                checks["shutdown_cleanup"] = "PASS" if shutdown.returncode == 0 else "UNAVAILABLE"
            except subprocess.TimeoutExpired:
                checks["shutdown_cleanup"] = "TIMEOUT"
    shutil.rmtree(derived, ignore_errors=True)

print(json.dumps({
    "timestamp_utc": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "environment": "Xcode 27.2; iOS Simulator 27.2; Apple Silicon macOS",
    "command": "python3 scripts/phase0b/ios-simulator-smoke.py",
    "duration_seconds": round(time.monotonic() - started, 2),
    "result": result,
    "simulator_model": simulator_name,
    "checks": checks,
    "limitations": limitations,
}, indent=2))
if result != "VERIFIED":
    raise SystemExit(1)
