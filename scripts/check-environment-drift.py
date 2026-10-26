#!/usr/bin/env python3
import argparse, hashlib, json, pathlib, re, subprocess, urllib.request
from datetime import datetime, timezone

MIG_RE = re.compile(r"^(\d{3})_.*\.sql$")

def sha256(path):
    h=hashlib.sha256(); h.update(path.read_bytes()); return h.hexdigest()

def expected(repo):
    repo=pathlib.Path(repo)
    version=json.loads((repo/'version.json').read_text(encoding='utf-8-sig')).get('version')
    migrations=[]
    for p in sorted((repo/'supabase/migrations').glob('*.sql')):
        m=MIG_RE.match(p.name)
        if m and int(m.group(1)) >= 44:
            migrations.append({'file':p.name,'number':int(m.group(1)),'sha256':sha256(p)})
    funcs=[]
    for p in sorted((repo/'supabase/functions').glob('*/index.ts')):
        funcs.append({'function':p.parent.name,'sha256':sha256(p)})
    return {'frontend_version':version,'migrations':migrations,'edge_functions':funcs}

def psql(url, sql):
    cp=subprocess.run(['psql',url,'-X','-A','-t','-F','\t','-v','ON_ERROR_STOP=1','-c',sql],text=True,capture_output=True)
    if cp.returncode: return None, (cp.stderr.strip() or cp.stdout.strip())
    return cp.stdout.strip(), None

def db_state(url, exp):
    exists,err=psql(url,"select to_regclass('private.schema_migrations') is not null;")
    if err: return {'status':'ERROR','error':err}
    if exists != 't': return {'status':'BEHIND','registry':'MISSING','applied_migrations':[],'details':'private.schema_migrations does not exist'}
    out,err=psql(url,"select filename,sha256 from private.schema_migrations order by filename;")
    if err: return {'status':'ERROR','error':err}
    actual={}
    if out:
        for line in out.splitlines():
            parts=line.split('\t')
            if len(parts)>=2: actual[parts[0]]=parts[1]
    expected_map={x['file']:x['sha256'] for x in exp['migrations']}
    changed=[f for f,h in actual.items() if f in expected_map and expected_map[f] != h]
    unexpected=[f for f in actual if f not in expected_map]
    missing=[f for f in expected_map if f not in actual]
    status='DRIFT' if changed or unexpected else ('BEHIND' if missing else 'ALIGNED')
    return {'status':status,'registry':'PRESENT','missing':missing,'changed_hash':changed,'unexpected':unexpected,'applied_migrations':sorted(actual)}

def fetch_version(base):
    try:
        with urllib.request.urlopen(base.rstrip('/')+'/version.json',timeout=20) as r:
            data=json.loads(r.read().decode('utf-8-sig'))
        return {'status':'OK','version':data.get('version')}
    except Exception as e: return {'status':'ERROR','error':str(e)}

def frontend_state(base, exp):
    remote=fetch_version(base)
    if remote['status']!='OK': return {'status':'ERROR','expected':exp['frontend_version'],**remote}
    return {'status':'ALIGNED' if remote['version']==exp['frontend_version'] else 'DRIFT','expected':exp['frontend_version'],'actual':remote['version'],'url':base}

def overall(*states):
    vals=[x['status'] for x in states]
    if 'ERROR' in vals: return 'ERROR'
    if 'DRIFT' in vals: return 'DRIFT'
    if 'BEHIND' in vals: return 'BEHIND'
    return 'ALIGNED'

def git_relation(repo_a, repo_b, label_a, label_b):
    # Checkouts are separate worktrees; compare commit ids using git merge-base --is-ancestor.
    a=subprocess.check_output(['git','-C',repo_a,'rev-parse','HEAD'],text=True).strip()
    b=subprocess.check_output(['git','-C',repo_b,'rev-parse','HEAD'],text=True).strip()
    if a==b: relation='SAME_COMMIT'
    else:
        ab=subprocess.run(['git','-C',repo_a,'merge-base','--is-ancestor',a,b]).returncode==0
        ba=subprocess.run(['git','-C',repo_a,'merge-base','--is-ancestor',b,a]).returncode==0
        relation='BEHIND' if ab else ('AHEAD' if ba else 'DIVERGED')
    return {'from':label_a,'to':label_b,'relation':relation,'from_commit':a,'to_commit':b}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--develop-repo',required=True); ap.add_argument('--test-repo',required=True); ap.add_argument('--demo-repo',required=True)
    ap.add_argument('--test-db-url',required=True); ap.add_argument('--demo-db-url',required=True)
    ap.add_argument('--develop-frontend-url',required=True); ap.add_argument('--test-frontend-url',required=True); ap.add_argument('--demo-frontend-url',required=True)
    ap.add_argument('--output',required=True); a=ap.parse_args()
    dve=expected(a.develop_repo); te=expected(a.test_repo); de=expected(a.demo_repo)
    dvfe=frontend_state(a.develop_frontend_url,dve)
    tdb=db_state(a.test_db_url,te); tfe=frontend_state(a.test_frontend_url,te)
    ddb=db_state(a.demo_db_url,de); dfe=frontend_state(a.demo_frontend_url,de)
    edge_note='Supabase does not expose deployed function source hashes through this check; release manifests provide deployment evidence.'
    report={
      'schema_version':2,'generated_at_utc':datetime.now(timezone.utc).isoformat(timespec='seconds'),'mode':'READ_ONLY',
      'model':{'DEVELOP':'develop branch + /develop/ frontend','TEST':'test branch + /test/ frontend + Supabase TEST','DEMO':'main branch + root frontend + Supabase DEMO'},
      'DEVELOP':{'expected':dve,'frontend':dvfe,'database':{'status':'NOT_APPLICABLE','note':'DEVELOP has no independent Supabase database in the current topology.'},'edge_functions':{'status':'REPOSITORY_ONLY','expected_repo_hashes':dve['edge_functions']},'overall':dvfe['status']},
      'TEST':{'expected':te,'database':tdb,'frontend':tfe,'edge_functions':{'status':'NOT_DIRECTLY_VERIFIABLE','expected_repo_hashes':te['edge_functions'],'note':edge_note},'overall':overall(tdb,tfe)},
      'DEMO':{'expected':de,'database':ddb,'frontend':dfe,'edge_functions':{'status':'NOT_DIRECTLY_VERIFIABLE','expected_repo_hashes':de['edge_functions'],'note':edge_note},'overall':overall(ddb,dfe)},
      'promotion_path':{
        'develop_to_test':git_relation(a.develop_repo,a.test_repo,'DEVELOP','TEST'),
        'test_to_demo':git_relation(a.test_repo,a.demo_repo,'TEST','DEMO')
      }
    }
    pathlib.Path(a.output).write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps({'DEVELOP':report['DEVELOP']['overall'],'TEST':report['TEST']['overall'],'DEMO':report['DEMO']['overall'],'promotion_path':report['promotion_path']},indent=2))
    if 'ERROR' in (report['DEVELOP']['overall'],report['TEST']['overall'],report['DEMO']['overall']): raise SystemExit(2)
if __name__=='__main__': main()
