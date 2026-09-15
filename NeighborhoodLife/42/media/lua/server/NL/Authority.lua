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

-- Commands that change only Neighborhood Life's ModData still need a durable
-- boundary: a dedicated-server stop between two table writes must not leave a
-- household, relationship, or profile half-applied. The journal stores a deep
-- copy of the complete world before the command and is cleared only once the
-- command has reached its response boundary. Cross-owner inventory and career
-- delivery commands keep their narrower journals below because those also
-- cover vanilla player-save state.
function NLAuthority.beginWorldJournal(world, player, command)
    if type(world) ~= "table" or not player then return nil end
    local before = NLDomain.copy(world)
    local journal = {
        version = 1,
        state = "prepared",
        player = NLAuthority.key(player),
        command = command,
        before = before,
    }
    world.mutationJournal = journal
    return journal
end

local function clearWorldJournal(world, journal)
    if world and (not journal or world.mutationJournal == journal) then
        world.mutationJournal = nil
        return true
    end
    return false
end

local function restoreWorld(world, before)
    for key in pairs(world) do world[key] = nil end
    for key, value in pairs(before) do world[key] = NLDomain.copy(value) end
end

function NLAuthority.recoverWorldJournal(world, player)
    local journal = world and world.mutationJournal
    if type(journal) ~= "table" then return true, "none" end
    if NLQAGlobalJournalFaultMode == "before-clear"
            and NLQAGlobalJournalFaultConsumed == true
            and journal.state == NLQAGlobalJournalFaultMode then
        return false, "Global data recovery held for crash probe"
    end
    if not player or NLAuthority.key(player) ~= journal.player then
        return false, "Global data recovery belongs to another account"
    end
    if type(journal.before) ~= "table" then
        return false, "Global data recovery record is incomplete"
    end
    restoreWorld(world, journal.before)
    world.mutationJournal = nil
    if NLQAGlobalJournalFaultMode == "before-clear" then
        NLQAGlobalJournalFaultConsumed = true
    end
    if NLQAMultiplayerServer then
        print("NLQA GLOBAL JOURNAL RECOVERY: state=repaired player=" .. tostring(journal.player)
            .. " command=" .. tostring(journal.command))
    end
    return true, "repaired"
end

function NLAuthority.commitWorldJournal(world, journal)
    -- QA-only forced-stop probe: leave the prepared journal in ModData after
    -- the command's writes, then let the isolated runner checkpoint and stop
    -- the real server. Normal production sessions never define this global.
    if journal and type(NLQAGlobalJournalFaultMode) == "string"
            and NLQAGlobalJournalFaultConsumed ~= true
            and (not NLQAGlobalJournalFaultCommand
                or journal.command == NLQAGlobalJournalFaultCommand) then
        NLQAGlobalJournalFaultConsumed = true
        journal.state = NLQAGlobalJournalFaultMode
        if NLQAMultiplayerServer then
            print("NLQA GLOBAL JOURNAL PARTIAL: command=" .. tostring(journal.command)
                .. " state=" .. tostring(journal.state))
        end
        return false
    end
    return clearWorldJournal(world, journal)
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

local function deliveryInventoryCount(player, itemType)
    local inventory = player and player.getInventory and player:getInventory()
    local all = inventory and inventory.getItems and inventory:getItems()
    if not all then return 0 end
    local count = 0
    for i = 0, all:size() - 1 do
        local item = all:get(i)
        local equipped = false
        if item and player.isEquipped then
            local equippedOk, equippedValue = pcall(player.isEquipped, player, item)
            equipped = equippedOk and equippedValue == true
        end
        if item and item.getFullType and item:getFullType() == itemType and not equipped then
            count = count + 1
        end
    end
    return count
end

