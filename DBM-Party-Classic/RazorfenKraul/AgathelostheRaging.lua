local mod	= DBM:NewMod("AgathelostheRaging", "DBM-Party-Classic", 11)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261030120000")
mod:SetCreatureID(4422)
mod:SetEncounterID(883)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 30485"
)

--https://classic.wowhead.com/spell=8555/left-for-dead nani? is wowhead tripping? no mention of this in comments or guides
local warningEnrage				= mod:NewTargetNoFilterAnnounce(30485, 2)

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 30485 and args:IsDestTypeHostile() then
		warningEnrage:Show(args.destName)
	end
end
