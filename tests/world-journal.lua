package.path = arg[1] .. '/42/media/lua/server/?.lua;' .. arg[1] .. '/42/media/lua/shared/?.lua;' .. package.path
function isClient() return false end
function isServer() return true end
Perks = {Tailoring = 'Tailoring', Woodwork = 'Woodwork', Doctor = 'Doctor'}
function getTimestampMs() return 1000 end
local saved = {}
ModData = {getOrCreate = function(key) saved[key] = saved[key] or {}; return saved[key] end}
Events = {OnClientCommand = {Add = function() end}, OnMainMenuEnter = {Add = function() end}}

local NLAuthority = require 'NL/Authority'
local world = NLAuthority.world()
world.players.seed = {credits = 7, nested = {value = 'before'}}
world.households = {['home:seed'] = {revision = 3, members = {seed = {role = 'owner'}}}}
local before = NLDomain.copy(world)
local player = {getUsername = function() return 'seed' end, getPlayerNum = function() return 0 end}
local journal = NLAuthority.beginWorldJournal(world, player, 'task')
assert(journal and journal.state == 'prepared' and world.mutationJournal == journal,
    'global mutation journal is prepared before a world command')
world.players.seed.credits = 99
world.players.seed.nested.value = 'partial'
world.players.extra = {credits = 100}
world.households['home:seed'].members.seed.role = 'member'
world.households['home:new'] = {revision = 1}
local recovered, state = NLAuthority.recoverWorldJournal(world, player)
assert(recovered and state == 'repaired' and not world.mutationJournal,
    'global mutation journal clears after restoring the pre-command world')
assert(world.players.seed.credits == before.players.seed.credits
    and world.players.seed.nested.value == before.players.seed.nested.value
    and not world.players.extra
    and world.households['home:seed'].members.seed.role == 'owner'
    and not world.households['home:new'],
    'global recovery restores nested profiles and household rows atomically')

local foreign = {getUsername = function() return 'foreign' end, getPlayerNum = function() return 1 end}
journal = NLAuthority.beginWorldJournal(world, player, 'interact')
world.players.seed.credits = 11
local blocked, blockedState = NLAuthority.recoverWorldJournal(world, foreign)
assert(not blocked and blockedState == 'Global data recovery belongs to another account'
    and world.mutationJournal == journal and world.players.seed.credits == 11,
    'foreign recovery cannot consume the active global journal')
assert(NLAuthority.commitWorldJournal(world, journal) and not world.mutationJournal,
    'successful world command commits and clears its journal')
NLQAGlobalJournalFaultMode = 'before-clear'
NLQAGlobalJournalFaultCommand = 'task'
journal = NLAuthority.beginWorldJournal(world, player, 'task')
world.players.seed.credits = 42
assert(not NLAuthority.commitWorldJournal(world, journal)
    and world.mutationJournal == journal and journal.state == 'before-clear',
    'QA crash hook leaves the prepared journal after the world mutation')
NLQAGlobalJournalFaultConsumed = true
local held, heldState = NLAuthority.recoverWorldJournal(world, player)
assert(not held and heldState == 'Global data recovery held for crash probe'
    and world.mutationJournal == journal,
    'QA crash hook holds recovery until the real server checkpoint is complete')
NLQAGlobalJournalFaultMode = nil
NLQAGlobalJournalFaultCommand = nil
NLQAGlobalJournalFaultConsumed = nil
assert(NLAuthority.recoverWorldJournal(world, player)
    and world.players.seed.credits == 11 and not world.mutationJournal,
    'the interrupted QA mutation remains recoverable')
print('PASS: global world mutation journal restores nested ModData, protects account ownership and commits cleanly')
