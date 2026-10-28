local mod	= DBM:NewMod("NorthrendBeasts", "DBM-Coliseum")
local L		= mod:GetLocalizedStrings()

local UnitExists, UnitGUID, UnitName = UnitExists, UnitGUID, UnitName
local GetSpellInfo = GetSpellInfo
local GetPlayerMapPosition, SetMapToCurrentZone = GetPlayerMapPosition, SetMapToCurrentZone

mod:SetRevision("20261028211808")
mod:SetCreatureID(34796, 35144, 34799, 34797)
mod:SetEncounterID(629)
mod:SetUsedIcons(1, 2, 3, 4, 5, 6, 7, 8)
mod:SetMinSyncRevision(20220925000000)
mod:SetMinCombatTime(30)
mod:SetBossHPInfoToHighest()
mod:RegisterCombat("combat")
mod:SetWipeTime(25) --Temporary band-aid, because you lose combat on AC during an encounter...

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL"
)
mod:RegisterEventsInCombat(
	"SPELL_CAST_START 66313 66330 67647 67648 67649 66794 67644 67645 67646 66821 66818 66901 67615 67616 67617 66902 67627 67628 67629 66880 67606 67607 67608 66796 67632 67633 67634",
	"SPELL_CAST_SUCCESS 66331 67477 67478 67479 67641 66883 67642 67643 66824 67612 67613 67614 66879 67624 67625 67626 66689 67650 67651 67652",
	"SPELL_AURA_APPLIED 67477 66331 67478 67479 67657 66759 67658 67659 66823 67618 67619 67620 66869 66758 66636 68335",
	"SPELL_AURA_APPLIED_DOSE 67477 66331 67478 67479 66636",
	"SPELL_AURA_REMOVED 66869 66758",
	"SPELL_DAMAGE 66320 67472 67473 67475 66317 66881 67638 67639 67640",
	"SPELL_MISSED 66320 67472 67473 67475 66317 66881 67638 67639 67640",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UNIT_DIED",
	"UNIT_SPELLCAST_START"
)

local gormok = L.Gormok
local dreadscale = L.Dreadscale
local acidmaw = L.Acidmaw
local icehowl = L.Icehowl

local GetTime = GetTime
local introTime = 0 -- AC heroic: Dreadscale, Icehowl and enrage are timed from the Gormok intro yell

-- General
local enrageTimer			= mod:NewBerserkTimer(520) -- AC heroic: 520s after Gormok intro yell
local timerCombatStart		= mod:NewCombatTimer(23)
local timerNextBoss			= mod:NewTimer(150, "TimerNextBoss", 2457, nil, nil, 1) -- AC heroic: 150s / 340s after Gormok intro yell

mod:AddRangeFrameOption("10")

-- Stage One: Gormok the Impaler
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1)..": "..gormok)
local warnImpaleOn			= mod:NewStackAnnounce(66331, 2, nil, "Tank|Healer")
local warnFireBomb			= mod:NewSpellAnnounce(66317, 3, nil, false)
local WarningSnobold		= mod:NewAnnounce("WarningSnobold", 4)

local specWarnImpale3		= mod:NewSpecialWarningStack(66331, nil, 3, nil, nil, 1, 6)
local specWarnAnger3		= mod:NewSpecialWarningStack(66636, "Tank|Healer", 3, nil, nil, 1, 6)
local specWarnGTFO			= mod:NewSpecialWarningGTFO(66317, nil, nil, nil, 1, 8)
local specWarnSilence		= mod:NewSpecialWarningSpell(66330, "SpellCaster")
local specWarnStompPreWarn	= mod:NewSpecialWarningPreWarn(66330, "SpellCaster", 3, nil, nil, 1, 2)

