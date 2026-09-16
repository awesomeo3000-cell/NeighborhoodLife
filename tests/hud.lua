local file,mode=arg[1],arg[2]
package.preload['ISUI/ISPanel']=function() end
package.preload['ISUI/ISButton']=function() end
local opened={career=0,social=0,wardrobe=0,home=0}
package.preload['NL/Journal']=function() NLJournal={open=function() opened.career=opened.career+1 end} end
package.preload['NL/Relationships']=function() NLRelationships={open=function() opened.social=opened.social+1 end} end
package.preload['NL/WardrobePanel']=function() NLWardrobePanel={open=function() opened.wardrobe=opened.wardrobe+1 end} end
package.preload['NL/HouseholdPanel']=function() NLHouseholdPanel={open=function() opened.home=opened.home+1 end} end
package.preload['NL/Plumbob']=function() NLPlumbob={} return NLPlumbob end
package.preload['NL/NpcInteractionMenu']=function() return {} end
ISPanel={}
function ISPanel:derive() local t={}; t.__index=t; setmetatable(t,{__index=self}); return t end
function ISPanel:new(x,y,w,h) return setmetatable({x=x,y=y,width=w,height=h,children={}},self) end
local count=0
function ISPanel:initialise() end
function ISPanel:addChild(c) self.children[#self.children+1]=c end
function ISPanel:addToUIManager() count=count+1 end
function ISPanel:removeFromUIManager() count=count-1 end
function ISPanel:setHeight(v) self.height=v end
function ISPanel:setWidth(v) self.width=v end
function ISPanel:setX(v) self.x=v end
function ISPanel:setY(v) self.y=v end
function ISPanel:prerender() end
function ISPanel:drawText() end
function ISPanel:drawTextRight() end
function ISPanel:drawRect(x,y,w,h) assert(w>=0 and h>=0) end
ISButton={}
function ISButton:new(x,y,w,h,label,target,callback)
    return {x=x,y=y,width=w,height=h,title=label,target=target,callback=callback,visible=true,
        initialise=function() end,setX=function(self,v) self.x=v end,setY=function(self,v) self.y=v end,
        setWidth=function(self,v) self.width=v end,setVisible=function(self,v) self.visible=v end}
end
UIFont={Small=1}
function getTextManager() return {getFontHeight=function() return 14 end} end
Events={OnCreatePlayer={Add=function() end},OnMainMenuEnter={Add=function() end},OnTick={Add=function() end}}
CharacterStat={}
for _,key in ipairs({'HUNGER','THIRST','FATIGUE','BOREDOM','STRESS','UNHAPPINESS'}) do
    local max=(key=='BOREDOM' or key=='UNHAPPINESS') and 100 or 1
    CharacterStat[key]={key=key,getMinimumValue=function() return 0 end,getMaximumValue=function() return max end}
end
local function player(value,username)
    return {getUsername=function() return username end,isDead=function() return false end,getStats=function() return {get=function(_,stat) return value*stat:getMaximumValue() end} end}
end
local players={[0]=player(0.2,'nl-host'),[1]=player(0.8,'nl-guest')}
function getSpecificPlayer(i) return players[i] end
function getPlayerScreenLeft(i) return i*960 end
function getPlayerScreenTop() return 0 end
function getPlayerScreenWidth() return 960 end
function getPlayerScreenHeight() return 720 end

dofile(file)
NeighborhoodNeeds.create(0,players[0])
if mode=='disabled' then assert(count==0); print('PASS: HUD disabled; 0 panels'); return end
assert(count==1)
NeighborhoodNeeds.create(0,players[0]); assert(count==1)
NeighborhoodNeeds.create(1,players[1]); assert(count==2)
assert(NeighborhoodNeeds.header(players[0],0)=='NEIGHBORHOOD LIFE / nl-host')
assert(NeighborhoodNeeds.header(players[1],1)=='NEIGHBORHOOD LIFE / nl-guest')
for _,key in ipairs({'HUNGER','THIRST','FATIGUE','BOREDOM','STRESS','UNHAPPINESS'}) do
    assert(math.abs(NeighborhoodNeeds.read(players[0],key)-0.2)<0.0001)
    assert(math.abs(NeighborhoodNeeds.read(players[1],key)-0.8)<0.0001)
end
assert(NeighborhoodNeeds.read(player(-1),'HUNGER')==0)
assert(NeighborhoodNeeds.read(player(2),'THIRST')==1)
assert(NeighborhoodNeeds.read(players[0],'MISSING')==nil)
assert(NeighborhoodNeeds.read(player(0/0),'HUNGER')==nil)
local panel=NeighborhoodNeeds.instances[0]
assert(#panel.navButtons==5,'HUD exposes five visible feature buttons')
panel:prerender(); assert(panel.x==12 and panel.y>=0 and panel.width==360)
for _,b in ipairs(panel.navButtons) do assert(b.visible and b.width>0,'feature navigation button is visible') end
panel:onNavButton(panel.navButtons[1]); panel:onNavButton(panel.navButtons[2]); panel:onNavButton(panel.navButtons[3]); panel:onNavButton(panel.navButtons[5])
assert(opened.career==1 and opened.social==1 and opened.home==1 and opened.wardrobe==1,'visible HUD buttons route to feature panels')
local origWidth=getPlayerScreenWidth
getPlayerScreenWidth=function() return 2560 end
panel:prerender(); assert(panel.width==480,'HUD scales width appropriately on higher resolutions')
getPlayerScreenWidth=origWidth
panel:prerender(); assert(panel.width==360,'HUD restores baseline width')
panel:onMouseDown(5,5); assert(panel.collapsed and panel.height==panel.headerHeight)
for _,b in ipairs(panel.navButtons) do assert(not b.visible,'navigation hides with collapsed HUD') end
panel:prerender(); panel:onMouseDown(5,5); assert(not panel.collapsed)
players[0]=player(0.4); panel:prerender(); assert(panel.player==players[0])
players[0]=nil; panel:prerender(); NeighborhoodNeeds.instances[1]:prerender()
NeighborhoodNeeds.cleanup(); assert(count==0)
print('PASS: normalization, visible feature navigation, scaling, fold, reconnect and cleanup')