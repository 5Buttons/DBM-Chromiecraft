local mod	= DBM:NewMod("Auriaya", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260525220131")

mod:SetCreatureID(33515)
mod:SetEncounterID(750)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 64678 64389 64386 64688 64422",
	"SPELL_AURA_APPLIED 64396 64455",
	"SPELL_DAMAGE 64459 64675",
	"SPELL_MISSED 64459 64675",
	"UNIT_DIED"
)

local warnSwarm			= mod:NewTargetAnnounce(64396, 2)
local warnFearSoon		= mod:NewSoonAnnounce(64386, 1)
local warnCatDied		= mod:NewAnnounce("WarnCatDied", 3, 64455, nil, nil, nil, 64455)
local warnCatDiedOne	= mod:NewAnnounce("WarnCatDiedOne", 3, 64455, nil, nil, nil, 64455)

local specWarnFear		= mod:NewSpecialWarningSpell(64386, nil, nil, nil, 2, 2)
local specWarnBlast		= mod:NewSpecialWarningInterrupt(64389, "HasInterrupt", nil, 2, 1, 2)
local specWarnVoid		= mod:NewSpecialWarningMove(64675, nil, nil, nil, 1, 2)
local specWarnSonic		= mod:NewSpecialWarningMoveTo(64688, nil, nil, nil, 2, 2)

local enrageTimer		= mod:NewBerserkTimer(600)
local timerDefender		= mod:NewNextCountTimer(25, 64447, nil, nil, nil, 1) -- 25s on AC
local timerFear			= mod:NewCastTimer(64386, nil, nil, nil, 4)
local timerFearCD		= mod:NewCDTimer(35, 64386, nil, nil, nil, 4, nil, nil, nil) -- 35s on AC
local timerSwarmCD		= mod:NewCDTimer(40, 64396, nil, nil, nil, 1, nil, nil, true) 
local timerSonicCD		= mod:NewCDTimer(50, 64688, nil, nil, nil, 2, nil, DBM_COMMON_L.DEADLY_ICON, true) --50s on AC
local timerSonic		= mod:NewCastTimer(64688, nil, nil, nil, 2)

mod:GroupSpells(64447, 64455) -- Activate Feral Defender, Feral Essence

mod.vb.catLives = 9

function mod:OnCombatStart(delay)
	self.vb.catLives = 9
	enrageTimer:Start(-delay)
	timerFearCD:Start(35-delay)
	timerSonicCD:Start(45-delay)
	timerSwarmCD:Start(70-delay)
	timerDefender:Start(65-delay, self.vb.catLives) --60s, but first one will be delayed by 5s from Snetinel Blast on AC
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(64678, 64389) then -- Sentinel Blast
		specWarnBlast:Show(args.sourceName)
		specWarnBlast:Play("kickcast")
		if self:AntiSpam(5, 1) then
			timerFearCD:AddTime(5)
			timerSonicCD:AddTime(5)
			timerSwarmCD:AddTime(5)
			self:Unschedule(warnFearSoon.Show, warnFearSoon)
			warnFearSoon:Schedule(timerFearCD:GetRemaining() - 5)
		end
	elseif args.spellId == 64386 then -- Terrifying Screech
		specWarnFear:Show()
		specWarnFear:Play("fearsoon")
		timerFear:Start()
		timerFearCD:Start(35)
		self:Unschedule(warnFearSoon.Show, warnFearSoon)
		warnFearSoon:Schedule(timerFearCD:GetRemaining() - 5)
	elseif args:IsSpellID(64688, 64422) then -- Sonic Screech
		specWarnSonic:Show(TANK)
		specWarnSonic:Play("gathershare")
		timerSonic:Start()
		timerSonicCD:Start(50)
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 64396 then -- Guardian Swarm
		warnSwarm:Show(args.destName)
		timerSwarmCD:Start()
	elseif spellId == 64455 then -- Feral Essence
		DBM.BossHealth:AddBoss(34035, L.Defender:format(9))
	end
end

function mod:SPELL_DAMAGE(_, _, _, destGUID, _, _, spellId)
	if (spellId == 64459 or spellId == 64675) and destGUID == UnitGUID("player") and self:AntiSpam(3) then -- Feral Defender Void Zone
		specWarnVoid:Show()
		specWarnVoid:Play("runaway")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 34035 then
		self.vb.catLives = self.vb.catLives - 1
		if self.vb.catLives > 0 then
			timerDefender:Start(nil, self.vb.catLives)
			if self.vb.catLives == 1 then
				warnCatDiedOne:Show()
			else
				warnCatDied:Show(self.vb.catLives)
			end
			if self.Options.HealthFrame then
				DBM.BossHealth:RemoveBoss(34035)
				DBM.BossHealth:AddBoss(34035, L.Defender:format(self.vb.catLives))
			end
		else
			if self.Options.HealthFrame then
				DBM.BossHealth:RemoveBoss(34035)
			end
		end
	end
end
