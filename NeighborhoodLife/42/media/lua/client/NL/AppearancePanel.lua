require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Journal"
require "NL/Appearance"
require "NL/UITheme"

NLAppearancePanel = NLJournal:derive("NLAppearancePanel")
NLAppearancePanel.instances = {}

local C = NLUI.colors

function NLAppearancePanel:new(index)
    local o = ISPanel.new(self, 330, 130, 690, 500)
    o.playerIndex = index
    NLUI.applyPanel(o)
    return o
end

function NLAppearancePanel:initialise()
    ISPanel.initialise(self)
    self:button(self.width - 66, 11, 50, "X", "close")
    self.presetButtons = {}
    for i, id in ipairs(NLDefinitions.appearanceOrder) do
        self.presetButtons[id] = self:button(360, 142 + (i - 1) * 58, 286,
            NLDefinitions.appearancePresets[id].name, "select", id)
    end
end

function NLAppearancePanel:onButton(button)
    if button.action == "close" then self:setVisible(false); return end
    if button.action == "select" then
        NLClient.request(self.playerIndex, "appearance_select", { preset=button.value })
    end
end

local function hasGroomingTool(playerIndex)
    local player = getSpecificPlayer(playerIndex)
    local inv = player and player.getInventory and player:getInventory()
    if not inv then return false end
    if inv.containsTag and inv:containsTag("Scissors") then return true end
    if inv.containsType and (inv:containsType("Base.Scissors") or inv:containsType("Scissors")) then return true end
    return false
end

function NLAppearancePanel:prerender()
    ISPanel.prerender(self)
    NLUI.window(self, "Appearance", "Native Build 42 hair presets")

    local player = getSpecificPlayer(self.playerIndex)
    local alive = player ~= nil and not player:isDead()
    local profile = NLClient.profiles[self.playerIndex]
    local current = profile and profile.appearance and profile.appearance.preset or "natural"

    NLUI.well(self, 18, 92, 316, 338, "CURRENT LOOK")
    NLUI.card(self, 78, 126, 196, 154, true)
    NLUI.drawPlumbob(self, 176, 146, 26, 0.95)

    -- Avatar Headshot Frame
    NLUI.roundedRect(self, 136, 178, 80, 84, C.chromeSoft, 0.90)
    NLUI.roundedRect(self, 138, 180, 76, 80, C.surfaceLift, 0.98)
    local label = NLAppearance.label(current)
    if self.drawTextCentre then
        self:drawTextCentre(label, 176, 210, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    else
        self:drawText(label, 148, 210, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    end

    NLUI.pill(self, 86, 290, 180, "ACTIVE: " .. label:upper(), "good")

    local hasTool = hasGroomingTool(self.playerIndex)
    NLUI.pill(self, 46, 324, 260, hasTool and "SCISSORS READY IN INVENTORY" or "SCISSORS / MIRROR RECOMMENDED",
        hasTool and "good" or "warn")
    self:drawText("Saved to your Neighborhood Life profile", 42, 360,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    NLUI.well(self, 348, 92, 324, 338, "CHOOSE A PRESET", true)
    for id, button in pairs(self.presetButtons) do
        button:setEnable(alive)
        NLUI.setButtonActive(button, id == current)
    end

    if not profile then
        self:drawText("Waiting for saved profile data...", 364, 384,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
    end

    self:drawText("Wardrobe handles saved clothing separately.", 18, 454,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
end

function NLAppearancePanel.open(index)
    local panel = NLAppearancePanel.instances[index]
    if not panel then
        panel = NLAppearancePanel:new(index)
        panel:initialise()
        NLAppearancePanel.instances[index] = panel
    end
    panel:removeFromUIManager()
    panel:addToUIManager()
    panel:setX(getPlayerScreenLeft(index) + math.max(0, (getPlayerScreenWidth(index) - panel.width) / 2))
    panel:setY(getPlayerScreenTop(index) + math.max(0, (getPlayerScreenHeight(index) - panel.height) / 2))
    panel:setVisible(true)
    panel:bringToTop()
    NLClient.request(index, "refresh")
end

Events.OnMainMenuEnter.Add(function()
    for _, panel in pairs(NLAppearancePanel.instances) do panel:removeFromUIManager() end
    NLAppearancePanel.instances = {}
end)

return NLAppearancePanel
