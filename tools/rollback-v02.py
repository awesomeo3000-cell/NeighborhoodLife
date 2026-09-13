from pathlib import Path
import hashlib, shutil, sys

root=Path('E:/pzmod')
base=root/'evidence/v02/baseline'
target=Path(sys.argv[1]).resolve()
allowed={ (root/'evidence/v02/rollback-test').resolve(),
          (root/'NeighborhoodLife').resolve(),
          Path('C:/Users/clare/Zomboid/mods/NeighborhoodLife').resolve() }
assert target in allowed, 'Target must be an explicit mod checkout or rollback-test directory'
assert target.is_dir() and not target.is_symlink()
new_files=['42/media/lua/shared/NL/Definitions.lua','42/media/lua/shared/NL/Domain.lua',
           '42/media/lua/server/NL/Authority.lua','42/media/lua/client/NL/Client.lua',
           '42/media/lua/client/NL/Journal.lua','42/media/lua/client/NL/Wardrobe.lua']
for rel in new_files:
    path=(target/rel).resolve()
    assert path.is_relative_to(target), 'Path escaped mod directory'
    if path.exists(): path.unlink()
for path in base.rglob('*'):
    if path.is_file():
        output=(target/path.relative_to(base)).resolve()
        assert output.is_relative_to(target), 'Path escaped mod directory'
        output.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,output)
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
for path in base.rglob('*'):
    if path.is_file(): assert sha(path)==sha(target/path.relative_to(base))
print('PASS: restored baseline file hashes; HUD-only behavior')
