package.path = arg[1] .. '/42/media/lua/shared/?.lua;' .. arg[1] .. '/42/media/lua/server/?.lua;' .. package.path
local passed=0
local function check(condition,label) assert(condition,label); passed=passed+1 end
local server = true
function isClient() return false end
function isServer() return server end
local time,day=1000,0
function getTimestampMs() time=time+250; return time end
function getGameTime() return {getWorldAgeHours=function() return day*24 end} end
local persisted={}
ModData={getOrCreate=function(key) persisted[key]=persisted[key] or {}; return persisted[key] end}
Events={OnClientCommand={Add=function() end},OnRenderTick={Add=function() end},OnMainMenuEnter={Add=function() end}}
Perks={Tailoring='Tailoring',Woodwork='Woodwork',Doctor='Doctor'}
local packets,removed={},0
function sendServerCommand(player,module,command,args) packets[#packets+1]={player=player,args=args} end
function sendRemoveItemFromContainer() removed=removed+1 end
local function list(items)
    return {size=function() return #items end,get=function(_,i) return items[i+1] end}
end
local function item(fullType) return {getFullType=function() return fullType end} end
local function player(name)
    local p={name=name,items={},skill=0,dead=false}
    function p:getUsername() return self.name end
    function p:getPlayerNum() return 0 end
    function p:isDead() return self.dead end
    function p:getPerkLevel() return self.skill end
    function p:isEquipped(i) return i.equipped==true end
    function p:getInventory()
        local outer=self
        return {getItems=function() return list(outer.items) end,Remove=function(_,obj)
            for i,v in ipairs(outer.items) do if v==obj then table.remove(outer.items,i); return end end
        end}
    end
    return p
end
require 'NL/Authority'
local a,b=player('host'),player('guest')
local function cmd(p,c,args) NLAuthority.command('NeighborhoodLife',c,p,args or {}) end
local function profile(p) return NLDomain.profile(NLAuthority.world(),p.name) end
cmd(a,'refresh'); cmd(b,'refresh')
check(profile(a)~=profile(b),'isolated profiles')
check(packets[1].player==a and packets[2].player==b,'private snapshot recipients')
packets[1].args.credits=999; check(profile(a).credits==0,'snapshot detached from authority')
cmd(a,'select',{career='bogus'}); check(profile(a).career=='tailor','invalid career rejected')
cmd(a,'select',{career='carpenter',username='guest'}); check(profile(b).career=='tailor','spoofed target ignored')
cmd(a,'select',{career='tailor'})
local contract=NLDomain.contracts(profile(a))[1]
cmd(a,'deliver',{id=contract.id}); check(profile(a).credits==0,'empty inventory rejected')
for i=1,6 do a.items[#a.items+1]=item('Base.RippedSheets') end
a.items[1].equipped=true
cmd(a,'deliver',{id=contract.id}); check(#a.items==6 and profile(a).credits==0,'equipped item excluded; no partial consume')
a.items[1].equipped=false
cmd(a,'deliver',{id=contract.id}); check(profile(a).credits==10 and #a.items==0 and removed==6,'delivery consumed and synchronized once')
cmd(a,'deliver',{id=contract.id}); check(profile(a).credits==10 and removed==6,'replayed delivery no extra reward')
cmd(a,'select',{career='medic'}); cmd(a,'select',{career='tailor'}); cmd(a,'deliver',{id=contract.id})
check(profile(a).credits==10,'career switching cannot reset claims')
cmd(a,'promote'); check(profile(a).careers.tailor.rank==1,'premature promotion denied')
for slot=2,3 do
    local c=NLDomain.contracts(profile(a))[slot]
    for i=1,c.amount do a.items[#a.items+1]=item(c.item) end
    cmd(a,'deliver',{id=c.id})
end
check(profile(a).careers.tailor.xp==60,'three distinct contracts grant 60 XP')
cmd(a,'promote'); check(profile(a).careers.tailor.rank==1,'skill gate enforced')
a.skill=1; cmd(a,'promote'); check(profile(a).careers.tailor.rank==2,'earned promotion')
check(profile(b).credits==0 and profile(b).careers.tailor.rank==1,'guest progress unaffected')
day=1; cmd(a,'refresh')
local claimCount=0; for _ in pairs(profile(a).claimed) do claimCount=claimCount+1 end
check(claimCount==0,'day rollover')
local earnedCredits=profile(a).credits
cmd(a,'deliver',{id=contract.id}); check(profile(a).credits==earnedCredits,'old day token rejected')
local before=profile(a).credits
a.dead=true; cmd(a,'select',{career='medic'}); check(profile(a).career=='tailor','dead player rejected'); a.dead=false
NLAuthority.command('OtherMod','select',a,{career='medic'})
check(profile(a).career=='tailor','foreign module ignored')
NLAuthority.command('NeighborhoodLife','select',a,nil)
check(profile(a).career=='tailor','missing args ignored')
local saved=NLDomain.copy(persisted)
persisted=NLDomain.copy(saved); NLAuthority.lastRequest={}
cmd(a,'refresh'); check(profile(a).careers.tailor.rank==2 and profile(a).credits==before,'reloaded world data preserved')
local original=getTimestampMs
function getTimestampMs() return time end
cmd(a,'select',{career='medic'}); check(profile(a).career=='tailor','rate limit blocks rapid requests')
getTimestampMs=original
-- Client routing: two independently observed profiles even when both peers use slot zero.
server=false
local clients={[0]=a,[1]=b}
function getNumActivePlayers() return 2 end
function getSpecificPlayer(i) return clients[i] end
Events.OnServerCommand={Add=function() end}
package.path=arg[1]..'/42/media/lua/client/?.lua;'..package.path
require 'NL/Client'
local snapshot=NLDomain.copy(profile(b)); snapshot.username='guest'
NLClient.receive('NeighborhoodLife','snapshot',snapshot)
check(NLClient.profiles[0]==nil and NLClient.profiles[1]==snapshot,'client routes by authenticated character identity')
local stale=NLDomain.copy(snapshot); stale.revision=-1
NLClient.receive('NeighborhoodLife','snapshot',stale)
check(NLClient.profiles[1]~=stale,'out-of-order snapshot ignored')
print('PASS: '..passed..' gameplay assertions (authority, deliveries, promotions, routing, persistence, replay and malformed input)')
