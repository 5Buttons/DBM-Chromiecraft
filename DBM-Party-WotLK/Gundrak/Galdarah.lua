local mod	= DBM:NewMod("Galdarah", "DBM-Party-WotLK", 5)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20261026180406")
mod:SetCreatureID(29306)
mod:SetEncounterID(390)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 55250 59824 54956 59827 55292 59829",
	"UNIT_SPELLCAST_SUCCEEDED"
)

local warnPhase1		= mod:NewAnnounce("TimerPhase1", 4, "Interface\\Icons\\Spell_Shadow_ShadesOfDarkness")
local warnPhase2		= mod:NewAnnounce("TimerPhase2", 4, "Interface\\Icons\\Spell_Shadow_ShadesOfDarkness")

local specWarnSlash		= mod:NewSpecialWarningMove(59824)

local timerStomp		= mod:NewCDTimer("v10-12", 59829)
local timerSlash		= mod:NewCDTimer("v17-19", 59824)
local timerCharge		= mod:NewCDTimer(16, 59827)
local timerPhase1		= mod:NewTimer(32, "TimerPhase1", 72262)
local timerPhase2		= mod:NewTimer(32, "TimerPhase2", 72262)

function mod:OnCombatStart()
	self:SetStage(1)
	timerSlash:Start("v11-19")
	timerPhase2:Start()
end

function mod:SPELL_CAST_SUCCESS(args)
if args.spellId == 59824 or args.spellId == 55250 then
	timerSlash:Start()
	specWarnSlash:Show()
	elseif args.spellId == 54956 or args.spellId == 59827 then
		timerCharge:Start()
	elseif args.spellId == 55292 or args.spellId == 59829 then
		timerStomp:Start()
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == "Transform" then
		self:SendSync("Transform")
	end
end

function mod:OnSync(msg)
	if msg == "Transform" and self:IsInCombat() then
		if self.vb.phase == 1 then
			self:SetStage(2) --rhino phase
			warnPhase2:Show()
			timerPhase1:Start()
			timerSlash:Cancel()
			timerStomp:Start("v7-10")
			timerCharge:Start("v8-11")
		elseif self.vb.phase == 2 then
			self:SetStage(1) --troll phase
			warnPhase1:Show()
			timerPhase2:Start()
			timerStomp:Cancel()
			timerCharge:Cancel()
			timerSlash:Start("v11-19")
		end
	end
end
