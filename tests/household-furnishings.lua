package.path = arg[1] .. '/42/media/lua/server/?.lua;' .. arg[1] .. '/42/media/lua/shared/?.lua;' .. package.path
function isClient() return false end
function isServer() return true end
Events = {OnGameStart={Add=function(fn) end}}
local objectList = {}
local square = {x=10, y=20, z=0}
function square:getX() return self.x end
function square:getY() return self.y end
function square:getZ() return self.z end
function square:getObjects() return {size=function() return #objectList end, get=function(_, i) return objectList[i+1] end} end
function square:getSpecialObjects() return {size=function() return 0 end, get=function() return nil end} end
function square:AddTileObject(object) object.square=self; objectList[#objectList+1]=object end
function square:RemoveTileObject(object)
    for i, value in ipairs(objectList) do if value == object then table.remove(objectList, i); return end end
end
function square:transmitRemoveItemFromSquare() end
local transmitted = 0
function square:transmitAddObjectToSquare(object, _)
    transmitted = transmitted + 1
    square:AddTileObject(object)
end
local cell = {getGridSquare=function(_, x, y, z) if x==10 and y==20 and z==0 then return square end end}
function getCell() return cell end
IsoObject = {new=function(squareObject, sprite, name)
    local object = {sprite=sprite, name=name, data={}}
    function object:getModData() return self.data end
    function object:getSquare() return self.square end
    function object:setSpecialTooltip() end
    function object:transmitCompleteItemToClients() end
    return object
end, getNew=function(squareObject, sprite, name, _) return IsoObject.new(squareObject, sprite, name) end}
require 'NL/Households'
require 'NL/HouseholdFurnishings'
local home = NLHouseholds.new('home:host', 'host', {x=10,y=20,z=0})
local first = NLHouseholdFurnishings.ensure(home)
assert(first and #objectList == 1, 'native storage furnishing created once')
assert(first:getModData().NeighborhoodHouseholdId == 'home:host', 'furnishing carries household identity')
assert(transmitted == 1, 'native furnishing transmitted through square object packet')
local second = NLHouseholdFurnishings.ensure(home)
assert(second == first and #objectList == 1, 'existing furnishing is reused')
local summary = NLHouseholds.copySummary(home, {host=true})
assert(summary.furnishing and summary.furnishing.kind == 'storage', 'furnishing persists in household snapshot')
NLHouseholdFurnishings.remove(home)
assert(#objectList == 0 and home.furnishing == nil, 'furnishing removal clears native object and record')
print('PASS: household furnishing creation, identity, reuse, snapshot persistence and removal')
