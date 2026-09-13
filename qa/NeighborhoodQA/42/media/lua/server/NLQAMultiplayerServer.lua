-- QA-only server observer. It records that the real client command reached the
-- production authority; it does not implement gameplay or alter the package.
NLQAMultiplayerServer = true
if isClient() then return end
local ok,err=pcall(function() require "NL/Authority" end)
print("NLQA MP SERVER BOOT: authority=" .. tostring(NLAuthority ~= nil) .. " requireOk=" .. tostring(ok)
    .. " error=" .. tostring(err))
local reannounced = false

local function tryReannounce()
    if reannounced then return end
    local playersOk, players = pcall(function() return GameServer.getPlayers() end)
    if not playersOk or not players then
        print("NLQA MP SERVER GAME-SERVER API: unavailable=" .. tostring(players))
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
