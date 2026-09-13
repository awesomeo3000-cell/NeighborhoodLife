NLSocialClient={snapshots={}}
function NLSocialClient.receive(module,command,args)
    if module~="NeighborhoodSocial" or command~="snapshot" or type(args)~="table" then return end
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
Events.OnMainMenuEnter.Add(function() NLSocialClient.snapshots={} end)
return NLSocialClient
