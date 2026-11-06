local mod	= DBM:NewMod("PlaguemawtheRotting", "DBM-Party-Classic", 10)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(7356)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 12946",
	"SPELL_AURA_APPLIED 12946"
)

local specWarnPutridStench			= mod:NewSpecialWarningDispel(12946, "RemoveDisease", nil, nil, 1, 2)

local timerPutridStenchCD			= mod:NewCDTimer(15, 12946, nil, nil, nil, 5, nil, DBM_COMMON_L.DISEASE_ICON)

function mod:OnCombatStart(delay)
	timerPutridStenchCD:Start(8-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 12946 then
		timerPutridStenchCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 12946 and self:CheckDispelFilter("disease") then
		specWarnPutridStench:Show(args.destName)
		specWarnPutridStench:Play("helpdispel")
	end
end
