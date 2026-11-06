local mod	= DBM:NewMod("NovosTheSummoner", "DBM-Party-WotLK", 4)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,heroic"

mod:SetRevision("20261105120000")
mod:SetCreatureID(26631)
mod:SetEncounterID(371)

mod:RegisterCombat("yell", L.YellPull)
mod:RegisterKill("yell", L.YellKill)
mod:SetWipeTime(25)

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 50089 59856 49034 59854",
	"CHAT_MSG_MONSTER_YELL"
)

local WarnCrystalHandler		= mod:NewAddsLeftAnnounce(49179, 2, 59910)
local warnPhase2				= mod:NewPhaseAnnounce(2)
local warnCurseTarget			= mod:NewTargetAnnounce(59856)

local specwarnCurse				= mod:NewSpecialWarningDispel(59856, "RemoveCurse")
local specwarnSnow				= mod:NewSpecialWarningMove(59854)

local timerCrystalHandler		= mod:NewNextTimer(16, 49179, nil, nil, nil, 1, 59910, DBM_COMMON_L.DAMAGE_ICON)
local timerNextCurse			= mod:NewCDTimer("v8-16", 59856)

mod.vb.CrystalHandlers = 4

function mod:OnCombatStart(delay)
	self:SetStage(1)
	timerCrystalHandler:Start(16-delay)
	self.vb.CrystalHandlers = 4
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.HandlerYell then
		self.vb.CrystalHandlers = self.vb.CrystalHandlers - 1
		WarnCrystalHandler:Show(self.vb.CrystalHandlers)
		if self.vb.CrystalHandlers > 0 then
			timerCrystalHandler:Start()
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	-- AC never says the stage 2 yell; Blizzard/Wrath of Misery are only cast in stage 2
	if self:GetStage(1) then
		self:SetStage(2)
		warnPhase2:Show()
	end
	if args:IsSpellID(50089, 59856) then
		warnCurseTarget:Show(args.destName)
		specwarnCurse:Show()
		timerNextCurse:Start()
	elseif args:IsSpellID(49034, 59854) and self:AntiSpam(1,2) then
		specwarnSnow:Show()
	end
end
