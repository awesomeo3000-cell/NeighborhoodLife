if isClient() then return end
require "NL/Households"
require "NL/Authority"

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
    local online = household and householdOnline(household) or {}
    local result = {
        username = key, revision = profile.revision, householdRevision = household and household.revision or 0,
        message = message or "Updated", invite = NLDomain.copy(profile.householdInvite),
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

local function homeOf(player)
    return { x = math.floor(player:getX()), y = math.floor(player:getY()), z = math.floor(player:getZ()) }
end

local function nearbyHome(player, household)
    if not household or not household.home then return false end
    if math.floor(player:getZ()) ~= household.home.z then return false end
    local dx, dy = player:getX() - household.home.x, player:getY() - household.home.y
    return dx * dx + dy * dy <= 36
end

function NLHouseholdAuthority.command(module, command, player, args)
    if module ~= NLHouseholdAuthority.module or not player or player:isDead() then return end
    if command ~= "refresh" and command ~= "create" and command ~= "invite"
            and command ~= "accept" and command ~= "leave" and command ~= "task" then return end
    if type(args) ~= "table" then args = {} end
    local key, now = NLAuthority.key(player), getTimestampMs()
    if NLHouseholdAuthority.lastRequest[key] and now - NLHouseholdAuthority.lastRequest[key] < 200 then return end
    NLHouseholdAuthority.lastRequest[key] = now
    local world, profile = NLAuthority.world(), NLDomain.profile(NLAuthority.world(), key)
    NLDomain.day(profile, math.floor(getGameTime():getWorldAgeHours() / 24))
    local message = "Updated"
    local household = profile.householdId and NLHouseholds.get(world, profile.householdId) or nil

    if command == "create" then
        if household then
            message = "You already belong to a household"
        else
            local id = "home:" .. key
            household = NLHouseholds.new(id, key, homeOf(player))
            NLHouseholds.ensure(world)[id] = household
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
                if NLHouseholds.memberCount(household) == 0 then NLHouseholds.ensure(world)[household.id] = nil
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
                notifyMembers(world, household, message)
                if NLQAMultiplayerServer then
                    print("NLQA HOUSEHOLD RESULT: username=" .. tostring(key)
                        .. " command=task message=" .. tostring(message))
                end
                return
            end
        end
    end
    snapshot(player, message)
    if NLQAMultiplayerServer then
        print("NLQA HOUSEHOLD RESULT: username=" .. tostring(key) .. " command=" .. tostring(command)
            .. " message=" .. tostring(message))
    end
end

Events.OnClientCommand.Add(NLHouseholdAuthority.command)
Events.OnMainMenuEnter.Add(function() NLHouseholdAuthority.lastRequest = {} end)
return NLHouseholdAuthority
