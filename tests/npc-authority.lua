-- Production NPC adapter contract test. Native body calls are deterministic
-- fixtures here; this is not real engine movement evidence.
package.path = arg[1] .. '/42/media/lua/shared/?.lua;' .. arg[1] .. '/42/media/lua/server/?.lua;' .. package.path
local function hook() return {Add=function(f) return f end} end
local saveHook
Events={OnClientCommand=hook(),OnRenderTick=hook(),OnMainMenuEnter=hook(),OnGameStart=hook(),OnTick=hook(),
    OnSave={Add=function(f) saveHook=f end}}
function isClient() return false end
function isServer() return false end
local worldStore={}
ModData={getOrCreate=function(key) worldStore[key]=worldStore[key] or {}; return worldStore[key] end}
function getTimestampMs() return 1000 end
local scheduleHour, scheduleDay = 7, 1
function getGameTime() return {getWorldAgeHours=function() return 0 end,
    getHour=function() return scheduleHour end, getDay=function() return scheduleDay end} end
Perks={Tailoring='Tailoring',Woodwork='Woodwork',Doctor='Doctor'}
local player={x=100,y=100,z=0,dead=false}
function player:getX() return self.x end; function player:getY() return self.y end
function player:getZ() return self.z end; function player:getPlayerNum() return 0 end
function player:getUsername() return 'npc-test-player' end; function player:isDead() return self.dead end
function getSpecificPlayer() return player end
local function square(x,y,z)
    return {getX=function() return x end,getY=function() return y end,getZ=function() return z end,
        isFree=function() return true end}
end
local objectSet={}
local objects={}
function objects:contains(value) return objectSet[value] == true end
function objects:add(value) objectSet[value] = true end
function objects:remove(value) objectSet[value] = nil end
local zombies={}
local zombieList={}
function zombieList:size() return #zombies end
function zombieList:get(index) return zombies[index+1] end
function getCell() return {getGridSquare=function(_,x,y,z) local s=square(x,y,z); s.getObjectList=function() return objects end; return s end,
    getObjectList=function() return objects end,getZombieList=function() return zombieList end} end
SurvivorFactory={CreateSurvivor=function() return {
    setForename=function() end,setSurname=function() end,setFemale=function() end} end}
BehaviorResult={Succeeded='succeeded'}
local function bodyAt(cell,desc,x,y,z)
    local b={x=x+0.5,y=y+0.5,z=z,mod={}}
    function b:setNpc(v) self.npc=v end; function b:isNpc() return self.npc end
    function b:setUsername(v) self.username=v end; function b:getUsername() return self.username end
    function b:setGodMod() end
    function b:getModData() return self.mod end; function b:dressInNamedOutfit() end
    function b:setX(v) self.x=v end; function b:setY(v) self.y=v end; function b:getX() return self.x end
    function b:getY() return self.y end; function b:getZ() return self.z end
    function b:getOnlineID() return self.onlineId or 44 end
    function b:setOnlineID(value) self.onlineId=value end
    function b:setCurrent(v) self.current=v end; function b:setSceneCulled() end
    function b:setAlphaAndTarget() end; function b:resetModelNextFrame() end
    function b:isDead() return self.dead == true end; function b:hasPath() return false end
    local behavior={}
    function behavior:pathToLocation(x1,y1,z1) self.target={x=x1,y=y1,z=z1} end
    function behavior:update() return BehaviorResult.Succeeded end
    function behavior:cancel() self.target=nil end
    function b:getPathFindBehavior2() return behavior end
    function b:setPath2() end
    function b:preupdate() end; function b:update() end; function b:postupdate() end
    return b
end
IsoPlayer={new=bodyAt}
local reannounced={}
local function javaMap()
    local map={data={}}
    function map:put(key,value) local previous=self.data[key]; self.data[key]=value; return previous end
    return map
