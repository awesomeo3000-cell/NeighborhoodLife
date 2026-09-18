require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Journal"
require "NL/Relationships"
require "NL/WardrobePanel"
require "NL/HouseholdPanel"
require "NL/Plumbob"
require "NL/UITheme"
pcall(require, "NL/NpcInteractionMenu")
pcall(require, "NL/NpcSinglePlayer")

NeighborhoodNeeds = ISPanel:derive("NeighborhoodNeeds")
NeighborhoodNeeds.enabled = true
NeighborhoodNeeds.instances = {}

NeighborhoodNeeds.rows = {
    { "Hunger", "HUNGER" }, { "Thirst", "THIRST" },
    { "Fatigue", "FATIGUE" }, { "Boredom", "BOREDOM" },
    { "Stress", "STRESS" }, { "Unhappiness", "UNHAPPINESS" }
}

NeighborhoodNeeds.nav = {
    { "Career", "career" },
    { "Social", "social" },
    { "Home", "home" },
    { "Appearance", "appearance" },
    { "Wardrobe", "wardrobe" },
}

local C = NLUI.colors

function NeighborhoodNeeds.read(player, key)
    local stat = CharacterStat[key]
    if not player or not stat then return nil end
    local value = player:getStats():get(stat)
    local lo, hi = stat:getMinimumValue(), stat:getMaximumValue()
    if type(value) ~= "number" or value ~= value or hi <= lo then return nil end
    return math.max(0, math.min(1, (value - lo) / (hi - lo)))
end

function NeighborhoodNeeds:new(index, player)
    local font = getTextManager():getFontHeight(UIFont.Small)
    local o = ISPanel.new(self, 0, 0, 500, 320)
    o.playerIndex, o.player = index, player
    o.rowHeight = math.max(31, font + 17)
    o.headerHeight = 48
    o.navButtonHeight = 30
    o.navGap = 6
    o.needsTop = 76
    o.navTop = o.needsTop + 3 * o.rowHeight + 24
    o.expandedHeight = o.navTop + o.navButtonHeight + 18
    o.collapsed = false
    NLUI.applyPanel(o)
    o:setHeight(o.expandedHeight)
    return o
end

function NeighborhoodNeeds:initialise()
    ISPanel.initialise(self)
    self.navButtons = {}
    for i, item in ipairs(self.nav) do
        local button = ISButton:new(0, 0, 80, self.navButtonHeight, item[1], self, self.onNavButton)
        button.action = item[2]
        NLUI.styleButton(button)
        button:initialise()
        self:addChild(button)
        self.navButtons[i] = button
    end
end

function NeighborhoodNeeds.playerName(player, index)
    if player and player.getUsername then
        local ok, name = pcall(player.getUsername, player)
        if ok and name and name ~= "" then return tostring(name) end
    end
    return "Player " .. tostring((index or 0) + 1)
end

function NeighborhoodNeeds.header(player, index)
    return "NEIGHBORHOOD LIFE / " .. NeighborhoodNeeds.playerName(player, index)
end

function NeighborhoodNeeds:dataStatus()
    local ready = 0
    if NLClient and NLClient.profiles and NLClient.profiles[self.playerIndex] then ready = ready + 1 end
    if NLSocialClient and NLSocialClient.snapshots and NLSocialClient.snapshots[self.playerIndex] then ready = ready + 1 end
    if NLHouseholdClient and NLHouseholdClient.snapshots and NLHouseholdClient.snapshots[self.playerIndex] then ready = ready + 1 end
    return ready, 3
end

function NeighborhoodNeeds:requestFeatureData()
    if NLClient and NLClient.request then pcall(NLClient.request, self.playerIndex, "refresh") end
    if NLSocialClient and NLSocialClient.request then pcall(NLSocialClient.request, self.playerIndex, "refresh") end
    if NLHouseholdClient and NLHouseholdClient.request then pcall(NLHouseholdClient.request, self.playerIndex, "refresh") end
end

function NeighborhoodNeeds:layoutNav()
    if not self.navButtons then return end
    local inner = self.width - 32
    local gap = self.navGap
    local buttonWidth = math.floor((inner - gap * 4) / 5)
    for i, button in ipairs(self.navButtons) do
        button:setX(16 + (i - 1) * (buttonWidth + gap))
        button:setY(self.navTop)
        button:setWidth(buttonWidth)
        button:setVisible(not self.collapsed)
    end
end

function NeighborhoodNeeds:onNavButton(button)
    if not button then return end
    if button.action == "career" then
        NLJournal.open(self.playerIndex)
    elseif button.action == "social" then
        NLRelationships.open(self.playerIndex)
    elseif button.action == "home" then
        NLHouseholdPanel.open(self.playerIndex)
    elseif button.action == "appearance" then
        local ok, err = pcall(require, "NL/AppearancePanel")
        if not ok then
            print("[NeighborhoodLife] Appearance panel failed to load: " .. tostring(err))
            return
        end
        if NLAppearancePanel then NLAppearancePanel.open(self.playerIndex) end
    elseif button.action == "wardrobe" then
        NLWardrobePanel.open(self.playerIndex)
    end
