NLUI = NLUI or {}

NLUI.colors = {
    shadow = { r=0.01, g=0.08, b=0.18, a=0.28 },

    chromeDeep = { r=0.01, g=0.52, b=0.82, a=0.98 },
    chrome = { r=0.05, g=0.62, b=0.92, a=0.98 },
    chromeBright = { r=0.22, g=0.74, b=0.97, a=1.00 },
    chromeSoft = { r=0.49, g=0.82, b=0.98, a=1.00 },

    surface = { r=0.95, g=0.97, b=0.99, a=0.98 },
    surfaceAlt = { r=0.91, g=0.95, b=0.99, a=0.96 },
    surfaceLift = { r=1.00, g=1.00, b=1.00, a=0.99 },
    surfaceBlue = { r=0.78, g=0.90, b=0.97, a=0.96 },

    line = { r=0.73, g=0.87, b=0.95, a=0.85 },
    lineSoft = { r=0.85, g=0.93, b=0.98, a=0.65 },

    textLight = { r=1.00, g=1.00, b=1.00, a=1.00 },
    textDark = { r=0.06, g=0.18, b=0.30, a=1.00 },
    muted = { r=0.25, g=0.45, b=0.60, a=1.00 },

    buttonFill = { r=0.96, g=0.98, b=1.00, a=1.00 },
    buttonEdge = { r=0.68, g=0.84, b=0.94, a=1.00 },
    buttonShine = { r=1.00, g=1.00, b=1.00, a=0.55 },
    buttonText = { r=0.06, g=0.24, b=0.42, a=1.00 },

    buttonHover = { r=0.05, g=0.62, b=0.92, a=1.00 },
    buttonHoverEdge = { r=0.01, g=0.52, b=0.82, a=1.00 },
    buttonHoverShine = { r=0.60, g=0.88, b=1.00, a=0.50 },

    buttonActive = { r=0.01, g=0.52, b=0.82, a=1.00 },
    buttonActiveEdge = { r=0.01, g=0.40, b=0.68, a=1.00 },
    buttonActiveShine = { r=0.35, g=0.78, b=0.98, a=0.45 },

    buttonGhost = { r=0.93, g=0.96, b=0.99, a=0.95 },
    buttonGhostEdge = { r=0.68, g=0.84, b=0.94, a=0.90 },
    buttonGhostShine = { r=1.00, g=1.00, b=1.00, a=0.40 },

    tabFill = { r=0.01, g=0.52, b=0.82, a=1.00 },
    tabEdge = { r=0.01, g=0.40, b=0.68, a=1.00 },
    tabShine = { r=0.35, g=0.78, b=0.98, a=0.50 },

    danger = { r=0.92, g=0.26, b=0.32, a=1.00 },
    dangerEdge = { r=0.75, g=0.15, b=0.20, a=1.00 },
    dangerShine = { r=1.00, g=0.55, b=0.60, a=0.40 },

    disabled = { r=0.86, g=0.90, b=0.93, a=1.00 },
    disabledEdge = { r=0.72, g=0.78, b=0.82, a=1.00 },
    disabledShine = { r=0.96, g=0.98, b=0.99, a=1.00 },
    disabledText = { r=0.52, g=0.58, b=0.62, a=1.00 },

    buttonFriendly = { r=0.13, g=0.68, b=0.38, a=1.00 },
    buttonFriendlyEdge = { r=0.08, g=0.48, b=0.26, a=1.00 },
    buttonFriendlyShine = { r=0.45, g=0.88, b=0.60, a=1.00 },

    buttonRomance = { r=0.89, g=0.28, b=0.48, a=1.00 },
    buttonRomanceEdge = { r=0.65, g=0.15, b=0.33, a=1.00 },
    buttonRomanceShine = { r=0.98, g=0.60, b=0.75, a=1.00 },

    buttonAccent = { r=0.08, g=0.55, b=0.82, a=1.00 },
    buttonAccentEdge = { r=0.04, g=0.38, b=0.62, a=1.00 },
    buttonAccentShine = { r=0.40, g=0.78, b=0.98, a=1.00 },

    plumbobGreen = { r=0.18, g=0.86, b=0.28, a=1.00 },
    plumbobGreenDark = { r=0.08, g=0.56, b=0.18, a=1.00 },
    plumbobGreenLight = { r=0.55, g=0.98, b=0.60, a=1.00 },

    track = { r=0.85, g=0.92, b=0.96, a=0.90 },
    trackEdge = { r=0.68, g=0.82, b=0.92, a=0.80 },
    green = { r=0.13, g=0.72, b=0.38, a=1.00 },
    greenDark = { r=0.06, g=0.48, b=0.22, a=1.00 },
    yellow = { r=0.96, g=0.65, b=0.14, a=1.00 },
    red = { r=0.92, g=0.26, b=0.32, a=1.00 },
    pink = { r=0.89, g=0.28, b=0.48, a=1.00 },
    cyan = { r=0.05, g=0.68, b=0.92, a=1.00 },

    -- Floating conversation bubbles are deliberately not framed windows. Keep
    -- their cool near-white treatment separate from the blue window system.
    conversationBubble = { r=0.97, g=0.98, b=1.00, a=0.97 },
    conversationBubbleHover = { r=1.00, g=1.00, b=1.00, a=1.00 },
    conversationBorder = { r=0.60, g=0.71, b=0.83, a=1.00 },
    conversationBorderHover = { r=0.20, g=0.52, b=0.84, a=1.00 },
    conversationText = { r=0.09, g=0.25, b=0.51, a=1.00 },
    conversationTextHover = { r=0.05, g=0.18, b=0.43, a=1.00 },
    conversationNav = { r=0.88, g=0.94, b=1.00, a=0.98 },
    conversationNavBorder = { r=0.31, g=0.59, b=0.88, a=1.00 },
    conversationRomance = { r=1.00, g=0.94, b=0.97, a=0.97 },
    conversationRomanceBorder = { r=0.91, g=0.55, b=0.72, a=1.00 },
    conversationRomanceText = { r=0.62, g=0.15, b=0.40, a=1.00 },
    conversationShadow = { r=0.02, g=0.06, b=0.12, a=0.30 },
    conversationHighlight = { r=1.00, g=1.00, b=1.00, a=0.55 },
}

