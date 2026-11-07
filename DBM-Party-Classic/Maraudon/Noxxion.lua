local mod	= DBM:NewMod(423, "DBM-Party-Classic", 8, 232)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(13282)
mod:SetEncounterID(422)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 10966 21707"
)

--TODO, spawns affect uppercut timer?
local warningSpawns					= mod:NewSpellAnnounce(21707, 2)
local warningUppercut				= mod:NewSpellAnnounce(10966, 2)

local timerUppercutCD				= mod:NewCDTimer(13, 10966, nil, nil, nil, 5, nil, DBM_COMMON_L.TANK_ICON)

function mod:OnCombatStart(delay)
	timerUppercutCD:Start(9-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 10966 then
		warningUppercut:Show()
		timerUppercutCD:Start()
	elseif args.spellId == 21707 then
		warningSpawns:Show()
	end
end