local timerNextStomp		= mod:NewCDTimer("v20-25", 66330, nil, nil, nil, 2, nil, DBM_COMMON_L.INTERRUPT_ICON, nil, mod:IsSpellCaster() and 3 or nil, 3) --AC 20-25s
local timerImpaleCD			= mod:NewCDTimer("v9-10", 66331, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON, true) -- AC: 9-10s
local timerRisingAnger		= mod:NewCDTimer("v16-24", 66636, nil, nil, nil, 1, nil, nil, true) -- AC: 16-24s

local soundAuraMastery		= mod:NewSound(66330, "soundConcAuraMastery")

-- Stage Two: Acidmaw & Dreadscale
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2)..": "..dreadscale.." & "..acidmaw)
local warnSlimePool			= mod:NewSpellAnnounce(66883, 2, nil, "Melee")
local warnToxin				= mod:NewTargetAnnounce(66823, 3)
local warnBile				= mod:NewTargetAnnounce(66869, 3)
local warnEnrageWorm		= mod:NewSpellAnnounce(68335, 3)

local specWarnToxin			= mod:NewSpecialWarningMoveTo(66823, nil, nil, nil, 1, 2)
local specWarnBile			= mod:NewSpecialWarningYou(66869, nil, nil, nil, 1, 2)

