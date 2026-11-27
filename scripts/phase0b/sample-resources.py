#!/usr/bin/env python3
"""Low-overhead /proc sampler for Phase 0C; emits JSON to stdout only."""
import argparse
import json
import platform
import re
import time
from datetime import datetime, timezone
from pathlib import Path


def keyed_file(path, names):
    result = {}
    try:
        for row in Path(path).read_text().splitlines():
            fields = row.split()
            if len(fields) > 1 and fields[0].rstrip(":") in names:
                result[fields[0].rstrip(":")] = int(fields[1])
    except (OSError, ValueError):
        pass
    return result


def pressure():
    result = {}
    for kind in ("cpu", "memory", "io"):
        path = Path("/proc/pressure") / kind
        try:
            result[kind] = path.read_text().splitlines()
        except OSError:
            result[kind] = None
    return result


def cpu_ticks():
    try:
        values = [int(value) for value in Path("/proc/stat").read_text().splitlines()[0].split()[1:]]
        return {"total": sum(values), "idle": values[3] + values[4]}
    except (OSError, ValueError, IndexError):
        return None


def disk_bytes():
    read = written = 0
    try:
        for device in Path("/sys/block").iterdir():
            if (device / "partition").exists():
                continue
            fields = (device / "stat").read_text().split()
            read += int(fields[2]) * 512
            written += int(fields[6]) * 512
    except (OSError, ValueError, IndexError):
        return None
    return {"read_bytes": read, "written_bytes": written}


def browser_pss_kib():
    total = count = 0
    try:
        for proc in Path("/proc").iterdir():
            if not proc.name.isdigit():
                continue
            try:
                name = (proc / "comm").read_text().strip()
                if not re.search(r"chrom|cage|labwc|weston", name, re.IGNORECASE):
                    continue
                pss = next((row.split()[1] for row in (proc / "smaps_rollup").read_text().splitlines() if row.startswith("Pss:")), None)
                if pss is not None:
                    total += int(pss)
                    count += 1
            except (OSError, ValueError, StopIteration):
                continue
    except OSError:
        pass
    return {"process_count": count, "summed_pss_kib": total}


def cgroup_memory():
    try:
        line = next(row for row in Path("/proc/self/cgroup").read_text().splitlines() if row.startswith("0::"))
        cgroup = Path("/sys/fs/cgroup") / line[3:].lstrip("/")
    except (OSError, StopIteration):
        return None
    values = {}
    for name in ("memory.current", "memory.peak", "memory.max", "memory.high"):
        try:
            raw = (cgroup / name).read_text().strip()
            values[name] = int(raw) if raw.isdigit() else raw
        except OSError:
            values[name] = None
    try:
        events = {}
        for row in (cgroup / "memory.events").read_text().splitlines():
            name, value = row.split()
            events[name] = int(value)
        values["memory.events"] = events
    except OSError:
        values["memory.events"] = None
    values["path"] = "redacted"
    return values


def thermal():
    values = {}
    for path in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
        try:
            values[path.parent.name] = round(int(path.read_text()) / 1000, 1)
        except (OSError, ValueError):
            values[path.parent.name] = None
    return values


def snapshot(include_pss):
    started = time.monotonic()
    memory = keyed_file("/proc/meminfo", {"MemTotal", "MemAvailable", "SwapTotal", "SwapFree"})
    vm = keyed_file("/proc/vmstat", {"pswpin", "pswpout", "pgmajfault", "oom_kill"})
    result = {
        "monotonic_seconds": time.monotonic(),
        "memory_kib": memory,
        "vmstat_pages_or_events": vm,
        "cpu_ticks": cpu_ticks(),
        "pressure": pressure(),
        "disk": disk_bytes(),
        "cgroup_memory": cgroup_memory(),
        "thermal_c": thermal(),
    }
    if include_pss:
        result["browser_compositor_pss"] = browser_pss_kib()
    result["sampler_read_seconds"] = round(time.monotonic() - started, 4)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration", type=int, default=300, help="sampling duration, 1..86400 seconds")
    parser.add_argument("--interval", type=float, default=5.0, help="sampling interval in seconds")
    parser.add_argument("--pss-every", type=int, default=3, help="take PSS every N samples; 0 disables PSS")
    args = parser.parse_args()
    if not 1 <= args.duration <= 86400 or args.interval <= 0 or args.pss_every < 0:
        parser.error("invalid duration, interval, or pss-every value")

    start = time.monotonic()
    end = start + args.duration
    samples = []
    while True:
        include_pss = args.pss_every > 0 and len(samples) % args.pss_every == 0
        samples.append(snapshot(include_pss))
        now = time.monotonic()
        if now >= end:
            break
        time.sleep(min(args.interval, end - now))

    cpu_busy = []
    for old, new in zip(samples, samples[1:]):
        a, b = old["cpu_ticks"], new["cpu_ticks"]
        if a and b and b["total"] > a["total"]:
            total = b["total"] - a["total"]
            idle = b["idle"] - a["idle"]
            cpu_busy.append(round(100 * (total - idle) / total, 2))
    output = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "environment": {"os": platform.system(), "architecture": platform.machine(), "kernel": platform.release()},
        "command": f"sample-resources.py --duration {args.duration} --interval {args.interval} --pss-every {args.pss_every}",
        "duration_seconds": round(time.monotonic() - start, 2),
        "interval_seconds": args.interval,
        "sample_count": len(samples),
        "cpu_busy_percent": cpu_busy,
        "limitations": [
            "The sampler's cgroup may not be the browser service cgroup; path is redacted.",
            "PSS is summed only for readable Chromium/compositor processes and sampled every N records.",
            "Disk bytes aggregate whole block devices, excluding partitions; per-service attribution is unavailable.",
            "PSI is null when unavailable; short idle data is not a workload result.",
        ],
        "samples": samples,
    }
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
