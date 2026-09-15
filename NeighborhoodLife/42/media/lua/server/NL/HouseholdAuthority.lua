if isClient() then return end
require "NL/Households"
require "NL/Authority"
NLHouseholdFurnishings = require "NL/HouseholdFurnishings"

NLHouseholdAuthority = { module = "NeighborhoodHousehold", lastRequest = {} }

local function onlineRows()
    local rows = {}
    if type(getOnlinePlayers) ~= "function" then return rows end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return rows end
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player and player:getUsername() and player:getUsername() ~= "" then
            rows[player:getUsername()] = player
        end
    end
    return rows
end

local function householdOnline(household)
    local players, result = onlineRows(), {}
    for key in pairs(household.members or {}) do result[key] = players[key] ~= nil end
    return result, players
end

local function findOnline(username)
    return onlineRows()[username]
end

local function snapshot(player, message)
    local world = NLAuthority.world()
    local key = NLAuthority.key(player)
    local profile = NLDomain.profile(world, key)
    local household = profile.householdId and NLHouseholds.get(world, profile.householdId) or nil
    if household and NLHouseholdFurnishings then NLHouseholdFurnishings.ensure(household) end
    local online = household and householdOnline(household) or {}
    local result = {
        username = key, revision = profile.revision, householdRevision = household and household.revision or 0,
        message = message or "Updated", invite = NLDomain.copy(profile.householdInvite),
        homeActivities = NLDomain.copy(profile.homeActivities),
        homeAspiration = NLDomain.copy(profile.homeAspiration),
        homeAspirationLabel = NLAspirations.homeLabel(profile),
        household = NLHouseholds.copySummary(household, online),
    }
    sendServerCommand(player, NLHouseholdAuthority.module, "snapshot", result)
    return result
end

local function notifyMembers(world, household, message)
    local _, players = householdOnline(household)
    for key in pairs(household.members or {}) do
        if players[key] then snapshot(players[key], message) end
    end
end

local function recordSharedHomeActivity(world, household, task, actorKey)
    local actorReward = 0
    for memberKey in pairs(household.members or {}) do
        local memberProfile = NLDomain.profile(world, memberKey)
        local reward = NLAspirations.recordHomeActivity(memberProfile, task)
        if memberKey == actorKey then actorReward = reward end
    end
    return actorReward
end

local function homeOf(player)
    return { x = math.floor(player:getX()), y = math.floor(player:getY()), z = math.floor(player:getZ()) }
end

local function nearbyHome(player, household)
    if not household or not household.home then return false end
    if math.floor(player:getZ()) ~= household.home.z then return false end
    local dx, dy = player:getX() - household.home.x, player:getY() - household.home.y
    return dx * dx + dy * dy <= 36
end

local function validItemType(itemType)
    return type(itemType) == "string" and #itemType <= 100
        and itemType:match("^[%w_%-]+%.[%w_%-]+$") ~= nil
end

local function requestedAmount(args)
    local amount = math.floor(tonumber(args and args.amount) or 0)
    if amount < 1 or amount > 50 then return nil end
    return amount
end

