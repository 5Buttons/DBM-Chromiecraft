local mod	= DBM:NewMod("Bazzalan", "DBM-Party-Classic", 9)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261030120000")
mod:SetCreatureID(11519)
mod:SetEncounterID(433)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 2818",
	"SPELL_AURA_APPLIED 2818"
)

local warningDeadlyPoison			= mod:NewTargetNoFilterAnnounce(2818, 2, nil, "RemovePoison")

local timerDeadlyPoisonCD			= mod:NewAITimer(180, 2818, nil, "RemovePoison", nil, 5, nil, DBM_COMMON_L.POISON_ICON)

function mod:OnCombatStart(delay)
	timerDeadlyPoisonCD:Start(1-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 2818 and args:IsSrcTypeHostile() then
		timerDeadlyPoisonCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 2818 and args:IsDestTypePlayer() and self:CheckDispelFilter("poison") then
		warningDeadlyPoison:Show(args.destName)
	end
end
