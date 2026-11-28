#!/usr/bin/env python3
"""QUAL-03A read-only GitHub evidence lookup; never authorizes promotions."""
import argparse
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile

API = 'https://api.github.com'


class EvidenceRequestError(Exception):
    def __init__(self, stage, status):
        self.stage = stage
        self.status = status
        super().__init__(f'GitHub evidence request failed at {stage}: HTTP {status}')


def request(url, token, stage):
    req = urllib.request.Request(url, headers={
        'Authorization': 'Bearer ' + token,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'yebenes-qual03a',
    })
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        # No token, signed URL or response body is exposed in diagnostics.
        raise EvidenceRequestError(stage, exc.code) from exc


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def evaluate(mode, repository, token):
    source = 'test' if mode == 'TEST_TO_DEMO' else 'develop'
    ref = 'origin/' + source
    tree = git('rev-parse', ref + '^{tree}')
    if not repository or not token:
        return {'status': 'ERROR', 'source': source, 'tree_sha': tree, 'reason': 'Missing GitHub API configuration'}
    base = f'{API}/repos/{repository}'
    # A successful workflow job alone does not establish analyzer validity.
    for page in range(1, 4):
        url = base + '/actions/workflows/code-quality.yml/runs?' + urllib.parse.urlencode({
            'branch': 'develop', 'event': 'push', 'per_page': 100, 'page': page})
        runs = json.loads(request(url, token, 'list_quality_runs')).get('workflow_runs', [])
        if not runs:
            break
        for run in runs:
            if run.get('status') != 'completed' or run.get('conclusion') != 'success':
                continue
            commit = run.get('head_sha')
            if not commit:
                continue
            commit_data = json.loads(request(base + '/git/commits/' + commit, token, 'read_commit_tree'))
            if commit_data.get('tree', {}).get('sha') != tree:
                continue
            artifacts = json.loads(request(base + f"/actions/runs/{run['id']}/artifacts?per_page=100", token, 'list_run_artifacts')).get('artifacts', [])
            match = next((a for a in artifacts if a.get('name') == 'qual-01-reports' and not a.get('expired')), None)
            if not match:
                return {'status': 'INCONCLUSIVE', 'source': source, 'tree_sha': tree,
                        'run_url': run.get('html_url'), 'reason': 'Matching run has no available report artifact'}
            data = request(match['archive_download_url'], token, 'download_report_artifact')
            with zipfile.ZipFile(io.BytesIO(data)) as z:
                names = z.namelist()
                comparison_name = next((n for n in names if n.endswith('qual-02-comparison.json')), None)
                eslint_name = next((n for n in names if n.endswith('eslint-report.json')), None)
                if not comparison_name or not eslint_name:
                    return {'status': 'INCONCLUSIVE', 'source': source, 'tree_sha': tree,
                            'run_url': run.get('html_url'), 'reason': 'ESLint or comparison report missing'}
                comparison = json.loads(z.read(comparison_name))
                eslint = json.loads(z.read(eslint_name))
                if not isinstance(eslint, list):
                    raise ValueError('Invalid ESLint report')
                status = comparison.get('status', 'ERROR')
                if status not in ('PASS', 'REGRESSION', 'INCONCLUSIVE', 'ERROR'):
                    status = 'ERROR'
                return {'status': status, 'source': source, 'tree_sha': tree,
                        'run_url': run.get('html_url'), 'reason': 'QUAL-02A report matched by Git tree; cognitive analysis not certified'}
    return {'status': 'INCONCLUSIVE', 'source': source, 'tree_sha': tree,
            'reason': 'No matching completed quality run found (searched up to 300 recent develop push runs)'}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--mode', choices=['DRY_RUN', 'DEVELOP_TO_TEST', 'TEST_TO_DEMO'], required=True)
    p.add_argument('--output', required=True)
    args = p.parse_args()
    try:
        result = evaluate(args.mode, os.getenv('GH_REPOSITORY', ''), os.getenv('GH_TOKEN', ''))
    except (OSError, ValueError, KeyError, urllib.error.URLError, zipfile.BadZipFile, subprocess.CalledProcessError, EvidenceRequestError) as exc:
        result = {'status': 'ERROR', 'reason': str(exc)}
    Path(args.output).write_text(json.dumps(result, indent=2) + '\n')
    print('QUAL-03A:', result['status'], result.get('reason', ''))
    return 0  # Observational only.


if __name__ == '__main__':
    sys.exit(main())
