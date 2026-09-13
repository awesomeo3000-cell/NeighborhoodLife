from pathlib import Path
import subprocess, sys

ROOT = Path('E:/pzmod')
GAME = Path('E:/SteamLibrary/steamapps/common/ProjectZomboid')
LUA = 'C:/Program Files (x86)/Lua/5.1/lua.exe'
LUAC = 'C:/Program Files (x86)/Lua/5.1/luac.exe'
mode = sys.argv[1]
target = ROOT/'evidence/v02/baseline' if mode == 'baseline' else ROOT/'NeighborhoodLife'
log = []

def run(command, cwd=ROOT):
    result = subprocess.run([str(x) for x in command],cwd=cwd,text=True,capture_output=True)
    log.extend(['COMMAND: '+subprocess.list2cmdline([str(x) for x in command]),
                'CWD: '+str(cwd),'OUTPUT: '+result.stdout.strip(),
                'STDERR: '+result.stderr.strip(),'EXIT: '+str(result.returncode)])
    (ROOT/f'evidence/v02/{mode}-tests.log').write_text('\n'.join(log),encoding='utf-8')
    if result.returncode:
        print('\n'.join(log)); raise SystemExit(result.returncode)

run([LUA, ROOT/'tests/hud.lua',target/'42/media/lua/client/NeighborhoodNeeds.lua','enabled'])
if mode == 'baseline':
    print('PASS: baseline HUD regression')
elif mode == 'modified':
    for path in target.rglob('*.lua'): run([LUAC,'-p',path])
    for suite in ['gameplay','wardrobe','social','social-authority','interfaces','wardrobe-panel','aspirations']: run([LUA,ROOT/f'tests/{suite}.lua',target])
    run(['javac','-cp',GAME/'projectzomboid.jar','-d',ROOT/'tests/classes',ROOT/'tests/EngineLua.java'])
    for suite in ['gameplay','wardrobe','social','social-authority','interfaces','wardrobe-panel','aspirations']:
        run(['java','-cp',str(ROOT/'tests/classes')+';projectzomboid.jar;.',
             'EngineLua',target,ROOT/f'tests/{suite}.lua'],GAME)
    print('PASS: HUD, syntax, 60 gameplay/social assertions, wardrobe; Lua 5.1 and game Kahlua')
else:
    raise SystemExit('Expected baseline or modified')
