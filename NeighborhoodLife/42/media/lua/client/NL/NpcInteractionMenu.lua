-- Direct world interaction for authored neighborhood NPCs.
--
-- The menu is only a client entry point. Every action still travels through
-- NLSocialClient and is checked by the server for identity, proximity, line
-- of sight, cooldown and relationship state.
require "NL/SocialClient"
pcall(require, "NL/NpcClient")
pcall(require, "NL/Relationships")

NLNpcInteractionMenu = {}

local actions = {
    { label = "Introduce", action = "introduce" },
    { label = "Chat", action = "chat" },
    { label = "Tell a joke", action = "joke" },
    { label = "Ask about work", action = "ask_work" },
    { label = "Talk about home", action = "talk_home" },
    { label = "Compliment", action = "compliment" },
    { label = "Flirt", action = "flirt" },
    { label = "Ask on a date", action = "date" },
    { label = "View relationship", action = "relationships" },
}

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

local function firstInventoryType(player)
    local inventory = player and player.getInventory and player:getInventory()
    local items = inventory and inventory.getItems and inventory:getItems()
    if not items then return nil end
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        local fullType = item and item.getFullType and item:getFullType()
        local equipped = false
        if item and player.isEquipped then
            local ok, value = pcall(player.isEquipped, player, item)
            equipped = ok and value == true
        end
        if fullType and not equipped then return fullType end
    end
    return nil
end

local function firstNpcInventoryType(id)
    local state = stateFor(id)
    if state and state.inventoryItems and state.inventoryItems[1] then
        local entry = state.inventoryItems[1]
        return entry.item, tonumber(entry.amount or 1) or 1
    end
    if state and state.inventory then
        for itemType, amount in pairs(state.inventory) do
            if tonumber(amount) and tonumber(amount) > 0 then
                return itemType, tonumber(amount)
            end
        end
    end
    return nil, 0
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

local function addAction(submenu, label, player, id, action)
    submenu:addOption(label, player, NLNpcInteractionMenu.activate, id, action)
end

function NLNpcInteractionMenu.menu(index, context, worldobjects)
    local player = getSpecificPlayer(index)
    if not player or player:isDead() or not context then return end
    local seen = {}
    for _, object in ipairs(worldobjects or {}) do
        local id = idFromObject(object)
        if id and not seen[id] then
            seen[id] = true
            local option = context:addOption("Neighborhood: " .. npcLabel(id))
            local submenu = ISContextMenu:getNew(context)
            context:addSubMenu(option, submenu)
            for _, entry in ipairs(actions) do
                addAction(submenu, entry.label, player, id, entry.action)
            end
            if activeDateFor(index, id) then
                addAction(submenu, "Spend time together", player, id, "date_activity")
            end
            local relationship = relationshipFor(index, id)
            if relationship and relationship.canPartner then
                addAction(submenu, "Commit to partnership", player, id, "partner")
            elseif relationship and relationship.canBreakup then
                addAction(submenu, "End partnership", player, id, "breakup")
            end
            if relationship and relationship.canApologize then
                addAction(submenu, "Apologize", player, id, "apologize")
            end
            addAction(submenu, "Give 1 item", player, id, "give")
            local requestType = firstNpcInventoryType(id)
            addAction(submenu, requestType and ("Request 1 " .. tostring(requestType))
                or "Request item", player, id, "request")
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(NLNpcInteractionMenu.menu)
return NLNpcInteractionMenu
