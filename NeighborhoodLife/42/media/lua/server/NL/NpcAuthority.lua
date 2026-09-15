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
    offscreen = {},
    tick = 0,
    started = false,
    startAttempts = 0,
    danger = {},
    repairStacked = true,
    -- Presence is a motion heartbeat as well as a lifecycle snapshot. Thirty
    -- server ticks keeps client replicas moving toward the same native route
    -- target without waiting for the older twelve-second refresh interval.
    presenceInterval = 30,
    motionSequence = 0,
    definitions = { "marisol", "kenji", "amara" },
}

local function emit(message)
    if NLQANpc or NLQAMultiplayerServer then
        print("NLQA NPC PRODUCTION " .. message)
    end
end

local function hasOnlineId(body, onlineId)
    if not body or not body.getOnlineID or onlineId == nil then return false end
    local ok, value = pcall(body.getOnlineID, body)
    return ok and tonumber(value) == tonumber(onlineId)
end

-- Build 42's dedicated Kahlua host exposes IsoPlayer.setOnlineID(short), but
-- Lua numbers arrive as Double and the field proxy is not writable there. Do
-- not invoke either unsupported route on that host: it produces an engine
-- error for every authored body without changing the id. A future engine
-- bridge can provide a typed setter explicitly; the older GameServer-exposed
-- host keeps the original best-effort calls for compatibility.
local function assignNativeOnlineId(body, onlineId)
    if not body or onlineId == nil then return false end
    local typedOk, typedSetter = pcall(function() return NLNativeOnlineIdSetter end)
    if typedOk and type(typedSetter) == "function" then
        local callOk = pcall(typedSetter, body, tonumber(onlineId))
        if callOk and hasOnlineId(body, onlineId) then return true end
    end
    local serverOk, serverApi = pcall(function() return GameServer end)
    if not serverOk or type(serverApi) ~= "table" then return false end
    local methodOk, setter = pcall(function() return body.setOnlineID end)
    if methodOk and setter then pcall(setter, body, onlineId) end
    if hasOnlineId(body, onlineId) then return true end
    local fieldOk = pcall(function() body.onlineId = onlineId end)
    return fieldOk and hasOnlineId(body, onlineId)
end

NLNpcAuthority.assignNativeOnlineId = assignNativeOnlineId

local function presencePacket()
    local world = NLAuthority.world()
    local entries = {}
    local onlineIdCounts = {}
    for id, body in pairs(NLNpcAuthority.bodies) do
        local row = NLNeighbors.get(world, id)
        local definition = NLNeighbors.definitions[id]
        if row and row.alive ~= false and body and not body:isDead() then
            local isFemale = true
            if definition and definition.female ~= nil then isFemale = definition.female end
            local onlineId
            if body.getOnlineID then
                local onlineOk, value = pcall(body.getOnlineID, body)
                if onlineOk and tonumber(value) and tonumber(value) >= 0 then
                    onlineId = tonumber(value)
                end
            end
            local target = NLNpcAuthority.targets[id]
            entries[#entries + 1] = {
                id=id, x=body:getX(), y=body:getY(), z=body:getZ(),
                waypoint=row.waypoint or 1,
                alive=true, revision=row.revision or 0,
                name=definition and definition.name or id,
                female=isFemale,
                outfit=definition and definition.outfit or "Generic01",
                onlineId=onlineId,
                routine=row.routine or "home",
                schedule=definition and definition.schedule or nil,
                -- The position is the authoritative sample; the motion
                -- target lets a client continue the same route between
                -- heartbeats instead of repeatedly stopping at each sample.
                motion=target and {
                    active=true, sequence=NLNpcAuthority.motionSequence,
                    targetX=(target.x or body:getX()) + 0.5,
                    targetY=(target.y or body:getY()) + 0.5,
                    targetZ=target.z or body:getZ(),
                    waypoint=target.waypoint or row.waypoint or 1,
                } or nil,
            }
            if onlineId ~= nil then
                onlineIdCounts[onlineId] = (onlineIdCounts[onlineId] or 0) + 1
            end
        end
    end
    -- Build 42 currently returns the same default online id for multiple
    -- server-created NPC IsoPlayers. A duplicate hint is unsafe for client
    -- promotion, so only publish an identity that is unique in this roster.
    for _, entry in ipairs(entries) do
        if entry.onlineId ~= nil and onlineIdCounts[entry.onlineId] ~= 1 then
            entry.onlineId = nil
        end
    end
    return { revision=getTimestampMs(), npcs=entries }, #entries
end
NLNpcAuthority.presencePacket = presencePacket

function NLNpcAuthority.sendPresence(player)
    if not isServer() or not player then return 0 end
    local packet, count = presencePacket()
    sendServerCommand(player, "NeighborhoodLife", "npc_presence", packet)
    NLNpcAuthority.reannounceTo(player)
    return count
end

-- Build 42 exposes the native server reannouncement entry point only on
-- installations that publish GameServer to Lua. Use it when available, but
-- keep the authoritative npc_presence path as the compatibility route.
local function gameServerApi()
    local apiOk, api = pcall(function() return GameServer end)
    if apiOk and api and api.getConnectionFromPlayer and api.sendPlayerConnected then
        return api, "global"
    end
    -- Dedicated Build 42 omits the GameServer global, but its Kahlua bridge
    -- can expose the loaded static class through getClass. Keep this adapter
    -- best-effort: the authoritative npc_presence packet remains the fallback.
    if type(getClass) == "function" then
        local classOk, classApi = pcall(getClass, "zombie.network.GameServer")
        if classOk and classApi and classApi.getConnectionFromPlayer
                and classApi.sendPlayerConnected then
            return classApi, "getClass"
        end
    end
    return nil, nil
