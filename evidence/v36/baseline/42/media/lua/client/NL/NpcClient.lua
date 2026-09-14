-- Client view of authoritative NPC state.
--
-- Build 42.20.4 does not expose the native server re-announcement path to Lua.
-- When a native server body is not present in the client's online list, this
-- creates a local native IsoPlayer replica driven only by server npc_presence
-- packets. It remains a real in-world character locally (model, object and
-- plumbob), while all position/state authority remains server-side.
if not isClient or not isClient() then return end

require "NL/Plumbob"
NLNpcClient = { bodies={}, targets={}, states={}, paths={}, modes={}, revision=0 }

local function nativeBody(id)
    local cellOk, cell = pcall(getCell)
    if not cellOk or not cell then return nil end
    local listOk, list = pcall(cell.getObjectListForLua, cell)
    if not listOk or not list then return nil end
    local countOk, count = pcall(list.size, list)
    if not countOk then return nil end
    for i=0,count-1 do
        local itemOk, object = pcall(list.get, list, i)
        if itemOk and object and object.getModData then
            local dataOk, data = pcall(object.getModData, object)
            if dataOk and data and data.NeighborhoodNpcId == id then return object end
        end
    end
    return nil
end

local function positionBody(body, x, y, z)
    body:setX(x); body:setY(y)
    if body.setZ then body:setZ(z) end
    local cell = getCell()
    local square = cell and cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
    if square and body.setCurrent then body:setCurrent(square) end
end

local function createReplica(entry)
    local id = tostring(entry.id)
    local body = nativeBody(id)
    if not body and IsoPlayer and SurvivorFactory then
        local cell = getCell()
        local desc = SurvivorFactory.CreateSurvivor()
        local name = tostring(entry.name or "Marisol Vega")
        local forename, surname = name:match("^(%S+)%s+(.+)$")
        desc:setForename(forename or name); desc:setSurname(surname or "Neighbor")
        desc:setFemale(entry.female ~= false)
        body = IsoPlayer.new(cell, desc, math.floor(entry.x), math.floor(entry.y), math.floor(entry.z))
        body:setNpc(true)
        body:setUsername(name .. " [Neighborhood Life]")
        body:setGodMod(true)
        body:getModData().NeighborhoodNpcId = id
        body:dressInNamedOutfit(entry.outfit or "Generic01")
        body:setSceneCulled(false)
        body:setAlphaAndTarget(1, 1)
        body:resetModelNextFrame()
        if not cell:getObjectList():contains(body) then cell:getObjectList():add(body) end
    end
    if not body then return nil end
    NLNpcClient.bodies[id] = body
    positionBody(body, entry.x, entry.y, entry.z)
    NLPlumbob.register("npc:" .. id, body, 0, NLPlumbob.remoteColor)
    return body
end

function NLNpcClient.apply(packet)
    if type(packet) ~= "table" or type(packet.npcs) ~= "table" then return 0 end
    local revision = tonumber(packet.revision or 0) or 0
    if revision < NLNpcClient.revision then return 0 end
    NLNpcClient.revision = revision
    local seen = {}
    for _, entry in ipairs(packet.npcs) do
        if entry.id and entry.alive ~= false then
            local id = tostring(entry.id)
            seen[id] = true
            NLNpcClient.states[id] = entry
            local body = NLNpcClient.bodies[id] or createReplica(entry)
            if body then
                local old = NLNpcClient.targets[id]
                NLNpcClient.targets[id] = entry
                -- Do not restart a native path for every heartbeat. A restart
                -- is only needed when the authoritative target has moved by
                -- more than a small correction window.
                local path = NLNpcClient.paths[id]
                if path and old and math.abs((entry.x or 0) - (old.x or 0)) < 0.35
                        and math.abs((entry.y or 0) - (old.y or 0)) < 0.35
                        and (entry.z or 0) == (old.z or 0) then
                    path.targetX, path.targetY, path.targetZ = entry.x, entry.y, entry.z
                end
            end
        end
    end
    for id, body in pairs(NLNpcClient.bodies) do
        if not seen[id] then
            NLPlumbob.unregister("npc:" .. id)
            if getCell then
                local cell = getCell()
                local list = cell and cell:getObjectList()
                if list and list.remove then list:remove(body) end
            end
            NLNpcClient.bodies[id] = nil
            NLNpcClient.targets[id] = nil
            NLNpcClient.paths[id] = nil
            NLNpcClient.modes[id] = nil
            NLNpcClient.states[id] = nil
        end
    end
    return #packet.npcs
