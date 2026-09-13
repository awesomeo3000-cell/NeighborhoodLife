-- Experimental body/movement test. Loaded ONLY by the separate QA mod.
-- The engine does not tick an IsoPlayer that is not in the local player list, so
-- this probe emulates the player frame for the QA NPC: preupdate, update,
-- native PathFindBehavior2:update (as WalkToTimedAction does), postupdate.
NLQANpc = { tick = 0, maxDistance = 0, legs = 0, plannedLegs = 3 }

local function emit(message)
    print("NLQA NPC " .. message)
end

function NLQANpc.freeSquareNear(cell,x,y,pz,minDistance,maxDistance,avoid)
    local best=nil
    local bestDistance=nil
    for dx=-maxDistance,maxDistance do
        for dy=-maxDistance,maxDistance do
            local distance=math.sqrt(dx*dx+dy*dy)
            if distance>=minDistance and distance<=maxDistance then
                local square=cell:getGridSquare(x+dx,y+dy,pz)
                if square and square:isFree(false)
                        and (not avoid or square:getX()~=avoid:getX() or square:getY()~=avoid:getY()) then
                    if not best or distance<bestDistance then
                        best=square
                        bestDistance=distance
                    end
                end
            end
        end
    end
    return best
end

function NLQANpc.start()
    if isClient() then return end
    -- Once the production adapter is loaded, this helper becomes an observer.
    -- It must never create a second body beside the real persisted neighbor.
    if NLNpcAuthority then
        NLQANpc.productionPending=true
        if UIManager.getSpeedControls() then UIManager.getSpeedControls():SetCurrentGameSpeed(1) end
        if NLNpcAuthority.bodies and NLNpcAuthority.bodies.marisol then
            NLQANpc.body=NLNpcAuthority.bodies.marisol
            NLQANpc.production=true
            emit("PRODUCTION BODY: adapter owns Marisol")
        end
        return
    end
    local ok,err=pcall(function()
        local player=getSpecificPlayer(0)
        local cell=getCell()
        local px,py,pz=math.floor(player:getX()),math.floor(player:getY()),math.floor(player:getZ())
        local square=NLQANpc.freeSquareNear(cell,px,py,pz,1,2,nil)
        assert(square,"No free adjacent square")
        local desc=SurvivorFactory.CreateSurvivor()
        desc:setForename("Marisol"); desc:setSurname("Vega"); desc:setFemale(true)
        local npc=IsoPlayer.new(cell,desc,square:getX(),square:getY(),square:getZ())
        npc:setNpc(true)
        npc:setUsername("Marisol Vega [NPC test]")
        npc:setGodMod(true)
        npc:getModData().NeighborhoodNpcId="qa_marisol"
        npc:setX(square:getX()+0.5); npc:setY(square:getY()+0.5)
        npc:setCurrent(square)
        npc:dressInNamedOutfit("Generic01")
        npc:setSceneCulled(false)
        npc:setAlphaAndTarget(1,1)
        npc:resetModelNextFrame()
        if not cell:getObjectList():contains(npc) then cell:getObjectList():add(npc) end
        assert(getSpecificPlayer(0)==player,"NPC constructor replaced local player")
        assert(npc:isNpc(),"NPC flag did not attach AI component")
        assert(npc:getHumanVisual(),"No human visual")
        NLQANpc.body=npc
        if NLPlumbob then
            NLPlumbob.register("qa:marisol",npc,0,{r=0.28,g=0.86,b=0.95})
        end
        NLQANpc.origin={x=npc:getX(),y=npc:getY()}
        if NLSocialAuthority then
            NLSocialAuthority.register("marisol",npc,{x=square:getX(),y=square:getY(),z=pz})
        end
        emit("SPAWN: "..npc:getX()..","..npc:getY()..","..npc:getZ().."; local player unchanged")
    end)
    if not ok then print("NLQA NPC FAIL: "..tostring(err)) end
end

function NLQANpc.nextLeg()
    local npc=NLQANpc.body
    local cell=getCell()
    local current=npc:getCurrentSquare()
    local cx,cy,cz=math.floor(npc:getX()),math.floor(npc:getY()),math.floor(npc:getZ())
    local target=NLQANpc.freeSquareNear(cell,cx,cy,cz,2,5,current)
    if not target then target=NLQANpc.freeSquareNear(cell,cx,cy,cz,1,2,current) end
    if not target then
        NLQANpc.routeDone=true
        emit("ROUTE RESULT: no further free waypoint after "..NLQANpc.legs.." legs")
        return
    end
    NLQANpc.legTarget={x=target:getX()+0.5,y=target:getY()+0.5,z=target:getZ()}
    NLQANpc.legDone=false
    emit(string.format("LEG %d START: from=%.2f,%.2f to=%d,%d",
        NLQANpc.legs+1,npc:getX(),npc:getY(),target:getX(),target:getY()))
    npc:getPathFindBehavior2():pathToLocation(target:getX(),target:getY(),target:getZ())
