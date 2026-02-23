local mod	= DBM:NewMod("Grobbulus", "DBM-Naxx", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260223165304")
mod:SetCreatureID(15931)
mod:SetUsedIcons(1, 2, 3, 4)
mod:SetEncounterID(1111)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 28169",
	"SPELL_AURA_REMOVED 28169",
--	"SPELL_CAST_SUCCESS 28240 28157 54364",
	"SPELL_CAST_SUCCESS 28157 54364",
	"SPELL_SUMMON 28240",
	"UNIT_HEALTH boss1"
)

local warnInjection			= mod:NewTargetNoFilterAnnounce(28169, 2)
local warnCloud				= mod:NewSpellAnnounce(28240, 2)
local warnSlimeSpray 		= mod:NewSpellAnnounce(28157, 2, nil, false)

local specWarnInjection		= mod:NewSpecialWarningYou(28169, nil, nil, nil, 1, 2)
local yellInjection			= mod:NewYellMe(28169, nil, false)

local timerInjection		= mod:NewTargetTimer(10, 28169, nil, nil, nil, 3)
local timerInjectionCD		= mod:NewCDTimer(20, 28169, nil, nil, nil, 3)
local timerCloud			= mod:NewNextTimer(15, 28240, nil, nil, nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerSlimeSpray		= mod:NewCDTimer(20, 28157, nil, false, nil, 2)
local enrageTimer			= mod:NewBerserkTimer(720)

mod:AddSetIconOption("SetIconOnInjectionTarget", 28169, false, false, {1, 2, 3, 4})

local mutateIcons = {}
local warnedHealth = false

local function addIcon(self)
	for i, j in ipairs(mutateIcons) do
		local icon = 0 + i
		self:SetIcon(j, icon)
	end
end

local function removeIcon(self, target)
	for i, j in ipairs(mutateIcons) do
		if j == target then
			table.remove(mutateIcons, i)
			self:SetIcon(target, 0)
		end
	end
	addIcon(self)
end

-- Calculate dynamic injection timer based on health percentage
-- Formula from Azerothcore: 6000 + (120 * healthPct)
local function getInjectionTimer(healthPct)
	return (6 + (0.12 * healthPct))
end

function mod:OnCombatStart(delay)
	table.wipe(mutateIcons)
	warnedHealth = false
	if self:IsDifficulty("normal10") then
		enrageTimer:Start(540 - delay) -- 9 minutes for 10-man
	else
		enrageTimer:Start(720 - delay) -- 12 minutes for 25-man
	end
	timerCloud:Start(15 - delay)
	timerInjectionCD:Start(20 - delay)
	timerSlimeSpray:Start(10 - delay)
end

function mod:OnCombatEnd()
	for _, j in ipairs(mutateIcons) do
		self:SetIcon(j, 0)
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 28169 then
		warnInjection:Show(args.destName)
		timerInjection:Start(args.destName)
		if args:IsPlayer() then
			specWarnInjection:Show()
			specWarnInjection:Play("runout")
			yellInjection:Yell()
		end
		if self.Options.SetIconOnInjectionTarget then
			table.insert(mutateIcons, args.destName)
			addIcon(self)
		end
		-- Schedule next injection based on current boss health
		local healthPct = self:GetBossHP(15931) or 100
		local nextTimer = getInjectionTimer(healthPct)
		timerInjectionCD:Start(nextTimer)
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 28169 then
		timerInjection:Cancel(args.destName) --Cancel timer if someone is dumb and dispels it.
		if self.Options.SetIconOnInjectionTarget then
			removeIcon(self, args.destName)
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(28157, 54364) then
		warnSlimeSpray:Show()
		timerSlimeSpray:Start()
	end
end

function mod:SPELL_SUMMON(args)
	if args.spellId == 28240 and args:GetSrcCreatureID() == 15931 then
		warnCloud:Show()
		timerCloud:Start()
	end
end

function mod:UNIT_HEALTH(uId)
	if not warnedHealth and self:GetUnitCreatureId(uId) == 15931 then
		local h = UnitHealth(uId) / UnitHealthMax(uId)
		if h < 0.35 then
			warnedHealth = true
		end
	end
end