end

function NeighborhoodNeeds:onMouseDown(x, y)
    if y <= self.headerHeight then
        self.collapsed = not self.collapsed
        self:setHeight(self.collapsed and self.headerHeight or self.expandedHeight)
        self:layoutNav()
    end
    return true
end

local function drawHeader(panel)
    panel:drawRect(0, 0, panel.width, panel.height, 0.42, C.shadow.r, C.shadow.g, C.shadow.b)
    panel:drawRect(0, 0, panel.width, panel.headerHeight, 1, C.frameDark.r, C.frameDark.g, C.frameDark.b)
    panel:drawRect(3, 3, panel.width - 6, panel.headerHeight - 6, 1, C.headerBottom.r, C.headerBottom.g, C.headerBottom.b)
    panel:drawRect(4, 4, panel.width - 8, 18, 1, C.headerTop.r, C.headerTop.g, C.headerTop.b)
end

function NeighborhoodNeeds:prerender()
    local player = getSpecificPlayer(self.playerIndex)
    if not player or player:isDead() then return end
    self.player = player

    local left, top = getPlayerScreenLeft(self.playerIndex), getPlayerScreenTop(self.playerIndex)
    local width, height = getPlayerScreenWidth(self.playerIndex), getPlayerScreenHeight(self.playerIndex)
    local uiScale = math.max(1.0, math.min(1.35, (width or 1920) / 1920))
    local targetWidth = math.floor(500 * uiScale)
    self:setWidth(math.min(targetWidth, math.max(360, width - 24)))
    self:setX(left + 12)
    self:setY(top + math.max(12, height - self.height - 84))
    self:layoutNav()

    ISPanel.prerender(self)
    drawHeader(self)

    self.title = self.header(player, self.playerIndex)
    self:drawText(self.title, 14, 8, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)

    local ready, total = self:dataStatus()
    self.syncTick = (self.syncTick or 0) + 1
    if ready < total and self.syncTick % 120 == 0 then self:requestFeatureData() end

    local syncText = ready == total and "READY" or ("SYNC " .. tostring(ready) .. "/" .. tostring(total))
    self:drawTextRight(syncText, self.width - 34, 8,
        ready == total and C.green.r or C.yellow.r,
        ready == total and C.green.g or C.yellow.g,
        ready == total and C.green.b or C.yellow.b, 1, UIFont.Small)
    self:drawTextRight(self.collapsed and "+" or "-", self.width - 14, 8,
        C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)

    if self.collapsed then return end

    self:drawRect(4, self.headerHeight, self.width - 8, self.height - self.headerHeight - 4,
        1, C.frameMid.r, C.frameMid.g, C.frameMid.b)
    self:drawRect(8, self.headerHeight + 4, self.width - 16, self.height - self.headerHeight - 12,
        1, C.well.r, C.well.g, C.well.b)

    self:drawText("Needs", 16, 56, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    self:drawText("Lower pressure is better", 62, 56, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    local columnWidth = math.floor((self.width - 46) / 2)
    for i, row in ipairs(self.rows) do
        local col = (i - 1) % 2
        local line = math.floor((i - 1) / 2)
        local x = 16 + col * (columnWidth + 14)
        local y = self.needsTop + line * self.rowHeight
        local value = self.read(player, row[2])

        self:drawText(row[1], x, y, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        local label = value and (tostring(math.floor(value * 100 + 0.5)) .. "%") or "N/A"
        self:drawTextRight(label, x + columnWidth, y, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        NLUI.progress(self, x, y + 18, columnWidth, 12, value or 0, value and NLUI.needColor(value) or "yellow")
    end

    self:drawText("Life Panels", 16, self.navTop - 21,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
end

function NeighborhoodNeeds.create(index, player)
    local old = NeighborhoodNeeds.instances[index]
    if old then old:removeFromUIManager() end
    NeighborhoodNeeds.instances[index] = nil
    if not NeighborhoodNeeds.enabled or not player then return end

    local panel = NeighborhoodNeeds:new(index, player)
    panel:initialise()
    panel:addToUIManager()
    NeighborhoodNeeds.instances[index] = panel
    panel:requestFeatureData()
end

function NeighborhoodNeeds.cleanup()
    for _, panel in pairs(NeighborhoodNeeds.instances) do panel:removeFromUIManager() end
    NeighborhoodNeeds.instances = {}
end

local function ensureNeedsPanel()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not NeighborhoodNeeds.instances[i] then
            NeighborhoodNeeds.create(i, player)
        end
    end
end

Events.OnCreatePlayer.Add(NeighborhoodNeeds.create)
if Events.OnGameStart then Events.OnGameStart.Add(ensureNeedsPanel) end
if Events.OnTick then
    local checkTick = 0
    Events.OnTick.Add(function()
        checkTick = checkTick + 1
        if checkTick % 60 == 0 then ensureNeedsPanel() end
    end)
end
Events.OnMainMenuEnter.Add(NeighborhoodNeeds.cleanup)
