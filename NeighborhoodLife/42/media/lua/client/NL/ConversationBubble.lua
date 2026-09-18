-- Floating conversation pill used by the world conversation overlay.
--
-- This is deliberately not a framed window: it is a small near-white pill with
-- dark blue text that floats above the world. The rounded shape is assembled
-- from per-row rectangles so the production mod needs no binary UI assets and
-- the contract tests can run without a texture cache.
require "ISUI/ISButton"
require "NL/UITheme"

NLConversationBubble = ISButton:derive("NLConversationBubble")

local C = NLUI.colors

local MIN_WIDTH = 92
local MAX_WIDTH = 232
local NAV_MIN_WIDTH = 132
local NORMAL_HEIGHT = 26
local NAV_HEIGHT = 28

local function textManager()
    if type(getTextManager) ~= "function" then return nil end
    local ok, manager = pcall(getTextManager)
    return ok and manager or nil
end

function NLConversationBubble.textWidth(label, font)
    label = tostring(label or "")
    local manager = textManager()
    if manager and manager.MeasureStringX then
        local ok, width = pcall(manager.MeasureStringX, manager, font or UIFont.Small, label)
        if ok and tonumber(width) then return tonumber(width) end
    end
    return #label * 7
end

local function horizontalPadding(kind)
    return kind == "nav" and 40 or 28
end

function NLConversationBubble.measure(label, kind)
    local width = NLConversationBubble.textWidth(label) + horizontalPadding(kind)
    local minimum = kind == "nav" and NAV_MIN_WIDTH or MIN_WIDTH
    if width < minimum then width = minimum end
    if width > MAX_WIDTH then width = MAX_WIDTH end
    return math.floor(width)
end

-- Keep the label inside the fixed maximum pill width with a plain ellipsis.
function NLConversationBubble.fit(label, kind)
    label = tostring(label or "")
    local maximum = MAX_WIDTH - horizontalPadding(kind)
    if NLConversationBubble.textWidth(label) <= maximum then return label end
    local text = label
    while #text > 4 and NLConversationBubble.textWidth(text .. "...") > maximum do
        text = string.sub(text, 1, #text - 1)
    end
    return text .. "..."
end

function NLConversationBubble.colorsFor(kind, hover)
    local colors = {
        fill = C.conversationBubble,
        border = C.conversationBorder,
        text = C.conversationText,
        shadow = C.conversationShadow,
        highlight = C.conversationHighlight,
    }
    if kind == "nav" then
        colors.fill = C.conversationNav
        colors.border = C.conversationNavBorder
    elseif kind == "romance" then
        colors.fill = C.conversationRomance
        colors.border = C.conversationRomanceBorder
        colors.text = C.conversationRomanceText
    end
    if hover then
        colors.fill = C.conversationBubbleHover
        colors.border = C.conversationBorderHover
        colors.text = kind == "romance" and C.conversationRomanceText or C.conversationTextHover
    end
    return colors
end

local function drawPillShape(panel, x, y, w, h, color)
    if not panel or not panel.drawRect or w <= 0 or h <= 0 then return end
    color = color or C.conversationBubble
    local radius = h / 2
    for row = 0, h - 1 do
        local dy = row + 0.5 - radius
        local square = radius * radius - dy * dy
        local inset = radius - math.sqrt(square > 0 and square or 0)
        local index = math.floor(inset + 0.5)
        local rowWidth = w - index * 2
        if rowWidth > 0 then
            panel:drawRect(x + index, y + row, rowWidth, 1,
                color.a or 1, color.r, color.g, color.b)
        end
    end
end

NLConversationBubble.drawPillShape = drawPillShape

function NLConversationBubble.draw(panel, x, y, w, h, colors)
    if not panel then return end
    colors = colors or NLConversationBubble.colorsFor("normal", false)
    drawPillShape(panel, x + 1, y + 2, w, h, colors.shadow)
    drawPillShape(panel, x, y, w, h, colors.border)
    drawPillShape(panel, x + 1, y + 1, w - 2, h - 2, colors.fill)
    if panel.drawRect and w > 10 and h > 8 and colors.highlight then
        local highlight = colors.highlight
        panel:drawRect(x + math.floor(h / 2), y + 2, w - h, 1,
            highlight.a or 0.4, highlight.r, highlight.g, highlight.b)
    end
end

function NLConversationBubble.fontHeight(font)
    local manager = textManager()
    if manager and manager.getFontHeight then
        local ok, height = pcall(manager.getFontHeight, manager, font or UIFont.Small)
        if ok and tonumber(height) then return tonumber(height) end
    end
    return 12
end

function NLConversationBubble:new(x, y, label, kind, onClick)
    kind = kind or "normal"
    local width = NLConversationBubble.measure(label, kind)
    local height = kind == "nav" and NAV_HEIGHT or NORMAL_HEIGHT
    local o = ISButton.new(self, x, y, width, height,
        NLConversationBubble.fit(label, kind), nil, NLConversationBubble.clicked)
    o.kind = kind
    o.label = NLConversationBubble.fit(label, kind)
    o.navigation = false
    o.onBubbleClick = onClick
    o.backgroundColor = C.conversationBubble
    o.backgroundColorMouseOver = C.conversationBubbleHover
    o.borderColor = C.conversationBorder
    o.textColor = C.conversationText
    return o
end

function NLConversationBubble:setNavigation(navigation)
    self.navigation = navigation == true
    return self
end

function NLConversationBubble.clicked(target, bubble)
    if bubble and bubble.onBubbleClick then
        bubble.onBubbleClick(bubble)
    end
end

function NLConversationBubble:prerender()
    local hover = self.mouseOver == true or self.pressed == true
    local colors = NLConversationBubble.colorsFor(self.kind, hover)
    NLConversationBubble.draw(self, 0, 0, self.width, self.height, colors)
    if self.drawTextCentre then
        local height = NLConversationBubble.fontHeight(self.font)
        local y = math.floor((self.height - height) / 2)
        self:drawTextCentre(self.label or "", math.floor(self.width / 2), y,
            colors.text.r, colors.text.g, colors.text.b, 1, self.font or UIFont.Small)
    end
end

return NLConversationBubble
