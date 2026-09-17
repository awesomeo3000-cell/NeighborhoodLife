-- Single-player presentation bridge for authored Neighborhood Life NPCs.
--
-- Build 42 can create an IsoPlayer Lua object without presenting it in the
-- active world. Solo play therefore owns a small local bridge that explicitly
-- attaches authored neighbors to the world. Multiplayer keeps the existing
-- NLNpcAuthority + NLNpcClient replication path.
local function flag(name)
    local fn = _G[name]
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn)
    return ok and value == true
end

if flag("isClient") or flag("isServer") then return end

require "NL/Neighbors"
require "NL/Plumbob"

NLNpcSinglePlayer = {
    bodies = {},
    owned = {},
    started = false,
    tick = 0,
}

local IDS = { "marisol", "kenji", "amara" }

local function log(message)
    print("[NeighborhoodLife] NPC/SP " .. tostring(message))
end

log("bridge loaded")

local function safeCall(object, method, ...)
    if not object then return false, nil end
    local okMethod, fn = pcall(function() return object[method] end)
    if not okMethod or not fn then return false, nil end
    return pcall(fn, object, ...)
end

local function cell()
    if type(getCell) == "function" then
        local ok, value = pcall(getCell)
        if ok and value then return value end
    end
    if type(getWorld) == "function" then
        local okWorld, world = pcall(getWorld)
        if okWorld and world and world.getCell then
            local okCell, value = pcall(world.getCell, world)
            if okCell and value then return value end
        end
    end
    return nil
end

local function listSize(list)
    if not list or not list.size then return 0 end
    local ok, value = pcall(list.size, list)
    return ok and (tonumber(value) or 0) or 0
end

local function listGet(list, index)
    if not list or not list.get then return nil end
    local ok, value = pcall(list.get, list, index)
    return ok and value or nil
end

