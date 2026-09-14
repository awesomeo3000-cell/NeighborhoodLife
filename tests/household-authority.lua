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
    local p = {name=name, x=x, y=y, z=0, dead=false, skill=0}
    function p:getUsername() return self.name end
    function p:getPlayerNum() return 0 end
    function p:isDead() return self.dead end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return self.z end
    function p:getPerkLevel() return self.skill end
    function p:getOnlineID() return 0 end
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
command(players[1], 'task', {task='tidy'})
assert(world.households[hostProfile.householdId].tasks.tidy == 1, 'daily replay rejected')
assert(#packets > 0 and packets[#packets].module == 'NeighborhoodHousehold', 'private household packets sent')
print('PASS: household authority create/invite/accept, shared home activity, reward, replay guard and private packets')
