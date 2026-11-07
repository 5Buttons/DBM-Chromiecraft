local mod	= DBM:NewMod(484, "DBM-Party-Classic", 20, 241)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(8127)
mod:SetEncounterID(595)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 11895 11899 8376",
	"SPELL_CAST_SUCCESS 11894"
)

--TODO, Totems on shared timer?
--TODO, tone down special warnings if they are too much. They might be more than people are used to/want in classic
local warningEarthgrabTotem			= mod:NewSpellAnnounce(8376, 2)
local warningHealingWard			= mod:NewSpellAnnounce(11899, 4)

local specWarnHealingWaveSelf			= mod:NewSpecialWarningInterrupt(11895, "HasInterrupt", nil, nil, 1, 2)
local specWarnMinions					= mod:NewSpecialWarningSwitch(11894, "Dps", nil, nil, 1, 2)

function mod:SPELL_CAST_START(args)
	if args.spellId == 11895 then
		if self:CheckInterruptFilter(args.sourceGUID, false, true) then
			specWarnHealingWaveSelf:Show(args.sourceName)
			specWarnHealingWaveSelf:Play("kickcast")
		end
	elseif args.spellId == 8376 and args:IsSrcTypeHostile() then
		warningEarthgrabTotem:Show()
	elseif args.spellId == 11899 and args:IsSrcTypeHostile() then
		warningHealingWard:Show()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 11894 then
		specWarnMinions:Show()
		specWarnMinions:Play("killmob")
	end
end
