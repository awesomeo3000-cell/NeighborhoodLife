-- Multiplayer evidence logger. Loaded only by NeighborhoodQA in isolated profiles.
NLQAMultiplayer = { snapshots = 0, refreshAttempts = 0, refreshSent = false,
    presenceCount = 0, movementFrame = 0, movementSent = false,
    remoteScanFrame = 0, remoteScanCount = 0, remoteScanLogged = false,
    socialFrame = 0, socialRefreshSent = false, socialActionSent = false,
    socialActionScheduled = false, socialTarget = nil, socialActionDue = 0,
    socialResultLogged = false, careerSeedSent = false, careerSeeded = false,
    careerSelectSent = false, careerDeliverSent = false, careerResultLogged = false,
    careerDue = 0, careerStage = 0 }

local function emit(label, value)
    print("NLQA MP " .. label .. ": " .. tostring(value))
end

local function qaIdentity()
    if NLQAIdentity then return NLQAIdentity end
    return {}
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
    emit("CONNECTED", qaIdentity().username or "?")
    if isServer() then return end
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
Events.OnServerCommand.Add(function(module, command, args)
    if module == "NeighborhoodLife" and command == "snapshot" and type(args) == "table" then
        NLQAMultiplayer.snapshots = NLQAMultiplayer.snapshots + 1
        emit("SNAPSHOT", "username=" .. tostring(args.username) .. " revision=" .. tostring(args.revision)
            .. " snapshotCount=" .. tostring(NLQAMultiplayer.snapshots))
        if qaIdentity().username == "nl-host" and args.username == "nl-host"
                and NLQAMultiplayer.careerDeliverSent and not NLQAMultiplayer.careerResultLogged
                and args.message and string.find(args.message,"Delivery complete",1,true) then
            NLQAMultiplayer.careerResultLogged=true
            emit("CAREER RESULT", "delivery complete message="..tostring(args.message))
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
        for _,entry in ipairs(args.npcs) do
            rows[#rows+1]=string.format("%s@%.2f,%.2f,%.0f/w%d", tostring(entry.id),
                tonumber(entry.x or 0), tonumber(entry.y or 0), tonumber(entry.z or 0),
                tonumber(entry.waypoint or 0))
        end
        emit("NPC PRESENCE", "revision="..tostring(args.revision)
            .." count="..tostring(#args.npcs).." entries="..table.concat(rows, ","))
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
        for _,entry in ipairs(args.neighbors or {}) do
            if entry.id=="marisol" and entry.relation and entry.relation.met then hostMet=true end
        end
        if qaIdentity().username == "nl-host" and args.message
                and (string.find(args.message, "I'm ", 1, true) or hostMet)
                and not NLQAMultiplayer.socialResultLogged then
            NLQAMultiplayer.socialResultLogged=true
            emit("SOCIAL RESULT", hostMet and "host introduction already persisted"
                or "host introduction delivered")
        end
    end
    if module == "NeighborhoodQA" and command == "career_seeded" and type(args) == "table"
            and qaIdentity().username == "nl-host" then
        NLQAMultiplayer.careerSeeded=true
        NLQAMultiplayer.careerDue=NLQAMultiplayer.socialFrame+30
        emit("CAREER SEED ACK", "item="..tostring(args.item).." amount="..tostring(args.amount))
    end
end)

-- QA-only world-body conversation probe. The host starts beside the persisted
-- neighborhood slice and introduces itself through the real production social
-- command. The guest requests the same snapshot from its separate position;
-- its result remains proximity-gated rather than being fabricated locally.
Events.OnRenderTick.Add(function()
    if not isClient() or not NLSocialClient then return end
    NLQAMultiplayer.socialFrame=NLQAMultiplayer.socialFrame+1
    if NLQAMultiplayer.socialFrame==900 then
        NLSocialClient.request(0,"refresh")
        NLQAMultiplayer.socialRefreshSent=true
        emit("SOCIAL REFRESH", qaIdentity().username or "?")
    end
    if NLQAMultiplayer.socialRefreshSent and not NLQAMultiplayer.socialActionSent
            and NLSocialClient.snapshots[0] then
        local snapshot=NLSocialClient.snapshots[0]
        if qaIdentity().username=="nl-host" then
            if not NLQAMultiplayer.socialActionScheduled then
                for _,entry in ipairs(snapshot.neighbors or {}) do
                    if entry.canInteract then
                        NLQAMultiplayer.socialTarget=entry.id
                        NLQAMultiplayer.socialActionDue=NLQAMultiplayer.socialFrame+30
                        NLQAMultiplayer.socialActionScheduled=true
                        emit("SOCIAL ACTION SCHEDULED", "introduce id="..tostring(entry.id))
                        break
                    end
                end
            elseif NLQAMultiplayer.socialFrame>=NLQAMultiplayer.socialActionDue then
                NLSocialClient.request(0,"interact",
                    {id=NLQAMultiplayer.socialTarget,action="introduce"})
                NLQAMultiplayer.socialActionSent=true
                emit("SOCIAL ACTION", "introduce id="..tostring(NLQAMultiplayer.socialTarget))
            end
        else
            NLQAMultiplayer.socialActionSent=true
            emit("SOCIAL ACTION", "guest refresh-only; no local interaction stimulus")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.socialResultLogged
            and not NLQAMultiplayer.careerSeedSent then
        local player=getSpecificPlayer(0)
        if player then
            sendClientCommand(player,"NeighborhoodQA","seed_inventory",{career="tailor"})
            NLQAMultiplayer.careerSeedSent=true
            emit("CAREER SEED REQUEST", "tailor")
        end
    end
    if qaIdentity().username=="nl-host" and NLQAMultiplayer.careerSeeded
            and not NLQAMultiplayer.careerSelectSent
            and NLQAMultiplayer.socialFrame>=NLQAMultiplayer.careerDue then
        NLClient.request(0,"select",{career="tailor"})
        NLQAMultiplayer.careerSelectSent=true
        NLQAMultiplayer.careerStage=1
        NLQAMultiplayer.careerDue=NLQAMultiplayer.socialFrame+30
        emit("CAREER SELECT", "tailor")
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
        if luaListOk and luaList then
            local listCountOk,listCount=pcall(luaList.size,luaList)
            if listCountOk then
                for i=0,listCount-1 do
                    local objectOk,object=pcall(luaList.get,luaList,i)
                    if objectOk and object and object.getModData then
                        local dataOk,data=pcall(object.getModData,object)
                        if dataOk and data and data.NeighborhoodNpcId then npcReplicas=npcReplicas+1 end
                    end
                end
            end
        end
        details[#details + 1] = "productionNpcReplicas=" .. tostring(npcReplicas)
    end
    if type(getOnlinePlayers) == "function" then
        local onlineOk, online = pcall(getOnlinePlayers)
        details[#details + 1] = onlineOk and scanList("OnlinePlayers", online, player)
            or "OnlinePlayers=error:" .. tostring(online)
    else
        details[#details + 1] = "OnlinePlayers=unavailable"
    end
    local markerCount = 0
    if NLPlumbob and NLPlumbob.instances then
        for id, _ in pairs(NLPlumbob.instances) do
            if string.sub(id, 1, 7) == "remote:" then markerCount = markerCount + 1 end
        end
    end
    details[#details + 1] = "productionRemoteMarkers=" .. tostring(markerCount)
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
