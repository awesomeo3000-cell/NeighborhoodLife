-- Sims-style world conversation overlay.
--
-- Choices float around the targeted NPC as individual pills instead of opening
-- a framed interaction panel. This module is presentation only: every final
-- choice still routes through NLNpcInteractionMenu.activate() and the existing
-- server-authoritative NLSocialClient request flow.
require "NL/SocialClient"
require "NL/ConversationBubble"

NLConversationOverlay = {
    overlays = {},
    MAX_PRIMARY = 6,
    INTERACT_RANGE = 4.5,
    REBUILD_TICKS = 10,
}

local CATEGORIES = {
    { key = "friendly", label = "Friendly" },
    { key = "funny", label = "Funny" },
    { key = "romance", label = "Romance" },
    { key = "relationship", label = "Relationship" },
}

local LAYOUT_GAP = 8
local LAYOUT_SIDE = 30
local LAYOUT_EDGE = 6

local function toNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function clamp(value, low, high)
    if high < low then return low end
    if value < low then return low end
    if value > high then return high end
    return value
end

function NLConversationOverlay.snapshot(index, id)
    local snapshots = NLSocialClient and NLSocialClient.snapshots
    local snapshot = snapshots and snapshots[index]
    for _, neighbor in ipairs((snapshot and snapshot.neighbors) or {}) do
        if neighbor.id == id then return neighbor end
    end
    return nil
end

function NLConversationOverlay.playerItemChoice(player)
    if NLNpcInteractionMenu and NLNpcInteractionMenu.firstPlayerItemChoice then
        local ok, choice = pcall(NLNpcInteractionMenu.firstPlayerItemChoice, player)
        if ok then return choice end
    end
    return nil
end

function NLConversationOverlay.npcItemChoice(id)
    if NLNpcInteractionMenu and NLNpcInteractionMenu.firstNpcItemChoice then
        local ok, choice = pcall(NLNpcInteractionMenu.firstNpcItemChoice, id)
        if ok then return choice end
    end
    return nil
end

local function availableForOtherPartner(npc)
    return npc and (npc.exclusive ~= true or npc.isPartner == true)
end

function NLConversationOverlay.flirtAvailable(npc)
    return availableForOtherPartner(npc) == true
end

function NLConversationOverlay.dateAvailable(npc, relation)
    if not availableForOtherPartner(npc) then return false end
    local activeDate = relation and relation.activeDate
    if activeDate and activeDate.status == "active" then return false end
    if (toNumber(relation and relation.friendship, 0) or 0) < 35 then return false end
    if (toNumber(relation and relation.attraction, 0) or 0) < 15 then return false end
    return true
end

-- Action discovery is derived from the authoritative social snapshot and the
-- current inventories. The client may omit clearly unavailable choices, but
-- the server still validates every request.
function NLConversationOverlay.availableActions(index, id, player)
    local npc = NLConversationOverlay.snapshot(index, id)
    if not npc then return {} end
    local relation = npc.relation or {}
    local entries = {}
    local function add(action, label, category, kind)
        entries[#entries + 1] = {
            action = action, label = label, category = category,
            kind = kind or "normal", priority = #entries + 1,
        }
    end

    if relation.met ~= true then
        add("introduce", "Introduce", "friendly")
    else
        local activeDate = relation.activeDate
        if activeDate and activeDate.status == "active" then
            add("date_activity", "Spend time together", "romance", "romance")
        end
        if npc.canApologize then add("apologize", "Apologize", "friendly") end
        add("chat", "Chat", "friendly")
        if (toNumber(relation.friendship, 0) or 0) >= 20 then
            add("compliment", "Compliment", "friendly")
        end
        add("joke", "Tell a joke", "funny")
        if NLConversationOverlay.flirtAvailable(npc) then
            add("flirt", "Flirt", "romance", "romance")
        end
        add("ask_work", "Ask about work", "friendly")
        add("talk_home", "Talk about home", "friendly")
        local give = NLConversationOverlay.playerItemChoice(player)
        if give then add("give", "Give " .. tostring(give.label or give.item), "friendly") end
        local request = NLConversationOverlay.npcItemChoice(id)
        if request then add("request", "Request " .. tostring(request.label or request.item), "friendly") end
        if NLConversationOverlay.dateAvailable(npc, relation) then
            add("date", "Ask on a date", "romance", "romance")
        end
        if npc.canPartner then add("partner", "Become partners", "romance", "romance") end
        if npc.canBreakup then add("breakup", "End partnership", "romance", "romance") end
    end
    add("relationships", "View relationship", "relationship")
    return entries
