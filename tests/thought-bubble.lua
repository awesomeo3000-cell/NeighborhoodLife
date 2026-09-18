-- Reaction thought-bubble contract. Native-shaped UI/projection mocks; this is
-- not gameplay or multiplayer evidence.
local root = arg[1]
package.path = root .. '/42/media/lua/client/?.lua;' .. root .. '/42/media/lua/shared/?.lua;' .. package.path

ISPanel = {}
function ISPanel:derive(name) local t = {}; t.__index = t; setmetatable(t, {__index=self}); return t end
function ISPanel:new(x, y, w, h) return setmetatable({ x=x, y=y, width=w, height=h }, self) end
function ISPanel:initialise() end
function ISPanel:addToUIManager() self.attached = true end
function ISPanel:removeFromUIManager() self.attached = false end
function ISPanel:bringToTop() self.onTop = true end
function ISPanel:setVisible(v) self.visible = v end
function ISPanel:setX(v) self.x = v end
function ISPanel:setY(v) self.y = v end
function ISPanel:setWidth(v) self.width = v end
function ISPanel:setHeight(v) self.height = v end
function ISPanel:getWidth() return self.width end
function ISPanel:getHeight() return self.height end
function ISPanel:prerender() end
function ISPanel:drawRect() end
function ISPanel:drawTextureScaled(texture) self.drawn = texture.path end
package.preload['ISUI/ISPanel'] = function() return ISPanel end

local tickHook, renderHook, menuHook, disconnectHook
Events = {
    OnTick = { Add = function(f) tickHook = f end },
    OnRenderTick = { Add = function(f) renderHook = f end },
    OnMainMenuEnter = { Add = function(f) menuHook = f end },
    OnDisconnect = { Add = function(f) disconnectHook = f end },
}

local NOW = 1000
function getTimestampMs() return NOW end
function getTexture(path) return { path = path } end

local localPlayer = { name = 'nl-host' }
function localPlayer:getUsername() return self.name end
function getNumActivePlayers() return 2 end
function getSpecificPlayer(index) return index == 0 and localPlayer or nil end

local viewportOffset = { [0] = { left = 0, top = 0 }, [1] = { left = 640, top = 0 } }
function getPlayerScreenLeft(index) return viewportOffset[index].left end
function getPlayerScreenTop(index) return viewportOffset[index].top end
function getPlayerScreenWidth() return 640 end
function getPlayerScreenHeight() return 720 end

local screenX, screenY = 320, 360
function isoToScreenX(index) return screenX + viewportOffset[index].left end
function isoToScreenY(index) return screenY + viewportOffset[index].top end

NLSocialClient = { snapshots = {}, lastEvent = nil }
package.preload['NL/SocialClient'] = function() return NLSocialClient end

local bodies = {}
local function newBody(id)
    local body = { id = id, dead = false, square = {} }
    function body:isDead() return self.dead end
    function body:getCurrentSquare() return self.square end
    function body:getX() return 10.5 end
    function body:getY() return 10.5 end
    function body:getZ() return 0 end
    bodies[id] = body
    return body
end
NLNpcInteractionMenu = {
    findBody = function(id) return bodies[tostring(id)] end,
}

require 'NL/Social'
require 'NL/ThoughtBubble'

local model = newBody('marisol')
newBody('kenji')

-- Mood classification stays on the authoritative deltas.
local function reaction(action, ok, before, after)
    return NLSocial.reaction(action, ok, before or {}, after or {})
end
assert(reaction('introduce', true) == 'happy', 'introduction reads as happy')
assert(reaction('chat', true, { friendship=10 }, { friendship=14 }) == 'happy', 'positive chat reads as happy')
assert(reaction('flirt', true, { attraction=0 }, { attraction=4 }) == 'romantic', 'successful flirt reads as romantic')
assert(reaction('date_activity', true, { attraction=1 }, { attraction=4 }) == 'romantic', 'date activity reads as romantic')
assert(reaction('partner', true) == 'romantic', 'partnership reads as romantic')
assert(reaction('compliment', true, { attraction=0 }, { attraction=2 }) == 'happy',
    'a compliment stays happy instead of romantic')
assert(reaction('flirt', true, { friendship=0 }, { friendship=-3 }) == 'angry',
    'a rejected advance reads as angry')
assert(reaction('breakup', true) == 'sad', 'breakup reads as sad')
assert(reaction('request', true) == 'neutral', 'a fulfilled request reads as neutral')
assert(reaction('joke', true, { friendship=0 }, { friendship=2 }) == 'neutral', 'a weak joke reads as neutral')
assert(reaction('chat', false) == 'irritated', 'pacing rejection reads as irritated')
assert(reaction('flirt', false) == 'disinterested', 'unavailable flirt reads as disinterested')
assert(reaction('compliment', false) == 'irritated', 'premature compliment reads as irritated')
assert(reaction('date', false) == 'disinterested', 'unready date reads as disinterested')
assert(NLSocial.moods[reaction('unknown', true)] == true,
    'the classifier always returns a known mood key')

