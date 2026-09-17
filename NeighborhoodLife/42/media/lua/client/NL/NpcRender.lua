-- World-character presentation bridge for locally created IsoPlayer bodies.
--
-- Build 42 renders world characters through FBO render chunks. That path
-- deliberately skips any moving object whose exact class is IsoPlayer and
-- draws engine-owned players from IsoPlayer.players / GameClient.IDToPlayerMap
-- only. Authored neighbors and presentation replicas belong to neither
-- roster, so their ModelManager model is active but never receives a draw
-- call. Queue the same IsoPlayer.render call the engine uses for its own
-- players from a world-render Lua event; this is presentation-only and never
-- mutates authoritative state.
NLNpcRender = {
    bodies = {},
    order = {},
}

local function bodyLog(message)
    print("[NeighborhoodLife] NPC/RENDER " .. tostring(message))
end

local function bodyDead(body)
    if not body or not body.isDead then return true end
    local ok, dead = pcall(body.isDead, body)
    return not ok or dead == true
end

function NLNpcRender.lightFor(body, observerIndex)
    local square = body and body.getCurrentSquare and body:getCurrentSquare() or nil
    if not square or not square.getLightInfo then return nil end
    local ok, light = pcall(square.getLightInfo, square, observerIndex or 0)
    return ok and light or nil
end

function NLNpcRender.render(body, observerIndex)
    if not body or not body.render or bodyDead(body) then return false end
    local light = NLNpcRender.lightFor(body, observerIndex)
    if not light then return false end
    local x, y, z = body:getX(), body:getY(), body:getZ()
    local ok = pcall(body.render, body, x, y, z, light, true, false, nil)
    if ok and body.renderShadow then
        pcall(body.renderShadow, body, x, y, z)
    end
    return ok
end

function NLNpcRender.register(id, body)
    if not id or not body then return false end
    if not NLNpcRender.bodies[id] then
        NLNpcRender.order[#NLNpcRender.order + 1] = id
    end
    NLNpcRender.bodies[id] = body
    return true
end

function NLNpcRender.unregister(id)
    if not id then return false end
    NLNpcRender.bodies[id] = nil
    for index = #NLNpcRender.order, 1, -1 do
        if NLNpcRender.order[index] == id then
            table.remove(NLNpcRender.order, index)
        end
    end
    return true
end

function NLNpcRender.renderAll()
    for _, id in ipairs(NLNpcRender.order) do
        local body = NLNpcRender.bodies[id]
        if body then NLNpcRender.render(body, 0) end
    end
end

function NLNpcRender.clear()
    NLNpcRender.bodies = {}
    NLNpcRender.order = {}
end

bodyLog("bridge loaded")

if Events and Events.OnPostRender then
    Events.OnPostRender.Add(NLNpcRender.renderAll)
end
if Events and Events.OnMainMenuEnter then
    Events.OnMainMenuEnter.Add(NLNpcRender.clear)
end

return NLNpcRender
