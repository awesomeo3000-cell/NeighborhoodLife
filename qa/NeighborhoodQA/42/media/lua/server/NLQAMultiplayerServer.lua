-- QA-only server observer. It records that the real client command reached the
-- production authority; it does not implement gameplay or alter the package.
NLQAMultiplayerServer = true
if isClient() then return end
pcall(require, "NLQANativeRosterConfig")
pcall(require, "NLQANpcMovementConfig")
pcall(require, "NLQAPartnershipConfig")
local ok,err=pcall(function() require "NL/Authority" end)
print("NLQA MP SERVER BOOT: authority=" .. tostring(NLAuthority ~= nil) .. " requireOk=" .. tostring(ok)
    .. " error=" .. tostring(err))
for _, name in ipairs({"getClass", "importClass", "Java", "luautils", "GameServer", "GameClient",
    "addZombiesInOutfit", "createZombie", "IsoZombie", "IsoDirections"}) do
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
local wardrobeExtraSeeded = {}
local dangerProbeSeeded = false
local householdViewpointMoved = false
local inventoryFaultArmed = false
local householdRestartProbeSent = false
local nativeRosterProbeDone = false
local nativeBridgeProbeDone = false
local partnershipProbeSeeded = false
local partnershipSnapshotAttempts = 0
local npcMovementSampleTick = 0

-- QA-only observer for the production movement heartbeat. The coordinates
-- come from the real server-native bodies; this observer never changes them.
Events.OnTick.Add(function()
    if NLQANpcMovementProbe ~= true or not NLNpcAuthority
            or not NLNpcAuthority.started then return end
    npcMovementSampleTick = npcMovementSampleTick + 1
    if npcMovementSampleTick % 60 ~= 0 then return end
    local rows = {}
    for _, id in ipairs({"marisol", "kenji", "amara"}) do
        local body = NLNpcAuthority.bodies[id]
        if body then
            rows[#rows + 1] = string.format("%s=%.2f,%.2f,%.0f", id,
                body:getX(), body:getY(), body:getZ())
        end
    end
    if #rows > 0 then print("NLQA NPC MOTION SAMPLE: " .. table.concat(rows, " ")) end
end)

-- QA-only relationship fixture. It gives the host the exact progression
-- prerequisites for the production partner command, then leaves the command,
-- snapshot, event and rejection paths entirely authoritative.
Events.OnTick.Add(function()
    if partnershipProbeSeeded or NLQAPartnershipProbe ~= true
            or not NLNpcAuthority or not NLNpcAuthority.started
            or type(getOnlinePlayers) ~= "function" then return end
    local listOk, players = pcall(getOnlinePlayers)
    if not listOk or not players then return end
    local host
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and player:getUsername() == "nl-host" then host = player; break end
    end
    if not host then return end
    local world = NLAuthority.world()
    local profile = NLDomain.profile(world, "nl-host")
    local relation = NLSocial.relation(profile, "marisol")
    relation.met = true
    relation.friendship = 40
    relation.trust = 30
    relation.attraction = 30
    relation.dates = 2
    relation.status = "Friend"
    relation.lastAction = -100
    profile.revision = profile.revision + 1
    -- Both accounts know the NPC before the guest attempts the same command;
    -- this makes the observed rejection come from the persisted partnership
    -- guard rather than the earlier "Introduce yourself first" gate.
    local guestProfile = NLDomain.profile(world, "nl-guest")
    local guestRelation = NLSocial.relation(guestProfile, "marisol")
    guestRelation.met = true
    guestRelation.friendship = 5
    guestRelation.trust = 2
    guestRelation.status = "Acquaintance"
    guestRelation.lastAction = -100
    guestProfile.revision = guestProfile.revision + 1
    partnershipProbeSeeded = true
    sendServerCommand(host, "NeighborhoodQA", "partnership_seeded", {target="marisol"})
    print("NLQA PARTNERSHIP SEED: target=marisol dates=2 trust=30 attraction=30 friendship=40")
end)

-- Some no-Steam Build 42 clients can drop a server command sent in the same
-- frame as the interaction event. Re-issue the production social snapshot
-- for the guest on later server ticks; the QA layer adds no relationship data.
Events.OnTick.Add(function()
    if NLQAPartnershipProbe ~= true or partnershipSnapshotAttempts >= 12
            or type(getOnlinePlayers) ~= "function" then return end
    local world = NLAuthority.world()
    local npc = world.neighbors and world.neighbors.marisol
    if not npc or npc.partner ~= "nl-host" then return end
    local listOk, players = pcall(getOnlinePlayers)
    if not listOk or not players then return end
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and player:getUsername() == "nl-guest" then
            NLSocialAuthority.snapshot(player, "partnership probe refresh")
            partnershipSnapshotAttempts = partnershipSnapshotAttempts + 1
            print("NLQA PARTNERSHIP SNAPSHOT RETRY: guest=nl-guest attempt="
                ..tostring(partnershipSnapshotAttempts))
            return
        end
    end
end)

