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
Events={OnCreatePlayer={Add=function() end},OnMainMenuEnter={Add=function() end}}
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
panel:prerender(); assert(panel.visible and panel.x==80 and panel.y==116)
character.isDead=function() return true end; panel:prerender(); assert(not panel.visible)
NLPlumbob.unregister('test:character'); assert(NLPlumbob.instances['test:character']==nil)
print('PASS: plumbob asset lookup, screen anchoring, dead-character hide, registration and cleanup')
