local mod	= DBM:NewMod("Galdarah", "DBM-Party-WotLK", 5)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic,mythic"

mod:SetRevision("20251221224131")
mod:SetCreatureID(29306)
mod:SetEncounterID(390)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 55250 59824 59827 59829",
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_SPELLCAST_SUCCEEDED"
)

local warnPhase1		= mod:NewAnnounce("TimerPhase1", 4, "Interface\\Icons\\Spell_Shadow_ShadesOfDarkness")
local warnPhase2		= mod:NewAnnounce("TimerPhase2", 4, "Interface\\Icons\\Spell_Shadow_ShadesOfDarkness")

local specWarnSlash		= mod:NewSpecialWarningMove(59824)

local timerStomp		= mod:NewCDTimer(20, 59829)
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
	elseif args.spellId == 59827 then
		timerCharge:Start()
	elseif args.spellId == 59829 then
		timerStomp:Start()
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == "Transform" and self:AntiSpam(2, 1) then
		if self.vb.phase == 1 then
			self:SetStage(2) --rhino phase
			warnPhase2:Show()
			timerPhase1:Start()
			timerSlash:Cancel()
			timerStomp:Start()
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

function mod:CHAT_MSG_MONSTER_YELL(msg) --currently doesnt work on AC https://github.com/chromiecraft/chromiecraft/issues/8823
	if msg == L.YellPhase2_1 or msg:find(L.YellPhase2_1) or msg == L.YellPhase2_2 or msg:find(L.YellPhase2_2) then
		if self.vb.phase == 1 then
			self:SetStage(2)
			timerPhase2:Cancel()
			warnPhase2:Show()
			timerPhase1:Start()
			timerSlash:Cancel()
			timerStomp:Cancel()
			timerCharge:Cancel()
			timerStomp:Start()
			timerCharge:Start("v8-11")
		elseif self.vb.phase == 2 then
			self:SetStage(1)
			timerPhase1:Cancel()
			warnPhase1:Show()
			timerPhase2:Start()
			timerSlash:Cancel()
			timerStomp:Cancel()
			timerCharge:Cancel()
			timerSlash:Start("v11-19")
		end
	end
end
