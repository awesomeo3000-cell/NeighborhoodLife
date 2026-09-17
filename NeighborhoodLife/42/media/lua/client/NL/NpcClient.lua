-- Client view of authoritative NPC state.
--
-- Build 42.20.4 does not expose the native server re-announcement path to Lua.
-- When a native server body is not present in the client's online list, this
-- creates a local native IsoPlayer replica driven only by server npc_presence
-- packets. It remains a real in-world character locally (model, object and
-- plumbob), while all position/state authority remains server-side.
if not isClient or not isClient() then return end

require "NL/Plumbob"
require "NL/NpcRender"
NLNpcClient = { bodies={}, targets={}, states={}, paths={}, modes={}, revision=0 }

-- A presence packet can outlive a native body when the client streams its
-- square out. Keep the authoritative row, but discard the stale Lua handle so
-- the next packet can create a local native replica instead of updating an
-- object that is no longer in the client cell.
local function bodyPresent(body)
    if not body or type(getCell) ~= "function" then return nil end
    local cellOk, cell = pcall(getCell)
    if not cellOk or not cell or not cell.getObjectListForLua then return nil end
    local listOk, list = pcall(cell.getObjectListForLua, cell)
    if not listOk or not list or not list.size or not list.get then return nil end
    local countOk, count = pcall(list.size, list)
    if not countOk then return nil end
    local hintedBody = nil
    local duplicateHint = false
    for i=0,count-1 do
        local objectOk, object = pcall(list.get, list, i)
        if objectOk and object == body then return true end
    end
    return false
end

local cancelNativePath
NLNpcClient.bodyPresent = bodyPresent

local function nativeBody(id, onlineId)
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
            if dataOk and data and data.NeighborhoodNpcId == id
                    and data.NeighborhoodNpcReplica ~= true then return object end
        end
        if onlineId ~= nil and object and object.getOnlineID then
            local onlineOk, value = pcall(object.getOnlineID, object)
            if onlineOk and tonumber(value) == tonumber(onlineId) then
                if hintedBody then duplicateHint = true end
                hintedBody = object
            end
        end
    end
    if hintedBody and not duplicateHint then return hintedBody end
    return nil
end

local function positionBody(body, x, y, z)
    body:setX(x); body:setY(y)
    if body.setZ then body:setZ(z) end
    local cell = getCell()
    local square = cell and cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
    if square and body.setCurrent then body:setCurrent(square) end
end

-- A presence heartbeat contains both the authoritative sample and, while a
-- server route is active, the next native waypoint. Following the motion
-- target locally keeps the rendered replica in motion between heartbeats;
-- each newer sample still replaces it and remains authoritative.
local function movementTarget(entry)
    local motion = entry and entry.motion
    if type(motion) == "table" and motion.active ~= false
            and tonumber(motion.targetX) and tonumber(motion.targetY) then
        return {
            x=tonumber(motion.targetX), y=tonumber(motion.targetY),
            z=tonumber(motion.targetZ or entry.z or 0) or 0,
        }
    end
    return entry
end

NLNpcClient.movementTarget = movementTarget

local function assignReplicaOnlineId(body, onlineId)
    if not body or onlineId == nil then return false end
    local expected = tonumber(onlineId)
    local methodOk, setter = pcall(function() return body.setOnlineID end)
    if methodOk and setter then pcall(setter, body, expected) end
    local getterOk, value = false, nil
    if body.getOnlineID then getterOk, value = pcall(body.getOnlineID, body) end
    if getterOk and tonumber(value) == expected then return true end
    local fieldOk = pcall(function() body.onlineId = expected end)
    if not fieldOk or not body.getOnlineID then return false end
    local verifyOk, verify = pcall(body.getOnlineID, body)
    return verifyOk and tonumber(verify) == expected
end

NLNpcClient.assignReplicaOnlineId = assignReplicaOnlineId

