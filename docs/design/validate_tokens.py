#!/usr/bin/env python3
"""Validate the proposed token contract and its declared color combinations."""
import json
import re
from pathlib import Path

p = Path(__file__).with_name('design-tokens.json')
t = json.loads(p.read_text())
roles = {'background', 'surface', 'surfaceRaised', 'foreground', 'mutedForeground', 'border', 'primary', 'primaryForeground', 'focus', 'success', 'warning', 'danger', 'info', 'interactive', 'interactiveForeground', 'pressed', 'disabledForeground', 'disabledSurface'}
colors = t['primitives']['color']
assert all(re.fullmatch(r'#[0-9A-Fa-f]{6}', v) for v in colors.values())
assert set(t['semanticColor']) == {'dark', 'light'}

def luminance(value):
    channels = [int(value[i:i+2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return sum(a * b for a, b in zip(linear, (0.2126, 0.7152, 0.0722)))

for theme, mapping in t['semanticColor'].items():
    assert roles <= mapping.keys(), f'{theme}: missing {roles - mapping.keys()}'
    assert all(v in colors for v in mapping.values()), f'{theme}: unknown primitive'
    pairs = [(fg, bg, 4.5) for fg in ('foreground', 'mutedForeground', 'success', 'warning', 'danger', 'info') for bg in ('background', 'surface', 'surfaceRaised')]
    pairs += [('interactiveForeground', 'interactive', 4.5), ('disabledForeground', 'disabledSurface', 4.5)]
    pairs += [('focus', bg, 3.0) for bg in ('background', 'surface', 'surfaceRaised')]
    pairs += [('border', bg, 3.0) for bg in ('background', 'surface')]
    for fg, bg, minimum in pairs:
        a, b = sorted((luminance(colors[mapping[fg]]), luminance(colors[mapping[bg]])))
        ratio = (b + .05) / (a + .05)
        print(f'{theme} {fg}/{bg}: {ratio:.2f}:1 (minimum {minimum})')
        assert ratio >= minimum, f'{theme}: {fg}/{bg} fails'
assert t['motion']['reducedMs'] == 0
assert t['ios']['minimumHitTargetPt'] >= 44
print('PASS: semantic coverage, references, contrast and platform minima')
