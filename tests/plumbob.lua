local root = arg[1]
package.path = root .. '/42/media/lua/client/?.lua;' .. root .. '/42/media/lua/shared/?.lua;' .. package.path
package.preload['ISUI/ISPanel'] = function() end
ISPanel = {}
function ISPanel:derive() local t = {}; t.__index = t; setmetatable(t, {__index=self}); return t end
function ISPanel:new(x,y,w,h) return setmetatable({x=x,y=y,width=w,height=h}, self) end
function ISPanel:initialise() end
function ISPanel:addToUIManager() self.attached=true end
function ISPanel:removeFromUIManager() self.attached=false end
function ISPanel:bringToTop() end
function ISPanel:setVisible(v) self.visible=v end
function ISPanel:setWidth(v) self.width=v end
function ISPanel:setHeight(v) self.height=v end
function ISPanel:setX(v) self.x=v end
function ISPanel:setY(v) self.y=v end
function ISPanel:prerender() end
function ISPanel:drawTextureScaled() end
function ISPanel:drawRect() end
Events={OnCreatePlayer={Add=function() end},OnRenderTick={Add=function() end},OnMainMenuEnter={Add=function() end}}
function getTexture(path) return {path=path} end
function getSpecificPlayer() return {alive=true} end
function getCore() return {getZoom=function() return 1 end} end
function getPlayerScreenLeft() return 0 end
function getPlayerScreenTop() return 0 end
function isoToScreenX() return 100 end
function isoToScreenY() return 300 end

dofile(root .. '/42/media/lua/client/NL/Plumbob.lua')
assert(NLPlumbob.screenPosition(100,200,0,0,40,56,128)==80)
local character={getX=function() return 12 end,getY=function() return 13 end,getZ=function() return 0 end,isDead=function() return false end}
local panel=NLPlumbob.register('test:character',character,0)
assert(panel.texture.path=='media/textures/NL_Plumbob.png')
assert(panel.visible,"registered plumbob must start visible so UIManager can prerender it")
panel:prerender()
assert(panel.visible and panel.x==math.floor(100-panel.width/2))
local expectedLift = NLPlumbob.baseLift or 128
assert(panel.y==300-panel.height-expectedLift)
if NLPlumbob.baseWidth then
    assert(panel.width==NLPlumbob.baseWidth and panel.height==NLPlumbob.baseHeight,
        "plumbob panel uses its configured compact dimensions")
    if NLPlumbob.baseWidth==3 then
        assert(NLPlumbob.baseHeight==5 and NLPlumbob.baseLift==20,
            "plumbob uses the pin-sized, close placement dimensions")
    end
    if NLPlumbob.baseWidth <= 12 then
        assert(NLPlumbob.baseHeight <= 16,
            "plumbob remains smaller than the character model")
        if NLPlumbob.baseWidth==6 then
            assert(NLPlumbob.baseLift <= 30,
                "plumbob tip stays close to the character")
        else
            assert(NLPlumbob.baseLift <= 80,
                "plumbob tip stays within the compact placement range")
        end
    end
end
character.isDead=function() return true end; panel:prerender(); assert(not panel.visible)
NLPlumbob.unregister('test:character'); assert(NLPlumbob.instances['test:character']==nil)
local localPlayer={getX=function() return 12 end,getY=function() return 13 end,getZ=function() return 0 end,isDead=function() return false end}
local remotePlayer={getUsername=function() return 'nl-guest' end,getX=function() return 14 end,getY=function() return 13 end,getZ=function() return 0 end,isDead=function() return false end}
function getNumActivePlayers() return 1 end
function getSpecificPlayer() return localPlayer end
function getOnlinePlayers() return {size=function() return 2 end,get=function(_,i) return i==0 and localPlayer or remotePlayer end} end
if NLPlumbob.syncRemotePlayers then
    assert(NLPlumbob.syncRemotePlayers()==2)
    assert(NLPlumbob.instances['remote:nl-guest'].character==remotePlayer)
    function getOnlinePlayers() return {size=function() return 1 end,get=function() return localPlayer end} end
    NLPlumbob.syncRemotePlayers(); assert(NLPlumbob.instances['remote:nl-guest']==nil)
end
if NLPlumbob.applyPresence then
    assert(NLPlumbob.applyPresence({revision=10,players={{username='nl-guest',x=104,y=205,z=0}}})==1)
    local presence=NLPlumbob.instances['presence:nl-guest']
    assert(presence and presence.character.isPresence and presence.character.x==104,
        'authoritative presence creates a marker-only remote fallback')
    NLPlumbob.applyPresence({revision=11,players={}})
    assert(NLPlumbob.instances['presence:nl-guest']==nil,'empty presence removes fallback marker')
end
print('PASS: plumbob asset lookup, screen anchoring, dead-character hide, registration and cleanup')
