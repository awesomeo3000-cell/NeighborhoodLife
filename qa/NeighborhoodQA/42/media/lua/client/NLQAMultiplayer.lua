-- Multiplayer evidence logger. Loaded only by NeighborhoodQA in isolated profiles.
NLQAMultiplayer = { snapshots = 0 }

local function emit(label, value)
    print("NLQA MP " .. label .. ": " .. tostring(value))
end

Events.OnGameStart.Add(function()
    local player = getSpecificPlayer(0)
    emit("CLIENT START", "username=" .. tostring(player and player:getUsername())
        .. " isClient=" .. tostring(isClient()) .. " isServer=" .. tostring(isServer()))
    if player and isClient() and NLClient then
        NLClient.request(0, "refresh")
    end
end)

Events.OnServerCommand.Add(function(module, command, args)
    if module == "NeighborhoodLife" and command == "snapshot" and type(args) == "table" then
        NLQAMultiplayer.snapshots = NLQAMultiplayer.snapshots + 1
        emit("SNAPSHOT", "username=" .. tostring(args.username) .. " revision=" .. tostring(args.revision)
            .. " snapshotCount=" .. tostring(NLQAMultiplayer.snapshots))
    end
end)
