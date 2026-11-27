#!/usr/bin/env python3
"""Summarize observational static-analysis reports without changing release gates."""
import argparse
import json
from collections import Counter
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    for key in ('install', 'eslint', 'actionlint', 'shellcheck'):
        parser.add_argument('--' + key, default='not-run')
    args = parser.parse_args()
    print('# QUAL-01B — Informative code quality')
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
    if report.exists():
        try:
            items = json.loads(report.read_text(encoding='utf-8'))
            cyclomatic = sum(m.get('ruleId') == 'complexity' for f in items for m in f.get('messages', []))
            cognitive = sum(m.get('ruleId') == 'sonarjs/cognitive-complexity' for f in items for m in f.get('messages', []))
            print(f'\nComplexity baseline: cyclomatic **{cyclomatic}**; cognitive **{cognitive}** (threshold 15 each).')
        except (ValueError, OSError, TypeError):
            print('\nComplexity baseline unavailable: invalid ESLint report.')
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
