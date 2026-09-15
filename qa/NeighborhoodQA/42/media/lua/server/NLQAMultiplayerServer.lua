-- QA-only server observer. It records that the real client command reached the
-- production authority; it does not implement gameplay or alter the package.
NLQAMultiplayerServer = true
if isClient() then return end
pcall(require, "NLQANativeRosterConfig")
pcall(require, "NLQANativeReflectionConfig")
pcall(require, "NLQANpcMovementConfig")
pcall(require, "NLQAPartnershipConfig")
pcall(require, "NLQADateConfig")
pcall(require, "NLQASocialBreadthConfig")
pcall(require, "NLQANpcScheduleConfig")
pcall(require, "NLQAZombieModeConfig")
local ok,err=pcall(function() require "NL/Authority" end)
print("NLQA MP SERVER BOOT: authority=" .. tostring(NLAuthority ~= nil) .. " requireOk=" .. tostring(ok)
    .. " error=" .. tostring(err))
print("NLQA ZOMBIE MODE: disabled=" .. tostring(NLQAZombiesDisabled == true)
    .. " sandboxZombies=" .. tostring(SandboxVars and SandboxVars.Zombies))
local zombieModeActiveLogged = false
Events.OnTick.Add(function()
    if zombieModeActiveLogged then return end
    zombieModeActiveLogged = true
    print("NLQA ZOMBIE MODE ACTIVE: disabled=" .. tostring(NLQAZombiesDisabled == true)
        .. " sandboxZombies=" .. tostring(SandboxVars and SandboxVars.Zombies))
end)
for _, name in ipairs({"getClass", "importClass", "Java", "luautils", "GameServer", "GameClient",
    "getNumClassFunctions", "getClassFunction", "getNumClassFields", "getClassField",
    "getClassFieldVal", "addZombiesInOutfit", "createZombie", "IsoZombie", "IsoDirections"}) do
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
local nativeStaticRosterProbeDone = false
local nativePacketProbeDone = false
local nativeBridgeProbeDone = false
local nativeReflectionProbeDone = false
local nativeSurfaceProbeDone = false
local partnershipProbeSeeded = false
local partnershipSnapshotAttempts = 0
local dateProbeSeeded = false
local dateServerSaveAttempted = false
local datePersistenceLoaded = false
local datePersistenceAnnouncementAttempts = 0
local npcMovementSampleTick = 0
local socialBreadthSeeded = false
local socialBreadthClocked = false
local npcScheduleProbeTick = 0
local npcScheduleSeeded = false
local npcScheduleHomeObserved = false
local npcScheduleWorkObserved = false

