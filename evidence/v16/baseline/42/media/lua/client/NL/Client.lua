require "NL/Domain"
NLClient = { profiles = {} }

function NLClient.receive(module, command, args)
    if module ~= "NeighborhoodLife" or command ~= "snapshot" or type(args) ~= "table" then return end
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
Events.OnMainMenuEnter.Add(function() NLClient.profiles = {} end)
return NLClient