end
local nativeMaps={
    IDToPlayerMap=javaMap(), UserNameToPlayerMap=javaMap(),
}
local nativeRoster={items={}}
function nativeRoster:contains(value) for _,item in ipairs(self.items) do if item==value then return true end end return false end
function nativeRoster:add(value) self.items[#self.items+1]=value end
GameServer={
    Players=nativeRoster, IDToPlayerMap=nativeMaps.IDToPlayerMap,
    UserNameToPlayerMap=nativeMaps.UserNameToPlayerMap,
    getConnectionFromPlayer=function(target) return {target=target,getConnectedGUID=function() return 9001 end} end,
    sendPlayerConnected=function(source, connection)
        reannounced[#reannounced+1]={source=source,connection=connection}
    end,
}
function getOnlinePlayers()
    return {size=function() return 1 end,get=function() return player end}
end
NLAuthority={module='NeighborhoodLife',world=function() local w=ModData.getOrCreate('NeighborhoodLife_v2'); w.version=w.version or 2; return w end}
package.preload['NL/Authority']=function() return NLAuthority end
package.preload['NL/SocialAuthority']=function() NLSocialAuthority={bodies={},register=function(id,b,h) NLSocialAuthority.bodies[id]=b; return true end}; return NLSocialAuthority end
NLQANpc=true
local nativePositionSyncCalls=0
NLNativeNpcPositionSync=function(body,x,y,z)
    nativePositionSyncCalls=nativePositionSyncCalls+1
    body.realx=x; body.realy=y; body.realz=z
    return true
end
require 'NL/NpcAuthority'
assert(NLNpcAuthority and type(NLNpcAuthority.start)=='function')
NLNpcAuthority.start()
local body=NLNpcAuthority.bodies.marisol
assert(body and body:isNpc() and body:getModData().NeighborhoodNpcId=='marisol','production body created')
assert(nativePositionSyncCalls>=1,
    'typed native position bridge receives authoritative spawn coordinates')
assert(body:getOnlineID()==30001,'native NPC receives its stable authored online identity')
assert(NLNpcAuthority.assignNativeOnlineId(body,30001),'online identity assignment verifies through the native getter')
assert(NLNpcAuthority.routineForHour(NLNeighbors.definitions.marisol, 7)=='home',
    'authored routine selects home before the work window')
assert(NLNpcAuthority.routineForHour(NLNeighbors.definitions.marisol, 9)=='work',
    'authored routine selects work inside the career window')
scheduleHour=9
NLNpcAuthority.update()
local scheduledRow=NLAuthority.world().neighbors.marisol
assert(scheduledRow.routine=='work' and scheduledRow.routineHour==9,
    'server clock transition persists the NPC work routine')
local scheduledPacket=NLNpcAuthority.presencePacket()
local scheduledEntry
for _, entry in ipairs(scheduledPacket.npcs or {}) do
    if entry.id=='marisol' then scheduledEntry=entry; break end
end
assert(scheduledEntry and scheduledEntry.routine=='work' and scheduledEntry.schedule=='tailor',
    'presence heartbeat carries the authoritative NPC routine and career')
if NLNpcAuthority.presencePacket then
    NLNpcAuthority.targets.marisol={x=body:getX()+2,y=body:getY(),z=body:getZ(),waypoint=1}
    local motionPacket=NLNpcAuthority.presencePacket()
    local motionEntry
    for _, entry in ipairs(motionPacket.npcs or {}) do
        if entry.id == 'marisol' then motionEntry = entry; break end
    end
    assert(motionEntry and motionEntry.motion
        and motionEntry.motion.targetX==body:getX()+2.5,
        'presence heartbeat carries the active authoritative route target')
    NLNpcAuthority.targets.marisol=nil
end
if NLNpcAuthority.safeFallbackStep then
    local freeStepX,freeStepY=NLNpcAuthority.safeFallbackStep(body,{x=math.floor(body:getX())+2,y=math.floor(body:getY()),z=body:getZ()})
    assert(freeStepX and freeStepY,'stalled native path has a bounded free-tile fallback')
    local originalBodyX,originalBodyY=body:getX(),body:getY()
    local originalGetCell=getCell
    getCell=function()
        return {getGridSquare=function(_,x,y,z)
            local s=square(x,y,z)
            s.isFree=function() return x~=101 end
            return s
        end}
    end
    body:setX(100.95); body:setY(100.50)
    local blockedStepX,blockedStepY=NLNpcAuthority.safeFallbackStep(body,{x=102,y=100,z=0})
    assert(blockedStepX and blockedStepY and math.floor(blockedStepX)~=101,
        'stalled native path refuses to cross an occupied tile')
    getCell=function()
        return {getGridSquare=function(_,x,y,z)
            local s=square(x,y,z)
            s.isFree=function()
                return not ((x==101 and y==100) or (x==100 and y==101)
                    or (x==101 and y==101))
            end
            return s
        end}
    end
    body:setX(100.95); body:setY(100.95)
    local detourTarget={x=102,y=101,z=0}
    local detourStepX,detourStepY=NLNpcAuthority.safeFallbackStep(body,detourTarget)
    assert(detourStepX and detourStepY and detourStepY<body:getY() and detourTarget.detour,
        'stalled native path chooses a remembered free-side detour around a corner')
    body:setX(detourTarget.detour.x); body:setY(detourTarget.detour.y)
    local aroundStepX,aroundStepY
    for _=1,80 do
        aroundStepX,aroundStepY=NLNpcAuthority.safeFallbackStep(body,detourTarget)
        if not aroundStepX then break end
        body:setX(aroundStepX); body:setY(aroundStepY)
        if math.floor(aroundStepX)==101 then break end
    end
    assert(aroundStepX and math.floor(aroundStepX)==101,
        'stalled native path resumes across the obstacle from the detour tile')
    getCell=originalGetCell
    body:setX(originalBodyX); body:setY(originalBodyY)
end
if NLNpcAuthority.dangerNear and NLNpcAuthority.safeDangerStep then
    local threat={x=body:getX()-1.0,y=body:getY(),z=body:getZ(),dead=false}
    function threat:getX() return self.x end; function threat:getY() return self.y end
    function threat:getZ() return self.z end; function threat:isZombie() return true end
    function threat:isDead() return self.dead end; function threat:isFakeDead() return false end
    zombies[1]=threat
    local nearest,distance=NLNpcAuthority.dangerNear(body,4.0)
    assert(nearest==threat and distance<4.0,'loaded-cell danger scan finds a living nearby zombie')
    local retreatX,retreatY=NLNpcAuthority.safeDangerStep(body,threat)
    assert(retreatX and retreatY and retreatX>body:getX(),'danger fallback steps away from the zombie')
    local originalIsServer=isServer
    isServer=function() return true end
    local beforeDangerX=body:getX()
    NLNpcAuthority.targets.marisol={x=body:getX()+2,y=body:getY(),z=body:getZ(),waypoint=1,
        lastX=body:getX(),lastY=body:getY(),stall=0}
    NLNpcAuthority.update()
    assert(NLNpcAuthority.danger.marisol and not NLNpcAuthority.targets.marisol
        and body:getX()>beforeDangerX,'server route pauses and retreats from nearby danger')
    isServer=originalIsServer
    zombies[1]=nil
end
local expectedBodies=#NLNpcAuthority.definitions
if NLNpcAuthority.reannounceTo then
    if NLNpcAuthority.resolveNativeNpcBridge then
        local typedCalls=0
        local previousBridge=NLNativeNpcBridge
        NLNativeNpcBridge=function(source, recipient)
            typedCalls=typedCalls+1
            assert(source and recipient,'typed native bridge receives body and recipient')
            return true
        end
        assert(NLNpcAuthority.resolveNativeNpcBridge() ~= nil,
            'typed native bridge is discoverable from the server environment')
        local beforeTyped=#reannounced
        assert(NLNpcAuthority.reannounceTo(player)==expectedBodies
            and typedCalls==expectedBodies and #reannounced==beforeTyped,
            'typed native bridge reannounces every authored body without Lua GameServer')
        NLNativeNpcBridge=previousBridge
    end
    assert(NLNpcAuthority.reannounceTo(player)==expectedBodies
        and #reannounced==expectedBodies,
        'native reannounce adapter sends authored bodies to a connected player')
    assert(nativeMaps.IDToPlayerMap.data[30001]==NLNpcAuthority.bodies.marisol
        and nativeMaps.IDToPlayerMap.data[30002]==NLNpcAuthority.bodies.kenji
        and nativeMaps.IDToPlayerMap.data[30003]==NLNpcAuthority.bodies.amara,
        'native reannounce registers authored online ids in GameServer')
    assert(nativeMaps.UserNameToPlayerMap.data['Marisol Vega [Neighborhood Life]']==30001
        and #nativeRoster.items==expectedBodies,
        'native reannounce registers usernames and adds each body to the native roster')
    if NLNpcAuthority.resolveGameServer then
        local globalGameServer=GameServer
        GameServer=nil
        function getClass(name)
            if name == 'zombie.network.GameServer' then return globalGameServer end
        end
        local beforeClassRoute=#reannounced
        assert(NLNpcAuthority.reannounceTo(player)==expectedBodies
            and #reannounced==beforeClassRoute+expectedBodies,
            'native reannounce adapter uses the loaded GameServer class when global is absent')
        GameServer=globalGameServer
    end
end
if expectedBodies>=3 then
    for _, id in ipairs({'kenji','amara'}) do
        local extra=NLNpcAuthority.bodies[id]
        assert(extra and extra:isNpc() and extra:getModData().NeighborhoodNpcId==id,
            'all authored neighborhood bodies created: '..id)
    end
end
local row=NLAuthority.world().neighbors.marisol
assert(row and row.spawned and row.position.x==body:getX(),'body position persisted')
local savedX,savedY=row.position.x,row.position.y
body:setX(savedX+0.37); body:setY(savedY+0.23)
if saveHook then
    assert(saveHook()==expectedBodies,'save hook persists all authored native body positions')
    assert(math.abs(row.position.x-body:getX())<0.001 and math.abs(row.position.y-body:getY())<0.001,
        'save hook writes the current authoritative position')
    savedX,savedY=row.position.x,row.position.y
end
NLNpcAuthority.update()
assert(row.position.x==body:getX() and row.position.y==body:getY(),'route tick keeps registry authoritative')
NLNpcAuthority.reset()
NLNpcAuthority.start()
local restored=NLNpcAuthority.bodies.marisol
assert(restored and math.abs(restored:getX()-savedX)<0.001 and math.abs(restored:getY()-savedY)<0.001,
    'saved position restores into the native body')
if expectedBodies>=3 then
    assert(NLNpcAuthority.bodies.kenji and NLNpcAuthority.bodies.amara,
        'all authored bodies restore after reset')
end
if NLNpcAuthority.repairStacked then
    -- Legacy isolated saves can contain stacked rows. A restart must repair
    -- those rows to distinct native squares; this remains a mock contract, not
    -- gameplay evidence.
    local savedWorld=NLAuthority.world()
    for _, id in ipairs({'marisol','kenji','amara'}) do
        local stacked=savedWorld.neighbors[id]
        stacked.position={x=101.5,y=101.5,z=0}; stacked.home={x=101,y=101,z=0}
        stacked.revision=1; stacked.spawned=true; stacked.alive=true
    end
    NLNpcAuthority.reset(); NLNpcAuthority.start()
    local occupied={}
    for _, id in ipairs({'marisol','kenji','amara'}) do
        local stackedBody=NLNpcAuthority.bodies[id]
        local key=math.floor(stackedBody:getX())..':'..math.floor(stackedBody:getY())..':'..math.floor(stackedBody:getZ())
        assert(not occupied[key],'stacked legacy NPC rows are repaired to distinct squares')
        occupied[key]=true
    end
end
if NLNpcAuthority.reconcileBodies and NLNpcAuthority.recoverMissingBodies then
    -- Lifecycle contract: a removed native body becomes an unavailable but
    -- still alive persistent neighbor, then recovers only from its saved tile;
    -- a native death is retired, persisted and omitted from the body table.
    local offscreenBody=NLNpcAuthority.bodies.kenji
    local offscreenRow=NLAuthority.world().neighbors.kenji
    objectSet[offscreenBody]=nil
    NLNpcAuthority.update()
    assert(not NLNpcAuthority.bodies.kenji and NLNpcAuthority.offscreen.kenji,
        'missing native body is retired as an offscreen transient')
    assert(offscreenRow.alive==true and offscreenRow.position.x==offscreenBody:getX(),
        'offscreen retirement preserves the persistent identity and last position')
    NLNpcAuthority.tick=NLNpcAuthority.offscreen.kenji.nextAttempt
    local recovered=NLNpcAuthority.recoverMissingBodies()
    assert(recovered==1 and NLNpcAuthority.bodies.kenji,
        'offscreen native body recovers at the persisted tile without player fallback')
    local deadBody=NLNpcAuthority.bodies.amara
    deadBody.dead=true
    NLNpcAuthority.update()
    assert(not NLNpcAuthority.bodies.amara and NLAuthority.world().neighbors.amara.alive==false,
        'native death retires the body and persists a dead neighbor row')
end
print('PASS: production NPC identity, native body adapter, route tick and save/reload position restoration')
