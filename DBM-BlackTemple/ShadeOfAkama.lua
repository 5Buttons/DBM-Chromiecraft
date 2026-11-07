local mod	= DBM:NewMod("Akama", "DBM-BlackTemple")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261030190000") --based on Cafe20241023v3
mod:SetCreatureID(22841, 23191, 23215, 23216, 23523, 23318, 23524, 23319)

mod:SetModelID(21357)

mod:RegisterCombat("combat")
mod:SetWipeTime(50)--Adds come about every 50 seconds, so require at least this long to wipe combat if they die instantly

mod:RegisterEventsInCombat(
	"UNIT_DIED"
)

mod:RegisterEvents(
	"SPELL_AURA_REMOVED 34189"
)

local warnPhase2		= mod:NewPhaseAnnounce(2)
local warnDefender		= mod:NewAnnounce("warnAshtongueDefender", 2, 41180)
local warnSorc			= mod:NewAnnounce("warnAshtongueSorcerer", 2, 40520)

local specWarnAdds		= mod:NewSpecialWarningAddsCustom(42035, "-Healer", nil, nil, 1, 2)

local timerCombatStart		= mod:NewCombatTimer(7.5) -- AC: Akama Soul Channel 7.5s after Stealth removed
local timerAddsCD		= mod:NewAddsCustomTimer("v50-60", 42035)
local timerDefenderCD		= mod:NewTimer("v30-40", "timerAshtongueDefender", 41180, nil, nil, 1)
local timerSorcCD		= mod:NewTimer("v30-35", "timerAshtongueSorcerer", 40520, nil, nil, 1)

mod.vb.sorcCount = 0
mod.vb.defenderCount = 0

--note: west is right side, east is left side, left spawns first

local function addsWestLoop(self)
	specWarnAdds:Show(DBM_COMMON_L.WEST)
	specWarnAdds:Play("killmob")
	specWarnAdds:ScheduleVoice(1, "west")
	self:Schedule(50, addsWestLoop, self)
	timerAddsCD:Start("v50-60", DBM_COMMON_L.WEST)
end

local function addsEastLoop(self)
	specWarnAdds:Show(DBM_COMMON_L.EAST)
	specWarnAdds:Play("killmob")
	specWarnAdds:ScheduleVoice(1, "east")
	self:Schedule(50, addsEastLoop, self)
	timerAddsCD:Start("v50-60", DBM_COMMON_L.EAST)
end

local function sorcLoop(self)
	self.vb.sorcCount = self.vb.sorcCount + 1
	warnSorc:Show(self.vb.sorcCount)
	self:Schedule(30, sorcLoop, self)
	timerSorcCD:Start("v30-35", self.vb.sorcCount+1)
end

local function defenderLoop(self)
	self.vb.defenderCount = self.vb.defenderCount + 1
	warnDefender:Show(self.vb.defenderCount)
	self:Schedule(30, defenderLoop, self)
	timerDefenderCD:Start("v30-40", self.vb.defenderCount+1)
end

function mod:OnCombatEnd()
	self:UnregisterShortTermEvents()
	self:Unschedule(addsWestLoop)
	self:Unschedule(addsEastLoop)
	self:Unschedule(sorcLoop)
	self:Unschedule(defenderLoop)
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 34189 and args:GetDestCreatureID() == 23191 then--Coming out of stealth (he's been activated)
		timerCombatStart:Start()
		self:RegisterShortTermEvents("SWING_DAMAGE", "SWING_MISSED")
		self:SetStage(1)
		self.vb.sorcCount = 0
		self.vb.defenderCount = 0
		-- AC: generators start on Akama Soul Channel (+7.5s); Defender/Sorcerer +2-5s, East +3s, West +10s
		self:Schedule(9.5, defenderLoop, self)
		self:Schedule(9.5, sorcLoop, self)
		self:Schedule(10.5, addsEastLoop, self)
		self:Schedule(17.5, addsWestLoop, self)
		timerDefenderCD:Start("v9.5-12.5", 1)
		timerSorcCD:Start("v9.5-12.5", 1)
		timerAddsCD:Start(10.5, DBM_COMMON_L.EAST)
		timerAddsCD:Start(17.5, DBM_COMMON_L.WEST)
	end
end

function mod:SWING_DAMAGE(_, sourceName)
	if sourceName == L.name and self.vb.phase == 1 then
		self:UnregisterShortTermEvents()
		self:SetStage(2)
		warnPhase2:Show()
		timerAddsCD:Stop()
		timerDefenderCD:Stop()
		timerSorcCD:Stop()
		self:Unschedule(addsWestLoop)
		self:Unschedule(addsEastLoop)
		self:Unschedule(sorcLoop)
		self:Unschedule(defenderLoop)
	end
end
mod.SWING_MISSED = mod.SWING_DAMAGE

function mod:UNIT_DIED(args)
	if self:GetCIDFromGUID(args.destGUID) == 22841 then
		DBM:EndCombat(self)
	end
end
