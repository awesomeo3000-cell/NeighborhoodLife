-- Client-side presentation of an authoritative remote player.
--
-- Build 42.20.4 can temporarily omit a connected peer from its native
-- getOnlinePlayers() list. In that gap, keep the real server position visible
-- as a local native IsoPlayer replica. The replica is presentation-only: the
-- server presence packet remains the sole source of identity and coordinates.
if not isClient or not isClient() then return end

require "NL/Plumbob"

NLRemotePlayerClient = {
    bodies = {}, targets = {}, paths = {}, modes = {}, states = {}, revision = 0,
}

local function localUsername(username)
    if not username or username == "" then return true end
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and player.getUsername then
            local ok, name = pcall(player.getUsername, player)
            if ok and name == username then return true end
        end
    end
    return false
end

local function nativePlayer(username)
    if type(getOnlinePlayers) ~= "function" then return nil end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players or not players.size or not players.get then return nil end
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player and player.getUsername then
            local nameOk, name = pcall(player.getUsername, player)
            local dataOk, data = pcall(player.getModData, player)
            local isReplica = dataOk and data and data.NeighborhoodRemotePlayerId
            if nameOk and name == username and not localUsername(name) and not isReplica then
                return player
            end
        end
    end
    return nil
end

local function positionBody(body, x, y, z)
    body:setX(x); body:setY(y)
    if body.setZ then body:setZ(z) end
    local cell = getCell and getCell()
    local square = cell and cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
    if square and body.setCurrent then body:setCurrent(square) end
end

local function removeReplica(username, body)
    if not body then return end
    local data = body.getModData and body:getModData() or nil
    if not data or not data.NeighborhoodRemotePlayerId then return end
    local cell = getCell and getCell()
    local list = cell and cell:getObjectList()
    if list and list.remove then list:remove(body) end
end

local function createReplica(username, entry)
    if not IsoPlayer or not SurvivorFactory or not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end
    local desc = SurvivorFactory.CreateSurvivor()
    desc:setForename(username)
    desc:setSurname("Remote")
    if entry.female ~= nil and desc.setFemale then desc:setFemale(entry.female) end
    local body = IsoPlayer.new(cell, desc, math.floor(entry.x), math.floor(entry.y),
        math.floor(entry.z or 0))
    body:setNpc(true)
    body:setUsername(username)
    body:setGodMod(true)
    local data = body:getModData()
    data.NeighborhoodRemotePlayerId = username
    data.NeighborhoodRemotePlayerReplica = true
    body:setSceneCulled(false)
    body:setAlphaAndTarget(1, 1)
    body:resetModelNextFrame()
    if not cell:getObjectList():contains(body) then cell:getObjectList():add(body) end
    positionBody(body, tonumber(entry.x or 0) or 0, tonumber(entry.y or 0) or 0,
        tonumber(entry.z or 0) or 0)
    return body
end

local function cancelPath(username, body)
    local path = NLRemotePlayerClient.paths[username]
    if path and path.behavior and path.behavior.cancel then
        pcall(path.behavior.cancel, path.behavior)
    end
    if body and body.setPath2 then pcall(body.setPath2, body, nil) end
    NLRemotePlayerClient.paths[username] = nil
end

local function beginPath(username, body, target)
    if not body or not body.getPathFindBehavior2 then return false end
    local ok, behavior = pcall(body.getPathFindBehavior2, body)
    if not ok or not behavior or not behavior.pathToLocation or not behavior.update then return false end
    local started = pcall(behavior.pathToLocation, behavior, target.x, target.y, target.z)
    if not started then return false end
    NLRemotePlayerClient.paths[username] = {
        behavior = behavior, targetX = target.x, targetY = target.y,
        targetZ = target.z, stall = 0,
    }
    return true
end

