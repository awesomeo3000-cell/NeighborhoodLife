-- Sims-style reaction thought bubble shown above a neighbor after an
-- interaction. The mood arrives from the authoritative social result, so the
-- client only presents it: rejected interactions use the private snapshot
-- reaction and remote actors use the replicated social event feed.
require "ISUI/ISPanel"
require "NL/SocialClient"

NLThoughtBubble = {
    bubbles = {},
    lastSnapshotSeq = {},
    lastEventRevision = nil,
    SIZE = 64,
    LIFT = 160,
    DURATION = 4200,
    FADE_IN = 200,
    FADE_OUT = 520,
    POP = 180,
    moods = {
        happy = true, romantic = true, angry = true, irritated = true,
        disinterested = true, sad = true, neutral = true,
    },
    fallbackColors = {
        happy = { r=1.00, g=0.84, b=0.34 },
        romantic = { r=1.00, g=0.56, b=0.72 },
        angry = { r=0.95, g=0.36, b=0.30 },
        irritated = { r=0.97, g=0.66, b=0.33 },
        disinterested = { r=0.66, g=0.71, b=0.75 },
        sad = { r=0.48, g=0.66, b=0.92 },
        neutral = { r=0.72, g=0.82, b=0.90 },
    },
}

local function clamp(value, low, high)
    if high < low then return low end
    if value < low then return low end
    if value > high then return high end
    return value
end

local function bodyAlive(body)
    if not body then return false end
    if body.isDead then
        local ok, dead = pcall(body.isDead, body)
        if not ok or dead == true then return false end
    end
    if body.getCurrentSquare then
        local ok, square = pcall(body.getCurrentSquare, body)
        if not ok or not square then return false end
    end
    return true
end

function NLThoughtBubble.textureFor(mood)
    if not NLThoughtBubble.moods[mood] then mood = "neutral" end
    return "media/textures/NL_Thought_" .. mood .. ".png"
end

-- Same world-to-screen projection used by NLPlumbob, kept local so the bubble
-- works even when the conversation overlay is closed.
function NLThoughtBubble.screenAnchor(index, body)
    if not body or type(isoToScreenX) ~= "function" or type(isoToScreenY) ~= "function" then
        return nil
    end
    local x = body.getX and body:getX() or nil
    local y = body.getY and body:getY() or nil
    local z = body.getZ and body:getZ() or 0
    if x == nil or y == nil then return nil end
    local okX, screenX = pcall(isoToScreenX, index, x, y, z or 0)
    local okY, screenY = pcall(isoToScreenY, index, x, y, z or 0)
    if not okX or not okY or screenX == nil or screenY == nil then return nil end
    return tonumber(screenX) or 0, tonumber(screenY) or 0
end

-- In Project Zomboid, Core.getZoom(index) returns values where zoom < 1.0 is
-- zoomed IN (larger model) and zoom > 1.0 is zoomed OUT. Clamping prevents
-- extreme edge cases.
function NLThoughtBubble.zoomScale(index)
    local zoom = 1
    if type(getCore) == "function" then
        local core = getCore()
        if core and core.getZoom then
            local ok, value = pcall(core.getZoom, core, index)
            if ok and tonumber(value) then zoom = tonumber(value) end
        end
    end
    return math.max(0.25, math.min(4, zoom))
end

function NLThoughtBubble.viewport(index)
    local left = type(getPlayerScreenLeft) == "function" and (tonumber(getPlayerScreenLeft(index)) or 0) or 0
    local top = type(getPlayerScreenTop) == "function" and (tonumber(getPlayerScreenTop(index)) or 0) or 0
    local width = type(getPlayerScreenWidth) == "function" and (tonumber(getPlayerScreenWidth(index)) or 1280) or 1280
    local height = type(getPlayerScreenHeight) == "function" and (tonumber(getPlayerScreenHeight(index)) or 720) or 720
    return { left = left, top = top, width = width, height = height }
end

