-- Client view of authoritative NPC state.
--
-- Build 42.20.4 does not expose the native server re-announcement path to Lua.
-- When a native server body is not present in the client's online list, this
-- creates a local native IsoPlayer replica driven only by server npc_presence
-- packets. It remains a real in-world character locally (model, object and
-- plumbob), while all position/state authority remains server-side.
if not isClient or not isClient() then return end

require "NL/Plumbob"
NLNpcClient = { bodies={}, targets={}, states={}, revision=0 }

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
        desc:setForename("Marisol"); desc:setSurname("Vega"); desc:setFemale(true)
        body = IsoPlayer.new(cell, desc, math.floor(entry.x), math.floor(entry.y), math.floor(entry.z))
        body:setNpc(true)
        body:setUsername("Marisol Vega [Neighborhood Life]")
        body:setGodMod(true)
        body:getModData().NeighborhoodNpcId = id
        body:dressInNamedOutfit("Generic01")
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
            if body then NLNpcClient.targets[id] = entry end
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
            NLNpcClient.states[id] = nil
        end
    end
    return #packet.npcs
end

function NLNpcClient.update()
    for id, target in pairs(NLNpcClient.targets) do
        local body = NLNpcClient.bodies[id]
        if body and target then
            local dx, dy = target.x-body:getX(), target.y-body:getY()
            local distance = math.sqrt(dx*dx + dy*dy)
            if distance > 0.02 then
                local step = math.min(distance, 0.18)
                positionBody(body, body:getX()+dx/distance*step,
                    body:getY()+dy/distance*step, target.z)
            else
                positionBody(body, target.x, target.y, target.z)
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
    NLNpcClient.bodies={}; NLNpcClient.targets={}; NLNpcClient.states={}; NLNpcClient.revision=0
end

Events.OnTick.Add(NLNpcClient.update)
Events.OnMainMenuEnter.Add(NLNpcClient.cleanup)
if Events.OnDisconnect then
    Events.OnDisconnect.Add(NLNpcClient.cleanup)
end
return NLNpcClient
