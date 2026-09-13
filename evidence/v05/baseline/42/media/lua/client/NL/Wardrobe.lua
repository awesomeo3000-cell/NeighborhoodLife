require "TimedActions/ISWearClothing"
require "TimedActions/ISTimedActionQueue"
NLWardrobe = {}

function NLWardrobe.save(player, slot)
    local outfits = player:getModData().NeighborhoodOutfits or {}
    local items, saved = player:getWornItems(), {}
    for i=0,items:size()-1 do
        saved[#saved+1] = items:get(i):getItem():getFullType()
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
    for _,fullType in ipairs(saved) do
        local match = nil
        for i=0,inventory:size()-1 do
            local item=inventory:get(i)
            if not used[item] and item:getFullType()==fullType then match=item; break end
        end
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
