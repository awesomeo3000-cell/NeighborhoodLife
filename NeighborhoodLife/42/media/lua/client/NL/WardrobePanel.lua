require "NL/Journal"
require "NL/Wardrobe"
NLWardrobePanel=NLJournal:derive("NLWardrobePanel")
NLWardrobePanel.instances={}

function NLWardrobePanel:initialise()
    ISPanel.initialise(self)
    self:button(self.width-75,10,60,"Close","close")
    self.slots={}
    for i=1,3 do
        local y=110+(i-1)*90
        self.slots[i]={save=self:button(320,y,115,"Save current","save",i),
            wear=self:button(445,y,125,"Wear outfit","wear",i)}
    end
end
function NLWardrobePanel:onButton(button)
    if button.action=="close" then self:setVisible(false); return end
    local player=getSpecificPlayer(self.playerIndex)
    if not player or player:isDead() then return end
    if button.action=="save" then
        if NLWardrobe.requestSave then NLWardrobe.requestSave(player,button.value)
        else NLWardrobe.save(player,button.value) end
    elseif button.action=="wear" then NLWardrobe.wear(player,button.value) end
end
function NLWardrobePanel:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD / WARDROBE",16,14,0.12,0.38,0.63,1,UIFont.Small)
    self:drawText("Your looks / save three outfits from clothes you own",16,60,0.18,0.24,0.32,1,UIFont.Small)
    local player=getSpecificPlayer(self.playerIndex)
    local alive=player~=nil and not player:isDead()
    local profile=NLClient.profiles[self.playerIndex]
    local outfits=alive and ((profile and profile.outfits) or player:getModData().NeighborhoodOutfits or {}) or {}
    for i=1,3 do
        local y=95+(i-1)*90
        local saved=outfits[i]
        self:drawRect(16,y,285,72,1,0.88,0.94,0.98)
        self:drawText("LOOK "..i,28,y+10,0.12,0.38,0.63,1,UIFont.Small)
        self:drawText(saved and (#saved.." saved pieces") or "Empty / save your current clothes",28,y+36,0.18,0.24,0.32,1,UIFont.Small)
        self.slots[i].save:setEnable(alive)
        self.slots[i].wear:setEnable(alive and saved~=nil and #saved>0)
    end
    self:drawText("Wear uses clothing in your main inventory and normal equip actions.",16,382,0.30,0.38,0.47,1,UIFont.Small)
    self:drawText("Missing pieces are skipped. Other worn layers stay on.",16,405,0.30,0.38,0.47,1,UIFont.Small)
end
function NLWardrobePanel.open(index)
    local panel=NLWardrobePanel.instances[index]
    if not panel then panel=NLWardrobePanel:new(index); panel:initialise(); NLWardrobePanel.instances[index]=panel end
    panel:setX(getPlayerScreenLeft(index)+math.max(0,(getPlayerScreenWidth(index)-panel.width)/2))
    panel:setY(getPlayerScreenTop(index)+math.max(0,(getPlayerScreenHeight(index)-panel.height)/2))
    panel:removeFromUIManager(); panel:addToUIManager(); panel:setVisible(true); panel:bringToTop()
end
Events.OnMainMenuEnter.Add(function()
    for _,panel in pairs(NLWardrobePanel.instances) do panel:removeFromUIManager() end
    NLWardrobePanel.instances={}
end)
return NLWardrobePanel
