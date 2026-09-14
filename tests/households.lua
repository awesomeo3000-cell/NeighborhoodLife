package.path = arg[1] .. '/42/media/lua/shared/?.lua;' .. package.path
require 'NL/Domain'
require 'NL/Households'

local world = NLDomain.newWorld()
local home = NLHouseholds.new('home:host', 'host', {x=10,y=20,z=0})
NLHouseholds.ensure(world)[home.id] = home
local host = NLDomain.profile(world, 'host')
local guest = NLDomain.profile(world, 'guest')
host.householdId = home.id
assert(NLHouseholds.memberCount(home) == 1)
assert(NLHouseholds.addMember(home, 'guest'))
guest.householdId = home.id
assert(NLHouseholds.memberCount(home) == 2)
local ok, message = NLHouseholds.completeTask(home, 'host', 'tidy', 0)
assert(ok and string.find(message, 'Tidy shared home', 1, true))
assert(home.tasks.tidy == 1 and home.members.host.contribution == 1)
assert(not NLHouseholds.completeTask(home, 'host', 'tidy', 0), 'duplicate task is blocked')
assert(NLHouseholds.completeTask(home, 'guest', 'meal', 0))
local copy = NLDomain.copy(world)
assert(copy.households[home.id].members.guest.contribution == 1, 'household state persists')
assert(not NLHouseholds.completeTask(home, 'outsider', 'social', 0), 'outsider cannot act')
assert(not NLHouseholds.completeTask(home, 'host', 'bogus', 0), 'unknown activity rejected')
if NLHouseholds.transferOwner then
    assert(NLHouseholds.transferOwner(home, 'host', 'guest'))
    assert(home.owner == 'guest' and home.members.host.role == 'member'
        and home.members.guest.role == 'owner', 'household ownership transfers roles')
    assert(not NLHouseholds.transferOwner(home, 'host', 'guest'), 'former owner cannot transfer again')
end
local summary = NLHouseholds.copySummary(home, {host=true})
local hostRow
for _, row in ipairs(summary.members) do if row.username == 'host' then hostRow = row end end
assert(hostRow and hostRow.online, 'online state is derived')
print('PASS: household membership, shared activities, daily replay guard, persistence and isolation')
