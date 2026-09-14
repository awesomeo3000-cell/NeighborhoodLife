require "TimedActions/ISWearClothing"
require "TimedActions/ISTimedActionQueue"
NLWardrobe = {}

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

function NLWardrobe.wear(player, slot)
    local outfits = player:getModData().NeighborhoodOutfits or {}
    local saved = outfits[slot]
    if not saved then player:Say("Save this outfit slot first."); return end
    local missing,used = 0,{}
    local inventory = player:getInventory():getItems()
    for _,entry in ipairs(saved) do
        -- Old presets stored strings. New presets keep the garment identity,
        -- preserving the chosen color/pattern when several pieces share a type.
        local fullType=type(entry)=="table" and entry.fullType or entry
        local itemId=type(entry)=="table" and entry.itemId or nil
        local match,fallback = nil,nil
        for i=0,inventory:size()-1 do
            local item=inventory:get(i)
            if not used[item] and item:getFullType()==fullType then
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
    if missing>0 then player:Say(missing.." outfit pieces missing from main inventory.") end
end

function NLWardrobe.menu(index, context)
    local player=getSpecificPlayer(index)
    if not player or player:isDead() then return end
    local option=context:addOption("Neighborhood wardrobe")
    local sub=ISContextMenu:getNew(context)
    context:addSubMenu(option,sub)
    for slot=1,3 do
        sub:addOption("Save current outfit "..slot,player,NLWardrobe.save,slot)
        sub:addOption("Wear saved outfit "..slot,player,NLWardrobe.wear,slot)
    end
end
Events.OnFillWorldObjectContextMenu.Add(NLWardrobe.menu)
return NLWardrobe
