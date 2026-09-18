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

local function buttonTitle(button)
    if button.title and button.title ~= "" then return tostring(button.title) end
    if button.name and button.name ~= "" then return tostring(button.name) end
    return ""
end

function NLSimsButton:prerender()
    local enabled = self.enable ~= false
    local kind = self.nlKind or "primary"
    local fill, edge, shine, text = C.buttonFill, C.buttonEdge, C.buttonShine, C.buttonText

    if kind == "ghost" then
        fill, edge, shine, text = C.surfaceLift, C.line, C.buttonGhostShine, C.chromeDeep
    elseif kind == "danger" then
        fill, edge, shine, text = C.danger, C.dangerEdge, C.dangerShine, C.textLight
    elseif kind == "close" then
        fill, edge, shine, text = { r=0.18, g=0.68, b=0.92, a=0.35 }, { r=0.75, g=0.90, b=1.00, a=0.65 }, C.buttonShine, C.textLight
    elseif kind == "tab" then
        if self.nlActive then
            fill, edge, shine, text = C.surfaceLift, C.chrome, C.buttonShine, C.chromeDeep
        else
            fill, edge, shine, text = { r=0.88, g=0.94, b=0.98, a=0.65 }, { r=0.78, g=0.88, b=0.95, a=0.45 }, C.buttonGhostShine, C.muted
        end
    elseif kind == "friendly" then
        fill, edge, shine, text = C.buttonFriendly, C.buttonFriendlyEdge, C.buttonFriendlyShine, C.textLight
    elseif kind == "romance" then
        fill, edge, shine, text = C.buttonRomance, C.buttonRomanceEdge, C.buttonRomanceShine, C.textLight
    elseif kind == "accent" then
        fill, edge, shine, text = C.buttonAccent, C.buttonAccentEdge, C.buttonAccentShine, C.textLight
    end

    if self.nlActive and kind ~= "tab" then
        fill, edge, shine = C.buttonActive, C.buttonActiveEdge, C.buttonActiveShine
        text = C.textLight
    elseif hovered(self) and enabled then
        if kind == "close" then
            fill, edge, shine = { r=0.92, g=0.30, b=0.35, a=0.90 }, C.dangerEdge, C.dangerShine
            text = C.textLight
        elseif kind == "tab" then
            if not self.nlActive then
                fill, edge, shine = { r=0.96, g=0.98, b=1.00, a=0.92 }, C.chromeSoft, C.buttonShine
                text = C.chromeDeep
            end
        elseif kind == "friendly" then
            fill, edge, shine = C.buttonFriendlyShine, C.buttonFriendlyEdge, C.buttonShine
            text = C.textDark
        elseif kind == "romance" then
            fill, edge, shine = C.buttonRomanceShine, C.buttonRomanceEdge, C.buttonShine
            text = C.textDark
        elseif kind == "ghost" then
            fill, edge, shine = C.surfaceLift, C.chrome, C.buttonShine
            text = C.chrome
        else
            fill, edge, shine = C.buttonHover, C.buttonHoverEdge, C.buttonHoverShine
            text = C.textLight
        end
    elseif not enabled then
        fill, edge, shine, text = C.disabled, C.disabledEdge, C.disabledShine, C.disabledText
    end

    local rad = math.min(16, math.floor(self.height / 2))
    if kind == "close" then rad = 8 end
    NLUI.roundedRect(self, 0, 2, self.width, self.height - 2, C.shadow, (self.nlActive or hovered(self)) and 0.16 or 0.08, rad)
    NLUI.roundedRect(self, 0, 0, self.width, self.height, edge, 1, rad)
    NLUI.roundedRect(self, 1, 1, self.width - 2, self.height - 2, fill, 1, rad - 1)
    NLUI.roundedRect(self, 3, 2, self.width - 6, math.max(3, math.floor((self.height - 4) * 0.32)), shine, 0.35, rad - 2)

    self.textColor = text
    local title = buttonTitle(self)
    local textY = math.max(3, math.floor((self.height - 14) / 2))
    if self.drawTextCentre then
        self:drawTextCentre(title, math.floor(self.width / 2), textY,
            text.r, text.g, text.b, 1, UIFont.Small)
    elseif self.drawText then
        self:drawText(title, 10, textY, text.r, text.g, text.b, 1, UIFont.Small)
    end
end

function NLSimsButton:render()
    -- Intentionally no-op to prevent ISButton:render from overwriting custom styled text
end

return NLSimsButton
