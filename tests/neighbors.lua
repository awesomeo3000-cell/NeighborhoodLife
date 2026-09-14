package.path=arg[1]..'/42/media/lua/shared/?.lua;'..package.path
require 'NL/Neighbors'
local n=0
local function check(v,label) assert(v,label); n=n+1 end
local world=NLDomain.newWorld()
local rows=NLNeighbors.ensure(world)
check(rows.marisol and rows.kenji and rows.amara,'all neighborhood identities initialized')
check(rows.marisol.position.x==rows.marisol.home.x,'initial position is home')
check(rows.marisol.onlineId==30001 and rows.kenji.onlineId==30002
    and rows.amara.onlineId==30003,'authored native online identities persist with neighborhood rows')
check(NLNeighbors.position(world,'marisol',11,12,0,2),'position update accepted')
local copy=NLDomain.copy(world)
check(copy.neighbors.marisol.position.x==11 and copy.neighbors.marisol.waypoint==2,'position serializes')
check(NLNeighbors.dead(world,'kenji'),'death state accepted')
check(NLNeighbors.get(world,'kenji').alive==false,'death persists')
check(not NLNeighbors.position(world,'kenji',1,1,0),'dead neighbor cannot move')
local profileA=NLDomain.profile(world,'host'); local profileB=NLDomain.profile(world,'guest')
profileA.relationships={marisol={friendship=20}}; profileB.relationships={marisol={friendship=0}}
check(copy.players==nil or copy.players.host==nil,'neighbor copy does not alias player profiles')
check(profileA.relationships.marisol.friendship~=profileB.relationships.marisol.friendship,'players retain private relationships')
print('PASS: '..n..' persistent-neighbor identity, route position, death and per-player isolation assertions')