-- Backward aliases used by existing panels and tests while the visual layer evolves.
NLUI.colors.frameDark = NLUI.colors.chromeDeep
NLUI.colors.frameMid = NLUI.colors.chrome
NLUI.colors.frameLight = NLUI.colors.chromeBright
NLUI.colors.headerTop = NLUI.colors.chromeBright
NLUI.colors.headerBottom = NLUI.colors.chrome
NLUI.colors.well = NLUI.colors.surface
NLUI.colors.wellAlt = NLUI.colors.surfaceAlt
NLUI.colors.wellDark = NLUI.colors.surfaceBlue
NLUI.colors.borderLight = NLUI.colors.lineSoft
NLUI.colors.borderDark = NLUI.colors.chromeDeep
NLUI.colors.button = NLUI.colors.buttonFill
NLUI.colors.buttonBorder = NLUI.colors.buttonEdge
NLUI.colors.close = NLUI.colors.danger
NLUI.colors.closeHover = NLUI.colors.dangerShine

local C = NLUI.colors

local function rect(panel, x, y, w, h, color, alpha)
    if not panel or not panel.drawRect or w <= 0 or h <= 0 then return end
    panel:drawRect(math.floor(x), math.floor(y), math.floor(w), math.floor(h),
        alpha or color.a or 1, color.r, color.g, color.b)
end

function NLUI.roundedRect(panel, x, y, w, h, color, alpha, radius)
    if not panel or not panel.drawRect or w <= 0 or h <= 0 then return end
    alpha = alpha or color.a or 1
    radius = radius or (h <= 24 and 4 or 8)
    radius = math.min(radius, math.floor(w / 2), math.floor(h / 2))
    if radius <= 2 then
        rect(panel, x, y, w, h, color, alpha)
        return
    end
    local bodyH = h - radius * 2
    if bodyH > 0 then
        rect(panel, x, y + radius, w, bodyH, color, alpha)
    end
    for i = 0, radius - 1 do
        local dy = radius - i
        local dx = math.floor(math.sqrt(math.max(0, radius * radius - dy * dy)) + 0.5)
        local inset = radius - dx
        local stripW = w - inset * 2
        if stripW > 0 then
            rect(panel, x + inset, y + i, stripW, 1, color, alpha)
            rect(panel, x + inset, y + h - 1 - i, stripW, 1, color, alpha)
        end
    end
