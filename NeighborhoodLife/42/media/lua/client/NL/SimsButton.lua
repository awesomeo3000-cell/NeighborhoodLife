require "ISUI/ISButton"
require "NL/UITheme"

NLSimsButton = ISButton:derive("NLSimsButton")

local C = NLUI.colors

function NLSimsButton:new(x, y, w, h, title, target, onclick)
    local o = ISButton.new(self, x, y, w, h, title, target, onclick)
    o.backgroundColor = {r=0,g=0,b=0,a=0}
    o.backgroundColorMouseOver = {r=0,g=0,b=0,a=0}
    o.borderColor = {r=0,g=0,b=0,a=0}
    o.textColor = C.buttonText
    o.nlKind = "primary"
    o.nlActive = false
    o.nlCompact = false
    return o
end

function NLSimsButton:setKind(kind)
    self.nlKind = kind or "primary"
end

function NLSimsButton:setActive(active)
    self.nlActive = active == true
end

local function hovered(button)
    if button.isMouseOver then
        local ok, value = pcall(button.isMouseOver, button)
        if ok then return value == true end
    end
    return button.mouseOver == true
end

function NLSimsButton:prerender()
    local enabled = self.enable ~= false
    local kind = self.nlKind or "primary"
    local fill, edge, shine, text = C.buttonFill, C.buttonEdge, C.buttonShine, C.buttonText

    if kind == "ghost" then
        fill, edge, shine, text = C.buttonGhost, C.buttonGhostEdge, C.buttonGhostShine, C.textDark
    elseif kind == "danger" then
        fill, edge, shine, text = C.danger, C.dangerEdge, C.dangerShine, C.textLight
    elseif kind == "tab" then
        fill, edge, shine, text = C.tabFill, C.tabEdge, C.tabShine, C.textLight
    end

    if self.nlActive then
        fill, edge, shine = C.buttonActive, C.buttonActiveEdge, C.buttonActiveShine
        text = C.textLight
    elseif hovered(self) and enabled then
        fill, edge, shine = C.buttonHover, C.buttonHoverEdge, C.buttonHoverShine
        text = C.textLight
    elseif not enabled then
        fill, edge, shine, text = C.disabled, C.disabledEdge, C.disabledShine, C.disabledText
    end

    NLUI.roundedRect(self, 0, 2, self.width, self.height - 3, C.shadow, 0.26)
    NLUI.roundedRect(self, 0, 0, self.width, self.height - 3, edge, 1)
    NLUI.roundedRect(self, 2, 2, self.width - 4, self.height - 7, fill, 1)
    NLUI.roundedRect(self, 4, 3, self.width - 8, math.max(5, math.floor((self.height - 8) * 0.34)), shine, 0.34)

    self.textColor = text
    ISButton.prerender(self)
end

return NLSimsButton
