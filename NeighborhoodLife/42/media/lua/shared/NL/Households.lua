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
        }, tasks = {}, claims = {}, storage = {}, storageEntries = {}, furnishing = nil, revision = 1,
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

function NLHouseholds.transferOwner(household, from, target)
    if not household or household.owner ~= from then
        return false, "Only the household owner can transfer ownership"
    end
    if type(target) ~= "string" or target == "" or target == from then
        return false, "Choose another household member"
    end
    local current = NLHouseholds.member(household, from)
    local nextOwner = NLHouseholds.member(household, target)
    if not nextOwner then return false, "Ownership can only go to a member" end
    current.role = "member"
    nextOwner.role = "owner"
    household.owner = target
    household.revision = (household.revision or 0) + 1
    return true, "Household ownership transferred to " .. target
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

function NLHouseholds.storageCount(household, itemType)
    if not household or type(itemType) ~= "string" then return 0 end
    return math.max(0, math.floor(tonumber((household.storage or {})[itemType]) or 0))
end

function NLHouseholds.storageTotal(household)
    local total = 0
    for _, count in pairs((household and household.storage) or {}) do
        total = total + math.max(0, math.floor(tonumber(count) or 0))
    end
    return total
end

local function cleanText(value, limit)
    if type(value) ~= "string" then return nil end
    if #value == 0 or #value > (limit or 100) then return nil end
    return value
end

local function cleanNumber(value, minimum, maximum)
    value = tonumber(value)
    if not value then return nil end
    value = math.floor(value * 1000 + 0.5) / 1000
    if minimum and value < minimum then value = minimum end
    if maximum and value > maximum then value = maximum end
    return value
end

function NLHouseholds.normalizeStorageEntry(itemType, value)
    value = type(value) == "table" and value or {}
    return {
        item = cleanText(value.item or itemType, 100) or itemType,
        name = cleanText(value.name, 100),
        category = cleanText(value.category, 60),
        container = cleanText(value.container, 60),
        condition = cleanNumber(value.condition, 0, 100),
        maxCondition = cleanNumber(value.maxCondition, 0, 100),
        usedDelta = cleanNumber(value.usedDelta, 0, 1),
    }
end

function NLHouseholds.copyStorageDetails(household)
    local result = {}
    for itemType, entries in pairs((household and household.storageEntries) or {}) do
        if type(entries) == "table" then
            for _, entry in ipairs(entries) do
                local copy = NLHouseholds.normalizeStorageEntry(itemType, entry)
                copy.item = itemType
                result[#result + 1] = copy
            end
        end
    end
    table.sort(result, function(a, b)
        return tostring(a.item) .. tostring(a.name or "") < tostring(b.item) .. tostring(b.name or "")
    end)
    return result
end

function NLHouseholds.store(household, itemType, amount, details)
    if not household or type(itemType) ~= "string" or itemType == "" then
        return false, "Invalid storage item"
    end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return false, "Storage amount must be positive" end
    if NLHouseholds.storageTotal(household) + amount > 500 then
        return false, "Household storage is full"
    end
    household.storage = household.storage or {}
    household.storageEntries = household.storageEntries or {}
    household.storage[itemType] = NLHouseholds.storageCount(household, itemType) + amount
    local entries = household.storageEntries[itemType] or {}
    for index = 1, amount do
        entries[#entries + 1] = NLHouseholds.normalizeStorageEntry(itemType,
            type(details) == "table" and details[index] or nil)
    end
    household.storageEntries[itemType] = entries
    household.revision = (household.revision or 0) + 1
    return true, "Stored " .. amount .. " " .. itemType .. " in shared storage"
end

function NLHouseholds.retrieve(household, itemType, amount)
    if not household or type(itemType) ~= "string" or itemType == "" then
        return false, "Invalid storage item"
    end
    amount = math.floor(tonumber(amount) or 0)
    local available = NLHouseholds.storageCount(household, itemType)
    if amount < 1 then return false, "Storage amount must be positive" end
    if available < amount then
        return false, "Shared storage has only " .. available .. " " .. itemType
    end
    household.storage = household.storage or {}
    household.storageEntries = household.storageEntries or {}
    local entries = household.storageEntries[itemType] or {}
    local removedDetails = {}
    for _ = 1, amount do
        if #entries > 0 then removedDetails[#removedDetails + 1] = table.remove(entries) end
    end
    if #entries == 0 then household.storageEntries[itemType] = nil end
    household.storage[itemType] = available - amount
    if household.storage[itemType] == 0 then household.storage[itemType] = nil end
    household.revision = (household.revision or 0) + 1
    return true, "Retrieved " .. amount .. " " .. itemType .. " from shared storage", removedDetails
end

function NLHouseholds.copyStorage(household)
    if not household then return nil end
    local result = {}
    for itemType, amount in pairs(household.storage or {}) do
        local count = NLHouseholds.storageCount(household, itemType)
        if count > 0 then result[itemType] = count end
    end
    return result
end

function NLHouseholds.copySummary(household, online)
    if not household then return nil end
    local result = {
        id = household.id, name = household.name, owner = household.owner,
        home = { x = household.home.x, y = household.home.y, z = household.home.z },
        furnishing = household.furnishing and {
            kind = household.furnishing.kind, x = household.furnishing.x,
            y = household.furnishing.y, z = household.furnishing.z,
            sprite = household.furnishing.sprite,
        } or nil,
        tasks = {}, storage = NLHouseholds.copyStorage(household),
        storageDetails = NLHouseholds.copyStorageDetails(household), members = {}, revision = household.revision,
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