end

function NLUI.clamp(value, lo, hi)
    value = tonumber(value) or 0
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

function NLUI.applyPanel(panel)
    if not panel then return panel end
    panel.backgroundColor = { r=0, g=0, b=0, a=0 }
    panel.borderColor = { r=0, g=0, b=0, a=0 }
    panel.moveWithMouse = true
    return panel
end

function NLUI.styleButton(button, kind, active)
    if not button then return button end
    if button.setKind then button:setKind(kind or "primary") end
    if button.setActive then button:setActive(active == true) end
    return button
end

function NLUI.setButtonActive(button, active)
    if not button then return end
    if button.setActive then
        button:setActive(active == true)
    else
        button.backgroundColor = active and C.buttonActive or C.buttonFill
    end
end

function NLUI.window(panel, title, subtitle)
    if not panel then return end
    local w, h = panel.width or 0, panel.height or 0

    -- 1. Soft Outer Drop Shadow
    NLUI.roundedRect(panel, 4, 6, w - 4, h - 4, C.shadow, 0.20, 14)
    NLUI.roundedRect(panel, 6, 8, w - 8, h - 6, C.shadow, 0.10, 14)

    -- 2. Clean Window Border (2px sky blue frame)
    NLUI.roundedRect(panel, 0, 0, w, h, C.chromeDeep, 0.95, 14)
    NLUI.roundedRect(panel, 1.5, 1.5, w - 3, h - 3, C.chrome, 0.95, 13)

    -- 3. Top Title Header (Glossy Sky Blue Gradient)
    local headerH = 48
    NLUI.roundedRect(panel, 3, 3, w - 6, headerH, C.chrome, 1.0, 11)
    NLUI.roundedRect(panel, 5, 4, w - 10, math.floor(headerH * 0.45), C.chromeBright, 0.65, 9)
    rect(panel, 3, 3 + headerH - 1, w - 6, 1, C.chromeDeep, 0.70)

    -- 4. Main Window Surface (Crisp Frosted White-Azure Glass)
    NLUI.roundedRect(panel, 3, 3 + headerH, w - 6, h - headerH - 6, C.surface, 0.98, 11)
    NLUI.roundedRect(panel, 5, 3 + headerH + 2, w - 10, h - headerH - 10, C.surfaceLift, 0.35, 9)

    -- 5. Title & Subtitle Typography
    local font = UIFont.Medium or UIFont.Small
    if panel.drawTextCentre and title then
        panel:drawTextCentre(title, math.floor(w / 2), 13, 0, 0.10, 0.22, 0.40, font)
        panel:drawTextCentre(title, math.floor(w / 2), 12, C.textLight.r, C.textLight.g, C.textLight.b, 1, font)
    elseif panel.drawText and title then
        panel:drawText(title, 20, 12, 0, 0.10, 0.22, 0.40, font)
        panel:drawText(title, 19, 11, C.textLight.r, C.textLight.g, C.textLight.b, 1, font)
    end
    if panel.drawText and subtitle and subtitle ~= "" then
        panel:drawText(subtitle, 20, 31, 0.88, 0.96, 1.00, 0.90, UIFont.Small)
    end
end

