package.path=arg[1]..'/42/media/lua/shared/?.lua;'..package.path
require 'NL/Domain'
local p=NLDomain.profile(NLDomain.newWorld(),'host')
assert(NLAspirations.advance(p)==0 and p.credits==0)
for day=1,3 do
    NLDomain.day(p,day)
    assert(NLDomain.complete(p,NLDomain.contracts(p)[1]))
end
assert(p.credits==45 and p.aspiration.stage==2,'actual completion triggers first bonus')
assert(NLAspirations.advance(p)==0 and p.credits==45,'repeat evaluation never rewards twice')
local saved=NLDomain.copy(p)
assert(NLAspirations.advance(saved)==0 and saved.credits==45,'saved reward state survives reload')
NLDomain.select(p,'medic')
assert(NLAspirations.advance(p)==0 and p.aspiration.stage==2,'career switch preserves aspiration')
p.careers.medic.delivered=6
assert(NLAspirations.advance(p)==0,'promotion gate is required')
p.careers.medic.rank=2
assert(NLAspirations.advance(p)==30 and p.aspiration.stage==3)
p.careers.medic.delivered=21; p.careers.medic.rank=4
assert(NLAspirations.advance(p)==60 and p.aspiration.stage==4)
assert(NLAspirations.advance(p)==0)
assert(NLAspirations.label(p)=='Aspiration complete: Neighborhood Pillar')
local guest=NLDomain.profile(NLDomain.newWorld(),'guest')
assert(NLAspirations.advance(guest)==0 and guest.credits==0,'player isolation')
print('PASS: aspiration milestones, delivery hook, promotion gate, one-time rewards, reload and player isolation')
