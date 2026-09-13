from pathlib import Path
import subprocess, sys
root=Path('E:/pzmod')
mode=sys.argv[1]
lua='C:/Program Files (x86)/Lua/5.1/lua.exe'
if mode=='modified':
    result=subprocess.run(['python',str(root/'tools/verify.py'),'modified'])
    raise SystemExit(result.returncode)
target=root/'evidence/v03'/('baseline' if mode=='baseline' else 'rollback-test')
assert mode in ('baseline','rollback')
commands=[[lua,str(root/'tests/hud.lua'),str(target/'42/media/lua/client/NeighborhoodNeeds.lua'),'enabled']]
commands += [[lua,str(root/f'tests/{name}.lua'),str(target)] for name in ('gameplay','wardrobe')]
for command in commands:
    result=subprocess.run(command,capture_output=True,text=True)
    if result.returncode:
        print(result.stdout,result.stderr); raise SystemExit(result.returncode)
print('PASS: '+mode+' HUD, 24 career assertions and wardrobe')
