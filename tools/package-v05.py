from pathlib import Path
import subprocess, shutil, hashlib, zipfile, difflib
root=Path('E:/pzmod'); ev=root/'evidence/v05'; src=root/'NeighborhoodLife'; base=ev/'baseline'
record=['Changed: wardrobe saved entries now contain fullType and itemId; wear prefers exact garment with same-type fallback and legacy compatibility.',
        'Mouse and keyboard automation: none. NPC engine probe: model allocated, alpha=0, movement=0; integration unfinished.']
def run(label,cmd):
    r=subprocess.run(cmd,capture_output=True,text=True)
    record.extend([label+' COMMAND: '+subprocess.list2cmdline(cmd),'INPUT: '+str(cmd[-1]),'OUTPUT: '+r.stdout.strip(),'STDERR: '+r.stderr.strip(),'EXIT: '+str(r.returncode)])
    assert r.returncode==0
lua='C:/Program Files (x86)/Lua/5.1/lua.exe'
def regression(label,target):
    run(label,[lua,str(root/'tests/hud.lua'),str(target/'42/media/lua/client/NeighborhoodNeeds.lua'),'enabled'])
    for suite in ('gameplay','wardrobe','social','social-authority','interfaces'):
        run(label,[lua,str(root/f'tests/{suite}.lua'),str(target)])
regression('BASELINE',base)
run('MODIFIED',['python',str(root/'tools/verify.py'),'modified'])
shutil.copytree(src,ev/'rollback-test',dirs_exist_ok=True)
run('ROLLBACK',['C:/Program Files/Git/bin/bash.exe',str(ev/'ROLLBACK.sh'),str(ev/'rollback-test')])
regression('RESTORED',ev/'rollback-test')
files=lambda d:{p.relative_to(d).as_posix():p for p in d.rglob('*') if p.is_file()}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old,new,restored=files(base),files(src),files(ev/'rollback-test')
assert set(old)==set(restored) and all(sha(old[k])==sha(restored[k]) for k in old)
diff=[]
for k in sorted(set(old)|set(new)):
    diff.extend(difflib.unified_diff(old[k].read_text().splitlines(True) if k in old else [],new[k].read_text().splitlines(True) if k in new else [],fromfile='baseline/'+k,tofile='modified/'+k))
    record.append('HASH '+k+' BASELINE '+(sha(old[k]) if k in old else 'ABSENT')+' MODIFIED '+sha(new[k]))
(ev/'DIFF_FILE.patch').write_text(''.join(diff),encoding='utf-8')
with zipfile.ZipFile(ev/'MODIFIED_FILE.zip','w',zipfile.ZIP_DEFLATED) as z:
    z.writestr('NeighborhoodLife/common/','')
    for k,p in new.items(): z.write(p,'NeighborhoodLife/'+k)
record.append('Restored behavior: baseline HUD, careers, social and wardrobe regressions pass; exact original hashes restored on separate copy. Working source retains new panel.')
for name in ('MODIFIED_FILE.zip','DIFF_FILE.patch','VERIFICATION.txt','ROLLBACK.sh'): record.append('ARTIFACT: '+str(ev/name))
(ev/'VERIFICATION.txt').write_text('\n'.join(record)+'\n',encoding='utf-8')
with zipfile.ZipFile(ev/'MODIFIED_FILE.zip') as z: assert z.testzip() is None
for name in ('DIFF_FILE.patch','VERIFICATION.txt','ROLLBACK.sh'): assert (ev/name).read_text()
print('PASS: baseline, modified and rollback tests; original hashes restored; four artifacts reopened')
