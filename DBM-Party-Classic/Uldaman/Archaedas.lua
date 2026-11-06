local mod	= DBM:NewMod(473, "DBM-Party-Classic", 18, 239)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(2748)
mod:SetEncounterID(554)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 10252 10258",
	"SPELL_CAST_SUCCESS 6524"
)

local warningAwakenEarthenGuardians		= mod:NewSpellAnnounce(10252, 2)
local warningAwakenVaultWarder			= mod:NewSpellAnnounce(10258, 2)
local warningGroundTremor				= mod:NewSpellAnnounce(6524, 3)

local timerGroundTremorCD				= mod:NewCDTimer("v14-20", 6524, nil, nil, nil, 2)--AC: first 0-10s, then 14-20s

function mod:SPELL_CAST_START(args)
	if args.spellId == 10252 then
		warningAwakenEarthenGuardians:Show()
	elseif args.spellId == 10258 then
		warningAwakenVaultWarder:Show()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 6524 then
		warningGroundTremor:Show()
		timerGroundTremorCD:Start()
	end
end
