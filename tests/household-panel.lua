package.path = arg[1] .. '/42/media/lua/client/?.lua;' .. arg[1] .. '/42/media/lua/shared/?.lua;' .. package.path
package.preload['ISUI/ISPanel'] = function() end
package.preload['ISUI/ISButton'] = function() end
ISPanel = {}
function ISPanel:derive() local t = {}; t.__index = t; return setmetatable(t, {__index=self}) end
function ISPanel:new(x,y,w,h) return setmetatable({x=x,y=y,width=w,height=h,children={}}, self) end
function ISPanel:initialise() end
function ISPanel:addChild(child) self.children[#self.children+1] = child end
function ISPanel:setVisible(value) self.visible = value end
function ISPanel:bringToTop() end
function ISPanel:addToUIManager() self.attached = true end
function ISPanel:removeFromUIManager() self.attached = false end
function ISPanel:prerender() end
function ISPanel:drawText() end
function ISPanel:setX(value) self.x = value end
function ISPanel:setY(value) self.y = value end
ISButton = {}
function ISButton:new(x,y,w,h,label,target,callback)
    return {target=target, callback=callback, setEnable=function(self, value) self.enabled=value end,
        initialise=function() end}
end
Events = {OnServerCommand={Add=function() end}, OnMainMenuEnter={Add=function() end}, OnRenderTick={Add=function() end}}
UIFont = {Small=1}
function getNumActivePlayers() return 1 end
local player = {name='host', dead=false}
function player:getUsername() return self.name end
function player:isDead() return self.dead end
function getSpecificPlayer() return player end
function isClient() return false end
require 'NL/HouseholdPanel'
local profile = NLDomain.profile(NLDomain.newWorld(), 'host')
NLClient.profiles[0] = profile
NLHouseholdPanel.instances[0] = nil
local panel = NLHouseholdPanel:new(0); panel:initialise(); panel:prerender()
local home = NLHouseholds.new('home:host', 'host', {x=1,y=2,z=0})
NLHouseholdClient.snapshots[0] = {
    username='host', householdRevision=1, message='Ready',
    household=NLHouseholds.copySummary(home, {host=true}),
}
panel:prerender()
for _, button in pairs(panel.taskButtons) do assert(button.enabled, 'home activity enabled for member') end
print('PASS: household panel empty/shared states, member activity controls and client routing load')
