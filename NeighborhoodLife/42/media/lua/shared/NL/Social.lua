require "NL/Domain"
NLSocial = {}
NLSocial.people = {
    marisol = { name="Marisol Vega", age=31, personality="Creative, warm, protective",
        career="tailor", female=true, friendly=6, humor=4, flirt=4,
        workLine="The tailoring bench keeps me grounded. Every repaired seam is one more useful thing in the world.",
        homeLine="I want a home with bright windows, a worktable, and enough chairs for whoever needs shelter.",
        complimentLine="That is kind of you to notice. You make this hard day feel a little lighter." },
    kenji = { name="Kenji Arakawa", age=36, personality="Reserved, practical, loyal",
        career="carpenter", female=false, friendly=3, humor=2, flirt=3,
        workLine="I reinforce what still stands. A sound door and a dry roof solve more problems than speeches do.",
        homeLine="A household needs honest rules, a stocked cupboard, and people who show up when the weather turns.",
        complimentLine="I appreciate the directness. You have a good eye for details." },
    amara = { name="Amara Okonkwo", age=29, personality="Outgoing, determined, candid",
        career="medic", female=true, friendly=5, humor=6, flirt=5,
        workLine="The clinic is all triage and small victories. I keep moving because somebody is always counting on me.",
        homeLine="Home should feel like a place where you can exhale, even when the street outside is chaos.",
        complimentLine="Keep talking like that and I might start believing you. I like your confidence." }
}
NLSocial.order={"marisol","kenji","amara"}
NLSocial.actions={introduce=true,chat=true,joke=true,ask_work=true,talk_home=true,
    compliment=true,flirt=true,date=true,date_activity=true,partner=true,breakup=true,
    apologize=true}

local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end

function NLSocial.relation(profile,id)
    profile.relationships=profile.relationships or {}
    if not profile.relationships[id] then
        profile.relationships[id]={met=false,friendship=0,trust=0,attraction=0,
            status="Stranger",lastAction=-100,lastFlirt=-100,lastCompliment=-100,
            dates=0,completedDates=0,workTalks=0,homeTalks=0,compliments=0,
            activeDate=nil,memories={}}
    end
    return profile.relationships[id]
end

function NLSocial.interact(profile,npc,action,hours,key)
    local def=NLSocial.people[npc.id]
    if not def or not NLSocial.actions[action] then return false,"Unknown interaction" end
    if npc.dead then return false,"They have died." end
    local r=NLSocial.relation(profile,npc.id)
    -- The second step of a date is an intentional immediate follow-up. Other
    -- interactions retain the normal pacing guard.
    if action~="date_activity" and hours-r.lastAction<0.25 then
        return false,"Give the conversation a little time."
    end
    if action~="introduce" and not r.met then return false,"Introduce yourself first." end
    local message
    if action=="introduce" then
        if r.met then return false,"You already know each other." end
        r.met=true; r.friendship=def.friendly; r.trust=2; r.status="Acquaintance"
        message="I'm "..def.name..". It's good to meet another survivor."
    elseif action=="chat" then
        r.friendship=r.friendship+def.friendly; r.trust=r.trust+3
        message="I'd like to hear how you've been getting on."
    elseif action=="joke" then
        r.friendship=r.friendship+def.humor
        message=def.humor>=4 and "I needed that laugh today." or "That's terrible. ...All right, a little funny."
    elseif action=="ask_work" then
        r.workTalks=(r.workTalks or 0)+1
        r.friendship=r.friendship+2; r.trust=r.trust+2
        message=def.workLine or "Work keeps me moving. I am still figuring out what that means now."
    elseif action=="talk_home" then
        r.homeTalks=(r.homeTalks or 0)+1
        r.friendship=r.friendship+2; r.trust=r.trust+3
        message=def.homeLine or "I have been thinking about what makes a place feel like home."
    elseif action=="compliment" then
        if hours-(r.lastCompliment or -100)<4 then
            return false,"Let's keep it sincere and give that a little time."
        end
        if r.friendship<20 then return false,"Let's get to know each other a little better first." end
        r.lastCompliment=hours; r.compliments=(r.compliments or 0)+1
        r.friendship=r.friendship+1; r.attraction=r.attraction+2
        message=def.complimentLine or "That is kind of you to say."
    elseif action=="apologize" then
        if r.friendship>=0 then return false,"There is nothing to apologize for." end
        r.friendship=r.friendship+3; message="Thank you for saying that."
    elseif action=="flirt" then
        if def.age<18 or npc.partner and npc.partner~=key then return false,"I'm not available for that." end
        if hours-r.lastFlirt<4 then return false,"Let's not rush this." end
        r.lastFlirt=hours
        if r.friendship<20 or r.trust<10 then
            r.friendship=r.friendship-3; message="I'd rather get to know you first."
        else
            r.attraction=r.attraction+def.flirt; message="I was hoping we'd get to spend more time together."
        end
    elseif action=="date" then
        if npc.partner and npc.partner~=key then return false,"I'm seeing someone." end
        if r.friendship<35 or r.attraction<15 then return false,"I'm not ready for a date." end
        if r.activeDate and r.activeDate.status=="active" then
            return false,"Finish your current date first."
        end
        if r.lastDate and hours-r.lastDate<24 then return false,"Let's plan another day." end
        r.lastDate=hours; r.dates=r.dates+1; r.attraction=r.attraction+5; r.trust=r.trust+5
        r.activeDate={status="active",startedAt=hours}
        message="I'd like that. Let's spend a quiet moment together."
    elseif action=="date_activity" then
        if not r.activeDate or r.activeDate.status~="active" then
            return false,"There is no active date to continue."
        end
        if hours-r.activeDate.startedAt>2 then
            return false,"The date opportunity has passed."
        end
        r.activeDate.completedAt=hours; r.activeDate.status="completed"
        r.completedDates=(r.completedDates or 0)+1
        r.friendship=r.friendship+4; r.trust=r.trust+6; r.attraction=r.attraction+3
        message="That was lovely. I feel closer to you already."
    elseif action=="partner" then
        if npc.partner then return false,"Already in a partnership." end
        if r.dates<2 or r.trust<30 or r.attraction<30 then return false,"I'm not ready to make that commitment." end
        npc.partner=key; r.status="Partner"; message="Yes. I want to build a life with you."
    elseif action=="breakup" then
        if npc.partner~=key then return false,"You are not partners." end
        npc.partner=nil; r.status="Former partner"; r.friendship=r.friendship-15; r.attraction=0
        message="I understand. I need some space."
    end
    r.friendship=clamp(r.friendship,-100,100); r.trust=clamp(r.trust,0,100); r.attraction=clamp(r.attraction,0,100)
    if r.status~="Partner" and r.status~="Former partner" then
        r.status=r.friendship>=40 and "Friend" or "Acquaintance"
    end
    r.lastAction=hours
    r.memories[#r.memories+1]={action=action,hour=hours,text=message}
    if #r.memories>12 then table.remove(r.memories,1) end
    profile.revision=profile.revision+1
    return true,message
end
return NLSocial
