local mod	= DBM:NewMod("InterrogatorVishas", "DBM-Party-Classic", 12)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261030120000")
mod:SetCreatureID(3983)
mod:SetEncounterID(444)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 2767",
	"SPELL_AURA_APPLIED 2767"
)

local warningImmolate				= mod:NewTargetNoFilterAnnounce(2767, 2)

local timerImmolateCD				= mod:NewAITimer(180, 2767, nil, nil, nil, 3, nil, DBM_COMMON_L.MAGIC_ICON)

function mod:OnCombatStart(delay)
	timerImmolateCD:Start(1-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 2767 and args:IsSrcTypeHostile() then
		timerImmolateCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 2767 and args:IsDestTypePlayer() then
		warningImmolate:Show(args.destName)
	end
end
