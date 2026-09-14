require "TimedActions/ISWearClothing"
require "TimedActions/ISUnequipAction"
require "TimedActions/ISTimedActionQueue"
NLWardrobe = {}

function NLWardrobe.applyProfile(player, outfits)
    if not player or type(outfits) ~= "table" then return end
    player:getModData().NeighborhoodOutfits = outfits
end

function NLWardrobe.save(player, slot)
    local outfits = player:getModData().NeighborhoodOutfits or {}
    local items, saved = player:getWornItems(), {}
    for i=0,items:size()-1 do
        local item=items:get(i):getItem()
        saved[#saved+1] = {fullType=item:getFullType(),itemId=item:getID()}
    end
    outfits[slot] = saved
    player:getModData().NeighborhoodOutfits = outfits
    player:Say("Outfit "..slot.." saved ("..#saved.." pieces).")
end

local function entryDetails(entry)
    if type(entry) == "table" then
        return entry.fullType, entry.itemId
    end
    return entry, nil
end

local function wornItems(player)
    local items = player:getWornItems()
    local result = {}
    for i=0,items:size()-1 do
        local worn = items:get(i)
        local item = worn and worn:getItem()
        if item then result[#result+1] = item end
    end
    return result
end

local function matchesEntry(item, entry)
    local fullType, itemId = entryDetails(entry)
    if not item or item:getFullType() ~= fullType then return false end
    return itemId == nil or item:getID() == itemId
end

function NLWardrobe.wear(player, slot)
    local outfits = player:getModData().NeighborhoodOutfits or {}
    local saved = outfits[slot]
    if not saved then player:Say("Save this outfit slot first."); return end
    local missing,used,retained,retainedEntry,worn = 0,{}, {}, {}, wornItems(player)
    -- A saved outfit is a replacement preset. Keep one currently worn item for
    -- each saved layer, then remove every unrelated layer before wearing the
    -- saved inventory items. Matching by item id preserves exact variants;
    -- legacy string entries continue to match by full type.
    for savedIndex,entry in ipairs(saved) do
        local exact, fallback = nil, nil
        for _,item in ipairs(worn) do
            if not retained[item] and matchesEntry(item, entry) then
                local _, itemId = entryDetails(entry)
                fallback = fallback or item
                if itemId ~= nil and item:getID() == itemId then exact=item; break end
            end
        end
        local match = exact or fallback
        if match then
            retained[match]=true
            used[match]=true
            retainedEntry[savedIndex]=true
        end
    end
    for _,item in ipairs(worn) do
        if not retained[item] then
            ISTimedActionQueue.add(ISUnequipAction:new(player,item,50))
        end
    end
    local inventory = player:getInventory():getItems()
    for savedIndex,entry in ipairs(saved) do
        if not retainedEntry[savedIndex] then
            -- Old presets stored strings. New presets keep the garment identity,
            -- preserving the chosen color/pattern when several pieces share a type.
            local fullType,itemId=entryDetails(entry)
            local match,fallback = nil,nil
            for i=0,inventory:size()-1 do
                local item=inventory:get(i)
                if not used[item] and item:getFullType()==fullType and not retained[item] then
                    fallback=fallback or item
                    if itemId~=nil and item:getID()==itemId then match=item; break end
                end
            end
            match=match or fallback
            if match then
                used[match]=true
                ISTimedActionQueue.add(ISWearClothing:new(player,match))
            else missing=missing+1 end
        end
    end
    if missing>0 then player:Say(missing.." outfit pieces missing from main inventory.") end
end

function NLWardrobe.requestSave(player, slot)
    if not player then return end
    if NLClient and NLClient.request then
        NLClient.request(player:getPlayerNum(), "wardrobe_save", { slot = slot })
    else
        NLWardrobe.save(player, slot)
    end
end

function NLWardrobe.menu(index, context)
    local player=getSpecificPlayer(index)
    if not player or player:isDead() then return end
    local option=context:addOption("Neighborhood wardrobe")
    local sub=ISContextMenu:getNew(context)
    context:addSubMenu(option,sub)
    for slot=1,3 do
        sub:addOption("Save current outfit "..slot,player,NLWardrobe.requestSave,slot)
        sub:addOption("Wear saved outfit "..slot,player,NLWardrobe.wear,slot)
    end
end
Events.OnFillWorldObjectContextMenu.Add(NLWardrobe.menu)
return NLWardrobe
