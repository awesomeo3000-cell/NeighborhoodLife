-- World-context NPC interaction contract. This proves menu discovery and
-- command routing with shaped UI fixtures; it is not real mouse or multiplayer
-- gameplay evidence.
local root = arg[1]
package.path = root .. '/42/media/lua/client/?.lua;' .. package.path

local eventHook
Events = { OnFillWorldObjectContextMenu = { Add = function(f) eventHook = f end } }
local panelStub = function() end
package.preload['NL/SocialClient'] = function()
    NLSocialClient = { requests = {}, request = function(index, command, args)
        NLSocialClient.requests[#NLSocialClient.requests + 1] = {
            index = index, command = command, args = args,
        }
    end }
    return NLSocialClient
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
assert(#context.options == 1, 'world context menu discovers one authored NPC')
local submenu = context.options[1].submenu
assert(context.options[1].label == 'Neighborhood: Marisol Vega')
assert(#submenu.options == 7, 'NPC menu exposes five social actions plus give/request')

local byLabel = {}
for _, option in ipairs(submenu.options) do byLabel[option.label] = option end
byLabel['Introduce'].callback(byLabel['Introduce'].target, unpack(byLabel['Introduce'].args))
assert(NLSocialClient.requests[#NLSocialClient.requests].command == 'interact'
    and NLSocialClient.requests[#NLSocialClient.requests].args.id == 'marisol'
    and NLSocialClient.requests[#NLSocialClient.requests].args.action == 'introduce',
    'introduce action routes through the production social client')
byLabel['Give 1 item'].callback(byLabel['Give 1 item'].target, unpack(byLabel['Give 1 item'].args))
assert(NLSocialClient.requests[#NLSocialClient.requests].command == 'give'
    and NLSocialClient.requests[#NLSocialClient.requests].args.item == 'Base.Hammer',
    'give action selects an unequipped main-inventory item')
byLabel['Request 1 Base.Bandage'].callback(byLabel['Request 1 Base.Bandage'].target,
    unpack(byLabel['Request 1 Base.Bandage'].args))
assert(NLSocialClient.requests[#NLSocialClient.requests].command == 'request'
    and NLSocialClient.requests[#NLSocialClient.requests].args.item == 'Base.Bandage',
    'request action selects an authoritative NPC inventory item')

player.dead = true
local deadContext = newMenu()
eventHook(0, deadContext, { object }, false)
assert(#deadContext.options == 0, 'dead local players receive no NPC context actions')
print('PASS: world-context NPC discovery, social actions, item routing and dead-player guard')
