require "NL/Journal"
require "NL/SocialClient"
NLRelationships=NLJournal:derive("NLRelationships")
NLRelationships.instances={}

function NLRelationships:new(index)
    local o=NLJournal.new(self,index)
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
    local labels={{"Introduce","introduce"},{"Chat","chat"},{"Joke","joke"},
        {"Flirt","flirt"},{"Ask on a date","date"},{"Become partners","partner"},{"Break up","breakup"}}
    for i,v in ipairs(labels) do
        local col=(i-1)%3; local row=math.floor((i-1)/3)
        self.actions[i]=self:button(16+col*186,250+row*35,176,v[1],v[2])
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
    if npc then NLSocialClient.request(self.playerIndex,"interact",{id=npc.id,action=button.action}) end
end
function NLRelationships:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD / RELATIONSHIPS",16,14,0.12,0.38,0.63,1,UIFont.Small)
    local data=NLSocialClient.snapshots[self.playerIndex]
    local npc=data and data.neighbors[self.selected]
    local nearby=npc and npc.available and not npc.dead and npc.canInteract==true
    for _,b in ipairs(self.actions) do b:setEnable(nearby==true) end
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
    local location=npc.dead and "Deceased" or npc.available and ("Distance: "..math.floor(npc.distance or 0).." tiles") or "Away"
    self:drawText(location.." | Conversations require proximity and line of sight.",16,231,0.30,0.38,0.47,1,UIFont.Small)
    self:drawText(string.sub(data.message or "",1,78),16,367,0.12,0.38,0.63,1,UIFont.Small)
    local memories=npc.relation.memories
    local latest=memories[#memories]
    if latest then self:drawText("Memory: "..string.sub(latest.text,1,70),16,396,0.30,0.38,0.47,1,UIFont.Small) end
    local event=NLSocialClient.lastEvent
    if event then
        self:drawText("Shared event: "..tostring(event.actor).." "
            ..tostring(event.action).." with "..tostring(event.npcName),16,423,
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
