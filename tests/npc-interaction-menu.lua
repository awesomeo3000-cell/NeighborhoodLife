-- World-context NPC interaction contract. This proves menu discovery, the
-- conversation-overlay entry point and command routing with shaped UI fixtures;
-- it is not real mouse or multiplayer gameplay evidence.
local root = arg[1]
package.path = root .. '/42/media/lua/client/?.lua;' .. package.path

local eventHook
Events = { OnFillWorldObjectContextMenu = { Add = function(f) eventHook = f end } }
package.preload['NL/SocialClient'] = function()
NLSocialClient = { requests = {}, snapshots = { [0] = { neighbors = {
    { id = 'marisol', relation = { activeDate = { status = 'active' } }, canPartner = true },
} } }, request = function(index, command, args)
        NLSocialClient.requests[#NLSocialClient.requests + 1] = {
            index = index, command = command, args = args,
        }
    end }
    return NLSocialClient
end
NLRelationships = { opens = {}, open = function(index)
    NLRelationships.opens[#NLRelationships.opens + 1] = index
end }
package.preload['NL/ConversationOverlay'] = function()
    NLConversationOverlay = { opens = {}, open = function(index, id, body)
        NLConversationOverlay.opens[#NLConversationOverlay.opens + 1] = {
            index = index, id = id, body = body,
        }
    end }
    return NLConversationOverlay
end
package.preload['NL/NpcClient'] = function() return NLNpcClient end

local player = { dead = false, playerNum = 0 }
function player:isDead() return self.dead end
function player:getPlayerNum() return self.playerNum end
local item = { getFullType = function() return 'Base.Hammer' end }
local items = { item }
function items:size() return #self end
function items:get(index) return self[index + 1] end
function player:getInventory() return { getItems = function() return items end } end
function player:isEquipped() return false end
function getSpecificPlayer() return player end

NLNpcClient = { bodies = {}, states = {
    marisol = { id = 'marisol', name = 'Marisol Vega', inventoryItems = {
        { item = 'Base.Bandage', amount = 2 },
    } },
} }

local function newMenu()
    local menu = { options = {} }
    function menu:addOption(label, target, callback, ...)
        local option = { label = label, target = target, callback = callback, args = {...} }
        self.options[#self.options + 1] = option
        return option
    end
    function menu:addSubMenu(option, submenu) option.submenu = submenu end
    return menu
end
ISContextMenu = { getNew = function() return newMenu() end }

require 'NL/NpcInteractionMenu'

local object = { data = { NeighborhoodNpcId = 'marisol' } }
function object:getModData() return self.data end
local context = newMenu()
eventHook(0, context, { object }, false)
assert(#context.options == 2, 'world context menu discovers the authored NPC talk and profile entries')
assert(context.options[1].label == 'Talk to Marisol Vega',
    'primary discovery option opens the world conversation bubbles')
assert(context.options[2].label == 'View relationship',
    'secondary option keeps the relationship details viewer reachable')
assert(context.options[1].submenu == nil, 'talk entry no longer opens a large interaction submenu')

context.options[1].callback(context.options[1].target, unpack(context.options[1].args))
assert(#NLConversationOverlay.opens == 1, 'talk entry opens one conversation overlay')
assert(NLConversationOverlay.opens[1].index == 0
    and NLConversationOverlay.opens[1].id == 'marisol'
    and NLConversationOverlay.opens[1].body == object,
    'conversation overlay opens for the current player and selected NPC body')

context.options[2].callback(context.options[2].target, unpack(context.options[2].args))
assert(#NLRelationships.opens == 1 and NLRelationships.opens[1] == 0,
    'relationship profile action opens for the current player')

-- Build 42 mouse context logic stores a clicked IsoPlayer under
-- ISWorldObjectContextMenu.fetchVars.clickedPlayer instead of the Lua
-- worldobjects list, so the entry point must read both sources.
ISWorldObjectContextMenu = { fetchVars = { clickedPlayer = object } }
local clickedContext = newMenu()
eventHook(0, clickedContext, {}, false)
assert(#clickedContext.options == 2, 'real clicked-player context discovers the authored NPC')
assert(clickedContext.options[1].label == 'Talk to Marisol Vega',
    'clicked-player discovery opens the conversation overlay')
clickedContext.options[1].callback(clickedContext.options[1].target,
    unpack(clickedContext.options[1].args))
assert(#NLConversationOverlay.opens == 2
    and NLConversationOverlay.opens[2].id == 'marisol'
    and NLConversationOverlay.opens[2].body == object,
    'clicked-player discovery passes the clicked NPC body to the overlay')

local stranger = { data = {} }
function stranger:getModData() return self.data end
ISWorldObjectContextMenu.fetchVars.clickedPlayer = stranger
local strangerContext = newMenu()
eventHook(0, strangerContext, {}, false)
assert(#strangerContext.options == 0,
    'non-authored clicked players receive no neighborhood entries')
ISWorldObjectContextMenu.fetchVars.clickedPlayer = nil

local function requestCount() return #NLSocialClient.requests end
NLNpcInteractionMenu.activate(player, 'marisol', 'introduce')
assert(NLSocialClient.requests[requestCount()].command == 'interact'
    and NLSocialClient.requests[requestCount()].args.id == 'marisol'
    and NLSocialClient.requests[requestCount()].args.action == 'introduce',
    'introduce action routes through the production social client')
NLNpcInteractionMenu.activate(player, 'marisol', 'date_activity')
assert(NLSocialClient.requests[requestCount()].args.action == 'date_activity',
    'active date activity routes through the production social client')
NLNpcInteractionMenu.activate(player, 'marisol', 'ask_work')
assert(NLSocialClient.requests[requestCount()].args.action == 'ask_work',
    'work conversation routes through the production social client')
NLNpcInteractionMenu.activate(player, 'marisol', 'talk_home')
assert(NLSocialClient.requests[requestCount()].args.action == 'talk_home',
    'home conversation routes through the production social client')
NLNpcInteractionMenu.activate(player, 'marisol', 'compliment')
assert(NLSocialClient.requests[requestCount()].args.action == 'compliment',
    'compliment routes through the production social client')
NLNpcInteractionMenu.activate(player, 'marisol', 'partner')
assert(NLSocialClient.requests[requestCount()].args.action == 'partner',
    'partnership commitment routes through the production social client')
NLNpcInteractionMenu.activate(player, 'marisol', 'give')
assert(NLSocialClient.requests[requestCount()].command == 'give'
    and NLSocialClient.requests[requestCount()].args.item == 'Base.Hammer',
    'give action selects an unequipped main-inventory item')
NLNpcInteractionMenu.activate(player, 'marisol', 'request')
assert(NLSocialClient.requests[requestCount()].command == 'request'
    and NLSocialClient.requests[requestCount()].args.item == 'Base.Bandage',
    'request action selects an authoritative NPC inventory item')

assert(NLNpcInteractionMenu.findBody('marisol') == nil,
    'findBody only resolves registered NPC bodies')
assert(NLNpcInteractionMenu.firstPlayerItemChoice(player).item == 'Base.Hammer',
    'shared item helper rejects equipped items and returns the first eligible type')
assert(NLNpcInteractionMenu.firstNpcItemChoice('marisol').item == 'Base.Bandage',
    'shared item helper reads the authoritative NPC inventory')

player.dead = true
local deadContext = newMenu()
eventHook(0, deadContext, { object }, false)
assert(#deadContext.options == 0, 'dead local players receive no NPC context actions')
print('PASS: world-context NPC discovery, overlay entry point, profile option and item routing')