-- These helpers are QA-only. They seed genuine Item instances in the host's
-- networked inventory so the production household authority must capture and
-- restore instance metadata during the probe.
local function qaSetItemValue(item, method, value)
    if not item or value == nil then return end
    local ok, fn = pcall(function() return item[method] end)
    if ok and fn then pcall(fn, item, value) end
end

local function qaItemValue(item, method)
    if not item then return nil end
    local ok, fn = pcall(function() return item[method] end)
    if not ok or not fn then return nil end
    local valueOk, value = pcall(fn, item)
    return valueOk and value or nil
end

local function qaSetFluidFraction(item, fraction)
    local container = qaItemValue(item, "getFluidContainer")
    if not container then return false end
    local ok, adjust = pcall(function() return container.adjustAmount end)
    if not ok or not adjust then return false end
    local capacity = qaItemValue(container, "getCapacity")
    if not capacity then return false end
    local adjusted = pcall(adjust, container, tonumber(fraction) * tonumber(capacity))
    return adjusted == true
end

local function qaFluidFraction(item)
    local container = qaItemValue(item, "getFluidContainer")
    local amount = qaItemValue(container, "getAmount")
    local capacity = qaItemValue(container, "getCapacity")
    if amount == nil or capacity == nil or tonumber(capacity) == 0 then return nil end
    return tonumber(amount) / tonumber(capacity)
end

local function qaClearInventoryType(inventory, fullType)
    local items = inventory and inventory:getItems()
    if not items then return end
    for index = items:size() - 1, 0, -1 do
        local item = items:get(index)
        if item and item:getFullType() == fullType then
            inventory:Remove(item)
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(inventory, item)
            end
        end
    end
end

local function qaSeedInventoryItem(inventory, fullType, configure)
    if not inventory or not inventory.AddItem then return nil end
    local ok, item = pcall(inventory.AddItem, inventory, fullType)
    if not ok or not item then return nil end
    if configure then configure(item) end
    if sendAddItemToContainer then sendAddItemToContainer(inventory, item) end
    return item
end

-- The crash probe supplies NLQAInventoryFaultMode through a temporary
-- server-only QA config file. It never exists in the production package.
Events.OnTick.Add(function()
    if inventoryFaultArmed or type(NLQAInventoryFaultMode) ~= "string"
            or not NLSocialAuthority then return end
    NLSocialAuthority.testFaultPhase=NLQAInventoryFaultMode
    inventoryFaultArmed=true
    print("NLQA INVENTORY FAULT ARMED: phase="..tostring(NLQAInventoryFaultMode))
end)

