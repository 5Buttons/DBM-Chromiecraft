local mod	= DBM:NewMod("Eck", "DBM-Party-WotLK", 5)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20261105120000")
mod:SetCreatureID(29932)
mod:SetEncounterID(1988)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
)

local enrageTimer	= mod:NewBerserkTimer(90)

function mod:OnCombatStart(delay)
	enrageTimer:Start(90 - delay)
end
