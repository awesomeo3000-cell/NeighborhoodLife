package.path=arg[1]..'/42/media/lua/shared/?.lua;'..arg[1]..'/42/media/lua/server/?.lua;'..package.path
local now=0
function isClient() return false end
function isServer() return true end
function getTimestampMs() now=now+500; return now end
function getGameTime() return {getWorldAgeHours=function() return now/1000 end} end
Events={OnClientCommand={Add=function() end},OnMainMenuEnter={Add=function() end}}
local world={}
ModData={getOrCreate=function() return world end}
local last
function sendServerCommand(p,m,c,args) last={player=p,args=args} end
require 'NL/SocialAuthority'
local function actor(name,x,y,z)
    local a={name=name,x=x,y=y,z=z,dead=false,visible=true}
    function a:getUsername() return self.name end
    function a:getPlayerNum() return 0 end
    function a:getX() return self.x end
    function a:getY() return self.y end
    function a:getZ() return self.z end
    function a:isDead() return self.dead end
    function a:CanSee() return self.visible end
    local function makeItem(itemType)
        return {fullType=itemType,getFullType=function(self) return self.fullType end,
            getDisplayName=function(self) return self.fullType=='Base.Hammer' and 'Hammer' or 'Ripped Sheets' end}
    end
    local items={makeItem('Base.RippedSheets'),makeItem('Base.RippedSheets'),makeItem('Base.Hammer')}
    local inventory={}
    function inventory:getItems()
        return {size=function() return #items end,get=function(_,i) return items[i+1] end}
    end
    function inventory:Remove(item)
        for i,value in ipairs(items) do if value==item then table.remove(items,i); return end end
    end
    function inventory:AddItem(itemType)
        local item=makeItem(itemType); items[#items+1]=item; return item
    end
    function a:getInventory() return inventory end
    function a:isEquipped() return false end
    function a:itemCount(itemType)
        local count=0; for _,item in ipairs(items) do if item.fullType==itemType then count=count+1 end end
        return count
    end
    return a
end
local p=actor('host',0,0,0); local q=actor('guest',0,0,0); local body=actor('npc',1,0,0)
local n=0
local function check(v,s) assert(v,s); n=n+1 end
local function cmd(player,action)
    NLSocialAuthority.command('NeighborhoodSocial','interact',player,{id='marisol',action=action})
end
check(NLSocialAuthority.register('marisol',body,{x=1,y=0,z=0}),'register engine body')
check(not NLSocialAuthority.register('fake',body,{}),'unknown id rejected')
cmd(p,'introduce')
check(last.args.neighbors[1].canInteract==true,'nearby snapshot enables interaction')
check(last.player==p and last.args.neighbors[1].relation.met,'targeted introduction snapshot')
cmd(q,'introduce')
check(last.player==q and last.args.neighbors[1].relation.met,'separate guest introduction')
local profile=NLDomain.profile(world,'host'); local r=NLSocial.relation(profile,'marisol'); local before=r.friendship
body.x=8; cmd(p,'chat'); check(r.friendship==before,'distance gate')
check(last.args.neighbors[1].canInteract==false,'distant snapshot disables interaction')
body.x=1; body.z=1; cmd(p,'chat'); check(r.friendship==before,'floor gate')
check(last.args.neighbors[1].canInteract==false,'different floor disables interaction')
body.z=0; p.visible=false; cmd(p,'chat'); check(r.friendship==before,'line of sight gate')
check(last.args.neighbors[1].canInteract==false,'occluded snapshot disables interaction')
p.visible=true; cmd(p,'chat'); check(r.friendship>before,'near visible conversation')
local sheetsBefore=p:itemCount('Base.RippedSheets')
if NLSocialAuthority.inventoryExchange then
    NLSocialAuthority.command('NeighborhoodSocial','give',p,{id='marisol',item='Base.RippedSheets',amount=1})
    check(p:itemCount('Base.RippedSheets')==sheetsBefore-1,'give removes one unequipped item from player inventory')
    check((world.neighbors.marisol.inventory['Base.RippedSheets'] or 0)==1,
        'give persists one item in the NPC inventory')
    check(last.args.neighbors[1].inventory['Base.RippedSheets']==1,
        'snapshot exposes authoritative NPC inventory state')
    NLSocialAuthority.command('NeighborhoodSocial','request',p,{id='marisol',item='Base.RippedSheets',amount=1})
    check(p:itemCount('Base.RippedSheets')==sheetsBefore,'request returns the stored item to the player')
    check(world.neighbors.marisol.inventory['Base.RippedSheets']==nil,
        'request decrements the authoritative NPC inventory')
    if last.args.neighbors[1].inventoryItems then
        local hammerBefore=p:itemCount('Base.Hammer')
        NLSocialAuthority.command('NeighborhoodSocial','give',p,{id='marisol',item='Base.Hammer',amount=1})
        check(p:itemCount('Base.Hammer')==hammerBefore-1,'give accepts a second item type')
        check(last.args.neighbors[1].inventoryItems[1].label=='Hammer',
            'snapshot includes stable display metadata for stored items')
        check(last.args.neighbors[1].inventoryItems[1].item=='Base.Hammer',
            'snapshot includes the stored item full type')
        NLSocialAuthority.command('NeighborhoodSocial','request',p,{id='marisol',item='Base.Hammer',amount=1})
        check(p:itemCount('Base.Hammer')==hammerBefore,'request restores the selected item type')
        world.neighbors.marisol.inventory['bad']=-3
        NLNeighbors.get(world,'marisol')
        check(world.neighbors.marisol.inventory['bad']==nil,'malformed saved inventory entries are normalized away')
    end
end
if NLSocialAuthority.recoverInventoryJournal then
    local repairCount=p:itemCount('Base.Hammer')
    local row=world.neighbors.marisol
    row.inventory={['Base.Hammer']=1}; row.inventoryMeta={['Base.Hammer']={label='Hammer'}}; row.revision=41
    world.inventoryJournal={version=1,state='world-applied',mode='give',player='host',npcId='marisol',
        itemType='Base.Hammer',amount=1,npcBefore=0,playerBefore=repairCount,
        npcRevisionBefore=40,inventoryMetaBefore=nil}
    check(NLSocialAuthority.recoverInventoryJournal(world,p),'partial world-side exchange repaired')
    check((row.inventory['Base.Hammer'] or 0)==0 and p:itemCount('Base.Hammer')==repairCount,
        'partial exchange restores both owners to the recorded pre-state')
    world.inventoryJournal={version=1,state='player-applied',mode='request',player='host',npcId='marisol',
        itemType='Base.RippedSheets',amount=1,npcBefore=2,playerBefore=p:itemCount('Base.RippedSheets'),
        npcRevisionBefore=row.revision,inventoryMetaBefore={label='Ripped Sheets'}}
    row.inventory={['Base.RippedSheets']=1}; row.inventoryMeta={['Base.RippedSheets']={label='Ripped Sheets'}}
    check(NLSocialAuthority.recoverInventoryJournal(world,p),'partial player-side exchange repaired')
    check((row.inventory['Base.RippedSheets'] or 0)==2,'request repair restores NPC inventory count')
    check(world.inventoryJournal==nil,'repaired transaction journal is cleared')
end
before=r.friendship; p.dead=true; cmd(p,'chat'); check(r.friendship==before,'dead player rejected'); p.dead=false
body.dead=true; cmd(p,'chat'); check(world.neighbors.marisol.dead and r.friendship==before,'dead NPC persisted and rejected')
last.args.neighbors[1].relation.friendship=999
check(r.friendship~=999,'snapshot cannot mutate authority')
NLSocialAuthority.bodies={}; cmd(p,'chat'); check(r.friendship==before,'unloaded body rejected')
print('PASS: '..n..' social authority assertions (proximity, visibility, private snapshots, death and absent bodies)')
