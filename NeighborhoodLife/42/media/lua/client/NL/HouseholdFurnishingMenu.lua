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
    return NLHouseholdFurnishingMenu.requestItem(player, action, "Base.RippedSheets", 1)
end

function NLHouseholdFurnishingMenu.requestItem(player, action, itemType, amount)
    if not player or player:isDead() or not NLHouseholdClient then return end
    NLHouseholdClient.request(player:getPlayerNum(), "furnishing", {
        action = action, item = itemType, amount = amount or 1,
    })
end

local function inventoryTypes(player)
    local result, seen = {}, {}
    local inventory = player and player.getInventory and player:getInventory()
    local items = inventory and inventory.getItems and inventory:getItems()
    if not items then result[1] = "Base.RippedSheets"; return result end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and item:getFullType()
        local equipped = false
        if player.isEquipped and item then
            local ok, value = pcall(player.isEquipped, player, item)
            equipped = ok and value == true
        end
        if fullType and not equipped and not seen[fullType] then
            seen[fullType] = true; result[#result + 1] = fullType
        end
    end
    table.sort(result)
    if #result == 0 then result[1] = "Base.RippedSheets" end
    return result
end

local function storedTypes(index)
    local result, seen = {}, {}
    local state = NLHouseholdClient and NLHouseholdClient.snapshots
        and NLHouseholdClient.snapshots[index]
    local storage = state and state.household and state.household.storage or {}
    for itemType, amount in pairs(storage or {}) do
        if tonumber(amount) and tonumber(amount) > 0 and not seen[itemType] then
            seen[itemType] = true; result[#result + 1] = itemType
        end
    end
    table.sort(result)
    return result
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
    for _, itemType in ipairs(inventoryTypes(player)) do
        sub:addOption("Store 1 " .. itemType, player,
            NLHouseholdFurnishingMenu.requestItem, "store", itemType, 1)
    end
    local stored = storedTypes(index)
    if #stored == 0 then
        sub:addOption("Take 1 Ripped Sheet", player,
            NLHouseholdFurnishingMenu.request, "retrieve")
    else
        for _, itemType in ipairs(stored) do
            sub:addOption("Take 1 " .. itemType, player,
                NLHouseholdFurnishingMenu.requestItem, "retrieve", itemType, 1)
        end
    end
end

function NLHouseholdFurnishingMenu.open(player)
    if player then player:Say("Household storage") end
end

Events.OnFillWorldObjectContextMenu.Add(NLHouseholdFurnishingMenu.menu)
return NLHouseholdFurnishingMenu
