require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Client"
NLJournal = ISPanel:derive("NLJournal")
NLJournal.instances = {}

local function setBtnVisible(b, v)
    if b and b.setVisible then b:setVisible(v) end
end

function NLJournal:new(index)
    local o = ISPanel.new(self, 330, 130, 590, 450)
    o.playerIndex = index
    o.backgroundColor = { r=0.96, g=0.98, b=1, a=0.98 }
    o.borderColor = { r=0.62, g=0.76, b=0.88, a=1 }
    o.moveWithMouse = true
    return o
end

function NLJournal:button(x,y,w,text,action,value)
    local button = ISButton:new(x,y,w,28,text,self,self.onButton)
    button.action, button.value = action, value
    button.backgroundColor = {r=0.86,g=0.92,b=0.97,a=1}
    button.backgroundColorMouseOver = {r=0.69,g=0.87,b=0.98,a=1}
    button.borderColor = {r=0.53,g=0.69,b=0.82,a=1}
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
    self.currentTab = "career"
    self.rewardPage = 1
    self:button(self.width-75,10,60,"Close","close")
    self.tabCareer = self:button(215,10,75,"Careers","tab","career")
    self.tabRewards = self:button(298,10,135,"Community Store","tab","rewards")
    self.careerButtons = {}
    for i,id in ipairs(NLDefinitions.careerOrder) do
        self.careerButtons[id] = self:button(16+(i-1)*150,48,140,NLDefinitions.careers[id].name,"select",id)
    end
    self.deliverButtons = {}
    for i=1,3 do self.deliverButtons[i] = self:button(455,162+(i-1)*48,115,"Deliver","deliver",i) end
    self.promoteButton = self:button(16,347,180,"Check promotion","promote")
    self.refreshButton = self:button(210,347,100,"Refresh","refresh")
    self.workButton = self:button(320,347,150,"Work shift","work")

    self.rewardButtons = {}
    for i=1,4 do
        self.rewardButtons[i] = self:button(455,90+(i-1)*58,115,"Buy","buy_reward",i)
        setBtnVisible(self.rewardButtons[i], false)
    end
    self.rewardPrev = self:button(16,347,80,"< Prev","reward_page",-1)
    self.rewardNext = self:button(102,347,80,"Next >","reward_page",1)
    setBtnVisible(self.rewardPrev, false)
    setBtnVisible(self.rewardNext, false)
end

function NLJournal:updateTabVisibility()
    local isCareer = self.currentTab == "career"
    for _, b in pairs(self.careerButtons) do setBtnVisible(b, isCareer) end
    for _, b in ipairs(self.deliverButtons) do setBtnVisible(b, isCareer) end
    if self.promoteButton then setBtnVisible(self.promoteButton, isCareer) end
    if self.workButton then setBtnVisible(self.workButton, isCareer) end
    for _, b in ipairs(self.rewardButtons) do setBtnVisible(b, not isCareer) end
    if self.rewardPrev then setBtnVisible(self.rewardPrev, not isCareer) end
    if self.rewardNext then setBtnVisible(self.rewardNext, not isCareer) end
end

