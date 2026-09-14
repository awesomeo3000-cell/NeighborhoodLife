if isClient() then return end
require "NL/Social"
require "NL/Authority"
require "NL/Neighbors"
NLSocialAuthority={bodies={},lastRequest={}}

function NLSocialAuthority.broadcastEvent(actor,npcId,action,message)
    if not isServer() or type(getOnlinePlayers)~="function" then return 0 end
    local ok,players=pcall(getOnlinePlayers)
    if not ok or not players then return 0 end
    local person=NLSocial.people[npcId] or {}
    local packet={actor=NLAuthority.key(actor),npcId=npcId,
        npcName=person.name or tostring(npcId),action=action,message=message,
        revision=getTimestampMs()}
    local count=0
    for i=0,players:size()-1 do
        sendServerCommand(players:get(i),"NeighborhoodSocial","event",packet)
        count=count+1
    end
    return count
end

function NLSocialAuthority.register(id,body,home)
    if not NLSocial.people[id] or not body or not NLNeighbors.definitions[id] then return false end
    local world=NLAuthority.world()
    NLNeighbors.register(world,id,home)
    NLSocialAuthority.bodies[id]=body
    return true
end

local function validItemType(itemType)
    return type(itemType)=="string" and #itemType<=100
        and itemType:match("^[%w_%-]+%.[%w_%-]+$")~=nil
end

local function requestedAmount(args)
    local amount=math.floor(tonumber(args and args.amount) or 0)
    if amount<1 or amount>20 then return nil end
    return amount
end

