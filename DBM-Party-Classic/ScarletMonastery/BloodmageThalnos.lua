local mod	= DBM:NewMod("BloodmageThalnos", "DBM-Party-Classic", 12)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(4543)
mod:SetEncounterID(445)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 8814",
	"SPELL_CAST_SUCCESS 12470"
)

local warningFlameSpike				= mod:NewSpellAnnounce(8814, 2)
local warningFireNova				= mod:NewSpellAnnounce(12470, 2)

local timerFlameSpikeCD				= mod:NewCDTimer(20, 8814, nil, nil, nil, 3)

function mod:OnCombatStart(delay)
	timerFlameSpikeCD:Start(7-delay)
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 8814 then
		warningFlameSpike:Show()
		timerFlameSpikeCD:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 12470 then
		warningFireNova:Show()
	end
end
