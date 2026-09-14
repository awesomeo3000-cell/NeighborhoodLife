if isClient() then return end
require "NL/Social"
require "NL/Authority"
require "NL/Neighbors"
NLSocialAuthority={bodies={},lastRequest={}}

function NLSocialAuthority.register(id,body,home)
    if not NLSocial.people[id] or not body or not NLNeighbors.definitions[id] then return false end
    local world=NLAuthority.world()
    NLNeighbors.register(world,id,home)
    NLSocialAuthority.bodies[id]=body
    return true
end

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
    if command~="refresh" and command~="interact" then return end
    local key=NLAuthority.key(player); local now=getTimestampMs()
    if NLQAMultiplayerServer then
        print("NLQA SOCIAL COMMAND: "..tostring(command).." username="..tostring(key)
            .." id="..tostring(args.id).." action="..tostring(args.action))
    end
    if NLSocialAuthority.lastRequest[key] and now-NLSocialAuthority.lastRequest[key]<200 then return end
    NLSocialAuthority.lastRequest[key]=now
    local message="Updated"
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
            if not ok then message="Not completed: "..message end
        end
    end
    NLSocialAuthority.snapshot(player,message)
    if NLQAMultiplayerServer and command=="interact" then
        print("NLQA SOCIAL RESULT: username="..tostring(key).." message="..tostring(message))
    end
end
Events.OnClientCommand.Add(NLSocialAuthority.command)
Events.OnMainMenuEnter.Add(function() NLSocialAuthority.bodies={}; NLSocialAuthority.lastRequest={} end)
return NLSocialAuthority