NLThoughtBubblePanel = ISPanel:derive("NLThoughtBubblePanel")

function NLThoughtBubblePanel:new(mood)
    local size = NLThoughtBubble.SIZE
    local o = ISPanel.new(self, 0, 0, size, size)
    o.mood = mood
    o.alpha = 1
    o.texture = type(getTexture) == "function" and getTexture(NLThoughtBubble.textureFor(mood)) or nil
    o.backgroundColor = { r=0, g=0, b=0, a=0 }
    o.borderColor = { r=0, g=0, b=0, a=0 }
    o:setVisible(true)
    return o
end

function NLThoughtBubblePanel:prerender()
    if self.texture and self.drawTextureScaled then
        self:drawTextureScaled(self.texture, 0, 0, self.width, self.height,
            self.alpha or 1, 1, 1, 1)
        return
    end
    -- Texture-free fallback keeps the reaction readable before assets load
    -- (and in the Lua contract tests).
    if not self.drawRect then return end
    local alpha = self.alpha or 1
    local color = NLThoughtBubble.fallbackColors[self.mood] or NLThoughtBubble.fallbackColors.neutral
    self:drawRect(2, 10, self.width - 4, self.height - 16, alpha * 0.95, 0.96, 0.97, 0.99)
    self:drawRect(12, 4, self.width - 24, self.height - 24, alpha * 0.95, 0.99, 0.99, 1.00)
    self:drawRect(6, 26, 8, 8, alpha * 0.95, 0.96, 0.97, 0.99)
    local dot = math.floor(self.width * 0.28)
    self:drawRect(dot, dot, self.width - dot * 2, self.height - dot * 2, alpha, color.r, color.g, color.b)
end

function NLThoughtBubble.isActive(npcId)
    return NLThoughtBubble.bubbles[tostring(npcId or "")] ~= nil
end

function NLThoughtBubble.activeCount()
    local count = 0
    for _, _ in pairs(NLThoughtBubble.bubbles) do count = count + 1 end
    return count
end

function NLThoughtBubble.remove(npcId)
    local key = tostring(npcId or "")
    local entry = NLThoughtBubble.bubbles[key]
    if not entry then return false end
    if entry.panel and entry.panel.removeFromUIManager then
        pcall(entry.panel.removeFromUIManager, entry.panel)
    end
    NLThoughtBubble.bubbles[key] = nil
    return true
end

