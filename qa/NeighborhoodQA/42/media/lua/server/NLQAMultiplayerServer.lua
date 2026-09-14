-- QA-only server observer. It records that the real client command reached the
-- production authority; it does not implement gameplay or alter the package.
NLQAMultiplayerServer = true
if isClient() then return end
local ok,err=pcall(function() require "NL/Authority" end)
print("NLQA MP SERVER BOOT: authority=" .. tostring(NLAuthority ~= nil) .. " requireOk=" .. tostring(ok)
    .. " error=" .. tostring(err))
local reannounced = false
local careerSeeded = {}

-- QA-only server fixture: seed real authoritative inventory on the host, then
-- let the production career command consume it. This does not modify the
-- production mod or fake the delivery response; it only provides deterministic
-- world inventory without mouse/keyboard control.
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "NeighborhoodQA" or command ~= "seed_inventory" or not player then return end
    local username = player:getUsername()
    if username ~= "nl-host" or careerSeeded[username] then return end
    local item = "Base.RippedSheets"
    local amount = 6
    for _=1,amount do player:getInventory():AddItem(item) end
    careerSeeded[username] = true
    print("NLQA CAREER SEED: username="..tostring(username).." item="..item.." amount="..amount)
    sendServerCommand(player,"NeighborhoodQA","career_seeded",{item=item,amount=amount})
end)

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
