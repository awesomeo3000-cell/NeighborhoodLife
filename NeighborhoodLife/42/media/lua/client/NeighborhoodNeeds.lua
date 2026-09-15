require "ISUI/ISPanel"
require "NL/Journal"
require "NL/Relationships"
require "NL/WardrobePanel"
require "NL/HouseholdPanel"
require "NL/Plumbob"
require "NL/NpcInteractionMenu"
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

-- Numbers show adverse intensity; bar fill shows remaining wellbeing. No gameplay writes.
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
    local o = ISPanel.new(self, 0, 0, 300, 50 + 6 * (font + 17))
    o.playerIndex, o.player = index, player
    o.rowHeight, o.headerHeight = font + 17, font + 16
    o.expandedHeight = o.headerHeight + 6 * o.rowHeight + font + 20
    o.collapsed = false
    o.backgroundColor = { r = 0.96, g = 0.98, b = 1, a = 0.97 }
    o.borderColor = { r = 0.62, g = 0.76, b = 0.88, a = 1 }
    o:setHeight(o.expandedHeight)
    return o
end

function NeighborhoodNeeds.playerName(player, index)
    if player and player.getUsername then
        local ok, name = pcall(player.getUsername, player)
        if ok and name and name ~= "" then return tostring(name) end
    end
    return "Player " .. tostring((index or 0) + 1)
end

function NeighborhoodNeeds.header(player, index)
    return "NEEDS / " .. NeighborhoodNeeds.playerName(player, index)
        .. " / LOWER % IS BETTER"
end

function NeighborhoodNeeds:onMouseDown(x, y)
    if y <= self.headerHeight then
        self.collapsed = not self.collapsed
        self:setHeight(self.collapsed and self.headerHeight or self.expandedHeight)
    elseif not self.collapsed and y >= self.headerHeight + 6 * self.rowHeight then
        if x > self.width * 0.80 then NLHouseholdPanel.open(self.playerIndex)
        elseif x > self.width * 0.60 then NLWardrobePanel.open(self.playerIndex)
        elseif x > self.width * 0.40 then
            pcall(require, "NL/AppearancePanel")
            if NLAppearancePanel then NLAppearancePanel.open(self.playerIndex) end
        elseif x > self.width * 0.20 then NLRelationships.open(self.playerIndex)
        else NLJournal.open(self.playerIndex) end
    end
    return true
end

function NeighborhoodNeeds:prerender()
    local player = getSpecificPlayer(self.playerIndex)
    if not player or player:isDead() then return end
    self.player = player
    local left, top = getPlayerScreenLeft(self.playerIndex), getPlayerScreenTop(self.playerIndex)
    local width, height = getPlayerScreenWidth(self.playerIndex), getPlayerScreenHeight(self.playerIndex)
    self:setWidth(math.min(300, math.max(180, width - 24)))
    self:setX(left + 12)
    self:setY(top + math.max(12, height - self.height - 84))
    ISPanel.prerender(self)
    self.title = self.header(player, self.playerIndex)
    self:drawText(self.title, 12, 7, 0.12, 0.38, 0.63, 1, UIFont.Small)
    self:drawTextRight(self.collapsed and "+" or "-", self.width - 12, 7, 0.12, 0.38, 0.63, 1, UIFont.Small)
    if self.collapsed then return end
    for i, row in ipairs(self.rows) do
        local y = self.headerHeight + (i - 1) * self.rowHeight
        local value = self.read(player, row[2])
        local label = value and (tostring(math.floor(value * 100 + 0.5)) .. "%") or "N/A"
        self:drawText(row[1], 12, y, 0.18, 0.24, 0.32, 1, UIFont.Small)
        self:drawTextRight(label, self.width - 12, y, 0.18, 0.24, 0.32, 1, UIFont.Small)
        local by = y + self.rowHeight - 10
        self:drawRect(12, by, self.width - 24, 5, 1, 0.82, 0.87, 0.90)
        if value then
            local r, g = 0.3, 0.85
            if value >= 0.7 then r, g = 0.96, 0.35
            elseif value >= 0.35 then r, g = 0.95, 0.73 end
            self:drawRect(12, by, (self.width - 24) * (1 - value), 5, 1, r, g, 0.18)
        end
    end
    self:drawText("Careers   Social   Looks   Wardrobe   Home", 12,
        self.headerHeight + 6 * self.rowHeight + 3, 0.12, 0.38, 0.63, 1, UIFont.Small)
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
end

function NeighborhoodNeeds.cleanup()
    for _, panel in pairs(NeighborhoodNeeds.instances) do panel:removeFromUIManager() end
    NeighborhoodNeeds.instances = {}
end

Events.OnCreatePlayer.Add(NeighborhoodNeeds.create)
Events.OnMainMenuEnter.Add(NeighborhoodNeeds.cleanup)
