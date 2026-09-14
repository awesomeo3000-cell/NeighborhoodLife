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

local function mainInventoryCount(player,itemType)
    local inventory=player and player.getInventory and player:getInventory()
    local all=inventory and inventory.getItems and inventory:getItems()
    if not all then return 0 end
    local count=0
    for i=0,all:size()-1 do
        local item=all:get(i)
        local equipped=false
        if item and player.isEquipped then
            local equippedOk,equippedValue=pcall(player.isEquipped,player,item)
            equipped=equippedOk and equippedValue==true
        end
        if item and item.getFullType and item:getFullType()==itemType and not equipped then
            count=count+1
        end
    end
    return count
end

local function setJournal(world,journal)
    world.inventoryJournal=journal
    return journal
end

local function clearJournal(world)
    world.inventoryJournal=nil
end

local function journalBefore(world,player,row,npcId,itemType,amount,mode)
    return setJournal(world,{
        version=1, state="prepared", mode=mode,
        player=NLAuthority.key(player), npcId=npcId, itemType=itemType, amount=amount,
        npcBefore=tonumber(row.inventory[itemType] or 0) or 0,
        playerBefore=mainInventoryCount(player,itemType),
        npcRevisionBefore=tonumber(row.revision or 0) or 0,
        inventoryMetaBefore=NLDomain.copy(row.inventoryMeta and row.inventoryMeta[itemType] or nil),
    })
end

local function changeMainInventoryCount(player,itemType,target)
    local current=mainInventoryCount(player,itemType)
    local inventory=player and player.getInventory and player:getInventory()
    if not inventory then return false end
    if current<target and inventory.AddItem then
        for _=current+1,target do
            local ok,item=pcall(inventory.AddItem,inventory,itemType)
            if not ok or not item then return false end
        end
    elseif current>target then
        local chosen=mainInventoryItems(player,itemType,current-target)
        if not chosen or #chosen<current-target then return false end
        for _,item in ipairs(chosen) do inventory:Remove(item) end
    end
    return mainInventoryCount(player,itemType)==target
end

