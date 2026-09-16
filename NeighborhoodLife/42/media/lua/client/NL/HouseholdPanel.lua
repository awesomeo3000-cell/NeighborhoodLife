require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Client"
require "NL/HouseholdClient"

NLHouseholdPanel=ISPanel:derive("NLHouseholdPanel")
NLHouseholdPanel.instances={}

local C={
    panel={r=0.055,g=0.060,b=0.065,a=0.97}, border={r=0.30,g=0.30,b=0.28,a=1},
    text={r=0.93,g=0.92,b=0.88,a=1}, muted={r=0.66,g=0.67,b=0.63,a=1}, accent={r=0.86,g=0.70,b=0.38,a=1},
    button={r=0.12,g=0.13,b=0.14,a=1}, hover={r=0.22,g=0.23,b=0.22,a=1}, buttonBorder={r=0.34,g=0.33,b=0.29,a=1}
}

function NLHouseholdPanel:new(index)
    local o=ISPanel.new(self,330,90,620,590)
    o.playerIndex=index; o.backgroundColor=C.panel; o.borderColor=C.border; o.moveWithMouse=true
    return o
end

function NLHouseholdPanel:button(x,y,w,text,action,value)
    local button=ISButton:new(x,y,w,28,text,self,self.onButton)
    button.action,button.value=action,value; button.backgroundColor=C.button; button.backgroundColorMouseOver=C.hover
    button.borderColor=C.buttonBorder; button.textColor=C.text; button:initialise(); self:addChild(button); return button
end

function NLHouseholdPanel:initialise()
    ISPanel.initialise(self)
    self:button(self.width-76,10,60,"Close","close")
    self:button(16,50,120,"Create home","create")
    self:button(144,50,110,"Accept invite","accept")
    self:button(262,50,110,"Invite guest","invite")
    self:button(380,50,90,"Leave","leave")
    self:button(478,50,100,"Refresh","refresh")
    self.transferButton=self:button(16,86,150,"Transfer owner","transfer")
    self.storageButtons={
        store=self:button(16,420,184,"Store 1 RippedSheet","store",{item="Base.RippedSheets",amount=1}),
        retrieve=self:button(208,420,184,"Take 1 RippedSheet","retrieve",{item="Base.RippedSheets",amount=1}),
    }
    self.taskButtons={}
    for i,task in ipairs(NLHouseholds.taskOrder) do
        local col=(i-1)%3; local row=math.floor((i-1)/3)
        self.taskButtons[task]=self:button(16+col*196,462+row*34,186,NLHouseholds.tasks[task].label,"task",task)
    end
end

function NLHouseholdPanel:inviteTarget()
    local selfPlayer=getSpecificPlayer(self.playerIndex); local selfName=selfPlayer and selfPlayer:getUsername(); local presence=NLClient.presence
    for _,row in ipairs((presence and presence.players) or {}) do if row.username and row.username~=selfName then return row.username end end
end

function NLHouseholdPanel:transferTarget()
    local selfPlayer=getSpecificPlayer(self.playerIndex); local selfName=selfPlayer and selfPlayer:getUsername()
    local state=NLHouseholdClient.snapshots[self.playerIndex]; local household=state and state.household
    if not household or household.owner~=selfName then return nil end
    for _,row in ipairs(household.members or {}) do if row.username and row.username~=selfName then return row.username end end
end

function NLHouseholdPanel:onButton(button)
    if button.action=="close" then self:setVisible(false); return end
    if button.action=="invite" then local target=self:inviteTarget(); if target then NLHouseholdClient.request(self.playerIndex,"invite",{target=target}) end; return end
    if button.action=="transfer" then local target=self:transferTarget(); if target then NLHouseholdClient.request(self.playerIndex,"transfer",{target=target}) end; return end
    local args={}
    if button.action=="task" then args={task=button.value}
    elseif button.action=="store" or button.action=="retrieve" then args=button.value end
    NLHouseholdClient.request(self.playerIndex,button.action,args)
end

