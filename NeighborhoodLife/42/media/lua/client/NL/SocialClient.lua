NLSocialClient={snapshots={},events={},lastEvent=nil}
function NLSocialClient.receive(module,command,args)
    if module~="NeighborhoodSocial" or type(args)~="table" then return end
    if command=="event" then
        NLSocialClient.events[#NLSocialClient.events+1]=args
        while #NLSocialClient.events>20 do table.remove(NLSocialClient.events,1) end
        NLSocialClient.lastEvent=args
        return
    end
    if command~="snapshot" then return end
    for i=0,getNumActivePlayers()-1 do
        local p=getSpecificPlayer(i)
        if p then
            local key=p:getUsername()
            if not key or key=="" then key="local:"..i end
            if key==args.username then
                local previous=NLSocialClient.snapshots[i]
                if not previous or args.revision>=previous.revision then NLSocialClient.snapshots[i]=args end
            end
        end
    end
end
function NLSocialClient.request(index,command,args)
    local p=getSpecificPlayer(index)
    if not p or p:isDead() then return end
    if isClient() then sendClientCommand(p,"NeighborhoodSocial",command,args or {})
    elseif NLSocialAuthority then NLSocialAuthority.command("NeighborhoodSocial",command,p,args or {}) end
end
Events.OnServerCommand.Add(NLSocialClient.receive)
Events.OnMainMenuEnter.Add(function()
    NLSocialClient.snapshots={}; NLSocialClient.events={}; NLSocialClient.lastEvent=nil
end)
if Events.OnDisconnect then Events.OnDisconnect.Add(function()
    NLSocialClient.snapshots={}; NLSocialClient.events={}; NLSocialClient.lastEvent=nil
end) end
return NLSocialClient
