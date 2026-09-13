if isClient() then return end
require "NL/Domain"

NLAuthority = { module = "NeighborhoodLife", lastRequest = {} }

function NLAuthority.world()
    local world = ModData.getOrCreate("NeighborhoodLife_v2")
    world.version = world.version or NLDefinitions.version
    world.players = world.players or {}
    return world
end

function NLAuthority.key(player)
    -- Server-supplied player, never a username from packet args. Accounts retain
    -- careers across character deaths; each world owns a separate profile store.
    local name = player:getUsername()
    if not name or name == "" then name = "local:" .. player:getPlayerNum() end
    return name
end

function NLAuthority.snapshot(player, profile, message)
    local result = NLDomain.copy(profile)
    result.playerNum = player:getPlayerNum()
    result.username = NLAuthority.key(player)
    result.message = message or "Updated"
    result.skill = player:getPerkLevel(Perks[NLDefinitions.careers[profile.career].perk])
    if isServer() then sendServerCommand(player, NLAuthority.module, "snapshot", result)
    elseif NLClient then NLClient.receive(NLAuthority.module, "snapshot", result) end
    if NLQAMultiplayerServer then
        print("NLQA PRODUCTION AUTHORITY SNAPSHOT: username=" .. tostring(result.username)
            .. " revision=" .. tostring(result.revision))
    end
    return result
end

function NLAuthority.delivery(player, profile, id)
    if type(id) ~= "string" or #id > 100 then return false, "Invalid delivery" end
    local contract = NLDomain.findContract(profile, id)
    if not contract then return false, "Delivery expired; refresh the board" end
    if profile.claimed[id] then return false, "Already delivered" end
    -- Main inventory only. Bags/worn/held items are never silently consumed.
    local inv = player:getInventory()
    local all = inv:getItems()
    local chosen = {}
    for i = 0, all:size() - 1 do
        local item = all:get(i)
        if item:getFullType() == contract.item and not player:isEquipped(item) then
            chosen[#chosen + 1] = item
            if #chosen == contract.amount then break end
        end
    end
    if #chosen < contract.amount then
        return false, "Need " .. contract.amount .. " " .. contract.item .. " in main inventory"
    end
    for _, item in ipairs(chosen) do
        inv:Remove(item)
        if isServer() then sendRemoveItemFromContainer(inv, item) end
    end
    return NLDomain.complete(profile, contract)
end

function NLAuthority.command(module, command, player, args)
    if module ~= NLAuthority.module or not player or player:isDead() then return end
    if command ~= "refresh" and command ~= "select" and command ~= "deliver" and command ~= "promote" then return end
    -- Build 42's dedicated-server callback can omit the empty packet table for
    -- no-argument commands. Treat that as an empty request instead of dropping
    -- an otherwise valid refresh from a real client.
    if type(args) ~= "table" then args = {} end
    local key = NLAuthority.key(player)
    if NLQAMultiplayerServer then
        print("NLQA PRODUCTION AUTHORITY COMMAND: " .. tostring(command)
            .. " username=" .. tostring(key))
    end
    local now = getTimestampMs()
    if NLAuthority.lastRequest[key] and now - NLAuthority.lastRequest[key] < 200 then return end
    NLAuthority.lastRequest[key] = now
    local profile = NLDomain.profile(NLAuthority.world(), key)
    NLDomain.day(profile, math.floor(getGameTime():getWorldAgeHours() / 24))
    local ok, message = true, "Updated"
    if command == "select" then ok, message = NLDomain.select(profile, args.career)
    elseif command == "deliver" then ok, message = NLAuthority.delivery(player, profile, args.id)
    elseif command == "promote" then
        ok, message = NLDomain.promote(profile, player:getPerkLevel(Perks[NLDefinitions.careers[profile.career].perk]))
    end
    if not ok then message = "Not completed: " .. message end
    NLAuthority.snapshot(player, profile, message)
end

Events.OnClientCommand.Add(NLAuthority.command)
Events.OnMainMenuEnter.Add(function() NLAuthority.lastRequest = {} end)
return NLAuthority