-- QA-only native multiplayer experiment.  The installed dedicated server
-- exposes getOnlinePlayers() but does not publish GameServer to Lua.  Add the
-- already-created NPC bodies to that exposed roster for one isolated run to
-- test whether the vanilla server loop distributes them without a Java bridge.
-- This never runs in the production mod and suppresses the QA presence repeat
-- while the roster is being observed so NPC bodies are not treated as clients.
Events.OnTick.Add(function()
    if nativeRosterProbeDone or NLQANativeRosterProbe ~= true
            or type(getOnlinePlayers) ~= "function"
            or not NLNpcAuthority or not NLNpcAuthority.started then return end
    local listOk, players = pcall(getOnlinePlayers)
    if not listOk or not players or not players.size or not players.add then return end
    local before = players:size()
    if before < 2 then return end
    local added, details = 0, {}
    for _, id in ipairs({"marisol", "kenji", "amara"}) do
        local body = NLNpcAuthority.bodies[id]
        if body then
            local containsOk, already = false, false
            if players.contains then
                containsOk, already = pcall(players.contains, players, body)
            end
            if not containsOk or already ~= true then
                local addOk = pcall(players.add, players, body)
                if addOk then added = added + 1 end
            end
            details[#details + 1] = id .. "=" .. tostring(added)
        end
    end
    nativeRosterProbeDone = true
    print("NLQA NATIVE ROSTER PROBE: before=" .. tostring(before)
        .. " after=" .. tostring(players:size()) .. " added=" .. tostring(added)
        .. " bodies=" .. table.concat(details, ","))
end)

-- QA-only bridge discovery. The installed dedicated server may publish the
-- IsoPlayer class table even when it withholds GameServer. Record the exact
-- static surface and whether it can return a native player collection before
-- the roster experiment mutates its exposed online-player list.
Events.OnTick.Add(function()
    if nativeBridgeProbeDone or NLQANativeRosterProbe ~= true then return end
    if type(IsoPlayer) ~= "table" then
        nativeBridgeProbeDone = true
        print("NLQA NATIVE BRIDGE PROBE: IsoPlayerType=" .. tostring(type(IsoPlayer)))
        return
    end
    local members = {}
    for _, name in ipairs({"new", "getPlayers", "getPlayerCount", "getPlayer", "players",
        "setLocalPlayer", "getLocalPlayerByOnlineID"}) do
        local ok, value = pcall(function() return IsoPlayer[name] end)
        members[#members + 1] = name .. "=" .. tostring(ok and type(value) or "error")
    end
    local countResult = "unavailable"
    local getPlayersOk, nativePlayers = pcall(function() return IsoPlayer.getPlayers() end)
    if getPlayersOk and nativePlayers then
        if nativePlayers.size then
            local sizeOk, size = pcall(nativePlayers.size, nativePlayers)
            countResult = sizeOk and tostring(size) or "size-error"
        else
            countResult = "no-size"
        end
    elseif not getPlayersOk then
        countResult = "call-error"
    end
    nativeBridgeProbeDone = true
    print("NLQA NATIVE BRIDGE PROBE: IsoPlayerType=table members=" .. table.concat(members, ",")
        .. " getPlayers=" .. tostring(getPlayersOk) .. " count=" .. tostring(countResult))
end)

-- The restart tool adds this QA-only server config after the initial household
-- has been stored. Tell the reconnecting client to request a fresh snapshot;
-- this marker is deliberately server-issued rather than inferred from stale
-- client state.
Events.OnTick.Add(function()
    if householdRestartProbeSent or NLQAPreserveHouseholdRestart ~= true
            or type(getOnlinePlayers) ~= "function" then return end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return end
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and player:getUsername() == "nl-host" then
            householdRestartProbeSent=true
            sendServerCommand(player, "NeighborhoodQA", "household_restart_probe", {})
            print("NLQA HOUSEHOLD RESTART PROBE: host marker sent")
            return
        end
    end
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
    -- The dedicated server's `getClass()` result is a Kahlua class proxy, not
    -- a reflection table. Calling Java reflection methods on that proxy emits
    -- engine errors and cannot reach the static GameServer class. Keep this
    -- probe diagnostic-only; the global bridge report above is authoritative.
    local classOk, bodyClass = pcall(function() return source:getClass() end)
    print("NLQA MP REFLECTION: classOk=" .. tostring(classOk)
        .. " classProxy=" .. tostring(bodyClass)
        .. " methods=unavailable")
    return 0
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

-- QA-only server danger stimulus. It uses the installed engine's real zombie
-- spawn entry point, so production danger handling is observed through the
-- dedicated server's loaded IsoCell rather than a Lua-only stand-in.
Events.OnClientCommand.Add(function(module, command, player)
    if module ~= "NeighborhoodQA" or command ~= "danger_probe" or not player
            or player:getUsername() ~= "nl-host" or dangerProbeSeeded then return end
    local npc = NLNpcAuthority and NLNpcAuthority.bodies and NLNpcAuthority.bodies.marisol
    if not npc then
        print("NLQA DANGER PROBE FAILED: reason=no-marisol-body")
        return
    end
    local x, y, z = math.floor(npc:getX()) + 1, math.floor(npc:getY()), math.floor(npc:getZ())
    local ok, result, err = false, nil, nil
    if type(addZombiesInOutfit) == "function" then
        ok, result = pcall(addZombiesInOutfit, x, y, z, 1, nil, 50)
    elseif type(createZombie) == "function" then
        ok, result = pcall(createZombie, x, y, z, nil, 0, IsoDirections and IsoDirections.S)
    else
        err = "server zombie spawn API unavailable"
    end
    if not ok then err = result; result = nil end
    dangerProbeSeeded = true
    local count = 0
    if result and result.size then count = result:size() end
    print("NLQA DANGER PROBE: ok=" .. tostring(ok) .. " count=" .. tostring(count)
        .. " x=" .. tostring(x) .. " y=" .. tostring(y) .. " z=" .. tostring(z)
        .. " error=" .. tostring(err))
end)

-- QA-only extra layer: seed a hat after the production slot snapshot has been
-- captured. The production wear call must remove this later-worn garment even
-- though it is absent from the saved slot.
Events.OnClientCommand.Add(function(module, command, player)
    if module ~= "NeighborhoodQA" or command ~= "seed_wardrobe_extra" or not player
            or player:getUsername() ~= "nl-host" or wardrobeExtraSeeded["nl-host"] then return end
    local square = player:getCurrentSquare()
    if not square then
        print("NLQA WARDROBE EXTRA SEED FAILED: username=nl-host reason=no-current-square")
        return
    end
    local item = "Base.Hat_Cowboy"
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
    square:AddWorldInventoryItem(item, 0.75, 0.50, 0.0)
    wardrobeExtraSeeded["nl-host"] = true
    print("NLQA WARDROBE EXTRA WORLD SEED: username=nl-host item=" .. item
        .. " square=" .. tostring(square:getX()) .. "," .. tostring(square:getY())
        .. "," .. tostring(square:getZ()))
    sendServerCommand(player, "NeighborhoodQA", "wardrobe_extra_seeded", {item=item})
end)

Events.OnClientCommand.Add(function(module, command, player)
    if module ~= "NeighborhoodQA" or command ~= "reset_household" or not player
            or player:getUsername() ~= "nl-host" then return end
    local world = NLAuthority.world()
    for _, username in ipairs({"nl-host", "nl-guest"}) do
        local profile = NLDomain.profile(world, username)
        profile.householdId, profile.householdInvite = nil, nil
        profile.claimed = {}
        profile.worked = {}
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
        if not (args and args.preserveHousehold == true) then
            profile.householdId, profile.householdInvite = nil, nil
        end
        profile.claimed = {}
        profile.worked = {}
    end
    if not (args and args.preserveHousehold == true) then
        for _, household in pairs(world.households or {}) do
            if NLHouseholdFurnishings then NLHouseholdFurnishings.remove(household) end
        end
        world.households = {}
        print("NLQA HOUSEHOLD RESET: career fixture cleared persisted household and claims")
    else
        print("NLQA HOUSEHOLD PRESERVED: career fixture retained persisted household")
    end
    local item = "Base.RippedSheets"
    local promotionProbe = args and args.promotionProbe == true
    local promotionItem = "Base.Bandage"
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
            if oldItem and (oldItem:getFullType() == item
                    or (promotionProbe and oldItem:getFullType() == promotionItem)) then
                square:transmitRemoveItemFromSquare(worldObject)
            end
        end
    end
    for index=1,amount do
        square:AddWorldInventoryItem(item, 0.25 + (index * 0.07), 0.50, 0.0)
    end
    local promotionAmount = 0
    local promotionPickupMode = nil
    local promotionSkill = nil
    if promotionProbe then
        -- The probe uses the engine's real XP object to satisfy the first
        -- promotion's vanilla skill gate; it never changes production state.
        promotionAmount = 8
        promotionPickupMode = "networked-main-inventory-seed"
        for index=1,promotionAmount do
            qaSeedInventoryItem(inventory, promotionItem)
        end
        local debugOk = false
        if Perks and Perks.Doctor and player.setPerkLevelDebug then
            debugOk = pcall(player.setPerkLevelDebug, player, Perks.Doctor, 1)
        end
        local skillOk, skill = pcall(player.getPerkLevel, player, Perks and Perks.Doctor)
        promotionSkill = skillOk and skill or nil
        print("NLQA CAREER PROMOTION SEED: item="..promotionItem
            .." amount="..tostring(promotionAmount).." debugLevelOk="..tostring(debugOk)
            .." skill="..tostring(promotionSkill))
    end
    local metadataProbe = args and args.metadataProbe == true
    if metadataProbe then
        qaClearInventoryType(inventory, "Base.KitchenKnife")
        qaClearInventoryType(inventory, "Base.WaterBottle")
        local knife = qaSeedInventoryItem(inventory, "Base.KitchenKnife", function(item)
            qaSetItemValue(item, "setCondition", 4)
        end)
        local bottle = qaSeedInventoryItem(inventory, "Base.WaterBottle", function(item)
            qaSetFluidFraction(item, 0.25)
        end)
        print("NLQA HOUSEHOLD METADATA SEED: item=Base.KitchenKnife condition=4 actual="
            .. tostring(qaItemValue(knife, "getCondition")) .. " ok=" .. tostring(knife ~= nil))
        print("NLQA HOUSEHOLD METADATA SEED: item=Base.WaterBottle usedDelta=0.25 actual="
            .. tostring(qaFluidFraction(bottle)) .. " ok=" .. tostring(bottle ~= nil))
    end
    careerSeeded[username] = true
    print("NLQA CAREER WORLD SEED: username="..tostring(username).." item="..item
        .." amount="..amount.." square="..tostring(square:getX())..","..tostring(square:getY())
        ..","..tostring(square:getZ()))
    sendServerCommand(player,"NeighborhoodQA","career_seeded",{
        item=item, amount=amount, mode="world", metadataProbe=metadataProbe,
        promotionProbe=promotionProbe, promotionItem=promotionItem,
        promotionAmount=promotionAmount, promotionSkill=promotionSkill,
        promotionPickupMode=promotionPickupMode,
        seedX=square:getX(), seedY=square:getY(), seedZ=square:getZ(),
    })
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
