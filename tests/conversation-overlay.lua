-- Sims-style conversation overlay contract. Native-shaped UI/projection mocks;
-- this is not gameplay, mouse or multiplayer evidence.
local root = arg[1]
package.path = root .. '/42/media/lua/client/?.lua;' .. root .. '/42/media/lua/shared/?.lua;' .. package.path

UIFont = { Small = 1 }
function getTextManager()
    return {
        MeasureStringX = function(_, _, label) return #tostring(label) * 7 end,
        getFontHeight = function() return 12 end,
    }
end

ISButton = {}
function ISButton:derive(name) local t = {}; t.__index = t; setmetatable(t, {__index=self}); return t end
function ISButton:new(x, y, width, height, title, target, onclick)
    local o = { x=x, y=y, width=width, height=height, title=title, enable=true, mouseOver=false,
        onclick=onclick, target=target }
    setmetatable(o, self)
    self.__index = self
    return o
end
package.preload['ISUI/ISButton'] = function() return ISButton end
package.preload['ISUI/ISPanel'] = function() return ISButton end

local function addMethods(class)
    function class:initialise() end
    function class:addToUIManager() self.attached = true end
    function class:removeFromUIManager() self.attached = false end
    function class:bringToTop() self.onTop = true end
    function class:setVisible(v) self.visible = v end
    function class:setX(v) self.x = v end
    function class:setY(v) self.y = v end
    function class:getX() return self.x end
    function class:getY() return self.y end
    function class:setWidth(v) self.width = v end
    function class:setHeight(v) self.height = v end
    function class:getWidth() return self.width end
    function class:getHeight() return self.height end
    function class:setEnable(v) self.enable = v end
    function class:setTitle(v) self.title = v end
    function class:getTitle() return self.title end
    function class:drawRect() end
    function class:drawTextCentre() end
    function class:prerender() end
end
addMethods(ISButton)

local tickHook, renderHook, menuHook, disconnectHook
Events = {
    OnTick = { Add = function(f) tickHook = f end },
    OnRenderTick = { Add = function(f) renderHook = f end },
    OnMainMenuEnter = { Add = function(f) menuHook = f end },
    OnDisconnect = { Add = function(f) disconnectHook = f end },
}

local snapshots = {}
NLSocialClient = {
    snapshots = snapshots,
    requests = {},
    request = function(index, command, args)
        NLSocialClient.requests[#NLSocialClient.requests + 1] = {
            index = index, command = command, args = args,
        }
    end,
}
package.preload['NL/SocialClient'] = function() return NLSocialClient end

