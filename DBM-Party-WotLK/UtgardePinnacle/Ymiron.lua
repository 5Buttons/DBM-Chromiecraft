local mod	= DBM:NewMod("Ymiron", "DBM-Party-WotLK", 11)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20251123220131")
mod:SetCreatureID(26861)
mod:SetEncounterID(583)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 51750",
	"SPELL_CAST_START 48294 59301",
	"SPELL_AURA_APPLIED 48294 59301",
	"SPELL_AURA_REMOVED 48294 59301"
)

local warningBane		= mod:NewSpecialWarningSoon(48294, "Dps", nil, nil, 1, 2)
local specWarnBaneDispell	= mod:NewSpecialWarningDispel(48294, "MagicDispeller", nil, nil, 1, 2)

local warningScreams	= mod:NewSpellAnnounce(51750, 2)

local timerBane			= mod:NewBuffActiveTimer(5, 48294, nil, nil, nil, 5, nil, DBM_COMMON_L.MAGIC_ICON)
local timerScreams		= mod:NewBuffActiveTimer(8, 51750, nil, nil, nil, 2)

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(48294, 59301) then
		warningBane:Show()
		warningBane:Play("stopattack")
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 51750 then
		warningScreams:Show()
		timerScreams:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(48294, 59301) then
		timerBane:Start()
		specWarnBaneDispell:Show()
		specWarnBaneDispell:Play("dispelboss")
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(48294, 59301) then
		timerBane:Stop()
	end
end
