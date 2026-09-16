require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Journal"
require "NL/Relationships"
require "NL/WardrobePanel"
require "NL/HouseholdPanel"
require "NL/Plumbob"
require "NL/NpcInteractionMenu"
require "NL/NpcSinglePlayer"

if Events.OnTick then
    Events.OnTick.Add(function()
        if NLNpcAuthority and NLNpcAuthority.update then NLNpcAuthority.update() end
    end)
end

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

local COLORS = {
    panel = { r = 0.055, g = 0.060, b = 0.065, a = 0.94 },
    border = { r = 0.30, g = 0.30, b = 0.28, a = 1 },
    text = { r = 0.93, g = 0.92, b = 0.88, a = 1 },
    muted = { r = 0.66, g = 0.67, b = 0.63, a = 1 },
    accent = { r = 0.86, g = 0.70, b = 0.38, a = 1 },
    track = { r = 0.20, g = 0.21, b = 0.21, a = 1 },
    button = { r = 0.12, g = 0.13, b = 0.14, a = 1 },
    buttonHover = { r = 0.22, g = 0.23, b = 0.22, a = 1 },
    buttonBorder = { r = 0.34, g = 0.33, b = 0.29, a = 1 },
}

-- Numbers and bar fill both show adverse intensity. Lower is better.
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
    local o = ISPanel.new(self, 0, 0, 360, 280)
    o.playerIndex, o.player = index, player
    o.rowHeight = math.max(25, font + 11)
    o.headerHeight = math.max(38, font + 23)
    o.navButtonHeight = 28
    o.navGap = 6
    o.navTop = o.headerHeight + 6 * o.rowHeight + 10
    o.expandedHeight = o.navTop + (o.navButtonHeight * 2) + o.navGap + 12
    o.collapsed = false
    o.backgroundColor = COLORS.panel
    o.borderColor = COLORS.border
    o:setHeight(o.expandedHeight)
    return o
end

function NeighborhoodNeeds:initialise()
    ISPanel.initialise(self)
    self.navButtons = {}
    for i, item in ipairs(self.nav) do
        local button = ISButton:new(0, 0, 80, self.navButtonHeight, item[1], self, self.onNavButton)
        button.action = item[2]
        button.backgroundColor = COLORS.button
        button.backgroundColorMouseOver = COLORS.buttonHover
        button.borderColor = COLORS.buttonBorder
        button.textColor = COLORS.text
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
    local inner = self.width - 24
    local gap = self.navGap
    local three = math.floor((inner - gap * 2) / 3)
    local two = math.floor((inner - gap) / 2)
    local y1 = self.navTop
    local y2 = y1 + self.navButtonHeight + gap
    for i = 1, 3 do
        local b = self.navButtons[i]
        b:setX(12 + (i - 1) * (three + gap))
        b:setY(y1)
        b:setWidth(three)
        b:setVisible(not self.collapsed)
    end
    for i = 4, 5 do
        local b = self.navButtons[i]
        b:setX(12 + (i - 4) * (two + gap))
        b:setY(y2)
        b:setWidth(two)
        b:setVisible(not self.collapsed)
    end
end

function NeighborhoodNeeds:onNavButton(button)
    if not button then return end
    if button.action == "career" then NLJournal.open(self.playerIndex)
    elseif button.action == "social" then NLRelationships.open(self.playerIndex)
    elseif button.action == "home" then NLHouseholdPanel.open(self.playerIndex)
    elseif button.action == "appearance" then
        local ok, err = pcall(require, "NL/AppearancePanel")
        if not ok then
            print("[NeighborhoodLife] Appearance panel failed to load: " .. tostring(err))
            return
        end
        if NLAppearancePanel then NLAppearancePanel.open(self.playerIndex) end
    elseif button.action == "wardrobe" then NLWardrobePanel.open(self.playerIndex) end
end

function NeighborhoodNeeds:onMouseDown(x, y)
    if y <= self.headerHeight then
        self.collapsed = not self.collapsed
        self:setHeight(self.collapsed and self.headerHeight or self.expandedHeight)
        self:layoutNav()
    end
    return true
end

function NeighborhoodNeeds:prerender()
    local player = getSpecificPlayer(self.playerIndex)
    if not player or player:isDead() then return end
    self.player = player
    local left, top = getPlayerScreenLeft(self.playerIndex), getPlayerScreenTop(self.playerIndex)
    local width, height = getPlayerScreenWidth(self.playerIndex), getPlayerScreenHeight(self.playerIndex)
    local uiScale = math.max(1.0, math.min(2.0, (width or 1920) / 1920))
    local targetWidth = math.floor(360 * uiScale)
    self:setWidth(math.min(targetWidth, math.max(220, width - 24)))
    self:setX(left + 12)
    self:setY(top + math.max(12, height - self.height - 84))
    self:layoutNav()
    ISPanel.prerender(self)

    self.title = self.header(player, self.playerIndex)
    self:drawText(self.title, 12, 6, COLORS.text.r, COLORS.text.g, COLORS.text.b, 1, UIFont.Small)
    local ready, total = self:dataStatus()
    local syncText = ready == total and "DATA READY" or ("SYNC " .. tostring(ready) .. "/" .. tostring(total))
    self:drawTextRight(syncText, self.width - 30, 6, COLORS.accent.r, COLORS.accent.g, COLORS.accent.b, 1, UIFont.Small)
    self:drawTextRight(self.collapsed and "+" or "-", self.width - 12, 6,
        COLORS.muted.r, COLORS.muted.g, COLORS.muted.b, 1, UIFont.Small)
    self:drawText("NEEDS PRESSURE / LOWER IS BETTER", 12, 22,
        COLORS.muted.r, COLORS.muted.g, COLORS.muted.b, 1, UIFont.Small)
    if self.collapsed then return end

    for i, row in ipairs(self.rows) do
        local y = self.headerHeight + (i - 1) * self.rowHeight
        local value = self.read(player, row[2])
        local statusHint = ""
        if value then
            if value >= 0.70 then statusHint = "High"
            elseif value >= 0.35 then statusHint = "Medium"
            else statusHint = "Low" end
        end
        local label = value and (tostring(math.floor(value * 100 + 0.5)) .. "%  " .. statusHint) or "N/A"
        self:drawText(row[1], 12, y + 1, COLORS.text.r, COLORS.text.g, COLORS.text.b, 1, UIFont.Small)
        self:drawTextRight(label, self.width - 12, y + 1, COLORS.muted.r, COLORS.muted.g, COLORS.muted.b, 1, UIFont.Small)
        local by = y + self.rowHeight - 7
        self:drawRect(12, by, self.width - 24, 5, 1, COLORS.track.r, COLORS.track.g, COLORS.track.b)
        if value then
            local r, g, b = 0.35, 0.68, 0.39
            if value >= 0.70 then r, g, b = 0.75, 0.25, 0.22
            elseif value >= 0.35 then r, g, b = 0.82, 0.61, 0.25 end
            self:drawRect(12, by, (self.width - 24) * value, 5, 1, r, g, b)
        end
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

Events.OnCreatePlayer.Add(NeighborhoodNeeds.create)
Events.OnMainMenuEnter.Add(NeighborhoodNeeds.cleanup)