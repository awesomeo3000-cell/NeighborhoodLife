require "NL/Journal"
require "NL/Wardrobe"
NLWardrobePanel=NLJournal:derive("NLWardrobePanel")
NLWardrobePanel.instances={}

function NLWardrobePanel:initialise()
    ISPanel.initialise(self)
    self:button(self.width-76,10,60,"Close","close")
    self.slots={}
    for i=1,3 do
        local y=122+(i-1)*96
        self.slots[i]={save=self:button(334,y,125,"Save current","save",i),wear=self:button(468,y,132,"Wear outfit","wear",i)}
    end
end

function NLWardrobePanel:onButton(button)
    if button.action=="close" then self:setVisible(false); return end
    local player=getSpecificPlayer(self.playerIndex)
    if not player or player:isDead() then return end
    if button.action=="save" then
        if NLWardrobe.requestSave then NLWardrobe.requestSave(player,button.value) else NLWardrobe.save(player,button.value) end
    elseif button.action=="wear" then NLWardrobe.wear(player,button.value) end
end

function NLWardrobePanel:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD / WARDROBE",16,14,0.93,0.92,0.88,1,UIFont.Small)
    self:drawText("Save up to three outfits from clothing you own.",16,68,0.66,0.67,0.63,1,UIFont.Small)
    local player=getSpecificPlayer(self.playerIndex)
    local alive=player~=nil and not player:isDead()
    local profile=NLClient.profiles[self.playerIndex]
    local outfits=alive and ((profile and profile.outfits) or player:getModData().NeighborhoodOutfits or {}) or {}
    for i=1,3 do
        local y=106+(i-1)*96
        local saved=outfits[i]
        self:drawRect(16,y,296,76,1,0.10,0.11,0.12)
        self:drawText("LOOK "..i,28,y+12,0.86,0.70,0.38,1,UIFont.Small)
        self:drawText(saved and (#saved.." saved pieces") or "Empty",28,y+38,0.93,0.92,0.88,1,UIFont.Small)
        self.slots[i].save:setEnable(alive)
        self.slots[i].wear:setEnable(alive and saved~=nil and #saved>0)
    end
    self:drawText("Wear uses matching clothing from your main inventory.",16,410,0.66,0.67,0.63,1,UIFont.Small)
    self:drawText("Missing pieces are skipped. Other worn layers remain equipped.",16,434,0.66,0.67,0.63,1,UIFont.Small)
end

function NLWardrobePanel.open(index)
    local panel=NLWardrobePanel.instances[index]
    if not panel then panel=NLWardrobePanel:new(index); panel:initialise(); NLWardrobePanel.instances[index]=panel end
    panel:setX(getPlayerScreenLeft(index)+math.max(0,(getPlayerScreenWidth(index)-panel.width)/2))
    panel:setY(getPlayerScreenTop(index)+math.max(0,(getPlayerScreenHeight(index)-panel.height)/2))
    panel:removeFromUIManager(); panel:addToUIManager(); panel:setVisible(true); panel:bringToTop()
end
Events.OnMainMenuEnter.Add(function() for _,panel in pairs(NLWardrobePanel.instances) do panel:removeFromUIManager() end; NLWardrobePanel.instances={} end)
return NLWardrobePanel