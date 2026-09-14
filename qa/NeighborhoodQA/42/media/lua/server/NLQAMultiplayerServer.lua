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

Events.OnClientCommand.Add(function(module, command, player)
    if module ~= "NeighborhoodQA" or command ~= "reset_household" or not player
            or player:getUsername() ~= "nl-host" then return end
    local world = NLAuthority.world()
    for _, username in ipairs({"nl-host", "nl-guest"}) do
        local profile = NLDomain.profile(world, username)
        profile.householdId, profile.householdInvite = nil, nil
        profile.claimed = {}
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
