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

function NLAuthority.broadcastPresence()
    if not isServer() or type(getOnlinePlayers) ~= "function" then return 0 end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return 0 end
    local entries = {}
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local username = player and player:getUsername()
        if player and username and username ~= "" then
            entries[#entries + 1] = {
                username = username,
                x = player:getX(), y = player:getY(), z = player:getZ(),
                onlineId = player:getOnlineID(),
            }
        end
    end
    local packet = { revision = getTimestampMs(), players = entries }
    for i = 0, players:size() - 1 do
        sendServerCommand(players:get(i), NLAuthority.module, "presence", packet)
    end
    return #entries
end

function NLAuthority.snapshot(player, profile, message)
    local result = NLDomain.copy(profile)
    result.playerNum = player:getPlayerNum()
    result.username = NLAuthority.key(player)
    result.message = message or "Updated"
    result.workedToday = profile.worked and profile.worked[profile.career] == profile.day or false
    result.skill = player:getPerkLevel(Perks[NLDefinitions.careers[profile.career].perk])
    if isServer() then sendServerCommand(player, NLAuthority.module, "snapshot", result)
    elseif NLClient then NLClient.receive(NLAuthority.module, "snapshot", result) end
    NLAuthority.broadcastPresence()
    if NLNpcAuthority and NLNpcAuthority.broadcastPresence then
        NLNpcAuthority.broadcastPresence()
    end
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

function NLAuthority.work(player, profile)
    local career = NLDefinitions.careers[profile.career]
    local perk = career and Perks[career.perk]
    local skill = perk and player:getPerkLevel(perk) or 0
    return NLDomain.work(profile, skill)
end

function NLAuthority.selectAppearance(profile, presetId)
    if type(presetId) ~= "string" or not NLDefinitions.appearancePresets[presetId] then
        return false, "Unknown appearance preset"
    end
    profile.appearance = profile.appearance or { preset = "natural" }
    if profile.appearance.preset ~= presetId then
        profile.appearance = { preset = presetId }
        profile.revision = profile.revision + 1
    end
    return true, NLDefinitions.appearancePresets[presetId].name .. " appearance selected"
end

-- Capture the authoritative player's currently worn garment identities. The
-- client only requests a slot; the server reads the real worn-item list so a
-- preset cannot contain client-invented item types or IDs.
function NLAuthority.captureOutfit(player, profile, slot)
    if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > 3 then
        return false, "Choose wardrobe slot 1, 2 or 3"
    end
    if not player or not player.getWornItems then return false, "Wardrobe unavailable" end
    local worn = player:getWornItems()
    local saved = {}
    if worn and worn.size and worn.get then
        for i = 0, worn:size() - 1 do
            local wornItem = worn:get(i)
            local item = wornItem and wornItem.getItem and wornItem:getItem()
            if item and item.getFullType then
                saved[#saved + 1] = {
                    fullType = item:getFullType(),
                    itemId = item.getID and item:getID() or nil,
                }
            end
        end
    end
    profile.outfits = profile.outfits or {}
    profile.outfits[slot] = saved
    profile.revision = profile.revision + 1
    return true, "Outfit " .. tostring(slot) .. " saved (" .. tostring(#saved) .. " pieces)."
end

function NLAuthority.command(module, command, player, args)
    if module ~= NLAuthority.module or not player or player:isDead() then return end
    if command ~= "refresh" and command ~= "presence" and command ~= "select"
            and command ~= "deliver" and command ~= "promote" and command ~= "work"
            and command ~= "wardrobe_save" and command ~= "appearance_select" then return end
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
    if command == "presence" then
        NLAuthority.broadcastPresence()
        if NLNpcAuthority and NLNpcAuthority.broadcastPresence then
            NLNpcAuthority.broadcastPresence()
        end
        return
    end
    local profile = NLDomain.profile(NLAuthority.world(), key)
    NLDomain.day(profile, math.floor(getGameTime():getWorldAgeHours() / 24))
    local ok, message = true, "Updated"
    if command == "select" then ok, message = NLDomain.select(profile, args.career)
    elseif command == "deliver" then ok, message = NLAuthority.delivery(player, profile, args.id)
    elseif command == "promote" then
        ok, message = NLDomain.promote(profile, player:getPerkLevel(Perks[NLDefinitions.careers[profile.career].perk]))
    elseif command == "work" then ok, message = NLAuthority.work(player, profile)
    elseif command == "wardrobe_save" then
        ok, message = NLAuthority.captureOutfit(player, profile, args.slot)
    elseif command == "appearance_select" then
        ok, message = NLAuthority.selectAppearance(profile, args.preset)
    end
    if not ok then message = "Not completed: " .. message end
    NLAuthority.snapshot(player, profile, message)
end

Events.OnClientCommand.Add(NLAuthority.command)
Events.OnMainMenuEnter.Add(function() NLAuthority.lastRequest = {} end)
return NLAuthority
