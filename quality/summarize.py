#!/usr/bin/env python3
"""Summarize observational static-analysis reports without changing release gates."""
import argparse
import json
from collections import Counter
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    for key in ('install', 'eslint', 'cognitive', 'actionlint', 'shellcheck'):
        parser.add_argument('--' + key, default='not-run')
    args = parser.parse_args()
    print('# QUAL-01C — Informative code quality')
    print('This run is observational and does not authorize or block promotion.\n')
    print(f'Analyzer installation: **{args.install}**')
    print('| Tool | Exit code | Findings |')
    print('|---|---|---|')
    report = Path('eslint-report.json')
    if report.exists():
        try:
            data = json.loads(report.read_text(encoding='utf-8'))
            counts = Counter()
            for file in data:
                counts.update(m.get('ruleId') or 'parse/config' for m in file.get('messages', []))
            eslint_info = f'{sum(counts.values())} findings; top rules: ' + ', '.join(
                f'{key}={value}' for key, value in counts.most_common(5)
            )
        except (ValueError, OSError, TypeError) as exc:
            eslint_info = f'Report unreadable: {type(exc).__name__}'
    else:
        eslint_info = 'No report generated'
    print(f'| ESLint | {args.eslint} | {eslint_info} |')
    cognitive_report = Path('cognitive-report.json')
    if cognitive_report.exists():
        try:
            items = json.loads(cognitive_report.read_text(encoding='utf-8'))
            cognitive = sum(m.get('ruleId') == 'sonarjs/cognitive-complexity'
                            for f in items for m in f.get('messages', []))
            cognitive_info = f'{cognitive} cognitive-complexity findings (threshold 15)'
        except (ValueError, OSError, TypeError):
            cognitive_info = 'Report unreadable'
    else:
        cognitive_info = 'No report generated; inspect cognitive-stderr.txt'
    print(f'| Cognitive complexity (optional) | {args.cognitive} | {cognitive_info} |')
    if report.exists():
        try:
            items = json.loads(report.read_text(encoding='utf-8'))
            cyclomatic = sum(m.get('ruleId') == 'complexity' for f in items for m in f.get('messages', []))
            print(f'\nCyclomatic baseline: **{cyclomatic}** (threshold 15).')
        except (ValueError, OSError, TypeError):
            print('\nCyclomatic baseline unavailable: invalid ESLint report.')
    for tool in ('actionlint', 'shellcheck'):
        file = Path(f'{tool}-report.txt')
        lines = [line for line in file.read_text(encoding='utf-8', errors='replace').splitlines() if line.strip()] if file.exists() else []
        print(f'| {tool} | {getattr(args, tool)} | {len(lines)} nonempty report lines |')
    version_file = Path('analyzer-versions.txt')
    if version_file.exists():
        print('\nAnalyzer versions:')
        print('```')
        print(version_file.read_text(encoding='utf-8', errors='replace').strip())
        print('```')
    print('\nDownload the `qual-01-reports` artifact for details. Analyzer failures must be reviewed; a green job does not mean the code is clean.')


if __name__ == '__main__':
    main()
