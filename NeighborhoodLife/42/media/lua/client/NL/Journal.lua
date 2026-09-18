require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Client"
require "NL/UITheme"

NLJournal = ISPanel:derive("NLJournal")
NLJournal.instances = {}

local C = NLUI.colors

local function setBtnVisible(button, visible)
    if button and button.setVisible then button:setVisible(visible) end
end

function NLJournal:new(index)
    local o = ISPanel.new(self, 330, 130, 690, 570)
    o.playerIndex = index
    NLUI.applyPanel(o)
    return o
end

function NLJournal:button(x, y, w, text, action, value)
    local button = ISButton:new(x, y, w, 28, text, self, self.onButton)
    button.action, button.value = action, value
    NLUI.styleButton(button, action == "close" and "close" or "primary")
    button:initialise()
    self:addChild(button)
    return button
end

function NLJournal:initialise()
    ISPanel.initialise(self)
    self.currentTab = "career"
    self.rewardPage = 1

    self:button(self.width - 66, 11, 50, "X", "close")
    self.tabCareer = self:button(188, 58, 140, "Careers", "tab", "career")
    self.tabRewards = self:button(336, 58, 184, "Community Store", "tab", "rewards")

    self.careerButtons = {}
    for i, id in ipairs(NLDefinitions.careerOrder) do
        self.careerButtons[id] = self:button(18 + (i - 1) * 218, 96, 210,
            NLDefinitions.careers[id].name, "select", id)
    end

    self.deliverButtons = {}
    for i = 1, 3 do
        self.deliverButtons[i] = self:button(532, 270 + (i - 1) * 52, 124, "Deliver", "deliver", i)
    end

    self.promoteButton = self:button(18, 484, 188, "Check promotion", "promote")
    self.refreshButton = self:button(214, 484, 100, "Refresh", "refresh")
    self.workButton = self:button(322, 484, 180, "Work shift", "work")

    self.rewardButtons = {}
    for i = 1, 4 do
        self.rewardButtons[i] = self:button(532, 136 + (i - 1) * 74, 124, "Buy", "buy_reward", i)
        setBtnVisible(self.rewardButtons[i], false)
    end
    self.rewardPrev = self:button(18, 456, 84, "< Prev", "reward_page", -1)
    self.rewardNext = self:button(110, 456, 84, "Next >", "reward_page", 1)
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
        local reward = NLDefinitions.rewards and NLDefinitions.rewards[(self.rewardPage - 1) * 4 + button.value]
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

function NLJournal:prerender()
    ISPanel.prerender(self)
    NLUI.window(self, "Neighborhood Journal", "Careers, rewards and neighborhood progress")

    NLUI.setButtonActive(self.tabCareer, self.currentTab == "career")
    NLUI.setButtonActive(self.tabRewards, self.currentTab == "rewards")

    local profile = NLClient.profiles[self.playerIndex]
    if not profile then
        NLUI.well(self, 18, 100, 654, 410, "WORLD DATA")
        self:drawText("Waiting for world data. Use Refresh if this persists.", 32, 142,
            C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        for _, button in ipairs(self.deliverButtons) do button:setEnable(false) end
        return
    end

    if self.currentTab == "rewards" then
        NLUI.well(self, 18, 100, 654, 338, "COMMUNITY REWARDS")
        NLUI.pill(self, 520, 104, 136, "Credits: " .. tostring(profile.credits or 0), "good")

        local rewards = NLDefinitions.rewards or {}
        local maxPage = math.max(1, math.ceil(#rewards / 4))
        for i = 1, 4 do
            local reward = rewards[(self.rewardPage - 1) * 4 + i]
            local button = self.rewardButtons[i]
            if reward then
                setBtnVisible(button, true)
                local afford = (profile.credits or 0) >= reward.credits
                button:setEnable(afford)
                button:setTitle(tostring(reward.credits) .. " credits")
                local y = 132 + (i - 1) * 74
                self:drawRect(30, y, 488, 60, 1, C.wellAlt.r, C.wellAlt.g, C.wellAlt.b)
                self:drawText(reward.name, 42, y + 7, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
                self:drawText(string.sub(reward.desc or "", 1, 74), 42, y + 27,
                    C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
                self:drawText("Cost: " .. tostring(reward.credits), 42, y + 44,
                    afford and C.frameMid.r or C.red.r,
                    afford and C.frameMid.g or C.red.g,
                    afford and C.frameMid.b or C.red.b, 1, UIFont.Small)
            else
                setBtnVisible(button, false)
            end
        end

        self:drawText("Page " .. self.rewardPage .. " / " .. maxPage, 212, 463,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        self.rewardPrev:setEnable(self.rewardPage > 1)
        self.rewardNext:setEnable(self.rewardPage < maxPage)

        NLUI.well(self, 18, 500, 654, 48, "STATUS", true)
        self:drawText(string.sub(profile.message or "", 1, 86), 30, 528,
            C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        return
    end

    for id, button in pairs(self.careerButtons) do
        NLUI.setButtonActive(button, id == profile.career)
    end

    local definition = NLDefinitions.careers[profile.career]
    local progress = profile.careers[profile.career]
    if not definition or not progress then return end

    NLUI.well(self, 18, 136, 654, 86, "CAREER PROGRESS")
    self:drawText(definition.ranks[progress.rank], 32, 171,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    self:drawText("Skill " .. tostring(profile.skill) .. "   |   Career XP " .. tostring(progress.xp)
        .. "   |   Deliveries " .. tostring(progress.delivered), 32, 193,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    local shift = definition.shift
    local worked = profile.workedToday == true
        or (profile.worked and profile.worked[profile.career] == profile.day)
    NLUI.pill(self, 476, 168, 180, worked and "SHIFT COMPLETE" or "SHIFT READY",
        worked and "good" or nil)

    NLUI.well(self, 18, 232, 654, 190, "SUPPLY REQUESTS")
    for i, contract in ipairs(NLDomain.contracts(profile)) do
        local y = 271 + (i - 1) * 52
        local done = profile.claimed[contract.id]
        self:drawRect(30, y - 7, 486, 38, 1, C.wellAlt.r, C.wellAlt.g, C.wellAlt.b)
        self:drawText(contract.amount .. " x " .. contract.item, 42, y,
            C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        if done then
            NLUI.pill(self, 420, y - 2, 92, "DONE", "good")
        end
        self.deliverButtons[i]:setEnable(not done)
    end

    self.workButton:setEnable(not worked)

    NLUI.well(self, 18, 432, 654, 42, "ASPIRATION", true)
    self:drawText(NLAspirations.label(profile), 32, 459,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    self:drawText(NLAspirations.homeLabel(profile), 360, 459,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    local nextRank = NLDefinitions.promotions[progress.rank + 1]
    local nextText = nextRank and ("Next rank: skill " .. nextRank.skill .. ", " .. nextRank.xp
        .. " XP, " .. nextRank.variety .. " delivery types") or "Top career rank reached"
    self:drawText(nextText, 18, 526, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
    self:drawText(string.sub(profile.message or "", 1, 86), 18, 546,
        C.frameMid.r, C.frameMid.g, C.frameMid.b, 1, UIFont.Small)
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
    panel:setX(left + math.max(12, math.min(300, getPlayerScreenWidth(index) - panel.width - 12)))
    panel:setY(top + math.max(12, math.min(70, getPlayerScreenHeight(index) - panel.height - 12)))
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
