from pathlib import Path
import hashlib,shutil,sys
root=Path('E:/pzmod'); baseline=root/'evidence/v03/baseline'
target=Path(sys.argv[1]).resolve()
assert target in {(root/'evidence/v03/rollback-test').resolve(),(root/'NeighborhoodLife').resolve(),
                  Path('C:/Users/clare/Zomboid/mods/NeighborhoodLife').resolve()}
assert target.is_dir() and not target.is_symlink()
added=['42/media/lua/shared/NL/Social.lua','42/media/lua/server/NL/SocialAuthority.lua',
       '42/media/lua/client/NL/SocialClient.lua','42/media/lua/client/NL/Relationships.lua']
for rel in added:
    p=(target/rel).resolve(); assert p.is_relative_to(target)
    if p.exists(): p.unlink()
for p in baseline.rglob('*'):
    if p.is_file():
        dest=(target/p.relative_to(baseline)).resolve(); assert dest.is_relative_to(target)
        dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,dest)
        assert hashlib.sha256(dest.read_bytes()).digest()==hashlib.sha256(p.read_bytes()).digest()
print('PASS: original v0.2 hashes restored; relationship modules removed from test copy')
