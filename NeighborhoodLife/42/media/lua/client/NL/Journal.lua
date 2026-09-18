require "ISUI/ISPanel"
require "NL/Client"
require "NL/UITheme"
require "NL/SimsButton"

NLJournal = ISPanel:derive("NLJournal")
NLJournal.instances = {}

local C = NLUI.colors

local function setBtnVisible(button, visible)
    if button and button.setVisible then button:setVisible(visible) end
end

function NLJournal:new(index)
    local o = ISPanel.new(self, 330, 120, 720, 610)
    o.playerIndex = index
    NLUI.applyPanel(o)
    return o
end

function NLJournal:button(x, y, w, text, action, value, kind)
    local button = NLSimsButton:new(x, y, w, 30, text, self, self.onButton)
    button.action, button.value = action, value
    button:setKind(kind or (action == "close" and "close" or "primary"))
    button:initialise()
    self:addChild(button)
    return button
end

function NLJournal:initialise()
    ISPanel.initialise(self)
    self.currentTab = "career"
    self.rewardPage = 1

    -- Clean modern Sims close button in header
    self:button(self.width - 44, 9, 30, "✕", "close", nil, "close")

    -- Top Navigation Segmented Tabs (Careers | Community Store) centered
    local topTabW = 168
    local topTabX = math.floor((self.width - topTabW * 2 - 10) / 2)
    self.tabCareer = self:button(topTabX, 58, topTabW, "Careers", "tab", "career", "tab")
    self.tabRewards = self:button(topTabX + topTabW + 10, 58, topTabW, "Community Store", "tab", "rewards", "tab")

    -- Career Sub-tabs across 668px width
    self.careerButtons = {}
    local numCareers = #NLDefinitions.careerOrder
    local careerBtnW = math.floor((668 - (numCareers - 1) * 8) / numCareers)
    for i, id in ipairs(NLDefinitions.careerOrder) do
        self.careerButtons[id] = self:button(26 + (i - 1) * (careerBtnW + 8), 102, careerBtnW,
            NLDefinitions.careers[id].name, "select", id, "tab")
    end

    -- Supply delivery buttons tucked neatly inside cards
    self.deliverButtons = {}
    for i = 1, 3 do
        self.deliverButtons[i] = self:button(544, 286 + (i - 1) * 52 + 7, 138,
            "Deliver", "deliver", i, "ghost")
    end

    -- Bottom action buttons
    self.promoteButton = self:button(26, 536, 160, "Check promotion", "promote", nil, "ghost")
    self.refreshButton = self:button(196, 536, 110, "Refresh", "refresh", nil, "ghost")
    self.workButton = self:button(316, 536, 160, "Work shift", "work", nil, "primary")

    -- Rewards catalog
    self.rewardButtons = {}
    for i = 1, 4 do
        self.rewardButtons[i] = self:button(544, 138 + (i - 1) * 78 + 18, 138,
            "Buy", "buy_reward", i, "ghost")
        setBtnVisible(self.rewardButtons[i], false)
    end
    self.rewardPrev = self:button(26, 480, 90, "Previous", "reward_page", -1, "ghost")
    self.rewardNext = self:button(126, 480, 90, "Next", "reward_page", 1, "ghost")
    setBtnVisible(self.rewardPrev, false)
    setBtnVisible(self.rewardNext, false)
end

function NLJournal:updateTabVisibility()
    local career = self.currentTab == "career"
    for _, button in pairs(self.careerButtons) do setBtnVisible(button, career) end
    for _, button in ipairs(self.deliverButtons) do setBtnVisible(button, career) end
    setBtnVisible(self.promoteButton, career)
    setBtnVisible(self.refreshButton, career)
    setBtnVisible(self.workButton, career)

    for _, button in ipairs(self.rewardButtons) do setBtnVisible(button, not career) end
    setBtnVisible(self.rewardPrev, not career)
    setBtnVisible(self.rewardNext, not career)
end

