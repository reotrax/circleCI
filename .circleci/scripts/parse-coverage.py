#!/usr/bin/env python3
import json
import sys

with open('coverage/coverage-summary.json', 'r') as f:
    data = json.load(f)

total = data['total']
print(f"{total['statements']['pct']}|{total['branches']['pct']}|{total['functions']['pct']}|{total['lines']['pct']}")

# ファイルごとのカバレッジ
for path, metrics in data.items():
    if path != 'total' and 'src/' in path:
        file_name = path.split('src/')[-1] if 'src/' in path else path
        print(f"FILE|src/{file_name}|{metrics['statements']['pct']}|{metrics['branches']['pct']}|{metrics['functions']['pct']}|{metrics['lines']['pct']}")
