local mod	= DBM:NewMod("Kologarn", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261029213519")
mod:SetCreatureID(32930)
mod:SetEncounterID(749)
mod:SetUsedIcons(5, 6, 7, 8)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 62166 63981",
	"SPELL_AURA_APPLIED 64290 64292 64002 63355",
	"SPELL_AURA_APPLIED_DOSE 64002 63355",
	"SPELL_AURA_REMOVED 64290 64292",
	"SPELL_DAMAGE 63356 64003 63573 64006 63783 63982 63346 63976",
	"SPELL_MISSED 63356 64003 63573 64006 63783 63982 63346 63976",
	"CHAT_MSG_RAID_BOSS_WHISPER",
	"UNIT_DIED",
	"UNIT_SPELLCAST_SUCCEEDED"
)

mod:SetBossHealthInfo(
	32930, L.Health_Body,
	32934, L.Health_Right_Arm,
	32933, L.Health_Left_Arm
)

-- General
local enrageTimer				= mod:NewBerserkTimer(480)
local timerTimeForDisarmed		= mod:NewTimer(10, "achievementDisarmed")	-- 10 HC / 12 nonHC

--NOTE: Two crunch armors are setup to appear in gui twice on purpose, because they are very different mechanically. One is meant to be ignored and one is meant to be tank swap
-- Kologarn
mod:AddTimerLine(L.name)
local warnFocusedEyebeam		= mod:NewTargetNoFilterAnnounce(63346, 4)
local warnCrunchArmor			= mod:NewStackAnnounce(64002, 2, nil, "Tank|Healer")

local specWarnCrunchArmor2		= mod:NewSpecialWarningStack(64002, nil, 2, nil, 2, 1, 6)
local specWarnEyebeam			= mod:NewSpecialWarningRun(63346, nil, nil, nil, 4, 2)
local specWarnEyebeamNear		= mod:NewSpecialWarningClose(63346, nil, nil, nil, 1, 2)
local yellBeam					= mod:NewYell(63346)

local timerCrunch10				= mod:NewTargetTimer(6, 63355)
local timerNextSmash			= mod:NewCDTimer(14, 64003, nil, "Tank", nil, 5, nil, DBM_COMMON_L.TANK_ICON) -- 8s first, then 14s on AC
local timerNextEyebeam			= mod:NewCDTimer(20, 63346, nil, nil, nil, 3, nil, DBM_COMMON_L.IMPORTANT_ICON, true) -- 10s first, then 20s on AC

mod:AddSetIconOption("SetIconOnEyebeamTarget", 63346, true, false, {5})

-- Right Arm
mod:AddTimerLine(L.Health_Right_Arm)
local warnGrip					= mod:NewTargetNoFilterAnnounce(64292, 2)

local timerNextGrip				= mod:NewNextTimer(25, 62166, nil, nil, nil, 3) -- 15s first, then 25s on AC
local timerRespawnRightArm		= mod:NewTimer(50, "timerRightArm", nil, nil, nil, 1) --50s on AC

mod:AddSetIconOption("SetIconOnGripTarget", 64292, true, false, {7, 6, 5})

-- Left Arm
mod:AddTimerLine(L.Health_Left_Arm)
local timerNextShockwave		= mod:NewNextTimer(17, 63982, nil, nil, nil, 2) -- 17s first, then 17s on AC
local timerRespawnLeftArm		= mod:NewTimer(50, "timerLeftArm", nil, nil, nil, 1) --50s on AC

mod:GroupSpells(64292, 62166) -- Stone Grip aura and cast

mod.vb.disarmActive = false
local gripTargets = {}

local function armReset(self)
	self.vb.disarmActive = false
end

local function GripAnnounce(self)
	warnGrip:Show(table.concat(gripTargets, "<, >"))
	table.wipe(gripTargets)
end

