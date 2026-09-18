-- Appearance UI contract. This is a mock/unit test, not actual gameplay.
package.path = arg[1] .. '/42/media/lua/shared/?.lua;' .. arg[1] .. '/42/media/lua/client/?.lua;' .. package.path
package.preload['ISUI/ISPanel'] = function() end
package.preload['ISUI/ISButton'] = function() end
package.preload['NL/SimsButton'] = function()
    NLSimsButton = {}
    function NLSimsButton:new(x,y,w,h,label,target,callback)
        return { title=label, target=target, callback=callback,
            initialise=function() end,
            setEnable=function(self,v) self.enabled=v; self.enable=v end,
            setKind=function(self,v) self.nlKind=v end,
            setActive=function(self,v) self.nlActive=v end }
    end
    return NLSimsButton
end
ISPanel = {}
function ISPanel:derive() local t = {}; t.__index = t; return setmetatable(t, { __index = self }) end
function ISPanel:new(x,y,w,h) return setmetatable({ x=x,y=y,width=w,height=h,children={} }, self) end
function ISPanel:initialise() end
function ISPanel:addChild(c) self.children[#self.children + 1] = c end
function ISPanel:setVisible(v) self.visible = v end
function ISPanel:addToUIManager() self.attached = true end
function ISPanel:removeFromUIManager() self.attached = false end
function ISPanel:bringToTop() end
function ISPanel:setX(v) self.x = v end
function ISPanel:setY(v) self.y = v end
function ISPanel:prerender() end
function ISPanel:drawText() end
ISButton = {}
function ISButton:new(x,y,w,h,label,target,callback)
    return { title=label, target=target, callback=callback,
        initialise=function() end, setEnable=function(self,v) self.enabled=v end }
end
UIFont = { Small = 1 }
function isClient() return true end
function isServer() return false end
function sendClientCommand() end
Events = { OnMainMenuEnter = { Add = function() end }, OnServerCommand = { Add = function() end },
    OnRenderTick = { Add = function() end }, OnDisconnect = { Add = function() end } }
function getSpecificPlayer() return { isDead=function() return false end } end
function getPlayerScreenLeft() return 0 end
function getPlayerScreenTop() return 0 end
function getPlayerScreenWidth() return 1280 end
function getPlayerScreenHeight() return 720 end
NLClient = { profiles = { [0] = { appearance = { preset = 'natural' } } }, requests = {} }
function NLClient.request(_, command, args) NLClient.requests[#NLClient.requests + 1] = { command=command, args=args } end
NLJournal = {}
function NLJournal:derive() local t = {}; t.__index = t; return setmetatable(t, { __index = self }) end
function NLJournal:new(x,y,w,h) return ISPanel.new(self,x,y,w,h) end
function NLJournal:button(x,y,w,text,action,value)
    local button = ISButton:new(x,y,w,28,text,self,self.onButton)
    button.action, button.value = action, value; self:addChild(button); return button
end
require 'NL/Definitions'
require 'NL/Appearance'
require 'NL/AppearancePanel'
NLClient = { profiles = { [0] = { appearance = { preset = 'natural' } } }, requests = {} }
function NLClient.request(_, command, args) NLClient.requests[#NLClient.requests + 1] = { command=command, args=args } end
NLAppearancePanel.open(0)
local panel = NLAppearancePanel.instances[0]
panel:prerender()
assert(panel.presetButtons.bob and panel.presetButtons.bob.enabled, 'appearance panel enables presets for a live player')
panel.presetButtons.bob.callback(panel, panel.presetButtons.bob)
local request = NLClient.requests[#NLClient.requests]
assert(request.command == 'appearance_select' and request.args.preset == 'bob', 'panel sends selected preset')
getSpecificPlayer = function() return { isDead=function() return true end } end
panel:prerender(); assert(not panel.presetButtons.bob.enabled, 'appearance panel disables presets for a dead player')
print('PASS: appearance panel rendering, preset callbacks, reopen and dead-state gating')
