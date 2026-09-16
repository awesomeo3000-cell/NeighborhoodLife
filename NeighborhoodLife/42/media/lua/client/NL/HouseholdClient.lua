NLHouseholdClient={snapshots={}}

local function loadOptional(name)
    local ok,result=pcall(require,name)
    if not ok then print("[NeighborhoodLife] Failed to load "..tostring(name)..": "..tostring(result)) end
    return ok,result
end

loadOptional("NL/HouseholdFurnishingClient")

function NLHouseholdClient.receive(module,command,args)
    if module~="NeighborhoodHousehold" or type(args)~="table" then return end
    if command=="invite" then
        for i=0,getNumActivePlayers()-1 do
            local player=getSpecificPlayer(i)
            if player then
                local key=player:getUsername()
                if not key or key=="" then key="local:"..i end
                local old=NLHouseholdClient.snapshots[i] or {username=key,householdRevision=0}
                old.invite=args; old.message="Household invitation received"; NLHouseholdClient.snapshots[i]=old
            end
        end
        return
    end
    if command~="snapshot" then return end
    for i=0,getNumActivePlayers()-1 do
        local player=getSpecificPlayer(i)
        if player then
            local key=player:getUsername()
            if not key or key=="" then key="local:"..i end
            if key==args.username then
                local old=NLHouseholdClient.snapshots[i]
                local oldRevision=old and old.householdRevision or -1
                if (args.householdRevision or 0)>=oldRevision then
                    NLHouseholdClient.snapshots[i]=args
                    if NLClient and NLClient.profiles[i] and (args.revision or 0)>=(NLClient.profiles[i].revision or 0) then
                        NLClient.profiles[i].homeActivities=args.homeActivities
                        NLClient.profiles[i].homeAspiration=args.homeAspiration
                    end
                    if NLHouseholdFurnishingClient then
                        if args.household then NLHouseholdFurnishingClient.apply(args.household) else NLHouseholdFurnishingClient.clear() end
                    end
                end
            end
        end
    end
end

function NLHouseholdClient.request(index,command,args)
    local player=getSpecificPlayer(index)
    if not player or player:isDead() then return end
    if isClient() then sendClientCommand(player,"NeighborhoodHousehold",command,args or {})
    elseif NLHouseholdAuthority then NLHouseholdAuthority.command("NeighborhoodHousehold",command,player,args or {}) end
end

Events.OnServerCommand.Add(NLHouseholdClient.receive)
Events.OnMainMenuEnter.Add(function() NLHouseholdClient.snapshots={} end)
loadOptional("NL/HouseholdFurnishingMenu")
return NLHouseholdClient