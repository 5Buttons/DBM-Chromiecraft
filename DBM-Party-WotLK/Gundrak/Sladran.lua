local mod	= DBM:NewMod("Sladran", "DBM-Party-WotLK", 5)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20251221220131")
mod:SetCreatureID(29304)
mod:SetEncounterID(383)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START",
	"SPELL_AURA_APPLIED"
)

local warningNova	= mod:NewSpellAnnounce(55081, 3)
local warningWrap	= mod:NewTargetAnnounce(55126, 4)

local timerNovaCD	= mod:NewCDTimer("v16-53", 55081, nil, nil, nil, 2)


function mod:OnCombatStart(delay)
	timerNovaCD:Start()
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(55081, 59842) then
		warningNova:Show()
		timerNovaCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(55126, 61476) then  -- Snake Wrap
		warningWrap:Show(args.destName)
	end
end