function NLThoughtBubble.clear()
    local keys = {}
    for npcId, _ in pairs(NLThoughtBubble.bubbles) do keys[#keys + 1] = npcId end
    for _, npcId in ipairs(keys) do NLThoughtBubble.remove(npcId) end
    NLThoughtBubble.lastSnapshotSeq = {}
    NLThoughtBubble.lastEventRevision = nil
end

function NLThoughtBubble.show(npcId, mood, observerIndex, duration)
    local key = tostring(npcId or "")
    if key == "" or not mood then return false end
    if not NLThoughtBubble.moods[mood] then mood = "neutral" end
    local body = NLNpcInteractionMenu and NLNpcInteractionMenu.findBody
        and NLNpcInteractionMenu.findBody(key) or nil
    if not body then return false end
    NLThoughtBubble.remove(key)
    local panel = NLThoughtBubblePanel:new(mood)
    panel:initialise()
    if panel.addToUIManager then panel:addToUIManager() end
    if panel.bringToTop then panel:bringToTop() end
    local now = getTimestampMs()
    NLThoughtBubble.bubbles[key] = {
        panel = panel,
        body = body,
        mood = mood,
        observer = observerIndex or 0,
        born = now,
        expires = now + (tonumber(duration) or NLThoughtBubble.DURATION),
    }
    NLThoughtBubble.positionAll()
    return true
end

local function localActor(actor)
    if not actor or actor == "" then return true end
    local count = type(getNumActivePlayers) == "function" and getNumActivePlayers() or 1
    for index = 0, count - 1 do
        local player = getSpecificPlayer(index)
        if player and player.getUsername then
            local ok, username = pcall(player.getUsername, player)
            if ok and username == actor then return true end
        end
    end
    return false
end

NLThoughtBubble.localActor = localActor

function NLThoughtBubble.consumeSnapshots()
    if not NLSocialClient or not NLSocialClient.snapshots then return 0 end
    local count = type(getNumActivePlayers) == "function" and getNumActivePlayers() or 1
    local shown = 0
    for index = 0, count - 1 do
        local snapshot = NLSocialClient.snapshots[index]
        local reaction = snapshot and snapshot.reaction
        if reaction and reaction.seq ~= nil
                and reaction.seq ~= NLThoughtBubble.lastSnapshotSeq[index] then
            NLThoughtBubble.lastSnapshotSeq[index] = reaction.seq
            if reaction.mood and reaction.npcId then
                if NLThoughtBubble.show(reaction.npcId, reaction.mood, index) then
                    shown = shown + 1
                end
            end
        end
    end
    return shown
end

function NLThoughtBubble.consumeEvents()
    local event = NLSocialClient and NLSocialClient.lastEvent
    if not event or event.revision == NLThoughtBubble.lastEventRevision then return 0 end
    NLThoughtBubble.lastEventRevision = event.revision
    if event.mood and event.npcId and not localActor(event.actor) then
        return NLThoughtBubble.show(event.npcId, event.mood, 0) and 1 or 0
    end
    return 0
end

function NLThoughtBubble.update()
    local now = getTimestampMs()
    NLThoughtBubble.consumeSnapshots()
    NLThoughtBubble.consumeEvents()
    local expired = {}
    for npcId, entry in pairs(NLThoughtBubble.bubbles) do
        if now >= entry.expires or not bodyAlive(entry.body) then
            expired[#expired + 1] = npcId
        end
    end
    for _, npcId in ipairs(expired) do NLThoughtBubble.remove(npcId) end
end

function NLThoughtBubble.positionAll()
    local now = getTimestampMs()
    for _, entry in pairs(NLThoughtBubble.bubbles) do
        local panel = entry.panel
        if panel then
            local age = now - entry.born
            local remaining = entry.expires - now
            local alpha = 1
            if age < NLThoughtBubble.FADE_IN then alpha = age / NLThoughtBubble.FADE_IN end
            if remaining < NLThoughtBubble.FADE_OUT then
                alpha = math.min(alpha, remaining / NLThoughtBubble.FADE_OUT)
            end
            alpha = clamp(alpha, 0, 1)
            local zoom = NLThoughtBubble.zoomScale(entry.observer)
            local liftScale = 1 / zoom
            local sizeScale = math.max(0.75, math.min(1.4, 1 / zoom))
            local pop = 0.72 + 0.28 * math.min(1, math.max(0, age) / NLThoughtBubble.POP)
            local size = math.floor(NLThoughtBubble.SIZE * pop * sizeScale)
            panel.alpha = alpha
            panel:setWidth(size)
            panel:setHeight(size)
            local anchorX, anchorY = NLThoughtBubble.screenAnchor(entry.observer, entry.body)
            if anchorX then
                local viewport = NLThoughtBubble.viewport(entry.observer)
                local x = anchorX - size / 2
                local y = anchorY - math.floor(NLThoughtBubble.LIFT * liftScale) - size
                panel:setX(clamp(x, viewport.left + 4, viewport.left + viewport.width - 4 - size))
                panel:setY(clamp(y, viewport.top + 4, viewport.top + viewport.height - 4 - size))
                panel:setVisible(true)
            else
                panel:setVisible(false)
            end
        end
    end
end

Events.OnTick.Add(NLThoughtBubble.update)
Events.OnRenderTick.Add(NLThoughtBubble.positionAll)
Events.OnMainMenuEnter.Add(NLThoughtBubble.clear)
if Events.OnDisconnect then Events.OnDisconnect.Add(NLThoughtBubble.clear) end

return NLThoughtBubble
