require "ISUI/ISPanel"

-- Screen-space marker for the active character and future authoritative NPC bodies.
-- The adapter is deliberately separate from NPC spawning: a marker never creates a body.
NLPlumbob = ISPanel:derive("NLPlumbob")
NLPlumbob.enabled = true
NLPlumbob.instances = {}
NLPlumbob.presenceEntries = {}
NLPlumbob.presenceRevision = 0
NLPlumbob.nativeRemoteIds = {}
NLPlumbob.texturePath = "media/textures/NL_Plumbob.png"
NLPlumbob.defaultColor = { r = 0.22, g = 0.88, b = 0.58 }
NLPlumbob.remoteColor = { r = 0.28, g = 0.86, b = 0.95 }
-- Keep the player silhouette dominant. The marker is deliberately tiny and
-- close, while the 8x11 source texture also protects the size if Build 42
-- draws a texture at native dimensions instead of honoring a scaled panel.
NLPlumbob.baseWidth = 12
NLPlumbob.baseHeight = 16
NLPlumbob.baseLift = 150

function NLPlumbob.screenPosition(screenX, screenY, left, top, width, height, lift)
    return math.floor(screenX - left - width / 2), math.floor(screenY - top - height - lift)
end

function NLPlumbob:new(id, character, observerIndex, color)
    local o = ISPanel.new(self, 0, 0, NLPlumbob.baseWidth, NLPlumbob.baseHeight)
    o.markerId = id
    o.character = character
    o.observerIndex = observerIndex or 0
    o.color = color or self.defaultColor
    o.texture = getTexture(self.texturePath)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    -- UIManager skips invisible panels, so the first frame must be eligible to
    -- render; positionOverCharacter hides it when the character is unavailable.
    o:setVisible(true)
    return o
end

local function characterValue(character, method, field)
    if character and character.isPresence then
        return tonumber(character[field] or 0) or 0
    end
    if not character or not character[method] then return 0 end
    local ok, value = pcall(character[method], character)
    return ok and (tonumber(value) or 0) or 0
end

local function characterIsDead(character)
    if character and character.isPresence then return character.alive == false end
    if not character or not character.isDead then return true end
    local ok, dead = pcall(character.isDead, character)
    return not ok or dead == true
end

local function localUsername(username)
    if not username or username == "" then return true end
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and player.getUsername then
            local ok, name = pcall(player.getUsername, player)
            if ok and name == username then return true end
        end
    end
    return false
end

function NLPlumbob:positionOverCharacter()
    local character = self.character
    local index = self.observerIndex
    local observer = getSpecificPlayer(index)
    if not NLPlumbob.enabled or not character or not observer or characterIsDead(character) then
        self:setVisible(false)
        return false
    end

    -- In Project Zomboid, Core.getZoom(player) returns values where zoom < 1.0
    -- is zoomed IN (larger on-screen character model) and zoom > 1.0 is zoomed OUT.
    -- The world height of the character on screen scales as (baseHeight / zoom),
    -- so the world-to-screen lift must scale with (1 / zoom) to remain floating
    -- atop the character's head across all zoom levels.
    local zoom = 1
    if getCore and getCore().getZoom then
        local ok, val = pcall(getCore().getZoom, getCore(), index)
        if ok and tonumber(val) then zoom = tonumber(val) end
    end
    zoom = math.max(0.25, math.min(4, zoom))
    local liftScale = 1 / zoom
    local sizeScale = math.max(0.75, math.min(1.5, 1 / zoom))
    local width, height = math.floor(NLPlumbob.baseWidth * sizeScale),
        math.floor(NLPlumbob.baseHeight * sizeScale)
    self:setWidth(width)
    self:setHeight(height)
    local worldX = characterValue(character, "getX", "x")
    local worldY = characterValue(character, "getY", "y")
    local worldZ = characterValue(character, "getZ", "z")
    local sx = isoToScreenX(index, worldX, worldY, worldZ)
    local sy = isoToScreenY(index, worldX, worldY, worldZ)
    local left, top = getPlayerScreenLeft(index), getPlayerScreenTop(index)
    -- Lift the bottom tip past the full player model, leaving the gem atop the head.
    local x, y = NLPlumbob.screenPosition(sx, sy, left, top, width, height,
        math.floor(NLPlumbob.baseLift * liftScale))
    self:setX(x)
    self:setY(y)
    self:setVisible(true)
    return true
