local mod	= DBM:NewMod(463, "DBM-Party-Classic", 17, 237)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261030120000")
mod:SetCreatureID(5709)
mod:SetEncounterID(493)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 12890 12884 11876",
	"SPELL_AURA_APPLIED 12890"
)

local warningDeepSlumber			= mod:NewTargetNoFilterAnnounce(12890, 2)
local warningAcidBreath				= mod:NewSpellAnnounce(12884, 2)
local warningWarStomp				= mod:NewSpellAnnounce(11876, 2)

local timerDeepSlumberCD			= mod:NewAITimer(180, 12890, nil, nil, nil, 3, nil, DBM_COMMON_L.MAGIC_ICON)
local timerAcidBreathCD				= mod:NewAITimer(180, 12884, nil, nil, nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerWarStompCD				= mod:NewAITimer(180, 11876, nil, nil, nil, 2)

function mod:OnCombatStart(delay)
	timerDeepSlumberCD:Start(1-delay)
	timerAcidBreathCD:Start(1-delay)
	timerWarStompCD:Start(1-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 12890 then
		timerDeepSlumberCD:Start()
	elseif args.spellId == 12884 then
		warningAcidBreath:Show()
		timerAcidBreathCD:Start()
	elseif args.spellId == 11876 and args:IsSrcTypeHostile() then
		warningWarStomp:Show()
		timerWarStompCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 12890 then
		warningDeepSlumber:Show(args.destName)
	end
end
