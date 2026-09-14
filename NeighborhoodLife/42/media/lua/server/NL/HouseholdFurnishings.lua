-- Native Build 42 furnishing for the authoritative household storage.
-- The household record owns the identity and tile; the IsoObject is the
-- visible, networked world representation at that tile.
if isClient() then return end

NLHouseholdFurnishings = {
    sprite = "furniture_storage_02_19",
    objectName = "NeighborhoodHouseholdStorage",
}

local function emit(message)
    if NLQAMultiplayerServer then
        print("NLQA HOUSEHOLD FURNISHING: " .. tostring(message))
    end
end

local function squareFor(furnishing)
    if not furnishing or not getCell then return nil end
    local ok, cell = pcall(getCell)
    if not ok or not cell then return nil end
    return cell:getGridSquare(furnishing.x, furnishing.y, furnishing.z)
end

local function matches(object, householdId)
    if not object or not object.getModData then return false end
    local ok, data = pcall(object.getModData, object)
    return ok and data and data.NeighborhoodHouseholdId == householdId
end

local function findIn(square, householdId)
    if not square then return nil end
    for _, method in ipairs({ "getObjects", "getSpecialObjects" }) do
        local getter = square[method]
        if getter then
            local ok, list = pcall(getter, square)
            if ok and list and list.size and list.get then
                for i = 0, list:size() - 1 do
                    local item = list:get(i)
                    if matches(item, householdId) then return item end
                end
            end
        end
    end
    return nil
end

local function record(household, square, object)
    household.furnishing = {
        kind = "storage",
        x = square:getX(), y = square:getY(), z = square:getZ(),
        sprite = NLHouseholdFurnishings.sprite,
    }
    local data = object:getModData()
    data.NeighborhoodHouseholdId = household.id
    data.NeighborhoodHouseholdFurnishing = "storage"
    data.NeighborhoodHouseholdSprite = NLHouseholdFurnishings.sprite
    return object
end

function NLHouseholdFurnishings.find(household)
    return household and findIn(squareFor(household.furnishing), household.id) or nil
end

function NLHouseholdFurnishings.isNearby(household, player, radius)
    if not household or not player then return false end
    local furnishing = household.furnishing or household.home
    if not furnishing or not player.getX or not player.getY then return false end
    local z = math.floor(tonumber(player.getZ and player:getZ() or 0) or 0)
    if z ~= math.floor(tonumber(furnishing.z) or 0) then return false end
    local dx = player:getX() - (tonumber(furnishing.x) or 0)
    local dy = player:getY() - (tonumber(furnishing.y) or 0)
    local range = tonumber(radius) or 4.0
    return dx * dx + dy * dy <= range * range
end

function NLHouseholdFurnishings.ensure(household)
    if not household or not household.home then emit("SKIP reason=no-household-home"); return nil end
    if not IsoObject then emit("SKIP reason=IsoObject-unavailable"); return nil end
    local furnishing = household.furnishing or household.home
    local square = squareFor(furnishing)
    if not square then emit("SKIP reason=no-square x=" .. tostring(furnishing.x)
        .. " y=" .. tostring(furnishing.y) .. " z=" .. tostring(furnishing.z)); return nil end
    local existing = findIn(square, household.id)
    if existing then
        emit("REUSED household=" .. tostring(household.id) .. " x=" .. tostring(square:getX())
            .. " y=" .. tostring(square:getY()) .. " z=" .. tostring(square:getZ()))
        record(household, square, existing)
        return existing
    end
    local cell = getCell and getCell() or nil
    local ok, object
    if IsoObject.getNew then
        ok, object = pcall(IsoObject.getNew, square, NLHouseholdFurnishings.sprite,
            NLHouseholdFurnishings.objectName, false)
    end
    if not ok or not object then
        ok, object = pcall(IsoObject.new, square, NLHouseholdFurnishings.sprite,
            NLHouseholdFurnishings.objectName)
    end
    if (not ok or not object) and cell then
        ok, object = pcall(IsoObject.new, cell, square, NLHouseholdFurnishings.sprite,
            NLHouseholdFurnishings.objectName)
    end
    if not ok or not object then
        emit("SKIP reason=IsoObject-new-failed square=" .. tostring(square:getX())
            .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ()))
        return nil
    end
    record(household, square, object)
    if object.setSpecialTooltip then object:setSpecialTooltip(true) end
    if object.setName then pcall(object.setName, object, NLHouseholdFurnishings.objectName) end
    -- This native API both adds the object and emits the Build 42 object packet.
    -- Calling AddTileObject first makes transmitAddObjectToSquare return early.
    local transmitted = false
    if square.transmitAddObjectToSquare then
        local index = 0
        if square.getObjects then
            local objects = square:getObjects()
            if objects and objects.size then index = objects:size() - 1 end
        end
        pcall(square.transmitAddObjectToSquare, square, object, index)
        transmitted = true
    elseif square.AddTileObject then
        pcall(square.AddTileObject, square, object)
    end
    if not transmitted and object.transmitCompleteItemToClients then
        pcall(object.transmitCompleteItemToClients, object)
    end
    household.revision = (household.revision or 0) + 1
    emit("CREATED household=" .. tostring(household.id) .. " kind=storage x="
        .. tostring(square:getX()) .. " y=" .. tostring(square:getY()) .. " z="
        .. tostring(square:getZ()))
    return object
end

function NLHouseholdFurnishings.remove(household)
    local object = NLHouseholdFurnishings.find(household)
    if object and object.getSquare then
        local square = object:getSquare()
        if square and square.transmitRemoveItemFromSquare then
            square:transmitRemoveItemFromSquare(object)
        end
        if square and square.RemoveTileObject then square:RemoveTileObject(object) end
    end
    if household then household.furnishing = nil end
end

function NLHouseholdFurnishings.reconcile(world)
    local count = 0
    for _, household in pairs((world and world.households) or {}) do
        if NLHouseholdFurnishings.ensure(household) then count = count + 1 end
    end
    return count
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        if NLAuthority then NLHouseholdFurnishings.reconcile(NLAuthority.world()) end
    end)
end

return NLHouseholdFurnishings
