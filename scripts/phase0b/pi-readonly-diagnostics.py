#!/usr/bin/env python3
"""Sanitized, read-only Raspberry Pi capability inventory for Phase 0B."""
import json
import os
import platform
import re
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path


def text(path):
    try:
        return Path(path).read_text(errors="replace").strip()
    except OSError:
        return None


def command(args, timeout=8):
    if not shutil.which(args[0]):
        return None
    try:
        return subprocess.run(args, check=False, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return None


def meminfo():
    result = {}
    for line in (text("/proc/meminfo") or "").splitlines():
        match = re.match(r"^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)", line)
        if match:
            result[match.group(1)] = int(match.group(2))
    return result


def vmstat():
    result = {}
    for line in (text("/proc/vmstat") or "").splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] in {"pswpin", "pswpout", "pgmajfault", "oom_kill"}:
            result[parts[0]] = int(parts[1])
    return result


def psi():
    result = {}
    for kind in ("cpu", "memory", "io"):
        content = text(f"/proc/pressure/{kind}")
        result[kind] = content.splitlines() if content is not None else None
    return result


def sample_five_seconds():
    before = vmstat()
    samples = []
    started = time.monotonic()
    for index in range(6):
        mem = meminfo()
        samples.append({"mem_available_kib": mem.get("MemAvailable"), "swap_free_kib": mem.get("SwapFree")})
        if index < 5:
            time.sleep(1)
    elapsed = round(time.monotonic() - started, 2)
    after = vmstat()
    return {
        "duration_seconds": elapsed,
        "interval_seconds": 1,
        "samples": samples,
        "swap_page_deltas": {key: after.get(key, 0) - before.get(key, 0) for key in ("pswpin", "pswpout")},
        "major_fault_delta": after.get("pgmajfault", 0) - before.get("pgmajfault", 0),
        "oom_kill_delta": after.get("oom_kill", 0) - before.get("oom_kill", 0),
    }


def cgroup():
    result = {"version2": Path("/sys/fs/cgroup/cgroup.controllers").is_file()}
    if not result["version2"]:
        return result
    result["controllers"] = (text("/sys/fs/cgroup/cgroup.controllers") or "").split()
    result["subtree_control"] = (text("/sys/fs/cgroup/cgroup.subtree_control") or "").split()
    for name in ("memory.current", "memory.peak", "memory.max", "memory.high", "memory.events", "cpu.max", "io.stat"):
        result[name] = text(f"/sys/fs/cgroup/{name}")
    # Do not emit the cgroup path: it can contain service or user names.
    result["self_cgroup_path"] = "redacted" if text("/proc/self/cgroup") else None
    return result


def services():
    names = (
        "vaultwarden.service", "telegram-media-downloader.service", "cloudflared.service",
        "docker.service", "containerd.service", "avahi-daemon.service", "NetworkManager.service",
    )
    result = {}
    for name in names:
        value = command(["systemctl", "is-active", name])
        result[name] = value.splitlines()[0] if value else "unknown"
    failed = command(["systemctl", "--failed", "--no-legend", "--no-pager"])
    result["failed_unit_count"] = len(failed.splitlines()) if failed else 0
    docker_rows = command(["docker", "ps", "--format", "{{.Names}}|{{.Status}}"])
    result["running_container_count"] = len(docker_rows.splitlines()) if docker_rows else 0
    categories = {
        "vaultwarden": re.compile(r"vaultwarden", re.IGNORECASE),
        "telegram_media_downloader": re.compile(r"telegram|tgdl", re.IGNORECASE),
        "cloudflare_tunnel": re.compile(r"cloudflared|cloudflare", re.IGNORECASE),
    }
    for label, pattern in categories.items():
        matches = [row.split("|", 1)[1] for row in (docker_rows or "").splitlines() if pattern.search(row.split("|", 1)[0])]
        result[f"container_{label}"] = "healthy" if any("healthy" in state.lower() for state in matches) else ("running_no_healthcheck" if matches else "not_found_or_not_containerized")
    return result


def listeners():
    raw = command(["ss", "-ltnH"])
    if raw is None:
        return None
    results = set()
    for line in raw.splitlines():
        fields = line.split()
        if len(fields) < 4:
            continue
        local = fields[3]
        address, _, port = local.rpartition(":")
        if not port.isdigit():
            continue
        if address in {"127.0.0.1", "[::1]", "::1"}:
            scope = "loopback"
        elif address in {"0.0.0.0", "*", "[::]", "::"}:
            scope = "wildcard"
        else:
            scope = "non_loopback"
        results.add((scope, int(port)))
    return [{"scope": scope, "port": port} for scope, port in sorted(results)]


def graphics():
    devices = []
    for pattern in ("/dev/dri/*", "/dev/video*"):
        devices.extend(Path("/").glob(pattern.lstrip("/")))
    connectors = {}
    for status_path in Path("/sys/class/drm").glob("card*-*/status"):
        name = status_path.parent.name
        connectors[name] = {
            "status": text(status_path),
            "modes": (text(status_path.parent / "modes") or "").splitlines(),
        }
    video_names = {}
    for name_path in Path("/sys/class/video4linux").glob("video*/name"):
        video_names[name_path.parent.name] = text(name_path)
    thermal = {}
    for temp_path in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
        zone = temp_path.parent.name
        try:
            thermal[zone] = round(int(text(temp_path)) / 1000, 1)
        except (TypeError, ValueError):
            thermal[zone] = None
    return {
        "device_nodes": sorted(path.name for path in devices),
        "drm_connectors": connectors,
        "video_devices": video_names,
        "thermal_c": thermal,
        "vcgencmd_throttled": command(["vcgencmd", "get_throttled"]),
    }


def main():
    started = time.monotonic()
    os_release = {}
    for row in (text("/etc/os-release") or "").splitlines():
        if "=" in row:
            key, value = row.split("=", 1)
            if key in {"ID", "VERSION_ID", "VERSION_CODENAME"}:
                os_release[key] = value.strip('"')
    model = text("/proc/device-tree/model")
    output = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "environment": {"os": os_release, "architecture": platform.machine(), "kernel": platform.release(), "model": model},
        "command": "scripts/phase0b/pi-readonly-diagnostics.py",
        "duration_seconds": None,
        "result": "VERIFIED",
        "read_only": True,
        "memory_kib": meminfo(),
        "pressure": psi(),
        "cgroup_v2": cgroup(),
        "systemd_version": (command(["systemctl", "--version"]) or "unavailable").splitlines()[0],
        "systemd_slice_resource_properties": command([
            "systemctl", "show", "system.slice", "-p", "ControlGroup", "-p", "MemoryAccounting",
            "-p", "MemoryCurrent", "-p", "MemoryHigh", "-p", "MemoryMax", "-p", "CPUAccounting", "-p", "IOAccounting", "--no-pager",
        ]),
        "service_health": services(),
        "listening_sockets": listeners(),
        "graphics_video": graphics(),
        "five_second_sample": sample_five_seconds(),
        "limitations": [
            "Read-only idle/unspecified-workload snapshot; not a playback benchmark.",
            "Listener addresses, hostnames, cgroup paths, container names and process command lines are omitted.",
            "Package databases are not queried or modified; no packages are installed.",
            "Run with adequate read permissions; missing signals remain null/unavailable.",
        ],
    }
    output["duration_seconds"] = round(time.monotonic() - started, 2)
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
