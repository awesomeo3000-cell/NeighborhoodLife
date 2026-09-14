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
local inventoryFaultArmed = false

-- The crash probe supplies NLQAInventoryFaultMode through a temporary
-- server-only QA config file. It never exists in the production package.
Events.OnTick.Add(function()
    if inventoryFaultArmed or type(NLQAInventoryFaultMode) ~= "string"
            or not NLSocialAuthority then return end
    NLSocialAuthority.testFaultPhase=NLQAInventoryFaultMode
    inventoryFaultArmed=true
    print("NLQA INVENTORY FAULT ARMED: phase="..tostring(NLQAInventoryFaultMode))
end)

-- QA-only engine bridge probe.  Build 42 does not publish GameServer as a Lua
-- global on the dedicated server, but its native objects still carry a Java
-- class loader.  Try the public Java methods through that loader before
-- declaring native server-body reannouncement unavailable.  This probe never
-- enters the production mod package.
local function tryReflectiveNpcReannounce(players)
    if not NLNpcAuthority or not NLNpcAuthority.bodies then
        print("NLQA MP REFLECTION: npc-authority-unavailable")
        return 0
    end
    local source
    for _, id in ipairs({"marisol", "kenji", "amara"}) do
        if NLNpcAuthority.bodies[id] then
            source = NLNpcAuthority.bodies[id]
            break
        end
    end
    if not source then
        print("NLQA MP REFLECTION: no-native-npc-body")
        return 0
    end
    local classOk, bodyClass = pcall(function() return source:getClass() end)
    local nameOk, className = false, nil
    if classOk and bodyClass then nameOk, className = pcall(function() return bodyClass:getName() end) end
    local loaderOk, loader = false, nil
    if classOk and bodyClass then
        loaderOk, loader = pcall(function() return bodyClass:getClassLoader() end)
    end
    local serverClassOk, serverClass = false, nil
    if loaderOk and loader then
        serverClassOk, serverClass = pcall(function()
            return loader:loadClass("zombie.network.GameServer")
        end)
    end
    local connectionClassOk, connectionClass = false, nil
    if loaderOk and loader then
        connectionClassOk, connectionClass = pcall(function()
            return loader:loadClass("zombie.network.IConnection")
        end)
    end
    if classOk and bodyClass and not serverClassOk then
        serverClassOk, serverClass = pcall(function()
            return bodyClass:forName("zombie.network.GameServer")
        end)
    end
    if classOk and bodyClass and not connectionClassOk then
        connectionClassOk, connectionClass = pcall(function()
            return bodyClass:forName("zombie.network.IConnection")
        end)
    end
    print("NLQA MP REFLECTION: classOk=" .. tostring(classOk)
        .. " nameOk=" .. tostring(nameOk) .. " className=" .. tostring(className)
        .. " loaderOk=" .. tostring(loaderOk)
        .. " serverClassOk=" .. tostring(serverClassOk)
        .. " connectionClassOk=" .. tostring(connectionClassOk))
    if not loaderOk then print("NLQA MP REFLECTION LOADER ERROR: " .. tostring(loader)) end
    if not serverClassOk then print("NLQA MP REFLECTION SERVER CLASS ERROR: " .. tostring(serverClass)) end
    if not connectionClassOk then print("NLQA MP REFLECTION CONNECTION CLASS ERROR: " .. tostring(connectionClass)) end
    if not serverClassOk or not connectionClassOk or not serverClass or not connectionClass then
        return 0
    end
    local getConnectionOk, getConnection = pcall(function()
        return serverClass:getMethod("getConnectionFromPlayer", bodyClass)
    end)
    local sendConnectedOk, sendConnected = pcall(function()
        return serverClass:getMethod("sendPlayerConnected", bodyClass, connectionClass)
    end)
    print("NLQA MP REFLECTION METHODS: getConnectionOk=" .. tostring(getConnectionOk)
        .. " sendConnectedOk=" .. tostring(sendConnectedOk))
    if not getConnectionOk or not sendConnectedOk or not getConnection or not sendConnected then
        return 0
    end
    local sent = 0
    for targetIndex = 0, players:size() - 1 do
        local target = players:get(targetIndex)
        local connectionOk, connection = pcall(function()
            return getConnection:invoke(nil, target)
        end)
        if connectionOk and connection then
            local sendOk = pcall(function()
                return sendConnected:invoke(nil, source, connection)
            end)
            print("NLQA MP REFLECTION SEND: source=" .. tostring(source:getUsername())
                .. " target=" .. tostring(target:getUsername())
                .. " connectionOk=" .. tostring(connectionOk)
                .. " sendOk=" .. tostring(sendOk))
            if sendOk then sent = sent + 1 end
        else
            print("NLQA MP REFLECTION SEND: target=" .. tostring(target:getUsername())
                .. " connectionOk=" .. tostring(connectionOk)
                .. " connection=" .. tostring(connection))
        end
    end
    return sent
end

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
    if type(NLQAInventoryFaultMode)=="string" and world.inventoryJournal then
        print("NLQA INVENTORY FAULT: deferred career seed while journal is pending")
        return
    end
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
    -- Ten sheets leave one real client-acquired item for household storage
    -- after the production NPC give probe consumes one and medic delivery
    -- consumes eight.
    local amount = 10
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
        local onlineOk, onlinePlayers = false, nil
        if type(getOnlinePlayers) == "function" then
            onlineOk, onlinePlayers = pcall(getOnlinePlayers)
        end
        print("NLQA MP SERVER ONLINE PLAYERS FALLBACK: ok=" .. tostring(onlineOk)
            .. " players=" .. tostring(onlinePlayers))
        if not onlineOk or not onlinePlayers then return end
        players = onlinePlayers
    end
    print("NLQA MP SERVER GAME-SERVER API: players=" .. tostring(players:size()))
    if players:size() < 2 then return end
    local sent = 0
    if api and api.getConnectionFromPlayer and api.sendPlayerConnected then
        for sourceIndex = 0, players:size() - 1 do
            local source = players:get(sourceIndex)
            for targetIndex = 0, players:size() - 1 do
                local target = players:get(targetIndex)
                if source ~= target then
                    local connOk, connection = pcall(api.getConnectionFromPlayer, target)
                    if connOk and connection then
                        local sendOk = pcall(api.sendPlayerConnected, source, connection)
                        if sendOk then sent = sent + 1 end
                    end
                end
            end
        end
    end
    local reflectionOk, reflectiveSent = pcall(tryReflectiveNpcReannounce, players)
    if not reflectionOk then
        print("NLQA MP REFLECTION ERROR: " .. tostring(reflectiveSent))
        reflectiveSent = 0
    end
    reannounced = true
    print("NLQA MP SERVER REANNOUNCE: players=" .. tostring(players:size())
        .. " sent=" .. tostring(sent) .. " reflectiveNpcSent=" .. tostring(reflectiveSent))
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
