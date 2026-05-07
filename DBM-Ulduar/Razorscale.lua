local mod	= DBM:NewMod("Razorscale", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260507220131")
mod:SetCreatureID(33186)
mod:SetEncounterID(746)

mod:RegisterCombat("combat_yell", L.YellAir)

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 63317 64021 63236",
	"SPELL_CAST_SUCCESS 64771",
	"SPELL_AURA_APPLIED 64771",
	"SPELL_AURA_APPLIED_DOSE 64771",
	"SPELL_DAMAGE 64733 64704",
	"SPELL_MISSED 64733 64704",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_RAID_BOSS_EMOTE"
)

-- General
local enrageTimer					= mod:NewBerserkTimer(600)

-- Stage One
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1))
local warnTurretsReadySoon			= mod:NewAnnounce("warnTurretsReadySoon", 1, 48642)
local warnTurretsReady				= mod:NewAnnounce("warnTurretsReady", 3, 48642)
local warnDevouringFlame			= mod:NewTargetAnnounce(63236, 2, nil, false) -- Very spammy, requires turning on AND disabling target filter. Power user setting.

local specWarnDevouringFlame		= mod:NewSpecialWarningMove(64733, nil, nil, nil, 1, 2)
local specWarnDevouringFlameYou		= mod:NewSpecialWarningYou(64733, false, nil, nil, 1, 2)
local specWarnDevouringFlameNear	= mod:NewSpecialWarningClose(64733, false, nil, nil, 1, 2)
local yellDevouringFlame			= mod:NewYell(64733)

--Harpoons
local timerTurret1					= mod:NewTimer(40, "timerTurret1", 48642, nil, nil, 5, DBM_COMMON_L.IMPORTANT_ICON)
local timerTurret2					= mod:NewTimer(67, "timerTurret2", 48642, nil, nil, 5, DBM_COMMON_L.IMPORTANT_ICON)
local timerTurret3					= mod:NewTimer(94, "timerTurret3", 48642, nil, nil, 5, DBM_COMMON_L.IMPORTANT_ICON)
local timerTurret4					= mod:NewTimer(121, "timerTurret4", 48642, nil, nil, 5, DBM_COMMON_L.IMPORTANT_ICON)

-- Stage Two
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2))
local warnFuseArmor					= mod:NewStackAnnounce(64771, 2, nil, "Tank")

local specWarnFuseArmor				= mod:NewSpecialWarningStack(64771, nil, 2, nil, nil, 1, 6)
local specWarnFuseArmorOther		= mod:NewSpecialWarningTaunt(64771, nil, nil, nil, 1, 2)

local timerDeepBreathCooldown		= mod:NewCDTimer(20, 64021, nil, nil, nil, 5) --20s on AC
local timerDeepBreathCast			= mod:NewCastTimer(2.5, 64021)
local timerGrounded					= mod:NewTimer(45, "timerGrounded", nil, nil, nil, 6)
local timerFuseArmorCD				= mod:NewCDTimer(10.1, 64771, nil, "Tank", nil, 5, nil, DBM_COMMON_L.TANK_ICON)

mod:GroupSpells(63236, 64733) -- Devouring Flame (cast and damage)

local combattime = 0

function mod:FlameTarget(targetname)
	if not targetname then return end
	if targetname == UnitName("player") then
		specWarnDevouringFlameYou:Show()
		specWarnDevouringFlameYou:Play("targetyou")
		yellDevouringFlame:Yell()
	elseif self:CheckNearby(11, targetname) then
		specWarnDevouringFlameNear:Show(targetname)
		specWarnDevouringFlameNear:Play("runaway")
	else
		warnDevouringFlame:Show(targetname)
	end
end

function mod:OnCombatStart(delay)
	self:SetStage(1)
	enrageTimer:Start(-delay)
	combattime = GetTime()
	if self:IsDifficulty("normal10") then -- REVIEW: No log yet to validate 10-man timers.
		warnTurretsReadySoon:Schedule(53-delay)
		warnTurretsReady:Schedule(73-delay)
		timerTurret1:Start(-delay)
		timerTurret2:Start(-delay)
	else
		warnTurretsReadySoon:Schedule(34-delay)
		warnTurretsReady:Schedule(37-delay)
		timerTurret1:Start(-delay)
		timerTurret2:Start(-delay)
		timerTurret3:Start(-delay)
		timerTurret4:Start(-delay)
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(63317, 64021) then	-- Flame Breath
		timerDeepBreathCast:Start()
		timerDeepBreathCooldown:Start()
	elseif args.spellId == 63236 then		-- Devouring Flame
		self:BossTargetScanner(args.sourceGUID, "FlameTarget", 0.1, 12)
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 64771 then		-- Fuse Armor
		timerFuseArmorCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 64771 then		-- Fuse Armor
		local amount = args.amount or 1
		if amount >= 2 then
			if args:IsPlayer() then
				specWarnFuseArmor:Show(args.amount)
				specWarnFuseArmor:Play("stackhigh")
			else
				local _, _, _, _, _, _, expireTime = DBM:UnitDebuff("player", args.spellName)
				local remaining
				if expireTime then
					remaining = expireTime-GetTime()
				end
				if not UnitIsDeadOrGhost("player") and (not remaining or remaining and remaining < 12) then
					specWarnFuseArmorOther:Show(args.destName)
					specWarnFuseArmorOther:Play("tauntboss")
				else
					warnFuseArmor:Show(args.destName, amount)
				end
			end
		else
			warnFuseArmor:Show(args.destName, amount)
		end
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_DAMAGE(_, _, _, destGUID, _, _, spellId)
	if (spellId == 64733 or spellId == 64704) and destGUID == UnitGUID("player") and self:AntiSpam() then
		specWarnDevouringFlame:Show()
		specWarnDevouringFlame:Play("runaway")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:CHAT_MSG_RAID_BOSS_EMOTE(emote)
	if emote == L.EmotePhase2 or emote:find(L.EmotePhase2) then
		-- Phase 2: Razorscale grounded permanently.
		self:SetStage(2)
		timerTurret1:Stop()
		timerTurret2:Stop()
		timerTurret3:Stop()
		timerTurret4:Stop()
		timerGrounded:Stop()
		timerFuseArmorCD:Start(12)
		timerDeepBreathCooldown:Start()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if (msg == L.YellAir or msg == L.YellAir2) and GetTime() - combattime > 30 then
		if self:IsDifficulty("normal10") then -- REVIEW: 10-man timers unvalidated.
			warnTurretsReadySoon:Schedule(27)
			warnTurretsReady:Schedule(30)
			timerTurret1:Start(30)
			timerTurret2:Start(57)
		else

			warnTurretsReadySoon:Schedule(27)
			warnTurretsReady:Schedule(30)
			timerTurret1:Start(30)
			timerTurret2:Start(57)
			timerTurret3:Start(84)
			timerTurret4:Start(111)
		end
	elseif msg == L.YellGround then
		timerGrounded:Start()
	end
end