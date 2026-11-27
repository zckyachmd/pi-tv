#!/usr/bin/env python3
"""Negative token fixtures: mutations of the active contract plus malformed JSON."""
import copy
import json
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
original = json.loads((root / 'design-tokens.json').read_text())
fixtures = {}

def fixture(name, mutate):
    data = copy.deepcopy(original)
    mutate(data)
    fixtures[name] = json.dumps(data)

fixture('missing group', lambda t: t.pop('spacing'))
fixture('missing role', lambda t: t['semanticColor']['dark'].pop('pressedForeground'))
fixture('invalid type', lambda t: t['tv'].__setitem__('bodyPx', '24'))
fixture('boolean number', lambda t: t['ios'].__setitem__('minimumHitTargetPt', True))
fixture('numeric range', lambda t: t['tv'].__setitem__('safeMarginPercent', 50))
fixture('unknown reference', lambda t: t['semanticColor']['light'].__setitem__('focus', 'missing'))
fixture('invalid color', lambda t: t['primitives']['color'].__setitem__('11131a', '#xyzxyz'))
fixture('pressed contrast', lambda t: t['semanticColor']['dark'].__setitem__('pressedForeground', t['semanticColor']['dark']['pressed']))
fixture('primary contrast', lambda t: t['semanticColor']['light'].__setitem__('primaryForeground', t['semanticColor']['light']['primary']))
fixture('reduced motion', lambda t: t['motion'].__setitem__('reducedMs', 1))
fixtures['duplicate key'] = '{"version":"one","version":"two"}'
fixtures['invalid JSON constant'] = '{"version":"x", "bad": NaN}'

with tempfile.TemporaryDirectory() as tmp:
    path = Path(tmp) / 'tokens.json'
    for name, contents in fixtures.items():
        path.write_text(contents)
        for optimized in (False, True):
            cmd = [sys.executable] + (['-O'] if optimized else []) + [str(root / 'validate_tokens.py'), str(path)]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0 or 'ERROR:' not in result.stderr:
                print(f'FAIL: {name}, optimized={optimized}: {result.returncode} {result.stderr}', file=sys.stderr)
                sys.exit(1)
        print(f'PASS: {name} rejected in normal and optimized mode')
print(f'PASS: {len(fixtures)} negative fixtures')
