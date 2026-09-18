package.path=arg[1]..'/42/media/lua/client/?.lua;'..arg[1]..'/42/media/lua/shared/?.lua;'..package.path
package.preload['ISUI/ISPanel']=function() end
package.preload['ISUI/ISButton']=function() end
package.preload['NL/SimsButton']=function()
    NLSimsButton={}
    function NLSimsButton:new(x,y,w,h,label,target,callback)
        return {x=x,y=y,width=w,height=h,title=label,target=target,callback=callback,visible=true,
            initialise=function() end,
            setEnable=function(self,v) self.enabled=v; self.enable=v end,
            setVisible=function(self,v) self.visible=v end,
            setTitle=function(self,v) self.title=v end,
            setKind=function(self,v) self.nlKind=v end,
            setActive=function(self,v) self.nlActive=v end,
            setX=function(self,v) self.x=v end,setY=function(self,v) self.y=v end,
            setWidth=function(self,v) self.width=v end}
    end
    return NLSimsButton
end
ISPanel={}
function ISPanel:derive() local t={}; t.__index=t; return setmetatable(t,{__index=self}) end
function ISPanel:new(x,y,w,h) return setmetatable({x=x,y=y,width=w,height=h,children={}},self) end
function ISPanel:initialise() end
function ISPanel:addChild(c) self.children[#self.children+1]=c end
function ISPanel:setVisible(v) self.visible=v end
function ISPanel:bringToTop() end
function ISPanel:addToUIManager() self.attached=true end
function ISPanel:removeFromUIManager() self.attached=false end
function ISPanel:prerender() end
function ISPanel:drawText() end
function ISPanel:drawRect(x,y,w,h) assert(w>=0 and h>=0) end
function ISPanel:setX(v) self.x=v end
function ISPanel:setY(v) self.y=v end
ISButton={}
function ISButton:new(x,y,w,h,label,target,callback)
    return {target=target,callback=callback,title=label,initialise=function() end,
        setEnable=function(self,v) self.enabled=v end,setVisible=function(self,v) self.visible=v end,
        setTitle=function(self,v) self.title=v end}
end
Events={OnServerCommand={Add=function() end},OnRenderTick={Add=function() end},OnMainMenuEnter={Add=function() end}}
UIFont={Small=1}
function getNumActivePlayers() return 0 end
function getSpecificPlayer() return nil end
function getPlayerScreenLeft() return 0 end
function getPlayerScreenTop() return 0 end
function getPlayerScreenWidth() return 1280 end
function getPlayerScreenHeight() return 720 end
require 'NL/Relationships'
require 'NL/Social'
local requests={}
NLSocialClient.request=function(index,command,args) requests[#requests+1]={index=index,command=command,args=args} end
NLRelationships.open(0)
local panel=NLRelationships.instances[0]
panel:prerender(); assert(panel.actions[1].enabled==false)
local world=NLDomain.newWorld(); local p=NLDomain.profile(world,'host'); local rel=NLSocial.relation(p,'marisol')
NLSocialClient.snapshots[0]={neighbors={{id='marisol',name='Marisol Vega',age=31,personality='Creative',relation=rel,available=true,dead=false,distance=2,canInteract=true}},message='Hello',revision=1}
panel:prerender(); assert(panel.actions[1].enabled)
panel.actions[1].callback(panel,panel.actions[1])
assert(requests[#requests].command=='interact' and requests[#requests].args.action=='introduce')
assert(requests[#requests].args.id=='marisol')
NLRelationships.open(0); assert(NLRelationships.instances[0]==panel and panel.attached)
NLSocialClient.snapshots[0].neighbors[1].distance=5; NLSocialClient.snapshots[0].neighbors[1].canInteract=false
panel:prerender(); assert(not panel.actions[1].enabled)
NLSocialClient.snapshots[0].neighbors[1].distance=2; NLSocialClient.snapshots[0].neighbors[1].canInteract=true; NLSocialClient.snapshots[0].neighbors[1].dead=true
panel:prerender(); assert(not panel.actions[1].enabled)
NLSocialClient.snapshots[0].neighbors[1].dead=false
NLSocialClient.snapshots[0].neighbors[1].inventoryItems={{item='Base.Hammer',amount=1,label='Hammer'}}
local giveItem={getFullType=function() return 'Base.RippedSheets' end,getDisplayName=function() return 'Ripped Sheets' end}
local givePlayer={isDead=function() return false end,isEquipped=function() return false end,getInventory=function() return {getItems=function() return {size=function() return 1 end,get=function() return giveItem end} end} end}
function getSpecificPlayer() return givePlayer end
panel:prerender()
if panel.actions[9].value and panel.actions[9].value.item=='Base.Hammer' then
    assert(panel.actions[8].enabled and panel.actions[8].value.item=='Base.RippedSheets'); assert(panel.actions[9].enabled)
    panel.actions[8].callback(panel,panel.actions[8]); assert(requests[#requests].command=='give' and requests[#requests].args.item=='Base.RippedSheets')
    panel.actions[9].callback(panel,panel.actions[9]); assert(requests[#requests].command=='request' and requests[#requests].args.item=='Base.Hammer')
end
function getSpecificPlayer() return nil end
NLClient.profiles[0]=p; p.skill=0
NLJournal.open(0); NLJournal.instances[0]:prerender()
assert(NLJournal.instances[0].careerButtons.tailor.nlActive==true,'selected career uses shared active theme')
if NLJournal.instances[0].workButton then
    assert(NLJournal.instances[0].workButton.enabled,'career journal exposes a ready work-shift action')
    local originalJournalRequest=NLClient.request; local workCommand
    NLClient.request=function(_,command) workCommand=command end
    NLJournal.instances[0]:onButton(NLJournal.instances[0].workButton); NLClient.request=originalJournalRequest
    assert(workCommand=='work','career journal routes work shift')
end
print('PASS: relationship UI empty/populated/deceased states, callbacks, reopen and career selection theme')
if arg[2]=='wardrobe-panel' then
    package.preload['NL/Wardrobe']=function()
        NLWardrobe={save=function(p,slot) p.data.NeighborhoodOutfits[slot]={'Base.Shirt'} end,
            requestSave=function(p,slot) NLWardrobe.save(p,slot); if NLClient.profiles[0] then NLClient.profiles[0].outfits=p.data.NeighborhoodOutfits end end,
            wear=function(p,slot) p.worn=slot end}
    end
    require 'NL/WardrobePanel'
    local wearer={data={NeighborhoodOutfits={}},dead=false}
    function wearer:getModData() return self.data end
    function wearer:isDead() return self.dead end
    function getSpecificPlayer() return wearer end
    NLWardrobePanel.open(0)
    local w=NLWardrobePanel.instances[0]
    w:prerender(); assert(not w.slots[1].wear.enabled and w.slots[1].save.enabled)
    w.slots[1].save.callback(w,w.slots[1].save); w:prerender(); assert(w.slots[1].wear.enabled)
    w.slots[1].wear.callback(w,w.slots[1].wear); assert(wearer.worn==1)
    wearer.dead=true; w:prerender(); assert(not w.slots[1].save.enabled and not w.slots[1].wear.enabled)
    NLWardrobePanel.open(0); assert(w==NLWardrobePanel.instances[0] and w.attached)
    print('PASS: wardrobe panel empty/saved/dead states, save/wear callbacks and reopen')
end