local activations = {}
local npcItemChoices = {}
local bodies = {}
NLNpcInteractionMenu = {
    activate = function(player, id, action)
        activations[#activations + 1] = { player = player, id = id, action = action }
    end,
    firstPlayerItemChoice = function(player) return player and player.itemChoice or nil end,
    firstNpcItemChoice = function(id) return npcItemChoices[id] end,
    findBody = function(id) return bodies[id] end,
}

local function newBody(id)
    local body = { npcId = id, x = 10.5, y = 10.5, z = 0, dead = false, square = {} }
    function body:getX() return self.x end
    function body:getY() return self.y end
    function body:getZ() return self.z end
    function body:isDead() return self.dead end
    function body:getCurrentSquare() return self.square end
    bodies[id] = body
    return body
end

local function newPlayer(index)
    local player = { index = index, x = 10.5, y = 11.0, z = 0, dead = false, canSee = true }
    function player:isDead() return self.dead end
    function player:getX() return self.x end
    function player:getY() return self.y end
    function player:getZ() return self.z end
    function player:getPlayerNum() return self.index end
    function player:CanSee() return self.canSee end
    return player
end

local players = { [0] = newPlayer(0), [1] = newPlayer(1) }
function getSpecificPlayer(index) return players[index or 0] end
function getNumActivePlayers() return 2 end

local viewportOffset = { [0] = { left = 0, top = 0 }, [1] = { left = 640, top = 0 } }
function getPlayerScreenLeft(index) return viewportOffset[index].left end
function getPlayerScreenTop(index) return viewportOffset[index].top end
function getPlayerScreenWidth() return 640 end
function getPlayerScreenHeight() return 720 end

local screenX, screenY = 320, 400
function isoToScreenX(index, x, y, z)
    return screenX + (viewportOffset[index] and viewportOffset[index].left or 0)
end
function isoToScreenY(index, x, y, z)
    return screenY + (viewportOffset[index] and viewportOffset[index].top or 0)
end

local function newNeighbor(overrides)
    local neighbor = {
        id = 'marisol', name = 'Marisol Vega', available = true, dead = false,
        canInteract = true, distance = 1, sameFloor = true, exclusive = false,
        isPartner = false, canPartner = false, canBreakup = false, canApologize = false,
        inventoryItems = {}, inventory = {},
        relation = { met = true, friendship = 10, trust = 5, attraction = 0, activeDate = nil },
    }
    for key, value in pairs(overrides or {}) do neighbor[key] = value end
    return neighbor
end

local function setSnapshot(index, neighbor)
    snapshots[index] = { neighbors = { neighbor }, revision = 1 }
end

require 'NL/ConversationOverlay'

local body = newBody('marisol')
local kenjiBody = newBody('kenji')
setSnapshot(0, newNeighbor())
setSnapshot(1, newNeighbor())

local function actions(overrides)
    setSnapshot(0, newNeighbor(overrides))
    local overlay = NLConversationOverlay.overlays[0]
    if overlay then
        overlay.entries = NLConversationOverlay.availableActions(0, 'marisol', players[0])
    end
    return NLConversationOverlay.availableActions(0, 'marisol', players[0])
end

local function actionSet(entries)
    local set = {}
    for _, entry in ipairs(entries) do set[entry.action] = true end
    return set
end

local function bubbleFor(index, action)
    local overlay = NLConversationOverlay.overlays[index]
    for _, bubble in ipairs(overlay and overlay.bubbles or {}) do
        if bubble.entry and bubble.entry.action == action then return bubble end
    end
    return nil
end

local function bubbleCount(index)
    return #(NLConversationOverlay.overlays[index] and NLConversationOverlay.overlays[index].bubbles or {})
end

-- Opening
local overlay = NLConversationOverlay.open(0, 'marisol', body)
assert(overlay ~= nil and NLConversationOverlay.isOpen(0), 'opening a valid NPC creates one overlay')
assert(overlay.npcId == 'marisol' and overlay.body == body, 'overlay tracks the selected NPC body')
assert(NLSocialClient.requests[#NLSocialClient.requests].command == 'refresh',
    'opening the overlay requests a fresh authoritative snapshot')
assert(snapshots[0].neighbors[1].relation.friendship == 10 and not activations[1],
    'opening the overlay mutates no relationship data and sends no social action')

local previous = overlay
NLConversationOverlay.open(0, 'kenji', kenjiBody)
assert(NLConversationOverlay.overlays[0] ~= previous and NLConversationOverlay.overlays[0].npcId == 'kenji',
    'opening another NPC replaces the previous target for that player')
assert(NLConversationOverlay.overlays[0] ~= nil and NLConversationOverlay.overlays[1] == nil,
    'overlays stay owned by one local player index')

-- Action population
NLConversationOverlay.open(0, 'marisol', body)
local set = actionSet(actions())
assert(set.chat and set.joke and set.ask_work and set.talk_home and set.relationships,
    'an introduced relationship exposes the normal conversation actions')
assert(not set.introduce, 'introduce is omitted once the relationship is met')
assert(not set.compliment, 'compliment stays hidden below the friendship threshold')
assert(not set.date and not set.partner and not set.breakup and not set.apologize,
    'unavailable romance and repair actions are omitted rather than disabled')

set = actionSet(actions({ canApologize = true, canPartner = true, canBreakup = true,
    relation = { met = true, friendship = -5, trust = 40, attraction = 40,
        activeDate = { status = 'active' } } }))
assert(set.date_activity, 'an active date exposes Spend time together')
assert(set.apologize, 'canApologize exposes the apology action')
assert(set.partner and set.breakup, 'partner and breakup actions follow the authoritative flags')

set = actionSet(actions({ relation = { met = true, friendship = 40, trust = 20, attraction = 40 } }))
assert(set.compliment, 'compliment appears once friendship reaches the server threshold')
assert(set.date, 'a qualifying relationship can ask for a date')
assert(set.flirt, 'a qualifying, available neighbor can be flirted with')

players[0].itemChoice = { item = 'Base.Hammer', label = 'Hammer' }
npcItemChoices.marisol = { item = 'Base.Bandage', label = 'Bandage', amount = 2 }
local entries = NLConversationOverlay.availableActions(0, 'marisol', players[0])
set = actionSet(entries)
assert(set.give and set.request, 'give and request appear when both inventories have eligible items')
for _, entry in ipairs(entries) do
    if entry.action == 'give' then assert(entry.label == 'Give Hammer', 'give label names the offered item') end
    if entry.action == 'request' then assert(entry.label == 'Request Bandage', 'request label names the NPC item') end
end
players[0].itemChoice = nil
npcItemChoices.marisol = nil
set = actionSet(NLConversationOverlay.availableActions(0, 'marisol', players[0]))
assert(not set.give and not set.request, 'give and request are omitted without eligible inventory')

-- Routing through the existing activation path
activations = {}
NLConversationOverlay.open(0, 'marisol', body)
local chat = bubbleFor(0, 'chat')
assert(chat ~= nil, 'chat bubble rendered on the primary page')
chat.onBubbleClick(chat)
assert(#activations == 1 and activations[1].action == 'chat' and activations[1].id == 'marisol',
    'selecting chat routes through the production activation path')
assert(not NLConversationOverlay.isOpen(0), 'the overlay closes after an actual social action')

setSnapshot(0, newNeighbor({ exclusive = true,
    relation = { met = true, friendship = 10, trust = 5, attraction = 0 } }))
players[0].itemChoice = { item = 'Base.Hammer', label = 'Hammer' }
npcItemChoices.marisol = { item = 'Base.Bandage', label = 'Bandage', amount = 2 }
NLConversationOverlay.open(0, 'marisol', body)
local give = bubbleFor(0, 'give')
give.onBubbleClick(give)
assert(activations[#activations].action == 'give', 'give bubble uses the existing give path')
NLConversationOverlay.open(0, 'marisol', body)
local request = bubbleFor(0, 'request')
request.onBubbleClick(request)
assert(activations[#activations].action == 'request', 'request bubble uses the existing request path')
NLConversationOverlay.open(0, 'marisol', body)
NLConversationOverlay.choose(0, { action = 'relationships' })
assert(activations[#activations].action == 'relationships',
    'relationship bubble routes to the relationship details viewer')
assert(not NLConversationOverlay.isOpen(0), 'relationship selection closes the world overlay')

-- More Choices / Back navigation
setSnapshot(0, newNeighbor({ canApologize = true, canPartner = true, canBreakup = true,
    relation = { met = true, friendship = 40, trust = 40, attraction = 40,
        activeDate = { status = 'active' } } }))
players[0].itemChoice = { item = 'Base.Hammer', label = 'Hammer' }
npcItemChoices.marisol = { item = 'Base.Bandage', label = 'Bandage', amount = 2 }
activations = {}
local before = #activations
NLConversationOverlay.open(0, 'marisol', body)
overlay = NLConversationOverlay.overlays[0]
assert(overlay.page == 'primary', 'overlay opens on the primary page')
assert(bubbleCount(0) <= NLConversationOverlay.MAX_PRIMARY + 1,
    'the primary page never shows more than the capped cluster')
local more = bubbleFor(0, 'more')
assert(more ~= nil and more.navigation == true, 'More Choices appears when extra actions are available')
more.onBubbleClick(more)
assert(overlay.page == 'more' and #activations == before,
    'More Choices changes the page without sending a social command')
assert(bubbleFor(0, 'back') ~= nil, 'More Choices page offers Back')
local category = bubbleFor(0, 'category')
assert(category ~= nil, 'More Choices lists a category bubble')
category.onBubbleClick(category)
assert(overlay.page ~= 'primary' and overlay.page ~= 'more', 'category opens its own page')
assert(bubbleFor(0, 'back') ~= nil, 'category page offers Back')
bubbleFor(0, 'back').onBubbleClick()
assert(overlay.page == 'more', 'Back returns to the More Choices page')
bubbleFor(0, 'back').onBubbleClick()
assert(overlay.page == 'primary', 'Back returns to the primary page')

-- Anchoring and viewport clamping
NLConversationOverlay.closeAll()
NLConversationOverlay.open(0, 'marisol', body)
overlay = NLConversationOverlay.overlays[0]
screenX, screenY = 320, 400
renderHook()
for _, bubble in ipairs(overlay.bubbles) do
    assert(bubble.x >= 0 and bubble.y >= 0
        and bubble.x + bubble.width <= 640 and bubble.y + bubble.height <= 720,
        'bubbles stay inside the observer viewport')
    assert(math.abs(bubble.x - screenX) < 320 and math.abs(bubble.y - screenY) < 300,
        'bubbles are anchored around the projected NPC position')
end
local tracked = overlay.bubbles[1]
local oldX, oldY = tracked.x, tracked.y
screenX, screenY = 220, 300
renderHook()
assert(tracked.x ~= oldX or tracked.y ~= oldY, 'bubbles track the NPC when the camera moves')

screenX, screenY = 8, 8
renderHook()
for _, bubble in ipairs(overlay.bubbles) do
    assert(bubble.x >= 0 and bubble.y >= 0 and bubble.x + bubble.width <= 640,
        'a near-edge NPC shifts the cluster inward instead of clipping bubbles')
end

-- Layout offsets scale with the game zoom; zoom 1 keeps the tuned layout.
local scaleBubbles = { { width = 100, height = 26 }, { width = 100, height = 26 } }
local flatLayout = NLConversationOverlay.layoutCluster({ x = 400, y = 300 }, scaleBubbles,
    { left = 0, top = 0, width = 1280, height = 720 }, 1)
local zoomedLayout = NLConversationOverlay.layoutCluster({ x = 400, y = 300 }, scaleBubbles,
    { left = 0, top = 0, width = 1280, height = 720 }, 2)
assert(flatLayout[1].x == 400 - 30 - 100 and flatLayout[2].x == 400 + 30,
    'zoom 1 keeps the tuned paired layout')
assert(zoomedLayout[1].x == 400 - 60 - 100 and zoomedLayout[2].x == 400 + 60,
    'conversation layout offsets scale with the game zoom')
assert(zoomedLayout[1].y ~= flatLayout[1].y, 'conversation vertical center scales with the game zoom')
assert(NLConversationOverlay.zoomScale(0) == 1, 'missing zoom configuration defaults to 1')

NLConversationOverlay.open(1, 'marisol', body)
local second = NLConversationOverlay.overlays[1]
screenX, screenY = 320, 400
renderHook()
for _, bubble in ipairs(second.bubbles) do
    assert(bubble.x >= 640 and bubble.x + bubble.width <= 1280,
        'split-screen overlay uses the observer player viewport')
end
NLConversationOverlay.close(1)

-- Close behavior
NLConversationOverlay.closeAll()
NLConversationOverlay.open(0, 'marisol', body)
players[0].dead = true
tickHook()
assert(not NLConversationOverlay.isOpen(0), 'a dead local player closes the overlay')
players[0].dead = false

NLConversationOverlay.open(0, 'marisol', body)
body.dead = true
tickHook()
assert(not NLConversationOverlay.isOpen(0), 'a dead target closes the overlay')
body.dead = false

NLConversationOverlay.open(0, 'marisol', body)
body.square = nil
tickHook()
assert(not NLConversationOverlay.isOpen(0), 'a streamed-out or unavailable target body closes the overlay')
body.square = {}

NLConversationOverlay.open(0, 'marisol', body)
players[0].x = body.x + 10
tickHook()
assert(not NLConversationOverlay.isOpen(0), 'leaving interaction range closes the overlay')
players[0].x = body.x

NLConversationOverlay.open(0, 'marisol', body)
players[0].z = 1
tickHook()
assert(not NLConversationOverlay.isOpen(0), 'a different floor closes the overlay')
players[0].z = 0

NLConversationOverlay.open(0, 'marisol', body)
players[0].canSee = false
tickHook()
assert(not NLConversationOverlay.isOpen(0), 'lost line of sight closes the overlay')
players[0].canSee = true

NLConversationOverlay.open(0, 'marisol', body)
snapshots[0] = { neighbors = { newNeighbor({ dead = true }) }, revision = 2 }
tickHook()
assert(not NLConversationOverlay.isOpen(0), 'an authoritative death snapshot closes the overlay')

setSnapshot(0, newNeighbor())
NLConversationOverlay.open(0, 'marisol', body)
assert(NLConversationOverlay.isOpen(0), 'overlay reopens after the close condition clears')
menuHook()
assert(not NLConversationOverlay.anyOpen(), 'main menu cleanup removes every overlay')

NLConversationOverlay.open(0, 'marisol', body)
if disconnectHook then disconnectHook() end
assert(not NLConversationOverlay.anyOpen(), 'disconnect cleanup removes every overlay')

print('PASS: conversation overlay opening, availability, routing, navigation, anchoring and cleanup')
