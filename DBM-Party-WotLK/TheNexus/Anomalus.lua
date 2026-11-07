local mod	= DBM:NewMod("Anomalus", "DBM-Party-WotLK", 8)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20261105120000")
mod:SetCreatureID(26763)
mod:SetEncounterID(522)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_SUMMON 47743",
	"SPELL_AURA_APPLIED 47748",
	"SPELL_AURA_REMOVED 47748"
)

local warningRiftSoon	= mod:NewSoonAnnounce(47743, 2)
local warningRiftNow	= mod:NewSpellAnnounce(47743, 3)

-- AC: rifts are timed (25s normal / 15s heroic, first and repeat), boss timers pause while Rift Shield (47748) is up
local function riftInterval(self)
	return self:IsDifficulty("normal5") and 25 or 15
end

function mod:OnCombatStart(delay)
	warningRiftSoon:Schedule(riftInterval(self) - 5 - delay)
end

function mod:SPELL_SUMMON(args)
	if args.spellId == 47743 then
		warningRiftNow:Show()
		warningRiftSoon:Cancel()
		warningRiftSoon:Schedule(riftInterval(self) - 5)
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 47748 then
		warningRiftSoon:Cancel()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 47748 then
		warningRiftSoon:Cancel()
		warningRiftSoon:Schedule(riftInterval(self) - 5)
	end
end
