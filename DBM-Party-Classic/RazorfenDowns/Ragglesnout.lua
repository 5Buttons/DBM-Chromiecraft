local mod	= DBM:NewMod("Ragglesnout", "DBM-Party-Classic", 10)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(7354)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 12039 7645",
	"SPELL_AURA_APPLIED 7645"
)

local warningDominateMind			= mod:NewTargetNoFilterAnnounce(7645, 2)

local specWarnHeal					= mod:NewSpecialWarningInterrupt(12039, "HasInterrupt", nil, nil, 1, 2)

local timerHealCD					= mod:NewCDTimer(12, 12039, nil, nil, nil, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)
local timerDominateMindCD			= mod:NewCDTimer(15, 7645, nil, nil, nil, 3)

function mod:OnCombatStart(delay)
	timerDominateMindCD:Start(9-delay)
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 12039 and args:IsSrcTypeHostile() then
		timerHealCD:Start()
		if self:CheckInterruptFilter(args.sourceGUID, false, true) then
			specWarnHeal:Show(args.sourceName)
			specWarnHeal:Play("kickcast")
		end
	elseif args.spellId == 7645 then
		timerDominateMindCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 7645 then
		warningDominateMind:Show(args.destName)
	end
end
