#!/usr/bin/env python3
"""Summarize an apt-get -s plan using the active disposable apt cache."""
import json
import re
import subprocess
import sys
from pathlib import Path


text = Path(sys.argv[1]).read_text(errors="replace")
packages = []
for line in text.splitlines():
    match = re.match(r"^Inst\s+(\S+)(?:\s+\[[^]]+\])?\s+\((\S+)", line)
    if match:
        packages.append((match.group(1), match.group(2)))

installed_kib = download_bytes = unknown_sizes = 0
details = []
for package, version in packages:
    result = subprocess.run(["apt-cache", "show", f"{package}={version}"], capture_output=True, text=True, check=False)
    fields = {}
    for row in result.stdout.splitlines():
        if ": " in row:
            key, value = row.split(": ", 1)
            if key in {"Installed-Size", "Size"} and key not in fields:
                fields[key] = value
    if "Installed-Size" not in fields or "Size" not in fields:
        unknown_sizes += 1
    else:
        installed_kib += int(fields["Installed-Size"])
        download_bytes += int(fields["Size"])
    details.append({"package": package, "version": version, "installed_kib": fields.get("Installed-Size"), "download_bytes": fields.get("Size")})

summary = {
    "install_count": len(packages),
    "upgrade_count": sum(1 for row in text.splitlines() if row.startswith("Inst ") and " [" in row),
    "remove_count": sum(1 for row in text.splitlines() if row.startswith("Remv ")),
    "estimated_installed_kib": installed_kib,
    "estimated_download_bytes": download_bytes,
    "packages_without_size_metadata": unknown_sizes,
    "packages": details,
}
print(json.dumps(summary, indent=2, sort_keys=True))
