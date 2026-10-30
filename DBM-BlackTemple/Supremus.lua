local mod	= DBM:NewMod("Supremus", "DBM-BlackTemple")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261030190000")
mod:SetCreatureID(22898)
mod:SetModelID(21145)
mod:SetUsedIcons(8)
mod:SetHotfixNoticeRev(20230108000000)
mod:SetMinSyncRevision(20230108000000)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"CHAT_MSG_RAID_BOSS_EMOTE"
)

-- General
local warnPhase				= mod:NewAnnounce("WarnPhase", 4, 42052)

local timerPhase			= mod:NewTimer(60, "TimerPhase", 42052, nil, nil, 6)
local berserkTimer			= mod:NewBerserkTimer(900)

local timerFixate			= mod:NewTimer(10, "Fixate", nil, nil, nil, 1)

-- Stage One: Tank Phasse
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1)..": "..L.name)
local specWarnMolten		= mod:NewSpecialWarningMove(40265, nil, nil, nil, 1, 2)
-- Stage Two: Kite Phase
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2)..": "..DBM:GetSpellInfo(68987))
local warnFixate			= mod:NewTargetNoFilterAnnounce(41976, 3)

local specWarnVolcano		= mod:NewSpecialWarningMove(42052, nil, nil, nil, 1, 2)
local specWarnFixate		= mod:NewSpecialWarningRun(41976, nil, nil, nil, 4, 2)

mod:AddBoolOption("KiteIcon", true)

mod.vb.lastTarget = "None"

local function ScanTarget(self)
	local target, uId = self:GetBossTarget(22898)
	if target then
		if self.vb.lastTarget ~= target then
			self.vb.lastTarget = target
			if UnitIsUnit(uId, "player") and not self:IsTrivial() then
				specWarnFixate:Show()
				specWarnFixate:Play("justrun")
				specWarnFixate:ScheduleVoice(1, "keepmove")
			else
				warnFixate:Show(target)
			end
			if self.Options.KiteIcon then
				self:SetIcon(target, 8)
			end
		end
	end
end

function mod:OnCombatStart(delay)
	self:SetStage(1)
	berserkTimer:Start(-delay)
	timerPhase:Start(-delay, L.Kite)
	self.vb.lastTarget = "None"
	if not self:IsTrivial() then
		self:RegisterShortTermEvents(
			"SPELL_DAMAGE 40265 42052",
			"SPELL_MISSED 40265 42052"
		)
	end
end

function mod:OnCombatEnd()
	self:UnregisterShortTermEvents()
	if self.vb.lastTarget ~= "None" then
		self:SetIcon(self.vb.lastTarget, 0)
	end
end

function mod:SPELL_DAMAGE(_, _, _, destGUID, _, _, spellId)
	if spellId == 40265 and destGUID == UnitGUID("player") and self:AntiSpam(4, 1) and not self:IsTrivial() then
		specWarnMolten:Show()
		specWarnMolten:Play("runaway")
	elseif spellId == 42052 and destGUID == UnitGUID("player") and self:AntiSpam(4, 2) and not self:IsTrivial() then
		specWarnVolcano:Show()
		specWarnVolcano:Play("runaway")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.PhaseTank or msg:find(L.PhaseTank) then
		self:SetStage(1)
		warnPhase:Show(L.Tank)
		timerPhase:Start(L.Kite)
		timerFixate:Stop()
		self:Unschedule(ScanTarget)
		if self.vb.lastTarget ~= "None" then
			self:SetIcon(self.vb.lastTarget, 0)
			self.vb.lastTarget = "None"
		end
	elseif msg == L.ChangeTarget or msg:find(L.ChangeTarget) then
		if self:GetStage(1) then
			self:SetStage(2)
			warnPhase:Show(L.Kite)
			timerPhase:Start(L.Tank)
			if self:IsMelee() and not self:IsTrivial() then
				specWarnFixate:Show()
				specWarnFixate:Play("justrun")
			end
		end
		timerFixate:Start()
		self:Unschedule(ScanTarget)
		self:Schedule(0.5, ScanTarget, self)
	end
end
