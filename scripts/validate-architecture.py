#!/usr/bin/env python3
from pathlib import Path
import re, sys
ROOT=Path(__file__).resolve().parents[1]
errors=[]; notes=[]
def err(s): errors.append(s)
def ok(s): notes.append(s)
required=[
 'supabase/baseline','supabase/migrations','supabase/tests/contracts','supabase/seed','supabase/test-support','supabase/functions','supabase/config'
]
for d in required:
 p=ROOT/d
 if not p.is_dir(): err(f'missing required area: {d}')
 else: ok(f'area OK: {d}')
# Baseline: exactly one SQL snapshot + manifest; immutable semantics are validated by baseline workflow.
bdir=ROOT/'supabase/baseline'
if bdir.is_dir():
 sqls=list(bdir.glob('*.sql'))
 if len(sqls)!=1: err(f'baseline must contain exactly one SQL snapshot, found {len(sqls)}')
 if not (bdir/'manifest.json').is_file(): err('baseline manifest.json missing')
# Migrations >=044, numbered and unique.
mdir=ROOT/'supabase/migrations'
if mdir.is_dir():
 seen={}
 for p in sorted(mdir.glob('*.sql')):
  m=re.match(r'^(\d{3})_[a-z0-9][a-z0-9_]*\.sql$',p.name)
  if not m: err(f'invalid migration filename: {p.name}'); continue
  n=int(m.group(1))
  if n<44: err(f'incremental migration must be >=044: {p.name}')
  if n in seen: err(f'duplicate migration number {n:03d}: {seen[n]} and {p.name}')
  seen[n]=p.name
  txt=p.read_text(errors='ignore').lower()
  if 'test-data/' in txt or 'test-base.sql' in txt: err(f'migration references test seed content: {p.name}')
# Contract SQL must be read/assert only: no schema/data mutation outside DO assertion blocks.
tdir=ROOT/'supabase/tests/contracts'
if tdir.is_dir():
 for p in sorted(tdir.glob('*.sql')):
  if not re.match(r'^\d{3}_[a-z0-9][a-z0-9_]*_contract\.sql$',p.name): err(f'invalid contract filename: {p.name}')
# Seeds must not define schema objects / RLS / grants. Data fixtures only.
seed=ROOT/'supabase/seed'
for p in seed.rglob('*.sql') if seed.is_dir() else []:
 txt=re.sub(r'--.*?$','',p.read_text(errors='ignore'),flags=re.M).lower()
 forbidden=[r'\bcreate\s+(table|schema|function|type|view|policy|trigger)\b',r'\balter\s+table\b',r'\bdrop\s+(table|schema|function|type|view)\b',r'\bgrant\s+',r'\brevoke\s+']
 for pat in forbidden:
  if re.search(pat,txt): err(f'seed contains schema/security DDL ({pat}): {p.relative_to(ROOT)}'); break
# TEST-only infrastructure may contain DDL, but only for private TEST support objects.
ts=ROOT/'supabase/test-support'
if ts.is_dir():
 for p in sorted(ts.glob('*.sql')):
  txt=re.sub(r'--.*?$','',p.read_text(errors='ignore'),flags=re.M).lower()
  if re.search(r'\b(create|alter|drop)\s+(table|function|schema|view|type|policy|trigger)\s+(?:if\s+(?:not\s+)?exists\s+)?public\.',txt):
   err(f'test-support must not define public application schema objects: {p.relative_to(ROOT)}')
  if 'test' not in p.name.lower(): err(f'test-support SQL must be explicitly TEST-named: {p.relative_to(ROOT)}')

# No secret files in repository. Public client config is allowed, secret material is not.
secret_names={'.env','.env.local','.env.production','.env.test','secrets.json','secrets.yml','secrets.yaml','service-role.json'}
for p in ROOT.rglob('*'):
 if '.git' in p.parts or not p.is_file(): continue
 if p.name.lower() in secret_names or p.suffix.lower() in {'.pem','.p12','.pfx','.key'}:
  err(f'forbidden secret/key file tracked: {p.relative_to(ROOT)}')
# Detect common literal credentials, while allowing env/secrets references and public Supabase anon/publishable config.
scan_ext={'.js','.mjs','.ts','.json','.yml','.yaml','.sql','.sh','.py'}
patterns=[
 ('postgres credential URL',re.compile(r'postgres(?:ql)?://[^\s:@/]+:[^\s@/]+@',re.I)),
 ('private key',re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
 ('Supabase service-role JWT literal',re.compile(r'eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}')),
]
for p in ROOT.rglob('*'):
 if '.git' in p.parts or not p.is_file() or p.suffix.lower() not in scan_ext: continue
 txt=p.read_text(errors='ignore')
 for label,pat in patterns:
  if pat.search(txt): err(f'possible {label} in {p.relative_to(ROOT)}')
# Config area is documentation/public configuration only.
cfg=ROOT/'supabase/config'
if cfg.is_dir():
 for p in cfg.iterdir():
  if p.is_file() and p.suffix.lower() not in {'.md','.json','.example','.txt'}: err(f'unexpected config artifact: {p.relative_to(ROOT)}')
print('Yebenes architecture guardrails')
for n in notes: print('PASS',n)
if errors:
 for e in errors: print('ERROR',e,file=sys.stderr)
 print(f'ARCHITECTURE FAIL: {len(errors)} issue(s)',file=sys.stderr); sys.exit(1)
print('ARCHITECTURE PASS')