end

function NLQANpc.status(npc,pfb)
    local pathLength=-1
    local ok,value=pcall(function() return pfb:getPathLength() end)
    if ok and value then pathLength=value end
    return string.format("result=%s pathLength=%.2f hasPath=%s moving=%s animUpdating=%s",
        tostring(NLQANpc.lastResult),pathLength,tostring(npc:hasPath()),
        tostring(pfb:shouldBeMoving()),tostring(npc:isAnimationUpdatingThisFrame()))
end

function NLQANpc.update()
    if NLQANpc.production then return end
    local npc=NLQANpc.body
    if not npc or npc:isDead() then return end
    NLQANpc.tick=NLQANpc.tick+1
    local pfb=npc:getPathFindBehavior2()
    local origin=NLQANpc.origin
    local distance=math.sqrt((npc:getX()-origin.x)^2+(npc:getY()-origin.y)^2)
    if distance>NLQANpc.maxDistance then NLQANpc.maxDistance=distance end

    if NLQANpc.tick==60 then
        if UIManager.getSpeedControls() then UIManager.getSpeedControls():SetCurrentGameSpeed(1) end
        NLQANpc.nextLeg()
    end

    if NLQANpc.tick>60 and not NLQANpc.routeDone and not NLQANpc.pathError then
        if NLQANpc.legDone then
            if NLQANpc.tick-NLQANpc.legDoneTick>=30 then
                if NLQANpc.legs>=NLQANpc.plannedLegs then
                    NLQANpc.routeDone=true
                    emit(string.format("ROUTE RESULT: %d/%d legs reached; maxDistance=%.3f",
                        NLQANpc.legs,NLQANpc.plannedLegs,NLQANpc.maxDistance))
                    emit(string.format("MOVEMENT RESULT: maxDistance=%.3f legs=%d/%d routeDone=true",
                        NLQANpc.maxDistance,NLQANpc.legs,NLQANpc.plannedLegs))
                else
                    NLQANpc.nextLeg()
                end
            end
        else
            local ok,result=pcall(function()
                npc:preupdate()
                npc:update()
                local behavior=pfb:update()
                npc:postupdate()
                return behavior
            end)
            if not ok then
                NLQANpc.pathError=true
                emit("PATH FAIL: "..tostring(result))
            else
                NLQANpc.lastResult=tostring(result)
                if result==BehaviorResult.Succeeded then
                    NLQANpc.legs=NLQANpc.legs+1
                    local target=NLQANpc.legTarget
                    local error=math.sqrt((npc:getX()-target.x)^2+(npc:getY()-target.y)^2)
                    emit(string.format("LEG %d COMPLETE: tick=%d at=%.2f,%.2f targetError=%.3f",
                        NLQANpc.legs,NLQANpc.tick,npc:getX(),npc:getY(),error))
                    pfb:cancel()
                    npc:setPath2(nil)
                    NLQANpc.legDone=true
                    NLQANpc.legDoneTick=NLQANpc.tick
                end
            end
        end
    end

    if NLQANpc.tick%300==0 and not NLQANpc.routeDone then
        emit(string.format("MOVEMENT: distance=%.3f max=%.3f legs=%d x=%.2f y=%.2f %s",
            distance,NLQANpc.maxDistance,NLQANpc.legs,npc:getX(),npc:getY(),NLQANpc.status(npc,pfb)))
    end
    if NLQANpc.tick==2400 and not NLQANpc.routeDone then
        emit(string.format("MOVEMENT RESULT: maxDistance=%.3f legs=%d/%d routeDone=false",
            NLQANpc.maxDistance,NLQANpc.legs,NLQANpc.plannedLegs))
    end
end

Events.OnGameStart.Add(NLQANpc.start)
Events.OnTick.Add(NLQANpc.update)
Events.OnRenderTick.Add(function()
    if not NLQANpc.productionPending or NLQANpc.production then return end
    NLQANpc.observeFrame=(NLQANpc.observeFrame or 0)+1
    if NLNpcAuthority and NLNpcAuthority.bodies and NLNpcAuthority.bodies.marisol then
        NLQANpc.body=NLNpcAuthority.bodies.marisol
        NLQANpc.production=true
        emit("PRODUCTION BODY: adapter owns Marisol")
    elseif NLQANpc.observeFrame==300 then
        emit("PRODUCTION BODY MISSING: adapter did not create Marisol")
    end
end)

-- Persist the real isolated world without desktop input so the next launcher
-- run can verify native-body restoration from ModData.
Events.OnRenderTick.Add(function()
    if not NLQANpc.production or NLQANpc.saveAttempted then return end
    NLQANpc.saveFrame=(NLQANpc.saveFrame or 0)+1
    if NLQANpc.saveFrame<600 then return end
    NLQANpc.saveAttempted=true
    local ok,err=pcall(function() GameWindow.save(false) end)
    emit("SAVE "..(ok and "OK" or ("FAILED: "..tostring(err))))
end)
