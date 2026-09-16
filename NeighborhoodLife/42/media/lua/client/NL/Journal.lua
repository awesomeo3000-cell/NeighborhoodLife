require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Client"
NLJournal = ISPanel:derive("NLJournal")
NLJournal.instances = {}

local C = {
    panel={r=0.055,g=0.060,b=0.065,a=0.97}, border={r=0.30,g=0.30,b=0.28,a=1},
    text={r=0.93,g=0.92,b=0.88,a=1}, muted={r=0.66,g=0.67,b=0.63,a=1},
    accent={r=0.86,g=0.70,b=0.38,a=1}, active={r=0.31,g=0.27,b=0.16,a=1},
    button={r=0.12,g=0.13,b=0.14,a=1}, hover={r=0.22,g=0.23,b=0.22,a=1},
    buttonBorder={r=0.34,g=0.33,b=0.29,a=1}
}

local function setBtnVisible(b,v) if b and b.setVisible then b:setVisible(v) end end

function NLJournal:new(index)
    local o=ISPanel.new(self,330,130,620,540)
    o.playerIndex=index
    o.backgroundColor=C.panel
    o.borderColor=C.border
    o.moveWithMouse=true
    return o
end

function NLJournal:button(x,y,w,text,action,value)
    local button=ISButton:new(x,y,w,28,text,self,self.onButton)
    button.action,button.value=action,value
    button.backgroundColor=C.button
    button.backgroundColorMouseOver=C.hover
    button.borderColor=C.buttonBorder
    button.textColor=C.text
    button:initialise()
    self:addChild(button)
    return button
end

function NLJournal:initialise()
    ISPanel.initialise(self)
    self.currentTab="career"
    self.rewardPage=1
    self:button(self.width-76,10,60,"Close","close")
    self.tabCareer=self:button(245,10,82,"Careers","tab","career")
    self.tabRewards=self:button(335,10,145,"Community Store","tab","rewards")
    self.careerButtons={}
    for i,id in ipairs(NLDefinitions.careerOrder) do
        self.careerButtons[id]=self:button(16+(i-1)*154,54,144,NLDefinitions.careers[id].name,"select",id)
    end
    self.deliverButtons={}
    for i=1,3 do self.deliverButtons[i]=self:button(480,202+(i-1)*50,120,"Deliver","deliver",i) end
    self.promoteButton=self:button(16,410,180,"Check promotion","promote")
    self.refreshButton=self:button(206,410,100,"Refresh","refresh")
    self.workButton=self:button(316,410,150,"Work shift","work")

    self.rewardButtons={}
    for i=1,4 do
        self.rewardButtons[i]=self:button(480,112+(i-1)*66,120,"Buy","buy_reward",i)
        setBtnVisible(self.rewardButtons[i],false)
    end
    self.rewardPrev=self:button(16,410,80,"< Prev","reward_page",-1)
    self.rewardNext=self:button(102,410,80,"Next >","reward_page",1)
    setBtnVisible(self.rewardPrev,false)
    setBtnVisible(self.rewardNext,false)
end

function NLJournal:updateTabVisibility()
    local career=self.currentTab=="career"
    for _,b in pairs(self.careerButtons) do setBtnVisible(b,career) end
    for _,b in ipairs(self.deliverButtons) do setBtnVisible(b,career) end
    setBtnVisible(self.promoteButton,career); setBtnVisible(self.refreshButton,career); setBtnVisible(self.workButton,career)
    for _,b in ipairs(self.rewardButtons) do setBtnVisible(b,not career) end
    setBtnVisible(self.rewardPrev,not career); setBtnVisible(self.rewardNext,not career)
end

