#!/usr/bin/env python3
"""Validate migrated assets without requiring Flutter. Not a Dart/build check."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
content = json.loads((ROOT / 'assets/data/content.json').read_text())
groups = content['groups']
assert len(groups) == 150
assert len({g[0] for g in groups}) == 150
assert sum(len(g[3]) for g in groups) == 912
assert len(content['names']) == len(content['counts']) == 114

def validate(part):
    if isinstance(part, str):
        assert part.strip()
    elif isinstance(part, list):
        for p in part:
            validate(p)
    else:
        s, a, b = part['q']
        assert 1 <= s <= 114
        assert 1 <= a <= b <= content['counts'][s - 1]

for group in groups:
    for card in group[3]:
        validate(card[0])
        assert isinstance(card[1], int) and card[1] > 0
        assert isinstance(card[2], str)
for xml in (ROOT / 'android/app/src/main').rglob('*.xml'):
    ET.parse(xml)
assert (ROOT / 'assets/images/dedication.jpg').stat().st_size > 0
print('PASS: 150 groups, 912 cards, 114 surahs, Quran ranges, repeat counts, Android XML.')