end
NLNpcAuthority.resolveGameServer = gameServerApi

-- A QA or future engine bridge may expose the typed server registration path as
-- a JavaFunction. Prefer that path over Lua's optional GameServer surface: the
-- bridge owns the per-connection UdpConnection slot, server registries and
-- ConnectedPlayer packet, while this module keeps the compatibility packet as
-- the fallback for unbridged installations.
local function nativeNpcBridge()
    local bridgeOk, bridge = pcall(function() return NLNativeNpcBridge end)
    if bridgeOk and type(bridge) == "function" then return bridge end
    return nil
end
NLNpcAuthority.resolveNativeNpcBridge = nativeNpcBridge

-- An unowned server IsoPlayer can have its public position reset by the
-- engine's network update unless the authoritative real-position fields are
-- updated alongside the visible coordinates. A typed bridge may provide that
-- write without relying on Build 42's restricted Lua field proxy.
local function syncNativePosition(body, x, y, z)
    local setterOk, setter = pcall(function() return NLNativeNpcPositionSync end)
    if not setterOk or type(setter) ~= "function" then return false end
    local callOk, result = pcall(setter, body, x, y, z)
    return callOk and result ~= false
end
NLNpcAuthority.syncNativePosition = syncNativePosition

local function javaCall(receiver, methodName, ...)
    if not receiver then return false, nil end
    local methodOk, method = pcall(function() return receiver[methodName] end)
    if not methodOk or not method then return false, nil end
    return pcall(method, receiver, ...)
end

-- A server-created IsoPlayer must occupy the same native registries as a
-- connected player before ConnectedPlayer is sent.  Build 42 keeps these
-- registries public on GameServer, but only some Lua hosts publish the class
-- bridge.  Registration is therefore additive and verified per Java call;
-- the npc_presence compatibility packet remains authoritative when the bridge
-- is absent.
local function registerNativeBody(api, body)
    if not api or not body then return 0 end
    local idOk, onlineId = pcall(body.getOnlineID, body)
    if not idOk or tonumber(onlineId) == nil then return 0 end
    onlineId = tonumber(onlineId)
    local nameOk, username = pcall(body.getUsername, body)
    if not nameOk or not username or username == "" then return 0 end
    local registered = 0

    local rosterOk, roster = pcall(function() return api.Players end)
    if rosterOk and roster then
        local containsOk, contains = javaCall(roster, "contains", body)
        if containsOk and not contains then
            local addOk = javaCall(roster, "add", body)
            if addOk then registered = registered + 1 end
        end
    end

    local mapSpecs = {
        { field = "IDToPlayerMap", key = onlineId, value = body },
        { field = "UserNameToPlayerMap", key = username, value = onlineId },
    }
    for _, spec in ipairs(mapSpecs) do
        local fieldOk, map = pcall(function() return api[spec.field] end)
        if fieldOk and map then
            local putOk = javaCall(map, "put", spec.key, spec.value)
            if putOk then registered = registered + 1 end
        end
    end
    return registered
end
NLNpcAuthority.registerNativeBody = registerNativeBody

function NLNpcAuthority.reannounceTo(player)
    if not player then return 0 end
    local typedBridge = nativeNpcBridge()
    if typedBridge then
        local sent = 0
        for _, body in pairs(NLNpcAuthority.bodies) do
            if body then
                local bridgeOk, bridgeResult = pcall(typedBridge, body, player)
                if bridgeOk and bridgeResult ~= false then
                    sent = sent + 1
                    emit("ROSTER source=typed id=" .. tostring(body:getOnlineID()))
                end
            end
        end
        if sent > 0 then emit("REANNOUNCE source=typed sent=" .. tostring(sent)) end
        return sent
    end
    local api, source = gameServerApi()
    if not api then return 0 end
    local connectionOk, connection = pcall(api.getConnectionFromPlayer, player)
    if not connectionOk or not connection then return 0 end
    local sent = 0
    for _, body in pairs(NLNpcAuthority.bodies) do
        if body then
            local registered = registerNativeBody(api, body)
            local ok = pcall(api.sendPlayerConnected, body, connection)
            if ok then
                sent = sent + 1
                if registered > 0 then
                    emit("ROSTER source=" .. tostring(source) .. " id=" .. tostring(body:getOnlineID())
                        .. " fields=" .. tostring(registered))
                end
            end
        end
    end
    if sent > 0 then emit("REANNOUNCE source=" .. tostring(source) .. " sent=" .. tostring(sent)) end
    return sent
end

function NLNpcAuthority.reannounce()
    if not isServer() or type(getOnlinePlayers) ~= "function" then return 0 end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return 0 end
    local sent = 0
    for i = 0, players:size() - 1 do
        sent = sent + NLNpcAuthority.reannounceTo(players:get(i))
    end
    return sent
end

function NLNpcAuthority.broadcastPresence()
    if not isServer() or type(getOnlinePlayers) ~= "function" then return 0 end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then return 0 end
    local packet, count = presencePacket()
    for i=0,players:size()-1 do
        sendServerCommand(players:get(i), "NeighborhoodLife", "npc_presence", packet)
    end
    return count
end

