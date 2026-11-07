local mod	= DBM:NewMod(429, "DBM-Party-Classic", 8, 232)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(12203)
mod:SetEncounterID(426)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 21808",
	"SPELL_CAST_SUCCESS 10101 5568"
)

--TODO, verify timers further, in classic timers are never very static
local warningLandSlide				= mod:NewSpellAnnounce(21808, 2)
local warningKnockAway				= mod:NewSpellAnnounce(10101, 2)
local warningTrample				= mod:NewSpellAnnounce(5568, 2)

-- local specWarnWrath					= mod:NewSpecialWarningInterrupt(21807, "HasInterrupt", nil, nil, 1, 2)

local timerLandslideCD				= mod:NewCDTimer(25, 21808, nil, nil, nil, 1)
local timerKnockAwayCD				= mod:NewCDTimer(12, 10101, nil, nil, nil, 2)
local timerTrampleCD				= mod:NewCDTimer(8, 5568, nil, nil, nil, 2)

function mod:OnCombatStart(delay)
	timerTrampleCD:Start(3-delay)
	timerKnockAwayCD:Start(3-delay)
	timerLandslideCD:Start(12-delay)
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 21808 then
		warningLandSlide:Show()
		timerLandslideCD:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 10101 then
		warningKnockAway:Show()
		timerKnockAwayCD:Start()
	elseif args.spellId == 5568 and args:IsSrcTypeHostile() then
		warningTrample:Show()
		timerTrampleCD:Start()
	end
end