function NLJournal:onButton(button)
    if button.action == "close" then self:setVisible(false); return end
    if button.action == "tab" then
        self.currentTab = button.value
        self:updateTabVisibility()
        return
    end
    if button.action == "reward_page" then
        local maxPage = math.max(1, math.ceil(#(NLDefinitions.rewards or {}) / 4))
        self.rewardPage = math.max(1, math.min(maxPage, self.rewardPage + button.value))
        return
    end
    if button.action == "buy_reward" then
        local reward = NLDefinitions.rewards
            and NLDefinitions.rewards[(self.rewardPage - 1) * 4 + button.value]
        if reward then NLClient.request(self.playerIndex, "purchase", { rewardId = reward.id }) end
        return
    end

    local args = {}
    if button.action == "select" then args.career = button.value end
    if button.action == "deliver" then
        local profile = NLClient.profiles[self.playerIndex]
        if not profile then return end
        local contract = NLDomain.contracts(profile)[button.value]
        if not contract then return end
        args.id = contract.id
    end
    NLClient.request(self.playerIndex, button.action, args)
end

local function playerItemCount(playerIndex, fullType)
    local player = getSpecificPlayer(playerIndex)
    local inventory = player and player.getInventory and player:getInventory()
    if not inventory or not fullType then return 0 end
    if inventory.getItemCountRecurse then
        local ok, count = pcall(inventory.getItemCountRecurse, inventory, fullType)
        if ok and type(count) == "number" then return count end
    end
    if inventory.getItemCount then
        local ok, count = pcall(inventory.getItemCount, inventory, fullType)
        if ok and type(count) == "number" then return count end
    end
    if inventory.getItems then
        local ok, items = pcall(inventory.getItems, inventory)
        if ok and items then
            local count = 0
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item and item.getFullType and item:getFullType() == fullType then
                    count = count + 1
                end
            end
            return count
        end
    end
    return 0
end

local CAREER_EMBLEM_ITEMS = {
    tailor = "Base.Scissors",
    carpenter = "Base.Hammer",
    medic = "Base.FirstAidKit",
}

local function drawCareerInsignia(panel, x, y, size, careerId, rank)
    local rad = 10
    NLUI.roundedRect(panel, x + 1, y + 2, size, size + 8, C.shadow, 0.12, rad)
    NLUI.roundedRect(panel, x, y, size, size + 8, C.chromeSoft, 0.90, rad)
    NLUI.roundedRect(panel, x + 1, y + 1, size - 2, size + 6, C.surfaceLift, 0.98, rad - 1)
    NLUI.roundedRect(panel, x + 3, y + 2, size - 6, 8, C.buttonShine, 0.40, 3)

    local itemType = CAREER_EMBLEM_ITEMS[careerId]
    local scriptItem = itemType and getScriptManager and getScriptManager().FindItem and getScriptManager():FindItem(itemType)
    local iconName = scriptItem and scriptItem.getIcon and scriptItem:getIcon()
    local itemTex = iconName and getTexture and getTexture("Item_" .. iconName)
    if not itemTex and scriptItem and scriptItem.getNormalTexture then
        itemTex = scriptItem:getNormalTexture()
    end

    if itemTex and panel.drawTextureScaled then
        panel:drawTextureScaled(itemTex, x + math.floor((size - 40) / 2), y + 6, 40, 40, 1, 1, 1, 1)
    else
        NLUI.drawPlumbob(panel, x + math.floor(size / 2), y + 24, 22, 0.95)
    end

    local rankText = "Rank " .. tostring(rank or 1)
    local pillW = size - 12
    local pillX = x + 6
    local pillY = y + size - 12
    NLUI.roundedRect(panel, pillX, pillY, pillW, 16, C.chromeSoft, 0.35, 8)
    if panel.drawTextCentre then
        panel:drawTextCentre(rankText, pillX + math.floor(pillW / 2), pillY + 1,
            C.chromeDeep.r, C.chromeDeep.g, C.chromeDeep.b, 1, UIFont.Small)
    elseif panel.drawText then
        panel:drawText(rankText, pillX + 6, pillY + 1,
            C.chromeDeep.r, C.chromeDeep.g, C.chromeDeep.b, 1, UIFont.Small)
    end
end

local function drawCareerCard(panel, profile, definition, progress)
    NLUI.card(panel, 26, 146, 668, 106, true)

    drawCareerInsignia(panel, 40, 158, 68, profile.career, progress.rank)

    local font = UIFont.Medium or UIFont.Small
    panel:drawText(definition.name, 122, 158,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, font)
    panel:drawText(definition.ranks[progress.rank] or "", 122, 182,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    local nextRank = NLDefinitions.promotions[progress.rank + 1]
    local xpTarget = nextRank and math.max(1, tonumber(nextRank.xp or 1) or 1)
        or math.max(1, tonumber(progress.xp or 1) or 1)
    local xpRatio = math.min(1, (tonumber(progress.xp or 0) or 0) / xpTarget)
    NLUI.progress(panel, 122, 206, 330, 14, xpRatio, "cyan")

    panel:drawText("Level " .. tostring(progress.rank) .. " | " .. tostring(progress.xp) .. " / " .. tostring(xpTarget) .. " XP",
        122, 226, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    local worked = profile.workedToday == true
        or (profile.worked and profile.worked[profile.career] == profile.day)

    if worked then
        NLUI.pill(panel, 490, 162, 186, "✓ SHIFT COMPLETE", "good")
    else
        local rad = 13
        NLUI.roundedRect(panel, 490, 162, 186, 26, { r=0.06, g=0.18, b=0.30, a=0.95 }, 1, rad)
        NLUI.roundedRect(panel, 492, 163, 182, 8, C.buttonShine, 0.20, 3)
        if panel.drawText then
            panel:drawText("SHIFT READY", 516, 167, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)
        end
        NLUI.roundedRect(panel, 646, 166, 18, 18, C.green, 1, 9)
        if panel.drawText then
            panel:drawText("✓", 651, 167, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)
        end
    end

    panel:drawText("Skill Level " .. tostring(profile.skill), 490, 204,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    panel:drawText(tostring(progress.delivered) .. " deliveries completed", 490, 226,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    return worked
end

function NLJournal:prerender()
    ISPanel.prerender(self)
    NLUI.window(self, "Neighborhood Journal")

    NLUI.setButtonActive(self.tabCareer, self.currentTab == "career")
    NLUI.setButtonActive(self.tabRewards, self.currentTab == "rewards")

    local profile = NLClient.profiles[self.playerIndex]
    if not profile then
        NLUI.card(self, 26, 112, 668, 390, true)
        self:drawText("Waiting for world data...", 48, 148,
            C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        self:drawText("Use Refresh if this persists.", 48, 170,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        for _, button in ipairs(self.deliverButtons) do button:setEnable(false) end
        return
    end

    if self.currentTab == "rewards" then
        NLUI.sectionTitle(self, 28, 108, "Community Rewards")
        NLUI.pill(self, 520, 102, 174, "Credits " .. tostring(profile.credits or 0), "good")

        local rewards = NLDefinitions.rewards or {}
        local maxPage = math.max(1, math.ceil(#rewards / 4))
        for i = 1, 4 do
            local reward = rewards[(self.rewardPage - 1) * 4 + i]
            local button = self.rewardButtons[i]
            if reward then
                setBtnVisible(button, true)
                local afford = (profile.credits or 0) >= reward.credits
                button:setEnable(afford)
                button:setTitle(afford and "Buy" or "Need credits")
                if button.setKind then
                    button:setKind(afford and "primary" or "ghost")
                end

                local y = 138 + (i - 1) * 78
                NLUI.card(self, 26, y, 668, 68, false)

                local scriptItem = reward.item and getScriptManager and getScriptManager().FindItem and getScriptManager():FindItem(reward.item)
                local iconName = scriptItem and scriptItem.getIcon and scriptItem:getIcon()
                local itemTex = iconName and getTexture and getTexture("Item_" .. iconName)
                if not itemTex and scriptItem and scriptItem.getNormalTexture then
                    itemTex = scriptItem:getNormalTexture()
                end

                NLUI.roundedRect(self, 36, y + 10, 48, 48, C.surfaceAlt, 1, 8)
                NLUI.roundedRect(self, 37, y + 11, 46, 46, C.surfaceLift, 1, 7)
                if itemTex and self.drawTextureScaled then
                    self:drawTextureScaled(itemTex, 44, y + 18, 32, 32, 1, 1, 1, 1)
                else
                    NLUI.drawPlumbob(self, 60, y + 34, 20, 0.90)
                end

                self:drawText(reward.name, 96, y + 12,
                    C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
                self:drawText(string.sub(reward.desc or "", 1, 56), 96, y + 34,
                    C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

                local costColor = afford and C.chromeDeep or C.danger
                self:drawText(tostring(reward.credits) .. " credits", 430, y + 24,
                    costColor.r, costColor.g, costColor.b, 1, UIFont.Small)

                if button.setY then button:setY(y + 18) else button.y = y + 18 end
                if button.setHeight then button:setHeight(32) end
                button.height = 32
            else
                setBtnVisible(button, false)
            end
        end

        self:drawText("Page " .. self.rewardPage .. " of " .. maxPage, 238, 480,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        self.rewardPrev:setEnable(self.rewardPage > 1)
        self.rewardNext:setEnable(self.rewardPage < maxPage)

        NLUI.card(self, 26, 524, 668, 42, false)
        self:drawText(string.sub(profile.message or "", 1, 84), 42, 538,
            C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        return
    end

    for id, button in pairs(self.careerButtons) do
        NLUI.setButtonActive(button, id == profile.career)
    end

    local definition = NLDefinitions.careers[profile.career]
    local progress = profile.careers[profile.career]
    if not definition or not progress then return end

    local worked = drawCareerCard(self, profile, definition, progress)

    NLUI.sectionTitle(self, 28, 262, "Supply Requests")
    local contracts = NLDomain.contracts(profile)
    for i, contract in ipairs(contracts) do
        local y = 286 + (i - 1) * 52
        local done = profile.claimed[contract.id]
        local countInBackpack = playerItemCount(self.playerIndex, contract.item)
        local hasEnough = countInBackpack >= (contract.amount or 1)

        -- Supply request card spanning full 668px width
        NLUI.card(self, 26, y, 668, 46, false)

        -- Real Project Zomboid item icon lookup
        local scriptItem = getScriptManager and getScriptManager().FindItem and getScriptManager():FindItem(contract.item)
        local iconName = scriptItem and scriptItem.getIcon and scriptItem:getIcon()
        local itemTex = iconName and getTexture and getTexture("Item_" .. iconName)
        if not itemTex and scriptItem and scriptItem.getNormalTexture then
            itemTex = scriptItem:getNormalTexture()
        end

        -- Inset icon well
        NLUI.roundedRect(self, 32, y + 5, 36, 36, C.surfaceAlt, 1, 6)
        NLUI.roundedRect(self, 33, y + 6, 34, 34, C.surfaceLift, 1, 5)
        if itemTex and self.drawTextureScaled then
            self:drawTextureScaled(itemTex, 34, y + 7, 32, 32, 1, 1, 1, 1)
        else
            NLUI.drawPlumbob(self, 50, y + 23, 16, 0.85)
        end

        self:drawText(tostring(contract.amount) .. " x " .. NLUI.itemLabel(contract.item),
            78, y + 15, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)

        if done then
            NLUI.pill(self, 370, y + 11, 150, "DELIVERED", "neutral")
        elseif hasEnough then
            NLUI.pill(self, 340, y + 11, 180, "✓ " .. countInBackpack .. "/" .. contract.amount .. " IN BACKPACK", "good")
        else
            NLUI.pill(self, 370, y + 11, 150, countInBackpack .. "/" .. contract.amount .. " NEEDED", "warn")
        end

        local btn = self.deliverButtons[i]
        if btn then
            if btn.setY then btn:setY(y + 7) else btn.y = y + 7 end
            if btn.setHeight then btn:setHeight(32) end
            btn.height = 32
            btn:setEnable(hasEnough and not done)
            if btn.setKind then
                btn:setKind(hasEnough and not done and "primary" or "ghost")
            end
        end
    end

    self.workButton:setEnable(not worked)

    NLUI.sectionTitle(self, 28, 448, "Aspiration")
    NLUI.card(self, 26, 468, 668, 56, false)

    NLUI.drawPlumbob(self, 48, 496, 20, 0.95)

    local stage = profile.aspiration and profile.aspiration.stage or 1
    local m = NLAspirations.milestones[stage]
    local deliveries, ranks = NLAspirations.progress(profile)
    local stageTitle = m and ("Stage " .. stage .. ": " .. m.name .. " ⭐") or "Aspiration Complete ⭐"
    local stageStats = m and ("• Deliveries: " .. math.min(deliveries, m.deliveries) .. "/" .. m.deliveries
        .. "   • Promotions: " .. math.min(ranks, m.ranks) .. "/" .. m.ranks
        .. "   • Reward: +" .. m.reward .. " credits") or "All career milestones completed!"

    self:drawText(stageTitle, 72, 474, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    self:drawText(stageStats, 72, 492, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    local hm = NLAspirations.homeMilestones[profile.homeAspiration and profile.homeAspiration.stage or 1]
    if hm then
        local hTasks = NLAspirations.homeProgress(profile)
        local hText = "🏡 Home: " .. hm.name .. " (" .. math.min(hTasks, hm.tasks) .. "/" .. hm.tasks .. " tasks, +" .. hm.reward .. " credits)"
        self:drawText(hText, 72, 506, C.chromeDeep.r, C.chromeDeep.g, C.chromeDeep.b, 1, UIFont.Small)
    end

    local nextRank = NLDefinitions.promotions[progress.rank + 1]
    local nextText = nextRank and ("Next rank: skill " .. nextRank.skill .. ", " .. nextRank.xp
        .. " XP, " .. nextRank.variety .. " delivery types") or "Top career rank reached"
    self:drawText(nextText, 28, 576, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
end

function NLJournal.open(index)
    local panel = NLJournal.instances[index]
    if not panel then
        panel = NLJournal:new(index)
        panel:initialise()
        NLJournal.instances[index] = panel
    end
    panel:removeFromUIManager()
    panel:addToUIManager()

    local left, top = getPlayerScreenLeft(index), getPlayerScreenTop(index)
    panel:setX(left + math.max(12, math.floor((getPlayerScreenWidth(index) - panel.width) / 2)))
    panel:setY(top + math.max(12, math.floor((getPlayerScreenHeight(index) - panel.height) / 2) - 18))
    panel:setVisible(true)
    panel:bringToTop()
    panel:updateTabVisibility()
    NLClient.request(index, "refresh")
end

Events.OnMainMenuEnter.Add(function()
    for _, panel in pairs(NLJournal.instances) do panel:removeFromUIManager() end
    NLJournal.instances = {}
end)

return NLJournal
