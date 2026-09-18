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
    button:setKind(kind or (action == "close" and "danger" or "primary"))
    button:initialise()
    self:addChild(button)
    return button
end

function NLJournal:initialise()
    ISPanel.initialise(self)
    self.currentTab = "career"
    self.rewardPage = 1

    self:button(self.width - 52, 10, 36, "X", "close", nil, "danger")

    self.tabCareer = self:button(180, 68, 168, "Careers", "tab", "career", "tab")
    self.tabRewards = self:button(358, 68, 182, "Community Store", "tab", "rewards", "tab")

    self.careerButtons = {}
    for i, id in ipairs(NLDefinitions.careerOrder) do
        self.careerButtons[id] = self:button(26 + (i - 1) * 224, 108, 208,
            NLDefinitions.careers[id].name, "select", id, "ghost")
    end

    self.deliverButtons = {}
    for i = 1, 3 do
        self.deliverButtons[i] = self:button(550, 298 + (i - 1) * 50, 128,
            "Deliver", "deliver", i, "ghost")
    end

    self.promoteButton = self:button(28, 530, 164, "Check promotion", "promote", nil, "ghost")
    self.refreshButton = self:button(202, 530, 106, "Refresh", "refresh", nil, "ghost")
    self.workButton = self:button(318, 530, 170, "Work shift", "work", nil, "primary")

    self.rewardButtons = {}
    for i = 1, 4 do
        self.rewardButtons[i] = self:button(540, 148 + (i - 1) * 72, 138,
            "Buy", "buy_reward", i, "ghost")
        setBtnVisible(self.rewardButtons[i], false)
    end
    self.rewardPrev = self:button(28, 486, 90, "Previous", "reward_page", -1, "ghost")
    self.rewardNext = self:button(128, 486, 90, "Next", "reward_page", 1, "ghost")
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

local function drawCareerInsignia(panel, x, y, size, careerName, rank)
    NLUI.roundedRect(panel, x + 2, y + 3, size, size, C.shadow, 0.18)
    NLUI.roundedRect(panel, x, y, size, size, C.chromeBright, 1)
    NLUI.roundedRect(panel, x + 2, y + 2, size - 4, size - 4, C.chromeSoft, 1)
    NLUI.roundedRect(panel, x + 4, y + 4, size - 8, size - 8, C.surfaceLift, 0.98)

    -- Centered Plumbob on top half
    NLUI.drawPlumbob(panel, x + math.floor(size / 2), y + 16, 18, 0.95)

    -- Centered Career Initial and Rank below plumbob
    local initial = tostring(careerName or "?"):sub(1,1):upper()
    local rankLabel = initial .. " • " .. tostring(rank or 1)
    if panel.drawTextCentre then
        panel:drawTextCentre(rankLabel, x + math.floor(size / 2), y + 34,
            C.chromeDeep.r, C.chromeDeep.g, C.chromeDeep.b, 1, UIFont.Small)
    elseif panel.drawText then
        panel:drawText(rankLabel, x + 8, y + 34,
            C.chromeDeep.r, C.chromeDeep.g, C.chromeDeep.b, 1, UIFont.Small)
    end
end

local function drawCareerCard(panel, profile, definition, progress)
    NLUI.card(panel, 26, 150, 668, 104, true)

    drawCareerInsignia(panel, 42, 168, 58, definition.name, progress.rank)
    panel:drawText(definition.name, 116, 166,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    panel:drawText(definition.ranks[progress.rank], 116, 187,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    local nextRank = NLDefinitions.promotions[progress.rank + 1]
    local xpTarget = nextRank and math.max(1, tonumber(nextRank.xp or 1) or 1)
        or math.max(1, tonumber(progress.xp or 1) or 1)
    NLUI.progress(panel, 116, 214, 300, 14,
        math.min(1, (tonumber(progress.xp or 0) or 0) / xpTarget), "cyan")

    panel:drawText("Career XP " .. tostring(progress.xp) .. " / " .. tostring(xpTarget),
        116, 232, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    local worked = profile.workedToday == true
        or (profile.worked and profile.worked[profile.career] == profile.day)
    NLUI.pill(panel, 520, 172, 148, worked and "SHIFT COMPLETE" or "SHIFT READY",
        worked and "good" or nil)

    panel:drawText("Skill " .. tostring(profile.skill), 520, 208,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    panel:drawText(tostring(progress.delivered) .. " deliveries completed", 520, 229,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    return worked
end

function NLJournal:prerender()
    ISPanel.prerender(self)
    NLUI.window(self, "Neighborhood Journal", "Careers, rewards and neighborhood progress")

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
        NLUI.sectionTitle(self, 28, 116, "Community Rewards")
        NLUI.pill(self, 532, 108, 150, "Credits " .. tostring(profile.credits or 0), "good")

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

                local y = 146 + (i - 1) * 72
                NLUI.card(self, 28, y, 488, 58, false)
                self:drawText(reward.name, 44, y + 10,
                    C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
                self:drawText(string.sub(reward.desc or "", 1, 62), 44, y + 29,
                    C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
                self:drawText(tostring(reward.credits) .. " credits", 392, y + 10,
                    afford and C.chrome.r or C.red.r,
                    afford and C.chrome.g or C.red.g,
                    afford and C.chrome.b or C.red.b, 1, UIFont.Small)
            else
                setBtnVisible(button, false)
            end
        end

        self:drawText("Page " .. self.rewardPage .. " of " .. maxPage, 238, 495,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        self.rewardPrev:setEnable(self.rewardPage > 1)
        self.rewardNext:setEnable(self.rewardPage < maxPage)

        NLUI.card(self, 28, 534, 664, 42, false)
        self:drawText(string.sub(profile.message or "", 1, 84), 42, 548,
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

    NLUI.sectionTitle(self, 28, 270, "Supply Requests")
    local contracts = NLDomain.contracts(profile)
    for i, contract in ipairs(contracts) do
        local y = 292 + (i - 1) * 50
        local done = profile.claimed[contract.id]
        local countInBackpack = playerItemCount(self.playerIndex, contract.item)
        local hasEnough = countInBackpack >= (contract.amount or 1)
        NLUI.card(self, 28, y, 506, 42, false)

        self:drawText(tostring(contract.amount) .. " x " .. NLUI.itemLabel(contract.item),
            44, y + 13, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)

        if done then
            NLUI.pill(self, 370, y + 10, 150, "DELIVERED", "neutral")
        elseif hasEnough then
            NLUI.pill(self, 330, y + 10, 190, "READY (" .. countInBackpack .. "/" .. contract.amount .. ")", "good")
        else
            NLUI.pill(self, 330, y + 10, 190, "NEED (" .. countInBackpack .. "/" .. contract.amount .. ")", "warn")
        end
        self.deliverButtons[i]:setEnable(not done)
        self.deliverButtons[i]:setKind(hasEnough and not done and "primary" or "ghost")
    end

    self.workButton:setEnable(not worked)

    NLUI.sectionTitle(self, 28, 448, "Aspiration Milestones")
    local cardW = 326
    NLUI.card(self, 28, 470, cardW, 48, false)
    self:drawText("CAREER GOAL", 38, 476, C.chrome.r, C.chrome.g, C.chrome.b, 1, UIFont.Small)
    self:drawText(NLAspirations.label(profile), 38, 494,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)

    NLUI.card(self, 366, 470, cardW, 48, false)
    self:drawText("HOME GOAL", 376, 476, C.chrome.r, C.chrome.g, C.chrome.b, 1, UIFont.Small)
    self:drawText(NLAspirations.homeLabel(profile), 376, 494,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)

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
