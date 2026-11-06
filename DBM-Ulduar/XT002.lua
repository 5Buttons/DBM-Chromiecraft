local mod	= DBM:NewMod("XT002", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")
mod:SetCreatureID(33293)
mod:SetEncounterID(747)
mod:SetUsedIcons(1, 2)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 62776",
	"SPELL_AURA_APPLIED 62775 63018 65121 63024 64234 63849 65737 64193",
	"SPELL_AURA_REMOVED 63018 65121 63024 64234 63849",
	"SPELL_DAMAGE 64208 64206",
	"SPELL_MISSED 64208 64206"
)

-- General
local enrageTimer					= mod:NewBerserkTimer(600)
local timerAchieve					= mod:NewAchievementTimer(205, 2937)

mod:AddRangeFrameOption(12, nil, true)

-- Stage One
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1))
local warnLightBomb					= mod:NewTargetNoFilterAnnounce(65121, 3)
local warnGravityBomb				= mod:NewTargetNoFilterAnnounce(64234, 3)

local specWarnTympanicTantrum		= mod:NewSpecialWarningSpell(62776, nil, nil, nil, 1, 2)
local specWarnLightBomb				= mod:NewSpecialWarningMoveAway(65121, nil, nil, nil, 1, 2)
local yellLightBomb					= mod:NewYell(65121)
local specWarnGravityBomb			= mod:NewSpecialWarningMoveAway(64234, nil, nil, nil, 1, 2)
local yellGravityBomb				= mod:NewYell(64234)

local timerTympanicTantrumCast		= mod:NewCastTimer(62776)
local timerTympanicTantrum			= mod:NewBuffActiveTimer(8, 62776, nil, nil, nil, 5, nil, DBM_COMMON_L.HEALER_ICON)
local timerTympanicTantrumCD		= mod:NewCDTimer(60, 62776, nil, nil, nil, 2, nil, DBM_COMMON_L.HEALER_ICON, nil, 3) -- 60s on AC

local timerLightBomb				= mod:NewTargetTimer(9, 65121, nil, nil, nil, 3)
local timerGravityBomb				= mod:NewTargetTimer(9, 64234, nil, nil, nil, 3)
local timerLightBombCD				= mod:NewCDTimer(20, 65121, nil, false, nil, 3) -- AC: 16s (25) / 20s (10)
local timerGravityBombCD			= mod:NewCDTimer(20, 64234, nil, false, nil, 3) -- AC: 16s (25) / 20s (10)

mod:AddSetIconOption("SetIconOnLightBombTarget", 65121, true, false, {1})
mod:AddSetIconOption("SetIconOnGravityBombTarget", 64234, true, false, {2})

-- Stage Two
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2))
local timerHeart					= mod:NewCastTimer(30, 63849, nil, nil, nil, 6, nil, DBM_COMMON_L.DAMAGE_ICON)

-- Hard Mode
mod:AddTimerLine(DBM_COMMON_L.HEROIC_ICON..DBM_CORE_L.HARD_MODE)
local specWarnConsumption			= mod:NewSpecialWarningGTFO(64206, nil, nil, nil, 1, 8)--Hard mode void zone dropped by Gravity Bomb

function mod:OnCombatStart(delay)
	self:SetStage(1)
	enrageTimer:Start(-delay)
	timerAchieve:Start()
	timerTympanicTantrumCD:Start(60-delay)
	local is25 = self:IsDifficulty("normal25")
	timerLightBombCD:Start((is25 and 9 or 11)-delay)
	timerGravityBombCD:Start((is25 and 18 or 21)-delay)
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show(12)
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 62776 then					-- Tympanic Tantrum (aoe damage + daze)
		specWarnTympanicTantrum:Show()
		specWarnTympanicTantrum:Play("aesoon")
		timerTympanicTantrumCast:Start()
		timerTympanicTantrumCD:Start()
		timerLightBombCD:AddTime(10)		-- AC: DelayEvents(10s, GROUP_SEARING_GRAVITY)
		timerGravityBombCD:AddTime(10)
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 62775 and args.auraType == "DEBUFF" then	-- Tympanic Tantrum
		timerTympanicTantrum:Start()
	elseif args:IsSpellID(63018, 65121) then	-- Light Bomb
		if args:IsPlayer() then
			specWarnLightBomb:Show()
			specWarnLightBomb:Play("runout")
			yellLightBomb:Yell()
		end
		if self.Options.SetIconOnLightBombTarget then
			self:SetIcon(args.destName, 1)
		end
		warnLightBomb:Show(args.destName)
		timerLightBomb:Start(args.destName)
		timerLightBombCD:Start(self:IsDifficulty("normal25") and 16 or 20)
	elseif args:IsSpellID(63024, 64234) then		-- Gravity Bomb
		if args:IsPlayer() then
			specWarnGravityBomb:Show()
			specWarnGravityBomb:Play("runout")
			yellGravityBomb:Yell()
		end
		if self.Options.SetIconOnGravityBombTarget then
			self:SetIcon(args.destName, 2)
		end
		warnGravityBomb:Show(args.destName)
		timerGravityBomb:Start(args.destName)
		timerGravityBombCD:Start(self:IsDifficulty("normal25") and 16 or 20)
	elseif spellId == 63849 then	-- Exposed Heart
		self:SetStage(2)
		timerTympanicTantrumCD:Stop()
		timerTympanicTantrum:Stop()
		timerLightBombCD:Stop()
		timerGravityBombCD:Stop()
		timerHeart:Start()
	elseif args:IsSpellID(65737, 64193) then	-- Heartbreak (hard mode start)
		timerTympanicTantrumCD:Start(25) -- AC: hard mode reschedules directly, no 1s resume delay
		timerLightBombCD:Start(25)
		timerGravityBombCD:Start(self:IsDifficulty("normal25") and 33 or 15)
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(63018, 65121) then	-- Light Bomb
		if self.Options.SetIconOnLightBombTarget then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(63024, 64234) then	-- Gravity Bomb
		if self.Options.SetIconOnGravityBombTarget then
			self:SetIcon(args.destName, 0)
		end
	elseif args.spellId == 63849 then	-- Exposed Heart
		self:SetStage(1)
		timerHeart:Stop()
		timerTympanicTantrumCD:Start(26) -- AC: 1s resume attack + 25s (hard mode: corrected to 25s on Heartbreak)
		timerLightBombCD:Start(26)
		timerGravityBombCD:Start(self:IsDifficulty("normal25") and 34 or 16)
	end
end

function mod:SPELL_DAMAGE(_, _, _, destGUID, _, _, spellId)
	if (spellId == 64208 or spellId == 64206) and destGUID == UnitGUID("player") and self:AntiSpam() then
		specWarnConsumption:Show()
		specWarnConsumption:Play("watchfeet")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE
