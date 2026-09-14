-- Multiplayer evidence logger. Loaded only by NeighborhoodQA in isolated profiles.
NLQAMultiplayer = { snapshots = 0, refreshAttempts = 0, refreshSent = false,
    presenceCount = 0, movementFrame = 0, movementSent = false,
    remoteScanFrame = 0, remoteScanCount = 0, remoteScanLogged = false,
    plumbobSizeLogged = false, hudProbeLogged = false,
    streamProbeSent = false, streamProbeObserved = false, streamProbeFrame = 0,
    streamProbeOld = nil, streamWalkSent = false, streamWalkObserved = false,
    streamWalkFrame = 0, streamWalkStep = 0, streamWalkCheckLogged = false,
    streamWalkOriginX = nil, streamWalkOriginY = nil,
    socialFrame = 0, socialRefreshSent = false, socialActionSent = false,
    socialActionScheduled = false, socialActionName = nil, socialTarget = nil,
    socialActionDue = 0, socialActionCount = 0, socialActionPrepared = false,
    socialPositioned = false,
    socialConversationComplete = false,
    socialResultLogged = false, careerSeedSent = false, careerSeeded = false,
    careerSelectSent = false, careerDeliverSent = false, careerResultLogged = false,
    careerWorkSent = false, careerWorkResultLogged = false, careerWorkDue = 0,
    careerDue = 0, careerStage = 0, careerPickupAttempted = false,
    careerPickupObserved = false, careerPickupExpected = 0, careerPickupItem = nil,
    careerPickupNextAttempt = 0, householdCreateSent = false,
    householdInviteSent = false, householdAcceptSent = false,
    householdTaskSent = false, householdResultLogged = false,
    householdJoinLogged = false, householdCreatedObserved = false,
    householdInviteDue = 0, householdMembersObserved = false,
    householdStoreSent = false, householdStoreObserved = false,
    householdRetrieveSent = false, householdRetrieveObserved = false,
    householdFurnishingSent = false, householdFurnishingObserved = false,
    householdTransferSent = false, householdTransferObserved = false,
    householdTransferDue = 0, householdTaskDue = 0, householdResetSent = false,
    householdDirectCreateDue = 180,
    householdFurnishingPrepared = false, householdFurnishingActionDue = 0,
    dangerProbeSent = false,
    wardrobeSeedSent = false, wardrobeSeeded = false, wardrobePickupAttempted = false,
    wardrobePickupObserved = false, wardrobePickupNextAttempt = 0,
    wardrobeItemTypes = {}, wardrobeWearSent = false, wardrobeWearObserved = false,
    wardrobeWearDue = 0, wardrobeSaveSent = false, wardrobeSaveDue = 0,
    wardrobePersisted = false, wardrobeSnapshotRevision = nil, wardrobeOutfits = nil,
    wardrobeReplacementDue = 0, wardrobeUnequipAttempted = false,
    wardrobeUnequipNextAttempt = 0, wardrobeUnequipSent = false,
    wardrobeUnequipObserved = false, wardrobeReplacementSent = false,
    wardrobeReplacementObserved = false,
    wardrobeExtraType = nil, wardrobeExtraSeedSent = false, wardrobeExtraSeeded = false,
    wardrobeExtraPickupAttempted = false, wardrobeExtraPickupObserved = false,
    wardrobeExtraWearSent = false, wardrobeExtraWearObserved = false,
    wardrobeAutoRemovalBefore = nil, wardrobeAutoRemovalAfter = nil,
    wardrobeSnapshotLogged = false, wardrobeUiLogged = false,
    appearanceSelectSent = false, appearanceSelected = false, appearanceDue = 0,
    inventoryGiveSent = false, inventoryGiveObserved = false,
    inventoryRequestSent = false, inventoryRequestObserved = false,
    inventoryExchangeDue = 0, inventoryMetadataLogged = false,
    connectionCount = 0, inventoryRestartProbeSent = false,
    inventoryRestartObserved = false, inventoryRestartDue = 0 }
NLQAMultiplayer.socialCooldownFrames = 3600

local function emit(label, value)
    print("NLQA MP " .. label .. ": " .. tostring(value))
end

local function requestHouseholdFurnishing(action)
    local player = getSpecificPlayer(0)
    if not player then return false end
    pcall(require, "NL/HouseholdFurnishingMenu")
    if NLHouseholdFurnishingMenu and NLHouseholdFurnishingMenu.request then
        NLHouseholdFurnishingMenu.request(player, action)
        return true
    end
    NLHouseholdClient.request(0, "furnishing", {
        action = action, item = "Base.RippedSheets", amount = 1,
    })
    return true
end

local function qaIdentity()
    if NLQAIdentity then return NLQAIdentity end
    return {}
end

local function qaAppearancePreset()
    return qaIdentity().username == "nl-host" and "bob" or "braided"
end

-- Consume the launcher-supplied +connect/+password immediately, before vanilla
-- MainScreen opens its manual bootstrap popup. The isolated launcher normally
-- supplies NLQAIdentity, so these are only a fallback.
local argsAddress,argsPassword=nil,nil
pcall(function() argsAddress=getServerAddressFromArgs() end)
pcall(function() argsPassword=getServerPasswordFromArgs() end)

-- The engine's own no-Steam join path is the global serverConnect used by the
-- vanilla server browser. Vanilla MainScreen consumes +connect before mod event
-- handlers run, so the isolated launcher writes the endpoint into NLQAIdentity.
local function tryConnect()
    if NLQAMultiplayer.connectAttempted then return end
    if isClient() or isServer() then return end
    local identity=qaIdentity()
    local address=identity.address or argsAddress
    if not address or address=="" then return end
    if not canConnect() then return end
    NLQAMultiplayer.connectAttempted=true
    local ip,port=string.match(address,"^([^:]+):(%d+)$")
    if not ip then ip=address; port="16261" end
    local password=identity.password or argsPassword
    if not password or password=="" then password="qa-account-password" end
    local username=identity.username or "nl-qa"
    emit("CONNECT REQUEST", username.." -> "..ip..":"..port.." accountPassword="..tostring(password~=""))
    serverConnect(username,password,ip,"",port,"","Neighborhood QA",false,true,1,"")
end

local function armConnect()
    if isClient() or isServer() then return end
    NLQAMultiplayer.connectAttempted=false
    NLQAMultiplayer.connectFrame=0
    emit("CONNECT ARMED", tostring(qaIdentity().address or "args"))
end

local function createDefaultCharacter()
    local ok,err=pcall(function()
        local desc=MainScreen.instance and MainScreen.instance.desc
        if desc then
            desc:setForename("QA")
            desc:setSurname(qaIdentity().username or "Neighbor")
        end
        if MainScreen.instance and MainScreen.instance.charCreationProfession then
            CharacterCreationProfession.instance=MainScreen.instance.charCreationProfession
        end
        if MapSpawnSelect and MapSpawnSelect.instance then
            MapSpawnSelect.instance:useDefaultSpawnRegion()
        end
        GameWindow.doRenderEvent(false)
        forceChangeState(LoadingQueueState.new())
        emit("CHARACTER DEFAULT", tostring(desc and desc:getForename()).." "..tostring(desc and desc:getSurname()))
    end)
    if not ok then emit("CHARACTER FAILED", tostring(err)) end
end

-- QA-only hands-free movement stimulus. The production mod only observes the
-- server-authoritative position; this fixture supplies a real timed walk so
-- the presence heartbeat can be checked against changed coordinates.
local function queueHostWalk()
    if qaIdentity().username ~= "nl-host" then return end
    local player = getSpecificPlayer(0)
    local cell = getCell()
    if not player or not cell then return end
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local target
    local npc = NLNpcClient and (NLNpcClient.bodies.kenji or NLNpcClient.bodies.marisol)
    if npc then
        local nx, ny = math.floor(npc:getX()), math.floor(npc:getY())
        local candidates = {{nx+1,ny},{nx-1,ny},{nx,ny+1},{nx,ny-1}}
        for _, point in ipairs(candidates) do
            local square = cell:getGridSquare(point[1], point[2], z)
            if square and square:isFree(false) then target=square; break end
        end
    end
    target = target or cell:getGridSquare(x + 2, y, z)
    if not target or not target:isFree(false) then target = cell:getGridSquare(x + 1, y, z) end
    if not target then
        emit("MOVE FAILED", "no free target")
        return
    end
    local ok, err = pcall(function()
        require "TimedActions/WalkToTimedAction"
        assert(ISTimedActionQueue, "ISTimedActionQueue unavailable")
        ISTimedActionQueue.add(ISWalkToTimedAction:new(player, target))
    end)
    if ok then
        emit("MOVE QUEUED", string.format("from=%.2f,%.2f to=%d,%d",
            player:getX(), player:getY(), target:getX(), target:getY()))
    else
        emit("MOVE FAILED", tostring(err))
    end
end

Events.OnMainMenuEnter.Add(armConnect)

-- Wait a moment after the menu so the engine finishes tearing down any previous
-- connection, then join through the engine's own no-Steam path.
Events.OnRenderTick.Add(function()
    if NLQAMultiplayer.characterPending then
        NLQAMultiplayer.characterFrame=(NLQAMultiplayer.characterFrame or 0)+1
        if NLQAMultiplayer.characterFrame>=240 then
            NLQAMultiplayer.characterPending=false
            if checkSavePlayerExists() then
                emit("CHARACTER EXISTING", "engine will load the saved player")
            else
                createDefaultCharacter()
            end
        end
    end
    if NLQAMultiplayer.connectAttempted then return end
    NLQAMultiplayer.connectFrame=(NLQAMultiplayer.connectFrame or 0)+1
    if NLQAMultiplayer.connectFrame>=120 then tryConnect() end
end)

Events.OnGameStart.Add(function()
    local player = getSpecificPlayer(0)
    emit("CLIENT START", "username=" .. tostring(player and player:getUsername())
        .. " isClient=" .. tostring(isClient()) .. " isServer=" .. tostring(isServer()))
    NLQAMultiplayer.refreshFrame = 0
    NLQAMultiplayer.movementFrame = 0
end)

Events.OnRenderTick.Add(function()
    if not isClient() or NLQAMultiplayer.movementSent then return end
    NLQAMultiplayer.movementFrame = NLQAMultiplayer.movementFrame + 1
    if NLQAMultiplayer.movementFrame >= 420 then
        NLQAMultiplayer.movementSent = true
        queueHostWalk()
    end
end)

-- OnGameStart can fire while the client world is still attaching its first
-- player. Retry through the normal client command path once that player is
-- fully present, rather than treating an early no-op as multiplayer evidence.
Events.OnRenderTick.Add(function()
    if not isClient() or NLQAMultiplayer.refreshSent then return end
    NLQAMultiplayer.refreshFrame = (NLQAMultiplayer.refreshFrame or 0) + 1
    if NLQAMultiplayer.refreshFrame < 120 then return end
    local player = getSpecificPlayer(0)
    if not player or not NLClient then return end
    NLQAMultiplayer.refreshAttempts = NLQAMultiplayer.refreshAttempts + 1
    NLClient.request(0, "refresh")
    NLQAMultiplayer.refreshSent = true
    emit("REFRESH SENT", "attempt=" .. tostring(NLQAMultiplayer.refreshAttempts)
        .. " player=" .. tostring(player:getUsername()))
end)

Events.OnConnected.Add(function()
    NLQAMultiplayer.connectionCount=NLQAMultiplayer.connectionCount+1
    emit("CONNECTED", qaIdentity().username or "?")
    if isServer() then return end
    if qaIdentity().username=="nl-host" then
        NLQAMultiplayer.inventoryRestartDue=NLQAMultiplayer.socialFrame+120
        NLQAMultiplayer.inventoryRestartProbeSent=false
        NLQAMultiplayer.inventoryRestartObserved=false
        NLQAMultiplayer.careerWorkPersistedLogged=false
        emit("RESTART PROBE ARMED", "connection="..tostring(NLQAMultiplayer.connectionCount))
    end
    if checkSavePlayerExists() then return end
    -- Vanilla would open spawn and character creation screens here and wait for
    -- clicks. Defer the QA default steps so the engine can finish its own connect
    -- state teardown first (Entering LoadingQueueState before that nulls the
    -- connection and kills the client thread).
    NLQAMultiplayer.characterPending=true
    NLQAMultiplayer.characterFrame=0
end)

Events.OnConnectFailed.Add(function(message, detail)
    emit("CONNECT FAILED", tostring(message) .. " detail=" .. tostring(detail))
end)

Events.OnDisconnect.Add(function(message, detail)
    emit("DISCONNECT", tostring(message) .. " detail=" .. tostring(detail))
end)

Events.OnConnectionStateChanged.Add(function(state, message, arg)
    emit("CONNECTION STATE", tostring(state) .. " message=" .. tostring(message) .. " arg=" .. tostring(arg))
end)

-- QA-only client-acquisition probe. The server places real world inventory on
-- the current square; the client queues the same transfer action vanilla uses
-- for a world-item click. The production career command runs only after the
-- items are visible in this client's inventory.
local function qaInventoryCount(player, fullType)
    if not player or not player.getInventory then return 0 end
    local inventory = player:getInventory()
    if not inventory or not inventory.getItems then return 0 end
    local items = inventory:getItems()
    if not items or not items.size then return 0 end
    local count = 0
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item and item.getFullType and item:getFullType() == fullType then
            count = count + 1
        end
    end
    return count
end

-- QA-only viewpoint setup. Each isolated client can be placed on a free
-- adjacent square before its own production proximity gate is exercised.
local function positionClientForSocial(username, targetId)
    if qaIdentity().username ~= username then return false end
    local player=getSpecificPlayer(0)
    local npc=NLNpcClient and NLNpcClient.bodies
        and NLNpcClient.bodies[targetId or "marisol"]
    local cell=getCell and getCell()
    if not player or not npc or not cell then return false end
    local z=math.floor(npc:getZ())
    local nx,ny=math.floor(npc:getX()),math.floor(npc:getY())
    local candidates={{nx+1,ny},{nx-1,ny},{nx,ny+1},{nx,ny-1}}
    local fallback={nx+1,ny}
    for _,point in ipairs(candidates) do
        local square=cell:getGridSquare(point[1],point[2],z)
        if square and square:isFree(false) then
            fallback=fallback or point
            if player.teleportTo then player:teleportTo(point[1]+0.5,point[2]+0.5,z)
            else
                player:setX(point[1]+0.5); player:setY(point[2]+0.5)
                if player.setZ then player:setZ(z) end
                if player.setCurrent then player:setCurrent(square) end
            end
            local visible=true
            if player.CanSee then
                local visibleOk,visibleValue=pcall(player.CanSee,player,npc)
                visible=visibleOk and visibleValue==true
            end
            emit("SOCIAL VIEWPOINT CHECK", string.format("target=%s square=%d,%d,%d canSee=%s",
                tostring(targetId or "marisol"),point[1],point[2],z,tostring(visible)))
            if visible then
                NLQAMultiplayer.socialPositioned=true
                emit("SOCIAL VIEWPOINT", string.format("%s beside %s at %d,%d,%d",
                    tostring(username),tostring(targetId or "marisol"),point[1],point[2],z))
                return true
            end
        end
    end
    if fallback then
        -- The guest may not have the target chunk in its local square cache
        -- yet. Teleporting to the authoritative replica's adjacent fallback
        -- still leaves the production server to decide canInteract; the QA
        -- stimulus never fabricates a successful social result.
        local point=fallback
        if player.teleportTo then player:teleportTo(point[1]+0.5,point[2]+0.5,z)
        else
            player:setX(point[1]+0.5); player:setY(point[2]+0.5)
            if player.setZ then player:setZ(z) end
        end
        if username=="nl-guest" then
            NLQAMultiplayer.socialPositioned=true
            emit("SOCIAL VIEWPOINT", string.format("%s fallback beside %s at %d,%d,%d",
                tostring(username),tostring(targetId or "marisol"),point[1],point[2],z))
            return true
        end
        emit("SOCIAL VIEWPOINT WAIT", "no visible adjacent square yet")
    end
    return false
end

-- QA-only natural streaming stimulus. Walk the host far enough through the
-- loaded world that Build 42 can unload the NPC square; production remains the
-- only owner of the authoritative row and the client recovery decision.
local function queueStreamWalk()
    if qaIdentity().username ~= "nl-host" then return false end
    local player = getSpecificPlayer(0)
    local cell = getCell()
    if not player or not cell then return false end
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local target
    for _, point in ipairs({{x + 4, y}, {x - 4, y}, {x, y + 4}, {x, y - 4}}) do
        local candidate = cell:getGridSquare(point[1], point[2], z)
        if candidate and candidate:isFree(false) then target = candidate; break end
    end
    if not target then
        emit("STREAM WALK FAILED", "no loaded free target")
        return false
    end
    local ok, err = pcall(function()
        require "TimedActions/WalkToTimedAction"
        assert(ISTimedActionQueue, "ISTimedActionQueue unavailable")
        ISTimedActionQueue.add(ISWalkToTimedAction:new(player, target))
    end)
    if not ok then
        emit("STREAM WALK FAILED", tostring(err))
        return false
    end
    if not NLQAMultiplayer.streamWalkSent then
        NLQAMultiplayer.streamWalkOriginX, NLQAMultiplayer.streamWalkOriginY = player:getX(), player:getY()
    end
    NLQAMultiplayer.streamWalkStep = NLQAMultiplayer.streamWalkStep + 1
    NLQAMultiplayer.streamWalkSent = true
    emit("STREAM WALK QUEUED", string.format("step=%d from=%.2f,%.2f to=%d,%d",
        NLQAMultiplayer.streamWalkStep, player:getX(), player:getY(), target:getX(), target:getY()))
    return true
end

local function positionHostForSocial(targetId)
    return positionClientForSocial("nl-host", targetId)
end

local function positionHostForHousehold()
    if qaIdentity().username ~= "nl-host" then return false end
    local state = NLHouseholdClient and NLHouseholdClient.snapshots
        and NLHouseholdClient.snapshots[0]
    local home = state and state.household and state.household.home
    local player = getSpecificPlayer(0)
    if not home or not player then return false end
    local x, y, z = (tonumber(home.x) or player:getX()) + 0.5,
        (tonumber(home.y) or player:getY()) + 0.5, tonumber(home.z) or player:getZ()
    if player.teleportTo then player:teleportTo(x, y, z)
    else
        player:setX(x); player:setY(y)
        if player.setZ then player:setZ(z) end
        local cell = getCell and getCell()
        local square = cell and cell:getGridSquare(home.x, home.y, home.z)
        if square and player.setCurrent then player:setCurrent(square) end
    end
    emit("HOUSEHOLD VIEWPOINT", string.format("host moved to shared home tile x=%d y=%d z=%d",
        tonumber(home.x) or 0, tonumber(home.y) or 0, tonumber(home.z) or 0))
    return true
end

local function positionGuestForSocial(targetId)
    return positionClientForSocial("nl-guest", targetId or "kenji")
end

pcall(require, "NL/HouseholdClient")

local function queueCareerWorldPickup(itemType, expected)
    local player = getSpecificPlayer(0)
    local square = player and player:getCurrentSquare()
    local worlds = square and square:getWorldObjects()
    if not player or not worlds then return 0 end
    local ok, err = pcall(function() require "TimedActions/ISInventoryTransferUtil" end)
    if not ok or not ISTimedActionQueue or not ISInventoryTransferUtil then
        emit("CAREER PICKUP FAILED", "vanilla transfer API unavailable error=" .. tostring(err))
        return 0
    end
    local queued = 0
    for index = 0, worlds:size() - 1 do
        if queued >= expected then break end
        local worldObject = worlds:get(index)
        local item = worldObject and worldObject:getItem()
        if item and item.getFullType and item:getFullType() == itemType then
            local source = item:getContainer()
            local action = source and ISInventoryTransferUtil.newInventoryTransferAction(
                player, item, source, player:getInventory())
            if action then
                ISTimedActionQueue.add(action)
                queued = queued + 1
            end
        end
    end
    NLQAMultiplayer.careerPickupAttempted = true
    NLQAMultiplayer.careerPickupNextAttempt = NLQAMultiplayer.socialFrame + 60
    NLQAMultiplayer.careerPickupExpected = expected
    NLQAMultiplayer.careerPickupItem = itemType
    emit("CAREER PICKUP QUEUED", "item=" .. tostring(itemType) .. " expected=" .. tostring(expected)
        .. " queued=" .. tostring(queued))
    return queued
end