end

local function cancelNativePath(id, body)
    local path = NLNpcClient.paths[id]
    if path and path.behavior and path.behavior.cancel then
        pcall(path.behavior.cancel, path.behavior)
    end
    if body and body.setPath2 then pcall(body.setPath2, body, nil) end
    NLNpcClient.paths[id] = nil
end

local function beginNativePath(id, body, target)
    if not body or not body.getPathFindBehavior2 then return false end
    local ok, behavior = pcall(body.getPathFindBehavior2, body)
    if not ok or not behavior or not behavior.pathToLocation or not behavior.update then return false end
    local started = pcall(behavior.pathToLocation, behavior, target.x, target.y, target.z)
    if not started then return false end
    NLNpcClient.paths[id] = {
        behavior=behavior, targetX=target.x, targetY=target.y, targetZ=target.z,
        lastX=body:getX(), lastY=body:getY(), stall=0,
    }
    NLNpcClient.modes[id] = "native"
    return true
end

-- Build 42 only advances a non-local IsoPlayer's PathFindBehavior2 when the
-- normal character frame is driven. Run the same native frame sequence used
-- by WalkToTimedAction, then retain interpolation as a deterministic fallback
-- for clients where the native behavior is unavailable or stalls.
local function advanceNativePath(id, body, target)
    local path = NLNpcClient.paths[id]
    if not path then
        if not beginNativePath(id, body, target) then return false end
        path = NLNpcClient.paths[id]
    end
    path.targetX, path.targetY, path.targetZ = target.x, target.y, target.z
    local beforeX, beforeY = body:getX(), body:getY()
    local ok = pcall(function()
        body:preupdate()
        body:update()
        path.behavior:update()
        body:postupdate()
    end)
    if not ok then
        cancelNativePath(id, body)
        return false
    end
    local currentX, currentY = body:getX(), body:getY()
    if math.abs(currentX-beforeX) < 0.001 and math.abs(currentY-beforeY) < 0.001 then
        path.stall = path.stall + 1
    else
        path.stall = 0
    end
    local dx, dy = path.targetX-currentX, path.targetY-currentY
    if math.sqrt(dx*dx + dy*dy) <= 0.08 then
        positionBody(body, path.targetX, path.targetY, path.targetZ)
        cancelNativePath(id, body)
    elseif path.stall >= 20 then
        cancelNativePath(id, body)
        return false
    end
    path.lastX, path.lastY = currentX, currentY
    return true
end

function NLNpcClient.update()
    for id, target in pairs(NLNpcClient.targets) do
        local body = NLNpcClient.bodies[id]
        if body and target then
            local path = NLNpcClient.paths[id]
            if path and (math.abs((target.x or 0)-path.targetX) >= 0.35
                    or math.abs((target.y or 0)-path.targetY) >= 0.35
                    or (target.z or 0) ~= path.targetZ) then
                cancelNativePath(id, body)
            end
            if not advanceNativePath(id, body, target) then
                local dx, dy = target.x-body:getX(), target.y-body:getY()
                local distance = math.sqrt(dx*dx + dy*dy)
                if distance > 0.02 then
                    local step = math.min(distance, 0.18)
                    positionBody(body, body:getX()+dx/distance*step,
                        body:getY()+dy/distance*step, target.z)
                else
                    positionBody(body, target.x, target.y, target.z)
                end
                NLNpcClient.modes[id] = "fallback"
            end
        end
    end
end

function NLNpcClient.cleanup()
    for id, body in pairs(NLNpcClient.bodies) do
        NLPlumbob.unregister("npc:" .. id)
        local cell = getCell()
        local list = cell and cell:getObjectList()
        if list and list.remove then list:remove(body) end
    end
    for id, body in pairs(NLNpcClient.bodies) do cancelNativePath(id, body) end
    NLNpcClient.bodies={}; NLNpcClient.targets={}; NLNpcClient.states={}; NLNpcClient.paths={}; NLNpcClient.modes={}; NLNpcClient.revision=0
end

Events.OnTick.Add(NLNpcClient.update)
Events.OnMainMenuEnter.Add(NLNpcClient.cleanup)
if Events.OnDisconnect then
    Events.OnDisconnect.Add(NLNpcClient.cleanup)
end
return NLNpcClient
