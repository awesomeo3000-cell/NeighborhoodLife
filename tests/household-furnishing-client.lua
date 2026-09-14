package.path = arg[1] .. '/42/media/lua/client/?.lua;' .. package.path
function isClient() return true end
local objectList = {}
local square = {x=10, y=20, z=0}
function square:getObjects() return {size=function() return #objectList end, get=function(_, i) return objectList[i+1] end} end
function square:AddTileObject(object) object.square=self; objectList[#objectList+1]=object end
function square:RemoveTileObject(object)
    for i, value in ipairs(objectList) do if value == object then table.remove(objectList, i); return end end
end
local cell = {getGridSquare=function() return square end}
function getCell() return cell end
function getSprite(name) return name end
IsoObject = {new=function(_, squareObject, sprite)
    local object = {sprite=sprite, data={}}
    function object:getModData() return self.data end
    function object:getSquare() return self.square end
    function object:setName(name) self.name=name end
    function object:resetModelNextFrame() end
    return object
end}
local tick
Events = {OnMainMenuEnter={Add=function() end}, OnDisconnect={Add=function() end},
    OnTick={Add=function(fn) tick=fn end}}
dofile(arg[1] .. '/42/media/lua/client/NL/HouseholdFurnishingClient.lua')
local household = {id='home:host', furnishing={kind='storage',x=10,y=20,z=0,sprite='furniture_storage_02_19'}}
local first = NLHouseholdFurnishingClient.apply(household)
assert(first and #objectList == 1, 'client furnishing replica created')
assert(first:getModData().NeighborhoodHouseholdId == household.id, 'client furnishing identity preserved')
assert(NLHouseholdFurnishingClient.apply(household) == first and #objectList == 1, 'client furnishing reused')
NLHouseholdFurnishingClient.clear()
assert(#objectList == 0, 'client furnishing cleanup removes object')
local loaded = true
function cell:getGridSquare()
    if loaded then return square end
    return nil
end
loaded = false
assert(NLHouseholdFurnishingClient.apply(household) == nil, 'unloaded furnishing is deferred')
assert(NLHouseholdFurnishingClient.pending[household.id] == household, 'deferred furnishing is retained')
loaded = true
tick()
assert(NLHouseholdFurnishingClient.objects[household.id], 'deferred furnishing retries after streaming')
assert(not NLHouseholdFurnishingClient.pending[household.id], 'deferred furnishing clears after retry')
print('PASS: client household furnishing replica, identity, reuse and cleanup')