local timerSubmerge			= mod:NewCDTimer(45, 66948, nil, nil, nil, 6, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendBurrow.blp") --AC 45-50s, but no event at all, therefore no variance
local timerEmerge			= mod:NewNextTimer(10, 66947, nil, nil, nil, 6, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendUnBurrow.blp")
local timerSweepCD			= mod:NewCDTimer("v15-30", 66794, nil, "Melee", nil, 3, nil, nil, true) -- AC: 15-30s
local timerAcidicSpewCD		= mod:NewCDTimer(22, 66819, nil, "Tank", 2, 5, nil, DBM_COMMON_L.TANK_ICON, true) -- AC: 22s
local timerMoltenSpewCD		= mod:NewCDTimer(22, 66820, nil, "Tank", 2, 5, nil, DBM_COMMON_L.TANK_ICON, true) -- AC: 22s (25N AC [2026-10-28]) - 22.0
local timerParalyticSprayCD	= mod:NewCDTimer(20, 66901, nil, nil, nil, 3, nil, nil, true) -- AC: 20s
local timerBurningSprayCD	= mod:NewCDTimer(20, 66902, nil, nil, nil, 3, nil, nil, true) -- AC: 20s
local timerParalyticBiteCD	= mod:NewCDTimer(16, 66824, nil, "Melee", nil, 3, nil, nil, true) -- AC: 16s
local timerBurningBiteCD	= mod:NewCDTimer(16, 66879, nil, "Melee", nil, 3, nil, nil, true) -- AC: 16s (25N AC [2026-10-28]) - 16.0, 16.0
local timerSlimePoolCD		= mod:NewCDTimer(12, 66883, nil, "Melee", nil, 3)

mod:AddSetIconOption("SetIconOnBileTarget", 66869, false, 0, {1, 2, 3, 4, 5, 6, 7, 8})

-- Stage Three: Icehowl
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(3)..": "..icehowl)
local warnBreath			= mod:NewSpellAnnounce(66689, 2)
local warnRage				= mod:NewSpellAnnounce(66759, 3)
local warnCharge			= mod:NewTargetNoFilterAnnounce(52311, 4)

local specWarnCharge		= mod:NewSpecialWarningRun(52311, nil, nil, nil, 4, 2)
local specWarnChargeNear	= mod:NewSpecialWarningClose(52311, nil, nil, nil, 3, 2)
local specWarnFrothingRage	= mod:NewSpecialWarningDispel(66759, "RemoveEnrage", nil, nil, 1, 2)

local timerBreath			= mod:NewCastTimer(5, 66689, nil, nil, nil, 3) -- 5s channel on a random target
local timerBreathCD			= mod:NewCDTimer("v20-30", 66689, nil, nil, nil, 3)
local timerStaggeredDaze	= mod:NewBuffActiveTimer(15, 66758, nil, nil, nil, 5, nil, DBM_COMMON_L.DAMAGE_ICON)
local timerNextCrash		= mod:NewCDTimer("v32-52", 66683, nil, nil, nil, 2, nil, DBM_COMMON_L.MYTHIC_ICON)

mod:AddSetIconOption("SetIconOnChargeTarget", 52311, true, 0, {8})
mod:AddBoolOption("ClearIconsOnIceHowl", true)
mod:AddBoolOption("IcehowlArrow")

mod:GroupSpells(66902, 66869)--Burning Spray with Burning Bile
mod:GroupSpells(66901, 66823)--Paralytic Spray with Toxic Bile
mod:GroupSpells(52311, 66758, 66759)--Furious Charge, Staggering Daze, and Frothing Rage

local bileName = DBM:GetSpellInfo(66869)
local phases = {}
mod.vb.burnIcon = 1
mod.vb.DreadscaleActive = true
mod.vb.WormsSynced = false
mod.vb.DreadscaleDead = false
mod.vb.AcidmawDead = false

local function updateHealthFrame(phase)
	if phases[phase] then
		return
	end
	phases[phase] = true
	mod.vb.phase = phase
	if phase == 1 then
		DBM.BossHealth:Clear()
		DBM.BossHealth:AddBoss(34796, gormok)
	elseif phase == 2 then
		DBM.BossHealth:AddBoss(35144, acidmaw)
		DBM.BossHealth:AddBoss(34799, dreadscale)
	elseif phase == 3 then
		DBM.BossHealth:AddBoss(34797, icehowl)
	end
end

local function isBuffOwner(uId, spellId)
	if not uId and not spellId then return end
	local _, _, _, _, _, _, _, unitCaster = DBM:UnitBuff(uId, spellId)
	if unitCaster == uId then
		return true
	else
		return false
	end
end

function mod:OnCombatStart(delay)
	table.wipe(phases)
	self.vb.burnIcon = 1
	self.vb.DreadscaleActive = true
	self.vb.WormsSynced = false
	self.vb.DreadscaleDead = false
	self.vb.AcidmawDead = false
	self:SetStage(1)
	specWarnStompPreWarn:Schedule(12-delay)
	if self.Options.soundConcAuraMastery and isBuffOwner("player", 19746) then -- Concentration Aura Mastery by a Paladin will negate the interrupt effect of Staggering Stomp
		soundAuraMastery:Schedule(12-delay, "Interface\\AddOns\\DBM-Core\\sounds\\PlayerAbilities\\AuraMastery.ogg")
	else
		specWarnStompPreWarn:ScheduleVoice(12-delay, "silencesoon")
	end
	if self:IsHeroic() then
		local elapsed = introTime > 0 and GetTime() - introTime or delay
		timerNextBoss:Start(150 - elapsed)
		enrageTimer:Start(520 - elapsed)
	end
	timerRisingAnger:Start("v18-26") -- REVIEW! AC: 16-24s plus Jump to Hand (10N AC [2026-10-11]) - 22.8
	timerNextStomp:Start(15-delay)
	timerImpaleCD:Start(9.8-delay) -- (10N AC [2026-10-11]) - 9.8
	updateHealthFrame(1)
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

--These remain methods since they can't reverse schedule each other as local functions
function mod:WormsEmerge()
	timerEmerge:Cancel()
	timerSubmerge:Start()
	if not self.vb.AcidmawDead then
		if self.vb.DreadscaleActive then
			timerSweepCD:Start()
			timerParalyticSprayCD:Start(10)
		else
			timerSlimePoolCD:Start(14.5)
			timerParalyticBiteCD:Start(6)
			timerAcidicSpewCD:Start(11)
		end
	end
	if not self.vb.DreadscaleDead then
		if self.vb.DreadscaleActive then
			timerSlimePoolCD:Start(14.5)
			timerMoltenSpewCD:Start(11)
			timerBurningBiteCD:Start(6)
		else
			timerSweepCD:Start()
			timerBurningSprayCD:Start(15)
		end
	end
	self:ScheduleMethod(45, "WormsSubmerge")
end

function mod:WormsSubmerge()
	timerSubmerge:Cancel()
	timerEmerge:Start()
	timerSweepCD:Cancel()
	timerSlimePoolCD:Cancel()
	timerMoltenSpewCD:Cancel()
	timerParalyticSprayCD:Cancel()
	timerBurningBiteCD:Cancel()
	timerAcidicSpewCD:Cancel()
	timerBurningSprayCD:Cancel()
	timerParalyticBiteCD:Cancel()
	self.vb.DreadscaleActive = not self.vb.DreadscaleActive
	self.vb.WormsSynced = false
	self:ScheduleMethod(10, "WormsEmerge")
end

-- AC: engage/emerge is not visible, but the new form spits or spews right away
function mod:WormsCheckEmerge(dreadscaleActive)
	if not self.vb.WormsSynced and self.vb.DreadscaleActive == dreadscaleActive then
		self.vb.WormsSynced = true
		self:UnscheduleMethod("WormsEmerge")
		self:UnscheduleMethod("WormsSubmerge")
		self:WormsEmerge()
	end
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 66313 then									-- FireBomb (Impaler)
		warnFireBomb:Show()
	elseif args:IsSpellID(66330, 67647, 67648, 67649) then		-- Staggering Stomp
		timerNextStomp:Start()
		specWarnSilence:Show()
		specWarnStompPreWarn:Schedule(17) -- prewarn 3 sec before next
		if self.Options.soundConcAuraMastery and isBuffOwner("player", 19746) then -- Concentration Aura Mastery by a Paladin will negate the interrupt effect of Staggering Stomp
			soundAuraMastery:Schedule(17, "Interface\\AddOns\\DBM-Core\\sounds\\PlayerAbilities\\AuraMastery.ogg")
		else
			specWarnStompPreWarn:ScheduleVoice(17, "silencesoon")
		end
	elseif args:IsSpellID(66880, 67606, 67607, 67608) then		-- Acid Spit
		self:WormsCheckEmerge(true)
	elseif args:IsSpellID(66796, 67632, 67633, 67634) then		-- Fire Spit
		self:WormsCheckEmerge(false)
	elseif args:IsSpellID(66794, 67644, 67645, 67646) then		-- Sweep stationary worm
		timerSweepCD:Start()
	elseif spellId == 66821 then							-- Molten spew
		self:WormsCheckEmerge(true)
		timerMoltenSpewCD:Start()
	elseif spellId == 66818 then							-- Acidic Spew
		self:WormsCheckEmerge(false)
		timerAcidicSpewCD:Start()
	elseif args:IsSpellID(66901, 67615, 67616, 67617) then		-- Paralytic Spray
		timerParalyticSprayCD:Start()
	elseif args:IsSpellID(66902, 67627, 67628, 67629) then		-- Burning Spray
		self.vb.burnIcon = 1
		timerBurningSprayCD:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(67641, 66883, 67642, 67643) then			-- Slime Pool Cloud Spawn
		warnSlimePool:Show()
		timerSlimePoolCD:Start()
	elseif args:IsSpellID(66824, 67612, 67613, 67614) then		-- Paralytic Bite
		timerParalyticBiteCD:Start()
	elseif args:IsSpellID(66879, 67624, 67625, 67626) then		-- Burning Bite
		timerBurningBiteCD:Start()
	elseif args:IsSpellID(66331, 67477, 67478, 67479) then		-- Impale (cast, since the aura only refreshes at max stacks)
		timerImpaleCD:Start()
	elseif args:IsSpellID(66689, 67650, 67651, 67652) then		-- Arctic Breath
		timerBreath:Start()
		timerBreathCD:Start()
		warnBreath:Show()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if args:IsSpellID(67477, 66331, 67478, 67479) then	-- Impale
		warnImpaleOn:Show(args.destName, 1)
	elseif args:IsSpellID(67657, 66759, 67658, 67659) then	-- Frothing Rage
		timerBreathCD:Start("v5-8") -- AC: 5-8s after trample
		timerNextCrash:Start("v32-52") -- AC: Jump to middle 30-50s after trample, Massive Crash ~2.3s later
		warnRage:Show()
		specWarnFrothingRage:Show()
		specWarnFrothingRage:Play("trannow")
	elseif args:IsSpellID(66823, 67618, 67619, 67620) then	-- Paralytic Toxin
		warnToxin:CombinedShow(0.3, args.destName)
		if args:IsPlayer() then
			specWarnToxin:Show(bileName)
			specWarnToxin:Play("targetyou")
		end
	elseif spellId == 66869 then	-- Burning Bile
		warnBile:CombinedShow(0.3, args.destName)
		if args:IsPlayer() then
			specWarnBile:Show()
			specWarnBile:Play("targetyou")
		end
		if self.Options.SetIconOnBileTarget and self.vb.burnIcon < 9 then
			self:SetIcon(args.destName, self.vb.burnIcon)
			self.vb.burnIcon = self.vb.burnIcon + 1
		end
	elseif spellId == 66758 then	-- Staggered Daze
		timerStaggeredDaze:Start()
		timerNextCrash:Start("v47-67") -- AC: Jump to middle 30-50s after trample, delayed by 15s stun, Massive Crash ~2.3s later
	elseif spellId == 66636 then	-- Rising Anger
		WarningSnobold:Show(args.destName)
		timerRisingAnger:Start()
	elseif spellId == 68335 then	-- Enrage
		warnEnrageWorm:Show()
	end
end

function mod:SPELL_AURA_APPLIED_DOSE(args)
	if args:IsSpellID(67477, 66331, 67478, 67479) then	-- Impale
		local amount = args.amount or 1
		if (amount >= 3) or (amount >= 2 and self:IsHeroic()) then
			if args:IsPlayer() then
				specWarnImpale3:Show(amount)
				specWarnImpale3:Play("stackhigh")
			else
				warnImpaleOn:Show(args.destName, amount)
			end
		end
	elseif args.spellId == 66636 then	-- Rising Anger
		local amount = args.amount or 1
		WarningSnobold:Show(args.destName)
		timerRisingAnger:Start()
		if amount >= 4 then
			specWarnAnger3:Show(amount)
			specWarnAnger3:Play("stackhigh")
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 66869 then
		if self.Options.SetIconOnBileTarget then
			self:SetIcon(args.destName, 0)
		end
	elseif spellId == 66758 then -- Staggered Daze
		timerBreathCD:Start("v5-8") -- AC: 5-8s after trample, delayed by the 15s stun
	end
end

function mod:SPELL_DAMAGE(_, _, _, destGUID, _, _, spellId, spellName)
	if ((spellId == 66320 or spellId == 67472 or spellId == 67473 or spellId == 67475 or spellId == 66317) or (spellId == 66881 or spellId == 67638 or spellId == 67639 or spellId == 67640)) and destGUID == UnitGUID("player") and self:AntiSpam(3, 1) then	-- Fire Bomb (66317 is impact damage, not avoidable but leaving in because it still means earliest possible warning to move. Other 4 are tick damage from standing in it) // Slime Pool
		specWarnGTFO:Show(spellName)
		specWarnGTFO:Play("watchfeet")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg, _, _, _, target)
	if (msg:match(L.Charge) or msg:find(L.Charge)) and target then
		target = DBM:GetUnitFullName(target)
		warnCharge:Show(target)
		if self.Options.ClearIconsOnIceHowl then
			self:ClearIcons()
		end
		if target == UnitName("player") then
			specWarnCharge:Show()
			specWarnCharge:Play("justrun")
			if self.Options.PingCharge then
				Minimap:PingLocation()
			end
		elseif self:CheckNearby(11, target) then
			specWarnChargeNear:Show(target)
			specWarnChargeNear:Play("runaway")
		end
		if self.Options.IcehowlArrow then
			local uId = DBM:GetRaidUnitId(target)
			local x, y = GetPlayerMapPosition(uId)
			if x == 0 and y == 0 then
				SetMapToCurrentZone()
				x, y = GetPlayerMapPosition(uId)
			end
			DBM.Arrow:ShowRunAway(x, y, 12, 5)
		end
		if self.Options.SetIconOnChargeTarget then
			self:SetIcon(target, 8, 5)
		end
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.CombatStart or msg:find(L.CombatStart) then
		introTime = GetTime()
		timerCombatStart:Start()
	elseif msg == L.Phase2 or msg:find(L.Phase2) then
		self:SetStage(2)
		self.vb.WormsSynced = false
		self:ScheduleMethod(17, "WormsEmerge")
		timerCombatStart:Start(17) -- (10N AC [2026-10-11]) - Acidmaw Emerge 18.0, Dreadscale first melee 16.7
		timerNextBoss:Cancel()
		if self:IsHeroic() and introTime > 0 then
			timerNextBoss:Start(340 - (GetTime() - introTime))
		end
		updateHealthFrame(2)
		if self.Options.RangeFrame then
			DBM.RangeCheck:Show(10)
		end
	elseif msg == L.Phase3 or msg:find(L.Phase3) then
		updateHealthFrame(3)
		self:SetStage(3)
		timerBreathCD:Start("v30-33") -- AC: engage 13s after yell, Arctic Breath 17-20s after engage
		timerNextCrash:Start(50.2) -- AC: engage 13s after yell, Jump to middle 35s after engage, Massive Crash ~2.2s later
		self:UnscheduleMethod("WormsSubmerge")
		self:UnscheduleMethod("WormsEmerge")
		timerCombatStart:Start(13) -- AC: summon 3s after yell, attack 10s later
		timerNextBoss:Cancel()
		timerSubmerge:Cancel()
		timerEmerge:Cancel()
		if self.Options.RangeFrame then
			DBM.RangeCheck:Hide()
		end
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 34796 then
		specWarnStompPreWarn:Cancel()
		specWarnStompPreWarn:CancelVoice()
		soundAuraMastery:Cancel()
		timerNextStomp:Stop()
		timerImpaleCD:Stop()
		timerRisingAnger:Stop()
		DBM.BossHealth:RemoveBoss(cid) -- remove Gormok from the health frame
	elseif cid == 35144 then -- Acidmaw dead
		self.vb.AcidmawDead = true
		timerParalyticSprayCD:Cancel()
		timerParalyticBiteCD:Cancel()
		timerAcidicSpewCD:Cancel()
		if self.vb.DreadscaleActive then
			timerSweepCD:Cancel()
		else
			timerSlimePoolCD:Cancel()
		end
		if self.vb.DreadscaleDead then
			timerNextBoss:Cancel()
			DBM.BossHealth:RemoveBoss(35144)
			DBM.BossHealth:RemoveBoss(34799)
		end
	elseif cid == 34799 then -- Dreadscale dead
		self.vb.DreadscaleDead = true
		timerBurningSprayCD:Cancel()
		timerBurningBiteCD:Cancel()
		timerMoltenSpewCD:Cancel()
		if self.vb.DreadscaleActive then
			timerSlimePoolCD:Cancel()
		else
			timerSweepCD:Cancel()
		end
		if self.vb.AcidmawDead then
			timerNextBoss:Cancel()
			DBM.BossHealth:RemoveBoss(35144)
			DBM.BossHealth:RemoveBoss(34799)
		end
	elseif cid == 34797 then
		DBM:EndCombat(self)
	end
end

function mod:UNIT_SPELLCAST_START(_, spellName)
	if spellName == GetSpellInfo(66683) then -- Massive Crash
		self:SendSync("MassiveCrash")
	end
end

function mod:OnSync(msg)
	if msg == "MassiveCrash" and self:IsInCombat() then
		timerBreathCD:Cancel()
		timerNextCrash:Cancel()
	end
end
