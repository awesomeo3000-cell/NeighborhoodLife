NLAspirations={milestones={
    {name="Helping Hands",deliveries=3,ranks=0,reward=15},
    {name="Community Regular",deliveries=9,ranks=1,reward=30},
    {name="Neighborhood Pillar",deliveries=24,ranks=3,reward=60}
},homeMilestones={
    {name="First Nest",tasks=1,reward=5},
    {name="Shared Routine",tasks=3,reward=10},
    {name="Household Heart",tasks=6,reward=20}
},homeTasks={tidy=true,meal=true,social=true}}
function NLAspirations.progress(profile)
    local deliveries,ranks=0,0
    for _,career in pairs(profile.careers) do
        deliveries=deliveries+career.delivered
        ranks=ranks+career.rank-1
    end
    return deliveries,ranks
end
function NLAspirations.advance(profile)
    profile.aspiration=profile.aspiration or {stage=1}
    local state=profile.aspiration
    local deliveries,ranks=NLAspirations.progress(profile)
    local reward=0
    while NLAspirations.milestones[state.stage] do
        local milestone=NLAspirations.milestones[state.stage]
        if deliveries<milestone.deliveries or ranks<milestone.ranks then break end
        reward=reward+milestone.reward
        state.stage=state.stage+1
    end
    if reward>0 then
        profile.credits=profile.credits+reward
        profile.revision=profile.revision+1
    end
    return reward
end
function NLAspirations.label(profile)
    local stage=profile.aspiration and profile.aspiration.stage or 1
    local m=NLAspirations.milestones[stage]
    if not m then return "Aspiration complete: Neighborhood Pillar" end
    local deliveries,ranks=NLAspirations.progress(profile)
    return m.name..": "..math.min(deliveries,m.deliveries).."/"..m.deliveries
        .." deliveries, "..math.min(ranks,m.ranks).."/"..m.ranks.." promotions (+"..m.reward.." credits)"
end

function NLAspirations.homeProgress(profile)
    local activities = profile and profile.homeActivities or {}
    local total = 0
    for task, _ in pairs(NLAspirations.homeTasks) do
        total = total + math.max(0, math.floor(tonumber(activities[task]) or 0))
    end
    return total
end

function NLAspirations.advanceHome(profile)
    if not profile then return 0 end
    profile.homeAspiration = profile.homeAspiration or {stage=1}
    local state = profile.homeAspiration
    local tasks = NLAspirations.homeProgress(profile)
    local reward = 0
    while NLAspirations.homeMilestones[state.stage] do
        local milestone = NLAspirations.homeMilestones[state.stage]
        if tasks < milestone.tasks then break end
        reward = reward + milestone.reward
        state.stage = state.stage + 1
    end
    if reward > 0 then
        profile.credits = profile.credits + reward
        profile.revision = profile.revision + 1
    end
    return reward
end

function NLAspirations.recordHomeActivity(profile, task)
    if not profile or not NLAspirations.homeTasks[task] then return 0 end
    profile.homeActivities = profile.homeActivities or {}
    profile.homeActivities[task] = math.max(0, math.floor(tonumber(profile.homeActivities[task]) or 0)) + 1
    profile.homeActivities.total = NLAspirations.homeProgress(profile)
    profile.revision = profile.revision + 1
    return NLAspirations.advanceHome(profile)
end

function NLAspirations.homeLabel(profile)
    local stage = profile and profile.homeAspiration and profile.homeAspiration.stage or 1
    local milestone = NLAspirations.homeMilestones[stage]
    local tasks = NLAspirations.homeProgress(profile)
    if not milestone then return "Home aspiration complete: Household Heart" end
    return milestone.name..": "..math.min(tasks, milestone.tasks).."/"..milestone.tasks
        .." household activities (+"..milestone.reward.." credits)"
end
return NLAspirations
