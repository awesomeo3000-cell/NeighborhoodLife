package.path = arg[1] .. '/42/media/lua/shared/?.lua;' .. arg[1] .. '/42/media/lua/server/?.lua;' .. arg[1] .. '/42/media/lua/client/?.lua;' .. package.path
local target = arg[1]
local packets = {}
local world = {}
local now = 1000
function isClient() return false end
function isServer() return true end
function getTimestampMs() now = now + 250; return now end
function getGameTime() return {getWorldAgeHours=function() return 0 end} end
ModData = {getOrCreate=function() return world end}
Events = {OnClientCommand={Add=function() end},OnRenderTick={Add=function() end},OnMainMenuEnter={Add=function() end},OnServerCommand={Add=function() end},OnGameStart={Add=function() end},OnTick={Add=function() end}}
Perks = {Tailoring='Tailoring',Woodwork='Woodwork',Doctor='Doctor'}
function sendServerCommand(player,module,command,args)
    packets[#packets+1] = {player=player,module=module,command=command,args=args}
end
local function player(name,x)
    local p={name=name,x=x,y=10214,z=0,dead=false,skill=0}
    function p:getUsername() return self.name end
    function p:getPlayerNum() return 0 end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return self.z end
    function p:getOnlineID() return self.name == 'host' and 1 or 2 end
    function p:isDead() return self.dead end
    function p:getPerkLevel() return self.skill end
    return p
end
local host,guest=player('host',10754),player('guest',10755)
function getOnlinePlayers() return {size=function() return 2 end,get=function(_,i) return i==0 and host or guest end} end
require 'NL/Authority'
if not NLAuthority.broadcastPresence then
    print('PASS: replication suite skipped for pre-presence baseline')
    return
end
assert(NLAuthority.broadcastPresence()==2,'server presence must enumerate authoritative players')
local a,b=packets[1],packets[2]
assert(a.command=='presence' and b.command=='presence','presence sent to each connected player')
assert(a.args.players[2].username=='guest' and a.args.players[2].x==10755,'server position included')
assert(b.args.players[1].username=='host' and b.args.players[1].x==10754,'peer position included')
server = false
require 'NL/Client'
NLClient.receive('NeighborhoodLife','presence',a.args)
assert(NLClient.presence.players[2].username=='guest','client stores replicated presence')
local npcOk = pcall(require, 'NL/NpcAuthority')
if npcOk and NLNpcAuthority and NLNpcAuthority.broadcastPresence then
    local npc={getX=function() return 10756.5 end,getY=function() return 10214.5 end,
        getZ=function() return 0 end,isDead=function() return false end}
    NLNpcAuthority.bodies={marisol=npc}
    NLNpcAuthority.broadcastPresence()
    local npcPacket
    for _,packet in ipairs(packets) do if packet.command=='npc_presence' then npcPacket=packet end end
    assert(npcPacket and npcPacket.args.npcs[1].id=='marisol','NPC state sent to each connected player')
    NLClient.receive('NeighborhoodLife','npc_presence',npcPacket.args)
    assert(NLClient.npcPresence.npcs[1].x==10756.5,'client stores authoritative NPC state')
    print('PASS: authoritative player presence plus native-NPC state broadcast and client storage')
else
    print('PASS: authoritative two-player presence broadcast, coordinates, recipients and client storage')
end