function NLJournal:onButton(button)
    if button.action=="close" then self:setVisible(false); return end
    if button.action=="tab" then self.currentTab=button.value; self:updateTabVisibility(); return end
    if button.action=="reward_page" then
        local maxPage=math.max(1,math.ceil(#(NLDefinitions.rewards or {})/4))
        self.rewardPage=math.max(1,math.min(maxPage,self.rewardPage+button.value)); return
    end
    if button.action=="buy_reward" then
        local reward=NLDefinitions.rewards and NLDefinitions.rewards[(self.rewardPage-1)*4+button.value]
        if reward then NLClient.request(self.playerIndex,"purchase",{rewardId=reward.id}) end
        return
    end
    local args={}
    if button.action=="select" then args.career=button.value end
    if button.action=="deliver" then
        local p=NLClient.profiles[self.playerIndex]
        if not p then return end
        local contract=NLDomain.contracts(p)[button.value]
        if not contract then return end
        args.id=contract.id
    end
    NLClient.request(self.playerIndex,button.action,args)
end

function NLJournal:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD JOURNAL",16,14,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
    if self.tabCareer then self.tabCareer.backgroundColor=self.currentTab=="career" and C.active or C.button end
    if self.tabRewards then self.tabRewards.backgroundColor=self.currentTab=="rewards" and C.active or C.button end
    local p=NLClient.profiles[self.playerIndex]
    if not p then
        self:drawText("Waiting for world data. Use Refresh if this persists.",16,104,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        for _,b in ipairs(self.deliverButtons) do b:setEnable(false) end
        return
    end

    if self.currentTab=="rewards" then
        self:drawText("COMMUNITY REWARDS",16,62,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
        self:drawText("Credits: "..tostring(p.credits or 0),16,84,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
        local rewards=NLDefinitions.rewards or {}
        local maxPage=math.max(1,math.ceil(#rewards/4))
        for i=1,4 do
            local reward=rewards[(self.rewardPage-1)*4+i]
            local b=self.rewardButtons[i]
            if reward then
                setBtnVisible(b,true)
                local afford=(p.credits or 0)>=reward.credits
                b:setEnable(afford); b:setTitle(tostring(reward.credits).." credits")
                local y=112+(i-1)*66
                self:drawText(reward.name,16,y,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
                self:drawText(reward.desc,16,y+20,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
                self:drawText("Cost: "..tostring(reward.credits),16,y+40,afford and C.accent.r or 0.72,afford and C.accent.g or 0.35,afford and C.accent.b or 0.30,1,UIFont.Small)
            else setBtnVisible(b,false) end
        end
        self:drawText("Page "..self.rewardPage.." / "..maxPage,205,416,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        self.rewardPrev:setEnable(self.rewardPage>1); self.rewardNext:setEnable(self.rewardPage<maxPage)
        self:drawText(string.sub(p.message or "",1,86),16,474,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
        return
    end

    for id,button in pairs(self.careerButtons) do button.backgroundColor=id==p.career and C.active or C.button end
    local def,progress=NLDefinitions.careers[p.career],p.careers[p.career]
    self:drawText(def.ranks[progress.rank].."  |  Skill "..p.skill.."  |  Career XP "..progress.xp,16,102,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
    self:drawText("Community credits: "..p.credits.."  |  Deliveries: "..progress.delivered,16,126,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    local shift=def.shift
    local worked=p.workedToday==true or (p.worked and p.worked[p.career]==p.day)
    self:drawText("SHIFT  "..(shift and shift.name or "Unavailable")..(worked and "  /  DONE" or "  /  READY"),16,151,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
    self:drawText("SUPPLY REQUESTS",16,180,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
    for i,c in ipairs(NLDomain.contracts(p)) do
        local y=208+(i-1)*50
        local done=p.claimed[c.id]
        self:drawText(c.amount.." x "..c.item..(done and "  /  DONE" or ""),16,y,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
        self.deliverButtons[i]:setEnable(not done)
    end
    self.workButton:setEnable(not worked)
    self:drawText(NLAspirations.label(p),16,352,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
    self:drawText(NLAspirations.homeLabel(p),16,374,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    self:drawText("Deliveries consume matching items from your main inventory.",16,394,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    local nextRank=NLDefinitions.promotions[progress.rank+1]
    local nextText=nextRank and ("Next rank: skill "..nextRank.skill..", "..nextRank.xp.." XP, "..nextRank.variety.." delivery types") or "Top career rank reached"
    self:drawText(nextText,16,452,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    self:drawText(string.sub(p.message or "",1,86),16,478,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
end

function NLJournal.open(index)
    local panel=NLJournal.instances[index]
    if not panel then panel=NLJournal:new(index); panel:initialise(); NLJournal.instances[index]=panel end
    panel:removeFromUIManager(); panel:addToUIManager()
    local left,top=getPlayerScreenLeft(index),getPlayerScreenTop(index)
    panel:setX(left+math.max(12,math.min(330,getPlayerScreenWidth(index)-panel.width-12)))
    panel:setY(top+math.max(12,math.min(90,getPlayerScreenHeight(index)-panel.height-12)))
    panel:setVisible(true); panel:bringToTop(); panel:updateTabVisibility()
    NLClient.request(index,"refresh")
end

Events.OnMainMenuEnter.Add(function()
    for _,panel in pairs(NLJournal.instances) do panel:removeFromUIManager() end
    NLJournal.instances={}
end)
return NLJournal