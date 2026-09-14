-- QA-only server observer. It records that the real client command reached the
-- production authority; it does not implement gameplay or alter the package.
NLQAMultiplayerServer = true
if isClient() then return end
local ok,err=pcall(function() require "NL/Authority" end)
print("NLQA MP SERVER BOOT: authority=" .. tostring(NLAuthority ~= nil) .. " requireOk=" .. tostring(ok)
    .. " error=" .. tostring(err))
for _, name in ipairs({"getClass", "importClass", "Java", "luautils", "GameServer", "GameClient"}) do
    print("NLQA MP SERVER BRIDGE: " .. name .. "=" .. tostring(type(_G[name])))
end
if type(luautils) == "table" then
    local names = {}
    for name, _ in pairs(luautils) do names[#names + 1] = tostring(name) end
    table.sort(names)
    print("NLQA MP SERVER BRIDGE: luautilsKeys=" .. table.concat(names, ","))
end
if type(getClass) == "function" then
    local classOk, classValue = pcall(getClass, "zombie.network.GameServer")
    print("NLQA MP SERVER BRIDGE: getClass(GameServer) ok=" .. tostring(classOk)
        .. " value=" .. tostring(classValue))
end
local reannounced = false
local careerSeeded = {}
local wardrobeSeeded = {}
local householdViewpointMoved = false

-- QA-only viewpoint setup: after the real invite/accept flow, place the guest
-- at the shared home so the production client can exercise streamed-in tile
-- retry without mouse or keyboard input. This does not enter the mod package.
Events.OnTick.Add(function()
    if householdViewpointMoved or type(getOnlinePlayers) ~= "function" then return end
    if not careerSeeded["nl-host"] then return end
    local world = NLAuthority and NLAuthority.world()
    local household = world and world.households and world.households["home:nl-host"]
    if not household or not household.members or not household.members["nl-guest"] then return end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return end
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and player:getUsername() == "nl-guest" then
            local square = getCell():getGridSquare(household.home.x, household.home.y, household.home.z)
            if square then
                player:setX(household.home.x + 0.5)
                player:setY(household.home.y + 0.5)
                if player.setZ then player:setZ(household.home.z) end
                player:setCurrent(square)
                householdViewpointMoved = true
                sendServerCommand(player, "NeighborhoodQA", "household_viewpoint", {
                    x = household.home.x, y = household.home.y, z = household.home.z,
                })
                print("NLQA HOUSEHOLD VIEWPOINT: guest loaded shared home tile x="
                    .. tostring(household.home.x) .. " y=" .. tostring(household.home.y)
                    .. " z=" .. tostring(household.home.z))
            end
            return
        end
    end
end)

Events.OnClientCommand.Add(function(module, command, player)
    if module ~= "NeighborhoodQA" or command ~= "reset_household" or not player
            or player:getUsername() ~= "nl-host" then return end
    local world = NLAuthority.world()
    for _, username in ipairs({"nl-host", "nl-guest"}) do
        local profile = NLDomain.profile(world, username)
        profile.householdId, profile.householdInvite = nil, nil
        profile.claimed = {}
    end
    for _, household in pairs(world.households or {}) do
        if NLHouseholdFurnishings then NLHouseholdFurnishings.remove(household) end
    end
    world.households = {}
    print("NLQA HOUSEHOLD RESET: isolated host and guest household state cleared")
end)

-- QA-only server fixture: seed real world inventory on the host, then let the
-- client acquire it through vanilla's networked transfer action before the
-- production career command consumes it. This does not modify the production
-- mod or fake the delivery response.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "NeighborhoodQA" or command ~= "seed_inventory" or not player then return end
    local username = player:getUsername()
    if username ~= "nl-host" or careerSeeded[username] then return end
    local world = NLAuthority.world()
    for _, qaUsername in ipairs({"nl-host", "nl-guest"}) do
        local profile = NLDomain.profile(world, qaUsername)
        profile.householdId, profile.householdInvite = nil, nil
        profile.claimed = {}
    end
    for _, household in pairs(world.households or {}) do
        if NLHouseholdFurnishings then NLHouseholdFurnishings.remove(household) end
    end
    world.households = {}
    print("NLQA HOUSEHOLD RESET: career fixture cleared persisted household and claims")
    local item = "Base.RippedSheets"
    -- Nine sheets leave one real client-acquired item for the household
    -- storage deposit after the medic delivery consumes eight.
    local amount = 9
    local square = player:getCurrentSquare()
    if not square then
        print("NLQA CAREER SEED FAILED: username="..tostring(username).." reason=no-current-square")
        return
    end
    local inventory = player:getInventory()
    local existing = inventory and inventory:getItems()
    if existing then
        for index=existing:size()-1,0,-1 do
            local oldItem = existing:get(index)
            if oldItem and oldItem:getFullType() == item then
                inventory:Remove(oldItem)
                sendRemoveItemFromContainer(inventory, oldItem)
            end
        end
    end
    local worldObjects = square:getWorldObjects()
    if worldObjects then
        for index=worldObjects:size()-1,0,-1 do
            local worldObject = worldObjects:get(index)
            local oldItem = worldObject and worldObject:getItem()
            if oldItem and oldItem:getFullType() == item then
                square:transmitRemoveItemFromSquare(worldObject)
            end
        end
    end
    for index=1,amount do
        square:AddWorldInventoryItem(item, 0.25 + (index * 0.07), 0.50, 0.0)
    end
    careerSeeded[username] = true
    print("NLQA CAREER WORLD SEED: username="..tostring(username).." item="..item
        .." amount="..amount.." square="..tostring(square:getX())..","..tostring(square:getY())
        ..","..tostring(square:getZ()))
    sendServerCommand(player,"NeighborhoodQA","career_seeded",{item=item,amount=amount,mode="world"})
end)

