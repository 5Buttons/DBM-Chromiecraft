local mod	= DBM:NewMod(480, "DBM-Party-Classic", 19, 240)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(5775)
mod:SetEncounterID(591)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 8142"
)

local warnVines			= mod:NewSpellAnnounce(8142, 2)

local timerVinesCD		= mod:NewCDTimer("v10-13", 8142, nil, nil, nil, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)--AC: first 3-5s, then 10-13s

function mod:OnCombatStart(--[[delay]])
	timerVinesCD:Start("v3-5")
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 8142 and args:IsSrcTypeHostile() then
		warnVines:Show(args.sourceName)
		timerVinesCD:Start()
	end
end
