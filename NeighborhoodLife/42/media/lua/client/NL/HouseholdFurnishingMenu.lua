-- World-object actions for the server-authoritative household storage fixture.
-- The menu is only offered for the production object's identity marker; the
-- server still validates membership, proximity, item type and quantity.
NLHouseholdFurnishingMenu = {}

local function isStorageObject(object)
    if not object or not object.getModData then return false end
    local ok, data = pcall(object.getModData, object)
    return ok and data and data.NeighborhoodHouseholdFurnishing == "storage"
end

function NLHouseholdFurnishingMenu.request(player, action)
    if not player or player:isDead() or not NLHouseholdClient then return end
    NLHouseholdClient.request(player:getPlayerNum(), "furnishing", {
        action = action, item = "Base.RippedSheets", amount = 1,
    })
end

function NLHouseholdFurnishingMenu.menu(index, context, worldobjects)
    local player = getSpecificPlayer(index)
    if not player or player:isDead() then return end
    local found = false
    for _, object in ipairs(worldobjects or {}) do
        if isStorageObject(object) then found = true; break end
    end
    if not found then return end
    local option = context:addOption("Household storage", player,
        NLHouseholdFurnishingMenu.open)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)
    sub:addOption("Store 1 Ripped Sheet", player,
        NLHouseholdFurnishingMenu.request, "store")
    sub:addOption("Take 1 Ripped Sheet", player,
        NLHouseholdFurnishingMenu.request, "retrieve")
end

function NLHouseholdFurnishingMenu.open(player)
    if player then player:Say("Household storage") end
end

Events.OnFillWorldObjectContextMenu.Add(NLHouseholdFurnishingMenu.menu)
return NLHouseholdFurnishingMenu
