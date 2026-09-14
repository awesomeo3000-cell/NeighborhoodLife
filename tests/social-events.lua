local root=arg[1]
package.path=root..'/42/media/lua/client/?.lua;'..package.path
local serverHandler,menuHandler,disconnectHandler
Events={
    OnServerCommand={Add=function(fn) serverHandler=fn end},
    OnMainMenuEnter={Add=function(fn) menuHandler=fn end},
    OnDisconnect={Add=function(fn) disconnectHandler=fn end},
}
dofile(root..'/42/media/lua/client/NL/SocialClient.lua')
assert(NLSocialClient.lastEvent==nil and #NLSocialClient.events==0)
serverHandler('NeighborhoodSocial','event',{
    actor='nl-host',npcId='marisol',npcName='Marisol Vega',action='chat',message='Hello',revision=1})
assert(NLSocialClient.lastEvent.actor=='nl-host')
assert(NLSocialClient.lastEvent.action=='chat')
assert(#NLSocialClient.events==1)
for i=2,22 do
    serverHandler('NeighborhoodSocial','event',{actor='nl-host',npcId='marisol',
        action='joke',message='event '..i,revision=i})
end
assert(#NLSocialClient.events==20,'event feed remains bounded')
assert(NLSocialClient.events[1].message=='event 3','oldest event rolls off')
assert(NLSocialClient.lastEvent.message=='event 22')
disconnectHandler()
assert(NLSocialClient.lastEvent==nil and #NLSocialClient.events==0,'disconnect clears feed')
serverHandler('NeighborhoodSocial','event',{actor='nl-guest',npcId='kenji',
    action='chat',message='after disconnect',revision=23})
menuHandler()
assert(NLSocialClient.lastEvent==nil and #NLSocialClient.events==0,'menu clears feed')
print('PASS: replicated social event feed, bounded history, disconnect and menu cleanup')
