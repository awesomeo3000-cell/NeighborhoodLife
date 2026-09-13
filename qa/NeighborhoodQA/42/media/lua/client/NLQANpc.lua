-- Experimental body/movement test. Loaded ONLY by the separate QA mod.
NLQANpc = { tick = 0 }

function NLQANpc.start()
    if isClient() then return end
    local ok,err=pcall(function()
        local player=getSpecificPlayer(0)
        local cell=getCell()
        local px,py,pz=math.floor(player:getX()),math.floor(player:getY()),math.floor(player:getZ())
        local square=nil
        for dx=1,-1,-1 do
            for dy=1,-1,-1 do
                local candidate=cell:getGridSquare(px+dx,py+dy,pz)
                if not square and (dx~=0 or dy~=0) and candidate and candidate:isFree(false) then square=candidate end
            end
        end
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
        npc:setAlphaAndTarget(0,1)
        npc:resetModelNextFrame()
        if not cell:getObjectList():contains(npc) then cell:getObjectList():add(npc) end
        assert(getSpecificPlayer(0)==player,"NPC constructor replaced local player")
        assert(npc:isNpc(),"NPC flag did not attach AI component")
        assert(npc:getHumanVisual(),"No human visual")
        NLQANpc.body=npc
        NLQANpc.origin={x=npc:getX(),y=npc:getY()}
        NLQANpc.target={x=px,y=py,z=pz}
        if NLSocialAuthority then
            NLSocialAuthority.register("marisol",npc,{x=square:getX(),y=square:getY(),z=pz})
        end
        print("NLQA NPC SPAWN: "..npc:getX()..","..npc:getY()..","..npc:getZ().."; local player unchanged")
        npc:getPathFindBehavior2():pathToLocation(px,py,pz)
        getGameTime():setMultiplier(1)
        if UIManager.getSpeedControls() then UIManager.getSpeedControls():SetCurrentGameSpeed(1) end
    end)
    if not ok then print("NLQA NPC FAIL: "..tostring(err)) end
end

function NLQANpc.update()
    local npc=NLQANpc.body
    if not npc then return end
    NLQANpc.tick=NLQANpc.tick+1
    if NLQANpc.tick>60 and NLQANpc.tick<1800 and not NLQANpc.pathError then
        local ok,result=pcall(function() return npc:getPathFindBehavior2():update() end)
        if not ok then
            NLQANpc.pathError=true
            print("NLQA NPC PATH FAIL: "..tostring(result))
        elseif NLQANpc.tick%300==0 then
            print("NLQA NPC PATH RESULT: "..tostring(result))
        end
    end
    if NLQANpc.tick==60 then
        if UIManager.getSpeedControls() then UIManager.getSpeedControls():SetCurrentGameSpeed(1) end
        local path=npc:getPathFindBehavior2()
        path:pathToLocation(NLQANpc.target.x,NLQANpc.target.y,NLQANpc.target.z)
        npc:setVariable("bPathfind",true)
        print("NLQA NPC TARGET: "..path:getTargetX()..","..path:getTargetY()..","..path:getTargetZ())
        if NLRelationships then NLRelationships.open(0) end
    end
    if NLQANpc.tick==300 or NLQANpc.tick==900 or NLQANpc.tick==1800 then
        local o=NLQANpc.origin
        local distance=math.sqrt((npc:getX()-o.x)^2+(npc:getY()-o.y)^2)
        print("NLQA NPC MOVEMENT: distance="..distance.." square="..tostring(npc:getCurrentSquare()).." dead="..tostring(npc:isDead()).." alpha="..npc:getAlpha(0).." model="..tostring(npc:getModelInstance()))
    end
end
Events.OnGameStart.Add(NLQANpc.start)
Events.OnTick.Add(NLQANpc.update)
