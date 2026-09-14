NLAspirations={milestones={
    {name="Helping Hands",deliveries=3,ranks=0,reward=15},
    {name="Community Regular",deliveries=9,ranks=1,reward=30},
    {name="Neighborhood Pillar",deliveries=24,ranks=3,reward=60}
}}
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
return NLAspirations
