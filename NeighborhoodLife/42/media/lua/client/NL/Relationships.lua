require "NL/Journal"
require "NL/SocialClient"
NLRelationships=NLJournal:derive("NLRelationships")
NLRelationships.instances={}

local function displayName(item,itemType)
    if item and item.getDisplayName then
        local ok,label=pcall(item.getDisplayName,item)
        if ok and type(label)=="string" and label~="" then return label end
    end
    return itemType
end

local function playerGiveChoice(index)
    local player=getSpecificPlayer(index)
    local inventory=player and player.getInventory and player:getInventory()
    local items=inventory and inventory.getItems and inventory:getItems()
    if not items then return nil end
    local choices={}
    for i=0,items:size()-1 do
        local item=items:get(i)
        local fullType=item and item.getFullType and item:getFullType()
        local equipped=false
        if item and player.isEquipped then
            local ok,value=pcall(player.isEquipped,player,item)
            equipped=ok and value==true
        end
        if fullType and not equipped and not choices[fullType] then
            choices[fullType]={item=fullType,label=displayName(item,fullType)}
        end
    end
    local result={}
    for _,choice in pairs(choices) do result[#result+1]=choice end
    table.sort(result,function(a,b) return a.item<b.item end)
    return result[1]
end

local function setButtonText(button,text)
    if button.setTitle then pcall(button.setTitle,button,text) end
    button.title=text
end

function NLRelationships:new(index)
    local o=NLJournal.new(self,index)
    o.height=525
    o.selected=1
    return o
end
function NLRelationships:initialise()
    ISPanel.initialise(self)
    self:button(self.width-75,10,60,"Close","close")
    self:button(16,48,85,"Previous","previous")
    self:button(112,48,85,"Next","next")
    self:button(209,48,95,"Refresh","refresh")
    self.actions={}
    self.actionButtons={}
    local labels={{"Introduce","introduce"},{"Chat","chat"},{"Joke","joke"},
        {"Flirt","flirt"},{"Ask on a date","date"},{"Spend time together","date_activity"},
        {"Become partners","partner"},{"Break up","breakup"},
        {"Give item","give"},{"Request item","request"},
        {"Ask about work","ask_work"},{"Talk about home","talk_home"},
        {"Compliment","compliment"},{"Apologize","apologize"}}
    for i,v in ipairs(labels) do
        local col=(i-1)%3; local row=math.floor((i-1)/3)
        self.actions[i]=self:button(16+col*186,250+row*32,176,v[1],v[2],v[3])
        self.actionButtons[v[2]]=self.actions[i]
    end
end
function NLRelationships:onButton(button)
    if button.action=="close" then self:setVisible(false); return end
    local data=NLSocialClient.snapshots[self.playerIndex]
    local count=data and #data.neighbors or 0
    if button.action=="next" then self.selected=math.min(count,self.selected+1); return end
    if button.action=="previous" then self.selected=math.max(1,self.selected-1); return end
    if button.action=="refresh" then NLSocialClient.request(self.playerIndex,"refresh"); return end
    local npc=data and data.neighbors[self.selected]
    if npc then
        if button.action=="give" or button.action=="request" then
            local args={id=npc.id,item=button.value and button.value.item or "Base.RippedSheets",
                amount=button.value and button.value.amount or 1}
            NLSocialClient.request(self.playerIndex,button.action,args)
        else
            NLSocialClient.request(self.playerIndex,"interact",{id=npc.id,action=button.action})
        end
    end
end
function NLRelationships:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD / RELATIONSHIPS",16,14,0.12,0.38,0.63,1,UIFont.Small)
    local data=NLSocialClient.snapshots[self.playerIndex]
    local npc=data and data.neighbors[self.selected]
    local nearby=npc and npc.available and not npc.dead and npc.canInteract==true
    for _,b in ipairs(self.actions) do b:setEnable(nearby==true) end
    if self.actionButtons.partner then
        self.actionButtons.partner:setEnable(nearby==true and (npc.exclusive~=true or npc.isPartner==true))
    end
    if self.actionButtons.breakup then
        self.actionButtons.breakup:setEnable(nearby==true and npc.isPartner==true)
    end
    if self.actionButtons.apologize then
        self.actionButtons.apologize:setEnable(nearby==true and npc.relation and (tonumber(npc.relation.friendship or 0) or 0)<0)
    end
    if self.actionButtons.compliment then
        self.actionButtons.compliment:setEnable(nearby==true and npc.relation and (tonumber(npc.relation.friendship or 0) or 0)>=20)
    end
    if self.actionButtons.date_activity then
        local activeDate=npc and npc.relation and npc.relation.activeDate
        self.actionButtons.date_activity:setEnable(nearby==true and activeDate
            and activeDate.status=="active")
    end
    if not npc then
        self.selected=1
        self:drawText("No neighbors registered in this world yet.",16,98,0.18,0.24,0.32,1,UIFont.Small)
        self:drawText("NPC world integration is still in development.",16,124,0.30,0.38,0.47,1,UIFont.Small)
        return
    end
    self:drawText(npc.name.." / "..npc.age.." / "..npc.relation.status,16,92,0.12,0.38,0.63,1,UIFont.Small)
    self:drawText(npc.personality,16,117,0.30,0.38,0.47,1,UIFont.Small)
    local rows={{"Friendship",(npc.relation.friendship+100)/200,npc.relation.friendship},
        {"Trust",npc.relation.trust/100,npc.relation.trust},
        {"Attraction",npc.relation.attraction/100,npc.relation.attraction}}
    for i,v in ipairs(rows) do
        local y=145+(i-1)*29
        self:drawText(v[1],16,y,0.18,0.24,0.32,1,UIFont.Small)
        self:drawRect(115,y+4,380,10,1,0.82,0.87,0.90)
        local pink=i==3
        self:drawRect(115,y+4,380*v[2],10,1,pink and 0.91 or 0.42,pink and 0.38 or 0.78,pink and 0.65 or 0.19)
        self:drawText(tostring(v[3]),512,y,0.18,0.24,0.32,1,UIFont.Small)
    end
    local relationshipLocation=npc.exclusive and (npc.isPartner and "Your partner" or "In a partnership") or nil
    local location=npc.dead and "Deceased" or npc.available and ("Distance: "..math.floor(npc.distance or 0).." tiles") or "Away"
    if relationshipLocation then location=location.." | "..relationshipLocation end
    self:drawText(location.." | Conversations require proximity and line of sight.",16,231,0.30,0.38,0.47,1,UIFont.Small)
    local date=npc.relation.activeDate
    local dateText=date and date.status=="active" and "Date in progress: choose Spend time together"
        or date and date.status=="completed" and ("Last date complete | total completed: "
            ..tostring(npc.relation.completedDates or 0))
        or "No date in progress"
    self:drawText(dateText,16,248,0.12,0.38,0.63,1,UIFont.Small)
    local giveChoice=playerGiveChoice(self.playerIndex)
    local requestChoice=(npc.inventoryItems and npc.inventoryItems[1])
    if not requestChoice then
        for item,amount in pairs(npc.inventory or {}) do
            requestChoice={item=item,amount=amount,label=item}; break
        end
    end
    local giveButton=self.actionButtons.give
    local requestButton=self.actionButtons.request
    giveButton.value=giveChoice and {item=giveChoice.item,amount=1} or nil
    requestButton.value=requestChoice and {item=requestChoice.item,amount=1} or nil
    local isFav=giveChoice and NLSocial and NLSocial.isFavorite and NLSocial.isFavorite(npc.id, giveChoice.item)
    setButtonText(giveButton,giveChoice and ("Give 1 "..giveChoice.label..(isFav and " (Fav!)" or "")) or "Give item")
    setButtonText(requestButton,requestChoice and ("Request 1 "..(requestChoice.label or requestChoice.item)) or "Request item")
    giveButton:setEnable(nearby and giveChoice~=nil)
    requestButton:setEnable(nearby and requestChoice~=nil)
    local inventoryParts={}
    for _,entry in ipairs(npc.inventoryItems or {}) do
        inventoryParts[#inventoryParts+1]=tostring(entry.amount).." x "..tostring(entry.label or entry.item)
        if #inventoryParts==2 then break end
    end
    local inventoryText=#inventoryParts>0 and ("NPC inventory: "..table.concat(inventoryParts,", ")) or "NPC inventory: empty"
    self:drawText(inventoryText,16,415,0.30,0.38,0.47,1,UIFont.Small)
    self:drawText(string.sub(data.message or "",1,78),16,438,0.12,0.38,0.63,1,UIFont.Small)
    local memories=npc.relation.memories
    local latest=memories[#memories]
    if latest then self:drawText("Memory: "..string.sub(latest.text,1,70),16,460,0.30,0.38,0.47,1,UIFont.Small) end
    local event=NLSocialClient.lastEvent
    if event then
        self:drawText("Shared event: "..tostring(event.actor).." "
            ..tostring(event.action).." with "..tostring(event.npcName),16,482,
            0.30,0.38,0.47,1,UIFont.Small)
    end
end
function NLRelationships.open(index)
    local panel=NLRelationships.instances[index]
    if not panel then panel=NLRelationships:new(index); panel:initialise(); NLRelationships.instances[index]=panel end
    panel:removeFromUIManager(); panel:addToUIManager(); panel:setVisible(true); panel:bringToTop()
    NLSocialClient.request(index,"refresh")
end
Events.OnMainMenuEnter.Add(function()
    for _,p in pairs(NLRelationships.instances) do p:removeFromUIManager() end
    NLRelationships.instances={}
end)
return NLRelationships
