local mod = DBM:NewMod(562, "DBM-Party-BC", 14, 257)
local L = mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(17977)

mod:SetModelID(19438)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 34716",
	"SPELL_SUMMON 34730"
)

local warnTreants	= mod:NewSpellAnnounce(34727, 3)
local warnStomp		= mod:NewSpellAnnounce(34716, 4)

local timerTreants	= mod:NewNextTimer(40, 34727, nil, nil, nil, 1)
local timerStomp	= mod:NewBuffActiveTimer(5, 34716, nil, nil, nil, 3)

function mod:OnCombatStart(delay)
	timerTreants:Start(20-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 34716 then
		warnStomp:Show()
		timerStomp:Start()
	end
end

function mod:SPELL_SUMMON(args)
	if args.spellId == 34730 then
		warnTreants:Show()
		timerTreants:Start()
	end
end
