#!/usr/bin/env python3
"""Check local design links and inventory/flow traceability."""
import re
import sys
from pathlib import Path

base = Path(__file__).resolve().parent
errors = []
files = list(base.glob('*.md')) + [base.parent / 'planning/session-1c3a-completion.md']
for path in files:
    if not path.exists():
        errors.append(f'missing {path}')
        continue
    for link in re.findall(r'\]\(([^)]+)\)', path.read_text()):
        target = link.split('#', 1)[0]
        if target and not re.match(r'\w+://|mailto:', target) and not (path.parent / target).exists():
            errors.append(f'{path.name}: missing {link}')
inv = (base / 'SCREEN_INVENTORY.md').read_text()
rows = re.findall(r'^\| ((?:TV|IOS)-\d\d) (TV|iOS) \|(.+)$', inv, re.M)
ids = [row[0] for row in rows]
expected = {f'{prefix}-{n:02}' for prefix in ('TV', 'IOS') for n in range(1, 11)}
if len(ids) != len(set(ids)) or set(ids) != expected:
    errors.append('inventory IDs missing, duplicated or unexpected')
for name in ('UX_FLOWS.md', 'FOCUS_GRAPH.md'):
    refs = set(re.findall(r'\b(?:TV|IOS)-\d\d\b', (base / name).read_text()))
    if refs - set(ids):
        errors.append(f'{name}: unknown IDs {sorted(refs - set(ids))}')
    if name == 'UX_FLOWS.md' and set(ids) - refs:
        errors.append(f'{name}: unreferenced IDs {sorted(set(ids) - refs)}')
prd = (base.parent.parent / 'PRD.md').read_text()
reqs = set(re.findall(r'\bR-\d\d\b', inv))
defined = set(re.findall(r'\| (R-\d\d) \|', prd))
if reqs - defined:
    errors.append(f'unknown PRD IDs {sorted(reqs - defined)}')
cat = (base / 'COMPONENT_CATALOG.md').read_text()
components = {platform: set(re.findall(r'\| ' + platform + r' (\w+) \|', cat)) for platform in ('TV', 'iOS')}
# Components occur after the final semicolon in each state's cell or in its constraints cell.
for screen, platform, cells in rows:
    for name in re.findall(r'\b(?:AppGrid|AppTile|FocusRing|PageHeader|RecoveryPanel|ErrorPanel|LoadingState|PairingCodePanel|Dialog|StatusIndicator|SettingsRow|DeviceRow|ConnectionStatus|ErrorBanner|PairingScanner|PairingResult|DPad|RemoteButton|MediaControls|VolumeControl|Touchpad|KeyboardSheet)\b', cells):
        if name not in components[platform]:
            errors.append(f'{screen}: unknown {platform} component {name}')
print(f'Checked {len(files)} Markdown files, {len(ids)} screen IDs and {len(reqs)} PRD references')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('PASS: local links and references')
