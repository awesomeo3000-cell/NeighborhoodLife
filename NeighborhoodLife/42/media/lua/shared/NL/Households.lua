NLHouseholds = {
    taskOrder = { "tidy", "meal", "social" },
    tasks = {
        tidy = { label = "Tidy shared home", reward = 5 },
        meal = { label = "Prepare a household meal", reward = 5 },
        social = { label = "Spend time together", reward = 5 },
    },
}

function NLHouseholds.new(id, owner, home)
    return {
        id = id, name = "Neighborhood Home", owner = owner,
        home = home or { x = 0, y = 0, z = 0 }, members = {
            [owner] = { role = "owner", contribution = 0 },
        }, tasks = {}, claims = {}, revision = 1,
    }
end

function NLHouseholds.ensure(world)
    world.households = world.households or {}
    return world.households
end

function NLHouseholds.get(world, id)
    return NLHouseholds.ensure(world)[id]
end

function NLHouseholds.member(household, key)
    return household and household.members and household.members[key]
end

function NLHouseholds.addMember(household, key)
    if not household or not key or key == "" then return false, "Invalid member" end
    if household.members[key] then return false, "Already a household member" end
    household.members[key] = { role = "member", contribution = 0 }
    household.revision = (household.revision or 0) + 1
    return true, "Joined the household"
end

function NLHouseholds.removeMember(household, key)
    if not NLHouseholds.member(household, key) then return false, "Not a household member" end
    household.members[key] = nil
    household.revision = (household.revision or 0) + 1
    return true, "Left the household"
end

function NLHouseholds.completeTask(household, key, task, day)
    local definition = NLHouseholds.tasks[task]
    if not definition then return false, "Unknown household activity" end
    local member = NLHouseholds.member(household, key)
    if not member then return false, "You are not in this household" end
    household.claims = household.claims or {}
    local claim = tostring(day) .. ":" .. tostring(key) .. ":" .. task
    if household.claims[claim] then return false, "This activity is already complete today" end
    household.claims[claim] = true
    household.tasks[task] = (household.tasks[task] or 0) + 1
    member.contribution = (member.contribution or 0) + 1
    household.revision = (household.revision or 0) + 1
    return true, definition.label .. " complete: +" .. definition.reward .. " credits"
end

function NLHouseholds.memberCount(household)
    local count = 0
    for _ in pairs((household and household.members) or {}) do count = count + 1 end
    return count
end

function NLHouseholds.copySummary(household, online)
    if not household then return nil end
    local result = {
        id = household.id, name = household.name, owner = household.owner,
        home = { x = household.home.x, y = household.home.y, z = household.home.z },
        tasks = {}, members = {}, revision = household.revision,
    }
    for task, count in pairs(household.tasks or {}) do result.tasks[task] = count end
    for key, member in pairs(household.members or {}) do
        result.members[#result.members + 1] = {
            username = key, role = member.role, contribution = member.contribution or 0,
            online = online and online[key] == true or false,
        }
    end
    table.sort(result.members, function(a, b) return a.username < b.username end)
    return result
end

return NLHouseholds
