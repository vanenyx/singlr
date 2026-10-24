#!/usr/bin/env python3
"""Rebuild the name → codepoint map from the vendored CSS, without dependencies."""
import json, pathlib, re
root = pathlib.Path(__file__).resolve().parents[3]
styles = {}
for style in ('regular', 'light', 'fill'):
    css = (root / 'third_party/phosphor' / (style + '.css')).read_text()
    styles[style] = {name: int(code,16)
        for name, code in re.findall(r'\.ph-([\w-]+):before\s*\{\s*content:\s*"\\([0-9a-f]+)";', css)}
pathlib.Path(__file__).with_name('IconMap.js').write_text('.pragma library\nvar glyphs = '+json.dumps(styles, separators=(',', ':'))+';\n')
print('Phosphor:', ', '.join(f'{s}={len(m)}' for s,m in styles.items()))
