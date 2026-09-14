-- Client NPC replica contract test. This uses native-shaped fixtures; it is
-- not two-client or real gameplay evidence.
package.path = arg[1] .. '/42/media/lua/client/?.lua;' .. package.path
function isClient() return true end
local hooks={Add=function() end}
local disconnectHook
Events={OnTick=hooks,OnMainMenuEnter=hooks,OnCreatePlayer=hooks,OnRenderTick=hooks,
    OnDisconnect={Add=function(f) disconnectHook=f end}}
package.preload['ISUI/ISPanel']=function() end
ISPanel={}
function ISPanel:derive() local t={}; t.__index=t; return setmetatable(t,{__index=self}) end
function ISPanel:new(x,y,w,h) return setmetatable({x=x,y=y,width=w,height=h},self) end
function ISPanel:initialise() end; function ISPanel:addToUIManager() end
function ISPanel:removeFromUIManager() end; function ISPanel:bringToTop() end
function ISPanel:setVisible(v) self.visible=v end; function ISPanel:setWidth(v) self.width=v end
function ISPanel:setHeight(v) self.height=v end; function ISPanel:setX(v) self.x=v end
function ISPanel:setY(v) self.y=v end
local plumbobs={}
NLPlumbob={remoteColor={r=1,g=1,b=1},register=function(id,b) plumbobs[id]=b; return b end,
    unregister=function(id) plumbobs[id]=nil end}
