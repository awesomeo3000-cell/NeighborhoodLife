require "NL/Domain"
NLClient = { profiles = {}, presence = nil, presenceFrame = 0 }

function NLClient.receive(module, command, args)
    if module ~= "NeighborhoodLife" or type(args) ~= "table" then return end
    if command == "presence" then
        local old = NLClient.presence
        if not old or (args.revision or 0) >= (old.revision or 0) then NLClient.presence = args end
        return
    end
    if command ~= "snapshot" then return end
    -- Route only to local characters matching the server snapshot. No global getPlayer().
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            local key = player:getUsername()
            if not key or key == "" then key = "local:" .. i end
            if key == args.username then
                local old = NLClient.profiles[i]
                if not old or args.revision >= old.revision then NLClient.profiles[i] = args end
            end
        end
    end
end

function NLClient.request(index, command, args)
    local player = getSpecificPlayer(index)
    if not player or player:isDead() then return end
    if isClient() then sendClientCommand(player, "NeighborhoodLife", command, args or {})
    elseif NLAuthority then NLAuthority.command("NeighborhoodLife", command, player, args or {}) end
end

Events.OnServerCommand.Add(NLClient.receive)
Events.OnRenderTick.Add(function()
    if not isClient() then return end
    NLClient.presenceFrame = NLClient.presenceFrame + 1
    if NLClient.presenceFrame < 300 then return end
    NLClient.presenceFrame = 0
    for i = 0, getNumActivePlayers() - 1 do
        NLClient.request(i, "presence")
    end
end)
Events.OnMainMenuEnter.Add(function()
    NLClient.profiles = {}; NLClient.presence = nil; NLClient.presenceFrame = 0
end)
return NLClient