local function positionDateHost(host)
    local body = NLNpcAuthority and NLNpcAuthority.bodies and NLNpcAuthority.bodies.marisol
    if not host or not body then return false end
    local hostX, hostY, hostZ = math.floor(host:getX()), math.floor(host:getY()), math.floor(host:getZ())
    local x, y, z = hostX, hostY, hostZ
    local ok = pcall(function()
        host:setX(hostX + 0.25); host:setY(hostY + 0.5); host:setZ(hostZ)
        body:setX(x + 0.75); body:setY(y + 0.5); body:setZ(z)
    end)
    if ok then
        print("NLQA DATE POSITION: host=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
    end
    return ok
end

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

-- QA-only schedule observer. It advances the real Build 42 world clock from
-- home hours into the authored career window, then records the production
-- authority's persisted routine transition. No schedule state is implemented
-- here; the server NPC authority owns it.
Events.OnTick.Add(function()
    if NLQANpcScheduleProbe ~= true or not NLNpcAuthority
            or not NLNpcAuthority.started then return end
    npcScheduleProbeTick = npcScheduleProbeTick + 1
    local world = NLAuthority.world()
    local row = world.neighbors and world.neighbors.marisol
    if not row then return end
    if not npcScheduleSeeded then
        pcall(function()
            getGameTime():setMultiplier(1)
            getGameTime():setTimeOfDay(7)
        end)
        npcScheduleSeeded = true
        print("NLQA NPC SCHEDULE SEED: hour=7 expected=home")
        return
    end
    if row.routine == "home" and not npcScheduleHomeObserved then
        npcScheduleHomeObserved = true
        print("NLQA NPC SCHEDULE HOME: hour=" .. tostring(row.routineHour)
            .. " routine=" .. tostring(row.routine))
    end
    if npcScheduleHomeObserved and not npcScheduleWorkObserved
            and npcScheduleProbeTick >= 90 then
        pcall(function() getGameTime():setTimeOfDay(9) end)
    end
    if npcScheduleHomeObserved and row.routine == "work" and not npcScheduleWorkObserved then
        npcScheduleWorkObserved = true
        local target = NLNpcAuthority.routineTarget(row, row.routine)
        print("NLQA NPC SCHEDULE RESULT: id=marisol home=true work=true career="
            .. tostring(NLNeighbors.definitions.marisol.schedule)
            .. " hour=" .. tostring(row.routineHour)
            .. " target=" .. tostring(target and (target.x .. "," .. target.y) or "nil"))
        local playersOk, players = pcall(getOnlinePlayers)
        if playersOk and players then
            for index = 0, players:size() - 1 do
                local player = players:get(index)
                if player then
                    sendServerCommand(player, "NeighborhoodQA", "npc_schedule_result",
                        {id="marisol", routine="work", career=NLNeighbors.definitions.marisol.schedule})
                end
            end
        end
    end
end)

-- QA-only conversational-breadth fixture. It supplies a modest established
-- friendship to both accounts; the new work, home and compliment actions still
-- travel through the production client, authority, snapshot and event paths.
Events.OnTick.Add(function()
    if NLQASocialBreadthProbe ~= true
            or not NLNpcAuthority or not NLNpcAuthority.started
            or type(getOnlinePlayers) ~= "function" then return end
    local listOk, players = pcall(getOnlinePlayers)
    if not listOk or not players or players:size() < 2 then return end
    local host
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and player:getUsername() == "nl-host" then host = player; break end
    end
    local body = NLNpcAuthority.bodies and NLNpcAuthority.bodies.marisol
    if socialBreadthSeeded and host and body then
        -- Hold the moving native body beside the QA host while the production
        -- interaction gate is exercised. This keeps the probe hands-free and
        -- does not ship because this file lives in NeighborhoodQA.
        local x, y, z = math.floor(host:getX()), math.floor(host:getY()), math.floor(host:getZ())
        pcall(function()
            host:setX(x + 0.25); host:setY(y + 0.5); host:setZ(z)
            body:setX(x + 0.75); body:setY(y + 0.5); body:setZ(z)
        end)
        if not socialBreadthClocked then
            local profile = NLAuthority.world().players
                and NLAuthority.world().players["nl-host"]
            local relation = profile and profile.relationships
                and profile.relationships.marisol
            if relation and (tonumber(relation.compliments or 0) or 0) >= 1 then
                pcall(function() getGameTime():setMultiplier(1) end)
                socialBreadthClocked = true
                print("NLQA SOCIAL BREADTH CLOCK: restored=1")
            end
        end
        return
    end
    if socialBreadthSeeded then return end
    local world = NLAuthority.world()
    for _, username in ipairs({"nl-host", "nl-guest"}) do
        local profile = NLDomain.profile(world, username)
        local relation = NLSocial.relation(profile, "marisol")
        relation.met = true
        relation.friendship = 18
        relation.trust = 8
        relation.attraction = 0
        relation.status = "Acquaintance"
        relation.lastAction = -100
        relation.lastCompliment = -100
        relation.workTalks = 0
        relation.homeTalks = 0
        relation.compliments = 0
        profile.revision = profile.revision + 1
    end
    socialBreadthSeeded = true
    pcall(function() getGameTime():setMultiplier(60) end)
    print("NLQA SOCIAL BREADTH CLOCK: accelerated=60")
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player then
            sendServerCommand(player, "NeighborhoodQA", "social_breadth_seeded",
                {target="marisol"})
        end
    end
    print("NLQA SOCIAL BREADTH SEED: target=marisol met=true friendship=18 trust=8")
end)

-- QA-only persistence checkpoint. Build 42's normal world-save path owns the
-- actual ModData serialization; this asks that path to checkpoint immediately
-- after the production date mutation when the engine exposes its save hook.
Events.OnTick.Add(function()
    if dateServerSaveAttempted or NLQADateProbe ~= true
            or not NLNpcAuthority or not NLNpcAuthority.started
            or type(getOnlinePlayers) ~= "function" then return end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return end
    local world = NLAuthority.world()
    local profile = NLDomain.profile(world, "nl-host")
    local relation = NLSocial.relation(profile, "marisol")
    if (tonumber(relation.completedDates or 0) or 0) < 1 then return end
    dateServerSaveAttempted = true
    local saveOk, saveResult = pcall(function() return save(false) end)
    print("NLQA DATE SERVER SAVE: ok=" .. tostring(saveOk)
        .. " result=" .. tostring(saveResult))
end)

-- QA-only date fixture. It supplies progression prerequisites; the two date
-- mutations still travel through the production menu, client, authority,
-- snapshot and event paths.
Events.OnTick.Add(function()
    if dateProbeSeeded or NLQADateProbe ~= true or not NLNpcAuthority
            or not NLNpcAuthority.started or type(getOnlinePlayers) ~= "function" then return end
    local listOk, players = pcall(getOnlinePlayers)
    if not listOk or not players then return end
    local host
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and player:getUsername() == "nl-host" then host = player; break end
    end
    if not host then
        -- A replacement host can be present on the client while Build 42 is
        -- still returning nil for its server player. A live guest is enough
        -- to carry the persisted-state marker to a fresh client.
        local recipient = players:size() > 0 and players:get(0) or nil
        local world = NLAuthority.world()
        local profile = NLDomain.profile(world, "nl-host")
        local relation = NLSocial.relation(profile, "marisol")
        if recipient and (tonumber(relation.completedDates or 0) or 0) >= 1 then
            dateProbeSeeded = true
            datePersistenceLoaded = true
            datePersistenceAnnouncementAttempts = 1
            sendServerCommand(recipient, "NeighborhoodQA", "date_seeded",
                {target="marisol", persisted=true})
            print("NLQA DATE SEED SKIPPED: persisted completedDates="
                .. tostring(relation.completedDates) .. " recipient="
                .. tostring(recipient:getUsername()))
        end
        return
    end
    local world = NLAuthority.world()
    local profile = NLDomain.profile(world, "nl-host")
    local relation = NLSocial.relation(profile, "marisol")
    positionDateHost(host)
    if (tonumber(relation.completedDates or 0) or 0) >= 1 then
        dateProbeSeeded = true
        datePersistenceLoaded = true
        datePersistenceAnnouncementAttempts = 1
        sendServerCommand(host, "NeighborhoodQA", "date_seeded", {target="marisol", persisted=true})
        print("NLQA DATE SEED SKIPPED: persisted completedDates=" .. tostring(relation.completedDates))
        return
    end
    relation.met = true; relation.friendship = 40; relation.trust = 30
    relation.attraction = 20; relation.dates = 0; relation.completedDates = 0
    relation.lastAction = -100; relation.lastDate = -100; relation.activeDate = nil
    relation.status = "Friend"
    profile.revision = profile.revision + 1
    local guestProfile = NLDomain.profile(world, "nl-guest")
    local guestRelation = NLSocial.relation(guestProfile, "marisol")
    guestRelation.met = true; guestRelation.status = "Acquaintance"; guestRelation.lastAction = -100
    guestProfile.revision = guestProfile.revision + 1
    dateProbeSeeded = true
    sendServerCommand(host, "NeighborhoodQA", "date_seeded", {target="marisol"})
    print("NLQA DATE SEED: target=marisol friendship=40 trust=30 attraction=20 dates=0")
end)

-- Re-announce the persisted-state marker after the reconnect handshake. Some
-- no-Steam Build 42 clients drop the first server command while registering a
-- replacement player, so this retry stays QA-only and carries no new state.
Events.OnTick.Add(function()
    if not datePersistenceLoaded or NLQADateProbe ~= true
            or datePersistenceAnnouncementAttempts >= 12
            or type(getOnlinePlayers) ~= "function" then return end
    if not NLNpcAuthority or NLNpcAuthority.tick % 30 ~= 0 then return end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return end
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and (player:getUsername() == "nl-host" or index == 0) then
            sendServerCommand(player, "NeighborhoodQA", "date_seeded",
                {target="marisol", persisted=true})
            datePersistenceAnnouncementAttempts = datePersistenceAnnouncementAttempts + 1
            print("NLQA DATE PERSISTENCE ANNOUNCE: attempt="
                .. tostring(datePersistenceAnnouncementAttempts))
            return
        end
    end
end)

Events.OnTick.Add(function()
    if not dateProbeSeeded or NLQADateProbe ~= true
            or not NLNpcAuthority or not NLNpcAuthority.started
            or type(getOnlinePlayers) ~= "function" then return end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return end
    local world = NLAuthority.world()
    local relation = NLSocial.relation(NLDomain.profile(world, "nl-host"), "marisol")
    if (tonumber(relation.completedDates or 0) or 0) >= 1 then return end
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and player:getUsername() == "nl-host" then
            if NLNpcAuthority.tick % 30 == 0 then positionDateHost(player) end
            return
        end
    end
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

-- QA-only static-list experiment.  IsoPlayer.getPlayers() is a different
-- exposed surface from getOnlinePlayers(); test whether its returned native
-- list is the registry consumed by the server loop.  The mutation is limited
-- to this isolated profile and is never part of the production mod.
Events.OnTick.Add(function()
    if nativeStaticRosterProbeDone or NLQANativeRosterProbe ~= true
            or type(IsoPlayer) ~= "table" or not IsoPlayer.getPlayers
            or not NLNpcAuthority or not NLNpcAuthority.started then return end
    local listOk, players = pcall(IsoPlayer.getPlayers)
    nativeStaticRosterProbeDone = true
    if not listOk or not players then
        print("NLQA ISO-PLAYER LIST PROBE: getPlayers=false")
        return
    end
    local sizeOk, before = false, "unavailable"
    if players.size then sizeOk, before = pcall(players.size, players) end
    local added, addErrors = 0, 0
    if players.add then
        for _, id in ipairs({"marisol", "kenji", "amara"}) do
            local body = NLNpcAuthority.bodies[id]
            if body then
                local addOk = pcall(players.add, players, body)
                if addOk then added = added + 1 else addErrors = addErrors + 1 end
            end
        end
    end
    local afterOk, after = false, "unavailable"
    if players.size then afterOk, after = pcall(players.size, players) end
    local rereadOk, reread = pcall(IsoPlayer.getPlayers)
    local rereadSizeOk, rereadSize = false, "unavailable"
    if rereadOk and reread and reread.size then
        rereadSizeOk, rereadSize = pcall(reread.size, reread)
    end
    local arrayOk, playerArray = pcall(function() return IsoPlayer.players end)
    local emptySlot = "not-indexable"
    local arrayRead = "unavailable"
    if arrayOk and playerArray then
        arrayRead = type(playerArray)
    end
    local arrayAdd = "not-attempted"
    local body = NLNpcAuthority.bodies.marisol
    local postArrayOk, postArray = pcall(function() return IsoPlayer.getPlayers() end)
    local postArraySizeOk, postArraySize = false, "unavailable"
    if postArrayOk and postArray and postArray.size then
        postArraySizeOk, postArraySize = pcall(postArray.size, postArray)
    end
    local setterResult, setterContains = "unavailable", "unavailable"
    if IsoPlayer.setLocalPlayer and body then
        local setterOk = pcall(IsoPlayer.setLocalPlayer, 1, body)
        setterResult = setterOk and "called" or "error"
        local setterReadOk, setterRead = pcall(IsoPlayer.getPlayers)
        if setterReadOk and setterRead and setterRead.contains then
            local containsOk, contains = pcall(setterRead.contains, setterRead, body)
            setterContains = containsOk and tostring(contains) or "error"
        end
        local clearOk = pcall(IsoPlayer.setLocalPlayer, 1, nil)
        if not clearOk then setterResult = setterResult .. ":clear-error" end
    end
    print("NLQA ISO-PLAYER LIST PROBE: getPlayers=true before=" .. tostring(sizeOk and before or "error")
        .. " after=" .. tostring(afterOk and after or "error") .. " added=" .. tostring(added)
        .. " addErrors=" .. tostring(addErrors) .. " reread=" .. tostring(rereadSizeOk and rereadSize or "error")
        .. " array=" .. tostring(arrayRead) .. " emptySlot=" .. tostring(emptySlot)
        .. " arrayAdd=" .. tostring(arrayAdd) .. " postArray=" .. tostring(postArraySizeOk and postArraySize or "error")
        .. " setter=" .. tostring(setterResult) .. " setterContains=" .. tostring(setterContains))
end)

-- QA-only packet-route experiment.  GlobalObject exposes a small set of
-- server-side player sync helpers even when GameServer itself is hidden from
-- Lua.  Invoke only the routes that accept an IsoPlayer directly, then use
-- the existing client native-roster assertion to see whether any route can
-- create an engine-owned body.  This remains diagnostic and never enters the
-- production package.
local function invokeNativePacketGlobal(name, body)
    local globalOk, fn = pcall(function() return _G[name] end)
    if not globalOk or type(fn) ~= "function" then return "unavailable" end
    local callOk, result
    if name == "sendSyncPlayerFields" then
        callOk, result = pcall(fn, body, 0)
    else
        callOk, result = pcall(fn, body)
    end
    if callOk then return "called" end
    return "error:" .. tostring(result)
end

Events.OnTick.Add(function()
    if nativePacketProbeDone or NLQANativeRosterProbe ~= true
            or not NLNpcAuthority or not NLNpcAuthority.started
            or type(getOnlinePlayers) ~= "function" then return end
    local listOk, players = pcall(getOnlinePlayers)
    if not listOk or not players or not players.size or players:size() < 2 then return end
    local details = {}
    for _, id in ipairs({"marisol", "kenji", "amara"}) do
        local body = NLNpcAuthority.bodies[id]
        if body then
            local onlineOk, onlineId = pcall(body.getOnlineID, body)
            details[#details + 1] = id .. "=onlineId=" .. tostring(onlineOk and onlineId or "error")
                .. " syncFields=" .. invokeNativePacketGlobal("sendSyncPlayerFields", body)
                .. " visuals=" .. invokeNativePacketGlobal("syncVisuals", body)
                .. " humanVisual=" .. invokeNativePacketGlobal("sendHumanVisual", body)
        end
    end
    nativePacketProbeDone = true
    print("NLQA NATIVE PACKET PROBE: " .. table.concat(details, " "))
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
    local slots = {}
    local playerCountOk, playerCount = pcall(function() return IsoPlayer.numPlayers end)
    local playerArrayOk, playerArray = pcall(function() return IsoPlayer.players end)
    -- Build 42 exposes IsoPlayer.players as a Java array userdata. Kahlua's
    -- numeric indexing logs an engine error instead of returning a slot, so
    -- this probe records the surface type without touching the unsupported
    -- index operation.
    nativeBridgeProbeDone = true
    print("NLQA NATIVE BRIDGE PROBE: IsoPlayerType=table members=" .. table.concat(members, ",")
        .. " getPlayers=" .. tostring(getPlayersOk) .. " count=" .. tostring(countResult)
        .. " numPlayers=" .. tostring(playerCountOk and playerCount or "error")
        .. " playersArray=" .. tostring(playerArrayOk and type(playerArray) or "error")
        .. " slots=" .. table.concat(slots, ","))
end)

-- QA-only native server surface probe.  The Build 42 server publishes the
-- player object and a handful of sync helpers to Kahlua, while the actual
-- per-connection UdpConnection roster is kept behind GameServer.  Record the
-- complete connection/player/server-shaped global surface, the player-info
-- table, and the owner/packet links exposed by a real connected player and a
-- production NPC body.  This is evidence for the native bridge gate only;
-- it never changes a production body or a connection roster.
local function nativeSurfaceValue(name)
    local ok, value = pcall(function() return _G[name] end)
    if not ok then return "lookup-error" end
    if value == nil then return "nil" end
    return type(value)
end

local function nativeSurfaceCall(name, ...)
    local ok, fn = pcall(function() return _G[name] end)
    if not ok or type(fn) ~= "function" then return "unavailable" end
    local args = {...}
    local callOk, value = pcall(function() return fn(unpack(args)) end)
    if not callOk then return "error:" .. tostring(value) end
    if value == nil then return "nil" end
    return type(value)
end

local function nativeSurfaceOwner(body)
    if not body then return "body-unavailable" end
    local methodOk, method = pcall(function() return body.getOwner end)
    if not methodOk or type(method) ~= "function" then return "method-unavailable" end
    local ok, owner = pcall(method, body)
    if not ok then return "error:" .. tostring(owner) end
    return owner and type(owner) or "nil"
end

Events.OnTick.Add(function()
    if nativeSurfaceProbeDone or NLQANativeRosterProbe ~= true
            or not NLNpcAuthority or not NLNpcAuthority.started
            or type(getOnlinePlayers) ~= "function" then return end
    local listOk, players = pcall(getOnlinePlayers)
    if not listOk or not players or not players.size or players:size() < 2 then return end
    local target = players:get(0)
    if not target then return end
    nativeSurfaceProbeDone = true

    local names = {
        "getConnectionFromPlayer", "getPlayerFromConnection", "getConnection",
        "getUdpConnection", "getServerConnection", "getPlayerAt", "getPlayerByOnlineID",
        "getPlayerFromUsername", "getConnectedPlayers", "getOnlinePlayers",
        "sendPlayerConnected", "sendPlayerExtraInfo", "sendVisual",
        "sendSyncPlayerFields", "syncVisuals", "getServerOptions", "checkPermissions",
    }
    local globalTypes = {}
    for _, name in ipairs(names) do
        globalTypes[#globalTypes + 1] = name .. "=" .. nativeSurfaceValue(name)
    end

    local filtered = {}
    local globalScanOk, globalScanError = pcall(function()
        for name in pairs(_G) do
            local text = string.lower(tostring(name))
            if string.find(text, "connection", 1, true)
                    or string.find(text, "player", 1, true)
                    or string.find(text, "server", 1, true)
                    or string.find(text, "network", 1, true) then
                filtered[#filtered + 1] = tostring(name)
            end
        end
    end)
    table.sort(filtered)
    if #filtered > 80 then
        while #filtered > 80 do table.remove(filtered) end
    end

    local infoKeys = {}
    local infoOk, info = pcall(getPlayerInfo, target)
    if infoOk and info then
        pcall(function()
            for key in pairs(info) do
                infoKeys[#infoKeys + 1] = tostring(key)
            end
        end)
        table.sort(infoKeys)
    end
    local npc
    for _, id in ipairs({"marisol", "kenji", "amara"}) do
        if NLNpcAuthority.bodies[id] then npc = NLNpcAuthority.bodies[id]; break end
    end
    local aiType = "unavailable"
    if npc then
        local aiMethodOk, aiMethod = pcall(function() return npc.getNetworkCharacterAI end)
        local aiOk, ai = false, nil
        if aiMethodOk and type(aiMethod) == "function" then
            aiOk, ai = pcall(aiMethod, npc)
        end
        if aiOk and ai then
            aiType = type(ai)
        else
            aiType = "error"
        end
    end
    print("NLQA NATIVE SERVER SURFACE: globals=" .. table.concat(globalTypes, ",")
        .. " filteredOk=" .. tostring(globalScanOk)
        .. " filteredError=" .. tostring(globalScanError)
        .. " filtered=" .. table.concat(filtered, ",")
        .. " targetOwner=" .. nativeSurfaceOwner(target)
        .. " npcOwner=" .. nativeSurfaceOwner(npc)
        .. " getConnectionFromPlayer=" .. nativeSurfaceCall("getConnectionFromPlayer", target)
        .. " getConnectedPlayers=" .. nativeSurfaceCall("getConnectedPlayers")
        .. " playerInfo=" .. tostring(infoOk and type(info) or "error")
        .. " infoKeys=" .. table.concat(infoKeys, ",")
        .. " npcAI=" .. aiType)
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
local function reflectionMemberName(value)
    local text = tostring(value)
    local methodName = string.match(text, "%.([%w_]+)%(")
    if methodName then return methodName end
    return string.match(text, "%.([%w_]+)$") or text
end

local function reflectionCall(value, methodName, ...)
    local args = {...}
    local directOk, directResult = pcall(function()
        return value[methodName](value, unpack(args))
    end)
    if directOk then return true, directResult, "colon" end
    local staticOk, staticResult = pcall(function()
        return value[methodName](unpack(args))
    end)
    if staticOk then return true, staticResult, "static" end
    return false, directResult, tostring(staticResult)
end

local function findReflectiveMethod(target, needle)
    if type(getNumClassFunctions) ~= "function" or type(getClassFunction) ~= "function" then
        return nil, "helpers-unavailable"
    end
    local countOk, count = pcall(getNumClassFunctions, target)
    if not countOk or not count then return nil, "method-count-error" end
    for index = 0, math.min(count - 1, 520) do
        local methodOk, method = pcall(getClassFunction, target, index)
        if methodOk and method and string.find(tostring(method), needle, 1, true) then
            return method, tostring(method)
        end
    end
    return nil, "method-not-found:" .. needle
end

local function invokeReflectiveMethod(method, target, ...)
    if not method then return false, "method-unavailable" end
    local args = {...}
    local ok, result = pcall(function() return method:invoke(target, unpack(args)) end)
    return ok, result
end

local function tryReflectiveNpcReannounce(players)
    if nativeReflectionProbeDone or NLQANativeReflectionProbe ~= true
            or not players or not players.size or players:size() < 2 then return 0 end
    if not NLNpcAuthority or not NLNpcAuthority.started or not NLNpcAuthority.bodies then
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
    nativeReflectionProbeDone = true

    local classOk, bodyClass = pcall(function() return source:getClass() end)
    local classText = classOk and tostring(bodyClass) or "error:" .. tostring(bodyClass)
    local loadOk, gameServerClass, loadRoute = false, nil, "unavailable"
    local bridgeErrors = {}
    if classOk and bodyClass then
        -- Kahlua's debug enumerator does not enumerate methods on a
        -- java.lang.Class proxy in the dedicated server, even though direct
        -- method dispatch on that proxy is still available. Try the direct
        -- route first; this remains QA-only and is the only path that can
        -- establish whether the hidden GameServer class is reachable.
        local directLoaderOk, directLoader, directLoaderRoute = reflectionCall(bodyClass, "getClassLoader")
        if directLoaderOk and directLoader then
            local directLoadOk, directLoaded = reflectionCall(directLoader, "loadClass", "zombie.network.GameServer")
            if directLoadOk and directLoaded then
                loadOk, gameServerClass, loadRoute = true, directLoaded,
                    "direct-class-loader-" .. tostring(directLoaderRoute)
            else
                bridgeErrors[#bridgeErrors + 1] = "direct-loadClass=" .. tostring(directLoaded)
            end
        else
            bridgeErrors[#bridgeErrors + 1] = "direct-loader=" .. tostring(directLoader)
        end
        if not loadOk then
            local directForNameOk, directForName = reflectionCall(bodyClass, "forName", "zombie.network.GameServer")
            if directForNameOk and directForName then
                loadOk, gameServerClass, loadRoute = true, directForName, "direct-class-for-name"
            else
                bridgeErrors[#bridgeErrors + 1] = "direct-forName=" .. tostring(directForName)
            end
        end
        local loaderMethod, loaderMethodText = findReflectiveMethod(bodyClass, ".getClassLoader()")
        local loaderOk, loader = false, nil
        if not loadOk then loaderOk, loader = invokeReflectiveMethod(loaderMethod, bodyClass) end
        if loaderOk and loader and not loadOk then
            local loadMethod, loadMethodText = findReflectiveMethod(loader, ".loadClass(java.lang.String)")
            loadOk, gameServerClass = invokeReflectiveMethod(loadMethod, loader, "zombie.network.GameServer")
            if loadOk then loadRoute = "class-loader" end
            if not loadOk then bridgeErrors[#bridgeErrors + 1] = "loadClass=" .. tostring(loadMethodText) end
        end
        if not loadOk and (not loaderOk or not loader) then bridgeErrors[#bridgeErrors + 1] = "loader=" .. tostring(loaderMethodText) end
        if not loadOk then
            local forNameMethod, forNameMethodText = findReflectiveMethod(bodyClass, ".forName(java.lang.String)")
            loadOk, gameServerClass = invokeReflectiveMethod(forNameMethod, nil, "zombie.network.GameServer")
            if loadOk then loadRoute = "class-for-name" end
            if not loadOk then bridgeErrors[#bridgeErrors + 1] = "forName=" .. tostring(forNameMethodText) end
        end
    end

    local instanceOk, gameServer = false, nil
    local fieldNames, methodNames = {}, {}
    if loadOk and gameServerClass then
        local newInstanceMethod, newInstanceMethodText = findReflectiveMethod(gameServerClass, ".newInstance()")
        instanceOk, gameServer = invokeReflectiveMethod(newInstanceMethod, gameServerClass)
        if not instanceOk then bridgeErrors[#bridgeErrors + 1] = "newInstance=" .. tostring(newInstanceMethodText) end
    end
    if not instanceOk then
        local ctorOk, ctor = pcall(function() return GameServer() end)
        if ctorOk and ctor then instanceOk, gameServer = true, ctor end
    end

    local function enumerateReflection()
        if not instanceOk or not gameServer then return end
        if type(getNumClassFields) == "function" and type(getClassField) == "function" then
            local countOk, count = pcall(getNumClassFields, gameServer)
            if countOk and count then
                for index = 0, math.min(count - 1, 220) do
                    local fieldOk, field = pcall(getClassField, gameServer, index)
                    if fieldOk and field then
                        local name = reflectionMemberName(field)
                        if name == "Players" or name == "IDToPlayerMap" or name == "PlayerToAddressMap"
                                or name == "UserNameToPlayerMap" then
                            fieldNames[#fieldNames + 1] = name
                        end
                    end
                end
            end
        end
        if type(getNumClassFunctions) == "function" and type(getClassFunction) == "function" then
            local countOk, count = pcall(getNumClassFunctions, gameServer)
            if countOk and count then
                for index = 0, math.min(count - 1, 420) do
                    local methodOk, method = pcall(getClassFunction, gameServer, index)
                    if methodOk and method then
                        local name = reflectionMemberName(method)
                        if name == "sendPlayerConnected" or name == "getConnectionFromPlayer"
                                or name == "sendSyncPlayerFields" or name == "syncVisuals"
                                or name == "syncHumanVisual" then
                            methodNames[#methodNames + 1] = name
                        end
                    end
                end
            end
        end
    end
    local enumerateOk, enumerateError = pcall(enumerateReflection)
    local sent = 0
    local invokeStatus = "unavailable"
    if enumerateOk and instanceOk and gameServer and #methodNames > 0
            and type(getNumClassFunctions) == "function" and type(getClassFunction) == "function" then
        local countOk, count = pcall(getNumClassFunctions, gameServer)
        if countOk and count then
            for index = 0, math.min(count - 1, 420) do
                local methodOk, method = pcall(getClassFunction, gameServer, index)
                local name = methodOk and method and reflectionMemberName(method) or ""
                if methodOk and method and name == "sendPlayerConnected" then
                    local target = players:get(0)
                    if target == source and players:size() > 1 then target = players:get(1) end
                    local connectionOk, connection = pcall(function()
                        return GameServer.getConnectionFromPlayer(target)
                    end)
                    if not connectionOk then
                        connectionOk, connection = pcall(function()
                            return getConnectionFromPlayer(target)
                        end)
                    end
                    if not connectionOk or not connection then
                        connectionOk, connection = reflectionCall(gameServerClass,
                            "getConnectionFromPlayer", target)
                    end
                    if connectionOk and connection then
                        local callOk = pcall(function() return method:invoke(nil, source, connection) end)
                        if callOk then sent = sent + 1; invokeStatus = "called" else invokeStatus = "error" end
                    else
                        invokeStatus = "connection-unavailable"
                    end
                    break
                end
            end
        end
    elseif not enumerateOk then
        invokeStatus = "enumerate-error"
    end
    print("NLQA MP REFLECTION: classOk=" .. tostring(classOk)
        .. " classProxy=" .. classText .. " loadOk=" .. tostring(loadOk)
        .. " loadRoute=" .. loadRoute .. " instanceOk=" .. tostring(instanceOk)
        .. " fields=" .. table.concat(fieldNames, ",")
        .. " methods=" .. table.concat(methodNames, ",")
        .. " invoke=" .. invokeStatus .. " sent=" .. tostring(sent)
        .. " error=" .. tostring(enumerateError)
        .. " bridgeErrors=" .. table.concat(bridgeErrors, ";"))
    return sent
end

-- The first production refresh can arrive before the guest has completed the
-- connection handshake. Retry the diagnostic only after the real server has
-- two connected players, without changing the production refresh behavior.
Events.OnTick.Add(function()
    if nativeReflectionProbeDone or NLQANativeReflectionProbe ~= true
            or not NLNpcAuthority or not NLNpcAuthority.started
            or type(getOnlinePlayers) ~= "function" then return end
    local listOk, players = pcall(getOnlinePlayers)
    if listOk and players then tryReflectiveNpcReannounce(players) end
end)

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