function NLUI.sectionTitle(panel, x, y, text)
    if not panel or not panel.drawText then return end
    panel:drawText(text or "", x, y, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    rect(panel, x, y + 18, math.max(24, (panel.width or 100) - x * 2), 1, C.line, 0.45)
end

function NLUI.card(panel, x, y, w, h, raised)
    local rad = math.min(10, math.floor(h / 3))
    NLUI.roundedRect(panel, x + 1, y + 2, w - 1, h, C.shadow, raised and 0.14 or 0.07, rad)
    NLUI.roundedRect(panel, x, y, w, h, C.line, 0.80, rad)
    NLUI.roundedRect(panel, x + 1, y + 1, w - 2, h - 2, raised and C.surfaceLift or C.surfaceAlt, 0.98, rad - 1)
    NLUI.roundedRect(panel, x + 3, y + 2, w - 6, math.max(4, math.floor(h * 0.22)), C.buttonShine, raised and 0.35 or 0.18, rad - 2)
end

function NLUI.well(panel, x, y, w, h, label, alternate)
    NLUI.card(panel, x, y, w, h, not alternate)
    if label and panel.drawText then
        panel:drawText(label, x + 12, y + 9, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        rect(panel, x + 10, y + 29, w - 20, 1, C.line, 0.50)
    end
end

function NLUI.progress(panel, x, y, w, h, value, kind)
    value = NLUI.clamp(value, 0, 1)
    local rad = math.floor(h / 2)
    local trackColor = { r=0.08, g=0.14, b=0.22, a=0.88 }
    local trackEdge = { r=0.04, g=0.08, b=0.14, a=0.92 }
    NLUI.roundedRect(panel, x, y, w, h, trackEdge, 0.90, rad)
    NLUI.roundedRect(panel, x + 1, y + 1, w - 2, h - 2, trackColor, 0.95, rad - 1)

    local fill = { r=0.15, g=0.78, b=0.96, a=1.00 }
    if kind == "green" then fill = C.green
    elseif kind == "pink" then fill = C.pink
    elseif kind == "yellow" then fill = C.yellow
    elseif kind == "red" then fill = C.red end

    local inner = math.floor((w - 2) * value + 0.5)
    if inner > 2 then
        local fillRad = math.min(rad - 1, math.floor(inner / 2))
        NLUI.roundedRect(panel, x + 1, y + 1, inner, h - 2, fill, 1, fillRad)
        NLUI.roundedRect(panel, x + 3, y + 2, math.max(0, inner - 6), math.max(1, math.floor((h - 2) * 0.35)), C.buttonShine, 0.45, 2)
    end
end

function NLUI.needColor(value)
    value = NLUI.clamp(value, 0, 1)
    if value >= 0.70 then return "red" end
    if value >= 0.35 then return "yellow" end
    return "green"
end

function NLUI.needSatisfactionColor(sat)
    sat = NLUI.clamp(sat, 0, 1)
    if sat <= 0.25 then return "red" end
    if sat <= 0.55 then return "yellow" end
    return "green"
end

function NLUI.pill(panel, x, y, w, text, kind)
    local fill = C.chrome
    if kind == "good" then fill = C.green
    elseif kind == "warn" then fill = C.yellow
    elseif kind == "bad" then fill = C.danger
    elseif kind == "romance" then fill = C.pink
    elseif kind == "accent" or kind == "info" then fill = C.chrome
    elseif kind == "neutral" then fill = C.buttonGhostEdge
    end
    local h = 22
    local rad = math.floor(h / 2)
    NLUI.roundedRect(panel, x, y + 1, w, h, C.shadow, 0.12, rad)
    NLUI.roundedRect(panel, x, y, w, h, fill, 1.0, rad)
    NLUI.roundedRect(panel, x + 2, y + 1, w - 4, 6, C.buttonShine, 0.35, 3)
    if panel.drawTextCentre then
        panel:drawTextCentre(text or "", x + math.floor(w / 2), y + 4, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)
    elseif panel.drawText then
        panel:drawText(text or "", x + 8, y + 4, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)
    end
end

function NLUI.drawTraitPills(panel, x, y, maxWidth, traitsStr)
    if not panel or not traitsStr or traitsStr == "" then return y end
    local traits = {}
    for trait in string.gmatch(traitsStr, "[^,]+") do
        local trimmed = trait:match("^%s*(.-)%s*$")
        if trimmed and #trimmed > 0 then
            traits[#traits + 1] = trimmed
        end
    end
    if #traits == 0 then return y end

    local curX = x
    local curY = y
    local pillHeight = 22
    local rad = math.floor(pillHeight / 2)
    local tm = getTextManager and getTextManager()

    for _, trait in ipairs(traits) do
        local textW = tm and tm.MeasureStringX and tm:MeasureStringX(UIFont.Small, trait) or (#trait * 7)
        local pillW = math.max(42, textW + 18)
        if (curX + pillW) > (x + maxWidth) and curX > x then
            curX = x
            curY = curY + pillHeight + 5
        end
        NLUI.roundedRect(panel, curX, curY + 1, pillW, pillHeight, C.shadow, 0.08, rad)
        NLUI.roundedRect(panel, curX, curY, pillW, pillHeight, C.chromeSoft, 0.90, rad)
        NLUI.roundedRect(panel, curX + 1, curY + 1, pillW - 2, pillHeight - 2, C.surfaceLift, 0.98, rad - 1)
        NLUI.roundedRect(panel, curX + 2, curY + 2, pillW - 4, 5, C.buttonShine, 0.40, 2)
        if panel.drawTextCentre then
            panel:drawTextCentre(trait, curX + math.floor(pillW / 2), curY + 4, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        elseif panel.drawText then
            panel:drawText(trait, curX + 8, curY + 4, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        end
        curX = curX + pillW + 6
    end
    return curY + pillHeight
end

function NLUI.drawPlumbob(panel, cx, cy, size, alpha)
    if not panel or not panel.drawRect then return end
    alpha = alpha or 1
    local halfW = math.max(3, math.floor(size * 0.38))
    local halfH = math.max(5, math.floor(size * 0.58))

    for dy = 0, halfH - 1 do
        local span = math.floor((dy / halfH) * halfW + 0.5)
        local y = cy - halfH + dy
        if span > 0 then
            rect(panel, cx - span, y, span, 1, C.plumbobGreenDark or C.greenDark, alpha)
            rect(panel, cx, y, span, 1, C.plumbobGreenLight or C.green, alpha)
        end
    end
    for dy = 0, halfH do
        local span = math.floor(((halfH - dy) / halfH) * halfW + 0.5)
        local y = cy + dy
        if span > 0 then
            rect(panel, cx - span, y, span, 1, C.greenDark, alpha)
            rect(panel, cx, y, span, 1, C.plumbobGreen or C.green, alpha)
        end
    end
    rect(panel, cx - 1, cy - math.floor(halfH * 0.7), 2, math.floor(halfH * 1.4), C.buttonShine, alpha * 0.75)
end

function NLUI.monogram(panel, x, y, size, name)
    NLUI.roundedRect(panel, x + 2, y + 3, size, size, C.shadow, 0.18)
    NLUI.roundedRect(panel, x, y, size, size, C.chromeSoft, 1)
    NLUI.roundedRect(panel, x + 4, y + 4, size - 8, size - 8, C.surfaceLift, 0.96)
    local initial = tostring(name or "?"):sub(1,1):upper()
    if panel.drawText then
        panel:drawText(initial, x + math.floor(size * 0.43), y + math.floor(size * 0.37),
            C.chromeDeep.r, C.chromeDeep.g, C.chromeDeep.b, 1, UIFont.Small)
    end
end

function NLUI.metric(panel, label, valueText, x, y, w, value, kind)
    if panel.drawText then
        panel:drawText(label, x, y, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        if panel.drawTextRight then
            panel:drawTextRight(valueText or "", x + w, y, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        end
    end
    NLUI.progress(panel, x, y + 18, w, 12, value, kind)
end

function NLUI.itemLabel(fullType)
    local raw = tostring(fullType or "")
    raw = raw:gsub("^.-%.", "")
    local overrides = {
        RippedSheets = "Ripped Sheets",
        Nails = "Nails",
        Plank = "Plank",
    }
    if overrides[raw] then return overrides[raw] end
    raw = raw:gsub("_", " ")
    raw = raw:gsub("(%l)(%u)", "%1 %2")
    raw = raw:gsub("(%a)(%d)", "%1 %2")
    return raw
end

return NLUI
