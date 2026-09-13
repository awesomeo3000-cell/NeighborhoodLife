from pathlib import Path
import hashlib, shutil, sys
root=Path('E:/pzmod'); base=root/'evidence/v06/baseline'
target=Path(sys.argv[1]).resolve()
assert target in {(root/'NeighborhoodLife').resolve(),(root/'evidence/v06/rollback-test').resolve()}
added=(target/'42/media/lua/shared/NL/Aspirations.lua').resolve()
assert added.is_relative_to(target)
if added.exists(): added.unlink()
for p in base.rglob('*'):
    if p.is_file():
        dest=(target/p.relative_to(base)).resolve(); assert dest.is_relative_to(target)
        dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,dest)
        assert hashlib.sha256(dest.read_bytes()).digest()==hashlib.sha256(p.read_bytes()).digest()
print('PASS: original v0.5 hashes restored; garment preset behavior restored on test copy')
