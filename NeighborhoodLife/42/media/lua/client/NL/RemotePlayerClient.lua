-- Client-side presentation of an authoritative remote player.
--
-- Build 42.20.4 can temporarily omit a connected peer from its native
-- getOnlinePlayers() list. In that gap, keep the real server position visible
-- as a local native IsoPlayer replica. The replica is presentation-only: the
-- server presence packet remains the sole source of identity and coordinates.
if not isClient or not isClient() then return end

require "NL/Plumbob"
require "NL/NpcRender"

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
    local function candidate(player)
        if not player or not player.getUsername then return nil end
        local nameOk, name = pcall(player.getUsername, player)
        local dataOk, data = pcall(player.getModData, player)
        local isReplica = dataOk and data and data.NeighborhoodRemotePlayerId
        if nameOk and name == username and not localUsername(name) and not isReplica then
            return player
        end
        return nil
    end
    if type(getOnlinePlayers) == "function" then
        local ok, players = pcall(getOnlinePlayers)
        if ok and players and players.size and players.get then
            for i = 0, players:size() - 1 do
                local player = candidate(players:get(i))
                if player then return player end
            end
        end
    end
    -- A peer can be present in the loaded cell before Build 42 repopulates
    -- getOnlinePlayers(). Prefer that engine-owned object over a fallback
    -- replica so its native movement and replication remain authoritative.
    local cell = getCell and getCell()
    if cell and cell.getObjectListForLua then
        local listOk, list = pcall(cell.getObjectListForLua, cell)
        if listOk and list and list.size and list.get then
            local countOk, count = pcall(list.size, list)
            if countOk then
                for i = 0, count - 1 do
                    local player = candidate(list:get(i))
                    if player then return player end
                end
            end
        end
    end
    return nil
end

-- Contract tests use this flag to exercise the new cell-discovery branch
-- without making older production baselines fail their existing assertions.
NLRemotePlayerClient.cellNativeDiscoverySupported = true
NLRemotePlayerClient.findNativePlayer = nativePlayer

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
    if NLNpcRender and NLNpcRender.unregister then
        pcall(NLNpcRender.unregister, "remote:" .. tostring(username))
    end
    local cell = getCell and getCell()
    local list = cell and cell:getObjectList()
    if list and list.remove then list:remove(body) end
end

local function createReplica(username, entry)
    if not SurvivorFactory or not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end
    local desc = SurvivorFactory.CreateSurvivor()
    desc:setForename(username)
    desc:setSurname("Remote")
    if entry.female ~= nil and desc.setFemale then desc:setFemale(entry.female) end
    local body = nil
    if IsoPlayer and IsoPlayer.new then
        local okP, pBody = pcall(function()
            return IsoPlayer.new(cell, desc, math.floor(entry.x), math.floor(entry.y), math.floor(entry.z or 0))
        end)
        if okP and pBody then body = pBody end
    end
    if not body and IsoSurvivor and IsoSurvivor.new then
        local okS, sBody = pcall(function()
            return IsoSurvivor.new(desc, cell, math.floor(entry.x), math.floor(entry.y), math.floor(entry.z or 0))
        end)
        if okS and sBody then body = sBody end
    end
    if not body then return nil end
    if body.setNpc then pcall(body.setNpc, body, true) end
    if body.setName then pcall(body.setName, body, username) end
    if body.SetName then pcall(body.SetName, body, username) end
    if body.setUsername then pcall(body.setUsername, body, username) end
    if body.setGodMod then pcall(body.setGodMod, body, true) end
    if body.spottedByPlayer ~= nil then
        pcall(function() body.spottedByPlayer = true end)
    end
    local data = body:getModData()
    data.NeighborhoodRemotePlayerId = username
    data.NeighborhoodRemotePlayerReplica = true
    if body.setSceneCulled then pcall(body.setSceneCulled, body, false) end
    for p = 0, 3 do
        if body.setAlphaAndTarget then pcall(body.setAlphaAndTarget, body, p, 1.0) end
        if body.setTargetAlpha then pcall(body.setTargetAlpha, body, p, 1.0) end
        if body.setAlpha then pcall(body.setAlpha, body, p, 1.0) end
    end
    if body.setAlphaAndTarget then pcall(body.setAlphaAndTarget, body, 1.0) end
    if body.setTargetAlpha then pcall(body.setTargetAlpha, body, 1.0) end
    if body.setAlpha then pcall(body.setAlpha, body, 1.0) end
    if ModelManager and ModelManager.instance and ModelManager.instance.isCreated then
        local okC, created = pcall(ModelManager.instance.isCreated, ModelManager.instance)
        if okC and created and ModelManager.instance.Add then
            pcall(ModelManager.instance.Add, ModelManager.instance, body)
        end
    end
    if body.resetModel then pcall(body.resetModel, body) end
    if body.resetModelNextFrame then pcall(body.resetModelNextFrame, body) end
    if not cell:getObjectList():contains(body) then cell:getObjectList():add(body) end
    positionBody(body, tonumber(entry.x or 0) or 0, tonumber(entry.y or 0) or 0,
        tonumber(entry.z or 0) or 0)
    if NLNpcRender and NLNpcRender.register then
        pcall(NLNpcRender.register, "remote:" .. tostring(username), body)
    end
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
                if body and body ~= native then
                    cancelPath(username, body)
                    removeReplica(username, body)
                end
                if NLNpcRender and NLNpcRender.unregister then
                    pcall(NLNpcRender.unregister, "remote:" .. tostring(username))
                end
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
            if NLNpcRender and NLNpcRender.unregister then
                pcall(NLNpcRender.unregister, "remote:" .. tostring(username))
            end
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
        if NLNpcRender and NLNpcRender.unregister then
            pcall(NLNpcRender.unregister, "remote:" .. tostring(username))
        end
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
