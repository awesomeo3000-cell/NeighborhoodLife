require "NL/Journal"

local function menuCheck()
    local ok,err=pcall(function()
        for _,career in pairs(NLDefinitions.careers) do
            assert(Perks[career.perk], "Missing perk: "..career.perk)
            for _,material in ipairs(career.materials) do
                assert(getScriptManager():FindItem(material[1]), "Missing item: "..material[1])
            end
        end
        for _,row in ipairs(NeighborhoodNeeds.rows) do
            local stat=CharacterStat[row[2]]
            assert(stat and stat:getMaximumValue()>stat:getMinimumValue(),"Invalid stat "..row[2])
            print("NLQA STAT "..row[2].." "..stat:getMinimumValue()..".."..stat:getMaximumValue())
        end
        local p=NLDomain.profile(NLDomain.newWorld(),"UI TEST FIXTURE")
        NLDomain.day(p,0)
        p.skill=0; p.message="UI TEST FIXTURE - no player/world progress is being modified"
        NLClient.profiles[0]=p
        NLJournal.open(0)
        print("NLQA PASS: actual item/perk/stat APIs and real ISPanel journal construction")
    end)
    if not ok then print("NLQA FAIL: "..tostring(err)) end
end
Events.OnMainMenuEnter.Add(menuCheck)

-- Native test entry point: restart the already-created disposable save without
-- relying on a desktop click landing between the game's input polling frames.
Events.OnMainMenuEnter.Add(function()
    if MainScreen.latestSaveGameMode and MainScreen.latestSaveWorld and not NLQAAutoLoaded then
        NLQAAutoLoaded=true
        MainScreen.continueLatestSave(MainScreen.latestSaveGameMode,MainScreen.latestSaveWorld)
    end
end)

Events.OnGameStart.Add(function()
    local ok,err=pcall(function()
        assert(not isClient(),"Run initial gameplay smoke in an isolated single-player save")
        local p=getSpecificPlayer(0)
        assert(p and NLAuthority,"Player or authority missing")
        if NLPlumbob and not NLPlumbob.instances["player:0"] then
            NLPlumbob.createPlayer(0,p)
        end
        local plumbob=NLPlumbob and NLPlumbob.instances["player:0"]
        assert(plumbob,"Plumbob panel was not registered for the real player")
        assert(plumbob:positionOverCharacter(),"Plumbob panel did not anchor over the real player")
        print("NLQA PASS: real engine plumbob panel registered and anchored at "..plumbob:getX()..","..plumbob:getY())
        NLAuthority.lastRequest={}
        NLClient.request(0,"refresh")
        local profile=NLClient.profiles[0]
        assert(profile and profile.username==NLAuthority.key(p),"Snapshot not routed to player")
        assert(type(NeighborhoodNeeds.read(p,"HUNGER"))=="number","Actual stat read failed")
        print("NLQA PASS: real player, authority, persistent world store, snapshot routing and hunger read")
        -- Development fixture only: adds supplies to this isolated test character.
        -- Production mod never adds these items and never clears rate limits.
        local state=NLDomain.profile(NLAuthority.world(),NLAuthority.key(p))
        if not state.qaDeliveryChecked then
            NLDomain.select(state,"tailor")
            local contract=NLDomain.contracts(state)[1]
            if not state.claimed[contract.id] then
                for i=1,contract.amount do assert(p:getInventory():AddItem(contract.item)) end
                local before=state.credits
                NLAuthority.lastRequest={}; NLClient.request(0,"deliver",{id=contract.id})
                assert(state.credits==before+10,"Real inventory delivery reward failed")
                NLAuthority.lastRequest={}; NLClient.request(0,"deliver",{id=contract.id})
                assert(state.credits==before+10,"Duplicate delivery rewarded twice")
                print("NLQA PASS: real inventory consumption, +10 credits, duplicate claim rejected")
            end
            state.qaDeliveryChecked=true
        else
            assert(state.credits>=10,"Saved credits missing")
            print("NLQA PASS: career credits survived actual save/reload")
        end
        assert(IsoSurvivor and SurvivorFactory,"NPC constructors not exposed")
        print("NLQA PASS: IsoSurvivor and SurvivorFactory exposed; replication NOT tested")
        NLJournal.open(0)
    end)
    if not ok then print("NLQA FAIL: "..tostring(err)) end
end)
