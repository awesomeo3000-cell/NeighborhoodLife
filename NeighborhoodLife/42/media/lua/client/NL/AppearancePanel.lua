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

function NLAppearancePanel:prerender()
    ISPanel.prerender(self)
    NLUI.window(self, "Appearance", "Native Build 42 hair presets")

    local player = getSpecificPlayer(self.playerIndex)
    local alive = player ~= nil and not player:isDead()
    local profile = NLClient.profiles[self.playerIndex]
    local current = profile and profile.appearance and profile.appearance.preset or "natural"

    NLUI.well(self, 18, 92, 316, 338, "CURRENT LOOK")
    NLUI.monogram(self, 98, 138, 150, NLAppearance.label(current))
    self:drawText(NLAppearance.label(current), 104, 306,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    self:drawText("Saved to your Neighborhood Life profile", 54, 338,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

    NLUI.well(self, 348, 92, 324, 338, "CHOOSE A PRESET", true)
    for id, button in pairs(self.presetButtons) do
        button:setEnable(alive)
        NLUI.setButtonActive(button, id == current)
    end

    if not profile then
        self:drawText("Waiting for saved profile data...", 54, 378,
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
