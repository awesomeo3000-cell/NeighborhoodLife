-- Multiplayer evidence logger. Loaded only by NeighborhoodQA in isolated profiles.
NLQAMultiplayer = { snapshots = 0, refreshAttempts = 0, refreshSent = false }

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
    end
end)