-- QA-only clothing fixture: place real vanilla garments in the current square
-- so the host acquires them through the networked world-transfer action and
-- equips them through the production ISWearClothing path.
Events.OnClientCommand.Add(function(module, command, player)
    if module ~= "NeighborhoodQA" or command ~= "seed_wardrobe" or not player
            or player:getUsername() ~= "nl-host" or wardrobeSeeded["nl-host"] then return end
    local square = player:getCurrentSquare()
    if not square then
        print("NLQA WARDROBE SEED FAILED: username=nl-host reason=no-current-square")
        return
    end
    local items = {"Base.Shirt_FormalWhite", "Base.Trousers_Denim"}
    local worldObjects = square:getWorldObjects()
    if worldObjects then
        for index=worldObjects:size()-1,0,-1 do
            local worldObject = worldObjects:get(index)
            local oldItem = worldObject and worldObject:getItem()
            if oldItem and (oldItem:getFullType() == items[1] or oldItem:getFullType() == items[2]) then
                square:transmitRemoveItemFromSquare(worldObject)
            end
        end
    end
    for index, item in ipairs(items) do
        square:AddWorldInventoryItem(item, 0.25 + (index * 0.20), 0.50, 0.0)
    end
    wardrobeSeeded["nl-host"] = true
    print("NLQA WARDROBE WORLD SEED: username=nl-host items=" .. table.concat(items, ",")
        .. " square=" .. tostring(square:getX()) .. "," .. tostring(square:getY())
        .. "," .. tostring(square:getZ()))
    sendServerCommand(player, "NeighborhoodQA", "wardrobe_seeded", {items=items})
end)

local function tryReannounce()
    if reannounced then return end
    local apiOk, api = pcall(function() return GameServer end)
    local playersOk, players = false, nil
    if apiOk and api then
        playersOk, players = pcall(function() return api.Players end)
    end
    print("NLQA MP SERVER GAME-SERVER API: api=" .. tostring(api)
        .. " apiOk=" .. tostring(apiOk) .. " playersOk=" .. tostring(playersOk)
        .. " players=" .. tostring(players))
    if not playersOk or not players then
        return
    end
    print("NLQA MP SERVER GAME-SERVER API: players=" .. tostring(players:size()))
    if players:size() < 2 then return end
    local sent = 0
    for sourceIndex = 0, players:size() - 1 do
        local source = players:get(sourceIndex)
        for targetIndex = 0, players:size() - 1 do
            local target = players:get(targetIndex)
            if source ~= target then
                local connOk, connection = pcall(GameServer.getConnectionFromPlayer, target)
                if connOk and connection then
                    local sendOk = pcall(GameServer.sendPlayerConnected, source, connection)
                    if sendOk then sent = sent + 1 end
                end
            end
        end
    end
    reannounced = true
    print("NLQA MP SERVER REANNOUNCE: players=" .. tostring(players:size()) .. " sent=" .. tostring(sent))
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "NeighborhoodLife" and command == "refresh" and player then
        print("NLQA MP SERVER COMMAND: refresh username=" .. tostring(player:getUsername()))
        print("NLQA MP SERVER PLAYER: dead=" .. tostring(player:isDead())
            .. " authorityKey=" .. tostring(NLAuthority.key(player))
            .. " argsType=" .. tostring(type(args)))
        tryReannounce()
    end
end)
