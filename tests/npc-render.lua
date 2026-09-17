-- World-character presentation contract for Build 42 FBO render chunks. These
-- are native-shaped mocks; this is not gameplay or multiplayer evidence.
package.path = arg[1] .. '/42/media/lua/client/?.lua;' .. package.path
local postRender
Events = {
    OnPostRender = { Add=function(f) postRender=f end },
    OnMainMenuEnter = { Add=function() end },
}
require 'NL/NpcRender'

local draws = {}
local light = {r=1,g=1,b=1,a=1}
local body = { dead=false, square={ getLightInfo=function() return light end } }
function body:isDead() return self.dead end
function body:getCurrentSquare() return self.square end
function body:getX() return 4.5 end
function body:getY() return 6.5 end
function body:getZ() return 0 end
function body:render(x,y,z,color,b1,b2,b3)
    draws[#draws+1]={model=true,x=x,y=y,z=z,color=color,b1=b1,b2=b2,b3=b3}
end
function body:renderShadow(x,y,z) draws[#draws+1]={shadow=true,x=x,y=y,z=z} end

assert(NLNpcRender.register('npc:test', body), 'body registered for world rendering')
assert(NLNpcRender.register('npc:test', body), 'duplicate registration is accepted')
assert(#NLNpcRender.order==1, 'duplicate registration does not duplicate the draw order')
assert(postRender, 'world-render event handler registered')

postRender()
assert(#draws==2, 'one model draw and one shadow per registered body')
assert(draws[1].model and draws[1].x==4.5 and draws[1].y==6.5 and draws[1].z==0,
    'registered body is drawn at its world position')
assert(draws[1].color==light and draws[1].b1==true and draws[1].b2==false and draws[1].b3==nil,
    'draw uses the square lighting and the engine player render arguments')
assert(draws[2].shadow and draws[2].x==4.5, 'registered body receives a shadow pass')

local noLight = {
    isDead=function() return false end,
    getCurrentSquare=function() return { getLightInfo=function() return nil end } end,
    render=function() error('must not render without square lighting') end,
}
assert(NLNpcRender.render(noLight,0)==false, 'render refuses a body without square lighting')

body.dead = true
assert(NLNpcRender.render(body,0)==false, 'dead body is not drawn')
body.dead = false
assert(#draws==2, 'refused renders do not queue a draw')

assert(NLNpcRender.unregister('npc:test'), 'body unregistered')
assert(NLNpcRender.bodies['npc:test']==nil and #NLNpcRender.order==0, 'registry cleared')
NLNpcRender.register('npc:test', body)
NLNpcRender.clear()
assert(#NLNpcRender.order==0, 'menu cleanup clears the draw registry')
print('PASS: NPC FBO world-render registration, lighting, shadow and cleanup')
