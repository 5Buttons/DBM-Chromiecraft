local mod	= DBM:NewMod("Freya", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261011120000")

mod:SetCreatureID(32906)
mod:SetEncounterID(753)
mod:RegisterCombat("combat")
mod:RegisterKill("yell", L.YellKill)
mod:SetUsedIcons(4, 5, 6, 7, 8)

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL"
)
mod:RegisterEventsInCombat(
	"SPELL_CAST_START 62437 62859",
	"SPELL_CAST_SUCCESS 63571 62589 64587 64650",
	"SPELL_AURA_APPLIED 62283 62438 62439 62861 62862 62930 62451 62865",
	"SPELL_AURA_REMOVED 62519 62861 62438 63571 62589",
	"UNIT_DIED",
	"CHAT_MSG_RAID_BOSS_EMOTE"
)

-- Trash: 33430 Guardian Lasher (flower)
-- 33355 (nymph)
-- 33354 (tree)

--
-- Elder Stonebark (ground tremor / fist of stone)
-- Elder Brightleaf (unstable sunbeam)

-- General
local warnSimulKill				= mod:NewAnnounce("WarnSimulKill", 1)

local timerEnrage				= mod:NewBerserkTimer(600)

-- Stage One
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1))
local warnNatureFury			= mod:NewTargetAnnounce(63571, 2)

local specWarnLifebinder		= mod:NewSpecialWarningSwitch(62584, "Dps", nil, nil, 1, 2) -- actual spell id for the summon is 62869
local specWarnNatureFury		= mod:NewSpecialWarningMoveAway(63571, nil, nil, nil, 1, 2)
local yellNatureFury			= mod:NewYell(63571)

local warnAlliesOfNature		= mod:NewCountAnnounce(62678, 2, 62947)

local timerAlliesOfNature		= mod:NewNextCountTimer(60, 62678, nil, nil, nil, 1, 62947, DBM_COMMON_L.IMPORTANT_ICON..DBM_COMMON_L.DAMAGE_ICON) -- first 10s, repeat 60s on AC
local timerSimulKill			= mod:NewTimer(11, "TimerSimulKill", nil, nil, nil, 5, DBM_COMMON_L.DAMAGE_ICON, nil, nil, nil, nil, nil, nil, 62678) -- each trio member revives 11s after its own death on AC
local timerNatureFury			= mod:NewTargetTimer(10, 63571, nil, nil, nil, 3) -- 10s debuff, recast every 14s on AC
local timerLifebinderCD			= mod:NewNextTimer(45, 62584, nil, nil, nil, 1, nil, DBM_COMMON_L.IMPORTANT_ICON) -- first 30s, repeat 45s on AC

mod:AddRangeFrameOption(8, 63571)
mod:AddSetIconOption("SetIconOnFury", 63571, false, false, {7, 8})

-- Stage Two
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2))
local warnPhase2				= mod:NewPhaseAnnounce(2, 3, nil, nil, nil, nil, nil, 2)

local specWarnNatureBombSummon	= mod:NewSpecialWarningMove(64604)

local timerNextNatureBombSummon	= mod:NewNextTimer(12, 64604, nil, nil, nil, 2) -- summon every 18s on AC, started 12s after the explosion
local timerNatureBombExplosion	= mod:NewCastTimer(6, 64587, 34539, nil, nil, 2) -- bomb explodes ~6s after spawn on AC

-- Hard Mode
mod:AddTimerLine(DBM_COMMON_L.HEROIC_ICON..DBM_CORE_L.HARD_MODE)
local warnIronRoots				= mod:NewTargetNoFilterAnnounce(62438, 2) -- Hard mode Elder Ironbranch Alive
local yellIronRoots				= mod:NewYell(62438)
local timerIronRootsCD			= mod:NewCDTimer("v45-55", 62438, nil, nil, nil, 3) -- first 20s, 45-55s variance on AC

local specWarnUnstableBeam		= mod:NewSpecialWarningMove(62865, nil, nil, nil, 1, 2) -- Hard mode Elder Brightleaf Alive
local timerUnstableBeamCD		= mod:NewCDTimer("v38-48", 62865, nil, nil, nil, 3) -- first 60s, 38-48s variance on AC

local specWarnGroundTremor		= mod:NewSpecialWarningCast(62859, "SpellCaster", nil, 2, 1, 2) -- Hard mode Elder Stonebark Alive
local timerGroundTremorCD		= mod:NewCDCountTimer("v25-35", 62859, nil, nil, nil, 2) -- first 35s, 25-35s variance on AC

mod:AddSetIconOption("SetIconOnRoots", 62438, false, false, {6, 5, 4})

mod:GroupSpells(64587, 64604) -- Nature Bomb, internal Nature Bomb summon ID

local trioDeath = {}
local trioIds = {33202, 32916, 32919}
mod.vb.altIcon = true
mod.vb.iconId = 6
mod.vb.tremorCount = 0
mod.vb.isHardMode = false
mod.vb.waveThreshold = 0
mod.vb.waveCount = 0

function mod:OnCombatStart(delay)
	self.vb.altIcon = true
	self.vb.iconId = 6
	self.vb.tremorCount = 0
	self.vb.waveThreshold = 0
	self.vb.waveCount = 0
	table.wipe(trioDeath)
	self:SetStage(1)
	timerEnrage:Start(-delay)
	timerAlliesOfNature:Start(10-delay, "1/6")
	timerLifebinderCD:Start(30-delay)
end