package.preload['NL/Plumbob']=function() return NLPlumbob end
function getTexture(path) return {path=path} end
local objects={}
function objects:size() return #objects end
function objects:get(i) return objects[i+1] end
function objects:contains(object) for _,v in ipairs(self) do if v==object then return true end end return false end
function objects:add(object) self[#self+1]=object end
function objects:remove(object) for i,v in ipairs(self) do if v==object then table.remove(self,i); return end end end
local cell={getObjectListForLua=function() return objects end,getObjectList=function() return objects end}
function cell:getGridSquare(x,y,z) return {getX=function() return x end,getY=function() return y end,getZ=function() return z end} end
function getCell() return cell end
local function desc() return {setForename=function() end,setSurname=function() end,setFemale=function() end} end
SurvivorFactory={CreateSurvivor=desc}
IsoPlayer={new=function(_,_,x,y,z)
    local b={x=x+0.5,y=y+0.5,z=z,data={}}
    function b:setNpc(v) self.npc=v end; function b:setUsername(v) self.username=v end
    function b:setGodMod() end; function b:getModData() return self.data end
    function b:dressInNamedOutfit() end; function b:setSceneCulled() end
    function b:setAlphaAndTarget() end; function b:resetModelNextFrame() end
    function b:setX(v) self.x=v end; function b:setY(v) self.y=v end; function b:setZ(v) self.z=v end
    function b:getX() return self.x end; function b:getY() return self.y end; function b:getZ() return self.z end
    function b:setCurrent(v) self.current=v end
    function b:preupdate() end; function b:update() end; function b:postupdate() end
    local behavior={}
    function behavior:pathToLocation(x,y,z) self.pathTarget={x=x,y=y,z=z} end
    function behavior:update()
        if self.pathTarget then
            local dx=self.pathTarget.x-self.owner:getX(); local dy=self.pathTarget.y-self.owner:getY()
            self.owner:setX(self.owner:getX()+math.min(0.25,math.abs(dx))*(dx<0 and -1 or 1))
            self.owner:setY(self.owner:getY()+math.min(0.25,math.abs(dy))*(dy<0 and -1 or 1))
        end
    end
    function behavior:cancel() end
    behavior.owner=b
    function b:getPathFindBehavior2() return behavior end
    return b
end}
require 'NL/NpcClient'
assert(NLNpcClient.apply({revision=1,npcs={
    {id='marisol',name='Marisol Vega',female=true,x=10,y=11,z=0,alive=true},
    {id='kenji',name='Kenji Arakawa',female=false,x=12,y=11,z=0,alive=true}
}})==2)
local body=NLNpcClient.bodies.marisol
assert(body and body.npc and body:getModData().NeighborhoodNpcId=='marisol','native replica created')
assert(plumbobs['npc:marisol']==body,'replica plumbob registered')
assert(NLNpcClient.bodies.kenji and plumbobs['npc:kenji']==NLNpcClient.bodies.kenji,
    'second authored replica and plumbob registered')
NLNpcClient.apply({revision=2,npcs={
    {id='marisol',x=11,y=11,z=0,alive=true},
    {id='kenji',x=13,y=11,z=0,alive=true}
}})
NLNpcClient.update(); assert(body:getX()>10 and body:getX()<11,'replica interpolates authoritative target')
if NLNpcClient.modes then
    assert(NLNpcClient.modes.marisol=='native','replica uses native path frame when available')
end
if NLNpcClient.bodyPresent then
    local oldKenji=NLNpcClient.bodies.kenji
    objects:remove(oldKenji)
    NLNpcClient.apply({revision=3,npcs={{id='marisol',x=11,y=11,z=0,alive=true},{id='kenji',x=14,y=11,z=0,alive=true}}})
    assert(NLNpcClient.bodies.kenji and NLNpcClient.bodies.kenji~=oldKenji,
        'stale native handle is replaced after client cell streaming removes it')
    assert(plumbobs['npc:kenji']==NLNpcClient.bodies.kenji,
        'recreated streamed replica receives a fresh plumbob')
end
local promotionSupported=body:getModData().NeighborhoodNpcReplica==true
local lateNative
local expectedBody=body
if promotionSupported then
    lateNative=IsoPlayer.new(nil,nil,20,20,0)
    lateNative:getModData().NeighborhoodNpcId='marisol'
    objects:add(lateNative)
    NLNpcClient.apply({revision=4,npcs={{id='marisol',x=20,y=20,z=0,alive=true},{id='kenji',x=14,y=11,z=0,alive=true}}})
    assert(NLNpcClient.bodies.marisol==lateNative,
        'late server-native body promotes over an existing compatibility replica')
    assert(plumbobs['npc:marisol']==lateNative,
        'promoted native body receives the existing plumbob registration')
    expectedBody=lateNative
    if NLNpcClient.reconcileNativeBodies then
        objects:remove(lateNative)
        NLNpcClient.bodies.marisol=nil
        NLNpcClient.modes.marisol=nil
        NLPlumbob.unregister('npc:marisol')
        NLNpcClient.apply({revision=5,npcs={{id='marisol',x=21,y=20,z=0,alive=true},{id='kenji',x=14,y=11,z=0,alive=true}}})
        local packetlessNative=IsoPlayer.new(nil,nil,22,20,0)
        packetlessNative:getModData().NeighborhoodNpcId='marisol'
        objects:add(packetlessNative)
        assert(NLNpcClient.reconcileNativeBodies()==1
            and NLNpcClient.bodies.marisol==packetlessNative,
            'loaded-cell native body promotes without a new presence packet')
        assert(plumbobs['npc:marisol']==packetlessNative,
            'packetless native promotion keeps the plumbob attached')
        expectedBody=packetlessNative
    end
end
local xAfterNewer=body:getX()
local targetAfterNewer=NLNpcClient.targets.marisol
if NLNpcClient.revision then
    NLNpcClient.apply({revision=1,npcs={}})
    assert(NLNpcClient.targets.marisol==targetAfterNewer and NLNpcClient.bodies.marisol==expectedBody,
        'stale NPC packet is ignored')
end
NLNpcClient.apply({revision=5,npcs={}})
assert(NLNpcClient.bodies.marisol==nil and NLNpcClient.bodies.kenji==nil
    and plumbobs['npc:marisol']==nil and plumbobs['npc:kenji']==nil,
    'replica cleanup follows authoritative roster')
if disconnectHook then
    assert(disconnectHook,'disconnect cleanup hook registered')
    disconnectHook('server restart','qa')
else
    NLNpcClient.cleanup()
end
assert(NLNpcClient.revision==0,'disconnect/menu cleanup resets NPC revision')
print('PASS: client NPC native replica creation, authoritative interpolation, plumbob and cleanup')
