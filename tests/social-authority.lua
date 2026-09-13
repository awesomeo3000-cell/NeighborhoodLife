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
before=r.friendship; p.dead=true; cmd(p,'chat'); check(r.friendship==before,'dead player rejected'); p.dead=false
body.dead=true; cmd(p,'chat'); check(world.neighbors.marisol.dead and r.friendship==before,'dead NPC persisted and rejected')
last.args.neighbors[1].relation.friendship=999
check(r.friendship~=999,'snapshot cannot mutate authority')
NLSocialAuthority.bodies={}; cmd(p,'chat'); check(r.friendship==before,'unloaded body rejected')
print('PASS: '..n..' social authority assertions (proximity, visibility, private snapshots, death and absent bodies)')
