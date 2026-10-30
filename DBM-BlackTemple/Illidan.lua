local mod	= DBM:NewMod("Illidan", "DBM-BlackTemple")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20250317164800")
mod:SetCreatureID(22917, 22997)

mod:SetModelID(21135)
mod:SetUsedIcons(8)

mod:RegisterCombat("combat")

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_AURA focus target mouseover"
)

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 40904 39849 40832 40598",
	"SPELL_CAST_SUCCESS 41126 40631 41917",
	"SPELL_AURA_APPLIED 41917 41914 40585 40932 41083 40683 39869",
	"SPELL_AURA_REFRESH 40932",
	"SPELL_AURA_REMOVED 41917 41914",
	"SPELL_SUMMON 41117",
	"UNIT_DIED"
)


-- General
local timerCombatStart		= mod:NewCombatTimer(36+5) --add 5s
local berserkTimer		= mod:NewBerserkTimer(1500)

-- Stage One: You Are Not Prepared
mod:AddTimerLine(L.S1YouAreNotPrepared)
--local warnShearSoon		= mod:NewSoonAnnounce(41032, 2, nil, "Tank") -- not used on chromiecraft 20241023
local warnDrawSoul		= mod:NewSpellAnnounce(40904, 3, nil, "Tank", 2)
local warnParasite		= mod:NewTargetAnnounce(41917, 3)
local warnPhase2Soon		= mod:NewPrePhaseAnnounce(2, 3)

--[[
local specWarnShearBlock	= mod:NewSpecialWarningDefensive(41032, "Tank", nil, nil, 1, 2)
local specWarnShearTaunt	= mod:NewSpecialWarningTaunt(41032, "Tank", nil, nil, 1, 2)
]]-- not used on chromiecraft 20241023

local specWarnGTFO		= mod:NewSpecialWarningGTFO(40841, nil, nil, nil, 1, 2) -- Flame Crash / Blaze
local specWarnParasite		= mod:NewSpecialWarningYou(41917, nil, nil, nil, 1, 2)
local yellParasiteFades		= mod:NewShortFadesYell(41917)