function NLJournal:onButton(button)
    if button.action=="close" then self:setVisible(false); return end
    if button.action=="tab" then
        self.currentTab = button.value
        self:updateTabVisibility()
        return
    end
    if button.action=="reward_page" then
        local maxPage = math.max(1, math.ceil(#(NLDefinitions.rewards or {}) / 4))
        self.rewardPage = math.max(1, math.min(maxPage, self.rewardPage + button.value))
        return
    end
    if button.action=="buy_reward" then
        local idx = (self.rewardPage - 1) * 4 + button.value
        local reward = NLDefinitions.rewards and NLDefinitions.rewards[idx]
        if reward then
            NLClient.request(self.playerIndex, "purchase", { rewardId = reward.id })
        end
        return
    end
    local args = {}
    if button.action=="select" then args.career = button.value end
    if button.action=="deliver" then
        local p = NLClient.profiles[self.playerIndex]
        if not p then return end
        args.id = NLDomain.contracts(p)[button.value].id
    end
    if button.action=="work" then args = {} end
    NLClient.request(self.playerIndex,button.action,args)
end

function NLJournal:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD JOURNAL",16,14,0.12,0.38,0.63,1,UIFont.Small)
    if self.tabCareer then
        self.tabCareer.backgroundColor = self.currentTab=="career" and {r=0.69,g=0.87,b=0.98,a=1} or {r=0.86,g=0.92,b=0.97,a=1}
    end
    if self.tabRewards then
        self.tabRewards.backgroundColor = self.currentTab=="rewards" and {r=0.69,g=0.87,b=0.98,a=1} or {r=0.86,g=0.92,b=0.97,a=1}
    end
    local p = NLClient.profiles[self.playerIndex]
    if not p then
        self:drawText("Waiting for world data. Try Refresh.",16,95,0.18,0.24,0.32,1,UIFont.Small)
        for _,b in ipairs(self.deliverButtons) do b:setEnable(false) end
        return
    end

    if self.currentTab == "rewards" then
        self:drawText("COMMUNITY REWARDS CATALOG",16,52,0.12,0.38,0.63,1,UIFont.Small)
        self:drawText("Your Community Credits: " .. tostring(p.credits or 0),16,68,0.18,0.48,0.18,1,UIFont.Small)
        local rewards = NLDefinitions.rewards or {}
        local maxPage = math.max(1, math.ceil(#rewards / 4))
        for i = 1, 4 do
            local idx = (self.rewardPage - 1) * 4 + i
            local reward = rewards[idx]
            local b = self.rewardButtons[i]
            if reward then
                setBtnVisible(b, true)
                local canAfford = (p.credits or 0) >= reward.credits
                b:setEnable(canAfford)
                b:setTitle(tostring(reward.credits) .. " Credits")
                local y = 92 + (i - 1) * 58
                self:drawText(reward.name, 16, y, 0.12, 0.30, 0.47, 1, UIFont.Small)
                self:drawText(reward.desc, 16, y + 16, 0.38, 0.44, 0.52, 1, UIFont.Small)
                self:drawText("Cost: " .. tostring(reward.credits) .. " credits", 16, y + 32, canAfford and 0.18 or 0.65, canAfford and 0.48 or 0.18, 0.18, 1, UIFont.Small)
            else
                setBtnVisible(b, false)
            end
        end
        self:drawText("Page " .. tostring(self.rewardPage) .. " / " .. tostring(maxPage), 390, 352, 0.30, 0.38, 0.47, 1, UIFont.Small)
        if self.rewardPrev then self.rewardPrev:setEnable(self.rewardPage > 1) end
        if self.rewardNext then self.rewardNext:setEnable(self.rewardPage < maxPage) end
        local message = p.message or ""
        self:drawText(string.sub(message,1,72),16,415,0.12,0.38,0.63,1,UIFont.Small)
        if #message>72 then self:drawText(string.sub(message,73,144),16,434,0.12,0.38,0.63,1,UIFont.Small) end
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
    local shift = NLDefinitions.careers[p.career].shift
    local worked = p.workedToday == true or (p.worked and p.worked[p.career] == p.day)
    self:drawText("SHIFT: " .. (shift and shift.name or "Unavailable")
        .. (worked and " / DONE" or " / READY"), 16,135,0.12,0.38,0.63,1,UIFont.Small)
    self:drawText("SUPPLY REQUESTS / refresh each world day",16,142,0.12,0.38,0.63,1,UIFont.Small)
    for i,c in ipairs(NLDomain.contracts(p)) do
        local y = 170+(i-1)*48
        local done = p.claimed[c.id]
        self:drawText(c.amount .. " x " .. c.item .. (done and " / DONE" or ""),16,y,0.18,0.24,0.32,1,UIFont.Small)
        self.deliverButtons[i]:setEnable(not done)
    end
    if self.workButton then self.workButton:setEnable(not worked) end
    self:drawText(NLAspirations.label(p),16,284,0.12,0.38,0.63,1,UIFont.Small)
    self:drawText(NLAspirations.homeLabel(p),16,303,0.12,0.38,0.63,1,UIFont.Small)
    self:drawText("Delivery consumes items in your main inventory.",16,322,0.46,0.32,0.12,1,UIFont.Small)
    local nextRank = NLDefinitions.promotions[progress.rank+1]
    local text = nextRank and ("Next: skill "..nextRank.skill..", "..nextRank.xp.." XP, "..nextRank.variety.." delivery types") or "Top career rank reached"
    self:drawText(text,16,389,0.30,0.38,0.47,1,UIFont.Small)
    local message = p.message or ""
    self:drawText(string.sub(message,1,72),16,415,0.12,0.38,0.63,1,UIFont.Small)
    if #message>72 then self:drawText(string.sub(message,73,144),16,434,0.12,0.38,0.63,1,UIFont.Small) end
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
