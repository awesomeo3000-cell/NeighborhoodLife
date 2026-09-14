-- Client-side world representation for the server-authoritative household
-- furnishing. Build 42.20.4 does not consistently replicate a Lua-created
-- IsoObject from a dedicated server, so this creates the same native tile
-- object locally from the revisioned household snapshot.
if not isClient or not isClient() then return end

NLHouseholdFurnishingClient = { objects = {}, pending = {} }

local function existing(square, householdId)
    if not square or not square.getObjects then return nil end
    local ok, objects = pcall(square.getObjects, square)
    if not ok or not objects then return nil end
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object and object.getModData then
            local data = object:getModData()
            if data and data.NeighborhoodHouseholdId == householdId then return object end
        end
    end
end

local function applyLoaded(household)
    if not household or not household.id or not household.furnishing then return nil end
    local furnishing = household.furnishing
    local cell = getCell and getCell()
    local square = cell and cell:getGridSquare(furnishing.x, furnishing.y, furnishing.z)
    if not square then return nil end
    local object = existing(square, household.id)
    if not object and IsoObject and getSprite then
        local ok, created = pcall(IsoObject.new, cell, square,
            getSprite(furnishing.sprite or "furniture_storage_02_19"))
        if ok then object = created end
        if object then
            object:setName("NeighborhoodHouseholdStorage")
            local data = object:getModData()
            data.NeighborhoodHouseholdId = household.id
            data.NeighborhoodHouseholdFurnishing = furnishing.kind or "storage"
            data.NeighborhoodHouseholdSprite = furnishing.sprite
            if square.AddTileObject then square:AddTileObject(object) end
            if object.resetModelNextFrame then object:resetModelNextFrame() end
        end
    end
    if object then
        NLHouseholdFurnishingClient.objects[household.id] = object
        NLHouseholdFurnishingClient.pending[household.id] = nil
    end
    return object
end

function NLHouseholdFurnishingClient.apply(household)
    if not household or not household.id or not household.furnishing then return nil end
    local object = applyLoaded(household)
    if not object then
        NLHouseholdFurnishingClient.pending[household.id] = household
    end
    return object
end

function NLHouseholdFurnishingClient.clear()
    for id, object in pairs(NLHouseholdFurnishingClient.objects) do
        local square = object and object.getSquare and object:getSquare()
        if square and square.RemoveTileObject then square:RemoveTileObject(object) end
        NLHouseholdFurnishingClient.objects[id] = nil
    end
    NLHouseholdFurnishingClient.pending = {}
end

Events.OnMainMenuEnter.Add(NLHouseholdFurnishingClient.clear)
if Events.OnDisconnect then Events.OnDisconnect.Add(NLHouseholdFurnishingClient.clear) end
if Events.OnTick then
    Events.OnTick.Add(function()
        for _, household in pairs(NLHouseholdFurnishingClient.pending) do
            applyLoaded(household)
        end
    end)
end
return NLHouseholdFurnishingClient
