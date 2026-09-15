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
local home=NLDomain.profile(NLDomain.newWorld(),'homebody')
assert(NLAspirations.homeProgress(home)==0 and NLAspirations.advanceHome(home)==0)
assert(NLAspirations.recordHomeActivity(home,'tidy')==5 and home.homeAspiration.stage==2,
    'first household activity advances the home aspiration')
assert(NLAspirations.recordHomeActivity(home,'meal')==0 and NLAspirations.recordHomeActivity(home,'social')==10,
    'three distinct household activities award the shared-routine milestone')
assert(home.homeActivities.total==3 and NLAspirations.homeProgress(home)==3,
    'home activity counts persist by task and total')
assert(NLAspirations.recordHomeActivity(home,'bogus')==0 and home.homeAspiration.stage==3,
    'unknown household activity cannot advance the aspiration')
local guest=NLDomain.profile(NLDomain.newWorld(),'guest')
assert(NLAspirations.advance(guest)==0 and guest.credits==0,'player isolation')
print('PASS: aspiration milestones, delivery hook, promotion gate, one-time rewards, reload and player isolation')
