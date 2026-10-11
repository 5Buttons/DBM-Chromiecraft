local mod	= DBM:NewMod("FlameLeviathan", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261011200000")

mod:SetCreatureID(33113)
mod:SetEncounterID(744)

mod:RegisterCombat("yell", L.YellPull)

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 62396 62475 62374 62297 64482",
	"SPELL_AURA_REFRESH 62374",
	"SPELL_AURA_REMOVED 62396",
	"SPELL_SUMMON 62907"
)

local warnHodirsFury			= mod:NewTargetAnnounce(62297, 3)
local warnPursueTarget			= mod:NewTargetAnnounce(62374, 2)
local warnNextPursueSoon		= mod:NewAnnounce("warnNextPursueSoon", 3, 62374, nil, nil, nil, 62374)

local specWarnSystemOverload	= mod:NewSpecialWarningSpell(62475, nil, nil, nil, 1, 12)
local specWarnPursue			= mod:NewSpecialWarning("SpecialPursueWarnYou", nil, nil, 2, 4, 2, nil, 62374, 62374)

local timerSystemOverload		= mod:NewBuffActiveTimer(20, 62475, nil, nil, nil, 6)
local timerFlameVents			= mod:NewCastTimer(10, 62396, nil, nil, nil, 2, nil, DBM_COMMON_L.INTERRUPT_ICON)
local timertNextFlameVents		= mod:NewNextTimer(20, 62396, nil, nil, nil, 2)
local timerPursued				= mod:NewTargetTimer(31, 62374, nil, nil, nil, 3)

-- Hard Mode
mod:AddTimerLine(DBM_COMMON_L.HEROIC_ICON..DBM_CORE_L.HARD_MODE)
local specWarnWardOfLife		= mod:NewSpecialWarning("warnWardofLife", nil, nil, nil, 1, 2, nil, 62907, 62907)

local timerNextWardOfLife		= mod:NewNextTimer(29, 62907, nil, nil, nil, 1)

-- Pet GUID (vehicle) -> player name
local names = {}
local function buildNameTable()
	table.wipe(names)
	for uId in DBM:GetGroupMembers() do
		local petGUID = UnitGUID(uId.."pet")
		if petGUID then
			names[petGUID] = GetUnitName(uId, true)
		end
	end
end

-- ACC: Pursue every 31s, but events wait for the Flame Vents channel to end
local pursueDue, pursueTarget
local function nextPursue(t)
	local r = timertNextFlameVents:GetRemaining() or 0
	for _, s in ipairs({r, r + 20}) do
		if t > s and t < s + 10 then
			t = s + 10
		end
	end
	return t
end

local function updatePursue()
	local t = nextPursue(math.max(pursueDue - GetTime(), 0))
	timerPursued:Stop(pursueTarget)
	warnNextPursueSoon:Cancel()
	if t > 1 then
		timerPursued:Start(t, pursueTarget)
		if t > 5 then
			warnNextPursueSoon:Schedule(t - 5)
		end
	end
end

function mod:OnCombatStart(delay)
	buildNameTable()
	pursueDue, pursueTarget = nil, nil
	timertNextFlameVents:Start(20-delay)
end

function mod:OnTimerRecovery()
	buildNameTable()
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 62396 then		-- Flame Vents
		timerFlameVents:Start()
		timertNextFlameVents:Start()
	elseif spellId == 62475 then
		timertNextFlameVents:AddTime(20)
		timerSystemOverload:Start()
		specWarnSystemOverload:Show()
		specWarnSystemOverload:Play("attacktank")
		-- Pursue event firing during the stun fails the cast and reschedules 31s
		if pursueDue then
			local now = GetTime()
			if pursueDue < now + 20 then
				pursueDue = math.max(pursueDue, now) + 31
			end
			updatePursue()
		end
	elseif spellId == 62374 then	-- Pursued (same target = REFRESH)
		local target = names[args.destGUID] or args.destName
		pursueDue, pursueTarget = GetTime() + 31, target
		updatePursue()
		warnPursueTarget:Show(target)
		if target == UnitName("player") then
			specWarnPursue:Show()
			specWarnPursue:Play("justrun")
		end
	elseif spellId == 62297 then	-- Hodir's Fury (vehicle or player on foot)
		local target = args:IsPlayer() and args.destName or names[args.destGUID]
		if target then
			warnHodirsFury:CombinedShow(0.3, target)
		end
	elseif spellId == 64482 then	-- Tower of Life, applied on pull
		timerNextWardOfLife:Start(35)
	end
end
mod.SPELL_AURA_REFRESH = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 62396 then
		timerFlameVents:Stop()
		-- Channel ended (also on interrupt): recalculate Pursue prediction
		if pursueDue then
			updatePursue()
		end
	end
end

function mod:SPELL_SUMMON(args)
	if args.spellId == 62907 and self:AntiSpam(3, 1) then		-- Ward of Life (npc 34275)
		specWarnWardOfLife:Show()
		specWarnWardOfLife:Play("bigmob")
		timerNextWardOfLife:Start()
	end
end