local mod	= DBM:NewMod(422, "DBM-Party-Classic", 7, 231)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(7800)
mod:SetEncounterID(382)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 10101 11130 11511"
)

local warningKnockAway			= mod:NewSpellAnnounce(10101, 2)
local warningActivateBomb		= mod:NewSpellAnnounce(11511, 2)

local timerKnockAwayCD			= mod:NewCDTimer("v13-14", 10101, nil, nil, nil, 2)--AC: first 3s, then 13-14s
local timerActivateBomb			= mod:NewCDTimer(20, 11511, nil, nil, nil, 2)--AC: first 10s, then 20s

function mod:OnCombatStart(delay)
	timerKnockAwayCD:Start(3-delay)
	timerActivateBomb:Start(10-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(10101, 11130) then
		warningKnockAway:Show()
		timerKnockAwayCD:Start()
	elseif args.spellId == 11511 then
		warningActivateBomb:Show()
		timerActivateBomb:Start()
	end
end
