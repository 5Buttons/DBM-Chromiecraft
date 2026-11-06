local mod	= DBM:NewMod("Taragaman", "DBM-Party-Classic", 9)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(11520)
mod:SetEncounterID(431)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 18072 11970"
)

local warningUppercut			= mod:NewSpellAnnounce(18072, 3, nil, "Tank", 2)
local warningFireNova			= mod:NewSpellAnnounce(11970, 3)

local timerUppercutCD			= mod:NewCDTimer(10, 18072, nil, "Tank", 2, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerFireNovaCD			= mod:NewCDTimer(10, 11970, nil, nil, nil, 2, nil, DBM_COMMON_L.HEALER_ICON)

function mod:OnCombatStart(delay)
	timerUppercutCD:Start(3-delay)
	timerFireNovaCD:Start(7-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 18072 then
		warningUppercut:Show()
		timerUppercutCD:Start()
	elseif args.spellId == 11970 then
		warningFireNova:Show()
		timerFireNovaCD:Start()
	end
end
