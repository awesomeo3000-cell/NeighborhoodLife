require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Journal"
require "NL/Appearance"

NLAppearancePanel=NLJournal:derive("NLAppearancePanel")
NLAppearancePanel.instances={}

function NLAppearancePanel:new(index)
    local o=NLJournal.new(self,index)
    o.height=440
    return o
end

function NLAppearancePanel:initialise()
    ISPanel.initialise(self)
    self:button(self.width-76,10,60,"Close","close")
    self.presetButtons={}
    for i,id in ipairs(NLDefinitions.appearanceOrder) do
        self.presetButtons[id]=self:button(350,112+(i-1)*50,245,NLDefinitions.appearancePresets[id].name,"select",id)
    end
end

function NLAppearancePanel:onButton(button)
    if button.action=="close" then self:setVisible(false); return end
    if button.action=="select" then NLClient.request(self.playerIndex,"appearance_select",{preset=button.value}) end
end

function NLAppearancePanel:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD / APPEARANCE",16,14,0.93,0.92,0.88,1,UIFont.Small)
    self:drawText("Hair presets use native Build 42 assets.",16,66,0.66,0.67,0.63,1,UIFont.Small)
    local player=getSpecificPlayer(self.playerIndex)
    local alive=player~=nil and not player:isDead()
    local profile=NLClient.profiles[self.playerIndex]
    local current=profile and profile.appearance and profile.appearance.preset or "natural"
    self:drawText("CURRENT",16,116,0.86,0.70,0.38,1,UIFont.Small)
    self:drawText(NLAppearance.label(current),16,140,0.93,0.92,0.88,1,UIFont.Small)
    self:drawText("Choose a preset",350,86,0.66,0.67,0.63,1,UIFont.Small)
    for id,button in pairs(self.presetButtons) do
        button:setEnable(alive)
        button.backgroundColor=id==current and {r=0.31,g=0.27,b=0.16,a=1} or {r=0.12,g=0.13,b=0.14,a=1}
    end
    if not profile then self:drawText("Waiting for saved profile data...",16,184,0.66,0.67,0.63,1,UIFont.Small) end
    self:drawText("Selections are saved to your Neighborhood Life profile.",16,368,0.66,0.67,0.63,1,UIFont.Small)
    self:drawText("Wardrobe handles saved clothing separately.",16,392,0.66,0.67,0.63,1,UIFont.Small)
end

function NLAppearancePanel.open(index)
    local panel=NLAppearancePanel.instances[index]
    if not panel then panel=NLAppearancePanel:new(index); panel:initialise(); NLAppearancePanel.instances[index]=panel end
    panel:removeFromUIManager(); panel:addToUIManager()
    panel:setX(getPlayerScreenLeft(index)+math.max(0,(getPlayerScreenWidth(index)-panel.width)/2))
    panel:setY(getPlayerScreenTop(index)+math.max(0,(getPlayerScreenHeight(index)-panel.height)/2))
    panel:setVisible(true); panel:bringToTop(); NLClient.request(index,"refresh")
end

Events.OnMainMenuEnter.Add(function() for _,panel in pairs(NLAppearancePanel.instances) do panel:removeFromUIManager() end; NLAppearancePanel.instances={} end)
return NLAppearancePanel