-- Show, replace, expire and mood/texture resolution.
assert(NLThoughtBubble.show('marisol', 'happy'), 'a loaded neighbor shows a thought bubble')
assert(NLThoughtBubble.activeCount() == 1 and NLThoughtBubble.isActive('marisol'), 'one active bubble')
local entry = NLThoughtBubble.bubbles['marisol']
assert(entry.panel.attached and entry.panel.visible, 'bubble panel is attached and visible')
assert(entry.panel.texture.path == 'media/textures/NL_Thought_happy.png', 'happy texture selected')
assert(NLThoughtBubble.textureFor('nonsense') == 'media/textures/NL_Thought_neutral.png',
    'unknown moods fall back to the neutral texture')
assert(NLThoughtBubble.show('marisol', 'angry'), 'a new reaction replaces the old bubble')
assert(NLThoughtBubble.activeCount() == 1 and NLThoughtBubble.bubbles['marisol'].mood == 'angry',
    'replacement keeps a single bubble per neighbor')
assert(not NLThoughtBubble.show('nobody', 'happy'), 'an unloaded neighbor is skipped')
assert(not NLThoughtBubble.show('marisol', nil), 'a missing mood is rejected')

NOW = NOW + NLThoughtBubble.DURATION + 100
tickHook()
assert(NLThoughtBubble.activeCount() == 0, 'bubbles expire after their duration')

-- Snapshot reactions cover successes and rejections for the local player.
NLSocialClient.snapshots[0] = { reaction = { seq = 1, mood = 'irritated', npcId = 'marisol' } }
tickHook()
assert(NLThoughtBubble.isActive('marisol') and NLThoughtBubble.bubbles.marisol.mood == 'irritated',
    'a private snapshot reaction shows a thought bubble')
tickHook()
assert(NLThoughtBubble.activeCount() == 1, 'the same snapshot sequence is not replayed')
NLSocialClient.snapshots[0].reaction = { seq = 2, mood = 'happy', npcId = 'marisol' }
tickHook()
assert(NLThoughtBubble.bubbles.marisol.mood == 'happy', 'a newer snapshot sequence updates the bubble')

-- Remote actors use the replicated event feed.
NLSocialClient.lastEvent = { revision = 11, npcId = 'kenji', mood = 'sad', actor = 'nl-guest' }
tickHook()
assert(NLThoughtBubble.isActive('kenji') and NLThoughtBubble.bubbles.kenji.mood == 'sad',
    'a remote social event shows the neighbor reaction')
tickHook()
assert(NLThoughtBubble.activeCount() == 2, 'the same event revision is not replayed')
NLSocialClient.lastEvent = { revision = 12, npcId = 'kenji', mood = 'happy', actor = 'nl-host' }
tickHook()
assert(NLThoughtBubble.bubbles.kenji.mood == 'sad',
    'the local actor snapshot owns the bubble instead of duplicating the event')

-- Anchoring, clamping and split-screen viewport.
NOW = NOW + 600
NLThoughtBubble.clear()
NLThoughtBubble.show('marisol', 'happy', 0)
renderHook()
entry = NLThoughtBubble.bubbles.marisol
assert(entry.panel.x == screenX - entry.panel.width / 2, 'bubble is centered over the target')
assert(entry.panel.y == screenY - NLThoughtBubble.LIFT - entry.panel.height,
    'bubble floats above the target head')
local previousX = entry.panel.x
screenX, screenY = 5, 5
renderHook()
assert(entry.panel.x >= 4 and entry.panel.y >= 4, 'a near-edge target keeps the bubble on screen')
screenX, screenY = 320, 360
NLThoughtBubble.show('kenji', 'happy', 1)
renderHook()
local split = NLThoughtBubble.bubbles.kenji.panel
assert(split.x >= 640 and split.x + split.width <= 1280,
    'split-screen bubbles clamp to the observer viewport')

-- Zoom scaling keeps the bubble above a larger on-screen model.
getCore = function() return { getZoom = function() return 2 end } end
NOW = NOW + 600
NLThoughtBubble.clear()
NLThoughtBubble.show('marisol', 'happy', 0)
renderHook()
local zoomed = NLThoughtBubble.bubbles.marisol.panel
assert(zoomed.y == screenY - NLThoughtBubble.LIFT * 2 - zoomed.height,
    'zoomed-in thought bubble lift scales with the game zoom')
assert(zoomed.width > NLThoughtBubble.SIZE, 'zoomed-in thought bubble scales up')
getCore = nil

-- Dead targets and cleanup.
NLThoughtBubble.clear()
NLThoughtBubble.show('marisol', 'happy')
model.dead = true
tickHook()
assert(not NLThoughtBubble.isActive('marisol'), 'a dead target removes the bubble')
model.dead = false
NLThoughtBubble.show('marisol', 'happy')
menuHook()
assert(NLThoughtBubble.activeCount() == 0, 'main menu cleanup removes every bubble')
NLThoughtBubble.show('marisol', 'happy')
if disconnectHook then disconnectHook() end
assert(NLThoughtBubble.activeCount() == 0, 'disconnect cleanup removes every bubble')
print('PASS: reaction moods, thought-bubble lifecycle, anchoring, split-screen and cleanup')
