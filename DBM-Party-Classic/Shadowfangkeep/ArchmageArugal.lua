local mod	= DBM:NewMod("ArchmageArugal", "DBM-Party-Classic", 14)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(4275)
mod:SetEncounterID(471)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 7621 7136 7586 7587",
	"SPELL_AURA_APPLIED 7621"
)

local warningArugalsCurse			= mod:NewTargetNoFilterAnnounce(7621, 2)
local warningShadowPort				= mod:NewSpellAnnounce(7587, 2)

local timerArugalsCurseCD			= mod:NewCDTimer(25, 7621, nil, nil, nil, 3, nil, DBM_COMMON_L.CURSE_ICON)
local timerShadowPortCD				= mod:NewCDTimer(13, 7587, nil, nil, nil, 6)

function mod:OnCombatStart(delay)
	timerArugalsCurseCD:Start(7-delay)
	timerShadowPortCD:Start(3-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 7621 then
		timerArugalsCurseCD:Start()
	elseif args:IsSpellID(7136, 7586, 7587) then
		warningShadowPort:Show()
		timerShadowPortCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 7621 then
		warningArugalsCurse:Show(args.destName)
	end
end
