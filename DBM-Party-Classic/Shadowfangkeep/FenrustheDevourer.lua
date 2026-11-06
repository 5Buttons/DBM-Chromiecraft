local mod	= DBM:NewMod("FenrustheDevourer", "DBM-Party-Classic", 14)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(4274)
mod:SetEncounterID(469)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 7125",
	"SPELL_AURA_APPLIED 7125"
)

local warningToxicSaliva				= mod:NewTargetNoFilterAnnounce(7125, 2, nil, "RemovePoison")

local timerToxicSalivaCD				= mod:NewCDTimer("v22-45", 7125, nil, nil, nil, 3, nil, DBM_COMMON_L.POISON_ICON)

function mod:OnCombatStart()
	timerToxicSalivaCD:Start("v1-7")--AC: 1-7s, then 22-45s
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 7125 then
		timerToxicSalivaCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 7125 and self:CheckDispelFilter("poison") then
		warningToxicSaliva:Show(args.destName)
	end
end
