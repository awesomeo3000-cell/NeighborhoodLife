require "ISUI/ISPanel"

-- Screen-space marker for the active character and future authoritative NPC bodies.
-- The adapter is deliberately separate from NPC spawning: a marker never creates a body.
NLPlumbob = ISPanel:derive("NLPlumbob")
NLPlumbob.enabled = true
NLPlumbob.instances = {}
NLPlumbob.texturePath = "media/textures/NL_Plumbob.png"
NLPlumbob.defaultColor = { r = 0.22, g = 0.88, b = 0.58 }

function NLPlumbob.screenPosition(screenX, screenY, left, top, width, height, lift)
    return math.floor(screenX - left - width / 2), math.floor(screenY - top - height - lift)
end

function NLPlumbob:new(id, character, observerIndex, color)
    local o = ISPanel.new(self, 0, 0, 32, 48)
    o.markerId = id
    o.character = character
    o.observerIndex = observerIndex or 0
    o.color = color or self.defaultColor
    o.texture = getTexture(self.texturePath)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o:setVisible(false)
    return o
end

function NLPlumbob:positionOverCharacter()
    local character = self.character
    local index = self.observerIndex
    local observer = getSpecificPlayer(index)
    if not NLPlumbob.enabled or not character or not observer or character:isDead() then
        self:setVisible(false)
        return false
    end

    local zoom = 1
    if getCore and getCore().getZoom then zoom = math.max(0.5, getCore():getZoom(index)) end
    local scale = math.max(0.75, math.min(1.35, 1 / zoom))
    local width, height = math.floor(32 * scale), math.floor(48 * scale)
    self:setWidth(width)
    self:setHeight(height)
    local sx = isoToScreenX(index, character:getX(), character:getY(), character:getZ())
    local sy = isoToScreenY(index, character:getX(), character:getY(), character:getZ())
    local left, top = getPlayerScreenLeft(index), getPlayerScreenTop(index)
    local x, y = NLPlumbob.screenPosition(sx, sy, left, top, width, height, math.floor(48 * scale))
    self:setX(x)
    self:setY(y)
    self:setVisible(true)
    return true
end

function NLPlumbob:prerender()
    if not self:positionOverCharacter() then return end
    ISPanel.prerender(self)
    if self.texture then
        self:drawTextureScaled(self.texture, 0, 0, self.width, self.height, 0.96,
            self.color.r, self.color.g, self.color.b)
    else
        -- Keep a visible fallback if the texture cache is unavailable during load.
        local cx = math.floor(self.width / 2)
        self:drawRect(cx - 2, 0, 4, 5, 0.96, self.color.r, self.color.g, self.color.b)
        self:drawRect(cx - 8, 5, 16, 8, 0.96, self.color.r, self.color.g, self.color.b)
        self:drawRect(cx - 12, 13, 24, 8, 0.96, self.color.r, self.color.g, self.color.b)
        self:drawRect(cx - 8, 21, 16, 8, 0.96, self.color.r, self.color.g, self.color.b)
        self:drawRect(cx - 2, 29, 4, 7, 0.96, self.color.r, self.color.g, self.color.b)
    end
end

function NLPlumbob.register(id, character, observerIndex, color)
    if not id or not character then return nil end
    local old = NLPlumbob.instances[id]
    if old then old:removeFromUIManager() end
    local panel = NLPlumbob:new(id, character, observerIndex, color)
    panel:initialise()
    panel:addToUIManager()
    panel:bringToTop()
    NLPlumbob.instances[id] = panel
    return panel
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
end

Events.OnCreatePlayer.Add(NLPlumbob.createPlayer)
Events.OnMainMenuEnter.Add(NLPlumbob.cleanup)