-- Save the authoritative position before Build 42 serializes world ModData.
-- The periodic checkpoint remains useful during a live server, while this
-- hook closes the short window between checkpoints and a normal save/restart.
function NLNpcAuthority.persist()
    local world = NLAuthority.world()
    local count = 0
    for id, body in pairs(NLNpcAuthority.bodies) do
        local row = NLNeighbors.get(world, id)
        if row and body and not body:isDead() then
            NLNeighbors.position(world, id, body:getX(), body:getY(), body:getZ(), row.waypoint)
            count = count + 1
        end
    end
    return count
end

local function freeSquareNear(cell, x, y, z, minDistance, maxDistance, reserved)
    local best, bestDistance
    for dx = -maxDistance, maxDistance do
        for dy = -maxDistance, maxDistance do
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance >= minDistance and distance <= maxDistance then
                local square = cell:getGridSquare(x + dx, y + dy, z)
                local key = square and (square:getX() .. ":" .. square:getY() .. ":" .. square:getZ())
                if square and square:isFree(false) and (not reserved or not reserved[key])
                        and (not best or distance < bestDistance) then
                    best, bestDistance = square, distance
                end
            end
        end
    end
    return best
end

-- The native path behavior is authoritative when it advances.  The dedicated
-- server can still stall an unowned IsoPlayer, so its bounded fallback must
-- never step through a solid tile or an occupied square.  Choosing the next
-- free tile toward the target also lets a neighbor turn around a short-lived
-- obstruction instead of teleporting through it.
local function walkableSquare(cell, x, y, z)
    if not cell then return nil end
    local ok, square = pcall(cell.getGridSquare, cell, math.floor(x), math.floor(y), z)
    if not ok or not square then return nil end
    local freeOk, free = pcall(function() return square:isFree(false) end)
    if not freeOk or not free then return nil end
    if square.isSolidFloor then
        local floorOk, solid = pcall(function() return square:isSolidFloor() end)
        if floorOk and not solid then return nil end
    end
    return square
end

