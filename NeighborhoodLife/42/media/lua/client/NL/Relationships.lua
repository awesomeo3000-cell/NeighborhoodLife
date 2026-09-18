require "NL/Journal"
require "NL/SocialClient"
require "NL/UITheme"

NLRelationships = NLJournal:derive("NLRelationships")
NLRelationships.instances = {}

local C = NLUI.colors

local function displayName(item, itemType)
    if item and item.getDisplayName then
        local ok, label = pcall(item.getDisplayName, item)
        if ok and type(label) == "string" and label ~= "" then return label end
    end
    return itemType
end

local function playerGiveChoice(index)
    local player = getSpecificPlayer(index)
    local inventory = player and player.getInventory and player:getInventory()
    local items = inventory and inventory.getItems and inventory:getItems()
    if not items then return nil end
    local choices = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and item:getFullType()
        local equipped = false
        if item and player.isEquipped then
            local ok, value = pcall(player.isEquipped, player, item)
            equipped = ok and value == true
        end
        if fullType and not equipped and not choices[fullType] then
            choices[fullType] = { item=fullType, label=displayName(item, fullType) }
        end
    end
    local result = {}
    for _, choice in pairs(choices) do result[#result + 1] = choice end
    table.sort(result, function(a, b) return a.item < b.item end)
    return result[1]
end

local function setButtonText(button, text)
    if button.setTitle then pcall(button.setTitle, button, text) end
    button.title = text
end

function NLRelationships:new(index)
    local o = NLJournal.new(self, index)
    o.height = 640
    o.selected = 1
    return o
end

function NLRelationships:initialise()
    ISPanel.initialise(self)
    self:button(self.width - 44, 9, 30, "✕", "close", nil, "close")
    self:button(18, 58, 94, "< Previous", "previous")
    self:button(120, 58, 82, "Next >", "next")
    self:button(210, 58, 94, "Refresh", "refresh")

    self.filterTab = "all"
    self.filterAll = self:button(424, 58, 64, "All", "filter", "all", "tab")
    self.filterFriendly = self:button(492, 58, 82, "Friendly", "filter", "friendly", "tab")
    self.filterRomance = self:button(578, 58, 82, "Romance", "filter", "romance", "tab")

    self.actions = {}
    self.actionButtons = {}
    local labels = {
        {"Introduce","introduce","friendly"},{"Chat","chat","friendly"},{"Joke","joke","friendly"},
        {"Flirt","flirt","romance"},{"Ask on a date","date","romance"},{"Spend time together","date_activity","romance"},
        {"Become partners","partner","romance"},{"Break up","breakup","romance"},{"Give item","give","friendly"},{"Request item","request","friendly"},
        {"Ask about work","ask_work","friendly"},{"Talk about home","talk_home","friendly"},{"Compliment","compliment","friendly"},{"Apologize","apologize","friendly"}
    }

    for i, value in ipairs(labels) do
        local kind = value[3] == "romance" and "romance" or "friendly"
        self.actions[i] = self:button(18, 394, 206, value[1], value[2], nil, kind)
        self.actions[i].nlCategory = value[3]
        self.actionButtons[value[2]] = self.actions[i]
    end
    self:layoutActions()
end

function NLRelationships:layoutActions()
    local visibleIdx = 0
    for _, btn in ipairs(self.actions) do
        local matches = (self.filterTab == "all") or (btn.nlCategory == self.filterTab)
        btn:setVisible(matches)
        if matches then
            local col = visibleIdx % 3
            local row = math.floor(visibleIdx / 3)
            btn:setX(18 + col * 218)
            btn:setY(400 + row * 36)
            visibleIdx = visibleIdx + 1
        end
    end
end

function NLRelationships:onButton(button)
    if button.action == "close" then self:setVisible(false); return end
    if button.action == "filter" then
        self.filterTab = button.value
        self:layoutActions()
        return
    end
    local data = NLSocialClient.snapshots[self.playerIndex]
    local count = data and #data.neighbors or 0
    if button.action == "next" then self.selected = math.min(count, self.selected + 1); return end
    if button.action == "previous" then self.selected = math.max(1, self.selected - 1); return end
    if button.action == "refresh" then NLSocialClient.request(self.playerIndex, "refresh"); return end

    local npc = data and data.neighbors[self.selected]
    if npc then
        if button.action == "give" or button.action == "request" then
            NLSocialClient.request(self.playerIndex, button.action, {
                id=npc.id,
                item=button.value and button.value.item or "Base.RippedSheets",
                amount=button.value and button.value.amount or 1
            })
        else
            NLSocialClient.request(self.playerIndex, "interact", { id=npc.id, action=button.action })
        end
    end
end

function NLRelationships:prerender()
    ISPanel.prerender(self)
    NLUI.window(self, "Relationships", "Neighbors, chemistry and shared history")

    local data = NLSocialClient.snapshots[self.playerIndex]
    local npc = data and data.neighbors[self.selected]
    local nearby = npc and npc.available and not npc.dead and npc.canInteract == true

    for _, button in ipairs(self.actions) do button:setEnable(nearby == true) end
    if self.actionButtons.partner then
        self.actionButtons.partner:setEnable(nearby == true and (npc.exclusive ~= true or npc.isPartner == true))
    end
    if self.actionButtons.breakup then
        self.actionButtons.breakup:setEnable(nearby == true and npc.isPartner == true)
    end
    if self.actionButtons.apologize then
        self.actionButtons.apologize:setEnable(nearby == true and npc.relation
            and (tonumber(npc.relation.friendship or 0) or 0) < 0)
    end
    if self.actionButtons.compliment then
        self.actionButtons.compliment:setEnable(nearby == true and npc.relation
            and (tonumber(npc.relation.friendship or 0) or 0) >= 20)
    end
    if self.actionButtons.date_activity then
        local activeDate = npc and npc.relation and npc.relation.activeDate
        self.actionButtons.date_activity:setEnable(nearby == true
            and activeDate and activeDate.status == "active")
    end

    if self.filterAll then
        NLUI.setButtonActive(self.filterAll, self.filterTab == "all")
        NLUI.setButtonActive(self.filterFriendly, self.filterTab == "friendly")
        NLUI.setButtonActive(self.filterRomance, self.filterTab == "romance")
    end

    if not npc then
        self.selected = 1
        NLUI.well(self, 18, 100, 654, 236, "NEIGHBOR")
        self:drawText("No neighbors registered in this world yet.", 34, 150,
            C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        self:drawText("Refresh after the world finishes loading.", 34, 174,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        return
    end

    NLUI.well(self, 18, 100, 206, 264, "NEIGHBOR")
    NLUI.monogram(self, 40, 134, 76, npc.name)
    NLUI.drawPlumbob(self, 108, 142, 18, 0.95)
    self:drawText(npc.name, 36, 218, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    self:drawText("Age " .. tostring(npc.age) .. "  |  " .. tostring(npc.relation.status), 36, 238,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
    NLUI.drawTraitPills(self, 34, 258, 172, tostring(npc.personality or ""))

    local relationshipLocation = npc.exclusive
        and (npc.isPartner and "Partner" or "In partnership") or nil
    local dist = math.floor(npc.distance or 999)
    local inRange = npc.available and not npc.dead and (dist <= 4)
    local location
    local statusText
    local statusKind
    if npc.dead then
        location = "Deceased"
        statusText = "DECEASED"
        statusKind = "bad"
    elseif nearby then
        location = "Nearby: " .. dist .. " tiles"
        statusText = "READY TO TALK"
        statusKind = "good"
    elseif inRange then
        location = "In range: " .. dist .. " tiles"
        statusText = "FACE NPC"
        statusKind = "warn"
    elseif npc.available then
        location = "Distance: " .. dist .. " tiles"
        statusText = dist .. " TILES AWAY"
        statusKind = "accent"
    else
        location = "Away"
        statusText = "AWAY"
        statusKind = "neutral"
    end
    if relationshipLocation then location = location .. " | " .. relationshipLocation end
    self:drawText(location, 36, 308, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    NLUI.pill(self, 34, 330, 172, statusText, statusKind)

    NLUI.well(self, 236, 100, 436, 264, "RELATIONSHIP")
    NLUI.metric(self, "Friendship", tostring(npc.relation.friendship), 258, 140, 374,
        (npc.relation.friendship + 100) / 200, "green")
    NLUI.metric(self, "Trust", tostring(npc.relation.trust), 258, 192, 374,
        npc.relation.trust / 100, "cyan")
    NLUI.metric(self, "Attraction", tostring(npc.relation.attraction), 258, 244, 374,
        npc.relation.attraction / 100, "pink")

    local date = npc.relation.activeDate
    local dateText = date and date.status == "active" and "Date in progress"
        or date and date.status == "completed"
            and ("Last date complete | total " .. tostring(npc.relation.completedDates or 0))
        or "No date in progress"
    NLUI.pill(self, 258, 310, 250, dateText, date and date.status == "active" and "good" or nil)

    NLUI.well(self, 18, 376, 654, 190, "INTERACTIONS", true)

    local giveChoice = playerGiveChoice(self.playerIndex)
    local requestChoice = npc.inventoryItems and npc.inventoryItems[1]
    if not requestChoice then
        for item, amount in pairs(npc.inventory or {}) do
            requestChoice = { item=item, amount=amount, label=item }
            break
        end
    end

    local giveButton = self.actionButtons.give
    local requestButton = self.actionButtons.request
    giveButton.value = giveChoice and { item=giveChoice.item, amount=1 } or nil
    requestButton.value = requestChoice and { item=requestChoice.item, amount=1 } or nil
    local isFav = giveChoice and NLSocial and NLSocial.isFavorite
        and NLSocial.isFavorite(npc.id, giveChoice.item)
    setButtonText(giveButton, giveChoice and ("Give " .. giveChoice.label .. (isFav and " (Fav!)" or "")) or "Give item")
    setButtonText(requestButton, requestChoice and ("Request " .. (requestChoice.label or requestChoice.item))
        or "Request item")
    giveButton:setEnable(nearby and giveChoice ~= nil)
    requestButton:setEnable(nearby and requestChoice ~= nil)

    local inventoryParts = {}
    for _, entry in ipairs(npc.inventoryItems or {}) do
        inventoryParts[#inventoryParts + 1] = tostring(entry.amount) .. " x " .. tostring(entry.label or entry.item)
        if #inventoryParts == 2 then break end
    end

    self:drawText(#inventoryParts > 0 and ("NPC inventory: " .. table.concat(inventoryParts, ", "))
        or "NPC inventory: empty", 18, 578, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
    self:drawText(string.sub(data.message or "", 1, 88), 18, 598,
        C.frameMid.r, C.frameMid.g, C.frameMid.b, 1, UIFont.Small)

    local memories = npc.relation.memories
    local latest = memories and memories[#memories]
    if latest then
        self:drawText("Memory: " .. string.sub(latest.text, 1, 78), 18, 618,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
    end
end

function NLRelationships.open(index)
    local panel = NLRelationships.instances[index]
    if not panel then
        panel = NLRelationships:new(index)
        panel:initialise()
        NLRelationships.instances[index] = panel
    end
    panel:removeFromUIManager()
    panel:addToUIManager()
    panel:setVisible(true)
    panel:bringToTop()
    panel:setX(getPlayerScreenLeft(index) + math.max(0, (getPlayerScreenWidth(index) - panel.width) / 2))
    panel:setY(getPlayerScreenTop(index) + math.max(0, (getPlayerScreenHeight(index) - panel.height) / 2))
    NLSocialClient.request(index, "refresh")
end

Events.OnMainMenuEnter.Add(function()
    for _, panel in pairs(NLRelationships.instances) do panel:removeFromUIManager() end
    NLRelationships.instances = {}
end)

return NLRelationships
