-- Client application of the server-authoritative appearance preset.
-- Presets refer to native Build 42 HumanVisual hair styles only.
NLAppearance = {}

local function preset(id)
    if NLDefinitions and NLDefinitions.appearancePresets then
        return NLDefinitions.appearancePresets[id]
    end
end

function NLAppearance.applyProfile(player, appearance)
    if not player or type(appearance) ~= "table" then return false end
    local id = tostring(appearance.preset or "natural")
    local selected = preset(id) or preset("natural")
    if not selected or not player.getHumanVisual then return false end
    local visualOk, visual = pcall(player.getHumanVisual, player)
    if not visualOk or not visual then return false end
    local femaleOk, female = pcall(visual.isFemale, visual)
    local hair = femaleOk and female and selected.femaleHair or selected.maleHair
    local applied = false
    if hair and visual.setHairModel then
        local hairOk = pcall(visual.setHairModel, visual, hair)
        applied = hairOk
    end
    if player.resetModelNextFrame then pcall(player.resetModelNextFrame, player) end
    if player.syncVisuals then pcall(player.syncVisuals, player) end
    if player.getModData then
        local dataOk, data = pcall(player.getModData, player)
        if dataOk and data then data.NeighborhoodAppearance = id end
    end
    return applied
end

function NLAppearance.label(id)
    local selected = preset(id or "natural") or preset("natural")
    return selected and selected.name or "Natural"
end

return NLAppearance