local function createReplica(entry)
    local id = tostring(entry.id)
    local body = nativeBody(id)
    if not body and IsoPlayer and SurvivorFactory then
        local cell = getCell()
        local desc = SurvivorFactory.CreateSurvivor()
        local name = tostring(entry.name or "Marisol Vega")
        local forename, surname = name:match("^(%S+)%s+(.+)$")
        desc:setForename(forename or name); desc:setSurname(surname or "Neighbor")
        local okP, pBody
        if IsoPlayer and IsoPlayer.new then
            okP, pBody = pcall(function()
                return IsoPlayer.new(cell, desc, math.floor(entry.x), math.floor(entry.y), math.floor(entry.z))
            end)
            if okP and pBody then body = pBody end
        end
        if not body and IsoSurvivor and IsoSurvivor.new then
            local okS, sBody = pcall(function()
                return IsoSurvivor.new(desc, cell, math.floor(entry.x), math.floor(entry.y), math.floor(entry.z))
            end)
            if okS and sBody then body = sBody end
        end
        if body then
            if body.setNpc then pcall(body.setNpc, body, true) end
            assignReplicaOnlineId(body, entry.onlineId)
            local displayName = name .. " [Neighborhood Life]"
            if body.setName then pcall(body.setName, body, displayName) end
            if body.SetName then pcall(body.SetName, body, displayName) end
            if body.setUsername then pcall(body.setUsername, body, displayName) end
            if body.setGodMod then pcall(body.setGodMod, body, true) end
            if body.spottedByPlayer ~= nil then
                pcall(function() body.spottedByPlayer = true end)
            end
            local replicaData = body:getModData()
            replicaData.NeighborhoodNpcId = id
            replicaData.NeighborhoodNpcReplica = true
            if body.dressInPersistentOutfit then
                pcall(body.dressInPersistentOutfit, body, entry.outfit or "Generic01")
            end
            if body.dressInNamedOutfit then
                pcall(body.dressInNamedOutfit, body, entry.outfit or "Generic01")
            end
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
        end
    end
    if not body then return nil end
    NLNpcClient.bodies[id] = body
    positionBody(body, entry.x, entry.y, entry.z)
    NLPlumbob.register("npc:" .. id, body, 0, NLPlumbob.remoteColor)
    if NLNpcRender and NLNpcRender.register then
        pcall(NLNpcRender.register, "npc:" .. id, body)
    end
    return body
end

local function forgetReplica(id, body)
    if cancelNativePath then cancelNativePath(id, body) end
    NLPlumbob.unregister("npc:" .. id)
    if NLNpcRender and NLNpcRender.unregister then
        pcall(NLNpcRender.unregister, "npc:" .. id)
    end
    if getCell then
        local cell = getCell()
        local list = cell and cell:getObjectList()
        if list and list.remove then pcall(list.remove, list, body) end
    end
    NLNpcClient.bodies[id] = nil
    NLNpcClient.targets[id] = nil
    NLNpcClient.paths[id] = nil
    NLNpcClient.modes[id] = nil
end

