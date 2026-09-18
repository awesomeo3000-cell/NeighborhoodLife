NLUI = NLUI or {}

NLUI.colors = {
    shadow = { r=0.00, g=0.03, b=0.08, a=0.34 },

    chromeDeep = { r=0.025, g=0.19, b=0.36, a=0.98 },
    chrome = { r=0.045, g=0.36, b=0.63, a=0.98 },
    chromeBright = { r=0.12, g=0.59, b=0.87, a=1.00 },
    chromeSoft = { r=0.36, g=0.74, b=0.92, a=1.00 },

    surface = { r=0.90, g=0.96, b=0.985, a=0.98 },
    surfaceAlt = { r=0.82, g=0.92, b=0.97, a=0.98 },
    surfaceLift = { r=0.96, g=0.985, b=1.00, a=0.99 },
    surfaceBlue = { r=0.72, g=0.88, b=0.95, a=0.98 },

    line = { r=0.48, g=0.71, b=0.83, a=0.62 },
    lineSoft = { r=0.71, g=0.86, b=0.93, a=0.50 },

    textLight = { r=0.99, g=1.00, b=1.00, a=1.00 },
    textDark = { r=0.055, g=0.16, b=0.23, a=1.00 },
    muted = { r=0.28, g=0.42, b=0.50, a=1.00 },

    buttonFill = { r=0.93, g=0.96, b=0.98, a=1.00 },
    buttonEdge = { r=0.41, g=0.53, b=0.61, a=1.00 },
    buttonShine = { r=1.00, g=1.00, b=1.00, a=1.00 },
    buttonText = { r=0.07, g=0.28, b=0.47, a=1.00 },

    buttonHover = { r=0.15, g=0.57, b=0.86, a=1.00 },
    buttonHoverEdge = { r=0.03, g=0.28, b=0.52, a=1.00 },
    buttonHoverShine = { r=0.63, g=0.88, b=1.00, a=1.00 },

    buttonActive = { r=0.055, g=0.38, b=0.70, a=1.00 },
    buttonActiveEdge = { r=0.02, g=0.20, b=0.40, a=1.00 },
    buttonActiveShine = { r=0.32, g=0.72, b=0.94, a=1.00 },

    buttonGhost = { r=0.79, g=0.90, b=0.95, a=1.00 },
    buttonGhostEdge = { r=0.45, g=0.66, b=0.76, a=1.00 },
    buttonGhostShine = { r=0.96, g=0.99, b=1.00, a=1.00 },

    tabFill = { r=0.085, g=0.43, b=0.73, a=1.00 },
    tabEdge = { r=0.02, g=0.23, b=0.43, a=1.00 },
    tabShine = { r=0.30, g=0.70, b=0.92, a=1.00 },

    danger = { r=0.58, g=0.19, b=0.22, a=1.00 },
    dangerEdge = { r=0.34, g=0.08, b=0.10, a=1.00 },
    dangerShine = { r=0.84, g=0.40, b=0.42, a=1.00 },

    disabled = { r=0.72, g=0.76, b=0.79, a=1.00 },
    disabledEdge = { r=0.50, g=0.55, b=0.58, a=1.00 },
    disabledShine = { r=0.90, g=0.92, b=0.93, a=1.00 },
    disabledText = { r=0.38, g=0.42, b=0.44, a=1.00 },

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

    track = { r=0.36, g=0.47, b=0.52, a=0.88 },
    green = { r=0.27, g=0.78, b=0.30, a=1.00 },
    greenDark = { r=0.12, g=0.50, b=0.17, a=1.00 },
    yellow = { r=0.95, g=0.72, b=0.19, a=1.00 },
    red = { r=0.85, g=0.24, b=0.25, a=1.00 },
    pink = { r=0.86, g=0.35, b=0.65, a=1.00 },
    cyan = { r=0.18, g=0.69, b=0.86, a=1.00 },

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

function NLUI.roundedRect(panel, x, y, w, h, color, alpha)
    if not panel or w <= 0 or h <= 0 then return end
    if w < 8 or h < 8 then
        rect(panel, x, y, w, h, color, alpha)
        return
    end
    rect(panel, x + 3, y, w - 6, h, color, alpha)
    rect(panel, x + 1, y + 2, w - 2, h - 4, color, alpha)
    rect(panel, x, y + 4, w, h - 8, color, alpha)
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

    NLUI.roundedRect(panel, 8, 10, w - 8, h - 6, C.shadow, 0.34)
    NLUI.roundedRect(panel, 0, 0, w, h, C.chromeDeep, 0.98)
    NLUI.roundedRect(panel, 3, 3, w - 6, h - 6, C.chrome, 0.98)

    NLUI.roundedRect(panel, 7, 7, w - 14, 46, C.chromeBright, 1)
    NLUI.roundedRect(panel, 9, 26, w - 18, 26, C.chrome, 0.92)

    NLUI.roundedRect(panel, 8, 56, w - 16, h - 64, C.surface, 0.99)
    NLUI.roundedRect(panel, 11, 59, w - 22, h - 70, C.surfaceLift, 0.30)

    if panel.drawText and title then
        panel:drawText(title, 18, 13, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)
    end
    if panel.drawText and subtitle and subtitle ~= "" then
        panel:drawText(subtitle, 18, 33, 0.84, 0.95, 1.00, 1, UIFont.Small)
    end
end

function NLUI.sectionTitle(panel, x, y, text)
    if not panel or not panel.drawText then return end
    panel:drawText(text or "", x, y, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    rect(panel, x, y + 20, math.max(24, (panel.width or 100) - x * 2), 1, C.line, 0.52)
end

function NLUI.card(panel, x, y, w, h, raised)
    NLUI.roundedRect(panel, x + 2, y + 3, w, h, C.shadow, raised and 0.18 or 0.10)
    NLUI.roundedRect(panel, x, y, w, h, raised and C.surfaceLift or C.surfaceAlt, 0.99)
    NLUI.roundedRect(panel, x + 2, y + 2, w - 4, math.max(5, math.floor(h * 0.20)),
        C.buttonShine, raised and 0.30 or 0.18)
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
    NLUI.roundedRect(panel, x, y, w, h, C.track, 0.82)
    NLUI.roundedRect(panel, x + 2, y + 2, w - 4, h - 4, C.surfaceLift, 0.20)

    local fill = C.green
    if kind == "pink" then fill = C.pink
    elseif kind == "cyan" then fill = C.cyan
    elseif kind == "yellow" then fill = C.yellow
    elseif kind == "red" then fill = C.red end

    local inner = math.floor((w - 4) * value + 0.5)
    if inner > 1 then
        NLUI.roundedRect(panel, x + 2, y + 2, inner, h - 4, fill, 1)
        rect(panel, x + 5, y + 3, math.max(0, inner - 8), math.max(1, math.floor((h - 4) / 3)),
            C.buttonShine, 0.28)
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
    elseif kind == "bad" then fill = C.red
    elseif kind == "romance" then fill = C.pink
    elseif kind == "accent" or kind == "info" then fill = C.chromeBright
    elseif kind == "neutral" then fill = C.buttonGhostEdge
    end
    NLUI.roundedRect(panel, x, y, w, 22, fill, 1)
    NLUI.roundedRect(panel, x + 3, y + 2, w - 6, 7, C.buttonShine, 0.26)
    if panel.drawText then
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
    local pillHeight = 20
    local tm = getTextManager and getTextManager()

    for _, trait in ipairs(traits) do
        local textW = tm and tm.MeasureStringX and tm:MeasureStringX(UIFont.Small, trait) or (#trait * 7)
        local pillW = math.max(38, textW + 16)
        if (curX + pillW) > (x + maxWidth) and curX > x then
            curX = x
            curY = curY + pillHeight + 4
        end
        NLUI.roundedRect(panel, curX, curY, pillW, pillHeight, C.chromeSoft, 0.90)
        NLUI.roundedRect(panel, curX + 1, curY + 1, pillW - 2, pillHeight - 2, C.surfaceLift, 0.95)
        NLUI.roundedRect(panel, curX + 2, curY + 2, pillW - 4, 4, C.buttonShine, 0.35)
        if panel.drawText then
            panel:drawText(trait, curX + 8, curY + 3, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        end
        curX = curX + pillW + 6
    end
    return curY + pillHeight
end

function NLUI.drawPlumbob(panel, cx, cy, size, alpha)
    if not panel then return end
    alpha = alpha or 1
    local halfW = math.floor(size * 0.35)
    local halfH = math.floor(size * 0.5)

    -- Left upper facet
    rect(panel, cx - halfW, cy - math.floor(halfH * 0.3), halfW, math.floor(halfH * 0.8), C.plumbobGreen, alpha)
    -- Right upper facet (highlight)
    rect(panel, cx, cy - math.floor(halfH * 0.3), halfW, math.floor(halfH * 0.8), C.plumbobGreenLight, alpha)
    -- Lower facet
    rect(panel, cx - math.floor(halfW * 0.7), cy + math.floor(halfH * 0.5), math.floor(halfW * 1.4), math.floor(halfH * 0.5), C.plumbobGreenDark, alpha)
    -- Center shine
    rect(panel, cx - 1, cy - math.floor(halfH * 0.2), 2, math.floor(halfH * 1.1), C.buttonShine, alpha * 0.6)
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