local function deliveryValuesEqual(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do
        if not deliveryValuesEqual(value, right[key]) then return false end
    end
    for key, value in pairs(right) do
        if not deliveryValuesEqual(left[key], value) then return false end
    end
    return true
end

local function restoreDeliveryInventory(player, itemType, target)
    local inventory = player and player.getInventory and player:getInventory()
    local current = deliveryInventoryCount(player, itemType)
    if not inventory then return false end
    if current > target then
        local all = inventory.getItems and inventory:getItems()
        local chosen = {}
        if not all then return false end
        for i = 0, all:size() - 1 do
            local item = all:get(i)
            local equipped = false
            if item and player.isEquipped then
                local equippedOk, equippedValue = pcall(player.isEquipped, player, item)
                equipped = equippedOk and equippedValue == true
            end
            if item and item.getFullType and item:getFullType() == itemType and not equipped then
                chosen[#chosen + 1] = item
                if #chosen == current - target then break end
            end
        end
        if #chosen < current - target then return false end
        for _, item in ipairs(chosen) do
            inventory:Remove(item)
            if isServer() and sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(inventory, item)
            end
        end
    elseif current < target then
        if not inventory.AddItem then return false end
        for _ = current + 1, target do
            local ok, item = pcall(inventory.AddItem, inventory, itemType)
            if not ok or not item then return false end
            if isServer() and sendAddItemToContainer then
                sendAddItemToContainer(inventory, item)
            end
        end
    end
    return deliveryInventoryCount(player, itemType) == target
end

local function copyProfileInto(target, source)
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(source) do target[key] = NLDomain.copy(value) end
end

local function beginDeliveryJournal(world, player, profile, contract)
    local before = NLDomain.copy(profile)
    local expected = NLDomain.copy(before)
    local completed = NLDomain.complete(expected, contract)
    if not completed then return nil end
    world.deliveryJournal = {
        version = 1,
        state = "prepared",
        player = NLAuthority.key(player),
        contractId = contract.id,
        itemType = contract.item,
        amount = contract.amount,
        playerBefore = deliveryInventoryCount(player, contract.item),
        profileBefore = before,
        profileExpected = expected,
    }
    return world.deliveryJournal
end

local function clearDeliveryJournal(world)
    world.deliveryJournal = nil
end

-- A delivery crosses the vanilla player save and world ModData. Keep the
-- journal until both sides have reached the expected state so a dedicated
-- server restart can repair a half-applied career reward.
local function recoverDeliveryJournal(world, player)
    local journal = world and world.deliveryJournal
    if type(journal) ~= "table" then return true, "none" end
    local key = NLAuthority.key(player)
    if journal.player ~= key then
        return false, "Career delivery recovery belongs to another account"
    end
    if type(journal.profileBefore) ~= "table"
            or type(journal.profileExpected) ~= "table"
            or type(journal.itemType) ~= "string" then
        return false, "Career delivery recovery record is incomplete"
    end
    local profile = NLDomain.profile(world, key)
    local current = deliveryInventoryCount(player, journal.itemType)
    if current == journal.playerBefore - journal.amount
            and deliveryValuesEqual(profile, journal.profileExpected) then
        clearDeliveryJournal(world)
        return true, "completed"
    end
    if current == journal.playerBefore
            and deliveryValuesEqual(profile, journal.profileBefore) then
        clearDeliveryJournal(world)
        return true, "rolled-back"
    end
    if not restoreDeliveryInventory(player, journal.itemType, journal.playerBefore) then
        return false, "Career delivery recovery still needs repair"
    end
    copyProfileInto(profile, journal.profileBefore)
    clearDeliveryJournal(world)
    return true, "repaired"
end

NLAuthority.recoverDeliveryJournal = recoverDeliveryJournal

function NLAuthority.snapshot(player, profile, message, recoveryState)
    local result = NLDomain.copy(profile)
    result.playerNum = player:getPlayerNum()
    result.username = NLAuthority.key(player)
    result.message = message or "Updated"
    if recoveryState and recoveryState ~= "none" then
        result.recoveryState = recoveryState
    end
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
    local world = NLAuthority.world()
    local journal = beginDeliveryJournal(world, player, profile, contract)
    if not journal then return false, "Delivery transaction could not start" end
    for _, item in ipairs(chosen) do
        inv:Remove(item)
        if isServer() then sendRemoveItemFromContainer(inv, item) end
    end
    journal.state = "player-applied"
    if NLQADeliveryFaultMode == "player-applied" then
        NLQADeliveryFaultMode = nil
        if NLQAMultiplayerServer then
            print("NLQA DELIVERY JOURNAL PARTIAL: phase=player-applied item="
                .. tostring(contract.item) .. " amount=" .. tostring(contract.amount))
        end
        return false, "QA forced partial career delivery"
    end
    local ok, message = NLDomain.complete(profile, contract)
    if not ok then
        if restoreDeliveryInventory(player, contract.item, journal.playerBefore) then
            clearDeliveryJournal(world)
        end
        return false, message
    end
    journal.profileExpected = NLDomain.copy(profile)
    journal.state = "world-applied"
    clearDeliveryJournal(world)
    return true, message
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
    local world = NLAuthority.world()
    local recoveryMessage = "Updated"
    local recoveryState = "none"
    local worldRecovered, worldState = NLAuthority.recoverWorldJournal(world, player)
    if not worldRecovered then
        NLAuthority.snapshot(player, NLDomain.profile(world, key),
            "Global data recovery pending: " .. tostring(worldState))
        return
    end
    if worldState ~= "none" and NLQAMultiplayerServer then
        print("NLQA GLOBAL JOURNAL RECOVERY: state=" .. tostring(worldState)
            .. " player=" .. tostring(key))
    end
    if worldState == "repaired" then
        recoveryMessage = "Global data recovery repaired"
        recoveryState = worldState
    end
    if command ~= "presence" then
        local recovered, state = recoverDeliveryJournal(world, player)
        if state ~= "none" then recoveryState = state end
        if not recovered then
            NLAuthority.snapshot(player, NLDomain.profile(world, key),
                "Career delivery recovery pending: " .. tostring(recoveryState))
            return
        end
        if state ~= "none" and NLQAMultiplayerServer then
            print("NLQA DELIVERY JOURNAL RECOVERY: state=" .. tostring(state)
                .. " player=" .. tostring(key))
        end
        if state == "repaired" then
            recoveryMessage = "Career delivery recovery repaired"
        elseif state == "completed" then
            recoveryMessage = "Career delivery recovery confirmed"
        elseif state == "rolled-back" then
            recoveryMessage = "Career delivery recovery rolled back"
        end
    end
    local journal = command ~= "deliver" and NLAuthority.beginWorldJournal(world, player, command) or nil
    local profile = NLDomain.profile(world, key)
    NLDomain.day(profile, math.floor(getGameTime():getWorldAgeHours() / 24))
    local ok, message = true, recoveryMessage
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
    NLAuthority.commitWorldJournal(world, journal)
    NLAuthority.snapshot(player, profile, message, recoveryState)
end

Events.OnClientCommand.Add(NLAuthority.command)
Events.OnMainMenuEnter.Add(function() NLAuthority.lastRequest = {} end)
return NLAuthority
