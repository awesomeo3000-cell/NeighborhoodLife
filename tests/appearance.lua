-- Appearance contract: server validation/persistence plus native-shaped client
-- HumanVisual application. This is mock/unit evidence, not gameplay evidence.
package.path = arg[1] .. '/42/media/lua/shared/?.lua;' .. arg[1] .. '/42/media/lua/server/?.lua;' .. arg[1] .. '/42/media/lua/client/?.lua;' .. package.path
local function hook() return { Add = function(f) return f end } end
Events = { OnClientCommand = hook(), OnMainMenuEnter = hook() }
function isClient() return false end
function isServer() return true end
local store = {}
ModData = { getOrCreate = function(k) store[k] = store[k] or {}; return store[k] end }
Perks = { Tailoring = 'Tailoring', Woodwork = 'Woodwork', Doctor = 'Doctor' }
local now = 1000
function getTimestampMs() now = now + 250; return now end
function getGameTime() return { getWorldAgeHours = function() return 1 end } end
function getOnlinePlayers() return { size = function() return 0 end } end
local sent
function sendServerCommand(player, module, command, args) sent = { module=module, command=command, args=args } end
local player = {}
function player:getUsername() return 'appearance-player' end
function player:getPlayerNum() return 0 end
function player:isDead() return false end
function player:getPerkLevel() return 0 end
local visual = { female = true }
function visual:isFemale() return self.female end
function visual:setHairModel(name) self.hair = name end
function player:getHumanVisual() return visual end
function player:resetModelNextFrame() self.reset = true end
function player:syncVisuals() self.synced = true end
function player:getModData() self.data = self.data or {}; return self.data end
require 'NL/Authority'
if not NLDefinitions.appearancePresets then
    print('PASS: baseline appearance adapter absent (legacy branch)')
    return
end
require 'NL/Appearance'
local profile = NLDomain.profile(NLAuthority.world(), NLAuthority.key(player))
assert(profile.appearance.preset == 'natural', 'new profiles start with natural appearance')
local ok, message = NLAuthority.selectAppearance(profile, 'bob')
assert(ok and message == 'Bob cut appearance selected', 'server accepts a known preset')
assert(profile.appearance.preset == 'bob' and profile.revision == 1, 'preset persists and revisions profile')
local bad = NLAuthority.selectAppearance(profile, 'client-invented-model')
assert(not bad, 'server rejects arbitrary appearance ids')
NLAuthority.command('NeighborhoodLife', 'appearance_select', player, { preset = 'braided' })
assert(sent and sent.command == 'snapshot' and sent.args.appearance.preset == 'braided',
    'authoritative snapshot carries selected appearance')
assert(NLAppearance.applyProfile(player, { preset = 'bob' }) and visual.hair == 'Bob',
    'female native HumanVisual receives the selected hair style')
assert(player.reset and player.synced and player.data.NeighborhoodAppearance == 'bob',
    'appearance refreshes model and records local applied preset')
visual.female = false
assert(NLAppearance.applyProfile(player, { preset = 'short' }) and visual.hair == 'CrewCut',
    'male native HumanVisual receives the gendered hair style')
print('PASS: authoritative appearance presets, revisioned snapshot, native HumanVisual application and validation')