end

function NLPlumbob:prerender()
    if not self:positionOverCharacter() then return end
    ISPanel.prerender(self)
    if self.texture then
        self:drawTextureScaled(self.texture, 0, 0, self.width, self.height, 0.96, 1, 1, 1)
    else
        -- Keep a visible fallback if the texture cache is unavailable during load.
        local cx = math.floor(self.width / 2)
        local mid = math.max(1, math.floor(self.width * 0.62))
        local lower = math.max(1, math.floor(self.height * 0.42))
        self:drawRect(cx - 1, 0, 2, math.max(1, math.floor(self.height * 0.18)),
            0.96, self.color.r, self.color.g, self.color.b)
        self:drawRect(cx - math.floor(mid / 2), math.floor(self.height * 0.18), mid,
            math.max(1, math.floor(self.height * 0.34)), 0.96,
            self.color.r, self.color.g, self.color.b)
        self:drawRect(cx - math.floor(lower / 2), math.floor(self.height * 0.52), lower,
            math.max(1, math.floor(self.height * 0.32)), 0.96,
            self.color.r, self.color.g, self.color.b)
        self:drawRect(cx - 1, math.floor(self.height * 0.84), 2,
            math.max(1, self.height - math.floor(self.height * 0.84)), 0.96,
            self.color.r, self.color.g, self.color.b)
    end
end

function NLPlumbob.register(id, character, observerIndex, color)
    if not id or not character then return nil end
    local old = NLPlumbob.instances[id]
    if old and old.character == character then
        old.observerIndex = observerIndex or old.observerIndex
        return old
    end
    if old then old:removeFromUIManager() end
    local panel = NLPlumbob:new(id, character, observerIndex, color)
    panel:initialise()
    panel:addToUIManager()
    panel:bringToTop()
    NLPlumbob.instances[id] = panel
    return panel
end

local function isLocalCharacter(character)
    if not character then return true end
    for i = 0, getNumActivePlayers() - 1 do
        if getSpecificPlayer(i) == character then return true end
    end
    return false
end

local function isRemoteReplica(character)
    if not character or not character.getModData then return false end
    local ok, data = pcall(character.getModData, character)
    return ok and data and data.NeighborhoodRemotePlayerId ~= nil
end

-- Build 42 exposes the native remote-player bodies through getOnlinePlayers()
-- on clients. Attach the same world-to-screen marker to those bodies without
-- constructing a substitute character or trusting client-supplied positions.
function NLPlumbob.syncRemotePlayers()
    NLPlumbob.nativeRemoteIds = {}
    if not getOnlinePlayers then
        NLPlumbob.syncPresenceMarkers()
        return 0
    end
    local ok, players = pcall(getOnlinePlayers)
    if not ok or not players then
        NLPlumbob.syncPresenceMarkers()
        return 0
    end
    local seen = {}
    local count = players:size()
    for i = 0, count - 1 do
        local character = players:get(i)
        local username
        if character and not isLocalCharacter(character) and character.getUsername then
            local usernameOk
            usernameOk, username = pcall(character.getUsername, character)
            if not usernameOk then username = nil end
        end
        if character and username and username ~= "" and not isRemoteReplica(character) then
            local id = "remote:" .. tostring(username)
            seen[id] = true
            NLPlumbob.nativeRemoteIds[id] = true
            NLPlumbob.register(id, character, 0, NLPlumbob.remoteColor)
        end
    end
    for id, panel in pairs(NLPlumbob.instances) do
        if string.sub(id, 1, 7) == "remote:" and not seen[id] then
            NLPlumbob.unregister(id)
        end
    end
    NLPlumbob.syncPresenceMarkers()
    return count
