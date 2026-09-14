-- Build 42's mod loader reliably discovers this root server entry point.
-- Keep domain implementations in NL/ while explicitly registering the
-- production command handlers on dedicated servers as well as local worlds.
if isClient() then return end
require "NL/Authority"
require "NL/SocialAuthority"
require "NL/NpcAuthority"
require "NL/HouseholdAuthority"

-- The required domain modules register their own command handlers. Keeping
-- registration in one place avoids duplicate authority calls when Build 42
-- discovers both this root file and the nested module files.
