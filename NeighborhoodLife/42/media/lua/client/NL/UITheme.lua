NLUI = NLUI or {}

NLUI.colors = {
    shadow = { r=0.01, g=0.04, b=0.08, a=0.42 },
    frameDark = { r=0.02, g=0.20, b=0.38, a=0.98 },
    frameMid = { r=0.03, g=0.36, b=0.63, a=0.98 },
    frameLight = { r=0.10, g=0.56, b=0.84, a=1.00 },
    headerTop = { r=0.18, g=0.66, b=0.92, a=1.00 },
    headerBottom = { r=0.04, g=0.38, b=0.69, a=1.00 },
    well = { r=0.82, g=0.92, b=0.97, a=0.98 },
    wellAlt = { r=0.70, g=0.86, b=0.94, a=0.98 },
    wellDark = { r=0.51, g=0.74, b=0.86, a=0.98 },
    borderLight = { r=0.69, g=0.92, b=1.00, a=1.00 },
    borderDark = { r=0.02, g=0.21, b=0.40, a=1.00 },
    textLight = { r=0.98, g=1.00, b=1.00, a=1.00 },
    textDark = { r=0.04, g=0.18, b=0.29, a=1.00 },
    muted = { r=0.23, g=0.39, b=0.49, a=1.00 },
    button = { r=0.08, g=0.45, b=0.74, a=1.00 },
    buttonHover = { r=0.17, g=0.63, b=0.89, a=1.00 },
    buttonActive = { r=0.03, g=0.32, b=0.61, a=1.00 },
    buttonBorder = { r=0.65, g=0.91, b=1.00, a=1.00 },
    close = { r=0.57, g=0.17, b=0.20, a=1.00 },
    closeHover = { r=0.78, g=0.25, b=0.27, a=1.00 },
    track = { r=0.38, g=0.55, b=0.64, a=1.00 },
    green = { r=0.25, g=0.78, b=0.30, a=1.00 },
    yellow = { r=0.94, g=0.70, b=0.19, a=1.00 },
    red = { r=0.84, g=0.22, b=0.23, a=1.00 },
    pink = { r=0.84, g=0.33, b=0.62, a=1.00 },
    cyan = { r=0.17, g=0.72, b=0.88, a=1.00 },
}

local C = NLUI.colors

local function rect(panel, x, y, w, h, color, alpha)
    if not panel or not panel.drawRect or w <= 0 or h <= 0 then return end
    panel:drawRect(x, y, w, h, alpha or color.a or 1, color.r, color.g, color.b)
end

local function border(panel, x, y, w, h, color)
    if not panel or w <= 0 or h <= 0 then return end
    if panel.drawRectBorder then
        panel:drawRectBorder(x, y, w, h, color.a or 1, color.r, color.g, color.b)
        return
    end
    rect(panel, x, y, w, 1, color)
    rect(panel, x, y+h-1, w, 1, color)
    rect(panel, x, y, 1, h, color)
    rect(panel, x+w-1, y, 1, h, color)
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
    kind = kind or "primary"
    if kind == "close" then
        button.backgroundColor = C.close
        button.backgroundColorMouseOver = C.closeHover
    elseif active then
        button.backgroundColor = C.buttonActive
        button.backgroundColorMouseOver = C.buttonHover
    else
        button.backgroundColor = C.button
        button.backgroundColorMouseOver = C.buttonHover
    end
    button.borderColor = C.buttonBorder
    button.textColor = C.textLight
    return button
end

function NLUI.setButtonActive(button, active)
    return NLUI.styleButton(button, "primary", active == true)
end

function NLUI.window(panel, title, subtitle)
    if not panel then return end
    local w, h = panel.width or 0, panel.height or 0
    rect(panel, 5, 6, w-2, h-2, C.shadow)
    rect(panel, 0, 0, w, h, C.frameDark)
    rect(panel, 3, 3, w-6, h-6, C.frameMid)
    rect(panel, 6, 6, w-12, 42, C.headerBottom)
    rect(panel, 7, 7, w-14, 19, C.headerTop)
    rect(panel, 8, 49, w-16, h-57, C.well)
    border(panel, 0, 0, w, h, C.borderDark)
    border(panel, 4, 4, w-8, h-8, C.borderLight)
    if panel.drawText and title then
        panel:drawText(title, 16, 13, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)
    end
    if panel.drawText and subtitle and subtitle ~= "" then
        panel:drawText(subtitle, 16, 31, 0.80, 0.94, 1.00, 1, UIFont.Small)
    end
end

function NLUI.well(panel, x, y, w, h, label, alternate)
    local fill = alternate and C.wellAlt or C.well
    rect(panel, x, y, w, h, C.borderDark)
    rect(panel, x+2, y+2, w-4, h-4, fill)
    border(panel, x+2, y+2, w-4, h-4, C.borderLight)
    if label and panel.drawText then
        rect(panel, x+3, y+3, w-6, 23, C.frameMid)
        rect(panel, x+4, y+4, w-8, 10, C.frameLight)
        panel:drawText(label, x+12, y+7, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)
    end
end

function NLUI.progress(panel, x, y, w, h, value, kind)
    value = NLUI.clamp(value, 0, 1)
    rect(panel, x, y, w, h, C.borderDark)
    rect(panel, x+2, y+2, w-4, h-4, C.track)
    local fill = C.green
    if kind == "pink" then fill = C.pink
    elseif kind == "cyan" then fill = C.cyan
    elseif kind == "yellow" then fill = C.yellow
    elseif kind == "red" then fill = C.red end
    local inner = math.floor((w-4) * value + 0.5)
    if inner > 0 then rect(panel, x+2, y+2, inner, h-4, fill) end
    rect(panel, x+2, y+2, math.max(0, inner), math.max(1, math.floor((h-4)/3)), C.textLight, 0.22)
end

function NLUI.needColor(value)
    value = NLUI.clamp(value, 0, 1)
    if value >= 0.70 then return "red" end
    if value >= 0.35 then return "yellow" end
    return "green"
end

function NLUI.pill(panel, x, y, w, text, kind)
    local fill = kind == "good" and C.green or kind == "warn" and C.yellow
        or kind == "bad" and C.red or C.frameMid
    rect(panel, x, y, w, 20, C.borderDark)
    rect(panel, x+1, y+1, w-2, 18, fill)
    if panel.drawText then
        panel:drawText(text or "", x+7, y+3, C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)
    end
end

function NLUI.monogram(panel, x, y, size, name)
    rect(panel, x, y, size, size, C.borderDark)
    rect(panel, x+3, y+3, size-6, size-6, C.wellDark)
    rect(panel, x+7, y+7, size-14, size-14, C.frameMid)
    local initial = tostring(name or "?"):sub(1,1):upper()
    if panel.drawText then
        panel:drawText(initial, x+math.floor(size*0.42), y+math.floor(size*0.36),
            C.textLight.r, C.textLight.g, C.textLight.b, 1, UIFont.Small)
    end
end

function NLUI.metric(panel, label, valueText, x, y, w, value, kind)
    if panel.drawText then
        panel:drawText(label, x, y, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        panel:drawText(valueText or "", x+w-44, y, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
    end
    NLUI.progress(panel, x, y+18, w, 12, value, kind)
end

return NLUI