local function mainInventoryItems(player, itemType, amount)
    local inventory = player:getInventory()
    local all = inventory and inventory:getItems()
    if not all then return nil, "Main inventory unavailable" end
    local chosen = {}
    for i = 0, all:size() - 1 do
        local item = all:get(i)
        local equipped = false
        if player.isEquipped then
            local equippedOk, equippedValue = pcall(player.isEquipped, player, item)
            equipped = equippedOk and equippedValue == true
        end
        if item and item:getFullType() == itemType and not equipped then
            chosen[#chosen + 1] = item
            if #chosen == amount then break end
        end
    end
    return chosen, inventory
end

local function mainInventoryCount(player, itemType)
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

local function itemMethod(item, method)
    if not item then return nil end
    local ok, fn = pcall(function() return item[method] end)
    return ok and fn or nil
end

local function itemValue(item, method)
    local fn = itemMethod(item, method)
    if not fn then return nil end
    local valueOk, value = pcall(fn, item)
    return valueOk and value or nil
end

local function fluidValue(item, method)
    local fluidContainer = itemValue(item, "getFluidContainer")
    return itemValue(fluidContainer, method)
end

local function itemUsedDelta(item)
    local legacy = itemValue(item, "getUsedDelta")
    if legacy ~= nil then return legacy end
    local amount = fluidValue(item, "getAmount")
    local capacity = fluidValue(item, "getCapacity")
    if amount ~= nil and capacity ~= nil and tonumber(capacity) and tonumber(capacity) > 0 then
        return tonumber(amount) / tonumber(capacity)
    end
    return nil
end

local function itemStorageDetails(item, itemType)
    local container = itemValue(item, "getContainer")
    local containerType = container and itemValue(container, "getType") or nil
    return {
        item = itemType,
        name = itemValue(item, "getName"),
        category = itemValue(item, "getCategory"),
        container = containerType,
        condition = itemValue(item, "getCondition"),
        maxCondition = itemValue(item, "getConditionMax"),
        -- Build 42 fluid-container items no longer expose the legacy
        -- getUsedDelta API; persist their normalized fill level instead.
        usedDelta = itemUsedDelta(item),
    }
end

local function setItemValue(item, method, value)
    if not item or value == nil then return end
    local ok, fn = pcall(function() return item[method] end)
    if ok and fn then pcall(fn, item, value) end
end

local function applyStorageDetails(item, details)
    if not item or type(details) ~= "table" then return end
    setItemValue(item, "setCondition", details.condition)
    setItemValue(item, "setUsedDelta", details.usedDelta)
    if details.usedDelta ~= nil then
        local fluidContainer = itemValue(item, "getFluidContainer")
        local capacity = itemValue(fluidContainer, "getCapacity")
        local adjust = itemMethod(fluidContainer, "adjustAmount")
        if adjust and capacity ~= nil then
            pcall(adjust, fluidContainer, tonumber(details.usedDelta) * tonumber(capacity))
        end
    end
    -- Build 42 permits a restored custom display name on item instances. If a
    -- build omits the setter, the durable metadata still remains in the home.
    setItemValue(item, "setName", details.name)
end

local function beginStorageJournal(world, household, player, itemType, amount, mode, details)
    world.householdJournal = {
        version = 1, state = "prepared", mode = mode,
        player = NLAuthority.key(player), householdId = household.id,
        itemType = itemType, amount = amount,
        playerBefore = mainInventoryCount(player, itemType),
        storageBefore = NLHouseholds.storageCount(household, itemType),
        householdRevisionBefore = household.revision or 0,
        storageBeforeAll = NLDomain.copy(household.storage or {}),
        storageEntriesBeforeAll = NLDomain.copy(household.storageEntries or {}),
        details = NLDomain.copy(details),
    }
    return world.householdJournal
end

local function clearStorageJournal(world)
    world.householdJournal = nil
end

local function restoreInventoryCount(player, itemType, target, details)
    local current = mainInventoryCount(player, itemType)
    local inventory = player and player.getInventory and player:getInventory()
    if not inventory then return false end
    if current > target then
        local chosen = mainInventoryItems(player, itemType, current - target)
        if not chosen or #chosen < current - target then return false end
        for _, item in ipairs(chosen) do inventory:Remove(item) end
    elseif current < target and inventory.AddItem then
        for index = current + 1, target do
            local ok, item = pcall(inventory.AddItem, inventory, itemType)
            if not ok or not item then return false end
            applyStorageDetails(item, details and details[index - current])
        end
    end
    return mainInventoryCount(player, itemType) == target
end

local function restoreStorageState(household, journal)
    household.storage = NLDomain.copy(journal.storageBeforeAll or {})
    household.storageEntries = NLDomain.copy(journal.storageEntriesBeforeAll or {})
    household.revision = journal.householdRevisionBefore or household.revision
end

-- Household storage crosses a vanilla player save and the world's ModData.
-- Keep a recoverable journal until both sides reach their expected state; a
-- server restart can then repair a mutation interrupted between those writes.
local function recoverStorageJournal(world, player)
    local journal = world and world.householdJournal
    if type(journal) ~= "table" then return true, "none" end
    local key = NLAuthority.key(player)
    if journal.player ~= key then return false, "Household storage recovery belongs to another account" end
    local household = journal.householdId and NLHouseholds.get(world, journal.householdId) or nil
    if not household then return false, "Household storage recovery home is missing" end
    local currentPlayer = mainInventoryCount(player, journal.itemType)
    local currentStorage = NLHouseholds.storageCount(household, journal.itemType)
    local delta = journal.mode == "store" and journal.amount or -journal.amount
    local expectedPlayer = journal.playerBefore + (journal.mode == "store" and -journal.amount or journal.amount)
    local expectedStorage = journal.storageBefore + delta
    if currentPlayer == expectedPlayer and currentStorage == expectedStorage then
        clearStorageJournal(world)
        return true, "completed"
    end
    if currentPlayer == journal.playerBefore and currentStorage == journal.storageBefore then
        clearStorageJournal(world)
        return true, "rolled-back"
    end
    if not restoreInventoryCount(player, journal.itemType, journal.playerBefore,
            journal.mode == "store" and journal.details or nil) then
        return false, "Household storage recovery still needs repair"
    end
    restoreStorageState(household, journal)
    clearStorageJournal(world)
    return true, "repaired"
end

NLHouseholdAuthority.recoverStorageJournal = recoverStorageJournal

local function storageCommand(world, household, player, key, args, mode)
    local itemType = args and args.item
    local amount = requestedAmount(args)
    if not validItemType(itemType) then return false, "Use a valid item type such as Base.RippedSheets" end
    if not amount then return false, "Storage amount must be between 1 and 50" end
    if mode == "store" then
        local chosen, inventoryOrMessage = mainInventoryItems(player, itemType, amount)
        if not chosen then return false, inventoryOrMessage end
        if #chosen < amount then
            return false, "Need " .. amount .. " unequipped " .. itemType .. " in main inventory"
        end
        local details = {}
        for _, item in ipairs(chosen) do
            details[#details + 1] = itemStorageDetails(item, itemType)
        end
        local journal = beginStorageJournal(world, household, player, itemType, amount, mode, details)
        for _, item in ipairs(chosen) do
            inventoryOrMessage:Remove(item)
            if isServer() and sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(inventoryOrMessage, item)
            end
        end
        journal.state = "player-applied"
        if NLQAHouseholdFaultMode == "player-applied" then
            NLQAHouseholdFaultMode = nil
            if NLQAMultiplayerServer then
                print("NLQA HOUSEHOLD JOURNAL PARTIAL: phase=player-applied mode=store item="
                    .. tostring(itemType) .. " amount=" .. tostring(amount))
            end
            return false, "QA forced partial household transaction"
        end
        local ok, message = NLHouseholds.store(household, itemType, amount, details)
        if not ok then
            for index = 1, amount do
                local restored = inventoryOrMessage:AddItem(itemType)
                applyStorageDetails(restored, details[index])
                if isServer() and sendAddItemToContainer and restored then
                    sendAddItemToContainer(inventoryOrMessage, restored)
                end
            end
            clearStorageJournal(world)
        else
            journal.state = "world-applied"
            clearStorageJournal(world)
        end
        return ok, message
    end

    if NLHouseholds.storageCount(household, itemType) < amount then
        return false, "Shared storage has only " .. NLHouseholds.storageCount(household, itemType)
            .. " " .. itemType
    end
    local inventory = player:getInventory()
    if not inventory or not inventory.AddItem then
        return false, "Main inventory unavailable"
    end
    local added = {}
    local journal = beginStorageJournal(world, household, player, itemType, amount, mode)
    for _ = 1, amount do
        local addOk, item = pcall(inventory.AddItem, inventory, itemType)
        if not addOk or not item then
            for _, restored in ipairs(added) do
                inventory:Remove(restored)
                if isServer() and sendRemoveItemFromContainer then
                    sendRemoveItemFromContainer(inventory, restored)
                end
            end
            clearStorageJournal(world)
            return false, "Main inventory could not accept " .. itemType
        end
        added[#added + 1] = item
    end
    journal.state = "player-applied"
    if NLQAHouseholdFaultMode == "player-applied" then
        NLQAHouseholdFaultMode = nil
        if NLQAMultiplayerServer then
            print("NLQA HOUSEHOLD JOURNAL PARTIAL: phase=player-applied mode=retrieve item="
                .. tostring(itemType) .. " amount=" .. tostring(amount))
        end
        return false, "QA forced partial household transaction"
    end
    local ok, message, details = NLHouseholds.retrieve(household, itemType, amount)
    if not ok then
        for _, restored in ipairs(added) do inventory:Remove(restored) end
    end
    if ok then
        for index, item in ipairs(added) do
            applyStorageDetails(item, details and details[index])
            -- Send only after applying the instance metadata so the first
            -- client replica carries the restored condition/fluid state too.
            if isServer() and sendAddItemToContainer then
                sendAddItemToContainer(inventory, item)
            end
        end
        journal.state = "world-applied"
        clearStorageJournal(world)
    else
        clearStorageJournal(world)
    end
    return ok, message
end

local function furnishingCommand(world, household, player, key, args)
    if not NLHouseholdFurnishings or not NLHouseholdFurnishings.isNearby then
        return false, "Household storage is unavailable"
    end
    NLHouseholdFurnishings.ensure(household)
    if not NLHouseholdFurnishings.isNearby(household, player) then
        return false, "Stand beside the household storage"
    end
    local action = args and args.action
    if action ~= "store" and action ~= "retrieve" then
        return false, "Choose store or retrieve"
    end
    local ok, message = storageCommand(world, household, player, key, args, action)
    if not ok then return false, message end
    return true, "Used household storage: " .. message
end

function NLHouseholdAuthority.command(module, command, player, args)
    if module ~= NLHouseholdAuthority.module or not player or player:isDead() then return end
    if command ~= "refresh" and command ~= "create" and command ~= "invite"
            and command ~= "accept" and command ~= "leave" and command ~= "task"
            and command ~= "store" and command ~= "retrieve" and command ~= "furnishing"
            and command ~= "transfer" then return end
    if type(args) ~= "table" then args = {} end
    local key, now = NLAuthority.key(player), getTimestampMs()
    if NLHouseholdAuthority.lastRequest[key] and now - NLHouseholdAuthority.lastRequest[key] < 200 then return end
    NLHouseholdAuthority.lastRequest[key] = now
    local world = NLAuthority.world()
    local globalRecovered, globalState = NLAuthority.recoverWorldJournal(world, player)
    if not globalRecovered then
        snapshot(player, "Global data recovery pending: " .. tostring(globalState))
        return
    end
    if globalState == "repaired" and NLQAMultiplayerServer then
        print("NLQA GLOBAL JOURNAL RECOVERY: state=repaired player=" .. tostring(key))
    end
    local recovered, recoveryState = recoverStorageJournal(world, player)
    if not recovered then
        snapshot(player, "Household storage recovery pending: " .. tostring(recoveryState))
        return
    end
    if recoveryState ~= "none" and NLQAMultiplayerServer then
        print("NLQA HOUSEHOLD JOURNAL RECOVERY: state=" .. tostring(recoveryState)
            .. " player=" .. tostring(key))
    end
    local message = recoveryState == "repaired" and "Household storage recovery repaired"
        or recoveryState == "completed" and "Household storage recovery completed"
        or recoveryState == "rolled-back" and "Household storage recovery rolled back"
        or globalState == "repaired" and "Global data recovery repaired"
        or "Updated"
    local journal = command ~= "refresh" and command ~= "store" and command ~= "retrieve"
        and command ~= "furnishing" and NLAuthority.beginWorldJournal(world, player, command) or nil
    local profile = NLDomain.profile(world, key)
    NLDomain.day(profile, math.floor(getGameTime():getWorldAgeHours() / 24))
    local household = profile.householdId and NLHouseholds.get(world, profile.householdId) or nil

    if command == "create" then
        if household then
            message = "You already belong to a household"
        else
            local id = "home:" .. key
            household = NLHouseholds.new(id, key, homeOf(player))
            NLHouseholds.ensure(world)[id] = household
            if NLHouseholdFurnishings then NLHouseholdFurnishings.ensure(household) end
            profile.householdId, profile.householdInvite = id, nil
            profile.revision = profile.revision + 1
            message = "Neighborhood Home created"
        end
    elseif command == "invite" then
        local targetName = type(args.target) == "string" and args.target or ""
        local target = household and findOnline(targetName) or nil
        if not household then message = "Create a home first"
        elseif targetName == "" or #targetName > 64 or not target then message = "That neighbor is not online"
        elseif targetName == key then message = "You are already the owner"
        else
            local targetProfile = NLDomain.profile(world, targetName)
            if targetProfile.householdId then message = "That neighbor already has a household"
            else
                targetProfile.householdInvite = { householdId = household.id, from = key, name = household.name }
                targetProfile.revision = targetProfile.revision + 1
                sendServerCommand(target, NLHouseholdAuthority.module, "invite", {
                    householdId = household.id, from = key, name = household.name,
                })
                snapshot(target, "Household invitation received")
                message = "Invitation sent to " .. targetName
            end
        end
    elseif command == "transfer" then
        local targetName = type(args.target) == "string" and args.target or ""
        if not household then
            message = "Create or join a home first"
        else
            local ok
            ok, message = NLHouseholds.transferOwner(household, key, targetName)
            if ok then
                NLAuthority.commitWorldJournal(world, journal)
                notifyMembers(world, household, message)
                if NLQAMultiplayerServer then
                    print("NLQA HOUSEHOLD RESULT: username=" .. tostring(key)
                        .. " command=transfer owner=" .. tostring(household.owner)
                        .. " message=" .. tostring(message))
                end
                return
            end
        end
    elseif command == "accept" then
        local invite = profile.householdInvite
        local invited = invite and NLHouseholds.get(world, invite.householdId) or nil
        if household then message = "You already belong to a household"
        elseif not invited then profile.householdInvite = nil; message = "That invitation expired"
        else
            local ok
            ok, message = NLHouseholds.addMember(invited, key)
            if ok then
                profile.householdId, profile.householdInvite = invited.id, nil
                profile.revision = profile.revision + 1
                NLAuthority.commitWorldJournal(world, journal)
                notifyMembers(world, invited, key .. " joined the household")
                if NLQAMultiplayerServer then
                    print("NLQA HOUSEHOLD RESULT: username=" .. tostring(key)
                        .. " command=accept message=" .. tostring(message))
                end
                return
            end
        end
    elseif command == "leave" then
        if not household then message = "You are not in a household"
        else
            local ok
            ok, message = NLHouseholds.removeMember(household, key)
            if ok then
                profile.householdId = nil
                profile.revision = profile.revision + 1
                if household.owner == key then
                    local replacement
                    for member in pairs(household.members) do replacement = member; break end
                    household.owner = replacement
                    if replacement and household.members[replacement] then household.members[replacement].role = "owner" end
                end
                if NLHouseholds.memberCount(household) == 0 then
                    if NLHouseholdFurnishings then NLHouseholdFurnishings.remove(household) end
                    NLHouseholds.ensure(world)[household.id] = nil
                else notifyMembers(world, household, key .. " left the household") end
            end
        end
    elseif command == "task" then
        local task = type(args.task) == "string" and args.task or ""
        if not household then message = "Join a household first"
        elseif not nearbyHome(player, household) then message = "Household activities happen at home"
        else
            local ok
            ok, message = NLHouseholds.completeTask(household, key, task, profile.day)
            if ok then
                local definition = NLHouseholds.tasks[task]
                profile.credits = profile.credits + definition.reward
                profile.revision = profile.revision + 1
                local homeReward = recordSharedHomeActivity(world, household, task, key)
                if homeReward > 0 then
                    message = message .. " / Home aspiration reward +" .. tostring(homeReward) .. " credits"
                end
                NLAuthority.commitWorldJournal(world, journal)
                notifyMembers(world, household, message)
                if NLQAMultiplayerServer then
                    print("NLQA HOUSEHOLD RESULT: username=" .. tostring(key)
                        .. " command=task message=" .. tostring(message))
                end
                return
            end
        end
    elseif command == "store" or command == "retrieve" then
        if not household then message = "Join a household first"
        elseif command == "store" and not nearbyHome(player, household) then
            message = "Deposits require you to be at home"
        else
            local ok
            ok, message = storageCommand(world, household, player, key, args, command)
            if ok then
                notifyMembers(world, household, key .. " updated shared storage")
                if NLQAMultiplayerServer then
                    print("NLQA HOUSEHOLD RESULT: username=" .. tostring(key)
                        .. " command=" .. tostring(command) .. " message=" .. tostring(message))
                end
                return
            end
        end
    elseif command == "furnishing" then
        if not household then message = "Join a household first"
        else
            local ok
            ok, message = furnishingCommand(world, household, player, key, args)
            if ok then
                notifyMembers(world, household, key .. " used household storage")
                if NLQAMultiplayerServer then
                    print("NLQA HOUSEHOLD RESULT: username=" .. tostring(key)
                        .. " command=furnishing message=" .. tostring(message))
                end
                return
            end
        end
    end
    NLAuthority.commitWorldJournal(world, journal)
    snapshot(player, message)
    if NLQAMultiplayerServer then
        print("NLQA HOUSEHOLD RESULT: username=" .. tostring(key) .. " command=" .. tostring(command)
            .. " message=" .. tostring(message))
    end
end

Events.OnClientCommand.Add(NLHouseholdAuthority.command)
Events.OnMainMenuEnter.Add(function() NLHouseholdAuthority.lastRequest = {} end)
return NLHouseholdAuthority
