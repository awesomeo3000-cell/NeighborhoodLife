require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Journal"
require "NL/Appearance"

NLAppearancePanel = NLJournal:derive("NLAppearancePanel")
NLAppearancePanel.instances = {}

function NLAppearancePanel:new(index)
    local o = ISPanel.new(self, 330, 130, 590, 410)
    o.playerIndex = index
    o.backgroundColor = { r = 0.96, g = 0.98, b = 1, a = 0.98 }
    o.borderColor = { r = 0.62, g = 0.76, b = 0.88, a = 1 }
    o.moveWithMouse = true
    return o
end

function NLAppearancePanel:initialise()
    ISPanel.initialise(self)
    self:button(self.width - 75, 10, 60, "Close", "close")
    self.presetButtons = {}
    for i, id in ipairs(NLDefinitions.appearanceOrder) do
        self.presetButtons[id] = self:button(340, 92 + (i - 1) * 48, 220,
            NLDefinitions.appearancePresets[id].name, "select", id)
    end
end

function NLAppearancePanel:onButton(button)
    if button.action == "close" then self:setVisible(false); return end
    if button.action == "select" then
        NLClient.request(self.playerIndex, "appearance_select", { preset = button.value })
    end
end

function NLAppearancePanel:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD / APPEARANCE", 16, 14, 0.12, 0.38, 0.63, 1, UIFont.Small)
    self:drawText("Choose a native Build 42 hair preset for this survivor.",
        16, 60, 0.18, 0.24, 0.32, 1, UIFont.Small)
    local player = getSpecificPlayer(self.playerIndex)
    local alive = player ~= nil and not player:isDead()
    local profile = NLClient.profiles[self.playerIndex]
    local current = profile and profile.appearance and profile.appearance.preset or "natural"
    self:drawText("CURRENT: " .. NLAppearance.label(current), 16, 95,
        0.12, 0.38, 0.63, 1, UIFont.Small)
    for id, button in pairs(self.presetButtons) do
        button:setEnable(alive)
        button.backgroundColor = id == current
            and { r = 0.65, g = 0.88, b = 0.36, a = 1 }
            or { r = 0.86, g = 0.92, b = 0.97, a = 1 }
    end
    self:drawText("The server saves this choice to your account/world profile.",
        16, 302, 0.30, 0.38, 0.47, 1, UIFont.Small)
    self:drawText("Hair assets are supplied by the installed game; more original assets remain planned.",
        16, 326, 0.30, 0.38, 0.47, 1, UIFont.Small)
end

function NLAppearancePanel.open(index)
    local panel = NLAppearancePanel.instances[index]
    if not panel then
        panel = NLAppearancePanel:new(index); panel:initialise()
        NLAppearancePanel.instances[index] = panel
    end
    panel:removeFromUIManager(); panel:addToUIManager()
    panel:setX(getPlayerScreenLeft(index) + math.max(0, (getPlayerScreenWidth(index) - panel.width) / 2))
    panel:setY(getPlayerScreenTop(index) + math.max(0, (getPlayerScreenHeight(index) - panel.height) / 2))
    panel:setVisible(true); panel:bringToTop()
    NLClient.request(index, "refresh")
end

Events.OnMainMenuEnter.Add(function()
    for _, panel in pairs(NLAppearancePanel.instances) do panel:removeFromUIManager() end
    NLAppearancePanel.instances = {}
end)

return NLAppearancePanel
