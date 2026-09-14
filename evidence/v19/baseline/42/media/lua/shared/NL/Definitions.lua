NLDefinitions = {}
NLDefinitions.version = 2
NLDefinitions.careerOrder = { "tailor", "carpenter", "medic" }
NLDefinitions.careers = {
    tailor = { name = "Tailor", perk = "Tailoring", ranks = {
        "Mending Apprentice", "Neighborhood Tailor", "Pattern Maker", "Master Clothier"
    }, materials = { { "Base.RippedSheets", 6 }, { "Base.Sheet", 2 }, { "Base.Bandage", 3 } } },
    carpenter = { name = "Carpenter", perk = "Woodwork", ranks = {
        "Workshop Helper", "Repair Carpenter", "House Builder", "Master Carpenter"
    }, materials = { { "Base.Plank", 2 }, { "Base.Nails", 12 }, { "Base.Plank", 4 } } },
    medic = { name = "Medic", perk = "Doctor", ranks = {
        "First Aid Volunteer", "Neighborhood Medic", "Clinic Lead", "Community Physician"
    }, materials = { { "Base.RippedSheets", 8 }, { "Base.Bandage", 3 }, { "Base.Bandage", 5 } } }
}
-- Promotion requires deliveries AND the actual game skill; career XP is not skill XP.
NLDefinitions.promotions = {
    { xp = 0, skill = 0, variety = 0 }, { xp = 60, skill = 1, variety = 2 },
    { xp = 180, skill = 3, variety = 3 }, { xp = 360, skill = 5, variety = 3 }
}
return NLDefinitions
