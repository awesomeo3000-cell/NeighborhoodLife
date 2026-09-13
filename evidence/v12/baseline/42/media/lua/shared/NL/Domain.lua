require "NL/Definitions"
require "NL/Aspirations"
NLDomain = {}

function NLDomain.newWorld()
    return { version = NLDefinitions.version, players = {} }
end

function NLDomain.profile(world, key)
    world.players = world.players or {}
    if not world.players[key] then
        world.players[key] = { career = "tailor", careers = {}, credits = 0,
            revision = 0, day = -1, claimed = {}, outfits = {} }
    end
    local p = world.players[key]
    for _, id in ipairs(NLDefinitions.careerOrder) do
        p.careers[id] = p.careers[id] or { rank = 1, xp = 0, delivered = 0, variety = {} }
    end
    return p
end

function NLDomain.day(profile, day)
    if day > profile.day then
        profile.day, profile.claimed = day, {}
        profile.revision = profile.revision + 1
    end
end

function NLDomain.contracts(profile)
    local result = {}
    local career = NLDefinitions.careers[profile.career]
    for i, material in ipairs(career.materials) do
        result[i] = { id = profile.career .. ":" .. profile.day .. ":" .. i,
            item = material[1], amount = material[2], xp = 20, credits = 10, slot = i }
    end
    return result
end

function NLDomain.findContract(profile, id)
    for _, contract in ipairs(NLDomain.contracts(profile)) do
        if contract.id == id then return contract end
    end
end

function NLDomain.select(profile, id)
    if type(id) ~= "string" or not NLDefinitions.careers[id] then return false, "Unknown career" end
    if profile.career ~= id then
        profile.career = id
        profile.revision = profile.revision + 1
    end
    return true, "Career selected"
end

-- Call only after the authoritative adapter has removed the complete delivery.
function NLDomain.complete(profile, contract)
    if profile.claimed[contract.id] then return false, "Already delivered" end
    profile.claimed[contract.id] = true
    local progress = profile.careers[profile.career]
    progress.xp = progress.xp + contract.xp
    progress.delivered = progress.delivered + 1
    progress.variety[contract.slot] = true
    profile.credits = profile.credits + contract.credits
    profile.revision = profile.revision + 1
    NLAspirations.advance(profile)
    return true, "Delivery complete: +20 career XP, +10 community credits"
end

function NLDomain.promote(profile, skill)
    local progress = profile.careers[profile.career]
    local nextRank = NLDefinitions.promotions[progress.rank + 1]
    if not nextRank then return false, "Highest rank reached" end
    local variety = 0
    for _, done in pairs(progress.variety) do if done then variety = variety + 1 end end
    if skill < nextRank.skill or progress.xp < nextRank.xp or variety < nextRank.variety then
        return false, "Promotion needs skill " .. nextRank.skill .. ", XP " .. nextRank.xp
            .. " and " .. nextRank.variety .. " different delivery types"
    end
    progress.rank = progress.rank + 1
    profile.revision = profile.revision + 1
    NLAspirations.advance(profile)
    return true, "Promoted to " .. NLDefinitions.careers[profile.career].ranks[progress.rank]
end

function NLDomain.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = NLDomain.copy(v) end
    return result
end

return NLDomain
