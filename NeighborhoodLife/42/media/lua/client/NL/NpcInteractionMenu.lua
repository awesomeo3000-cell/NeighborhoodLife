-- Direct world interaction for authored neighborhood NPCs.
--
-- The world context menu is only the discovery point: it opens the floating
-- conversation overlay. Every action still travels through NLSocialClient and
-- is checked by the server for identity, proximity, line of sight, cooldown
-- and relationship state.
require "NL/SocialClient"
pcall(require, "NL/NpcClient")
pcall(require, "NL/ConversationOverlay")
pcall(require, "NL/Relationships")

NLNpcInteractionMenu = {}

local function idFromObject(object)
    if not object then return nil end
    if object.getModData then
        local ok, data = pcall(object.getModData, object)
        if ok and data and data.NeighborhoodNpcId then
            return tostring(data.NeighborhoodNpcId)
        end
    end
    if NLNpcSinglePlayer and NLNpcSinglePlayer.bodies then
        for id, body in pairs(NLNpcSinglePlayer.bodies) do
            if body == object then return tostring(id) end
        end
    end
    if NLNpcAuthority and NLNpcAuthority.bodies then
        for id, body in pairs(NLNpcAuthority.bodies) do
            if body == object then return tostring(id) end
        end
    end
    if NLNpcClient and NLNpcClient.bodies then
        for id, body in pairs(NLNpcClient.bodies) do
            if body == object then return tostring(id) end
        end
    end
    return nil
end

local function stateFor(id)
    return NLNpcClient and NLNpcClient.states and NLNpcClient.states[id] or nil
end

local function activeDateFor(index, id)
    local snapshot = NLSocialClient and NLSocialClient.snapshots
        and NLSocialClient.snapshots[index]
    for _, neighbor in ipairs((snapshot and snapshot.neighbors) or {}) do
        if neighbor.id == id then
            local date = neighbor.relation and neighbor.relation.activeDate
            return date and date.status == "active"
        end
    end
    return false
end

local function relationshipFor(index, id)
    local snapshot = NLSocialClient and NLSocialClient.snapshots
        and NLSocialClient.snapshots[index]
    for _, neighbor in ipairs((snapshot and snapshot.neighbors) or {}) do
        if neighbor.id == id then return neighbor end
    end
    return nil
end

local function npcLabel(id)
    local state = stateFor(id)
    if state and state.name then return tostring(state.name) end
    if NLNeighbors and NLNeighbors.definitions and NLNeighbors.definitions[id] then
        local def = NLNeighbors.definitions[id]
        if def.name then return tostring(def.name) end
    end
    return tostring(id)
end

local function displayName(item, itemType)
    if item and item.getDisplayName then
        local ok, label = pcall(item.getDisplayName, item)
        if ok and type(label) == "string" and label ~= "" then return label end
    end
    return itemType
end

-- Shared inventory helpers. The conversation overlay uses the same helpers as
-- the activation path so every label matches the item the server will receive.
function NLNpcInteractionMenu.firstPlayerItemChoice(player)
    local inventory = player and player.getInventory and player:getInventory()
    local items = inventory and inventory.getItems and inventory:getItems()
    if not items then return nil end
    local choices = {}
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        local fullType = item and item.getFullType and item:getFullType()
        local equipped = false
        if item and player.isEquipped then
            local ok, value = pcall(player.isEquipped, player, item)
            equipped = ok and value == true
        end
        if fullType and not equipped and not choices[fullType] then
            choices[fullType] = { item = fullType, label = displayName(item, fullType) }
        end
    end
    local names = {}
    for itemType, _ in pairs(choices) do names[#names + 1] = itemType end
    table.sort(names)
    return names[1] and choices[names[1]] or nil
end

local function firstInventoryType(player)
    local choice = NLNpcInteractionMenu.firstPlayerItemChoice(player)
    return choice and choice.item or nil
end

function NLNpcInteractionMenu.firstNpcItemChoice(id)
    local state = stateFor(id)
    if state and state.inventoryItems and state.inventoryItems[1] then
        local entry = state.inventoryItems[1]
        return {
            item = entry.item,
            label = entry.label or entry.item,
            amount = tonumber(entry.amount or 1) or 1,
        }
    end
    if state and state.inventory then
        local names = {}
        for itemType, amount in pairs(state.inventory) do
            if tonumber(amount) and tonumber(amount) > 0 then names[#names + 1] = itemType end
        end
        table.sort(names)
        if names[1] then
            return {
                item = names[1],
                label = names[1],
                amount = tonumber(state.inventory[names[1]]) or 1,
            }
        end
    end
    return nil
end

local function firstNpcInventoryType(id)
    local choice = NLNpcInteractionMenu.firstNpcItemChoice(id)
    if not choice then return nil, 0 end
    return choice.item, choice.amount or 1
end

function NLNpcInteractionMenu.findBody(id)
    id = tostring(id)
    local sources = {}
    if NLNpcSinglePlayer and NLNpcSinglePlayer.bodies then
        sources[#sources + 1] = NLNpcSinglePlayer.bodies
    end
    if NLNpcAuthority and NLNpcAuthority.bodies then
        sources[#sources + 1] = NLNpcAuthority.bodies
    end
    if NLNpcClient and NLNpcClient.bodies then
        sources[#sources + 1] = NLNpcClient.bodies
    end
    for _, bodies in ipairs(sources) do
        if bodies[id] then return bodies[id] end
    end
    return nil
end

function NLNpcInteractionMenu.activate(player, id, action)
    if not player or not id or not action or not NLSocialClient then return end
    local index = player.getPlayerNum and player:getPlayerNum() or 0
    if action == "relationships" then
        if NLRelationships and NLRelationships.open then NLRelationships.open(index) end
    elseif action == "give" then
        local itemType = firstInventoryType(player)
        if itemType then
            NLSocialClient.request(index, "give", { id = id, item = itemType, amount = 1 })
        end
    elseif action == "request" then
        local itemType, amount = firstNpcInventoryType(id)
        if itemType then
            NLSocialClient.request(index, "request", { id = id, item = itemType,
                amount = math.min(1, amount) })
        end
    else
        NLSocialClient.request(index, "interact", { id = id, action = action })
    end
end

-- Open the floating world conversation cluster for one authored neighbor.
function NLNpcInteractionMenu.talk(player, id, body)
    if not player or not id then return end
    if not NLConversationOverlay then
        pcall(require, "NL/ConversationOverlay")
    end
    if NLConversationOverlay and NLConversationOverlay.open then
        local index = player.getPlayerNum and player:getPlayerNum() or 0
        NLConversationOverlay.open(index, id, body)
    end
end

function NLNpcInteractionMenu.menu(index, context, worldobjects)
    local player = getSpecificPlayer(index)
    if not player or player:isDead() or not context then return end
    local seen = {}
    for _, object in ipairs(worldobjects or {}) do
        local id = idFromObject(object)
        if id and not seen[id] then
            seen[id] = true
            context:addOption("Talk to " .. npcLabel(id), player, NLNpcInteractionMenu.talk, id, object)
            context:addOption("View relationship", player, NLNpcInteractionMenu.activate, id, "relationships")
        end
    end
end

NLNpcInteractionMenu.idFromObject = idFromObject
NLNpcInteractionMenu.stateFor = stateFor
NLNpcInteractionMenu.activeDateFor = activeDateFor
NLNpcInteractionMenu.relationshipFor = relationshipFor
NLNpcInteractionMenu.npcLabel = npcLabel

Events.OnFillWorldObjectContextMenu.Add(NLNpcInteractionMenu.menu)
return NLNpcInteractionMenu
