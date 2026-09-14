-- Production NPC adapter contract test. Native body calls are deterministic
-- fixtures here; this is not real engine movement evidence.
package.path = arg[1] .. '/42/media/lua/shared/?.lua;' .. arg[1] .. '/42/media/lua/server/?.lua;' .. package.path
local function hook() return {Add=function(f) return f end} end
local saveHook
Events={OnClientCommand=hook(),OnRenderTick=hook(),OnMainMenuEnter=hook(),OnGameStart=hook(),OnTick=hook(),
    OnSave={Add=function(f) saveHook=f end}}
function isClient() return false end
function isServer() return false end
local worldStore={}
ModData={getOrCreate=function(key) worldStore[key]=worldStore[key] or {}; return worldStore[key] end}
function getTimestampMs() return 1000 end
function getGameTime() return {getWorldAgeHours=function() return 0 end} end
Perks={Tailoring='Tailoring',Woodwork='Woodwork',Doctor='Doctor'}
local player={x=100,y=100,z=0,dead=false}
function player:getX() return self.x end; function player:getY() return self.y end
function player:getZ() return self.z end; function player:getPlayerNum() return 0 end
function player:getUsername() return 'npc-test-player' end; function player:isDead() return self.dead end
function getSpecificPlayer() return player end
local function square(x,y,z)
    return {getX=function() return x end,getY=function() return y end,getZ=function() return z end,
        isFree=function() return true end}
end
local objects={contains=function() return false end,add=function() end}
function getCell() return {getGridSquare=function(_,x,y,z) local s=square(x,y,z); s.getObjectList=function() return objects end; return s end,
    getObjectList=function() return objects end} end
SurvivorFactory={CreateSurvivor=function() return {
    setForename=function() end,setSurname=function() end,setFemale=function() end} end}
BehaviorResult={Succeeded='succeeded'}
local function bodyAt(cell,desc,x,y,z)
    local b={x=x+0.5,y=y+0.5,z=z,mod={}}
    function b:setNpc(v) self.npc=v end; function b:isNpc() return self.npc end
    function b:setUsername(v) self.username=v end; function b:setGodMod() end
    function b:getModData() return self.mod end; function b:dressInNamedOutfit() end
    function b:setX(v) self.x=v end; function b:setY(v) self.y=v end; function b:getX() return self.x end
    function b:getY() return self.y end; function b:getZ() return self.z end
    function b:setCurrent(v) self.current=v end; function b:setSceneCulled() end
    function b:setAlphaAndTarget() end; function b:resetModelNextFrame() end
    function b:isDead() return false end; function b:hasPath() return false end
    local behavior={}
    function behavior:pathToLocation(x1,y1,z1) self.target={x=x1,y=y1,z=z1} end
    function behavior:update() return BehaviorResult.Succeeded end
    function behavior:cancel() self.target=nil end
    function b:getPathFindBehavior2() return behavior end
    function b:setPath2() end
    function b:preupdate() end; function b:update() end; function b:postupdate() end
    return b
end
IsoPlayer={new=bodyAt}
NLAuthority={module='NeighborhoodLife',world=function() local w=ModData.getOrCreate('NeighborhoodLife_v2'); w.version=w.version or 2; return w end}
package.preload['NL/Authority']=function() return NLAuthority end
package.preload['NL/SocialAuthority']=function() NLSocialAuthority={bodies={},register=function(id,b,h) NLSocialAuthority.bodies[id]=b; return true end}; return NLSocialAuthority end
NLQANpc=true
require 'NL/NpcAuthority'
assert(NLNpcAuthority and type(NLNpcAuthority.start)=='function')
NLNpcAuthority.start()
local body=NLNpcAuthority.bodies.marisol
assert(body and body:isNpc() and body:getModData().NeighborhoodNpcId=='marisol','production body created')
local row=NLAuthority.world().neighbors.marisol
assert(row and row.spawned and row.position.x==body:getX(),'body position persisted')
local savedX,savedY=row.position.x,row.position.y
body:setX(savedX+0.37); body:setY(savedY+0.23)
if saveHook then
    assert(saveHook()==1,'save hook persists the latest native body position')
    assert(math.abs(row.position.x-body:getX())<0.001 and math.abs(row.position.y-body:getY())<0.001,
        'save hook writes the current authoritative position')
    savedX,savedY=row.position.x,row.position.y
end
NLNpcAuthority.update()
assert(row.position.x==body:getX() and row.position.y==body:getY(),'route tick keeps registry authoritative')
NLNpcAuthority.reset()
NLNpcAuthority.start()
local restored=NLNpcAuthority.bodies.marisol
assert(restored and math.abs(restored:getX()-savedX)<0.001 and math.abs(restored:getY()-savedY)<0.001,
    'saved position restores into the native body')
print('PASS: production NPC identity, native body adapter, route tick and save/reload position restoration')
