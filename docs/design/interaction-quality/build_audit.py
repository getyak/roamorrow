#!/usr/bin/env python3
"""Embed current audit JSON so the report works offline. Run after review updates."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
page = ROOT / "index.html"
html = page.read_text()
for name in ("inventory", "scorecard"):
    source = ROOT / "current" / "inventory.json" if name == "inventory" and (ROOT / "current" / "inventory.json").exists() else ROOT / f"{name}.json"
    payload = json.dumps(json.loads(source.read_text()), ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c")
    block = f'<script type="application/json" id="{name}-data">{payload}</script>'
    pattern = rf'<script type="application/json" id="{name}-data">.*?</script>'
    if re.search(pattern, html, re.S):
        html = re.sub(pattern, lambda _: block, html, flags=re.S)
    else:
        html = html.replace("<script>\nlet inventory", block + "\n<script>\nlet inventory")
html = html.replace("Promise.all([fetch('inventory.json').then(r=>r.json()),fetch('scorecard.json').then(r=>r.json())])", "Promise.resolve(['inventory','scorecard'].map(name=>JSON.parse(document.getElementById(name+'-data').textContent)))")
page.write_text(html)
print(f"Standalone report: {page} ({len(html.encode()):,} bytes)")