function mod:OnCombatStart(delay)
	enrageTimer:Start(-delay)
	timerNextSmash:Start(8-delay)
	timerNextEyebeam:Start(10-delay)
	timerNextShockwave:Start(17-delay)
	timerNextGrip:Start(15-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(62166, 63981) then -- Stone Grip
		timerNextGrip:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(64290, 64292) then
		if self.Options.SetIconOnGripTarget then
			self:SetIcon(args.destName, 8 - #gripTargets, 10)
		end
		table.insert(gripTargets, args.destName)
		self:Unschedule(GripAnnounce)
		if #gripTargets >= 3 then
			GripAnnounce(self)
		else
			self:Schedule(0.3, GripAnnounce, self)
		end
	elseif args:IsSpellID(64002, 63355) then	-- Crunch Armor
		local amount = args.amount or 1
		if amount >= 2 then
			if args:IsPlayer() then
				specWarnCrunchArmor2:Show(amount)
				specWarnCrunchArmor2:Play("stackhigh")
			else
				warnCrunchArmor:Show(args.destName, amount)
			end
		else
			warnCrunchArmor:Show(args.destName, amount)
		end
		if self:IsDifficulty("normal10") then
			timerCrunch10:Start(args.destName)  -- We track duration timer only in 10-man since it's only 6sec and tanks don't switch.
		end
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(64290, 64292) then
		self:SetIcon(args.destName, 0)
	end
end

function mod:UNIT_DIED(args)
	if self:GetCIDFromGUID(args.destGUID) == 32934 then		-- right arm
		timerRespawnRightArm:Start()
		timerNextGrip:Cancel()
		if not self.vb.disarmActive then
			self.vb.disarmActive = true
			if self:IsDifficulty("normal10") then
				timerTimeForDisarmed:Start(12)
				self:Schedule(12, armReset, self)
			else
				timerTimeForDisarmed:Start()
				self:Schedule(10, armReset, self)
			end
		end
	elseif self:GetCIDFromGUID(args.destGUID) == 32933 then		-- left arm
		timerRespawnLeftArm:Start()
		timerNextShockwave:Cancel()
		if not self.vb.disarmActive then
			self.vb.disarmActive = true
			if self:IsDifficulty("normal10") then
				timerTimeForDisarmed:Start(12)
				self:Schedule(12, armReset, self)
			else
				timerTimeForDisarmed:Start()
				self:Schedule(10, armReset, self)
			end
		end
	end
end

function mod:SPELL_DAMAGE(_, _, _, destGUID, destName, _, spellId)
	if spellId == 63356 or spellId == 64003 or spellId == 63573 or spellId == 64006 then -- Overhead Smash (two-/one-armed) lands on his next swing, only the hit is logged reliably
		timerNextSmash:Start()
		-- AC: Smash and Sweep delay all other events by 1s. Grip/Shockwave bars are stopped while their arm is dead
		timerNextEyebeam:AddTime(1)
		if timerNextGrip:GetRemaining() > 0 then timerNextGrip:AddTime(1) end
		if timerNextShockwave:GetRemaining() > 0 then timerNextShockwave:AddTime(1) end
	elseif (spellId == 63783 or spellId == 63982) and self:AntiSpam(3, 5) then -- Shockwave, Arm Sweep cast only visible with the arm targeted
		timerNextShockwave:Start()
		timerNextSmash:AddTime(1)
		timerNextEyebeam:AddTime(1)
		if timerNextGrip:GetRemaining() > 0 then timerNextGrip:AddTime(1) end
	elseif (spellId == 63346 or spellId == 63976) and self:AntiSpam(2, 2) then
		if destGUID == UnitGUID("player") then
			specWarnEyebeam:Show()
		else
			local uId = self:GetUnitIdFromGUID(destGUID)
			if uId then
				local inRange = CheckInteractDistance(uId, 5)
				if inRange then
					specWarnEyebeamNear:Show(destName)
				end
			end
		end

	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:CHAT_MSG_RAID_BOSS_WHISPER(msg)
	if msg:find(L.FocusedEyebeam) then
		self:SendSync("EyeBeamOn", UnitName("player"))
	end
end

function mod:OnSync(msg, target)
	if msg == "EyeBeamOn" and self:AntiSpam(2, 1) then
		warnFocusedEyebeam:Show(target)
		if target == UnitName("player") then
			specWarnEyebeam:Show()
			specWarnEyebeam:Play("justrun")
			specWarnEyebeam:ScheduleVoice(1, "keepmove")
			yellBeam:Yell()
		end
		if self.Options.SetIconOnEyebeamTarget then
			self:SetIcon(target, 5, 8) -- 8-6 are taken by Stone Grip
		end
	elseif not self:IsInCombat() then
		return
	elseif msg == "EyebeamSummon" then
		timerNextEyebeam:Start()
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == GetSpellInfo(63342) then --Focused Eyebeam Summon Trigger
		self:SendSync("EyebeamSummon")
	end
end
