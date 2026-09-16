NLDefinitions = {}
NLDefinitions.version = 2
NLDefinitions.careerOrder = { "tailor", "carpenter", "medic" }
NLDefinitions.careers = {
    tailor = { name = "Tailor", perk = "Tailoring", ranks = {
        "Mending Apprentice", "Neighborhood Tailor", "Pattern Maker", "Master Clothier"
    }, materials = { { "Base.RippedSheets", 6 }, { "Base.Sheet", 2 }, { "Base.Bandage", 3 } },
        shift = { name="Mend a neighborhood garment", skill=0, xp=15, credits=5 } },
    carpenter = { name = "Carpenter", perk = "Woodwork", ranks = {
        "Workshop Helper", "Repair Carpenter", "House Builder", "Master Carpenter"
    }, materials = { { "Base.Plank", 2 }, { "Base.Nails", 12 }, { "Base.Plank", 4 } },
        shift = { name="Repair a neighborhood fixture", skill=0, xp=15, credits=5 } },
    medic = { name = "Medic", perk = "Doctor", ranks = {
        "First Aid Volunteer", "Neighborhood Medic", "Clinic Lead", "Community Physician"
    }, materials = { { "Base.RippedSheets", 8 }, { "Base.Bandage", 3 }, { "Base.Bandage", 5 } },
        shift = { name="Staff the neighborhood clinic", skill=0, xp=15, credits=5 } }
}
-- Promotion requires deliveries AND the actual game skill; career XP is not skill XP.
NLDefinitions.promotions = {
    { xp = 0, skill = 0, variety = 0 }, { xp = 60, skill = 1, variety = 2 },
    { xp = 180, skill = 3, variety = 3 }, { xp = 360, skill = 5, variety = 3 }
}

-- Appearance presets use only Build 42 hair styles already shipped by the
-- game.  The server stores the preset id; clients apply the corresponding
-- native HumanVisual style without inventing arbitrary model names.
NLDefinitions.appearanceOrder = { "natural", "bob", "braided", "short" }
NLDefinitions.appearancePresets = {
    natural = { name = "Natural", femaleHair = "Long", maleHair = "Short" },
    bob = { name = "Bob cut", femaleHair = "Bob", maleHair = "Picard" },
    braided = { name = "Braided", femaleHair = "Braids", maleHair = "Cornrows" },
    short = { name = "Short", femaleHair = "Short", maleHair = "CrewCut" },
}

-- Spendable Community Rewards catalog: players earn credits through daily shifts
-- and material deliveries, and can redeem credits for items and skill books.
NLDefinitions.rewards = {
    { id = "ripped_sheets", name = "Clean Ripped Sheets (x10)", item = "Base.RippedSheets", amount = 10, credits = 10, category = "supplies", desc = "Sterilized rags for mending or emergency bandages." },
    { id = "bandages", name = "Adhesive Bandages (x5)", item = "Base.Bandage", amount = 5, credits = 15, category = "medical", desc = "Sterile dressings ready for field wound care." },
    { id = "thread", name = "Sewing Thread (x2)", item = "Base.Thread", amount = 2, credits = 15, category = "tailoring", desc = "High-tensile thread suitable for tailoring." },
    { id = "nails_box", name = "Box of Nails", item = "Base.NailsBox", amount = 1, credits = 20, category = "carpentry", desc = "A sealed box of 100 assorted construction nails." },
    { id = "needle", name = "Sewing Needle", item = "Base.Needle", amount = 1, credits = 30, category = "tailoring", desc = "A precision steel needle for garment construction." },
    { id = "scissors", name = "Tailor's Scissors", item = "Base.Scissors", amount = 1, credits = 35, category = "tailoring", desc = "Sharp heavy-duty shears for cutting fabric." },
    { id = "hammer", name = "Claw Hammer", item = "Base.Hammer", amount = 1, credits = 40, category = "carpentry", desc = "A balanced steel claw hammer." },
    { id = "wood_saw", name = "Hand Saw", item = "Base.Saw", amount = 1, credits = 45, category = "carpentry", desc = "A hardened wood saw for crafting." },
    { id = "first_aid_kit", name = "First Aid Kit", item = "Base.FirstAidKit", amount = 1, credits = 50, category = "medical", desc = "A portable medical kit packed with supplies." },
    { id = "disinfectant", name = "Bottle of Disinfectant (x2)", item = "Base.Disinfectant", amount = 2, credits = 60, category = "medical", desc = "Medical-grade alcohol solution for cleaning wounds." },
    { id = "suture_needle", name = "Suture Needle & Thread (x2)", item = "Base.SutureNeedle", amount = 2, credits = 60, category = "medical", desc = "Surgical needles with suture thread." },
    { id = "book_tailoring_1", name = "Tailoring for Beginners", item = "Base.BookTailoring1", amount = 1, credits = 75, category = "books", desc = "Volume 1 manual covering basic stitches." },
    { id = "book_carpentry_1", name = "Carpentry for Beginners", item = "Base.BookCarpentry1", amount = 1, credits = 75, category = "books", desc = "Volume 1 guide on timber framing and tool safety." },
    { id = "book_first_aid_1", name = "First Aid Essentials", item = "Base.BookFirstAid1", amount = 1, credits = 75, category = "books", desc = "Volume 1 guide covering triage and wound care." },
}
return NLDefinitions