local function fallbackStep(body, target)
    if not body or not target then return nil end
    local currentX, currentY, currentZ = body:getX(), body:getY(), body:getZ()
    local destinationX, destinationY = target.x + 0.5, target.y + 0.5
    local cell = getCell and getCell()
    local function stepToward(goalX, goalY)
        local dx, dy = goalX - currentX, goalY - currentY
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= 0.05 then return currentX, currentY, nil end
        local signX = dx > 0 and 1 or (dx < 0 and -1 or 0)
        local signY = dy > 0 and 1 or (dy < 0 and -1 or 0)
        local directions = {}
        local function addDirection(x, y)
            if x ~= 0 or y ~= 0 then directions[#directions + 1] = { x=x, y=y } end
        end
        if signX ~= 0 then addDirection(signX, 0) end
        if signY ~= 0 then addDirection(0, signY) end
        if signX ~= 0 and signY ~= 0 then addDirection(signX, signY) end
        -- Keep both sides available for a perpendicular detour.  The old
        -- one-sided choice could walk into a blocked corner and oscillate in
        -- the same tile forever.
        if signX ~= 0 then addDirection(0, 1); addDirection(0, -1) end
        if signY ~= 0 then addDirection(1, 0); addDirection(-1, 0) end
        local step = math.min(0.08, distance)
        local best, bestScore
        for _, direction in ipairs(directions) do
            local length = math.sqrt(direction.x * direction.x + direction.y * direction.y)
            local nextX = currentX + direction.x / length * step
            local nextY = currentY + direction.y / length * step
            local crossesTile = math.floor(nextX) ~= math.floor(currentX)
                or math.floor(nextY) ~= math.floor(currentY)
            -- The current tile contains the body itself, so do not ask
            -- `isFree(false)` to reject that tile.  Only a tile-boundary
            -- crossing needs an occupancy/solid-floor check.
            local square = true
            if crossesTile then square = walkableSquare(cell, nextX, nextY, currentZ) end
            if square then
                local remainingX, remainingY = goalX - nextX, goalY - nextY
                local score = remainingX * remainingX + remainingY * remainingY
                if not best or score < bestScore then
                    best, bestScore = { x=nextX, y=nextY, square=square }, score
                end
            end
        end
        if not best then return nil end
        return best.x, best.y, best.square
    end

    -- A stalled horizontal/vertical route needs a remembered one-tile detour,
    -- not an arbitrary micro-step that leaves the body oscillating beside the
    -- same obstacle.  The detour is temporary target state and is cleared as
    -- soon as the adjacent tile is reached.
    if target.detour then
        local detour = target.detour
        local detourDistance = math.sqrt((detour.x-currentX)^2 + (detour.y-currentY)^2)
        if detourDistance <= 0.08 then
            if detour.exit then
                target.detour = detour.exit
                return stepToward(target.detour.x, target.detour.y)
            end
            target.detour = nil
        else
            return stepToward(detour.x, detour.y)
        end
    end

    local dx, dy = destinationX - currentX, destinationY - currentY
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance <= 0.05 then return currentX, currentY, nil end
    local step = math.min(0.08, distance)
    local directX = currentX + dx / distance * step
    local directY = currentY + dy / distance * step
    local crossesTile = math.floor(directX) ~= math.floor(currentX)
        or math.floor(directY) ~= math.floor(currentY)
    if crossesTile and not walkableSquare(cell, directX, directY, currentZ) then
        local tileX, tileY = math.floor(currentX), math.floor(currentY)
        local candidates = {}
        if math.abs(dx) >= math.abs(dy) then
            local nextTileX = tileX + (dx > 0 and 1 or -1)
            candidates = { { x=tileX + 0.5, y=tileY - 0.5,
                    exit={x=nextTileX + 0.5, y=tileY - 0.5} },
                { x=tileX + 0.5, y=tileY + 1.5,
                    exit={x=nextTileX + 0.5, y=tileY + 1.5} } }
        else
            local nextTileY = tileY + (dy > 0 and 1 or -1)
            candidates = { { x=tileX - 0.5, y=tileY + 0.5,
                    exit={x=tileX - 0.5, y=nextTileY + 0.5} },
                { x=tileX + 1.5, y=tileY + 0.5,
                    exit={x=tileX + 1.5, y=nextTileY + 0.5} } }
        end
        local detour, detourScore
        for _, candidate in ipairs(candidates) do
            local square = walkableSquare(cell, candidate.x, candidate.y, currentZ)
            local exitSquare = candidate.exit
                and walkableSquare(cell, candidate.exit.x, candidate.exit.y, currentZ)
            if square and exitSquare then
                local remainingX, remainingY = destinationX-candidate.x, destinationY-candidate.y
                local score = remainingX*remainingX + remainingY*remainingY
                if not detour or score < detourScore then
                    detour, detourScore = candidate, score
                end
            end
        end
        if detour then
            target.detour = detour
            return stepToward(detour.x, detour.y)
        end
    end
    return stepToward(destinationX, destinationY)
end

-- Exposed for the deterministic contract suite; gameplay still reaches this
-- helper only through the server's stalled-native-path branch.
NLNpcAuthority.safeFallbackStep = fallbackStep

local function listSize(list)
    if not list or not list.size then return 0 end
    local ok, size = pcall(list.size, list)
    return ok and (tonumber(size) or 0) or 0
end

local function listGet(list, index)
    if not list or not list.get then return nil end
    local ok, value = pcall(list.get, list, index)
    return ok and value or nil
end

local function livingZombie(value)
    if not value or not value.isZombie then return false end
    local zombieOk, zombie = pcall(value.isZombie, value)
    if not zombieOk or zombie ~= true then return false end
    if value.isDead then
        local deadOk, dead = pcall(value.isDead, value)
        if deadOk and dead == true then return false end
    end
    if value.isFakeDead then
        local fakeOk, fake = pcall(value.isFakeDead, value)
        if fakeOk and fake == true then return false end
    end
    return true
end

-- Return the closest living zombie in the loaded server cell. Build 42's
-- getZombieList is cheaper and more reliable than trusting a single square's
-- moving-object list, while the square scan keeps the adapter usable on older
-- engine builds and deterministic fixtures.
local function dangerNear(body, radius)
    if not body or not body.getX or not body.getY then return nil end
    if type(getCell) ~= "function" then return nil end
    local cellOk, cell = pcall(getCell)
    if not cellOk or not cell then return nil end
    local bx, by, bz = body:getX(), body:getY(), body.getZ and body:getZ() or 0
    local limit = tonumber(radius or 4) or 4
    local best, bestDistance
    local function inspect(value)
        if not livingZombie(value) or not value.getX or not value.getY then return end
        local sameZ = not value.getZ or math.abs((value:getZ() or bz) - bz) <= 0.5
        if not sameZ then return end
        local dx, dy = value:getX() - bx, value:getY() - by
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= limit and (not bestDistance or distance < bestDistance) then
            best, bestDistance = value, distance
        end
    end
    local listOk, zombies = false, nil
    if cell.getZombieList then listOk, zombies = pcall(cell.getZombieList, cell) end
    if listOk and zombies then
        for index = 0, listSize(zombies) - 1 do inspect(listGet(zombies, index)) end
    elseif cell.getGridSquare then
        local minX, maxX = math.floor(bx - limit), math.floor(bx + limit)
        local minY, maxY = math.floor(by - limit), math.floor(by + limit)
        for x = minX, maxX do
            for y = minY, maxY do
                local squareOk, square = pcall(cell.getGridSquare, cell, x, y, bz)
                if squareOk and square and square.getMovingObjects then
                    local objectsOk, objects = pcall(square.getMovingObjects, square)
                    if objectsOk and objects then
                        for index = 0, listSize(objects) - 1 do inspect(listGet(objects, index)) end
                    end
                end
            end
        end
    end
    return best, bestDistance
end

local function dangerStep(body, zombie)
    if not body or not zombie or not body.getX or not zombie.getX then return nil end
    local bx, by, bz = body:getX(), body:getY(), body:getZ()
    local dx, dy = bx - zombie:getX(), by - zombie:getY()
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return nil end
    local step = math.min(0.12, math.max(0.04, distance * 0.25))
    local nextX, nextY = bx + dx / distance * step, by + dy / distance * step
    local crossesTile = math.floor(nextX) ~= math.floor(bx)
        or math.floor(nextY) ~= math.floor(by)
    local square = true
    if crossesTile then square = walkableSquare(type(getCell) == "function" and getCell() or nil,
        nextX, nextY, bz) end
    if not square then return nil end
    return nextX, nextY, square
end

NLNpcAuthority.dangerNear = dangerNear
NLNpcAuthority.safeDangerStep = dangerStep

local function npcReservedSquares()
    local reserved = {}
    for _, existing in pairs(NLNpcAuthority.bodies) do
        if existing and existing.getX and existing.getY and existing.getZ then
            local key = math.floor(existing:getX()) .. ":" .. math.floor(existing:getY())
                .. ":" .. math.floor(existing:getZ())
            reserved[key] = true
        end
    end
    return reserved
end

local function setBodyPosition(body, square, x, y, z)
    local targetX = x or square:getX() + 0.5
    local targetY = y or square:getY() + 0.5
    local targetZ = z or square:getZ()
    body:setX(targetX)
    body:setY(targetY)
    if body.setZ then body:setZ(targetZ) end
    body:setCurrent(square)
    body:setSceneCulled(false)
    body:setAlphaAndTarget(1, 1)
    body:resetModelNextFrame()
    syncNativePosition(body, targetX, targetY, targetZ)
end

local function anchorPlayer()
    if getSpecificPlayer then
        local ok, player = pcall(getSpecificPlayer, 0)
        if ok and player then return player end
    end
    if type(getOnlinePlayers) == "function" then
        local ok, players = pcall(getOnlinePlayers)
        if ok and players then
            local sizeOk, size = pcall(players.size, players)
            if sizeOk and size > 0 then
                local playerOk, player = pcall(players.get, players, 0)
                if playerOk and player then return player end
            end
        end
    end
    return nil
end

local function spawnBody(id, row, player)
    if not IsoPlayer or not SurvivorFactory then return nil, "native NPC constructors unavailable" end
    local cell = getCell()
    if not cell then return nil, "cell unavailable" end
    local x, y, z = math.floor(row.position.x), math.floor(row.position.y), math.floor(row.position.z)
    local reserved = npcReservedSquares()
    local square = cell:getGridSquare(x, y, z)
    local requestedKey = x .. ":" .. y .. ":" .. z
    if not square or not square:isFree(false) or reserved[requestedKey] then
        -- A saved tile can be occupied after a restart by a player, a corpse,
        -- or a streamed map object. Search around the persisted tile first so
        -- the neighbor stays in the same home area before falling back to the
        -- current player's area.
        square = freeSquareNear(cell, x, y, z, 0, 4, reserved)
    end
    if not square and player then
        square = freeSquareNear(cell, math.floor(player:getX()), math.floor(player:getY()),
            math.floor(player:getZ()), 2, 4, reserved)
    end
    if not square then return nil, "no free spawn square" end

    if square:getX() ~= x or square:getY() ~= y or square:getZ() ~= z then
        emit(string.format("RELOCATE id=%s from=%d,%d,%d to=%d,%d,%d", id, x, y, z,
            square:getX(), square:getY(), square:getZ()))
        -- Keep the saved home aligned with the repaired spawn so the authored
        -- route does not immediately stack legacy neighbors on the next tick.
        row.home = { x=square:getX(), y=square:getY(), z=square:getZ() }
    end

    local definition = NLNeighbors.definitions[id] or {}
    local desc = SurvivorFactory.CreateSurvivor()
    desc:setForename(definition.forename or id)
    desc:setSurname(definition.surname or "Neighbor")
    desc:setFemale(definition.female ~= false)
    local body = IsoPlayer.new(cell, desc, square:getX(), square:getY(), square:getZ())
    body:setNpc(true)
    -- IsoPlayer defaults every Lua-created body to online id 1. Assign the
    -- stable authored slot before any presence packet is built so a future
    -- native server reannouncement can identify each neighbor unambiguously.
    local onlineAssigned = assignNativeOnlineId(body, definition.onlineId)
    body:setUsername((definition.name or id) .. " [Neighborhood Life]")
    body:setGodMod(true)
    body:getModData().NeighborhoodNpcId = id
    body:dressInNamedOutfit(definition.outfit or "Generic01")
    local exactX, exactY, exactZ
    if row.revision > 0 and row.position
            and math.floor(row.position.x) == square:getX()
            and math.floor(row.position.y) == square:getY()
            and math.floor(row.position.z) == square:getZ() then
        exactX, exactY, exactZ = row.position.x, row.position.y, row.position.z
    end
    setBodyPosition(body, square, exactX, exactY, exactZ)
    if not cell:getObjectList():contains(body) then cell:getObjectList():add(body) end
    NLNpcAuthority.bodies[id] = body
    NLSocialAuthority.register(id, body, row.home)
    NLNeighbors.position(NLAuthority.world(), id, body:getX(), body:getY(), body:getZ(), row.waypoint)
    if NLPlumbob then
        NLPlumbob.register("npc:" .. id, body, 0, NLPlumbob.remoteColor)
    end
    emit(string.format("SPAWN id=%s x=%.2f y=%.2f z=%.0f onlineId=%s assigned=%s",
        id, body:getX(), body:getY(), body:getZ(), tostring(body.getOnlineID and body:getOnlineID() or nil),
        tostring(onlineAssigned)))
    return body
end

-- A native body is transient.  The identity row remains authoritative when
-- the streamed cell drops the body, so recovery never teleports an NPC to a
-- player merely because its home tile is temporarily unavailable.
local function bodyPresent(body)
    if not body or type(getCell) ~= "function" then return nil end
    local cellOk, cell = pcall(getCell)
    if not cellOk or not cell or not cell.getObjectList then return nil end
    -- Dedicated Build 42 can expose a server cell object list that omits
    -- server-owned IsoPlayers even while their current square is valid. The
    -- native square is the stronger liveness signal in that case.
    for _, method in ipairs({"getCurrentSquare", "getSquare"}) do
        if body[method] then
            local squareOk, square = pcall(body[method], body)
            if squareOk and square then return true end
        end
    end
    local listOk, list = pcall(cell.getObjectList, cell)
    if not listOk or not list or not list.contains then return nil end
    local containsOk, present = pcall(list.contains, list, body)
    if not containsOk then return nil end
    return present == true
end

local function detachBody(body)
    if not body or type(getCell) ~= "function" then return false end
    local cellOk, cell = pcall(getCell)
    if not cellOk or not cell or not cell.getObjectList then return false end
    local listOk, list = pcall(cell.getObjectList, cell)
    if not listOk or not list or not list.remove then return false end
    local removedOk = pcall(list.remove, list, body)
    return removedOk
end

local function cancelBodyPath(id, body)
    local target = NLNpcAuthority.targets[id]
    if target and target.behavior and target.behavior.cancel then
        pcall(target.behavior.cancel, target.behavior)
    end
    if body and body.getPathFindBehavior2 then
        local behaviorOk, behavior = pcall(body.getPathFindBehavior2, body)
        if behaviorOk and behavior and behavior.cancel then pcall(behavior.cancel, behavior) end
    end
    if body and body.setPath2 then pcall(body.setPath2, body, nil) end
    NLNpcAuthority.targets[id] = nil
end

-- A neighbor's authored career supplies a small, persisted daily routine. The
-- route stays relative to the saved home so the first-world nearby placement
-- and every later restart remain valid, while the server clock selects home or
-- work without any client-supplied time or position.
local function worldClock()
    if type(getGameTime) ~= "function" then return nil, nil end
    local ok, gameTime = pcall(getGameTime)
    if not ok or not gameTime then return nil, nil end
    local hour, day
    if gameTime.getHour then
        local hourOk, value = pcall(gameTime.getHour, gameTime)
        if hourOk then hour = tonumber(value) end
    end
    if gameTime.getDay then
        local dayOk, value = pcall(gameTime.getDay, gameTime)
        if dayOk then day = tonumber(value) end
    end
    return hour, day
end

local function routineForHour(definition, hour)
    if not definition or hour == nil then return "home" end
    local startHour = tonumber(definition.workStart or 8) or 8
    local endHour = tonumber(definition.workEnd or 17) or 17
    return hour >= startHour and hour < endHour and "work" or "home"
end

local function routineTarget(row, routine)
    if not row or not row.home then return nil, 1 end
    if routine == "work" then
        local definition = NLNeighbors.definitions[row.id] or {}
        local offset = definition.workOffset or { x=2, y=0 }
        return { x=row.home.x + (tonumber(offset.x) or 0),
            y=row.home.y + (tonumber(offset.y) or 0), z=row.home.z }, 2
    end
    -- Home time still has a small authored local route so a neighbor can be
    -- seen living in the neighborhood instead of freezing on the spawn tile.
    return { x=row.home.x, y=row.home.y + 2, z=row.home.z }, 1
end

NLNpcAuthority.worldClock = worldClock
NLNpcAuthority.routineForHour = routineForHour
NLNpcAuthority.routineTarget = routineTarget

local function refreshRoutine(world, id, row, body)
    local definition = NLNeighbors.definitions[id] or {}
    local hour, day = worldClock()
    local desired = routineForHour(definition, hour)
    local previous = row.routine
    NLNeighbors.routine(world, id, desired, day, hour)
    if previous ~= desired then
        cancelBodyPath(id, body)
        local target = routineTarget(row, desired)
        emit(string.format("ROUTINE id=%s state=%s hour=%s target=%s", id, desired,
            tostring(hour), tostring(target and (target.x .. "," .. target.y) or "nil")))
        return true
    end
    return false
end

local function retireBody(id, row, body, reason)
    local world = NLAuthority.world()
    if row and body and body.getX and body.getY and body.getZ then
        local positionOk, x, y, z = pcall(function()
            return body:getX(), body:getY(), body:getZ()
        end)
        if positionOk then
            if reason == "DEATH" then
                NLNeighbors.dead(world, id)
            elseif row.alive ~= false then
                NLNeighbors.position(world, id, x, y, z, row.waypoint)
            end
        end
    elseif reason == "DEATH" and row then
        NLNeighbors.dead(world, id)
    end
    cancelBodyPath(id, body)
    detachBody(body)
    if NLPlumbob and NLPlumbob.unregister then
        pcall(NLPlumbob.unregister, "npc:" .. id)
    end
    NLSocialAuthority.bodies[id] = nil
    NLNpcAuthority.bodies[id] = nil
    if reason == "OFFSCREEN" then
        NLNpcAuthority.offscreen[id] = { nextAttempt = NLNpcAuthority.tick + 30 }
        emit(string.format("OFFSCREEN id=%s retryTick=%d", id, NLNpcAuthority.offscreen[id].nextAttempt))
    else
        NLNpcAuthority.offscreen[id] = nil
        emit("DEATH id=" .. tostring(id))
    end
    return true
end

local function reconcileBodies()
    local world = NLAuthority.world()
    local changed = false
    for id, body in pairs(NLNpcAuthority.bodies) do
        local row = NLNeighbors.get(world, id)
        local deadOk, dead = pcall(body.isDead, body)
        if not row or row.alive == false or (deadOk and dead == true) then
            retireBody(id, row, body, "DEATH")
            changed = true
        else
            local present = bodyPresent(body)
            if present == false then
                retireBody(id, row, body, "OFFSCREEN")
                changed = true
            end
        end
    end
    return changed
end

-- Exposed for the deterministic contract suite; actual offscreen recovery is
-- still driven by the server update cadence and the loaded native cell.
NLNpcAuthority.bodyPresent = bodyPresent
NLNpcAuthority.reconcileBodies = reconcileBodies

function NLNpcAuthority.start()
    if NLNpcAuthority.started or isClient() then return end
    NLNpcAuthority.startAttempts = NLNpcAuthority.startAttempts + 1
    if NLNpcAuthority.startAttempts > 1 and NLNpcAuthority.startAttempts % 60 ~= 1 then return end
    local player = anchorPlayer()
    if not player then return end
    local world = NLAuthority.world()
    local rows = NLNeighbors.ensure(world)
    local reserved = {}
    for _, id in ipairs(NLNpcAuthority.definitions) do
        local row = rows[id]
        if row and row.alive ~= false and not NLNpcAuthority.bodies[id] then
            -- The first isolated world gets a nearby home for every authored
            -- neighbor so the vertical slice is immediately observable.
            -- Subsequent starts restore each saved position independently.
            if row.revision == 0 and not row.spawned then
                local square = freeSquareNear(getCell(), math.floor(player:getX()), math.floor(player:getY()),
                    math.floor(player:getZ()), 2, 4, reserved)
                if square then
                    row.home = { x = square:getX(), y = square:getY(), z = square:getZ() }
                    row.position = { x = square:getX(), y = square:getY(), z = square:getZ() }
                    row.waypoint = 1
                    row.spawned = true
                    reserved[square:getX() .. ":" .. square:getY() .. ":" .. square:getZ()] = true
                end
            end
            if row.revision > 0 then
                emit(string.format("RESTORE id=%s x=%.2f y=%.2f revision=%d", id,
                    row.position.x, row.position.y, row.revision))
            end
            local body, err = spawnBody(id, row, player)
            if not body then emit("SPAWN FAILED id=" .. id .. ": " .. tostring(err)) end
        end
    end
    local complete = true
    for _, id in ipairs(NLNpcAuthority.definitions) do
        local row = rows[id]
        if row and row.alive ~= false and not NLNpcAuthority.bodies[id] then complete = false end
    end
    if complete then
        NLNpcAuthority.started = true
        NLNpcAuthority.startAttempts = 0
        local sent = NLNpcAuthority.reannounce()
        if sent > 0 then emit("REANNOUNCE sent=" .. tostring(sent)) end
    end
end

local function recoverMissingBodies()
    local world = NLAuthority.world()
    local rows = NLNeighbors.ensure(world)
    local recovered = 0
    for _, id in ipairs(NLNpcAuthority.definitions) do
        local row = rows[id]
        local schedule = NLNpcAuthority.offscreen[id]
        if row and row.alive ~= false and row.spawned and not NLNpcAuthority.bodies[id]
                and (not schedule or NLNpcAuthority.tick >= schedule.nextAttempt) then
            local body, err = spawnBody(id, row, nil)
            if body then
                recovered = recovered + 1
                NLNpcAuthority.offscreen[id] = nil
                emit(string.format("RECOVER id=%s x=%.2f y=%.2f", id, body:getX(), body:getY()))
            else
                NLNpcAuthority.offscreen[id] = {
                    nextAttempt = NLNpcAuthority.tick + 30,
                }
                emit("RECOVER WAIT id=" .. id .. ": " .. tostring(err))
            end
        end
    end
    return recovered
end

NLNpcAuthority.recoverMissingBodies = recoverMissingBodies

local function nextWaypoint(row, body)
    if row.spawned and row.home then
        local target, index = routineTarget(row, row.routine or "home")
        if target and body and body.getX and body.getY
                and math.abs(body:getX() - (target.x + 0.5)) < 0.06
                and math.abs(body:getY() - (target.y + 0.5)) < 0.06 then
            return nil, index
        end
        return target, index
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
    NLNpcAuthority.motionSequence = NLNpcAuthority.motionSequence + 1
    local lifecycleChanged = NLNpcAuthority.reconcileBodies()
    if NLNpcAuthority.recoverMissingBodies() > 0 then lifecycleChanged = true end
    if NLNpcAuthority.tick % 300 == 0 then
        for id, body in pairs(NLNpcAuthority.bodies) do
            emit(string.format("TICK id=%s x=%.2f y=%.2f", id, body:getX(), body:getY()))
        end
    end
    for id, body in pairs(NLNpcAuthority.bodies) do
        local world = NLAuthority.world()
        local row = NLNeighbors.get(world, id)
        if not row or row.alive == false or body:isDead() then
            retireBody(id, row, body, "DEATH")
            lifecycleChanged = true
        else
            refreshRoutine(world, id, row, body)
            local threat, threatDistance = dangerNear(body, 4.0)
            if threat then
                local previous = NLNpcAuthority.danger[id]
                cancelBodyPath(id, body)
                local nextX, nextY, square = dangerStep(body, threat)
                if nextX then
                    body:setX(nextX); body:setY(nextY)
                    if square and square ~= true then body:setCurrent(square) end
                    syncNativePosition(body, nextX, nextY, body:getZ())
                    NLNeighbors.position(world, id, nextX, nextY, body:getZ(), row.waypoint)
                end
                NLNpcAuthority.danger[id] = { zombie=threat, distance=threatDistance }
                if not previous or previous.zombie ~= threat then
                    emit(string.format("DANGER id=%s distance=%.2f moved=%s", id,
                        threatDistance or -1, tostring(nextX ~= nil)))
                end
            else
                NLNpcAuthority.danger[id] = nil
                local behavior = body:getPathFindBehavior2()
            if not body:hasPath() and not NLNpcAuthority.targets[id] then
                NLNpcAuthority.targets = NLNpcAuthority.targets or {}
                local target, index = nextWaypoint(row, body)
                if target then
                    NLNpcAuthority.targets[id] = { x=target.x, y=target.y, z=target.z, waypoint=index,
                        routine=row.routine or "home",
                        lastX=body:getX(), lastY=body:getY(), stall=0 }
                    behavior:pathToLocation(target.x, target.y, target.z)
                    emit(string.format("PATH id=%s from=%.2f,%.2f to=%.2f,%.2f waypoint=%d",
                        id, body:getX(), body:getY(), target.x, target.y, index))
                end
            end
            local target = NLNpcAuthority.targets and NLNpcAuthority.targets[id]
            if target then
                local currentX, currentY = body:getX(), body:getY()
                if target.lastX and math.abs(currentX-target.lastX)<0.001
                        and math.abs(currentY-target.lastY)<0.001 then
                    target.stall = target.stall + 1
                else
                    target.stall = 0
                end
                target.lastX, target.lastY = currentX, currentY
                -- Dedicated B42 has no local animation frame for an unowned
                -- IsoPlayer, so PathFindBehavior2 can remain stationary there.
                -- Keep the server-native body authoritative with a small tile
                -- step after the native behavior has demonstrably stalled.
                local rerouted = false
                if isServer() and target.stall >= 30 then
                    local nextX, nextY, square = fallbackStep(body, target)
                    if nextX then
                        body:setX(nextX); body:setY(nextY)
                        if square and square ~= true then body:setCurrent(square) end
                        syncNativePosition(body, nextX, nextY, body:getZ())
                        -- The typed position bridge has already committed the
                        -- authoritative step. Do not immediately run the
                        -- unowned body's update frame, which can restore its
                        -- previous network sample before the next heartbeat.
                        rerouted = true
                    else
                        -- A blocked fallback route must not keep hammering the
                        -- same target forever.  Cancel the native behavior,
                        -- advance the persisted route and let the next update
                        -- choose the next authored waypoint.
                        behavior:cancel(); body:setPath2(nil)
                        local next = target.routine == "work" and 2 or 1
                        local route = NLNeighbors.definitions[id].waypoints
                        if not row.spawned and route and next > #route then next = 1 end
                        NLNeighbors.position(world, id, currentX, currentY, body:getZ(), next)
                        NLNpcAuthority.targets[id] = nil
                        emit(string.format("BLOCKED id=%s x=%.2f,%.2f skippedWaypoint=%d",
                            id, currentX, currentY, target.waypoint or 0))
                        rerouted = true
                    end
                end
                local ok, result = true, nil
                if not rerouted then
                    local positionBridged = syncNativePosition(body, currentX, currentY, body:getZ())
                    ok, result = pcall(function()
                        if not positionBridged then body:preupdate(); body:update() end
                        local r = behavior:update()
                        if not positionBridged then body:postupdate() end
                        return r
                    end)
                end
                if not ok then
                    behavior:cancel(); body:setPath2(nil); NLNpcAuthority.targets[id] = nil
                elseif not rerouted and (result == BehaviorResult.Succeeded
                        or (isServer() and target.stall >= 30
                            and math.abs(body:getX()-(target.x+0.5))<0.06
                            and math.abs(body:getY()-(target.y+0.5))<0.06)) then
                    behavior:cancel(); body:setPath2(nil)
                    local next = target.routine == "work" and 2 or 1
                    local route = NLNeighbors.definitions[id].waypoints
                    if not row.spawned and route and next > #route then next = 1 end
                    NLNeighbors.position(world, id, body:getX(), body:getY(), body:getZ(), next)
                    NLNpcAuthority.targets[id] = nil
                    emit(string.format("MOVE id=%s x=%.2f y=%.2f waypoint=%d",
                        id, body:getX(), body:getY(), next))
                end
            end
            if NLNpcAuthority.tick % 120 == 0 then
                NLNpcAuthority.persist()
            end
            end
        end
    end
    if lifecycleChanged or NLNpcAuthority.tick % NLNpcAuthority.presenceInterval == 0 then
        NLNpcAuthority.broadcastPresence()
    end
end

function NLNpcAuthority.reset()
    if NLPlumbob and NLPlumbob.unregister then
        for id, _ in pairs(NLNpcAuthority.bodies) do
            pcall(NLPlumbob.unregister, "npc:" .. id)
        end
    end
    NLNpcAuthority.bodies = {}
    NLNpcAuthority.targets = {}
    NLNpcAuthority.offscreen = {}
    NLNpcAuthority.danger = {}
    NLNpcAuthority.started = false
    NLNpcAuthority.startAttempts = 0
    NLNpcAuthority.tick = 0
    NLNpcAuthority.motionSequence = 0
end

Events.OnGameStart.Add(NLNpcAuthority.start)
if Events.OnSave then
    Events.OnSave.Add(NLNpcAuthority.persist)
end
-- Dedicated servers own their simulation cadence.  In single-player the
-- client-side HUD bridge owns the cadence because Build 42 keeps server and
-- client event queues separate even though the world body is shared.
if isServer() then
    Events.OnTick.Add(NLNpcAuthority.update)
end
Events.OnMainMenuEnter.Add(NLNpcAuthority.reset)
return NLNpcAuthority