function NLHouseholdPanel:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD / HOUSEHOLD",16,14,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
    self:drawText("Shared home, storage and routines",180,92,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    local state=NLHouseholdClient.snapshots[self.playerIndex]
    if not state then self:drawText("Waiting for household data. Use Refresh if this persists.",16,132,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small); return end
    local p=NLClient.profiles[self.playerIndex]; local invite=state.invite
    if invite then
        self:drawText("INVITATION",16,132,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
        self:drawText(tostring(invite.name or invite.householdId).." from "..tostring(invite.from),16,156,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
    elseif state.household then
        local h=state.household
        self:drawText(h.name.."  /  owner: "..tostring(h.owner),16,132,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
        self:drawText("Home tile "..tostring(h.home.x)..", "..tostring(h.home.y)..", "..tostring(h.home.z),16,156,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        local y=186
        for _,member in ipairs(h.members or {}) do
            self:drawText((member.online and "ONLINE  " or "OFFLINE  ")..member.username.."  /  "..member.role.."  /  "..tostring(member.contribution).." routines",16,y,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
            y=y+23; if y>260 then break end
        end
        if state.homeAspirationLabel then self:drawText("Home aspiration: "..tostring(state.homeAspirationLabel),16,282,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small) end
        local actParts={}
        for _,taskKey in ipairs(NLHouseholds.taskOrder) do actParts[#actParts+1]=taskKey.." "..tostring(h.tasks and h.tasks[taskKey] or 0) end
        self:drawText("Activities: "..table.concat(actParts," | "),16,308,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
        local stored={}; for itemType,amount in pairs(h.storage or {}) do stored[#stored+1]=itemType.." x"..tostring(amount) end; table.sort(stored)
        self:drawText("Shared storage: "..(#stored>0 and table.concat(stored,", ") or "empty"),16,336,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
        local detailLabels={}
        for _,detail in ipairs(h.storageDetails or {}) do
            local label=tostring(detail.item); if detail.name then label=label.." / "..tostring(detail.name) end
            if detail.condition~=nil then label=label.." condition "..tostring(detail.condition) end
            detailLabels[#detailLabels+1]=label; if #detailLabels==2 then break end
        end
        if #detailLabels>0 then self:drawText("Saved metadata: "..table.concat(detailLabels,", "),16,362,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small) end
    else
        self:drawText("No household yet.",16,132,C.text.r,C.text.g,C.text.b,1,UIFont.Small)
        self:drawText("Create a home or accept an invitation to start shared progression.",16,156,C.muted.r,C.muted.g,C.muted.b,1,UIFont.Small)
    end
    self:drawText("SHARED STORAGE",16,397,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
    self:drawText("HOME ROUTINES",16,444,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
    for _,button in pairs(self.taskButtons) do button:setEnable(state.household~=nil and p~=nil) end
    for _,button in pairs(self.storageButtons) do button:setEnable(state.household~=nil and p~=nil) end
    if self.transferButton then self.transferButton:setEnable(self:transferTarget()~=nil) end
    self:drawText(string.sub(state.message or "",1,90),16,555,C.accent.r,C.accent.g,C.accent.b,1,UIFont.Small)
end

function NLHouseholdPanel.open(index)
    local panel=NLHouseholdPanel.instances[index]
    if not panel then panel=NLHouseholdPanel:new(index); panel:initialise(); NLHouseholdPanel.instances[index]=panel end
    panel:setX(getPlayerScreenLeft(index)+math.max(0,(getPlayerScreenWidth(index)-panel.width)/2))
    panel:setY(getPlayerScreenTop(index)+math.max(0,(getPlayerScreenHeight(index)-panel.height)/2))
    panel:removeFromUIManager(); panel:addToUIManager(); panel:setVisible(true); panel:bringToTop(); NLHouseholdClient.request(index,"refresh")
end
Events.OnMainMenuEnter.Add(function() for _,panel in pairs(NLHouseholdPanel.instances) do panel:removeFromUIManager() end; NLHouseholdPanel.instances={} end)
return NLHouseholdPanel