-- A Build 42 server-native body can enter the loaded cell through the engine
-- replication path without a fresh mod presence packet. Reconcile that cell
-- view every client tick so a compatibility replica never wins merely because
-- the network snapshot is older than the engine-owned object.
local function reconcileNativeBodies()
    if type(getCell) ~= "function" then return 0 end
    local cellOk, cell = pcall(getCell)
    if not cellOk or not cell or not cell.getObjectListForLua then return 0 end
    local listOk, list = pcall(cell.getObjectListForLua, cell)
    if not listOk or not list or not list.size or not list.get then return 0 end
    local countOk, count = pcall(list.size, list)
    if not countOk then return 0 end
    local promoted = 0
    for i=0,count-1 do
        local objectOk, object = pcall(list.get, list, i)
        if objectOk and object and object.getModData then
            local dataOk, data = pcall(object.getModData, object)
            local id = dataOk and data and data.NeighborhoodNpcId
            if not id and object.getOnlineID then
                local onlineOk, onlineId = pcall(object.getOnlineID, object)
                if onlineOk then
                    local candidateId, candidateCount
                    for candidateId, state in pairs(NLNpcClient.states) do
                        if state and state.onlineId ~= nil
                                and tonumber(state.onlineId) == tonumber(onlineId) then
                            candidateCount = (candidateCount or 0) + 1
                        end
                    end
                    if candidateCount == 1 then
                        for candidateId, state in pairs(NLNpcClient.states) do
                            if state and state.onlineId ~= nil
                                    and tonumber(state.onlineId) == tonumber(onlineId) then
                                id = candidateId
                                break
                            end
                        end
                    end
                end
            end
            if id and (not data or data.NeighborhoodNpcReplica ~= true) then
                id = tostring(id)
                local known = NLNpcClient.bodies[id]
                local knownIsFallback = false
                if known and known.getModData then
                    local knownDataOk, knownData = pcall(known.getModData, known)
                    knownIsFallback = knownDataOk and knownData
                        and knownData.NeighborhoodNpcReplica == true
                end
                if known ~= object and (not known or knownIsFallback or bodyPresent(known) == false) then
                    if known then forgetReplica(id, known) end
                    NLNpcClient.bodies[id] = object
                    local target = NLNpcClient.targets[id] or NLNpcClient.states[id]
                    if target and target.x and target.y then
                        positionBody(object, target.x, target.y, target.z or 0)
                    end
                    NLNpcClient.modes[id] = "native"
                    NLPlumbob.register("npc:" .. id, object, 0, NLPlumbob.remoteColor)
                    if NLNpcRender and NLNpcRender.register then
                        pcall(NLNpcRender.register, "npc:" .. id, object)
                    end
                    promoted = promoted + 1
                end
            end
        end
    end
    return promoted
end

NLNpcClient.reconcileNativeBodies = reconcileNativeBodies

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
            local body = NLNpcClient.bodies[id]
            -- A server-native body can arrive after the client has already
            -- created its compatibility replica. Promote to that body as
            -- soon as it appears instead of leaving the fallback in place.
            local discovered = nativeBody(id, entry.onlineId)
            if discovered and discovered ~= body then
                if body then forgetReplica(id, body) end
                body = discovered
                NLNpcClient.bodies[id] = body
                positionBody(body, entry.x, entry.y, entry.z)
                NLPlumbob.register("npc:" .. id, body, 0, NLPlumbob.remoteColor)
                if NLNpcRender and NLNpcRender.register then
                    pcall(NLNpcRender.register, "npc:" .. id, body)
                end
            end
            if body and bodyPresent(body) == false then
                forgetReplica(id, body)
                body = nil
            end
            body = body or createReplica(entry)
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
            forgetReplica(id, body)
            NLNpcClient.states[id] = nil
        end
    end
    return #packet.npcs
end

cancelNativePath = function(id, body)
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
    reconcileNativeBodies()
    for id, target in pairs(NLNpcClient.targets) do
        local body = NLNpcClient.bodies[id]
        if body and target then
            local desired = movementTarget(target)
            local path = NLNpcClient.paths[id]
            if path and (math.abs((desired.x or 0)-path.targetX) >= 0.35
                    or math.abs((desired.y or 0)-path.targetY) >= 0.35
                    or (desired.z or 0) ~= path.targetZ) then
                cancelNativePath(id, body)
            end
            if not advanceNativePath(id, body, desired) then
                local dx, dy = desired.x-body:getX(), desired.y-body:getY()
                local distance = math.sqrt(dx*dx + dy*dy)
                if distance > 0.02 then
                    local step = math.min(distance, 0.18)
                    positionBody(body, body:getX()+dx/distance*step,
                        body:getY()+dy/distance*step, desired.z)
                else
                    positionBody(body, desired.x, desired.y, desired.z)
                end
                NLNpcClient.modes[id] = "fallback"
            end
        end
    end
end

function NLNpcClient.cleanup()
    for id, body in pairs(NLNpcClient.bodies) do
        NLPlumbob.unregister("npc:" .. id)
        if NLNpcRender and NLNpcRender.unregister then pcall(NLNpcRender.unregister, "npc:" .. id) end
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
