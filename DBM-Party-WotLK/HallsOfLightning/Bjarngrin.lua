local mod	= DBM:NewMod("Bjarngrin", "DBM-Party-WotLK", 6)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(28586)
mod:SetEncounterID(555)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 52027 52028"
)

local warningWhirlwind		= mod:NewSpellAnnounce(52027, 3)

local specWarnWhirlwind		= mod:NewSpecialWarningRun(52027, "Melee", nil, nil, 4, 2)

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(52027, 52028) then
		if self.Options.SpecWarn52027run then
			specWarnWhirlwind:Show()
			specWarnWhirlwind:Play("runout")
		else
			warningWhirlwind:Show()
		end
	end
end
