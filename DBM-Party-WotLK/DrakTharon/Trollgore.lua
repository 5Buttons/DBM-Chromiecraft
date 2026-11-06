local mod	= DBM:NewMod("Trollgore", "DBM-Party-WotLK", 4)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20261105120000")
mod:SetCreatureID(26630)
mod:SetEncounterID(369)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 49555 59807",
	"SPELL_CAST_SUCCESS 49380 59803"
)

local warnConsume		= mod:NewSpellAnnounce(59803,1)

local timerExplosionCD	= mod:NewVarTimer("v15-19", 49555)
local timerNextConsume	= mod:NewNextTimer(15, 59803)

function mod:OnCombatStart(delay)
	timerExplosionCD:Start(35-delay)
	timerNextConsume:Start()
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(49555, 59807) then
		timerExplosionCD:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(49380, 59803) and self:AntiSpam(1) then
		warnConsume:Show()
		timerNextConsume:Start()
	end
end