function mod:OnCombatEnd(wipe)
	if not wipe then
		if DBT:GetBar(L.TrashRespawnTimer) then
			DBT:CancelBar(L.TrashRespawnTimer)
		end
	end
	if self.Options.HealthFrame then
		DBM.BossHealth:Hide()
	end
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(62437, 62859) then
		self.vb.tremorCount = self.vb.tremorCount + 1
		specWarnGroundTremor:Show()
		specWarnGroundTremor:Play("stopcast")
		timerGroundTremorCD:Start(nil, self.vb.tremorCount + 1)
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(63571, 62589) then -- Nature's Fury
		if self.Options.SetIconOnFury then
			self.vb.altIcon = not self.vb.altIcon -- alternates between Skull and X
			self:SetIcon(args.destName, self.vb.altIcon and 7 or 8, 10)
		end
		if args:IsPlayer() then
			specWarnNatureFury:Show()
			specWarnNatureFury:Play("runout")
			yellNatureFury:Yell()
			if self.Options.RangeFrame then
				DBM.RangeCheck:Show(8)
			end
		else
			warnNatureFury:Show(args.destName)
		end
		timerNatureFury:Start(args.destName)
	elseif args:IsSpellID(64587, 64650) then -- Nature Bomb explosion
		if self:AntiSpam(5, 64650) then
			specWarnNatureBombSummon:Cancel()
			specWarnNatureBombSummon:Schedule(12)
			timerNatureBombExplosion:Schedule(12)
			timerNextNatureBombSummon:Start()
		end
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(62283, 62438, 62439, 62861, 62862, 62930) then -- Iron Roots
		warnIronRoots:CombinedShow(0.5, args.destName)
		if args:IsPlayer() then
			yellIronRoots:Yell()
		end
		self.vb.iconId = self.vb.iconId - 1
		if self.Options.SetIconOnRoots then
			self:SetIcon(args.destName, self.vb.iconId, 15)
		end
	elseif args:IsSpellID(62451, 62865) then -- Unstable Energy (Sun Beam)
		if self:AntiSpam(20, 62451) then
			timerUnstableBeamCD:Start()
		end
		if args:IsPlayer() then
			specWarnUnstableBeam:Show()
			specWarnUnstableBeam:Play("runaway")
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 62519 then -- Attuned to Nature
		self:SetStage(2)
		warnPhase2:Show()
		warnPhase2:Play("ptwo")
		timerAlliesOfNature:Cancel()
		timerSimulKill:Stop()
		timerNextNatureBombSummon:Start(5)
		specWarnNatureBombSummon:Schedule(5)
		timerNatureBombExplosion:Schedule(5)
	elseif args:IsSpellID(62861, 62438) then -- Iron Roots
		if self.Options.SetIconOnRoots then
			self:RemoveIcon(args.destName)
		end
		self.vb.iconId = self.vb.iconId + 1
	elseif args:IsSpellID(63571, 62589) then -- Nature's Fury
		if self.Options.SetIconOnFury then
			self:RemoveIcon(args.destName)
		end
		if args:IsPlayer() and self.Options.RangeFrame then
			DBM.RangeCheck:Hide()
		end
	end
end

function mod:StartNextWaveTimer(timer)
	if self.vb.waveCount < 6 then
		timerAlliesOfNature:Start(timer, (self.vb.waveCount + 1).."/6")
	end
end

function mod:NewWave()
	self.vb.waveCount = self.vb.waveCount + 1
	warnAlliesOfNature:Show(self.vb.waveCount.."/6")
	timerAlliesOfNature:Stop()
	self:StartNextWaveTimer()
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 33202 or cid == 32916 or cid == 32919 then -- trio
		local now = GetTime()
		trioDeath[cid] = now
		local down = 0
		for _, id in ipairs(trioIds) do
			if trioDeath[id] and now - trioDeath[id] < 11 then
				down = down + 1
			end
		end
		if down == 3 then
			table.wipe(trioDeath)
			timerSimulKill:Stop()
			self:StartNextWaveTimer(16) -- 11s revive window + 5s on AC
			if self.Options.HealthFrame then
				for _, id in ipairs(trioIds) do
					DBM.BossHealth:RemoveBoss(id)
				end
			end
		elseif self:AntiSpam(11, 1) then
			timerSimulKill:Start()
			warnSimulKill:Show()
		end
	elseif cid == 33203 or cid == 32918 then -- Ancient Conservator, Detonating Lasher
		self.vb.waveThreshold = self.vb.waveThreshold - 1
		if self.vb.waveThreshold == 0 then
			self:StartNextWaveTimer(5)
		end
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.YellPullNormal then -- yell fires before IEEU, so set HM variable here instead of OnCombatStart
		self.vb.isHardMode = false
	elseif msg == L.YellPullHard then
		self.vb.isHardMode = true
		timerGroundTremorCD:Start(35, 1)
		timerIronRootsCD:Start(20)
		timerUnstableBeamCD:Start(60)
	elseif msg == L.SpawnYell then -- trio
		self:NewWave()
		table.wipe(trioDeath)
		if self.Options.HealthFrame then
			DBM.BossHealth:AddBoss(33202, L.WaterSpirit)
			DBM.BossHealth:AddBoss(32916, L.Snaplasher)
			DBM.BossHealth:AddBoss(32919, L.StormLasher)
		end
	elseif msg == L.YellAdds1 then -- Ancient Conservator
		self:NewWave()
		self.vb.waveThreshold = 1
	elseif msg == L.YellAdds2 then -- Detonating Lashers
		self:NewWave()
		self.vb.waveThreshold = 10
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg:find(L.EmoteLGift, 1, true) then
		specWarnLifebinder:Show()
		specWarnLifebinder:Play("targetchange")
		timerLifebinderCD:Start()
	elseif msg:find(GetSpellInfo(62438), 1, true) then
		timerIronRootsCD:Start()
	end
end