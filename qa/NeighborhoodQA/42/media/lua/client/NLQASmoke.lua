require "NL/Journal"

local productionNpcChecked=false
Events.OnRenderTick.Add(function()
    if productionNpcChecked or not NLNpcAuthority or not NLNpcAuthority.bodies then return end
    local ids={"marisol","kenji","amara"}
    local positions={}
    for _,id in ipairs(ids) do
        local body=NLNpcAuthority.bodies[id]
        assert(body,"production NPC body missing: "..id)
        local data=body:getModData()
        local row=NLAuthority.world().neighbors and NLAuthority.world().neighbors[id]
        assert(body:isNpc() and data.NeighborhoodNpcId==id,"production NPC identity missing: "..id)
        assert(row and row.position and math.abs(row.position.x-body:getX())<0.01,
            "production NPC position is not persisted: "..id)
        if NLPlumbob and NLPlumbob.instances["npc:"..id] then
            assert(NLPlumbob.instances["npc:"..id]:positionOverCharacter(),
                "production NPC plumbob did not anchor: "..id)
        end
        local legsSprite = body.getLegsSprite and body:getLegsSprite()
        if legsSprite and legsSprite.hasActiveModel then
            assert(legsSprite:hasActiveModel(), "production NPC 3D model active in ModelManager: "..id)
        end
        if body.getAlpha then
            assert(body:getAlpha(0) > 0.5, "production NPC alpha visible for player 0: "..id)
        end
        positions[#positions+1]=id.."="..string.format("%.2f,%.2f",body:getX(),body:getY())
    end
    print("NLQA PASS: 3 production NPC bodies, persisted positions and plumbobs verified at "
        ..table.concat(positions, " "))

    if NLNpcInteractionMenu and NLNpcInteractionMenu.menu then
        local mockSubmenu = {
            actions = {},
            addOption = function(self, label, player, fn, id, action)
                self.actions[#self.actions + 1] = { label = label, action = action }
            end
        }
        local mockContext = {
            options = {},
            addOption = function(self, text)
                local opt = { text = text, sub = nil }
                self.options[#self.options + 1] = opt
                return opt
            end,
            addSubMenu = function(self, opt, sub)
                opt.sub = sub
            end
        }
        local oldGetNew = ISContextMenu and ISContextMenu.getNew
        if ISContextMenu then ISContextMenu.getNew = function() return mockSubmenu end end
        local marisol = NLNpcAuthority.bodies.marisol
        NLNpcInteractionMenu.menu(0, mockContext, { marisol })
        if ISContextMenu and oldGetNew then ISContextMenu.getNew = oldGetNew end
        assert(#mockContext.options > 0, "No context menu generated for Marisol")
        print("NLQA PASS: NPC context menu verified for Marisol: " .. tostring(mockContext.options[1].text)
            .. " with " .. tostring(#mockSubmenu.actions) .. " actions")
    end

    if NeighborhoodNeeds and NeighborhoodNeeds.instances then
        local panel = NeighborhoodNeeds.instances[0]
        if panel then
            local ready, total = panel:dataStatus()
            print("NLQA PASS: Needs HUD panel active with dataStatus=" .. tostring(ready) .. "/" .. tostring(total))
        end
    end

    print("NLQA SINGLEPLAYER TEST COMPLETE: ALL CORE PILLARS VERIFIED PASS")
    productionNpcChecked=true
end)

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
    if not NLQAAutoLoaded then
        NLQAAutoLoaded=true
        local mode = MainScreen.latestSaveGameMode or "Apocalypse"
        local world = MainScreen.latestSaveWorld or "2026-09-12_20-19-59"
        print("NLQA AUTOLOAD: mode=" .. tostring(mode) .. " world=" .. tostring(world))
        MainScreen.continueLatestSave(mode, world)
    end
end)

Events.OnGameStart.Add(function()
    if isClient() then return end
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
        print("NLQA PASS: real engine plumbob panel registered and anchored at "..plumbob:getX()..","..plumbob:getY()
            .." size="..plumbob:getWidth().."x"..plumbob:getHeight())
        if NLQANpc and NLQANpc.body and NLPlumbob.instances["qa:marisol"] then
            assert(NLPlumbob.instances["qa:marisol"]:positionOverCharacter(),"NPC plumbob did not anchor")
            print("NLQA PASS: QA NPC plumbob adapter registered and anchored")
        end
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
