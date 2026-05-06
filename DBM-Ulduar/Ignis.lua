local mod	= DBM:NewMod("Ignis", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260506000000")
mod:SetCreatureID(33118)
mod:SetEncounterID(745)
mod:SetUsedIcons(8)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 62680 63472 62488",
	"SPELL_CAST_SUCCESS 62548 63474",
	"SPELL_AURA_APPLIED 62717 63477 62382",
	"SPELL_AURA_REMOVED 62717 63477"
)

local warnSlagPot				= mod:NewTargetNoFilterAnnounce(63477, 3)
local warnConstruct				= mod:NewCountAnnounce(62488, 2)

local specWarnFlameJetsCast		= mod:NewSpecialWarningCast(63472, "SpellCaster", nil, nil, 2, 2)
local specWarnFlameBrittle		= mod:NewSpecialWarningSwitch(62382, "Dps", nil, nil, 1, 2)

local timerFlameJetsCast		= mod:NewCastTimer(2.7, 63472, nil, nil, nil, 5, nil, DBM_COMMON_L.IMPORTANT_ICON)
local timerFlameJetsCooldown	= mod:NewCDTimer(40, 63472, nil, nil, nil, 2, nil, DBM_COMMON_L.IMPORTANT_ICON, true)

local timerActivateConstruct	= mod:NewCDCountTimer(38, 62488, nil, nil, nil, 1, nil, nil, true)

local timerScorchCast			= mod:NewCastTimer(3, 63473)
local timerScorchCooldown		= mod:NewCDTimer(26, 63473, nil, nil, nil, 5)


local timerSlagPot				= mod:NewTargetTimer(10, 63477, nil, nil, nil, 3, nil, DBM_COMMON_L.DEADLY_ICON)
local timerAchieve				= mod:NewAchievementTimer(240, 2930)

local soundAuraMastery			= mod:NewSound(63472, "soundConcAuraMastery")

mod:AddSetIconOption("SlagPotIcon", 63477, false, false, {8})

mod.vb.ConstructCount = 0

local function isBuffOwner(uId, spellId)
	if not uId and not spellId then return end
	local _, _, _, _, _, _, _, unitCaster = DBM:UnitBuff(uId, spellId)
	if unitCaster == uId then
		return true
	else
		return false
	end
end

function mod:GrabDelay()
	timerScorchCooldown:AddTime(6)
	timerFlameJetsCooldown:AddTime(6)
	timerActivateConstruct:AddTime(6)
	self:ScheduleMethod(24, "GrabDelay")
end

function mod:OnCombatStart(delay)
	self.vb.ConstructCount = 0
	timerAchieve:Start()
	timerActivateConstruct:Start(36-delay, 1)
	timerScorchCooldown:Start(10-delay)
	timerFlameJetsCooldown:Start(40-delay)
	self:ScheduleMethod(27-delay, "GrabDelay")
end

function mod:OnCombatEnd()
	self:UnscheduleMethod("GrabDelay")
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(62680, 63472) then		-- Flame Jets
		timerFlameJetsCast:Start()
		specWarnFlameJetsCast:Show()
		if self.Options.soundConcAuraMastery and isBuffOwner("player", 19746) then
			soundAuraMastery:Play("Interface\\AddOns\\DBM-Core\\sounds\\PlayerAbilities\\AuraMastery.ogg")
		else
			specWarnFlameJetsCast:Play("stopcast")
		end
		timerFlameJetsCooldown:Start(self:IsDifficulty("normal10") and 31 or 31)
	elseif args.spellId == 62488 then			-- Activate Construct
		self.vb.ConstructCount = self.vb.ConstructCount + 1
		warnConstruct:Show(self.vb.ConstructCount)
		if self.vb.ConstructCount < 20 then
			timerActivateConstruct:Start(self:IsDifficulty("normal10") and 38 or 38, self.vb.ConstructCount+1)
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(62548, 63474) then		-- Scorch
		timerScorchCast:Start()
		timerScorchCooldown:Start(self:IsDifficulty("normal10") and 26 or 26)
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(62717, 63477) then		-- Slag Pot
		warnSlagPot:Show(args.destName)
		timerSlagPot:Start(args.destName)
		if self.Options.SlagPotIcon then
			self:SetIcon(args.destName, 8, 10)
		end
	elseif args.spellId == 62382 and self:AntiSpam(5, 1) then	-- Flame Brittle
		specWarnFlameBrittle:Show()
		specWarnFlameBrittle:Play("killmob")
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(62717, 63477) then		-- Slag Pot
		if self.Options.SlagPotIcon then
			self:SetIcon(args.destName, 0)
		end
	end
end