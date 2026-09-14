require "NL/Domain"

-- Persistent neighborhood identity is separate from the transient engine body.
-- A missing body is therefore an unavailable neighbor, never a fake character.
NLNeighbors = {
    definitions = {
        marisol = { forename="Marisol", surname="Vega", name="Marisol Vega", female=true,
            outfit="Generic01", home={x=10780,y=10268,z=0},
            waypoints={{x=10780,y=10268,z=0},{x=10784,y=10268,z=0}}, schedule="tailor" },
        kenji = { forename="Kenji", surname="Arakawa", name="Kenji Arakawa", female=false,
            outfit="Generic01", home={x=10786,y=10270,z=0},
            waypoints={{x=10786,y=10270,z=0},{x=10790,y=10270,z=0}}, schedule="carpenter" },
        amara = { forename="Amara", surname="Okonkwo", name="Amara Okonkwo", female=true,
            outfit="Generic01", home={x=10782,y=10274,z=0},
            waypoints={{x=10782,y=10274,z=0},{x=10786,y=10274,z=0}}, schedule="medic" }
    }
}

local function copy(value)
    return NLDomain.copy(value)
end

function NLNeighbors.ensure(world)
    world.neighbors = world.neighbors or {}
    for id, def in pairs(NLNeighbors.definitions) do
        local row = world.neighbors[id]
        if not row then
            row = { id=id, home=copy(def.home), position=copy(def.home), waypoint=1,
                alive=true, inventory={}, revision=0 }
            world.neighbors[id] = row
        else
            row.id = id
            row.home = row.home or copy(def.home)
            row.position = row.position or copy(row.home)
            row.waypoint = row.waypoint or 1
            if row.alive == nil then row.alive = not row.dead end
            row.inventory = row.inventory or {}
            row.revision = row.revision or 0
        end
    end
    return world.neighbors
end

function NLNeighbors.get(world, id)
    NLNeighbors.ensure(world)
    return world.neighbors[id]
end

function NLNeighbors.register(world, id, home)
    if not NLNeighbors.definitions[id] then return false end
    local row = NLNeighbors.get(world, id)
    if home and not row.home then row.home = copy(home) end
    return true
end

function NLNeighbors.position(world, id, x, y, z, waypoint)
    local row = NLNeighbors.get(world, id)
    if not row or row.alive == false then return false end
    row.position = {x=x, y=y, z=z}
    if waypoint then row.waypoint = waypoint end
    row.revision = row.revision + 1
    return true
end

function NLNeighbors.dead(world, id)
    local row = NLNeighbors.get(world, id)
    if not row then return false end
    row.alive = false
    row.dead = true
    row.revision = row.revision + 1
    return true
end

return NLNeighbors