end

-- A dedicated server can know a peer's authoritative position even when the
-- client does not expose that peer through getOnlinePlayers(). Keep this as a
-- marker-only fallback: it never constructs a body or substitutes for native
-- character replication. Native bodies win whenever Build 42 exposes them.
function NLPlumbob.syncPresenceMarkers()
    local seen = {}
    for username, entry in pairs(NLPlumbob.presenceEntries) do
        if not localUsername(username) then
            local id = "presence:" .. tostring(username)
            seen[id] = true
            if NLPlumbob.nativeRemoteIds["remote:" .. tostring(username)] then
                NLPlumbob.unregister(id)
            else
                local proxy = NLPlumbob.instances[id] and NLPlumbob.instances[id].character
                if proxy then
                    proxy.x, proxy.y, proxy.z = entry.x, entry.y, entry.z
                    proxy.alive = entry.alive ~= false
                else
                    proxy = {
                        isPresence = true, username = username,
                        x = tonumber(entry.x or 0) or 0,
                        y = tonumber(entry.y or 0) or 0,
                        z = tonumber(entry.z or 0) or 0,
                        alive = entry.alive ~= false,
                    }
                    NLPlumbob.register(id, proxy, 0, NLPlumbob.remoteColor)
                end
            end
        end
    end
    local stale = {}
    for id, _ in pairs(NLPlumbob.instances) do
        if string.sub(id, 1, 9) == "presence:" and not seen[id] then
            stale[#stale + 1] = id
        end
    end
    for _, id in ipairs(stale) do
        NLPlumbob.unregister(id)
    end
end

function NLPlumbob.applyPresence(packet)
    if type(packet) ~= "table" or type(packet.players) ~= "table" then return 0 end
    local revision = tonumber(packet.revision or 0) or 0
    if revision < NLPlumbob.presenceRevision then return 0 end
    NLPlumbob.presenceRevision = revision
    NLPlumbob.presenceEntries = {}
    for _, entry in ipairs(packet.players) do
        local username = entry and tostring(entry.username or "") or ""
        if username ~= "" and not localUsername(username) then
            NLPlumbob.presenceEntries[username] = entry
        end
    end
    NLPlumbob.syncPresenceMarkers()
    local count = 0
    for _, _ in pairs(NLPlumbob.presenceEntries) do count = count + 1 end
    return count
end

function NLPlumbob.clearPresence()
    NLPlumbob.presenceEntries = {}
    NLPlumbob.presenceRevision = 0
    local stale = {}
    for id, _ in pairs(NLPlumbob.instances) do
        if string.sub(id, 1, 9) == "presence:" then stale[#stale + 1] = id end
    end
    for _, id in ipairs(stale) do
        NLPlumbob.unregister(id)
    end
end

function NLPlumbob.unregister(id)
    local panel = NLPlumbob.instances[id]
    if panel then panel:removeFromUIManager() end
    NLPlumbob.instances[id] = nil
end

function NLPlumbob.createPlayer(index, player)
    NLPlumbob.register("player:" .. tostring(index), player, index, NLPlumbob.defaultColor)
end

function NLPlumbob.cleanup()
    for _, panel in pairs(NLPlumbob.instances) do panel:removeFromUIManager() end
    NLPlumbob.instances = {}
    NLPlumbob.presenceEntries = {}
    NLPlumbob.presenceRevision = 0
    NLPlumbob.nativeRemoteIds = {}
end

Events.OnCreatePlayer.Add(NLPlumbob.createPlayer)
Events.OnRenderTick.Add(function()
    if not isClient() then return end
    NLPlumbob.syncRemotePlayers()
end)
Events.OnMainMenuEnter.Add(NLPlumbob.cleanup)
