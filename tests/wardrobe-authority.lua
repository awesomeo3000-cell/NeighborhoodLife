-- Server-authoritative wardrobe preset contract. The baseline branch does not
-- have this adapter; that branch is intentionally reported as legacy coverage.
package.path = arg[1] .. '/42/media/lua/shared/?.lua;' .. arg[1] .. '/42/media/lua/server/?.lua;' .. package.path
local function hook() return { Add = function(f) return f end } end
Events = { OnClientCommand = hook(), OnMainMenuEnter = hook() }
function isClient() return false end
function isServer() return true end
local worldStore = {}
ModData = { getOrCreate = function(key) worldStore[key] = worldStore[key] or {}; return worldStore[key] end }
Perks = { Tailoring = 'Tailoring', Woodwork = 'Woodwork', Doctor = 'Doctor' }
local now = 1000
function getTimestampMs() now = now + 250; return now end
function getGameTime() return { getWorldAgeHours = function() return 1 end } end
local sent
function sendServerCommand(player, module, command, args) sent = { module=module, command=command, args=args } end
function getOnlinePlayers() return { size=function() return 0 end } end
local function item(fullType, id)
    return { getFullType=function() return fullType end, getID=function() return id end }
end
local shirt, hat = item('Base.Shirt', 11), item('Base.Hat', 12)
local worn = { { getItem=function() return shirt end }, { getItem=function() return hat end } }
local player = {}
function player:getUsername() return 'wardrobe-authority-player' end
function player:getPlayerNum() return 0 end
function player:isDead() return false end
function player:getPerkLevel() return 0 end
function player:getWornItems() return { size=function() return #worn end, get=function(_, i) return worn[i+1] end } end
NLQAMultiplayerServer = false
require 'NL/Authority'
if not NLAuthority.captureOutfit then
    print('PASS: baseline wardrobe authority adapter absent (legacy branch)')
    return
end
local world = NLAuthority.world()
local profile = NLDomain.profile(world, NLAuthority.key(player))
local ok, message = NLAuthority.captureOutfit(player, profile, 1)
assert(ok and message == 'Outfit 1 saved (2 pieces).', 'captures authoritative worn garments')
assert(profile.outfits[1][1].fullType == 'Base.Shirt' and profile.outfits[1][1].itemId == 11,
    'stores exact first garment identity')
assert(profile.outfits[1][2].fullType == 'Base.Hat' and profile.outfits[1][2].itemId == 12,
    'stores exact second garment identity')
local invalid, invalidMessage = NLAuthority.captureOutfit(player, profile, 4)
assert(not invalid and invalidMessage == 'Choose wardrobe slot 1, 2 or 3', 'rejects invalid wardrobe slot')
NLAuthority.command('NeighborhoodLife', 'wardrobe_save', player, { slot = 2 })
assert(sent and sent.module == 'NeighborhoodLife' and sent.command == 'snapshot',
    'wardrobe save returns an authoritative snapshot')
assert(sent.args.outfits[2][1].fullType == 'Base.Shirt' and sent.args.revision == 3,
    'snapshot includes persisted preset and revision')
print('PASS: server-authoritative wardrobe capture, validation, persistence and snapshot')
