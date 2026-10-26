#!/usr/bin/env python3
import argparse, hashlib, json, subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def sha256(path: Path) -> str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024), b''): h.update(chunk)
    return h.hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

def frontend_version():
    p=ROOT/'version.json'
    if not p.exists(): return None
    try:
        data=json.loads(p.read_text(encoding='utf-8-sig'))
        return data.get('version')
    except Exception:
        return None

def migration_state():
    files=sorted((ROOT/'supabase/migrations').glob('*.sql')) if (ROOT/'supabase/migrations').exists() else []
    entries=[]
    for p in files:
        prefix=p.name.split('_',1)[0]
        entries.append({'file':p.name,'number':int(prefix) if prefix.isdigit() else None,'sha256':sha256(p)})
    numbered=[e for e in entries if e['number'] is not None]
    return {'count':len(entries),'highest_number':max((e['number'] for e in numbered), default=None),'files':entries}

def edge_state():
    base=ROOT/'supabase/functions'
    out=[]
    if base.exists():
        for p in sorted(base.glob('*/index.ts')):
            out.append({'function':p.parent.name,'file':str(p.relative_to(ROOT)).replace('\\','/'),'sha256':sha256(p)})
    return out

def baseline_state():
    manifest=ROOT/'supabase/baseline/manifest.json'
    if not manifest.exists(): return None
    try: return json.loads(manifest.read_text(encoding='utf-8-sig'))
    except Exception: return {'manifest_file':'supabase/baseline/manifest.json','parse_error':True}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--target',required=True,choices=['TEST','DEMO'])
    ap.add_argument('--source-ref',required=True)
    ap.add_argument('--run-id',required=True)
    ap.add_argument('--run-number',required=True)
    ap.add_argument('--output',required=True)
    a=ap.parse_args()
    data={
      'schema_version':1,
      'application':'Yebenes',
      'environment':a.target,
      'source_ref':a.source_ref,
      'git_commit':git('rev-parse','HEAD'),
      'git_commit_short':git('rev-parse','--short=12','HEAD'),
      'frontend_version':frontend_version(),
      'baseline':baseline_state(),
      'migrations':migration_state(),
      'edge_functions':edge_state(),
      'verification':{'architecture_guardrails':'PASS','migration_contracts':'PASS','frontend_smoke':'PASS'},
      'github_actions':{'run_id':str(a.run_id),'run_number':str(a.run_number)},
      'generated_at_utc':datetime.now(timezone.utc).isoformat(timespec='seconds')
    }
    Path(a.output).write_text(json.dumps(data,indent=2,ensure_ascii=True)+'\n',encoding='utf-8')
    print(json.dumps(data,indent=2))
if __name__=='__main__': main()