local function findExistingBody(id)
    local c = cell()
    if not c then return nil end
    local lists = {}
    if c.getObjectListForLua then
        local ok, list = pcall(c.getObjectListForLua, c)
        if ok and list then lists[#lists + 1] = list end
    end
    if c.getObjectList then
        local ok, list = pcall(c.getObjectList, c)
        if ok and list then lists[#lists + 1] = list end
    end
    for _, list in ipairs(lists) do
        for index = 0, listSize(list) - 1 do
            local object = listGet(list, index)
            if object and object.getModData then
                local ok, data = pcall(object.getModData, object)
                if ok and data and tostring(data.NeighborhoodNpcId or "") == tostring(id) then
                    return object
                end
            end
        end
    end
    return nil
end

local function squareKey(square)
    if not square then return nil end
    return tostring(square:getX()) .. ":" .. tostring(square:getY()) .. ":" .. tostring(square:getZ())
end

local function squareUsable(square, reserved)
    if not square then return false end
    local freeOk, free = pcall(square.isFree, square, false)
    if not freeOk or free ~= true then return false end
    if square.isSolidFloor then
        local floorOk, solid = pcall(square.isSolidFloor, square)
        if floorOk and solid ~= true then return false end
    end
    local key = squareKey(square)
    return not (reserved and key and reserved[key])
end

local function freeSquareNear(player, reserved, preferred)
    local c = cell()
    if not c or not player then return nil end
    if preferred then
        local ok, square = pcall(c.getGridSquare, c,
            math.floor(tonumber(preferred.x) or 0),
            math.floor(tonumber(preferred.y) or 0),
            math.floor(tonumber(preferred.z) or 0))
        if ok and squareUsable(square, reserved) then return square end
    end
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local best, bestDistance
    for dx = -4, 4 do
        for dy = -4, 4 do
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance >= 2 and distance <= 4 then
                local ok, square = pcall(c.getGridSquare, c, px + dx, py + dy, pz)
                if ok and squareUsable(square, reserved)
                        and (not best or distance < bestDistance) then
                    best, bestDistance = square, distance
                end
            end
        end
    end
    return best
end

local function createDescriptor(definition)
    if not SurvivorFactory or not SurvivorFactory.CreateSurvivor then
        return nil, "SurvivorFactory unavailable"
    end
    local female = definition.female ~= false
    local ok, desc = pcall(function()
        return SurvivorFactory.CreateSurvivor(nil, female)
    end)
    if not ok or not desc then
        ok, desc = pcall(function() return SurvivorFactory.CreateSurvivor() end)
        if not ok or not desc then return nil, tostring(desc) end
        safeCall(desc, "setFemale", female)
    end
    safeCall(desc, "setForename", definition.forename or "Neighbor")
    safeCall(desc, "setSurname", definition.surname or "Resident")
    if definition.outfit then safeCall(desc, "dressInNamedOutfit", definition.outfit) end
    return desc
end

local function prepareBody(id, definition, body, square)
    if not body then return nil end
    safeCall(body, "setNpc", true)
    safeCall(body, "setGhostMode", false)
    safeCall(body, "setSceneCulled", false)
    safeCall(body, "setUsername", (definition.name or id) .. " [Neighborhood Life]")
    safeCall(body, "setGodMod", true)
    safeCall(body, "setAlphaAndTarget", 1, 1)
    if square then
        local x, y, z = square:getX() + 0.5, square:getY() + 0.5, square:getZ()
        safeCall(body, "setX", x)
        safeCall(body, "setY", y)
        safeCall(body, "setZ", z)
        safeCall(body, "setCurrent", square)
    end
    if definition.outfit then safeCall(body, "dressInNamedOutfit", definition.outfit) end
    if not safeCall(body, "resetModel") then safeCall(body, "resetModelNextFrame") end
    if body.getModData then
        local ok, data = pcall(body.getModData, body)
        if ok and data then
            data.NeighborhoodNpcId = id
            data.NeighborhoodNpcSinglePlayer = true
        end
    end
    return body
end

local function createBody(id, definition, square)
    local c = cell()
    if not c or not square then return nil, "cell or spawn square unavailable" end
    if not IsoPlayer or not IsoPlayer.new then return nil, "IsoPlayer constructor unavailable" end
    local desc, descError = createDescriptor(definition)
    if not desc then return nil, descError end

    local ok, body = pcall(function()
        return IsoPlayer.new(c, desc, square:getX(), square:getY(), square:getZ())
    end)
    if not ok or not body then return nil, "IsoPlayer.new failed: " .. tostring(body) end

    prepareBody(id, definition, body, square)

    -- Critical for Build 42: constructing an IsoPlayer does not guarantee the
    -- object is registered for world presentation. Working NPC frameworks call
    -- addToWorld() explicitly. Without it the Lua body can exist while no model
    -- is rendered and no world interaction can discover it.
    local added, addError = safeCall(body, "addToWorld")
    if not added then
        return nil, "addToWorld failed: " .. tostring(addError)
    end

    -- Verify/repair the current square after world registration. Some builds
    -- overwrite the constructor position while attaching the object.
    prepareBody(id, definition, body, square)

    local currentOk, current = safeCall(body, "getCurrentSquare")
    if not currentOk or not current then
        local squareOk, fallbackSquare = safeCall(body, "getSquare")
        if not squareOk or not fallbackSquare then
            return nil, "world registration succeeded but body has no current square"
        end
    end

    return body
end

local function authorityWorld()
    if NLAuthority and NLAuthority.world then
        local ok, world = pcall(NLAuthority.world)
        if ok then return world end
    end
    return nil
end

local function registerBody(id, body, row)
    NLNpcSinglePlayer.bodies[id] = body
    if NLNpcAuthority then
        NLNpcAuthority.bodies = NLNpcAuthority.bodies or {}
        NLNpcAuthority.bodies[id] = body
    end
    if NLSocialAuthority and NLSocialAuthority.register then
        pcall(NLSocialAuthority.register, id, body, row and row.home or nil)
    end
    if NLPlumbob and NLPlumbob.register then
        pcall(NLPlumbob.register, "npc:" .. id, body, 0, NLPlumbob.remoteColor)
    end
end

function NLNpcSinglePlayer.start(_, player)
    if NLNpcSinglePlayer.started then return 0 end
    player = player or (getSpecificPlayer and getSpecificPlayer(0))
    if not player or player:isDead() then return 0 end
    local c = cell()
    if not c then
        log("spawn deferred: cell unavailable")
        return 0
    end

    local world = authorityWorld()
    local rows = world and NLNeighbors.ensure(world) or nil
    local reserved = {}
    local count = 0

    for _, id in ipairs(IDS) do
        local definition = NLNeighbors.definitions[id]
        local row = rows and rows[id] or nil
        local body = findExistingBody(id)
        if body then
            local current = body.getCurrentSquare and body:getCurrentSquare() or nil
            prepareBody(id, definition, body, current)
            log("reusing world body for " .. id)
        else
            local preferred = row and row.position or nil
            local square = freeSquareNear(player, reserved, preferred)
            if not square then
                log("SPAWN FAILED " .. id .. ": no free square within 2-4 tiles")
            else
                if row then
                    row.home = { x=square:getX(), y=square:getY(), z=square:getZ() }
                    row.position = { x=square:getX(), y=square:getY(), z=square:getZ() }
                    row.waypoint = 1
                    row.spawned = true
                end
                local err
                body, err = createBody(id, definition, square)
                if body then
                    NLNpcSinglePlayer.owned[id] = true
                    log(string.format("spawned %s at %d,%d,%d and added to world", id,
                        square:getX(), square:getY(), square:getZ()))
                else
                    log("SPAWN FAILED " .. id .. ": " .. tostring(err))
                end
            end
        end

        if body then
            local key = math.floor(body:getX()) .. ":" .. math.floor(body:getY()) .. ":" .. math.floor(body:getZ())
            reserved[key] = true
            if row and world then
                NLNeighbors.position(world, id, body:getX(), body:getY(), body:getZ(), row.waypoint or 1)
            end
            registerBody(id, body, row)
            count = count + 1
        end
    end

    if count == #IDS then
        NLNpcSinglePlayer.started = true
        if NLNpcAuthority then
            NLNpcAuthority.started = true
            NLNpcAuthority.startAttempts = 0
        end
        log("ready: 3/3 NPCs registered in world")
    else
        log("incomplete: " .. tostring(count) .. "/3 NPCs registered; retrying")
    end
    return count
end

function NLNpcSinglePlayer.update()
    if NLNpcSinglePlayer.started then return end
    NLNpcSinglePlayer.tick = NLNpcSinglePlayer.tick + 1
    if NLNpcSinglePlayer.tick == 1 or NLNpcSinglePlayer.tick % 60 == 0 then
        NLNpcSinglePlayer.start()
    end
end

function NLNpcSinglePlayer.cleanup()
    for id, body in pairs(NLNpcSinglePlayer.bodies) do
        if NLPlumbob and NLPlumbob.unregister then pcall(NLPlumbob.unregister, "npc:" .. id) end
        if NLNpcSinglePlayer.owned[id] and body then
            safeCall(body, "removeFromSquare")
            safeCall(body, "removeFromWorld")
        end
    end
    NLNpcSinglePlayer.bodies = {}
    NLNpcSinglePlayer.owned = {}
    NLNpcSinglePlayer.started = false
    NLNpcSinglePlayer.tick = 0
end

if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(NLNpcSinglePlayer.start) end
if Events.OnGameStart then Events.OnGameStart.Add(function() NLNpcSinglePlayer.start() end) end
if Events.OnTick then Events.OnTick.Add(NLNpcSinglePlayer.update) end
if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(NLNpcSinglePlayer.cleanup) end

return NLNpcSinglePlayer
