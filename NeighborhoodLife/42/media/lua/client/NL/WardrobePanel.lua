require "NL/Journal"
require "NL/Wardrobe"
require "NL/UITheme"

NLWardrobePanel = NLJournal:derive("NLWardrobePanel")
NLWardrobePanel.instances = {}

local C = NLUI.colors

function NLWardrobePanel:new(index)
    local o = ISPanel.new(self, 330, 130, 690, 520)
    o.playerIndex = index
    NLUI.applyPanel(o)
    return o
end

function NLWardrobePanel:initialise()
    ISPanel.initialise(self)
    self:button(self.width - 66, 11, 50, "X", "close")
    self.slots = {}
    for i = 1, 3 do
        local y = 142 + (i - 1) * 110
        self.slots[i] = {
            save = self:button(410, y, 112, "Save current", "save", i),
            wear = self:button(530, y, 122, "Wear outfit", "wear", i)
        }
    end
end

function NLWardrobePanel:onButton(button)
    if button.action == "close" then self:setVisible(false); return end
    local player = getSpecificPlayer(self.playerIndex)
    if not player or player:isDead() then return end
    if button.action == "save" then
        if NLWardrobe.requestSave then
            NLWardrobe.requestSave(player, button.value)
        else
            NLWardrobe.save(player, button.value)
        end
    elseif button.action == "wear" then
        NLWardrobe.wear(player, button.value)
    end
end

function NLWardrobePanel:prerender()
    ISPanel.prerender(self)
    NLUI.window(self, "Wardrobe", "Saved outfits from clothing you own")

    local player = getSpecificPlayer(self.playerIndex)
    local alive = player ~= nil and not player:isDead()
    local profile = NLClient.profiles[self.playerIndex]
    local outfits = alive and ((profile and profile.outfits)
        or player:getModData().NeighborhoodOutfits or {}) or {}

    NLUI.well(self, 18, 92, 654, 356, "SAVED LOOKS")
    for i = 1, 3 do
        local y = 132 + (i - 1) * 110
        local saved = outfits[i]
        NLUI.card(self, 34, y, 354, 84, true)
        NLUI.monogram(self, 48, y + 12, 56, "L" .. i)
        self:drawText("Look " .. i, 120, y + 14,
            C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        self:drawText(saved and (#saved .. " saved pieces") or "Empty slot", 120, y + 40,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        if saved and #saved > 0 then
            NLUI.pill(self, 120, y + 60, 106, "READY", "good")
        else
            NLUI.pill(self, 120, y + 60, 106, "EMPTY", "warn")
        end
        self.slots[i].save:setEnable(alive)
        self.slots[i].wear:setEnable(alive and saved ~= nil and #saved > 0)
    end

    self:drawText("Wear uses matching clothing from your main inventory.", 18, 468,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
    self:drawText("Missing pieces are skipped. Other worn layers remain equipped.", 18, 490,
        C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
end

function NLWardrobePanel.open(index)
    local panel = NLWardrobePanel.instances[index]
    if not panel then
        panel = NLWardrobePanel:new(index)
        panel:initialise()
        NLWardrobePanel.instances[index] = panel
    end
    panel:setX(getPlayerScreenLeft(index) + math.max(0, (getPlayerScreenWidth(index) - panel.width) / 2))
    panel:setY(getPlayerScreenTop(index) + math.max(0, (getPlayerScreenHeight(index) - panel.height) / 2))
    panel:removeFromUIManager()
    panel:addToUIManager()
    panel:setVisible(true)
    panel:bringToTop()
end

Events.OnMainMenuEnter.Add(function()
    for _, panel in pairs(NLWardrobePanel.instances) do panel:removeFromUIManager() end
    NLWardrobePanel.instances = {}
end)

return NLWardrobePanel
