package.path=arg[1]..'/42/media/lua/client/?.lua;'..package.path
package.preload['TimedActions/ISWearClothing']=function() end
package.preload['TimedActions/ISUnequipAction']=function() end
package.preload['TimedActions/ISTimedActionQueue']=function() end
Events={OnFillWorldObjectContextMenu={Add=function() end}}
local queued={}
ISWearClothing={new=function(_,p,item) return {player=p,item=item,kind='wear'} end}
ISUnequipAction={new=function(_,p,item,duration) return {player=p,item=item,duration=duration,kind='unequip'} end}
ISTimedActionQueue={add=function(action) queued[#queued+1]=action end}
local function list(items) return {size=function() return #items end,get=function(_,i) return items[i+1] end} end
local nextId=0
local function item(t)
    nextId=nextId+1; local id=nextId
    return {getFullType=function() return t end,getID=function() return id end}
end
local shirt,hat=item('Base.Shirt'),item('Base.Hat')
local jacket=item('Base.Jacket')
local data={}; local p={}
function p:getModData() return data end
function p:getWornItems() return list({{getItem=function() return shirt end},{getItem=function() return hat end}}) end
function p:getInventory() return {getItems=function() return list({shirt,hat}) end} end
function p:Say(text) self.lastText=text end
require 'NL/Wardrobe'
NLWardrobe.save(p,1); assert(#data.NeighborhoodOutfits[1]==2)
function p:getWornItems() return list({{getItem=function() return shirt end},{getItem=function() return jacket end}}) end
NLWardrobe.wear(p,1); assert(#queued==2 and queued[1].kind=='unequip' and queued[1].item==jacket)
assert(queued[2].kind=='wear' and queued[2].item==hat and queued[2].player==p)
assert(not p.lastText or not string.find(p.lastText,'outfit pieces missing',1,true))
NLWardrobe.wear(p,2); assert(#queued==2 and p.lastText=='Save this outfit slot first.')
local entry=data.NeighborhoodOutfits[1][2]
assert(entry=='Base.Hat' or entry.fullType=='Base.Hat')
if type(entry)=='table' then
    local otherShirt=item('Base.Shirt')
    function p:getWornItems() return list({{getItem=function() return jacket end}}) end
    function p:getInventory() return {getItems=function() return list({otherShirt,shirt,hat}) end} end
    local before=#queued; NLWardrobe.wear(p,1)
    local exactFound=false
    for i=before+1,#queued do if queued[i].kind=='wear' and queued[i].item==shirt then exactFound=true end end
    assert(exactFound,'exact garment wins over first same-type item')
    function p:getInventory() return {getItems=function() return list({otherShirt,hat}) end} end
    before=#queued; NLWardrobe.wear(p,1)
    local fallbackFound=false
    for i=before+1,#queued do if queued[i].kind=='wear' and queued[i].item==otherShirt then fallbackFound=true end end
    assert(fallbackFound,'replacement type fallback')
    data.NeighborhoodOutfits[2]={'Base.Shirt'}
    function p:getInventory() return {getItems=function() return list({otherShirt}) end} end
    NLWardrobe.wear(p,2); assert(queued[#queued].item==otherShirt,'legacy preset migration')
    data.NeighborhoodOutfits[3]={{fullType='Base.Shirt',itemId=999},{fullType='Base.Shirt',itemId=998}}
    before=#queued; NLWardrobe.wear(p,3)
    assert(#queued==before+2,'one garment never queued twice')
    assert(queued[#queued-1].kind=='unequip' and queued[#queued].kind=='wear')
    data.NeighborhoodOutfits[4]={'Base.Shirt','Base.Shirt'}
    before=#queued; NLWardrobe.wear(p,4)
    assert(#queued==before+2,'duplicate legacy strings never collapse into one retained layer')
    print('PASS: exact garment identity, replacement removal, fallback, legacy presets and duplicate exclusion')
end
print('PASS: wardrobe save, replacement unequip/wear queue, missing pieces and empty slot')
