from pathlib import Path
import difflib, hashlib, shutil, subprocess, zipfile

root=Path('E:/pzmod'); ev=root/'evidence/v03'; src=root/'NeighborhoodLife'; base=ev/'baseline'
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
record=['Changed fields: relationship domain, authority and UI; HUD relationship link; nearby action enablement; mod description.',
        'NPC body integration remains experimental; hosted multiplayer is not verified.']
for mode in ('baseline','modified'):
    cmd=['python',str(root/'tools/verify-v03.py'),mode]
    r=subprocess.run(cmd,capture_output=True,text=True)
    record += [mode.upper()+' COMMAND: '+subprocess.list2cmdline(cmd),'INPUT: '+mode,'OUTPUT: '+r.stdout.strip(),'STDERR: '+r.stderr.strip(),'EXIT: '+str(r.returncode)]
    assert r.returncode==0
shutil.copytree(src,ev/'rollback-test',dirs_exist_ok=True)
cmd=['C:/Program Files/Git/bin/bash.exe',str(ev/'ROLLBACK.sh'),str(ev/'rollback-test')]
r=subprocess.run(cmd,capture_output=True,text=True)
record+=['ROLLBACK COMMAND: '+subprocess.list2cmdline(cmd),'INPUT: '+str(ev/'rollback-test'),'OUTPUT: '+r.stdout.strip(),'STDERR: '+r.stderr.strip(),'EXIT: '+str(r.returncode)]
assert r.returncode==0
cmd=['python',str(root/'tools/verify-v03.py'),'rollback']
r=subprocess.run(cmd,capture_output=True,text=True)
record+=['RESTORED COMMAND: '+subprocess.list2cmdline(cmd),'INPUT: rollback','OUTPUT: '+r.stdout.strip(),'EXIT: '+str(r.returncode)]
assert r.returncode==0
files=lambda folder:{p.relative_to(folder).as_posix():p for p in folder.rglob('*') if p.is_file()}
old=files(base); new=files(src); restored=files(ev/'rollback-test')
assert set(old)==set(restored) and all(sha(old[k])==sha(restored[k]) for k in old)
diff=[]
for rel in sorted(set(old)|set(new)):
    a=old[rel].read_text().splitlines(True) if rel in old else []
    b=new[rel].read_text().splitlines(True) if rel in new else []
    diff.extend(difflib.unified_diff(a,b,fromfile='baseline/'+rel,tofile='modified/'+rel))
    record+=['HASH '+rel+' BASELINE '+(sha(old[rel]) if rel in old else 'ABSENT')+' MODIFIED '+(sha(new[rel]) if rel in new else 'ABSENT')]
(ev/'DIFF_FILE.patch').write_text(''.join(diff),encoding='utf-8')
with zipfile.ZipFile(ev/'MODIFIED_FILE.zip','w',zipfile.ZIP_DEFLATED) as z:
    z.writestr('NeighborhoodLife/common/','')
    for rel,p in new.items(): z.write(p,'NeighborhoodLife/'+rel)
for name in ('MODIFIED_FILE.zip','DIFF_FILE.patch','ROLLBACK.sh','VERIFICATION.txt'):
    record+=['ARTIFACT: '+str(ev/name)]
record+=['Restored behavior: v0.2 HUD, careers and wardrobe pass; exact original file hashes restored on separate copy. Working source retains social changes.']
(ev/'VERIFICATION.txt').write_text('\n'.join(record)+'\n',encoding='utf-8')
with zipfile.ZipFile(ev/'MODIFIED_FILE.zip') as z: assert z.testzip() is None
for name in ('DIFF_FILE.patch','ROLLBACK.sh','VERIFICATION.txt'): assert (ev/name).read_text()
print('PASS: four artifacts reopened; ZIP integrity verified; rollback hashes and behavior restored; source remains modified')
