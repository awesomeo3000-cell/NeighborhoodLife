package.path = arg[1] .. '/42/media/lua/server/?.lua;' .. arg[1] .. '/42/media/lua/shared/?.lua;' .. package.path
function isClient() return false end
function isServer() return true end
Perks = {Tailoring='Tailoring', Woodwork='Woodwork', Doctor='Doctor'}
local tick, day = 1000, 0
function getTimestampMs() tick = tick + 250; return tick end
function getGameTime() return {getWorldAgeHours=function() return day * 24 end} end
local saved = {}
ModData = {getOrCreate=function(key) saved[key] = saved[key] or {}; return saved[key] end}
local handlers = {}
Events = {OnClientCommand={Add=function(fn) handlers[#handlers+1]=fn end},
    OnMainMenuEnter={Add=function() end}}
local players = {}
local packets = {}
local function list(items)
    return {size=function() return #items end, get=function(_, index) return items[index+1] end}
end
local function player(name, x, y)
    local items = {}
    local function item(fullType) return {getFullType=function() return fullType end} end
    items[1], items[2] = item('Base.RippedSheets'), item('Base.RippedSheets')
    local inventory = {}
    function inventory:getItems() return list(items) end
    function inventory:Remove(target)
        for i, value in ipairs(items) do
            if value == target then table.remove(items, i); return end
        end
    end
    function inventory:AddItem(fullType)
        local value = item(fullType); items[#items + 1] = value; return value
    end
    local p = {name=name, x=x, y=y, z=0, dead=false, skill=0, items=items}
    function p:getUsername() return self.name end
    function p:getPlayerNum() return 0 end
    function p:isDead() return self.dead end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return self.z end
    function p:getPerkLevel() return self.skill end
    function p:getOnlineID() return 0 end
    function p:isEquipped() return false end
    function p:getInventory() return inventory end
    return p
end
players[1], players[2] = player('host', 10.5, 20.5), player('guest', 40.5, 50.5)
function getOnlinePlayers() return list(players) end
function sendServerCommand(playerObject, module, command, args)
    packets[#packets+1] = {player=playerObject, module=module, command=command, args=args}
end
local function command(p, name, args)
    NLHouseholdAuthority.command('NeighborhoodHousehold', name, p, args or {})
end
require 'NL/HouseholdAuthority'
command(players[1], 'create')
local world = NLAuthority.world()
local hostProfile = NLDomain.profile(world, 'host')
assert(hostProfile.householdId and world.households[hostProfile.householdId], 'home created')
command(players[1], 'invite', {target='guest'})
local guestProfile = NLDomain.profile(world, 'guest')
assert(guestProfile.householdInvite and guestProfile.householdInvite.from == 'host', 'server invitation persisted')
command(players[2], 'accept')
assert(guestProfile.householdId == hostProfile.householdId, 'guest joined shared home')
command(players[1], 'task', {task='tidy'})
assert(world.households[hostProfile.householdId].tasks.tidy == 1, 'home activity completed at home')
assert(hostProfile.credits == 5, 'shared activity reward credited')
local home = world.households[hostProfile.householdId]
if NLHouseholds.storageCount then
    command(players[1], 'store', {item='Base.RippedSheets', amount=1})
    assert(NLHouseholds.storageCount(home, 'Base.RippedSheets') == 1, 'host stored an unequipped main-inventory item')
    assert(#players[1].items == 1, 'stored item left host inventory')
    players[2].x, players[2].y = 10.5, 20.5
    command(players[2], 'retrieve', {item='Base.RippedSheets', amount=1})
    assert(NLHouseholds.storageCount(home, 'Base.RippedSheets') == 0, 'guest consumed shared storage quantity')
    assert(#players[2].items == 3, 'guest retrieved shared item into main inventory')
end
if NLHouseholdFurnishings and NLHouseholdFurnishings.isNearby then
    NLHouseholdFurnishings.isNearby = function() return true end
    command(players[1], 'furnishing', {action='store', item='Base.RippedSheets', amount=1})
    assert(NLHouseholds.storageCount(home, 'Base.RippedSheets') == 1,
        'furnishing command stores through the native fixture')
end
local recoveryItem = players[1]:getInventory():AddItem('Base.RippedSheets')
assert(recoveryItem and #players[1].items == 1, 'recovery fixture added to host inventory')
NLQAHouseholdFaultMode = 'player-applied'
command(players[1], 'furnishing', {action='store', item='Base.RippedSheets', amount=1})
assert(world.householdJournal and world.householdJournal.state == 'player-applied',
    'household journal remains after an interrupted player-side mutation')
assert(#players[1].items == 0 and NLHouseholds.storageCount(home, 'Base.RippedSheets') == 1,
    'fault leaves only the player-side half applied')
NLQAHouseholdFaultMode = nil
command(players[1], 'refresh')
assert(not world.householdJournal and #players[1].items == 1
    and NLHouseholds.storageCount(home, 'Base.RippedSheets') == 1,
    'refresh repairs the interrupted household storage transaction')
NLQAHouseholdFaultMode = 'player-applied'
command(players[1], 'furnishing', {action='retrieve', item='Base.RippedSheets', amount=1})
assert(world.householdJournal and world.householdJournal.mode == 'retrieve',
    'retrieve interruption leaves a recoverable household journal')
assert(#players[1].items == 2 and NLHouseholds.storageCount(home, 'Base.RippedSheets') == 1,
    'retrieve fault leaves only the player-side half applied')
NLQAHouseholdFaultMode = nil
command(players[1], 'refresh')
assert(not world.householdJournal and #players[1].items == 1
    and NLHouseholds.storageCount(home, 'Base.RippedSheets') == 1,
    'refresh removes the duplicate from an interrupted retrieve')
command(players[1], 'task', {task='tidy'})
assert(world.households[hostProfile.householdId].tasks.tidy == 1, 'daily replay rejected')
if NLHouseholds.transferOwner then
    command(players[1], 'transfer', {target='guest'})
    assert(home.owner == 'guest' and home.members.host.role == 'member'
        and home.members.guest.role == 'owner', 'owner can transfer household ownership')
    command(players[1], 'transfer', {target='host'})
    assert(home.owner == 'guest', 'former owner cannot reclaim ownership')
end
assert(#packets > 0 and packets[#packets].module == 'NeighborhoodHousehold', 'private household packets sent')
print('PASS: household authority create/invite/accept, shared storage deposit/withdrawal when available, activity, reward, replay guard and private packets')