local function advancePath(username, body, target)
    local path = NLRemotePlayerClient.paths[username]
    if not path then
        if not beginPath(username, body, target) then return false end
        path = NLRemotePlayerClient.paths[username]
    end
    path.targetX, path.targetY, path.targetZ = target.x, target.y, target.z
    local beforeX, beforeY = body:getX(), body:getY()
    local ok = pcall(function()
        body:preupdate(); body:update(); path.behavior:update(); body:postupdate()
    end)
    if not ok then cancelPath(username, body); return false end
    local currentX, currentY = body:getX(), body:getY()
    if math.abs(currentX - beforeX) < 0.001 and math.abs(currentY - beforeY) < 0.001 then
        path.stall = path.stall + 1
    else
        path.stall = 0
    end
    local dx, dy = path.targetX - currentX, path.targetY - currentY
    if math.sqrt(dx * dx + dy * dy) <= 0.08 then
        positionBody(body, path.targetX, path.targetY, path.targetZ)
        cancelPath(username, body)
    elseif path.stall >= 20 then
        cancelPath(username, body)
        return false
    end
    return true
end

function NLRemotePlayerClient.apply(packet)
    if type(packet) ~= "table" or type(packet.players) ~= "table" then return 0 end
    local revision = tonumber(packet.revision or 0) or 0
    if revision < NLRemotePlayerClient.revision then return 0 end
    NLRemotePlayerClient.revision = revision
    local seen = {}
    for _, entry in ipairs(packet.players) do
        local username = entry and tostring(entry.username or "") or ""
        if username ~= "" and not localUsername(username) then
            seen[username] = true
            NLRemotePlayerClient.states[username] = entry
            local native = nativePlayer(username)
            local body = NLRemotePlayerClient.bodies[username]
            if native then
                if body and body ~= native then removeReplica(username, body) end
                NLRemotePlayerClient.bodies[username] = native
                NLRemotePlayerClient.modes[username] = "engine"
                cancelPath(username, native)
            else
                if not body or not body.getModData
                        or not body:getModData().NeighborhoodRemotePlayerId then
                    body = createReplica(username, entry)
                    NLRemotePlayerClient.bodies[username] = body
                end
                if body then
                    NLRemotePlayerClient.targets[username] = {
                        x = tonumber(entry.x or 0) or 0, y = tonumber(entry.y or 0) or 0,
                        z = tonumber(entry.z or 0) or 0,
                    }
                    NLRemotePlayerClient.modes[username] = "replica"
                end
            end
        end
    end
    for username, body in pairs(NLRemotePlayerClient.bodies) do
        if not seen[username] then
            removeReplica(username, body)
            NLRemotePlayerClient.bodies[username] = nil
            NLRemotePlayerClient.targets[username] = nil
            NLRemotePlayerClient.states[username] = nil
            NLRemotePlayerClient.modes[username] = nil
            cancelPath(username, body)
        end
    end
    return #packet.players
end

function NLRemotePlayerClient.update()
    for username, target in pairs(NLRemotePlayerClient.targets) do
        local body = NLRemotePlayerClient.bodies[username]
        if body and NLRemotePlayerClient.modes[username] == "replica" then
            if not advancePath(username, body, target) then
                local dx, dy = target.x - body:getX(), target.y - body:getY()
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance > 0.02 then
                    local step = math.min(distance, 0.18)
                    positionBody(body, body:getX() + dx / distance * step,
                        body:getY() + dy / distance * step, target.z)
                else
                    positionBody(body, target.x, target.y, target.z)
                end
                NLRemotePlayerClient.modes[username] = "replica"
            end
        end
    end
end

function NLRemotePlayerClient.cleanup()
    for username, body in pairs(NLRemotePlayerClient.bodies) do
        cancelPath(username, body)
        removeReplica(username, body)
    end
    NLRemotePlayerClient.bodies = {}
    NLRemotePlayerClient.targets = {}
    NLRemotePlayerClient.paths = {}
    NLRemotePlayerClient.modes = {}
    NLRemotePlayerClient.states = {}
    NLRemotePlayerClient.revision = 0
end

Events.OnTick.Add(NLRemotePlayerClient.update)
Events.OnMainMenuEnter.Add(NLRemotePlayerClient.cleanup)
if Events.OnDisconnect then Events.OnDisconnect.Add(NLRemotePlayerClient.cleanup) end
return NLRemotePlayerClient
