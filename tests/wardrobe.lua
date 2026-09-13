package.path=arg[1]..'/42/media/lua/client/?.lua;'..package.path
package.preload['TimedActions/ISWearClothing']=function() end
package.preload['TimedActions/ISTimedActionQueue']=function() end
Events={OnFillWorldObjectContextMenu={Add=function() end}}
local queued={}
ISWearClothing={new=function(_,p,item) return {player=p,item=item} end}
ISTimedActionQueue={add=function(action) queued[#queued+1]=action end}
local function list(items) return {size=function() return #items end,get=function(_,i) return items[i+1] end} end
local nextId=0
local function item(t)
    nextId=nextId+1; local id=nextId
    return {getFullType=function() return t end,getID=function() return id end}
end
local shirt,hat=item('Base.Shirt'),item('Base.Hat')
local data={}; local p={}
function p:getModData() return data end
function p:getWornItems() return list({{getItem=function() return shirt end},{getItem=function() return hat end}}) end
function p:getInventory() return {getItems=function() return list({shirt}) end} end
function p:Say(text) self.lastText=text end
require 'NL/Wardrobe'
NLWardrobe.save(p,1); assert(#data.NeighborhoodOutfits[1]==2)
NLWardrobe.wear(p,1); assert(#queued==1 and queued[1].item==shirt and queued[1].player==p)
assert(string.find(p.lastText,'1 outfit pieces missing',1,true))
NLWardrobe.wear(p,2); assert(#queued==1 and p.lastText=='Save this outfit slot first.')
local entry=data.NeighborhoodOutfits[1][2]
assert(entry=='Base.Hat' or entry.fullType=='Base.Hat')
if type(entry)=='table' then
    local otherShirt=item('Base.Shirt')
    function p:getInventory() return {getItems=function() return list({otherShirt,shirt}) end} end
    NLWardrobe.wear(p,1); assert(queued[#queued].item==shirt,'exact garment wins over first same-type item')
    function p:getInventory() return {getItems=function() return list({otherShirt}) end} end
    NLWardrobe.wear(p,1); assert(queued[#queued].item==otherShirt,'replacement type fallback')
    data.NeighborhoodOutfits[2]={'Base.Shirt'}
    NLWardrobe.wear(p,2); assert(queued[#queued].item==otherShirt,'legacy preset migration')
    data.NeighborhoodOutfits[3]={{fullType='Base.Shirt',itemId=999},{fullType='Base.Shirt',itemId=998}}
    local before=#queued; NLWardrobe.wear(p,3)
    assert(#queued==before+1,'one garment never queued twice')
    print('PASS: exact garment identity, replacement fallback, legacy presets and duplicate exclusion')
end
print('PASS: wardrobe save, vanilla wear action queue, missing pieces and empty slot')