--local timerShearCD		= mod:NewCDTimer(10, 41032, nil, "Tank", nil, 5, nil, DBM_COMMON_L.TANK_ICON) -- not used on chromiecraft 20241023
local timerDrawSoul		= mod:NewCDTimer(32, 40904, nil, "Tank", nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerFlameCrash		= mod:NewCDTimer(26, 40832, nil, nil ,nil, 3) -- 25-30 first, 26-35 after
local timerParasite		= mod:NewTargetTimer(10, 41917, nil, false, nil, 1, nil, DBM_COMMON_L.IMPORTANT_ICON)
local timerParasiteCD		= mod:NewCDTimer(25, 41917, nil, nil, nil, 1) -- 25-30

mod:AddSetIconOption("ParasiteIcon", 41917)


-- Stage Two: Flames of Azzinoth (65%)
mod:AddTimerLine(L.S2FlamesOfAzzinoth)
--Illidan Stormrage
local warnPhase2		= mod:NewPhaseAnnounce(2)
local warnBarrage		= mod:NewTargetAnnounce(40585, 3)
local warnEyebeam		= mod:NewSpellAnnounce(40018, 3)

local specWarnBarrage		= mod:NewSpecialWarningMoveAway(40585, nil, nil, nil, 1, 2)
local specWarnUncagedWrath	= mod:NewSpecialWarningDefensive(39869, nil, nil, nil, 3, 2)

local timerBarrage		= mod:NewTargetTimer(10, 40585, nil, false, nil, 3, nil, DBM_COMMON_L.DEADLY_ICON)
local timerEyebeamCD		= mod:NewCDTimer(30+19, 40018, nil, nil, nil, 2)
local timerEyebeamCast		= mod:NewBuffActiveTimer(20, 40018) --new eyebeam casting timer

--Flame of Azzinoth
local timerFlameblastCD		= mod:NewCDTimer(15, 40631, nil, nil, nil, 2) --new CD timer, blaze will cast soon after by Flames of Azzinoth


-- Stage Three: The Demon Within
mod:AddTimerLine(L.S3TheDemonWithin)
local warnPhase3		= mod:NewPhaseAnnounce(3)
local warnFlame			= mod:NewTargetAnnounce(40932, 3)
local warnPhase4Soon		= mod:NewPrePhaseAnnounce(4, 3)

local timerFlameCD		= mod:NewCDTimer(24, 40932, nil, nil, nil, 2)

-- [Stage Three: The Demon Within] Demon Form
mod:AddTimerLine(DBM:GetSpellInfo(40506))
local warnDemon			= mod:NewSpellAnnounce(40506, 3)
local warnFlameBurst		= mod:NewSpellAnnounce(41131, 3)
local warnShadowDemon		= mod:NewTargetNoFilterAnnounce(41117, 3)
local warnHuman			= mod:NewAnnounce("WarnHuman", 3, 62844, nil, nil, nil, 40506)
local timerPhaseDemon		= mod:NewPhaseTimer(9) --new timer for phase 3, 2024.10.27

local specWarnShadowDemon	= mod:NewSpecialWarningSwitch(41117, "Dps", nil, nil, 3, 2)
local timerShadowDemon		= mod:NewNextTimer(100, 41117, nil, nil, nil, 1) --new shadow demon timer
local timerNextFlameBurst	= mod:NewCDTimer(20-0.5, 41131, nil, nil, nil, 3) --corrected to 19.5s

local timerNextDemon		= mod:NewCDTimer(60+2.6, 40506, nil, nil, nil, 6, nil, DBM_COMMON_L.IMPORTANT_ICON) -- transform + 2.6s until yell
local timerNextHuman		= mod:NewTimer(60, "TimerNextHuman", 62844, nil, nil, 6, nil, nil, nil, nil, nil, nil, nil, 40506)


-- Stage Four: The Long Hunt (30%)
mod:AddTimerLine(L.S4TheLongHunt)
local warnPhase4		= mod:NewPhaseAnnounce(4)
local warnEnrage		= mod:NewSpellAnnounce(40683, 3) -- Frenzy

local timerPhase4		= mod:NewPhaseTimer(31.4)
local timerEnrage		= mod:NewBuffActiveTimer(20, 40683)
local timerNextEnrage		= mod:NewNextTimer(40, 40683, nil, nil, nil, 1)

-- Maiev Shadowsong
local warnCaged			= mod:NewSpellAnnounce(40695, 3)
local timerCaged		= mod:NewBuffActiveTimer(15, 40695, nil, nil, nil, 6)
local timerNextCage		= mod:NewCDTimer(30, 40693, nil, nil, nil, 3)


mod:AddRangeFrameOption("6/8")-- 40932: Spell is 5 yards, but give it 6 or good measure since 5 yard check is probably least precise one since nerfs. / 41917: Parasitic. REVIEW! arbitrary range

mod.vb.flamesDown = 0
mod.vb.flameBursts = 0
mod.vb.warned_preP2 = false
mod.vb.warned_preP4 = false

local lastCageWarning = 0
local parasiticDebuffName = DBM:GetSpellInfo(41917)

local parasiticDebuffFilter
do
	parasiticDebuffFilter = function(uId)
		return DBM:UnitDebuff(uId, parasiticDebuffName)
	end
end

-- AC ScheduleAbilities(PHASE_LANDING / PHASE_MAIEV)
local function startHumanTimers(self)
	timerNextDemon:Start()
	timerFlameCrash:Start(25)
	timerDrawSoul:Start()
	timerParasiteCD:Start()
	timerFlameCD:Start(25)
	if self.vb.phase == 4 then
		timerNextEnrage:Start()
		timerNextCage:Start()
	end
end

local function humanForms(self)
	warnHuman:Show()
	timerNextFlameBurst:Cancel()
	startHumanTimers(self)
end

local function cancelHumanTimers()
	timerNextDemon:Cancel()
	timerFlameCrash:Cancel()
	timerDrawSoul:Cancel()
	timerParasiteCD:Cancel()
	timerFlameCD:Cancel()
	timerNextEnrage:Cancel()
	timerEnrage:Cancel()
	timerNextCage:Cancel()
end

function mod:OnCombatStart(delay)
	self:SetStage(1)
	self.vb.flamesDown = 0
	self.vb.flameBursts = 0
	self.vb.warned_preP2 = false
	self.vb.warned_preP4 = false
	lastCageWarning = 0
	--timerShearCD:Start()
	timerFlameCrash:Start(25-delay)
	berserkTimer:Start(-delay)
	timerDrawSoul:Start(-delay)
	timerParasiteCD:Start(-delay)
	if not self:IsTrivial() then
		self:RegisterShortTermEvents(
			"SPELL_DAMAGE 40841 40611",
			"SPELL_MISSED 40841 40611",
			"UNIT_HEALTH"
		)
	end
end

function mod:OnCombatEnd()
	self:UnregisterShortTermEvents()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 40904 then
		warnDrawSoul:Show()
		timerDrawSoul:Start()
	elseif spellId == 39849 then--Throw Glaive
		self:SetStage(2)
		self.vb.flamesDown = 0
		self.vb.warned_preP2 = true
		--timerShearCD:Cancel()
		warnPhase2:Show()
		timerEyebeamCD:Start(25+1.9)
		timerFlameblastCD:Start(16.5) -- tracking for Blaze from Flames of Azzinoth

--[[	elseif spellId == 41032 then -- Shear
		warnShearSoon:Schedule(7) -- 3s (+1.5s from cast time) is good enough to plan ahead
		timerShearCD:Start()
		specWarnShearBlock:Show()
		specWarnShearBlock:Play("defensive")
]]-- not used on chromiecraft 20241023

	elseif spellId == 40832 then -- Flame Crash
		timerFlameCrash:Start()
	elseif spellId == 40598 and self.vb.phase == 3 then -- Fireball keeps going while Illidan lands, abilities start ~11s after the last one
		self:Unschedule(startHumanTimers)
		self:Schedule(11, startHumanTimers, self)
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 41126 then
		warnFlameBurst:Show()
		self.vb.flameBursts = self.vb.flameBursts + 1
		if self.vb.flameBursts < 3 then
			timerNextFlameBurst:Start()
		end
	elseif spellId == 40631 then
		timerFlameblastCD:Start() -- tracking for blaze from Flames of Azzinoth
	elseif spellId == 41917 then
		timerParasiteCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 41917 or spellId == 41914 then
		timerParasite:Start(args.destName)
		if args:IsPlayer() then
			specWarnParasite:Show()
			specWarnParasite:Play("targetyou")
			yellParasiteFades:Countdown(spellId)
		else
			warnParasite:Show(args.destName)
		end
		if self.Options.ParasiteIcon then
			self:SetIcon(args.destName, 8)
		end
		if self.Options.RangeFrame then
			if DBM:UnitDebuff("player", args.spellName) then -- You have debuff, show everyone
				DBM.RangeCheck:Show(8, nil)
			else -- You do not have debuff, only show players who do
				DBM.RangeCheck:Show(8, parasiticDebuffFilter)
			end
		end
	elseif spellId == 40585 then
		timerBarrage:Start(args.destName)
		if args:IsPlayer() then
			specWarnBarrage:Show()
			specWarnBarrage:Play("runout")
			specWarnBarrage:ScheduleVoice(1, "keepmove")
		else
			warnBarrage:Show(args.destName)
		end
	elseif spellId == 40932 then
		warnFlame:CombinedShow(0.3, args.destName)
		timerFlameCD:Start()
	elseif spellId == 41083 then
		warnShadowDemon:CombinedShow(1, args.destName)
	elseif spellId == 40683 then
		warnEnrage:Show()
		timerEnrage:Start()
		timerNextEnrage:Start(100)
--[[
	elseif spellId == 41032 then -- Shear
		if not args:IsPlayer() then
			specWarnShearTaunt:Show(args.destName)
			specWarnShearTaunt:Play("tauntboss")
		end
]]-- not used on chromiecraft 20241023

	elseif spellId == 39869 then -- Uncaged Wrath
		specWarnUncagedWrath:Show()
		specWarnUncagedWrath:Play("defensive")
	end
end
mod.SPELL_AURA_REFRESH = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 41917 or spellId == 41914 then
		timerParasite:Stop(args.destName)
		if args:IsPlayer() then
			yellParasiteFades:Cancel()
		end
		if self.Options.ParasiteIcon then
			self:SetIcon(args.destName, 0)
		end
	end
end

function mod:SPELL_SUMMON(args)
	if args.spellId == 41117 and self:AntiSpam(5, 6) then -- triggered, no SPELL_CAST_START on AC
		specWarnShadowDemon:Show()
		specWarnShadowDemon:Play("killmob")
	end
end

function mod:SPELL_DAMAGE(_, _, _, destGUID, _, _, spellId)
	if (spellId == 40841 or spellId == 40611) and destGUID == UnitGUID("player") and self:AntiSpam(4, 5) then -- Flame Crash / Blaze (Flame of Azzinoth)
		specWarnGTFO:Show()
		specWarnGTFO:Play("runaway")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 22997 then
		self.vb.flamesDown = self.vb.flamesDown + 1
		if self.vb.flamesDown >= 2 then
			self:SetStage(3)
			if self.Options.RangeFrame then
				DBM.RangeCheck:Show(6)
			end
			timerFlameblastCD:Cancel()
			timerEyebeamCD:Cancel()
			warnPhase3:Show()
		end
	end
end


function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.Pull or msg:find(L.Pull) then
		timerCombatStart:Start()
	elseif msg == L.Eyebeam or msg:find(L.Eyebeam) then
		warnEyebeam:Show()
		timerEyebeamCD:Start()
		timerEyebeamCast:Start()
	elseif msg == L.Demon or msg:find(L.Demon) then
		self.vb.flameBursts = 0
		self:Unschedule(startHumanTimers)
		cancelHumanTimers()
		timerCaged:Cancel()
		warnDemon:Show()
		timerPhaseDemon:Start(9.6)
		timerNextHuman:Start(60+9.6)
		timerNextFlameBurst:Start(7+9.6)
		timerShadowDemon:Start(30+9.6)
		self:Unschedule(humanForms)
		self:Schedule(60+9.6, humanForms, self)

-- newly added to remove phase 2 spam
	elseif (msg == L.Phase2 or msg:find(L.Phase2)) and self.vb.phase < 2 then
		timerDrawSoul:Cancel()
		timerParasiteCD:Cancel()
		timerFlameCrash:Cancel()

	elseif (msg == L.Phase4 or msg:find(L.Phase4)) and self.vb.phase < 4 then
		self:SetStage(4)
		self.vb.warned_preP4 = true
		self:Unschedule(humanForms)
		self:Unschedule(startHumanTimers)
		cancelHumanTimers()
		timerNextFlameBurst:Cancel()
		timerShadowDemon:Cancel()
		timerPhaseDemon:Cancel()
		timerNextHuman:Cancel()

		timerPhase4:Start()
		warnPhase4:Schedule(31.4)
		self:Schedule(31.4, startHumanTimers, self)

	elseif msg == L.Defeated or msg:find(L.Defeated) then
		self:Stop()
	end
end

function mod:UNIT_AURA(uId)
	if DBM:UnitDebuff(uId, 40695) and GetTime() - lastCageWarning > 15 then -- no SPELL_AURA_APPLIED for Caged on AC
		lastCageWarning = GetTime()
		self:SendSync("caged")
	end
end

function mod:UNIT_HEALTH(uId)
	local cid = self:GetUnitCreatureId(uId)
	if not self.vb.warned_preP2 and cid == 22917 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.70 then --lowered by 5%
		self.vb.warned_preP2 = true
		warnPhase2Soon:Show()
	elseif not self.vb.warned_preP4 and cid == 22917 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.35 then
		self.vb.warned_preP4 = true
		warnPhase4Soon:Show()
	end
end

function mod:OnSync(msg)
	if msg == "caged" and not timerCaged:IsStarted() then
		warnCaged:Show()
		timerCaged:Start()
		-- AC cancels all abilities, demon transform after 15s, yell 2.6s later
		cancelHumanTimers()
		timerNextDemon:Start(16.4)
	end
end
