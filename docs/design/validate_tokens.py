#!/usr/bin/env python3
"""Validate the proposed token contract, including declared color pairings."""
import json
import math
import re
import sys
from pathlib import Path

ROLES = {'background', 'surface', 'surfaceRaised', 'foreground', 'mutedForeground', 'border', 'primary', 'primaryForeground', 'focus', 'success', 'warning', 'danger', 'info', 'interactive', 'interactiveForeground', 'pressed', 'pressedForeground', 'disabledForeground', 'disabledSurface'}


def fail(message):
    raise ValueError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            fail(f'duplicate JSON key: {key}')
        result[key] = value
    return result


def group(parent, key, required):
    value = parent.get(key)
    if not isinstance(value, dict):
        fail(f'{key}: expected object')
    missing = set(required) - value.keys()
    if missing:
        fail(f'{key}: missing {sorted(missing)}')
    return value


def number(value, name, minimum, maximum=None):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < minimum or (maximum is not None and value > maximum):
        fail(f'{name}: expected finite number in [{minimum}, {maximum if maximum is not None else "infinity"}]')


def luminance(value):
    channels = [int(value[i:i+2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return sum(a * b for a, b in zip(linear, (0.2126, 0.7152, 0.0722)))


def validate(t):
    if not isinstance(t, dict) or not isinstance(t.get('version'), str) or not t['version']:
        fail('root: expected object with non-empty version')
    for name, keys in [('spacing', ('xs', 'sm', 'md', 'lg', 'xl', '2xl', '3xl')), ('radius', ('sm', 'md', 'lg', 'xl'))]:
        for key, value in group(t, name, keys).items():
            number(value, f'{name}.{key}', 0)
    motion = group(t, 'motion', ('fastMs', 'normalMs', 'reducedMs'))
    for key, value in motion.items():
        number(value, f'motion.{key}', 0)
    if motion['reducedMs'] != 0:
        fail('motion.reducedMs: must be zero')
    tv = group(t, 'tv', ('titlePx', 'sectionPx', 'bodyPx', 'metaPx', 'focusWidthPx', 'safeMarginPercent', 'referenceWidth', 'referenceHeight'))
    for key, value in tv.items():
        number(value, f'tv.{key}', 0.001, 49 if key == 'safeMarginPercent' else None)
    ios = group(t, 'ios', ('minimumHitTargetPt', 'dynamicType', 'font'))
    number(ios['minimumHitTargetPt'], 'ios.minimumHitTargetPt', 44)
    if ios['dynamicType'] is not True or ios['font'] != 'system':
        fail('ios: dynamicType must be true and font must be system')
    colors = group(group(t, 'primitives', ('color',)), 'color', ())
    if not colors or any(not isinstance(v, str) or not re.fullmatch(r'#[0-9A-Fa-f]{6}', v) for v in colors.values()):
        fail('primitives.color: expected non-empty object of six-digit hex colors')
    themes = group(t, 'semanticColor', ('dark', 'light'))
    if set(themes) != {'dark', 'light'}:
        fail('semanticColor: expected exactly dark and light')
    for theme in themes:
        mapping = group(themes, theme, ROLES)
        for role, ref in mapping.items():
            if not isinstance(ref, str) or ref not in colors:
                fail(f'{theme}.{role}: unknown primitive reference {ref!r}')
        pairs = [(fg, bg, 4.5) for fg in ('foreground', 'mutedForeground', 'success', 'warning', 'danger', 'info') for bg in ('background', 'surface', 'surfaceRaised')]
        pairs += [('primaryForeground', 'primary', 4.5), ('interactiveForeground', 'interactive', 4.5), ('pressedForeground', 'pressed', 4.5), ('disabledForeground', 'disabledSurface', 4.5)]
        pairs += [('focus', bg, 3.0) for bg in ('background', 'surface', 'surfaceRaised')]
        pairs += [('border', bg, 3.0) for bg in ('background', 'surface')]
        for fg, bg, minimum in pairs:
            a, b = sorted((luminance(colors[mapping[fg]]), luminance(colors[mapping[bg]])))
            ratio = (b + .05) / (a + .05)
            print(f'{theme} {fg}/{bg}: {ratio:.2f}:1 (minimum {minimum})')
            if ratio < minimum:
                fail(f'{theme}: {fg}/{bg} fails contrast')


def main():
    if len(sys.argv) > 2:
        print('usage: validate_tokens.py [path]', file=sys.stderr)
        return 2
    path = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).with_name('design-tokens.json')
    try:
        with path.open(encoding='utf-8') as source:
            tokens = json.load(source, object_pairs_hook=unique_object, parse_constant=lambda value: fail(f'invalid JSON constant: {value}'))
        validate(tokens)
    except (OSError, ValueError, TypeError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        return 1
    print('PASS: token structure, references, contrast and platform minima')
    return 0


if __name__ == '__main__':
    sys.exit(main())
