-- Authoritative remote-player presentation contract. Native-shaped fixtures are
-- not two-client gameplay evidence.
package.path = arg[1] .. '/42/media/lua/client/?.lua;' .. package.path
function isClient() return true end
local hooks = { Add=function() end }
Events = { OnTick=hooks, OnMainMenuEnter=hooks, OnDisconnect=hooks }
local plumbob = { instances={} }
package.preload['NL/Plumbob'] = function() return plumbob end
function getNumActivePlayers() return 1 end
local localPlayer = { name='nl-guest' }
function localPlayer:getUsername() return self.name end
function getSpecificPlayer() return localPlayer end

local objects={}
function objects:size() return #objects end
function objects:get(i) return objects[i+1] end
function objects:contains(value) for _,v in ipairs(self) do if v==value then return true end end return false end
function objects:add(value) self[#self+1]=value end
function objects:remove(value) for i,v in ipairs(self) do if v==value then table.remove(self,i); return end end end
local cell={getObjectList=function() return objects end,
    getObjectListForLua=function() return objects end,
    getGridSquare=function(_,x,y,z) return {getX=function() return x end,getY=function() return y end,getZ=function() return z end} end}
function getCell() return cell end
local function desc()
    return {setForename=function() end,setSurname=function() end,setFemale=function() end}
end
SurvivorFactory={CreateSurvivor=desc}
IsoPlayer={new=function(_,_,x,y,z)
    local body={x=x+0.5,y=y+0.5,z=z,data={}}
    function body:setNpc(v) self.npc=v end; function body:setUsername(v) self.username=v end
    function body:setGodMod() end; function body:getModData() return self.data end
    function body:setSceneCulled() end; function body:setAlphaAndTarget() end
    function body:resetModelNextFrame() end; function body:setX(v) self.x=v end
    function body:setY(v) self.y=v end; function body:setZ(v) self.z=v end
    function body:getX() return self.x end; function body:getY() return self.y end
    function body:getZ() return self.z end; function body:setCurrent(v) self.current=v end
    function body:preupdate() end; function body:update() end; function body:postupdate() end
    local behavior={owner=body}
    function behavior:pathToLocation(x1,y1,z1) self.target={x=x1,y=y1,z=z1} end
    function behavior:update()
        if self.target then
            local dx=self.target.x-self.owner:getX(); local dy=self.target.y-self.owner:getY()
            self.owner:setX(self.owner:getX()+math.min(0.25,math.abs(dx))*(dx<0 and -1 or 1))
            self.owner:setY(self.owner:getY()+math.min(0.25,math.abs(dy))*(dy<0 and -1 or 1))
        end
    end
    function behavior:cancel() end
    function body:getPathFindBehavior2() return behavior end
    return body
end}
local online={localPlayer}
function getOnlinePlayers() return {size=function() return #online end,get=function(_,i) return online[i+1] end} end
require 'NL/RemotePlayerClient'

local function check(value,label) assert(value,label) end
check(NLRemotePlayerClient.apply({revision=1,players={{username='nl-host',x=10,y=11,z=0}}})==1,
    'presence packet accepted')
local replica=NLRemotePlayerClient.bodies['nl-host']
check(replica and replica:getModData().NeighborhoodRemotePlayerId=='nl-host',
    'missing native peer gets a local native replica')
check(NLRemotePlayerClient.modes['nl-host']=='replica','replica mode recorded')
NLRemotePlayerClient.apply({revision=2,players={{username='nl-host',x=12,y=11,z=0}}})
NLRemotePlayerClient.update()
check(replica:getX()>10,'new authoritative position moves the replica')
local target=NLRemotePlayerClient.targets['nl-host']
NLRemotePlayerClient.apply({revision=1,players={}})
check(NLRemotePlayerClient.targets['nl-host']==target,'stale presence is ignored')

local native={name='nl-host',x=20,y=21,z=0,data={}}
function native:getUsername() return self.name end; function native:getModData() return self.data end
function native:getX() return self.x end; function native:getY() return self.y end; function native:getZ() return self.z end
online={localPlayer,native}
NLRemotePlayerClient.apply({revision=3,players={{username='nl-host',x=20,y=21,z=0}}})
check(NLRemotePlayerClient.bodies['nl-host']==native,'native engine body wins when available')
check(NLRemotePlayerClient.modes['nl-host']=='engine','engine mode recorded')
check(not objects:contains(replica),'fallback replica removed after native body appears')
online={localPlayer}
local cellNative={name='nl-host',x=30,y=31,z=0,data={}}
function cellNative:getUsername() return self.name end
function cellNative:getModData() return self.data end
function cellNative:getX() return self.x end; function cellNative:getY() return self.y end
function cellNative:getZ() return self.z end
objects:add(cellNative)
if NLRemotePlayerClient.findNativePlayer then
    check(NLRemotePlayerClient.findNativePlayer('nl-host')==cellNative,
        'loaded-cell native peer is discoverable when online-player list is empty')
end
NLRemotePlayerClient.apply({revision=4,players={{username='nl-host',x=30,y=31,z=0}}})
if NLRemotePlayerClient.cellNativeDiscoverySupported then
    check(NLRemotePlayerClient.bodies['nl-host']==cellNative,
        'loaded-cell native peer wins when online-player list is temporarily empty')
    check(NLRemotePlayerClient.modes['nl-host']=='engine','loaded-cell native mode recorded')
end
NLRemotePlayerClient.apply({revision=5,players={}})
check(NLRemotePlayerClient.bodies['nl-host']==nil,'roster removal clears remote body state')
NLRemotePlayerClient.cleanup(); check(NLRemotePlayerClient.revision==0,'cleanup resets revision')
print('PASS: remote player replica creation, authoritative movement, native promotion, stale rejection and cleanup')
