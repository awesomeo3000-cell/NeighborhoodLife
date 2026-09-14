-- Authoritative neighborhood-body adapter.
--
-- The identity and route live in ModData; the IsoPlayer is only the native
-- in-world body for the current server/world.  This keeps a save/reload from
-- manufacturing a different neighbor while still letting Build 42 render,
-- collide with and path the body normally.
if isClient() then return end

require "NL/Authority"
require "NL/Neighbors"
require "NL/SocialAuthority"

NLNpcAuthority = {
    bodies = {},
    targets = {},
    tick = 0,
    started = false,
    definitions = { "marisol" },
}

local function emit(message)
    if NLQANpc or NLQAMultiplayerServer then
        print("NLQA NPC PRODUCTION " .. message)
    end
end

local function freeSquareNear(cell, x, y, z, minDistance, maxDistance)
    local best, bestDistance
    for dx = -maxDistance, maxDistance do
        for dy = -maxDistance, maxDistance do
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance >= minDistance and distance <= maxDistance then
                local square = cell:getGridSquare(x + dx, y + dy, z)
                if square and square:isFree(false)
                        and (not best or distance < bestDistance) then
                    best, bestDistance = square, distance
                end
            end
        end
    end
    return best
end

local function setBodyPosition(body, square)
    body:setX(square:getX() + 0.5)
    body:setY(square:getY() + 0.5)
    body:setCurrent(square)
    body:setSceneCulled(false)
    body:setAlphaAndTarget(1, 1)
    body:resetModelNextFrame()
end

local function spawnBody(id, row, player)
    if not IsoPlayer or not SurvivorFactory then return nil, "native NPC constructors unavailable" end
    local cell = getCell()
    if not cell then return nil, "cell unavailable" end
    local x, y, z = math.floor(row.position.x), math.floor(row.position.y), math.floor(row.position.z)
    local square = cell:getGridSquare(x, y, z)
    if not square or not square:isFree(false) then
        square = freeSquareNear(cell, math.floor(player:getX()), math.floor(player:getY()),
            math.floor(player:getZ()), 2, 4)
    end
    if not square then return nil, "no free spawn square" end

    local desc = SurvivorFactory.CreateSurvivor()
    desc:setForename("Marisol")
    desc:setSurname("Vega")
    desc:setFemale(true)
    local body = IsoPlayer.new(cell, desc, square:getX(), square:getY(), square:getZ())
    body:setNpc(true)
    body:setUsername("Marisol Vega [Neighborhood Life]")
    body:setGodMod(true)
    body:getModData().NeighborhoodNpcId = id
    body:dressInNamedOutfit("Generic01")
    setBodyPosition(body, square)
    if not cell:getObjectList():contains(body) then cell:getObjectList():add(body) end
    NLNpcAuthority.bodies[id] = body
    NLSocialAuthority.register(id, body, row.home)
    NLNeighbors.position(NLAuthority.world(), id, body:getX(), body:getY(), body:getZ(), row.waypoint)
    if NLPlumbob then
        NLPlumbob.register("npc:" .. id, body, 0, NLPlumbob.remoteColor)
    end
    emit(string.format("SPAWN id=%s x=%.2f y=%.2f z=%.0f", id, body:getX(), body:getY(), body:getZ()))
    return body
end

function NLNpcAuthority.start()
    if NLNpcAuthority.started or isClient() then return end
    local player = getSpecificPlayer(0)
    if not player then return end
    local world = NLAuthority.world()
    local rows = NLNeighbors.ensure(world)
    local id = NLNpcAuthority.definitions[1]
    local row = rows[id]
    if not row or row.alive == false then return end
    -- The first isolated world gets a nearby home so the vertical slice is
    -- immediately observable.  Subsequent starts restore the saved position.
    if row.revision == 0 and not row.spawned then
        local square = freeSquareNear(getCell(), math.floor(player:getX()), math.floor(player:getY()),
            math.floor(player:getZ()), 2, 4)
        if square then
            row.home = { x = square:getX(), y = square:getY(), z = square:getZ() }
            row.position = { x = square:getX(), y = square:getY(), z = square:getZ() }
            row.waypoint = 1
            row.spawned = true
        end
    end
    if row.revision > 0 then
        emit(string.format("RESTORE id=%s x=%.2f y=%.2f revision=%d", id,
            row.position.x, row.position.y, row.revision))
    end
    local body, err = spawnBody(id, row, player)
    if body then NLNpcAuthority.started = true else emit("SPAWN FAILED: " .. tostring(err)) end