-- QA-only clothing acquisition. The server seeds real vanilla clothing onto
-- the host's square; the host transfers it with the same action used by a
-- world-item click, then queues the production wear action before saving the
-- preset. No item or outfit enters the production package from this helper.
local function queueWardrobeWorldPickup(itemTypes, extra)
    local player = getSpecificPlayer(0)
    local square = player and player:getCurrentSquare()
    local worlds = square and square:getWorldObjects()
    if not player or not worlds then return 0 end
    local ok, err = pcall(function() require "TimedActions/ISInventoryTransferUtil" end)
    if not ok or not ISTimedActionQueue or not ISInventoryTransferUtil then
        emit("WARDROBE PICKUP FAILED", "vanilla transfer API unavailable error=" .. tostring(err))
        return 0
    end
    local wanted = {}
    for _, fullType in ipairs(itemTypes or {}) do wanted[fullType] = true end
    local queued = 0
    for index = 0, worlds:size() - 1 do
        local worldObject = worlds:get(index)
        local item = worldObject and worldObject:getItem()
        if item and item.getFullType and wanted[item:getFullType()] then
            local source = item:getContainer()
            local action = source and ISInventoryTransferUtil.newInventoryTransferAction(
                player, item, source, player:getInventory())
            if action then
                ISTimedActionQueue.add(action)
                queued = queued + 1
            end
        end
    end
    if extra then
        NLQAMultiplayer.wardrobeExtraPickupAttempted = true
        NLQAMultiplayer.wardrobeExtraPickupNextAttempt = NLQAMultiplayer.socialFrame + 60
    else
        NLQAMultiplayer.wardrobePickupAttempted = true
        NLQAMultiplayer.wardrobePickupNextAttempt = NLQAMultiplayer.socialFrame + 60
    end
    emit(extra and "WARDROBE EXTRA PICKUP QUEUED" or "WARDROBE PICKUP QUEUED", "expected=" .. tostring(#(itemTypes or {}))
        .. " queued=" .. tostring(queued))
    return queued
end

local function queueWardrobeExtraWear(itemType)
    local player = getSpecificPlayer(0)
    if not player or not player.getInventory then return 0 end
    local ok, err = pcall(function() require "TimedActions/ISWearClothing" end)
    if not ok or not ISTimedActionQueue or not ISWearClothing then
        emit("WARDROBE EXTRA WEAR FAILED", "vanilla wear API unavailable error=" .. tostring(err))
        return 0
    end
    local items = player:getInventory():getItems()
    local queued = 0
    if items and items.size and items.get then
        for index = 0, items:size() - 1 do
            local item = items:get(index)
            if item and item.getFullType and item:getFullType() == itemType then
                ISTimedActionQueue.add(ISWearClothing:new(player, item))
                queued = queued + 1
                break
            end
        end
    end
    NLQAMultiplayer.wardrobeExtraWearSent = true
    emit("WARDROBE EXTRA WEAR QUEUED", "item=" .. tostring(itemType)
        .. " queued=" .. tostring(queued))
    return queued
end

local function qaWornCount(player, fullType)
    if not player or not player.getWornItems then return 0 end
    local worn = player:getWornItems()
    if not worn or not worn.size or not worn.get then return 0 end
    local count = 0
    for index = 0, worn:size() - 1 do
        local wornItem = worn:get(index)
        local item = wornItem and wornItem.getItem and wornItem:getItem()
        if item and item.getFullType and item:getFullType() == fullType then
            count = count + 1
        end
    end
    return count
end

local function queueWardrobeWear(itemTypes)
    local player = getSpecificPlayer(0)
    if not player or not player.getInventory then return 0 end
    local ok, err = pcall(function() require "TimedActions/ISWearClothing" end)
    if not ok or not ISTimedActionQueue or not ISWearClothing then
        emit("WARDROBE WEAR FAILED", "vanilla wear API unavailable error=" .. tostring(err))
        return 0
    end
    local wanted = {}
    for _, fullType in ipairs(itemTypes or {}) do wanted[fullType] = true end
    local items = player:getInventory():getItems()
    local queued, used = 0, {}
    if items and items.size and items.get then
        for index = 0, items:size() - 1 do
            local item = items:get(index)
            if item and item.getFullType and wanted[item:getFullType()] and not used[item] then
                used[item] = true
                ISTimedActionQueue.add(ISWearClothing:new(player, item))
                queued = queued + 1
            end
        end
    end
    NLQAMultiplayer.wardrobeWearSent = true
    emit("WARDROBE WEAR QUEUED", "expected=" .. tostring(#(itemTypes or {}))
        .. " queued=" .. tostring(queued))
    return queued
end

local function queueWardrobeUnequip(itemTypes)
    local player = getSpecificPlayer(0)
    if not player or not player.getWornItems then return 0 end
    local ok, err = pcall(function() require "TimedActions/ISUnequipAction" end)
    if not ok or not ISTimedActionQueue or not ISUnequipAction then
        emit("WARDROBE UNEQUIP FAILED", "vanilla unequip API unavailable error=" .. tostring(err))
        return 0
    end
    local wanted = {}
    for _, fullType in ipairs(itemTypes or {}) do wanted[fullType] = true end
    local worn = player:getWornItems()
    local queued = 0
    if worn and worn.size and worn.get then
        for index = 0, worn:size() - 1 do
            local wornItem = worn:get(index)
            local item = wornItem and wornItem.getItem and wornItem:getItem()
            if item and item.getFullType and wanted[item:getFullType()] then
                ISTimedActionQueue.add(ISUnequipAction:new(player, item, 50))
                queued = queued + 1
            end
        end
    end
    NLQAMultiplayer.wardrobeUnequipAttempted = true
    NLQAMultiplayer.wardrobeUnequipNextAttempt = NLQAMultiplayer.socialFrame + 60
    if queued > 0 then NLQAMultiplayer.wardrobeUnequipSent = true end
    emit("WARDROBE UNEQUIP QUEUED", "expected=" .. tostring(#(itemTypes or {}))
        .. " queued=" .. tostring(queued))
    return queued
end

Events.OnServerCommand.Add(function(module, command, args)
    if module == "NeighborhoodQA" and command == "household_viewpoint" and type(args) == "table"
            and qaIdentity().username == "nl-guest" then
        local player = getSpecificPlayer(0)
        if player then
            local x = (tonumber(args.x) or player:getX()) + 0.5
            local y = (tonumber(args.y) or player:getY()) + 0.5
            local z = tonumber(args.z) or player:getZ()
            if player.teleportTo then player:teleportTo(x, y, z)
            else
                player:setX(x)
                player:setY(y)
                if player.setZ then player:setZ(z) end
            end
            local cell = getCell and getCell()
            local square = cell and cell:getGridSquare(args.x, args.y, args.z)
            if square and player.setCurrent then player:setCurrent(square) end
            emit("HOUSEHOLD VIEWPOINT", "guest moved to shared home tile x="
                .. tostring(args.x) .. " y=" .. tostring(args.y) .. " z=" .. tostring(args.z))
        end
    end
    if (module == "NeighborhoodLife" or module == "NeighborhoodSocial")
            and command == "snapshot" and type(args) == "table" then
        NLQAMultiplayer.snapshots = NLQAMultiplayer.snapshots + 1
        emit("SNAPSHOT", "username=" .. tostring(args.username) .. " revision=" .. tostring(args.revision)
            .. " snapshotCount=" .. tostring(NLQAMultiplayer.snapshots)
            .. " message=" .. tostring(args.message))
        if qaIdentity().username == "nl-host" and args.username == "nl-host" then
            local outfits = args.outfits or {}
            local pieces = outfits[1] and #outfits[1] or 0
            if pieces > 0 then
                NLQAMultiplayer.wardrobePersisted = true
                NLQAMultiplayer.wardrobeOutfits = outfits
                pcall(require, "NL/Wardrobe")
                local player = getSpecificPlayer(0)
                if NLWardrobe and NLWardrobe.applyProfile and player then
                    NLWardrobe.applyProfile(player, outfits)
                end
                if #NLQAMultiplayer.wardrobeItemTypes == 0 and outfits[1] then
                    for _, entry in ipairs(outfits[1]) do
                        local fullType = type(entry) == "table" and entry.fullType or entry
                        if fullType then NLQAMultiplayer.wardrobeItemTypes[#NLQAMultiplayer.wardrobeItemTypes + 1] = fullType end
                    end
                end
                if NLQAMultiplayer.wardrobeReplacementDue == 0 then
                    NLQAMultiplayer.wardrobeReplacementDue = NLQAMultiplayer.socialFrame + 90
                end
                if NLQAMultiplayer.wardrobeSnapshotRevision ~= args.revision then
                    NLQAMultiplayer.wardrobeSnapshotRevision = args.revision
                    NLQAMultiplayer.wardrobeSnapshotLogged = true
                    emit("WARDROBE SNAPSHOT", "slot=1 pieces=" .. tostring(pieces)
                        .. " revision=" .. tostring(args.revision))
                end
            end
        end
        if qaIdentity().username == "nl-host" and args.username == "nl-host"
                and not NLQAMultiplayer.wardrobeSaveSent
                and NLQAMultiplayer.wardrobeSaveDue == 0 then
            -- Keep the probe outside the production command adapter's
            -- duplicate-request window after refresh.
            NLQAMultiplayer.wardrobeSaveDue=NLQAMultiplayer.socialFrame+30
        end
        if qaIdentity().username == "nl-host" and args.username == "nl-host"
                and NLQAMultiplayer.careerDeliverSent and not NLQAMultiplayer.careerResultLogged
                and args.message and string.find(args.message,"Delivery complete",1,true) then
            NLQAMultiplayer.careerResultLogged=true
            NLQAMultiplayer.careerWorkDue=NLQAMultiplayer.socialFrame+30
            emit("CAREER RESULT", "delivery complete message="..tostring(args.message))
        end
        if qaIdentity().username == "nl-host" and args.username == "nl-host"
                and NLQAMultiplayer.careerWorkSent
                and not NLQAMultiplayer.careerWorkResultLogged
                and args.message and string.find(args.message,"career XP",1,true) then
            NLQAMultiplayer.careerWorkResultLogged=true
            emit("CAREER WORK RESULT", tostring(args.message))
        end
        if qaIdentity().username == "nl-host" and args.username == "nl-host"
                and not NLQAMultiplayer.careerWorkPersistedLogged
                and args.workedToday == true and args.careers
                and args.careers[args.career]
                and (tonumber(args.careers[args.career].shifts or 0) or 0) >= 1 then
            NLQAMultiplayer.careerWorkPersistedLogged=true
            emit("CAREER WORK RESTART SNAPSHOT", "career="..tostring(args.career)
                .." shifts="..tostring(args.careers[args.career].shifts)
                .." xp="..tostring(args.careers[args.career].xp)
                .." credits="..tostring(args.credits)
                .." workedToday="..tostring(args.workedToday))
        end
        if qaIdentity().username == "nl-host" and args.username == "nl-host"
                and not NLQAMultiplayer.inventoryGiveObserved and args.message
                and string.find(args.message,"Gave 1 Base.RippedSheets",1,true) then
            NLQAMultiplayer.inventoryGiveObserved=true
            NLQAMultiplayer.inventoryExchangeDue=NLQAMultiplayer.socialFrame+90
            emit("NPC INVENTORY GIVE RESULT", tostring(args.message))
        end
        if qaIdentity().username == "nl-host" and args.username == "nl-host"
                and not NLQAMultiplayer.inventoryRequestObserved and args.message
                and string.find(args.message,"Received 1 Base.RippedSheets",1,true) then
            NLQAMultiplayer.inventoryRequestObserved=true
            emit("NPC INVENTORY REQUEST RESULT", tostring(args.message))
        end
    if qaIdentity().username == "nl-host" and args.username == "nl-host"
                and not NLQAMultiplayer.inventoryMetadataLogged
                and (args.message and (string.find(args.message,"Gave 1 ",1,true)
                    or string.find(args.message,"Received 1 ",1,true))) then
            local neighbor=args.neighbors and args.neighbors[1]
            local entries={}
            for _,entry in ipairs((neighbor and neighbor.inventoryItems) or {}) do
                entries[#entries+1]=tostring(entry.item).."/"..tostring(entry.amount)
                    .."/"..tostring(entry.label)
            end
            NLQAMultiplayer.inventoryMetadataLogged=true
            emit("NPC INVENTORY ITEMS", #entries>0 and table.concat(entries,",") or "empty")
        end
        if qaIdentity().username=="nl-host" and args.username=="nl-host"
                and NLQAMultiplayer.inventoryRestartProbeSent
                and not NLQAMultiplayer.inventoryRestartObserved then
            local neighbor=args.neighbors and args.neighbors[1]
            local entries={}
            for _,entry in ipairs((neighbor and neighbor.inventoryItems) or {}) do
                entries[#entries+1]=tostring(entry.item).."/"..tostring(entry.amount)
                    .."/"..tostring(entry.label)
            end
            if #entries>0 then
                NLQAMultiplayer.inventoryRestartObserved=true
                emit("NPC INVENTORY RESTART SNAPSHOT", table.concat(entries,","))
            end
        end
        if qaIdentity().username == "nl-host" and args.username == "nl-host"
                and NLQAMultiplayer.careerSeeded then
            if not NLQAMultiplayer.careerSelectSent then
                NLQAMultiplayer.careerDue=NLQAMultiplayer.socialFrame+30
            elseif not NLQAMultiplayer.careerDeliverSent and NLQAMultiplayer.careerStage==1 then
                NLQAMultiplayer.careerDue=NLQAMultiplayer.socialFrame+30
            end
        end
    end
    if module == "NeighborhoodLife" and command == "presence" and type(args) == "table"
            and type(args.players) == "table" then
        NLQAMultiplayer.presenceCount = #args.players
        local names = {}
        for i, entry in ipairs(args.players) do
            names[#names + 1] = string.format("%s@%.2f,%.2f,%.0f", tostring(entry.username),
                tonumber(entry.x or 0), tonumber(entry.y or 0), tonumber(entry.z or 0))
        end
        emit("PRESENCE", "revision=" .. tostring(args.revision)
            .. " players=" .. tostring(NLQAMultiplayer.presenceCount)
            .. " names=" .. table.concat(names, ","))
    end
    if module == "NeighborhoodLife" and command == "npc_presence" and type(args) == "table"
            and type(args.npcs) == "table" then
        local rows={}
        local onlineHints=0
        for _,entry in ipairs(args.npcs) do
            local onlineId = tonumber(entry.onlineId)
            if onlineId and onlineId >= 0 then onlineHints = onlineHints + 1 end
            rows[#rows+1]=string.format("%s@%.2f,%.2f,%.0f/w%d", tostring(entry.id),
                tonumber(entry.x or 0), tonumber(entry.y or 0), tonumber(entry.z or 0),
                tonumber(entry.waypoint or 0)) .. "/online=" .. tostring(entry.onlineId)
        end
        emit("NPC PRESENCE", "revision="..tostring(args.revision)
            .." count="..tostring(#args.npcs).." onlineHints="..tostring(onlineHints)
            .." entries="..table.concat(rows, ","))
    end
    if module == "NeighborhoodSocial" and command == "event" and type(args) == "table" then
        emit("SOCIAL EVENT", "actor="..tostring(args.actor)
            .." action="..tostring(args.action)
            .." npc="..tostring(args.npcId)
            .." message="..tostring(args.message))
    end
    if module == "NeighborhoodSocial" and command == "snapshot" and type(args) == "table" then
        local rows={}
        for _,entry in ipairs(args.neighbors or {}) do
            rows[#rows+1]=string.format("%s/canInteract=%s/met=%s/friendship=%s",
                tostring(entry.id),tostring(entry.canInteract),
                tostring(entry.relation and entry.relation.met),
                tostring(entry.relation and entry.relation.friendship))
        end
        emit("SOCIAL SNAPSHOT", "message="..tostring(args.message)
            .." username="..tostring(args.username).." entries="..table.concat(rows, ","))
        local hostMet=false
        local hostEntry=nil
        for _,entry in ipairs(args.neighbors or {}) do
            if entry.id=="marisol" and entry.relation and entry.relation.met then hostMet=true end
            if entry.id==NLQAMultiplayer.socialTarget then hostEntry=entry end
        end
        if qaIdentity().username == "nl-host" and hostEntry
                and NLQAMultiplayer.socialActionSent and hostEntry.relation then
            local relation=hostEntry.relation
            local action=NLQAMultiplayer.socialActionName
            local nextAction=nil
            if action=="introduce" and relation.met then
                emit("SOCIAL STEP RESULT", "introduce met=true friendship="
                    ..tostring(relation.friendship).." trust="..tostring(relation.trust))
                nextAction="chat"
            elseif action=="chat" and (tonumber(relation.friendship or 0) or 0)>=12
                    and (tonumber(relation.trust or 0) or 0)>=5 then
                emit("SOCIAL STEP RESULT", "chat friendship="..tostring(relation.friendship)
                    .." trust="..tostring(relation.trust))
                nextAction="joke"
            elseif action=="joke" and (tonumber(relation.friendship or 0) or 0)>=16 then
                NLQAMultiplayer.socialConversationComplete=true
                NLQAMultiplayer.socialResultLogged=true
                NLQAMultiplayer.socialActionSent=false
                emit("SOCIAL CONVERSATION COMPLETE", "target="..tostring(NLQAMultiplayer.socialTarget)
                    .." friendship="..tostring(relation.friendship)
                    .." trust="..tostring(relation.trust))
            end
            if nextAction then
                NLQAMultiplayer.socialActionSent=false
                NLQAMultiplayer.socialActionName=nextAction
                NLQAMultiplayer.socialActionScheduled=true
                NLQAMultiplayer.socialActionPrepared=false
                NLQAMultiplayer.socialActionDue=NLQAMultiplayer.socialFrame
                    +NLQAMultiplayer.socialCooldownFrames
                emit("SOCIAL ACTION SCHEDULED", nextAction
                    .." id="..tostring(NLQAMultiplayer.socialTarget))
            end
        end
        if qaIdentity().username == "nl-guest" and hostEntry
                and NLQAMultiplayer.socialActionSent and hostEntry.relation then
            local relation=hostEntry.relation
            local action=NLQAMultiplayer.socialActionName
            if (action=="introduce" and relation.met)
                    or (action=="chat" and (tonumber(relation.friendship or 0) or 0)>=6) then
                NLQAMultiplayer.socialConversationComplete=true
                NLQAMultiplayer.socialResultLogged=true
                NLQAMultiplayer.socialActionSent=false
                emit("GUEST SOCIAL COMPLETE", "target="..tostring(NLQAMultiplayer.socialTarget)
                    .." friendship="..tostring(relation.friendship)
                    .." trust="..tostring(relation.trust))
            end
        end
    end
    if module == "NeighborhoodQA" and command == "wardrobe_seeded" and type(args) == "table"
            and qaIdentity().username == "nl-host" then
        NLQAMultiplayer.wardrobeSeeded = true
        NLQAMultiplayer.wardrobeItemTypes = args.items or {}
        NLQAMultiplayer.wardrobePickupAttempted = false
        NLQAMultiplayer.wardrobePickupObserved = false
        NLQAMultiplayer.wardrobePickupNextAttempt = NLQAMultiplayer.socialFrame
        queueWardrobeWorldPickup(NLQAMultiplayer.wardrobeItemTypes)
        emit("WARDROBE SEED ACK", "items=" .. table.concat(NLQAMultiplayer.wardrobeItemTypes, ","))
    end
    if module == "NeighborhoodQA" and command == "wardrobe_extra_seeded" and type(args) == "table"
            and qaIdentity().username == "nl-host" then
        NLQAMultiplayer.wardrobeExtraSeeded = true
        NLQAMultiplayer.wardrobeExtraType = args.item or "Base.Hat_Cowboy"
        NLQAMultiplayer.wardrobeExtraPickupAttempted = false
        NLQAMultiplayer.wardrobeExtraPickupObserved = false
        NLQAMultiplayer.wardrobeExtraPickupNextAttempt = NLQAMultiplayer.socialFrame
        queueWardrobeWorldPickup({NLQAMultiplayer.wardrobeExtraType}, true)
        emit("WARDROBE EXTRA SEED ACK", "item=" .. tostring(NLQAMultiplayer.wardrobeExtraType))
    end
    if module == "NeighborhoodQA" and command == "career_seeded" and type(args) == "table"
            and qaIdentity().username == "nl-host" then
        NLQAMultiplayer.careerSeeded=true
        NLQAMultiplayer.careerPickupAttempted=false
        NLQAMultiplayer.careerPickupObserved=false
        NLQAMultiplayer.careerPickupNextAttempt=NLQAMultiplayer.socialFrame
        NLQAMultiplayer.careerPickupExpected=tonumber(args.amount or 0) or 0
        NLQAMultiplayer.careerPickupItem=args.item
        queueCareerWorldPickup(NLQAMultiplayer.careerPickupItem,
            NLQAMultiplayer.careerPickupExpected)
        emit("CAREER SEED ACK", "item="..tostring(args.item).." amount="..tostring(args.amount))
    end
    if module == "NeighborhoodHousehold" and command == "invite" and type(args) == "table"
            and qaIdentity().username == "nl-guest" and not NLQAMultiplayer.householdAcceptSent then
        NLQAMultiplayer.householdAcceptSent=true
        emit("HOUSEHOLD INVITE", "from="..tostring(args.from).." id="..tostring(args.householdId))
        NLHouseholdClient.request(0,"accept")
        emit("HOUSEHOLD ACCEPT", "shared home")
    end
    if module == "NeighborhoodHousehold" and command == "snapshot" and type(args) == "table" then
        local home=args.household
        local members=home and home.members or {}
        emit("HOUSEHOLD SNAPSHOT", "username="..tostring(args.username)
            .." members="..tostring(#members).." furnishing="
            ..tostring(home and home.furnishing and home.furnishing.kind)
            .." furnishingTile="..tostring(home and home.furnishing and home.furnishing.x)
            ..","..tostring(home and home.furnishing and home.furnishing.y)
            ..","..tostring(home and home.furnishing and home.furnishing.z)
            .." message="..tostring(args.message))
        if qaIdentity().username=="nl-host" and home
                and not NLQAMultiplayer.householdCreatedObserved then
            NLQAMultiplayer.householdCreatedObserved=true
            NLQAMultiplayer.householdInviteDue=NLQAMultiplayer.socialFrame+30
        end
        if qaIdentity().username=="nl-guest" and #members>=2
                and not NLQAMultiplayer.householdJoinLogged then
            NLQAMultiplayer.householdJoinLogged=true
            emit("HOUSEHOLD JOIN RESULT", "shared home members="..tostring(#members))
        end
        if qaIdentity().username=="nl-host" and #members>=2
                and not NLQAMultiplayer.householdTaskSent then
            NLQAMultiplayer.householdMembersObserved=true
            NLQAMultiplayer.householdTaskDue=NLQAMultiplayer.socialFrame+60
        end
        if qaIdentity().username=="nl-host" and NLQAMultiplayer.householdStoreSent
                and not NLQAMultiplayer.householdStoreObserved and args.message
                and string.find(args.message,"used household storage",1,true) then
            NLQAMultiplayer.householdStoreObserved=true
            NLQAMultiplayer.householdTransferDue=NLQAMultiplayer.socialFrame+30
            NLQAMultiplayer.householdTaskDue=NLQAMultiplayer.socialFrame+60
            NLQAMultiplayer.householdFurnishingObserved=true
            emit("HOUSEHOLD FURNISHING RESULT", tostring(args.message))
        end
        if qaIdentity().username=="nl-host" and NLQAMultiplayer.householdStoreSent
                and not NLQAMultiplayer.householdStoreObserved and args.message
                and string.find(args.message,"Stand beside the household storage",1,true) then
            NLQAMultiplayer.householdStoreSent=false
            NLQAMultiplayer.householdFurnishingPrepared=false
            NLQAMultiplayer.householdFurnishingActionDue=NLQAMultiplayer.socialFrame+60
            emit("HOUSEHOLD FURNISHING RETRY", "server position was not beside the native object")
        end
        if qaIdentity().username=="nl-guest" and home
                and not NLQAMultiplayer.householdRetrieveSent
                and (home.storage and (home.storage["Base.RippedSheets"] or 0) > 0) then
            NLQAMultiplayer.householdRetrieveSent=true
            requestHouseholdFurnishing("retrieve")
            NLQAMultiplayer.householdFurnishingSent=true
            emit("HOUSEHOLD RETRIEVE", "Base.RippedSheets x1 source=production-world-menu-callback")
        elseif qaIdentity().username=="nl-guest" and NLQAMultiplayer.householdRetrieveSent
                and not NLQAMultiplayer.householdRetrieveObserved and args.message
                and string.find(args.message,"used household storage",1,true) then
            NLQAMultiplayer.householdRetrieveObserved=true
            emit("HOUSEHOLD FURNISHING RETRIEVE RESULT", tostring(args.message))
        end
        if qaIdentity().username=="nl-host" and home
                and NLQAMultiplayer.householdTransferSent
                and not NLQAMultiplayer.householdTransferObserved
                and home.owner == "nl-guest" then
            NLQAMultiplayer.householdTransferObserved=true
            emit("HOUSEHOLD TRANSFER RESULT", "owner=" .. tostring(home.owner)
                .. " members=" .. tostring(#members))
        end
        if qaIdentity().username=="nl-host" and NLQAMultiplayer.householdTaskSent
                and not NLQAMultiplayer.householdResultLogged and args.message
                and string.find(args.message,"complete",1,true) then
            NLQAMultiplayer.householdResultLogged=true
            emit("HOUSEHOLD TASK RESULT", tostring(args.message))
        end
    end
end)

-- QA-only appearance probe. It drives the production server command and then
-- checks the returned profile against the local native HumanVisual state.
-- This helper is never copied into the production package.
Events.OnRenderTick.Add(function()
    if not isClient() or NLQAMultiplayer.appearanceSelected
            or NLQAMultiplayer.snapshots == 0 then return end
    local expected = qaAppearancePreset()
    if not NLQAMultiplayer.appearanceSelectSent then
        if NLQAMultiplayer.appearanceDue == 0 then
            NLQAMultiplayer.appearanceDue = NLQAMultiplayer.socialFrame + 30
            emit("APPEARANCE SCHEDULED", "preset=" .. expected)
        elseif NLQAMultiplayer.socialFrame >= NLQAMultiplayer.appearanceDue then
            NLClient.request(0, "appearance_select", { preset = expected })
            NLQAMultiplayer.appearanceSelectSent = true
            emit("APPEARANCE SELECT", "preset=" .. expected .. " source=production-command")
        end
        return
    end
    local profile = NLClient.profiles and NLClient.profiles[0]
    if not profile or not profile.appearance or profile.appearance.preset ~= expected then return end
    local player = getSpecificPlayer(0)
    local applied = false
    local hair = "unavailable"
    if player and player.getModData then
        local data = player:getModData()
        applied = data and data.NeighborhoodAppearance == expected
    end
    if player and player.getHumanVisual then
        local visual = player:getHumanVisual()
        if visual and visual.getHairModel then
            local ok, value = pcall(visual.getHairModel, visual)
            if ok and value then hair = tostring(value) end
        end
    end
    NLQAMultiplayer.appearanceSelected = true
    emit("APPEARANCE APPLIED", "preset=" .. expected
        .. " localModData=" .. tostring(applied) .. " hair=" .. hair)
end)

-- QA-only world-body conversation probe. The host starts beside the persisted
-- neighborhood slice and completes introduce -> chat -> joke through the real
-- production social command. The guest requests the same snapshot from its
-- separate position; its result remains proximity-gated rather than being
-- fabricated locally.
Events.OnRenderTick.Add(function()
    if not isClient() or not NLSocialClient then return end
    NLQAMultiplayer.socialFrame=NLQAMultiplayer.socialFrame+1
    if qaIdentity().username=="nl-host"
            and not NLQAMultiplayer.inventoryRestartProbeSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.inventoryRestartDue then
        NLSocialClient.request(0,"refresh")
        NLQAMultiplayer.inventoryRestartProbeSent=true
        emit("NPC INVENTORY RESTART REFRESH", "connection="..tostring(NLQAMultiplayer.connectionCount))
    end
    if NLQAMultiplayer.socialFrame>=840 and not NLQAMultiplayer.socialPositioned then
        if qaIdentity().username=="nl-host" then
            positionHostForSocial()
        else
            positionGuestForSocial("kenji")
        end
    end
    if qaIdentity().username=="nl-host" and not NLQAMultiplayer.householdResetSent then
        local player=getSpecificPlayer(0)
        if player then
            sendClientCommand(player,"NeighborhoodQA","reset_household",{})
            NLQAMultiplayer.householdResetSent=true
            emit("HOUSEHOLD RESET", "isolated QA setup")
        end
    end
    -- The household vertical slice can run independently of the longer career
    -- probe. This keeps the actual storage furnishing check repeatable after a
    -- persisted career restart while still using the production command path.
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.householdResetSent
            and NLQAMultiplayer.snapshots>0
            and not NLQAMultiplayer.householdCreateSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.householdDirectCreateDue then
        NLQAMultiplayer.householdCreateSent=true
        NLHouseholdClient.request(0,"create")
        emit("HOUSEHOLD CREATE", "Neighborhood Home source=direct-vertical-slice")
    end
    if NLQAMultiplayer.socialFrame>=900 and NLQAMultiplayer.socialPositioned
            and not NLQAMultiplayer.socialRefreshSent then
        NLSocialClient.request(0,"refresh")
        NLQAMultiplayer.socialRefreshSent=true
        emit("SOCIAL REFRESH", qaIdentity().username or "?")
    end
    if NLQAMultiplayer.socialRefreshSent and not NLQAMultiplayer.socialActionSent
            and not NLQAMultiplayer.socialConversationComplete
            and NLSocialClient.snapshots[0] then
        local snapshot=NLSocialClient.snapshots[0]
        if qaIdentity().username=="nl-host" then
            if not NLQAMultiplayer.socialActionScheduled then
                for _,entry in ipairs(snapshot.neighbors or {}) do
                    if entry.canInteract then
                        NLQAMultiplayer.socialTarget=entry.id
                        NLQAMultiplayer.socialActionName=(entry.relation and entry.relation.met)
                            and "chat" or "introduce"
                        NLQAMultiplayer.socialActionDue=NLQAMultiplayer.socialFrame
                            +NLQAMultiplayer.socialCooldownFrames
                        NLQAMultiplayer.socialActionPrepared=false
                        NLQAMultiplayer.socialActionScheduled=true
                        emit("SOCIAL ACTION SCHEDULED", NLQAMultiplayer.socialActionName
                            .." id="..tostring(entry.id))
                        break
                    end
                end
            elseif not NLQAMultiplayer.socialActionPrepared
                    and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.socialActionDue-60 then
                NLQAMultiplayer.socialActionPrepared=positionHostForSocial(
                    NLQAMultiplayer.socialTarget)
            elseif NLQAMultiplayer.socialActionPrepared
                    and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.socialActionDue then
                NLSocialClient.request(0,"interact",
                    {id=NLQAMultiplayer.socialTarget,action=NLQAMultiplayer.socialActionName})
                NLQAMultiplayer.socialActionSent=true
                NLQAMultiplayer.socialActionScheduled=false
                NLQAMultiplayer.socialActionCount=NLQAMultiplayer.socialActionCount+1
                emit("SOCIAL ACTION", tostring(NLQAMultiplayer.socialActionName)
                    .." id="..tostring(NLQAMultiplayer.socialTarget)
                    .." step="..tostring(NLQAMultiplayer.socialActionCount))
            end
        else
            if not NLQAMultiplayer.socialActionScheduled then
                local target=nil
                for _,entry in ipairs(snapshot.neighbors or {}) do
                    if entry.id=="kenji" and entry.canInteract then
                        target=entry
                        break
                    end
                end
                if target then
                    NLQAMultiplayer.socialTarget=target.id
                    NLQAMultiplayer.socialActionName=(target.relation and target.relation.met)
                        and "chat" or "introduce"
                    NLQAMultiplayer.socialActionDue=NLQAMultiplayer.socialFrame
                        +NLQAMultiplayer.socialCooldownFrames
                    NLQAMultiplayer.socialActionPrepared=false
                    NLQAMultiplayer.socialActionScheduled=true
                    emit("GUEST SOCIAL ACTION SCHEDULED",
                        NLQAMultiplayer.socialActionName.." id="..tostring(target.id))
                end
            elseif not NLQAMultiplayer.socialActionPrepared
                    and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.socialActionDue-60 then
                NLQAMultiplayer.socialActionPrepared=positionGuestForSocial(
                    NLQAMultiplayer.socialTarget)
            elseif NLQAMultiplayer.socialActionPrepared
                    and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.socialActionDue then
                NLSocialClient.request(0,"interact",
                    {id=NLQAMultiplayer.socialTarget,action=NLQAMultiplayer.socialActionName})
                NLQAMultiplayer.socialActionSent=true
                NLQAMultiplayer.socialActionScheduled=false
                NLQAMultiplayer.socialActionCount=NLQAMultiplayer.socialActionCount+1
                emit("GUEST SOCIAL ACTION", NLQAMultiplayer.socialActionName
                    .." id="..tostring(NLQAMultiplayer.socialTarget)
                    .." step="..tostring(NLQAMultiplayer.socialActionCount))
            end
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.snapshots > 0
            and not NLQAMultiplayer.wardrobeSeedSent then
        local player=getSpecificPlayer(0)
        if player then
            sendClientCommand(player,"NeighborhoodQA","seed_wardrobe",{})
            NLQAMultiplayer.wardrobeSeedSent=true
            emit("WARDROBE SEED REQUEST", "vanilla clothing on current square")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeSeeded
            and not NLQAMultiplayer.wardrobePickupObserved
            and (not NLQAMultiplayer.wardrobePickupAttempted
                or NLQAMultiplayer.socialFrame>=NLQAMultiplayer.wardrobePickupNextAttempt) then
        NLQAMultiplayer.wardrobePickupAttempted=false
        queueWardrobeWorldPickup(NLQAMultiplayer.wardrobeItemTypes)
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeSeeded
            and not NLQAMultiplayer.wardrobePickupObserved then
        local player=getSpecificPlayer(0)
        local complete=true
        local counts={}
        for _, fullType in ipairs(NLQAMultiplayer.wardrobeItemTypes) do
            local count=qaInventoryCount(player, fullType)
            counts[#counts+1]=fullType.."="..tostring(count)
            if count < 1 then complete=false end
        end
        if complete and #NLQAMultiplayer.wardrobeItemTypes > 0 then
            NLQAMultiplayer.wardrobePickupObserved=true
            NLQAMultiplayer.wardrobeWearDue=NLQAMultiplayer.socialFrame+30
            emit("WARDROBE PICKUP COMPLETE", table.concat(counts, ",")
                .. " source=world-transfer-action")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobePickupObserved
            and not NLQAMultiplayer.wardrobeWearSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.wardrobeWearDue then
        queueWardrobeWear(NLQAMultiplayer.wardrobeItemTypes)
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeWearSent
            and not NLQAMultiplayer.wardrobeWearObserved then
        local player=getSpecificPlayer(0)
        local complete=true
        local counts={}
        for _, fullType in ipairs(NLQAMultiplayer.wardrobeItemTypes) do
            local count=qaWornCount(player, fullType)
            counts[#counts+1]=fullType.."="..tostring(count)
            if count < 1 then complete=false end
        end
        if complete and #NLQAMultiplayer.wardrobeItemTypes > 0 then
            NLQAMultiplayer.wardrobeWearObserved=true
            NLQAMultiplayer.wardrobeSaveDue=NLQAMultiplayer.socialFrame+30
            emit("WARDROBE WORN COMPLETE", table.concat(counts, ",")
                .. " source=vanilla-wear-action")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobePersisted
            and not NLQAMultiplayer.wardrobeExtraSeedSent then
        local player=getSpecificPlayer(0)
        if player then
            sendClientCommand(player,"NeighborhoodQA","seed_wardrobe_extra",{})
            NLQAMultiplayer.wardrobeExtraSeedSent=true
            emit("WARDROBE EXTRA SEED REQUEST", "item=Base.Hat_Cowboy after-snapshot")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeExtraSeeded
            and not NLQAMultiplayer.wardrobeExtraPickupObserved
            and (not NLQAMultiplayer.wardrobeExtraPickupAttempted
                or NLQAMultiplayer.socialFrame>=NLQAMultiplayer.wardrobeExtraPickupNextAttempt) then
        NLQAMultiplayer.wardrobeExtraPickupAttempted=false
        queueWardrobeWorldPickup({NLQAMultiplayer.wardrobeExtraType}, true)
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeExtraSeeded
            and not NLQAMultiplayer.wardrobeExtraPickupObserved then
        local player=getSpecificPlayer(0)
        if qaInventoryCount(player, NLQAMultiplayer.wardrobeExtraType) > 0 then
            NLQAMultiplayer.wardrobeExtraPickupObserved=true
            NLQAMultiplayer.wardrobeExtraWearDue=NLQAMultiplayer.socialFrame+30
            emit("WARDROBE EXTRA PICKUP COMPLETE", "item="
                .. tostring(NLQAMultiplayer.wardrobeExtraType)
                .. " source=world-transfer-action")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeExtraPickupObserved
            and not NLQAMultiplayer.wardrobeExtraWearSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.wardrobeExtraWearDue then
        queueWardrobeExtraWear(NLQAMultiplayer.wardrobeExtraType)
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeExtraWearSent
            and not NLQAMultiplayer.wardrobeExtraWearObserved then
        local player=getSpecificPlayer(0)
        if qaWornCount(player, NLQAMultiplayer.wardrobeExtraType) > 0 then
            NLQAMultiplayer.wardrobeExtraWearObserved=true
            NLQAMultiplayer.wardrobeReplacementDue=NLQAMultiplayer.socialFrame+30
            emit("WARDROBE EXTRA WORN COMPLETE", "item="
                .. tostring(NLQAMultiplayer.wardrobeExtraType)
                .. " source=vanilla-wear-action")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeReplacementDue > 0
            and NLQAMultiplayer.wardrobeExtraWearObserved
            and not NLQAMultiplayer.wardrobeUnequipObserved
            and (not NLQAMultiplayer.wardrobeUnequipAttempted
                or NLQAMultiplayer.socialFrame>=NLQAMultiplayer.wardrobeUnequipNextAttempt) then
        NLQAMultiplayer.wardrobeUnequipAttempted=false
        queueWardrobeUnequip(NLQAMultiplayer.wardrobeItemTypes)
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeUnequipSent
            and not NLQAMultiplayer.wardrobeUnequipObserved then
        local player=getSpecificPlayer(0)
        local complete=true
        local counts={}
        for _, fullType in ipairs(NLQAMultiplayer.wardrobeItemTypes) do
            local count=qaWornCount(player, fullType)
            counts[#counts+1]=fullType.."="..tostring(count)
            if count > 0 then complete=false end
        end
        if complete and #NLQAMultiplayer.wardrobeItemTypes > 0 then
            NLQAMultiplayer.wardrobeUnequipObserved=true
            NLQAMultiplayer.wardrobeAutoRemovalBefore = qaWornCount(
                player, NLQAMultiplayer.wardrobeExtraType)
            NLQAMultiplayer.wardrobeReplacementDue=NLQAMultiplayer.socialFrame+30
            emit("WARDROBE UNEQUIP COMPLETE", table.concat(counts, ",")
                .. " source=vanilla-unequip-action extraBefore="
                .. tostring(NLQAMultiplayer.wardrobeAutoRemovalBefore))
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeUnequipObserved
            and not NLQAMultiplayer.wardrobeReplacementSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.wardrobeReplacementDue then
        pcall(require, "NL/Wardrobe")
        local player=getSpecificPlayer(0)
        if NLWardrobe and NLWardrobe.wear and player then
            NLWardrobe.wear(player, 1)
            NLQAMultiplayer.wardrobeReplacementSent=true
            emit("WARDROBE REPLACEMENT REQUEST", "slot=1 source=production-NLWardrobe.wear")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.wardrobeReplacementSent
            and not NLQAMultiplayer.wardrobeReplacementObserved then
        local player=getSpecificPlayer(0)
        local complete=true
        local counts={}
        for _, fullType in ipairs(NLQAMultiplayer.wardrobeItemTypes) do
            local count=qaWornCount(player, fullType)
            counts[#counts+1]=fullType.."="..tostring(count)
            if count < 1 then complete=false end
        end
        if complete and #NLQAMultiplayer.wardrobeItemTypes > 0 then
            NLQAMultiplayer.wardrobeReplacementObserved=true
            NLQAMultiplayer.wardrobeAutoRemovalAfter = qaWornCount(
                player, NLQAMultiplayer.wardrobeExtraType)
            emit("WARDROBE REPLACEMENT COMPLETE", table.concat(counts, ",")
                .. " source=production-NLWardrobe.wear extraAfter="
                .. tostring(NLQAMultiplayer.wardrobeAutoRemovalAfter))
            if NLQAMultiplayer.wardrobeAutoRemovalBefore > 0
                    and NLQAMultiplayer.wardrobeAutoRemovalAfter == 0 then
                emit("WARDROBE AUTOMATIC LAYER REMOVAL", "item="
                    .. tostring(NLQAMultiplayer.wardrobeExtraType)
                    .. " before=" .. tostring(NLQAMultiplayer.wardrobeAutoRemovalBefore)
                    .. " after=" .. tostring(NLQAMultiplayer.wardrobeAutoRemovalAfter)
                    .. " source=production-NLWardrobe.wear")
            else
                emit("WARDROBE AUTOMATIC LAYER REMOVAL NOT PROVEN", "before="
                    .. tostring(NLQAMultiplayer.wardrobeAutoRemovalBefore)
                    .. " after=" .. tostring(NLQAMultiplayer.wardrobeAutoRemovalAfter))
            end
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.socialResultLogged
            and not NLQAMultiplayer.careerSeedSent then
        local player=getSpecificPlayer(0)
        if player then
            sendClientCommand(player,"NeighborhoodQA","seed_inventory",{career="medic"})
            NLQAMultiplayer.careerSeedSent=true
            emit("CAREER SEED REQUEST", "medic")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.careerSeeded
            and not NLQAMultiplayer.careerPickupObserved
            and (not NLQAMultiplayer.careerPickupAttempted
                or NLQAMultiplayer.socialFrame>=NLQAMultiplayer.careerPickupNextAttempt) then
        NLQAMultiplayer.careerPickupAttempted=false
        queueCareerWorldPickup(NLQAMultiplayer.careerPickupItem,
            NLQAMultiplayer.careerPickupExpected)
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.careerSeeded
            and not NLQAMultiplayer.careerPickupObserved then
        local player=getSpecificPlayer(0)
        local count=qaInventoryCount(player, NLQAMultiplayer.careerPickupItem)
        if count>=NLQAMultiplayer.careerPickupExpected
                and NLQAMultiplayer.careerPickupExpected>0 then
            NLQAMultiplayer.careerPickupObserved=true
            NLQAMultiplayer.careerDue=NLQAMultiplayer.socialFrame+30
            emit("CAREER PICKUP COMPLETE", "item="..tostring(NLQAMultiplayer.careerPickupItem)
                .. " localInventory="..tostring(count)
                .. " source=world-transfer-action")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.careerPickupObserved
            and NLQAMultiplayer.socialPositioned
            and not NLQAMultiplayer.inventoryGiveSent then
        NLSocialClient.request(0,"give",
            {id="marisol",item="Base.RippedSheets",amount=1})
        NLQAMultiplayer.inventoryGiveSent=true
        emit("NPC INVENTORY GIVE", "id=marisol item=Base.RippedSheets amount=1")
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.inventoryGiveObserved
            and not NLQAMultiplayer.inventoryRequestSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.inventoryExchangeDue then
        NLSocialClient.request(0,"request",
            {id="marisol",item="Base.RippedSheets",amount=1})
        NLQAMultiplayer.inventoryRequestSent=true
        emit("NPC INVENTORY REQUEST", "id=marisol item=Base.RippedSheets amount=1")
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.careerSeeded
            and NLQAMultiplayer.careerPickupObserved
            and not NLQAMultiplayer.careerSelectSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.careerDue then
        NLClient.request(0,"select",{career="medic"})
        NLQAMultiplayer.careerSelectSent=true
        NLQAMultiplayer.careerStage=1
        NLQAMultiplayer.careerDue=NLQAMultiplayer.socialFrame+30
        emit("CAREER SELECT", "medic")
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.careerSelectSent
            and not NLQAMultiplayer.careerDeliverSent
            and NLQAMultiplayer.careerStage==1
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.careerDue then
        local profile=NLClient.profiles[0]
        local contract=profile and NLDomain.contracts(profile)[1]
        if contract then
            NLClient.request(0,"deliver",{id=contract.id})
            NLQAMultiplayer.careerDeliverSent=true
            NLQAMultiplayer.careerStage=2
            emit("CAREER DELIVERY", "id="..tostring(contract.id))
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.careerResultLogged
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.careerWorkDue
            and not NLQAMultiplayer.careerWorkSent then
        NLClient.request(0,"work",{})
        NLQAMultiplayer.careerWorkSent=true
        emit("CAREER WORK", "shift")
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.careerWorkResultLogged
            and not NLQAMultiplayer.householdCreateSent then
        NLQAMultiplayer.householdCreateSent=true
        NLHouseholdClient.request(0,"create")
        emit("HOUSEHOLD CREATE", "Neighborhood Home")
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.householdCreatedObserved
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.householdInviteDue
            and not NLQAMultiplayer.householdInviteSent then
        local presence=NLClient.presence
        for _,entry in ipairs((presence and presence.players) or {}) do
            if entry.username and entry.username~="nl-host" then
                NLQAMultiplayer.householdInviteSent=true
                NLHouseholdClient.request(0,"invite",{target=entry.username})
                emit("HOUSEHOLD INVITE SENT", "target="..tostring(entry.username))
                break
            end
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.householdMembersObserved
            and not NLQAMultiplayer.householdStoreSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.householdTaskDue then
        if not NLQAMultiplayer.householdFurnishingPrepared then
            NLQAMultiplayer.householdFurnishingPrepared=positionHostForHousehold()
            NLQAMultiplayer.householdFurnishingActionDue=NLQAMultiplayer.socialFrame+30
            emit("HOUSEHOLD FURNISHING PREPARED", "waiting for server position sync")
        elseif NLQAMultiplayer.socialFrame>=NLQAMultiplayer.householdFurnishingActionDue then
            NLQAMultiplayer.householdStoreSent=true
            requestHouseholdFurnishing("store")
            NLQAMultiplayer.householdFurnishingSent=true
            emit("HOUSEHOLD FURNISHING", "store Base.RippedSheets x1 source=production-world-menu-callback")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.householdStoreObserved
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.householdTransferDue
            and not NLQAMultiplayer.householdTransferSent then
        NLQAMultiplayer.householdTransferSent=true
        NLHouseholdClient.request(0,"transfer",{target="nl-guest"})
        emit("HOUSEHOLD TRANSFER", "target=nl-guest")
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.householdStoreObserved
            and not NLQAMultiplayer.householdTaskSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.householdTaskDue then
        NLQAMultiplayer.householdTaskSent=true
        NLHouseholdClient.request(0,"task",{task="tidy"})
        emit("HOUSEHOLD TASK", "tidy")
    end
end)

-- Keep the discovery probe beside the already-loaded multiplayer logger. Some
-- Build 42 profiles enumerate only the original QA client script during a
-- reconnect, while this same callback is guaranteed to survive that path.
local function remoteObjectDetail(object, localPlayer)
    if not object or not object.getUsername then return nil end
    local ok, username = pcall(object.getUsername, object)
    if not ok or not username or username == "" then return nil end
    if object == localPlayer then return "local=" .. tostring(username) end
    local function value(method, fallback)
        if not object[method] then return fallback end
        local good, result = pcall(object[method], object)
        return good and result or fallback
    end
    return string.format("username=%s x=%.2f y=%.2f z=%.0f",
        tostring(username), tonumber(value("getX", 0)),
        tonumber(value("getY", 0)), tonumber(value("getZ", 0)))
end

local function scanList(label, players, localPlayer)
    if not players then return label .. "=absent" end
    local ok, count = pcall(players.size, players)
    if not ok then
        local entries = {}
        for _, object in pairs(players) do
            local detailOk, detail = pcall(remoteObjectDetail, object, localPlayer)
            if detailOk and detail then entries[#entries + 1] = detail end
        end
        return label .. "Table [" .. table.concat(entries, " | ") .. "]"
    end
    local found = {}
    for i = 0, count - 1 do
        local itemOk, object = pcall(players.get, players, i)
        if itemOk then
            local detailOk, detail = pcall(remoteObjectDetail, object, localPlayer)
            if detailOk and detail then found[#found + 1] = detail end
        end
    end
    return string.format("%sCount=%d [%s]", label, count, table.concat(found, " | "))
end

local function scanRemoteObjects()
    local player = getSpecificPlayer(0)
    local details = {}
    local ok, players = pcall(function() return IsoPlayer.getPlayers() end)
    details[#details + 1] = ok and scanList("IsoPlayer", players, player)
        or "IsoPlayer=error:" .. tostring(players)
    local clientOk, client = pcall(function() return GameClient and GameClient.instance end)
    if clientOk and client then
        local listOk, list = pcall(client.getPlayers, client)
        details[#details + 1] = listOk and scanList("GameClientPlayers", list, player)
            or "GameClientPlayers=error:" .. tostring(list)
        local connectedOk, connected = pcall(client.getConnectedPlayers, client)
        details[#details + 1] = connectedOk and scanList("ConnectedPlayers", connected, player)
            or "ConnectedPlayers=error:" .. tostring(connected)
    else
        details[#details + 1] = "GameClient=unavailable"
    end
    local cellOk, cell = pcall(getCell)
    if cellOk and cell then
        local remoteOk, remote = pcall(cell.getRemoteSurvivorList, cell)
        details[#details + 1] = remoteOk and scanList("RemoteSurvivors", remote, player)
            or "RemoteSurvivors=error:" .. tostring(remote)
        local luaListOk, luaList = pcall(cell.getObjectListForLua, cell)
        details[#details + 1] = luaListOk and scanList("ObjectListForLua", luaList, player)
            or "ObjectListForLua=error:" .. tostring(luaList)
        local npcReplicas=0
        local remoteReplicas=0
        local householdFurnishings=0
        if luaListOk and luaList then
            local listCountOk,listCount=pcall(luaList.size,luaList)
            if listCountOk then
                for i=0,listCount-1 do
                    local objectOk,object=pcall(luaList.get,luaList,i)
                    if objectOk and object and object.getModData then
                        local dataOk,data=pcall(object.getModData,object)
                        if dataOk and data and data.NeighborhoodNpcId then npcReplicas=npcReplicas+1 end
                        if dataOk and data and data.NeighborhoodRemotePlayerId then remoteReplicas=remoteReplicas+1 end
                        if dataOk and data and data.NeighborhoodHouseholdFurnishing then
                            householdFurnishings=householdFurnishings+1
                        end
                    end
                end
            end
        end
        details[#details + 1] = "productionNpcReplicas=" .. tostring(npcReplicas)
        details[#details + 1] = "productionRemoteReplicas=" .. tostring(remoteReplicas)
        details[#details + 1] = "productionHouseholdFurnishings=" .. tostring(householdFurnishings)
        local furnishingClientCount, furnishingPendingCount = 0, 0
        if NLHouseholdFurnishingClient then
            for _ in pairs(NLHouseholdFurnishingClient.objects or {}) do furnishingClientCount = furnishingClientCount + 1 end
            for _ in pairs(NLHouseholdFurnishingClient.pending or {}) do furnishingPendingCount = furnishingPendingCount + 1 end
        end
        details[#details + 1] = "productionHouseholdFurnishingClient=" .. tostring(furnishingClientCount)
            .. " productionHouseholdFurnishingPending=" .. tostring(furnishingPendingCount)
        -- QA-only packet diagnosis: list every object at the shared-home tile
        -- so a native AddItemToMap object without household ModData cannot be
        -- mistaken for the production snapshot replica.
        local tileOk, tile = pcall(cell.getGridSquare, cell, 8282, 11720, 1)
        if tileOk and tile and tile.getObjects then
            local objectOk, objects = pcall(tile.getObjects, tile)
            if objectOk and objects and objects.size and objects.get then
                local tileObjects = {}
                local nativeFurnishings = 0
                for i = 0, objects:size() - 1 do
                    local item = objects:get(i)
                    local function objectValue(method, fallback)
                        if not item or not item[method] then return fallback end
                        local valueOk, value = pcall(item[method], item)
                        return valueOk and value or fallback
                    end
                    local modData = item and item.getModData and item:getModData() or nil
                    if modData and modData.NeighborhoodHouseholdFurnishing then
                        nativeFurnishings = nativeFurnishings + 1
                    end
                    tileObjects[#tileObjects + 1] = tostring(objectValue("getName", "?"))
                        .. "/" .. tostring(objectValue("getSpriteName", "?"))
                        .. "/household=" .. tostring(modData and modData.NeighborhoodHouseholdFurnishing or "none")
                end
                details[#details + 1] = "qaHouseholdNativeFurnishings=" .. tostring(nativeFurnishings)
                details[#details + 1] = "qaHouseholdTileObjects=" .. table.concat(tileObjects, ";")
            end
        end
    end
    if type(getOnlinePlayers) == "function" then
        local onlineOk, online = pcall(getOnlinePlayers)
        details[#details + 1] = onlineOk and scanList("OnlinePlayers", online, player)
            or "OnlinePlayers=error:" .. tostring(online)
    else
        details[#details + 1] = "OnlinePlayers=unavailable"
    end
    local markerCount = 0
    local presenceMarkerCount = 0
    local nativePathCount = 0
    local fallbackReplicaCount = 0
    if NLPlumbob and NLPlumbob.instances then
        for id, _ in pairs(NLPlumbob.instances) do
            if string.sub(id, 1, 7) == "remote:" then markerCount = markerCount + 1 end
            if string.sub(id, 1, 9) == "presence:" then presenceMarkerCount = presenceMarkerCount + 1 end
        end
    end
    if NLNpcClient and NLNpcClient.bodies then
        for id, _ in pairs(NLNpcClient.bodies) do
            if NLNpcClient.modes and NLNpcClient.modes[id] == "native" then
                nativePathCount = nativePathCount + 1
            elseif NLNpcClient.modes and NLNpcClient.modes[id] == "fallback" then
                fallbackReplicaCount = fallbackReplicaCount + 1
            end
        end
    end
    details[#details + 1] = "productionRemoteMarkers=" .. tostring(markerCount)
    details[#details + 1] = "productionPresenceMarkers=" .. tostring(presenceMarkerCount)
    details[#details + 1] = "productionNpcNativePaths=" .. tostring(nativePathCount)
    details[#details + 1] = "productionNpcFallbackReplicas=" .. tostring(fallbackReplicaCount)
    emit("REMOTE SCAN", table.concat(details, " "))
end

Events.OnRenderTick.Add(function()
    if not isClient() or NLQAMultiplayer.remoteScanLogged then return end
    NLQAMultiplayer.remoteScanFrame = NLQAMultiplayer.remoteScanFrame + 1
    if NLQAMultiplayer.remoteScanFrame >= 300 then
        NLQAMultiplayer.remoteScanFrame = 0
        NLQAMultiplayer.remoteScanCount = NLQAMultiplayer.remoteScanCount + 1
        scanRemoteObjects()
        if NLQAMultiplayer.remoteScanCount >= 8 then
            NLQAMultiplayer.remoteScanLogged = true
        end
    end
end)

-- QA-only zombie stimulus. The server creates one real zombie beside Marisol
-- after the production native NPCs exist; the production authority must detect
-- it and retreat without relying on a client-side mock or teleport.
Events.OnRenderTick.Add(function()
    if not isClient() or NLQAMultiplayer.dangerProbeSent
            or qaIdentity().username ~= "nl-host" then return end
    if not NLNpcClient or not NLNpcClient.bodies or not NLNpcClient.bodies.marisol then return end
    local player = getSpecificPlayer(0)
    if not player then return end
    sendClientCommand(player, "NeighborhoodQA", "danger_probe", {})
    NLQAMultiplayer.dangerProbeSent = true
    emit("DANGER PROBE SENT", "target=marisol source=server-zombie")
end)

-- Prefer a real player walk to exercise Build 42 streaming. If the engine does
-- not unload the NPC body after the walk, retain the explicit local-removal
-- probe below as a separate compatibility check rather than conflating them.
Events.OnRenderTick.Add(function()
    if not isClient() or qaIdentity().username ~= "nl-host" or NLQAMultiplayer.streamWalkObserved
            or NLQAMultiplayer.streamProbeObserved then return end
    if not NLQAMultiplayer.streamWalkSent then
        NLQAMultiplayer.streamWalkFrame = NLQAMultiplayer.streamWalkFrame + 1
        if NLQAMultiplayer.streamWalkFrame >= 600 then queueStreamWalk() end
        return
    end
    NLQAMultiplayer.streamWalkFrame = NLQAMultiplayer.streamWalkFrame + 1
    if NLQAMultiplayer.streamWalkFrame % 240 == 0 and NLQAMultiplayer.streamWalkStep < 12 then
        queueStreamWalk()
    end
    local player = getSpecificPlayer(0)
    local body = NLNpcClient and NLNpcClient.bodies and NLNpcClient.bodies.kenji
    local originX = NLQAMultiplayer.streamWalkOriginX
    if not player or not originX or math.abs(player:getX() - originX) < 8 then return end
    local present = body and NLNpcClient.bodyPresent and NLNpcClient.bodyPresent(body) or false
    if not NLQAMultiplayer.streamWalkCheckLogged or NLQAMultiplayer.streamWalkFrame % 120 == 0 then
        NLQAMultiplayer.streamWalkCheckLogged = true
        emit("NATURAL STREAM CHECK", "playerDelta=" .. string.format("%.2f", math.abs(player:getX() - originX))
            .. " bodyPresent=" .. tostring(present))
    end
    if present == false and NLClient and NLClient.npcPresence then
        local old = body
        NLNpcClient.apply(NLClient.npcPresence)
        local fresh = NLNpcClient.bodies.kenji
        NLQAMultiplayer.streamWalkObserved = fresh ~= old
        emit("NATURAL STREAM RECOVERED", "target=kenji fresh=" .. tostring(fresh ~= old))
    end
end)

-- QA-only client streaming stimulus. Remove one real native NPC body from the
-- local cell while retaining its stale NLNpcClient handle, then apply the last
-- authoritative presence packet. Production NpcClient must discard the stale
-- handle and recreate the local native replica; the QA helper does not own the
-- identity or coordinates.
Events.OnRenderTick.Add(function()
    if not isClient() or qaIdentity().username ~= "nl-host" then return end
    if NLQAMultiplayer.streamProbeObserved then return end
    if not NLQAMultiplayer.streamWalkSent
            or (not NLQAMultiplayer.streamWalkObserved and NLQAMultiplayer.streamWalkFrame < 1800) then return end
    local body = NLNpcClient and NLNpcClient.bodies and NLNpcClient.bodies.kenji
    if not NLQAMultiplayer.streamProbeSent then
        if not body or not NLClient or not NLClient.npcPresence then return end
        NLQAMultiplayer.streamProbeFrame = NLQAMultiplayer.streamProbeFrame + 1
        if NLQAMultiplayer.streamProbeFrame < 900 then return end
        local old = body
        local removed = false
        if old.removeFromWorld then removed = pcall(old.removeFromWorld, old) end
        if old.removeFromSquare then removed = pcall(old.removeFromSquare, old) or removed end
        local cell = getCell and getCell()
        local list = cell and cell:getObjectList()
        if list and list.remove then removed = pcall(list.remove, list, old) or removed end
        NLQAMultiplayer.streamProbeOld = old
        NLQAMultiplayer.streamProbeSent = true
        emit("STREAM PROBE SENT", "target=kenji removed=" .. tostring(removed))
        NLNpcClient.apply(NLClient.npcPresence)
        body = NLNpcClient.bodies.kenji
    end
    if body and body ~= NLQAMultiplayer.streamProbeOld then
        NLQAMultiplayer.streamProbeObserved = true
        emit("STREAM PROBE RECOVERED", "target=kenji mode=" .. tostring(NLNpcClient.modes.kenji)
            .. " fresh=" .. tostring(body ~= NLQAMultiplayer.streamProbeOld))
    end
end)

-- QA-only visual contract: record the compact panel and source-texture sizes
-- from the live production marker without adding diagnostics to the mod.
Events.OnRenderTick.Add(function()
    if not isClient() or NLQAMultiplayer.plumbobSizeLogged then return end
    if not NLPlumbob or not NLPlumbob.instances then return end
    local details = {}
    for _, id in ipairs({"player:0", "npc:marisol"}) do
        local panel = NLPlumbob.instances[id]
        if panel then
            local textureWidth, textureHeight = 0, 0
            if panel.texture and panel.texture.getWidth then
                local okWidth, valueWidth = pcall(panel.texture.getWidth, panel.texture)
                local okHeight, valueHeight = pcall(panel.texture.getHeight, panel.texture)
                if okWidth then textureWidth = valueWidth end
                if okHeight then textureHeight = valueHeight end
            end
            details[#details + 1] = id .. "=" .. tostring(panel.width) .. "x"
                .. tostring(panel.height) .. " texture=" .. tostring(textureWidth)
                .. "x" .. tostring(textureHeight)
        end
    end
    if #details > 0 then
        NLQAMultiplayer.plumbobSizeLogged = true
        emit("PLUMBOB SIZE", table.concat(details, " "))
    end
end)

-- QA-only HUD contract: record the live production panel's local username and
-- six independently read vanilla stat values for each isolated client.
Events.OnRenderTick.Add(function()
    if not isClient() or NLQAMultiplayer.hudProbeLogged then return end
    pcall(require, "NeighborhoodNeeds")
    local player = getSpecificPlayer(0)
    local panel = NeighborhoodNeeds and NeighborhoodNeeds.instances
        and NeighborhoodNeeds.instances[0]
    if not player or not panel or not NeighborhoodNeeds.rows
            or not NeighborhoodNeeds.read then return end
    local values = {}
    for _, row in ipairs(NeighborhoodNeeds.rows) do
        local value = NeighborhoodNeeds.read(player, row[2])
        values[#values + 1] = row[2] .. "=" .. tostring(value)
    end
    NLQAMultiplayer.hudProbeLogged = true
    emit("HUD INSTANCE", "username=" .. NeighborhoodNeeds.playerName(player, 0)
        .. " title=" .. NeighborhoodNeeds.header(player, 0)
        .. " rows=" .. tostring(#NeighborhoodNeeds.rows)
        .. " values=" .. table.concat(values, ","))
end)

-- QA-only clothing vertical-slice probe. It opens the real production panel
-- and asks the server to capture the host's current worn garments; no QA item
-- or client-invented preset enters the production profile.
Events.OnRenderTick.Add(function()
    if not isClient() or qaIdentity().username ~= "nl-host"
            or NLQAMultiplayer.snapshots == 0
            or not NLQAMultiplayer.wardrobeWearObserved
            or NLQAMultiplayer.socialFrame < NLQAMultiplayer.wardrobeSaveDue
            or NLQAMultiplayer.wardrobeSaveSent then return end
    local player=getSpecificPlayer(0)
    if not player then return end
    pcall(require, "NL/Wardrobe")
    if NLWardrobe and NLWardrobe.requestSave then
        NLWardrobe.requestSave(player, 1)
        NLQAMultiplayer.wardrobeSaveSent=true
        emit("WARDROBE SAVE", "slot=1 source=server-authoritative-worn-items")
    end
    pcall(require, "NL/WardrobePanel")
    if NLWardrobePanel and NLWardrobePanel.open then
        NLWardrobePanel.open(0)
        local panel=NLWardrobePanel.instances and NLWardrobePanel.instances[0]
        if panel and not NLQAMultiplayer.wardrobeUiLogged then
            NLQAMultiplayer.wardrobeUiLogged=true
            emit("WARDROBE UI", "visible="..tostring(panel.isVisible and panel:isVisible() or panel.visible)
                .." x="..tostring(panel.x).." y="..tostring(panel.y)
                .." width="..tostring(panel.width).." height="..tostring(panel.height))
        end
    end
end)
