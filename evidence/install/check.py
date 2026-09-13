from pathlib import Path
import sys
p=Path(sys.argv[1]); enabled=sys.argv[2]=='enabled'
s=p.read_text()
assert ('mod = NeighborhoodLifeHUD,' in s)==enabled
assert 'mod = LifeSim,' in s
print('PASS: HUD '+('enabled' if enabled else 'disabled')+'; LifeSim preserved')