end

local function nextWaypoint(row, body)
    if row.spawned and row.home then
        local index = row.waypoint or 1
        if index == 1 then
            return { x = row.home.x + 2, y = row.home.y, z = row.home.z }, index
        end
        return { x = row.home.x, y = row.home.y + 2, z = row.home.z }, 2
    end
    local route = NLNeighbors.definitions[row.id].waypoints
    if not route or #route == 0 then return nil end
    local index = row.waypoint or 1
    local target = route[index]
    if not target then index = 1; target = route[index] end
    -- A saved first-world home supersedes the static definition for the first
    -- leg, then the route continues through the authored neighborhood points.
    if row.revision == 0 and row.home then target = row.home end
    return target, index
end

function NLNpcAuthority.update()
    if not NLNpcAuthority.started then NLNpcAuthority.start(); return end
    NLNpcAuthority.tick = NLNpcAuthority.tick + 1
    if NLNpcAuthority.tick % 300 == 0 then
        for id, body in pairs(NLNpcAuthority.bodies) do
            emit(string.format("TICK id=%s x=%.2f y=%.2f", id, body:getX(), body:getY()))
        end
    end
    for id, body in pairs(NLNpcAuthority.bodies) do
        local world = NLAuthority.world()
        local row = NLNeighbors.get(world, id)
        if not row or row.alive == false or body:isDead() then
            if row then NLNeighbors.dead(world, id) end
        else
            local behavior = body:getPathFindBehavior2()
            if not body:hasPath() and not NLNpcAuthority.targets[id] then
                NLNpcAuthority.targets = NLNpcAuthority.targets or {}
                local target, index = nextWaypoint(row, body)
                if target then
                    NLNpcAuthority.targets[id] = { x=target.x, y=target.y, z=target.z, waypoint=index }
                    behavior:pathToLocation(target.x, target.y, target.z)
                    emit(string.format("PATH id=%s from=%.2f,%.2f to=%.2f,%.2f waypoint=%d",
                        id, body:getX(), body:getY(), target.x, target.y, index))
                end
            end
            local target = NLNpcAuthority.targets and NLNpcAuthority.targets[id]
            if target then
                local ok, result = pcall(function()
                    body:preupdate(); body:update(); local r = behavior:update(); body:postupdate(); return r
                end)
                if not ok then
                    behavior:cancel(); body:setPath2(nil); NLNpcAuthority.targets[id] = nil
                elseif result == BehaviorResult.Succeeded then
                    behavior:cancel(); body:setPath2(nil)
                    local next = (target.waypoint or 1) + 1
                    local route = NLNeighbors.definitions[id].waypoints
                    if row.spawned then
                        if next > 2 then next = 1 end
                    elseif route and next > #route then next = 1 end
                    NLNeighbors.position(world, id, body:getX(), body:getY(), body:getZ(), next)
                    NLNpcAuthority.targets[id] = nil
                    emit(string.format("MOVE id=%s x=%.2f y=%.2f waypoint=%d",
                        id, body:getX(), body:getY(), next))
                end
            end
            if NLNpcAuthority.tick % 120 == 0 then
                NLNeighbors.position(world, id, body:getX(), body:getY(), body:getZ(), row.waypoint)
            end
        end
    end
end

function NLNpcAuthority.reset()
    NLNpcAuthority.bodies = {}
    NLNpcAuthority.targets = {}
    NLNpcAuthority.started = false
    NLNpcAuthority.tick = 0
end

Events.OnGameStart.Add(NLNpcAuthority.start)
-- Dedicated servers own their simulation cadence.  In single-player the
-- client-side HUD bridge owns the cadence because Build 42 keeps server and
-- client event queues separate even though the world body is shared.
if isServer() then
    Events.OnTick.Add(NLNpcAuthority.update)
end
Events.OnMainMenuEnter.Add(NLNpcAuthority.reset)
return NLNpcAuthority