local function mainInventoryItems(player,itemType,amount)
    local inventory=player:getInventory()
    local all=inventory and inventory:getItems()
    if not all then return nil,"Main inventory unavailable" end
    local chosen={}
    for i=0,all:size()-1 do
        local item=all:get(i)
        local equipped=false
        if player.isEquipped then
            local equippedOk,equippedValue=pcall(player.isEquipped,player,item)
            equipped=equippedOk and equippedValue==true
        end
        if item and item:getFullType()==itemType and not equipped then
            chosen[#chosen+1]=item
            if #chosen==amount then break end
        end
    end
    return chosen,inventory
end

local function itemLabel(item,itemType)
    if item and item.getDisplayName then
        local ok,label=pcall(item.getDisplayName,item)
        if ok and type(label)=="string" and label~="" then return label end
    end
    return itemType
end

local function rememberItem(row,itemType,item)
    row.inventoryMeta=row.inventoryMeta or {}
    row.inventoryMeta[itemType]={label=itemLabel(item,itemType)}
end

local function inventoryExchange(world,player,npcId,args,mode)
    local itemType=args and args.item
    local amount=requestedAmount(args)
    if not validItemType(itemType) then return false,"Use a valid item type such as Base.RippedSheets" end
    if not amount then return false,"Exchange amount must be between 1 and 20" end
    local row=NLNeighbors.get(world,npcId)
    row.inventory=row.inventory or {}
    if mode=="give" then
        local chosen,inventoryOrMessage=mainInventoryItems(player,itemType,amount)
        if not chosen then return false,inventoryOrMessage end
        if #chosen<amount then
            return false,"Need "..amount.." unequipped "..itemType.." in main inventory"
        end
        for _,item in ipairs(chosen) do
            inventoryOrMessage:Remove(item)
            if isServer() and sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(inventoryOrMessage,item)
            end
        end
        row.inventory[itemType]=(row.inventory[itemType] or 0)+amount
        rememberItem(row,itemType,chosen[1])
        row.revision=(row.revision or 0)+1
        return true,"Gave "..amount.." "..itemType.." to "..tostring(npcId).."."
    end

    local available=tonumber(row.inventory[itemType] or 0) or 0
    if available<amount then
        return false,"They have only "..available.." "..itemType
    end
    local inventory=player:getInventory()
    if not inventory or not inventory.AddItem then return false,"Main inventory unavailable" end
    local added={}
    for _=1,amount do
        local addOk,item=pcall(inventory.AddItem,inventory,itemType)
        if not addOk or not item then
            for _,restored in ipairs(added) do inventory:Remove(restored) end
            return false,"Main inventory could not accept "..itemType
        end
        added[#added+1]=item
        if isServer() and sendAddItemToContainer then
            sendAddItemToContainer(inventory,item)
        end
    end
    row.inventory[itemType]=available-amount
    if row.inventory[itemType]<=0 then
        row.inventory[itemType]=nil
        if row.inventoryMeta then row.inventoryMeta[itemType]=nil end
    end
    row.revision=(row.revision or 0)+1
    return true,"Received "..amount.." "..itemType.." from "..tostring(npcId).."."
end

-- Exposed for the deterministic authority contract; clients still reach this
-- path only through the server-gated give/request commands.
NLSocialAuthority.inventoryExchange=inventoryExchange

function NLSocialAuthority.snapshot(player,message)
    local world=NLAuthority.world()
    NLNeighbors.ensure(world)
    local profile=NLDomain.profile(world,NLAuthority.key(player))
    local result={username=NLAuthority.key(player),neighbors={},message=message or "Updated",revision=profile.revision}
    for _,id in ipairs(NLSocial.order) do
        local npc=NLNeighbors.get(world,id)
        if npc then
            local body=NLSocialAuthority.bodies[id]
            local row={id=id,name=NLSocial.people[id].name,personality=NLSocial.people[id].personality,
                age=NLSocial.people[id].age,dead=npc.dead or npc.alive==false,available=body~=nil,canInteract=false,
                inventory=NLDomain.copy(npc.inventory or {}),
                inventoryItems=NLDomain.copy(NLNeighbors.inventoryEntries(world,id)),
                relation=NLDomain.copy(NLSocial.relation(profile,id))}
            if body then
                if body:isDead() then NLNeighbors.dead(world,id) end
                row.dead=npc.dead or npc.alive==false
                row.distance=math.sqrt((body:getX()-player:getX())^2+(body:getY()-player:getY())^2)
                row.sameFloor=math.floor(body:getZ())==math.floor(player:getZ())
                row.canInteract=not row.dead and not player:isDead() and row.sameFloor
                    and row.distance<=4 and player:CanSee(body)
            end
            result.neighbors[#result.neighbors+1]=row
        end
    end
    if isServer() then sendServerCommand(player,"NeighborhoodSocial","snapshot",result)
    elseif NLSocialClient then NLSocialClient.receive("NeighborhoodSocial","snapshot",result) end
end

function NLSocialAuthority.command(module,command,player,args)
    if module~="NeighborhoodSocial" or not player or player:isDead() then return end
    if type(args)~="table" then args={} end
    if command~="refresh" and command~="interact" and command~="give" and command~="request" then return end
    local key=NLAuthority.key(player); local now=getTimestampMs()
    if NLQAMultiplayerServer then
        print("NLQA SOCIAL COMMAND: "..tostring(command).." username="..tostring(key)
            .." id="..tostring(args.id).." action="..tostring(args.action))
    end
    if NLSocialAuthority.lastRequest[key] and now-NLSocialAuthority.lastRequest[key]<200 then return end
    NLSocialAuthority.lastRequest[key]=now
    local message="Updated"
    local completed=command~="interact"
    if command=="interact" then
        local npc=(NLAuthority.world().neighbors or {})[args.id]
        local body=NLSocialAuthority.bodies[args.id]
        if not npc or not body then message="This neighbor is not nearby."
                elseif body:isDead() then NLNeighbors.dead(NLAuthority.world(),args.id); message="This neighbor has died."
        elseif math.floor(body:getZ())~=math.floor(player:getZ())
            or (body:getX()-player:getX())^2+(body:getY()-player:getY())^2>16 then
            message="Move within four tiles on the same floor."
        elseif not player:CanSee(body) then message="You need a clear line of sight."
        else
            local profile=NLDomain.profile(NLAuthority.world(),key)
            local ok
            ok,message=NLSocial.interact(profile,npc,args.action,getGameTime():getWorldAgeHours(),key)
            completed=ok==true
            if not completed then message="Not completed: "..message end
        end
    elseif command=="give" or command=="request" then
        local world=NLAuthority.world()
        local npc=(world.neighbors or {})[args.id]
        local body=NLSocialAuthority.bodies[args.id]
        if not npc or not body then message="This neighbor is not nearby."
        elseif body:isDead() then NLNeighbors.dead(world,args.id); message="This neighbor has died."
        elseif math.floor(body:getZ())~=math.floor(player:getZ())
            or (body:getX()-player:getX())^2+(body:getY()-player:getY())^2>16 then
            message="Move within four tiles on the same floor."
        elseif not player:CanSee(body) then message="You need a clear line of sight."
        else
            completed,message=inventoryExchange(world,player,args.id,args,command)
            if not completed then message="Not completed: "..message end
        end
    end
    NLSocialAuthority.snapshot(player,message)
    if completed and (command=="interact" or command=="give" or command=="request") then
        NLSocialAuthority.broadcastEvent(player,args.id,command,message)
    end
    if NLQAMultiplayerServer and command=="interact" then
        print("NLQA SOCIAL RESULT: username="..tostring(key).." message="..tostring(message))
    end
end
Events.OnClientCommand.Add(NLSocialAuthority.command)
Events.OnMainMenuEnter.Add(function() NLSocialAuthority.bodies={}; NLSocialAuthority.lastRequest={} end)
return NLSocialAuthority
