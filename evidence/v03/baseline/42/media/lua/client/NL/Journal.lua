require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Client"
NLJournal = ISPanel:derive("NLJournal")
NLJournal.instances = {}

function NLJournal:new(index)
    local o = ISPanel.new(self, 330, 130, 590, 450)
    o.playerIndex = index
    o.backgroundColor = { r=0.96, g=0.98, b=1, a=0.98 }
    o.borderColor = { r=0.62, g=0.76, b=0.88, a=1 }
    o.moveWithMouse = true
    return o
end

function NLJournal:button(x,y,w,text,action,value)
    local button = ISButton:new(x,y,w,28,text,self,NLJournal.onButton)
    button.action, button.value = action, value
    button.backgroundColor = {r=0.86,g=0.92,b=0.97,a=1}
    button.backgroundColorMouseOver = {r=0.69,g=0.87,b=0.98,a=1}
    button.borderColor = {r=0.53,g=0.69,b=0.82,a=1}
    button.textColor = {r=0.12,g=0.30,b=0.47,a=1}
    button:initialise()
    self:addChild(button)
    return button
end

function NLJournal:initialise()
    ISPanel.initialise(self)
    self:button(self.width-75,10,60,"Close","close")
    self.careerButtons = {}
    for i,id in ipairs(NLDefinitions.careerOrder) do
        self.careerButtons[id] = self:button(16+(i-1)*150,48,140,NLDefinitions.careers[id].name,"select",id)
    end
    self.deliverButtons = {}
    for i=1,3 do self.deliverButtons[i] = self:button(455,162+(i-1)*48,115,"Deliver","deliver",i) end
    self:button(16,325,180,"Check promotion","promote")
    self:button(210,325,100,"Refresh","refresh")
end

function NLJournal:onButton(button)
    if button.action=="close" then self:setVisible(false); return end
    local args = {}
    if button.action=="select" then args.career = button.value end
    if button.action=="deliver" then
        local p = NLClient.profiles[self.playerIndex]
        if not p then return end
        args.id = NLDomain.contracts(p)[button.value].id
    end
    NLClient.request(self.playerIndex,button.action,args)
end

function NLJournal:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD / CAREER JOURNAL",16,14,0.12,0.38,0.63,1,UIFont.Small)
    local p = NLClient.profiles[self.playerIndex]
    if not p then
        self:drawText("Waiting for world data. Try Refresh.",16,95,0.18,0.24,0.32,1,UIFont.Small)
        for _,b in ipairs(self.deliverButtons) do b:setEnable(false) end
        return
    end
    for id,button in pairs(self.careerButtons) do
        button.backgroundColor = id==p.career and {r=0.65,g=0.88,b=0.36,a=1}
            or {r=0.86,g=0.92,b=0.97,a=1}
    end
    local def,progress = NLDefinitions.careers[p.career],p.careers[p.career]
    self:drawText(def.ranks[progress.rank] .. " | Skill " .. p.skill .. " | Career XP " .. progress.xp,
        16,90,0.18,0.24,0.32,1,UIFont.Small)
    self:drawText("Community credits: " .. p.credits .. " | Deliveries: " .. progress.delivered,
        16,115,0.30,0.38,0.47,1,UIFont.Small)
    self:drawText("SUPPLY REQUESTS / refresh each world day",16,142,0.12,0.38,0.63,1,UIFont.Small)
    for i,c in ipairs(NLDomain.contracts(p)) do
        local y = 170+(i-1)*48
        local done = p.claimed[c.id]
        self:drawText(c.amount .. " x " .. c.item .. (done and " / DONE" or ""),16,y,0.18,0.24,0.32,1,UIFont.Small)
        self.deliverButtons[i]:setEnable(not done)
    end
    self:drawText("Delivery consumes items in your main inventory.",16,303,0.46,0.32,0.12,1,UIFont.Small)
    local nextRank = NLDefinitions.promotions[progress.rank+1]
    local text = nextRank and ("Next: skill "..nextRank.skill..", "..nextRank.xp.." XP, "..nextRank.variety.." delivery types") or "Top career rank reached"
    self:drawText(text,16,366,0.30,0.38,0.47,1,UIFont.Small)
    -- Wrap status rather than drawing arbitrarily long server feedback off-panel.
    local message = p.message or ""
    self:drawText(string.sub(message,1,72),16,392,0.12,0.38,0.63,1,UIFont.Small)
    if #message>72 then self:drawText(string.sub(message,73,144),16,411,0.12,0.38,0.63,1,UIFont.Small) end
end

function NLJournal.open(index)
    local panel = NLJournal.instances[index]
    if not panel then
        panel = NLJournal:new(index); panel:initialise()
        NLJournal.instances[index] = panel
    end
    -- The engine can clear UIManager at a world transition without clearing Lua.
    -- Reattach on every open, removing first so repeated opens never duplicate it.
    panel:removeFromUIManager(); panel:addToUIManager()
    local left,top = getPlayerScreenLeft(index),getPlayerScreenTop(index)
    panel:setX(left + math.max(12, math.min(330,getPlayerScreenWidth(index)-panel.width-12)))
    panel:setY(top + math.max(12, math.min(130,getPlayerScreenHeight(index)-panel.height-12)))
    panel:setVisible(true); panel:bringToTop()
    NLClient.request(index,"refresh")
end

Events.OnMainMenuEnter.Add(function()
    for _,panel in pairs(NLJournal.instances) do panel:removeFromUIManager() end
    NLJournal.instances = {}
end)
return NLJournal