-- Inventory mutations cross two persisted owners: the player's vanilla save and
-- the world's NPC ModData. The journal makes an interrupted exchange
-- recoverable instead of silently accepting a half-applied row.
function NLSocialAuthority.recoverInventoryJournal(world,player)
    local journal=world and world.inventoryJournal
    if type(journal)~="table" then return true,"none" end
    if not player or NLAuthority.key(player)~=journal.player then
        return false,"Inventory transaction belongs to another account" end
    local row=NLNeighbors.get(world,journal.npcId)
    local currentNpc=tonumber(row.inventory[journal.itemType] or 0) or 0
    local currentPlayer=mainInventoryCount(player,journal.itemType)
    local npcExpected=journal.mode=="give"
        and journal.npcBefore+journal.amount or journal.npcBefore-journal.amount
    local playerExpected=journal.mode=="give"
        and journal.playerBefore-journal.amount or journal.playerBefore+journal.amount
    if currentNpc==npcExpected and currentPlayer==playerExpected then
        clearJournal(world)
        NLSocialAuthority.lastRecoveryState="completed"
        return true,"completed"
    end
    if currentNpc==journal.npcBefore and currentPlayer==journal.playerBefore then
        clearJournal(world)
        NLSocialAuthority.lastRecoveryState="rolled-back"
        return true,"rolled-back"
    end
    -- A partial exchange is restored to the recorded pre-transaction counts.
    -- If a live inventory cannot accept the repair, keep the journal for the
    -- next login rather than discarding evidence of the unfinished mutation.
    if not changeMainInventoryCount(player,journal.itemType,journal.playerBefore) then
        return false,"Inventory transaction still needs repair" end
    if journal.npcBefore>0 then
        row.inventory[journal.itemType]=journal.npcBefore
        row.inventoryMeta=row.inventoryMeta or {}
        row.inventoryMeta[journal.itemType]=NLDomain.copy(journal.inventoryMetaBefore
            or {label=journal.itemType})
    else
        row.inventory[journal.itemType]=nil
        if row.inventoryMeta then row.inventoryMeta[journal.itemType]=nil end
    end
    row.revision=journal.npcRevisionBefore
    clearJournal(world)
    NLSocialAuthority.lastRecoveryState="repaired"
    return true,"repaired"
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
    local journal=journalBefore(world,player,row,npcId,itemType,amount,mode)
    if mode=="give" then
        local chosen,inventoryOrMessage=mainInventoryItems(player,itemType,amount)
        if not chosen then clearJournal(world); return false,inventoryOrMessage end
        if #chosen<amount then
            clearJournal(world)
            return false,"Need "..amount.." unequipped "..itemType.." in main inventory"
        end
        for _,item in ipairs(chosen) do
            inventoryOrMessage:Remove(item)
            if isServer() and sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(inventoryOrMessage,item)
            end
        end
        journal.state="player-applied"
        if NLSocialAuthority.testFaultPhase=="player-applied" then
            NLSocialAuthority.testFaultPhase=nil
            if NLQAMultiplayerServer then
                print("NLQA INVENTORY JOURNAL PARTIAL: phase=player-applied npc="
                    ..tostring(npcId).." item="..tostring(itemType)
                    .." amount="..tostring(amount))
            end
            return false,"QA forced partial inventory transaction"
        end
        row.inventory[itemType]=(row.inventory[itemType] or 0)+amount
        rememberItem(row,itemType,chosen[1])
        row.revision=(row.revision or 0)+1
        journal.state="world-applied"
        clearJournal(world)
        return true,"Gave "..amount.." "..itemType.." to "..tostring(npcId).."."
    end

    local available=tonumber(row.inventory[itemType] or 0) or 0
    if available<amount then
        clearJournal(world)
        return false,"They have only "..available.." "..itemType
    end
    local inventory=player:getInventory()
    if not inventory or not inventory.AddItem then
        clearJournal(world)
        return false,"Main inventory unavailable"
    end
    local added={}
    for _=1,amount do
        local addOk,item=pcall(inventory.AddItem,inventory,itemType)
        if not addOk or not item then
            for _,restored in ipairs(added) do inventory:Remove(restored) end
            clearJournal(world)
            return false,"Main inventory could not accept "..itemType
        end
        added[#added+1]=item
        if isServer() and sendAddItemToContainer then
            sendAddItemToContainer(inventory,item)
        end
    end
    journal.state="player-applied"
    row.inventory[itemType]=available-amount
    if row.inventory[itemType]<=0 then
        row.inventory[itemType]=nil
        if row.inventoryMeta then row.inventoryMeta[itemType]=nil end
    end
    row.revision=(row.revision or 0)+1
    journal.state="world-applied"
    clearJournal(world)
    return true,"Received "..amount.." "..itemType.." from "..tostring(npcId).."."
end

-- Exposed for the deterministic authority contract; clients still reach this
-- path only through the server-gated give/request commands.
NLSocialAuthority.inventoryExchange=inventoryExchange

function NLSocialAuthority.snapshot(player,message)
    local world=NLAuthority.world()
    NLNeighbors.ensure(world)
    local key=NLAuthority.key(player)
    local profile=NLDomain.profile(world,key)
    local result={username=NLAuthority.key(player),neighbors={},message=message or "Updated",revision=profile.revision}
    for _,id in ipairs(NLSocial.order) do
        local npc=NLNeighbors.get(world,id)
        if npc then
            local body=NLSocialAuthority.bodies[id]
            local relation=NLDomain.copy(NLSocial.relation(profile,id))
            local exclusive=npc.partner~=nil
            if npc.partner==key then
                relation.status="Partner"
            elseif exclusive then
                -- Replicate availability without exposing the other player's
                -- account key through a private relationship snapshot.
                relation.status="Unavailable"
            end
            local row={id=id,name=NLSocial.people[id].name,personality=NLSocial.people[id].personality,
                age=NLSocial.people[id].age,dead=npc.dead or npc.alive==false,available=body~=nil,canInteract=false,
                inventory=NLDomain.copy(npc.inventory or {}),
                inventoryItems=NLDomain.copy(NLNeighbors.inventoryEntries(world,id)),
                relation=relation, exclusive=exclusive, isPartner=npc.partner==key}
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
    -- Refresh is read-only and may follow a cross-client event immediately;
    -- only mutating social commands use the anti-spam window.
    if command~="refresh" and NLSocialAuthority.lastRequest[key]
            and now-NLSocialAuthority.lastRequest[key]<200 then return end
    if command~="refresh" then NLSocialAuthority.lastRequest[key]=now end
    local world=NLAuthority.world()
    local recovered,recoveryState=NLSocialAuthority.recoverInventoryJournal(world,player)
    if not recovered then
        NLSocialAuthority.snapshot(player,"Inventory recovery pending: "..tostring(recoveryState))
        return
    end
    if recoveryState=="repaired" or recoveryState=="completed" or recoveryState=="rolled-back" then
        if NLQAMultiplayerServer then
            print("NLQA INVENTORY JOURNAL RECOVERY: state="..tostring(recoveryState)
                .." player="..tostring(key))
        end
    end
    local message="Updated"
    if recoveryState=="repaired" then message="Inventory recovery repaired" end
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
        local eventAction=command
        if command=="interact" then eventAction=args.action end
        NLSocialAuthority.broadcastEvent(player,args.id,eventAction,message)
    end
    if NLQAMultiplayerServer and command=="interact" then
        print("NLQA SOCIAL RESULT: username="..tostring(key).." message="..tostring(message))
    end
end
Events.OnClientCommand.Add(NLSocialAuthority.command)
Events.OnMainMenuEnter.Add(function() NLSocialAuthority.bodies={}; NLSocialAuthority.lastRequest={} end)
return NLSocialAuthority
