require "ISUI/ISPanel"
require "NL/Journal"
require "NL/Relationships"
require "NL/WardrobePanel"
require "NL/HouseholdPanel"
require "NL/Plumbob"
require "NL/UITheme"
require "NL/SimsButton"
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
    local o = ISPanel.new(self, 0, 0, 600, 220)
    o.playerIndex, o.player = index, player
    o.headerHeight = 32
    o.navButtonHeight = 31
    o.navGap = 6
    o.navTop = 175
    o.expandedHeight = 214
    o.collapsed = false
    o.plumbobTexture = getTexture and getTexture("media/textures/NL_Plumbob.png") or nil
    NLUI.applyPanel(o)
    o:setHeight(o.expandedHeight)
    return o
end

function NeighborhoodNeeds:initialise()
    ISPanel.initialise(self)
    self.navButtons = {}
    for i, item in ipairs(self.nav) do
        local button = NLSimsButton:new(0, 0, 90, self.navButtonHeight, item[1], self, self.onNavButton)
        button.action = item[2]
        button:setKind("ghost")
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
    return "Neighborhood Life / " .. NeighborhoodNeeds.playerName(player, index)
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
    local inner = self.width - 28
    local gap = self.navGap
    local buttonWidth = math.floor((inner - gap * 4) / 5)
    for i, button in ipairs(self.navButtons) do
        button:setX(14 + (i - 1) * (buttonWidth + gap))
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

local function drawDockFrame(panel)
    NLUI.roundedRect(panel, 6, 7, panel.width, panel.height - 3, C.shadow, 0.30)
    NLUI.roundedRect(panel, 0, 0, panel.width, panel.height, C.chromeDeep, 0.97)
    NLUI.roundedRect(panel, 3, 3, panel.width - 6, panel.height - 6, C.chrome, 0.97)
    NLUI.roundedRect(panel, 6, 6, panel.width - 12, panel.headerHeight - 7, C.chromeBright, 1)
end

function NeighborhoodNeeds:prerender()
    local player = getSpecificPlayer(self.playerIndex)
    if not player or player:isDead() then return end
    self.player = player

    local left, top = getPlayerScreenLeft(self.playerIndex), getPlayerScreenTop(self.playerIndex)
    local width, height = getPlayerScreenWidth(self.playerIndex), getPlayerScreenHeight(self.playerIndex)
    local uiScale = math.max(1.0, math.min(1.24, (width or 1920) / 1920))
    local targetWidth = math.floor(600 * uiScale)
    self:setWidth(math.min(targetWidth, math.max(420, width - 28)))
    self:setX(left + 14)
    self:setY(top + math.max(12, height - self.height - 28))
    self:layoutNav()

    ISPanel.prerender(self)
    drawDockFrame(self)

    self.title = self.header(player, self.playerIndex)
    self:drawText(self.title, 14, 9, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)

    local ready, total = self:dataStatus()
    self.syncTick = (self.syncTick or 0) + 1
    if ready < total and self.syncTick % 120 == 0 then self:requestFeatureData() end

    local syncText = ready == total and "Ready" or ("Sync " .. tostring(ready) .. "/" .. tostring(total))
    self:drawTextRight(syncText, self.width - 34, 9,
        ready == total and C.green.r or C.yellow.r,
        ready == total and C.green.g or C.yellow.g,
        ready == total and C.green.b or C.yellow.b, 1, UIFont.Small)
    self:drawTextRight(self.collapsed and "+" or "-", self.width - 14, 9,
        C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)

    if self.collapsed then return end

    NLUI.roundedRect(self, 8, 36, self.width - 16, 132, C.surface, 0.99)

    local profile = NLClient and NLClient.profiles and NLClient.profiles[self.playerIndex]
    local mood = ready == total and "Life panels ready" or "Loading neighborhood data"

    NLUI.card(self, 14, 43, 128, 116, true)
    if self.plumbobTexture and self.drawTextureScaled then
        self:drawTextureScaled(self.plumbobTexture, 62, 54, 28, 38, 0.98, 1, 1, 1)
    else
        NLUI.roundedRect(self, 67, 56, 20, 32, C.green, 0.95)
    end
    self:drawText(NeighborhoodNeeds.playerName(player, self.playerIndex), 24, 102,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    local moodLabel = ready == total and "Ready" or "Loading"
    self:drawText(moodLabel, 24, 124, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    local needsX = 158
    local available = self.width - needsX - 18
    local colGap = 18
    local columnWidth = math.floor((available - colGap) / 2)

    for i, row in ipairs(self.rows) do
        local col = (i - 1) % 2
        local line = math.floor((i - 1) / 2)
        local x = needsX + col * (columnWidth + colGap)
        local y = 48 + line * 38
        local value = self.read(player, row[2])

        self:drawText(row[1], x, y, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        local label = value and (tostring(math.floor(value * 100 + 0.5)) .. "%") or "N/A"
        self:drawTextRight(label, x + columnWidth, y,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        NLUI.progress(self, x, y + 18, columnWidth, 12, value or 0,
            value and NLUI.needColor(value) or "yellow")
    end
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