end

local function categoryLabel(key)
    for _, category in ipairs(CATEGORIES) do
        if category.key == key then return category.label end
    end
    return key
end

function NLConversationOverlay.pageEntries(overlay)
    local all = (overlay and overlay.entries) or {}
    local page = overlay and overlay.page or "primary"
    local entries = {}
    if page == "primary" then
        local visible = math.min(#all, NLConversationOverlay.MAX_PRIMARY)
        if #all > visible then
            entries[#entries + 1] = {
                action = "more", label = "More Choices...", kind = "nav", navigation = true,
            }
        end
        for position = 1, visible do
            entries[#entries + 1] = all[position]
        end
        return entries
    end
    if page == "more" then
        entries[#entries + 1] = {
            action = "back", label = "Back...", kind = "nav", navigation = true, targetPage = "primary",
        }
        for _, category in ipairs(CATEGORIES) do
            local count = 0
            for _, entry in ipairs(all) do
                if entry.category == category.key then count = count + 1 end
            end
            if count > 0 then
                entries[#entries + 1] = {
                    action = "category", label = category.label, kind = "nav",
                    category = category.key, targetPage = category.key,
                }
            end
        end
        return entries
    end
    entries[#entries + 1] = {
        action = "back", label = "Back...", kind = "nav", navigation = true, targetPage = "more",
    }
    for _, entry in ipairs(all) do
        if entry.category == page then entries[#entries + 1] = entry end
    end
    return entries
end

function NLConversationOverlay.pageTitle(overlay)
    local page = overlay and overlay.page or "primary"
    if page == "primary" or page == "more" then return "Conversation" end
    return categoryLabel(page)
end

function NLConversationOverlay.signature(page, entries)
    local parts = { page }
    for _, entry in ipairs(entries or {}) do
        parts[#parts + 1] = tostring(entry.action) .. ":" .. tostring(entry.label)
    end
    return table.concat(parts, "|")
end

function NLConversationOverlay.viewport(index)
    local left = 0
    local top = 0
    local width = 1280
    local height = 720
    if type(getPlayerScreenLeft) == "function" then left = toNumber(getPlayerScreenLeft(index), 0) or 0 end
    if type(getPlayerScreenTop) == "function" then top = toNumber(getPlayerScreenTop(index), 0) or 0 end
    if type(getPlayerScreenWidth) == "function" then
        width = toNumber(getPlayerScreenWidth(index), width) or width
    elseif getCore then
        width = toNumber(getCore():getScreenWidth(), width) or width
    end
    if type(getPlayerScreenHeight) == "function" then
        height = toNumber(getPlayerScreenHeight(index), height) or height
    elseif getCore then
        height = toNumber(getCore():getScreenHeight(), height) or height
    end
    return { left = left, top = top, width = width, height = height }
end

-- Absolute world-to-screen projection, mirroring NLPlumbob. The observer index
-- keeps split-screen viewports independent and the caller clamps to the
-- matching player screen rectangle.
function NLConversationOverlay.screenAnchor(index, body)
    if not body or type(isoToScreenX) ~= "function" or type(isoToScreenY) ~= "function" then
        return nil
    end
    local worldX = body.getX and body:getX() or nil
    local worldY = body.getY and body:getY() or nil
    local worldZ = body.getZ and body:getZ() or 0
    if worldX == nil or worldY == nil then return nil end
    local okX, screenX = pcall(isoToScreenX, index, worldX, worldY, worldZ or 0)
    local okY, screenY = pcall(isoToScreenY, index, worldX, worldY, worldZ or 0)
    if not okX or not okY or screenX == nil or screenY == nil then return nil end
    return toNumber(screenX, 0) or 0, toNumber(screenY, 0) or 0
end

-- Deterministic cluster layout. The navigation bubble (More/Back) sits above
-- the action bubbles. Two columns flank the NPC when both sides fit; near a
-- screen edge the cluster becomes a single inward-shifted column and every
-- bubble is clamped inside the observer viewport.
function NLConversationOverlay.layoutCluster(anchor, bubbles, viewport)
    anchor = anchor or {}
    bubbles = bubbles or {}
    viewport = viewport or {}
    local anchorX = toNumber(anchor.x, 0) or 0
    local anchorY = toNumber(anchor.y, 0) or 0
    local vpLeft = toNumber(viewport.left, 0) or 0
    local vpTop = toNumber(viewport.top, 0) or 0
    local vpRight = vpLeft + (toNumber(viewport.width, 1280) or 1280)
    local vpBottom = vpTop + (toNumber(viewport.height, 720) or 720)

    local result = {}
    local nav = nil
    local navIndex = nil
    local actions = {}
    local actionIndexes = {}
    for index, bubble in ipairs(bubbles) do
        if bubble.navigation and not nav then
            nav = bubble
            navIndex = index
        else
            actions[#actions + 1] = bubble
            actionIndexes[#actionIndexes + 1] = index
        end
    end

    local rowHeight = LAYOUT_GAP
    local maxWidth = 0
    for _, bubble in ipairs(actions) do
        rowHeight = math.max(rowHeight, toNumber(bubble.height, 0) or 0)
        maxWidth = math.max(maxWidth, toNumber(bubble.width, 0) or 0)
    end
    rowHeight = rowHeight + LAYOUT_GAP

    local centerY = anchorY - 46
    local leftRoom = anchorX - vpLeft
    local rightRoom = vpRight - anchorX
    local paired = #actions > 1
        and leftRoom >= (LAYOUT_SIDE + maxWidth)
        and rightRoom >= (LAYOUT_SIDE + maxWidth)

    local function clampX(x, width)
        return clamp(x, vpLeft + LAYOUT_EDGE, vpRight - LAYOUT_EDGE - width)
    end
    local function clampY(y, height)
        return clamp(y, vpTop + LAYOUT_EDGE, vpBottom - LAYOUT_EDGE - height)
    end

    if paired then
        local rows = math.ceil(#actions / 2)
        local totalHeight = rows * rowHeight - LAYOUT_GAP
        local top = centerY - totalHeight / 2
        for position, bubble in ipairs(actions) do
            local row = math.floor((position - 1) / 2)
            local width = toNumber(bubble.width, 0) or 0
            local height = toNumber(bubble.height, 0) or 0
            local x = (position % 2 == 1)
                and (anchorX - LAYOUT_SIDE - width)
                or (anchorX + LAYOUT_SIDE)
            result[actionIndexes[position]] = {
                x = clampX(x, width),
                y = clampY(top + row * rowHeight, height),
            }
        end
        if nav then
            local width = toNumber(nav.width, 0) or 0
            result[navIndex] = {
                x = clampX(anchorX - width / 2, width),
                y = clampY(top - (toNumber(nav.height, 0) or 0) - LAYOUT_GAP, toNumber(nav.height, 0) or 0),
                navigation = true,
            }
        end
        return result
    end

    local rightSide = rightRoom >= leftRoom
    local count = #actions + (nav and 1 or 0)
    local y = centerY - (count * rowHeight - LAYOUT_GAP) / 2
    if nav then
        local width = toNumber(nav.width, 0) or 0
        local x = rightSide and (anchorX + LAYOUT_SIDE) or (anchorX - LAYOUT_SIDE - width)
        result[navIndex] = {
            x = clampX(x, width), y = clampY(y, toNumber(nav.height, 0) or 0), navigation = true,
        }
        y = y + (toNumber(nav.height, 0) or 0) + LAYOUT_GAP
    end
    for position, bubble in ipairs(actions) do
        local width = toNumber(bubble.width, 0) or 0
        local height = toNumber(bubble.height, 0) or 0
        local x = rightSide and (anchorX + LAYOUT_SIDE) or (anchorX - LAYOUT_SIDE - width)
        result[actionIndexes[position]] = { x = clampX(x, width), y = clampY(y, height) }
        y = y + height + LAYOUT_GAP
    end
    return result
end

local function destroyBubbles(overlay)
    for _, bubble in ipairs(overlay.bubbles or {}) do
        if bubble.removeFromUIManager then pcall(bubble.removeFromUIManager, bubble) end
    end
    overlay.bubbles = {}
    overlay.pageEntries = {}
end

local function rebuildBubbles(index)
    local overlay = NLConversationOverlay.overlays[index]
    if not overlay then return end
    local page = NLConversationOverlay.pageEntries(overlay)
    overlay.pageEntries = page
    for position, entry in ipairs(page) do
        local bubble = overlay.bubbles[position]
        if not bubble then
            local onClick = function() NLConversationOverlay.choose(index, entry) end
            bubble = NLConversationBubble:new(0, 0, entry.label, entry.kind, onClick)
            bubble.entry = entry
            bubble:setNavigation(entry.navigation == true)
            bubble:initialise()
            bubble:addToUIManager()
            overlay.bubbles[position] = bubble
        end
        bubble.entry = entry
    end
    for position = #page + 1, #overlay.bubbles do
        local bubble = overlay.bubbles[position]
        if bubble and bubble.removeFromUIManager then pcall(bubble.removeFromUIManager, bubble) end
        overlay.bubbles[position] = nil
    end
end

function NLConversationOverlay.refresh(index, force)
    local overlay = NLConversationOverlay.overlays[index]
    if not overlay then return false end
    local player = type(getSpecificPlayer) == "function" and getSpecificPlayer(index) or nil
    overlay.entries = NLConversationOverlay.availableActions(index, overlay.npcId, player)
    local page = NLConversationOverlay.pageEntries(overlay)
    local signature = NLConversationOverlay.signature(overlay.page, page)
    if not force and signature == overlay.signature then return false end
    overlay.signature = signature
    destroyBubbles(overlay)
    rebuildBubbles(index)
    NLConversationOverlay.position(index)
    return true
end

function NLConversationOverlay.position(index)
    local overlay = NLConversationOverlay.overlays[index]
    if not overlay or not overlay.body then return false end
    local anchorX, anchorY = NLConversationOverlay.screenAnchor(index, overlay.body)
    if anchorX == nil then return false end
    local sizes = {}
    for position, bubble in ipairs(overlay.bubbles) do
        sizes[position] = {
            width = bubble.getWidth and bubble:getWidth() or 0,
            height = bubble.getHeight and bubble:getHeight() or 0,
            navigation = bubble.navigation == true,
        }
    end
    local positions = NLConversationOverlay.layoutCluster(
        { x = anchorX, y = anchorY }, sizes, NLConversationOverlay.viewport(index))
    for position, bubble in ipairs(overlay.bubbles) do
        local point = positions[position]
        if point then
            bubble:setX(point.x)
            bubble:setY(point.y)
        end
    end
    return true
end

function NLConversationOverlay.isOpen(index)
    return NLConversationOverlay.overlays[index] ~= nil
end

function NLConversationOverlay.anyOpen()
    for _, _ in pairs(NLConversationOverlay.overlays) do return true end
    return false
end

function NLConversationOverlay.open(playerIndex, npcId, npcBody)
    if playerIndex == nil or npcId == nil then return nil end
    local player = type(getSpecificPlayer) == "function" and getSpecificPlayer(playerIndex) or nil
    if not player or (player.isDead and player:isDead()) then return nil end
    local id = tostring(npcId)
    local body = npcBody
    if not body and NLNpcInteractionMenu and NLNpcInteractionMenu.findBody then
        body = NLNpcInteractionMenu.findBody(id)
    end
    if not body then return nil end
    NLConversationOverlay.close(playerIndex)
    local overlay = {
        index = playerIndex,
        npcId = id,
        body = body,
        page = "primary",
        entries = {},
        pageEntries = {},
        bubbles = {},
        signature = nil,
        rebuildTimer = 0,
    }
    NLConversationOverlay.overlays[playerIndex] = overlay
    NLConversationOverlay.refresh(playerIndex, true)
    if NLSocialClient and NLSocialClient.request then
        NLSocialClient.request(playerIndex, "refresh")
    end
    return overlay
end

function NLConversationOverlay.close(index)
    local overlay = NLConversationOverlay.overlays[index]
    if not overlay then return end
    destroyBubbles(overlay)
    NLConversationOverlay.overlays[index] = nil
end

function NLConversationOverlay.closeAll()
    for index, _ in pairs(NLConversationOverlay.overlays) do
        NLConversationOverlay.close(index)
    end
end

local function setPage(index, page)
    local overlay = NLConversationOverlay.overlays[index]
    if not overlay then return end
    overlay.page = page
    NLConversationOverlay.refresh(index, true)
end

-- Navigation choices change pages without sending a social command. Only real
-- conversation choices reach the server-authoritative activation path.
function NLConversationOverlay.choose(index, entry)
    local overlay = NLConversationOverlay.overlays[index]
    if not overlay or not entry then return end
    if entry.action == "more" then
        setPage(index, "more")
        return
    end
    if entry.action == "back" then
        setPage(index, entry.targetPage or "primary")
        return
    end
    if entry.action == "category" then
        setPage(index, entry.targetPage or entry.category)
        return
    end
    local player = type(getSpecificPlayer) == "function" and getSpecificPlayer(index) or nil
    local npcId = overlay.npcId
    NLConversationOverlay.close(index)
    if player and npcId and NLNpcInteractionMenu and NLNpcInteractionMenu.activate then
        pcall(NLNpcInteractionMenu.activate, player, npcId, entry.action)
    end
end

function NLConversationOverlay.bodyValid(body)
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

function NLConversationOverlay.valid(index)
    local overlay = NLConversationOverlay.overlays[index]
    if not overlay then return false end
    local player = type(getSpecificPlayer) == "function" and getSpecificPlayer(index) or nil
    if not player or (player.isDead and player:isDead()) then return false end
    if not NLConversationOverlay.bodyValid(overlay.body) then return false end
    local dx = toNumber(player.getX and player:getX(), 0) - toNumber(overlay.body:getX(), 0)
    local dy = toNumber(player.getY and player:getY(), 0) - toNumber(overlay.body:getY(), 0)
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > NLConversationOverlay.INTERACT_RANGE then return false end
    if player.getZ and overlay.body.getZ
            and math.floor(player:getZ()) ~= math.floor(overlay.body:getZ()) then
        return false
    end
    if player.CanSee then
        local ok, canSee = pcall(player.CanSee, player, overlay.body)
        if ok and canSee == false then return false end
    end
    local npc = NLConversationOverlay.snapshot(index, overlay.npcId)
    if npc and (npc.dead == true or npc.available == false) then return false end
    return true
end

Events.OnTick.Add(function()
    for index, overlay in pairs(NLConversationOverlay.overlays) do
        if not NLConversationOverlay.valid(index) then
            NLConversationOverlay.close(index)
        else
            overlay.rebuildTimer = (overlay.rebuildTimer or 0) - 1
            if overlay.rebuildTimer <= 0 then
                overlay.rebuildTimer = NLConversationOverlay.REBUILD_TICKS
                NLConversationOverlay.refresh(index)
            end
        end
    end
end)

Events.OnRenderTick.Add(function()
    for index, _ in pairs(NLConversationOverlay.overlays) do
        NLConversationOverlay.position(index)
    end
end)

Events.OnMainMenuEnter.Add(NLConversationOverlay.closeAll)

if Events.OnDisconnect then
    Events.OnDisconnect.Add(NLConversationOverlay.closeAll)
end

if Events.OnKeyPressed then
    Events.OnKeyPressed.Add(function(key)
        if key == Keyboard.KEY_ESCAPE and NLConversationOverlay.anyOpen() then
            NLConversationOverlay.closeAll()
        end
    end)
end

return NLConversationOverlay
