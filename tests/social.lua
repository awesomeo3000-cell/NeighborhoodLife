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
check(act(p,'ask_work',1),'work conversation')
check(NLSocial.relation(p,'marisol').workTalks==1,'work conversation persists')
check(act(p,'talk_home',2),'home conversation')
check(NLSocial.relation(p,'marisol').homeTalks==1,'home conversation persists')
check(not act(p,'compliment',3),'compliment requires an established friendship')
check(act(p,'flirt',3),'early flirt gets response')
check(NLSocial.relation(p,'marisol').attraction==0,'rejected early advances do not grant attraction')
check(NLSocial.relation(q,'marisol').friendship==0,'separate players')
for t=2,10 do act(p,'chat',t) end
check(act(p,'compliment',11),'established friendship accepts a compliment')
check(NLSocial.relation(p,'marisol').compliments==1,'compliment persists')
check(NLSocial.relation(p,'marisol').attraction==2,'compliment adds bounded attraction')
check(not act(p,'compliment',12),'compliment pacing prevents spam')
for t=15,39,4 do act(p,'flirt',t) end
check(act(p,'date',45),'mutual-interest date')
check(NLSocial.relation(p,'marisol').activeDate.status=='active','date creates an active activity')
check(act(p,'date_activity',45.1),'date activity can follow immediately')
check(NLSocial.relation(p,'marisol').activeDate.status=='completed','date activity completes')
check(NLSocial.relation(p,'marisol').completedDates==1,'completed date count persists')
check(not act(p,'date',46),'daily date gate')
check(act(p,'date',70),'second date')
check(act(p,'date_activity',70.1),'second date activity completes')
check(NLSocial.relation(p,'marisol').completedDates==2,'two completed dates unlock commitment pacing')
check(act(p,'partner',71),'earned commitment')
check(npc.partner=='host','shared exclusive partnership')
act(q,'introduce',72,'guest')
check(not act(q,'flirt',73,'guest'),'partner conflict across players')
check(not act(q,'breakup',74,'guest'),'other player cannot end partnership')
check(act(p,'breakup',75),'partners can separate')
check(npc.partner==nil and NLSocial.relation(p,'marisol').status=='Former partner','breakup clears shared state')

-- Favorite gift checks
check(NLSocial.isFavorite('marisol','Base.Thread'),'thread is a favorite for marisol')
check(not NLSocial.isFavorite('marisol','Base.Hammer'),'hammer is not a favorite for marisol')
check(NLSocial.isFavorite('kenji','Base.Hammer'),'hammer is a favorite for kenji')
check(NLSocial.isFavorite('amara','Base.Bandage'),'bandage is a favorite for amara')

-- Gift giving mechanics
local marisolRel = NLSocial.relation(p,'marisol')
local friendBefore = marisolRel.friendship
local trustBefore = marisolRel.trust
local giftOk, giftMsg = NLSocial.giveGift(p, npc, 'Base.Apple', 76, 'host')
check(giftOk and marisolRel.friendship == friendBefore + 2 and marisolRel.trust == trustBefore + 1,
    'standard gift awards baseline relationship points')
local giftOk2, giftMsg2 = NLSocial.giveGift(p, npc, 'Base.Thread', 77, 'host')
check(giftOk2 and marisolRel.friendship == friendBefore + 8 and marisolRel.trust == trustBefore + 5,
    'favorite gift awards bonus relationship gains and custom appreciation')
check(string.find(giftMsg2, 'tailoring supplies') ~= nil, 'favorite gift generates tailored response')

-- Apology flow
marisolRel.friendship = -10
check(act(p, 'apologize', 78), 'apology accepted when friendship is negative')
check(marisolRel.friendship == -7, 'apology increases negative friendship')
marisolRel.friendship = 10
check(not act(p, 'apologize', 79), 'apology rejected when friendship is non-negative')

check(#NLSocial.relation(p,'marisol').memories<=12,'bounded memory')
npc.dead=true; check(not act(p,'chat',90),'dead NPC does not interact')
local copy=NLDomain.copy(w)
check(copy.players.host.relationships.marisol.status=='Former partner','serializable relationship data')
check(not NLSocial.interact(p,{id='unknown'},'chat',100,'host'),'unknown NPC rejected')
print('PASS: '..n..' social assertions (individual relationships, pacing, mutual interest, partnership conflict, breakup, favorites, gifts, apology, memories)')
