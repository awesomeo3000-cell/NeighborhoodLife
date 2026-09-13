package.path=arg[1]..'/42/media/lua/shared/?.lua;'..package.path
require 'NL/Social'
local n=0
local function check(v,label) assert(v,label); n=n+1 end
local w=NLDomain.newWorld(); local p=NLDomain.profile(w,'host'); local q=NLDomain.profile(w,'guest')
local npc={id='marisol'}
local function act(profile,action,t,key) return NLSocial.interact(profile,npc,action,t,key or 'host') end
check(not act(p,'chat',0),'must meet first')
check(act(p,'introduce',0),'introduction')
check(not act(p,'chat',0.1),'game time cooldown')
check(not act(p,'introduce',1),'cannot farm introductions')
check(act(p,'flirt',1),'early flirt gets response')
check(NLSocial.relation(p,'marisol').attraction==0,'rejected early advances do not grant attraction')
check(NLSocial.relation(q,'marisol').friendship==0,'separate players')
for t=2,10 do act(p,'chat',t) end
for t=15,39,4 do act(p,'flirt',t) end
check(act(p,'date',45),'mutual-interest date')
check(not act(p,'date',46),'daily date gate')
check(act(p,'date',70),'second date')
check(act(p,'partner',71),'earned commitment')
check(npc.partner=='host','shared exclusive partnership')
act(q,'introduce',72,'guest')
check(not act(q,'flirt',73,'guest'),'partner conflict across players')
check(not act(q,'breakup',74,'guest'),'other player cannot end partnership')
check(act(p,'breakup',75),'partners can separate')
check(npc.partner==nil and NLSocial.relation(p,'marisol').status=='Former partner','breakup clears shared state')
check(#NLSocial.relation(p,'marisol').memories<=12,'bounded memory')
npc.dead=true; check(not act(p,'chat',90),'dead NPC does not interact')
local copy=NLDomain.copy(w)
check(copy.players.host.relationships.marisol.status=='Former partner','serializable relationship data')
check(not NLSocial.interact(p,{id='unknown'},'chat',100,'host'),'unknown NPC rejected')
print('PASS: '..n..' social assertions (individual relationships, pacing, mutual interest, partnership conflict, breakup, memories)')
