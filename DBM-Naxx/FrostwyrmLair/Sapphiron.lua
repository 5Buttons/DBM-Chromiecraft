local mod	= DBM:NewMod("Sapphiron", "DBM-Naxx", 5)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260222224400")
mod:SetCreatureID(15989)
mod:SetEncounterID(1119)
mod:SetHotfixNoticeRev(20251222224400)
mod:SetMinSyncRevision(20220904000000)

mod:RegisterCombat("combat")
mod:SetModelScale(0.1)

mod:RegisterEventsInCombat(
--	"SPELL_CAST_START 28524",
	"SPELL_CAST_SUCCESS 28542 55665 28560 55696",
	"SPELL_AURA_APPLIED 28522 28547 55699",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UNIT_HEALTH"
)

--TODO, verify SPELL_CAST_START on retail to switch to it over emote, same as classicc era was done

-- General
local specWarnLowHP		= mod:NewSpecialWarning("SpecWarnSapphLow")

local berserkTimer		= mod:NewBerserkTimer(900)

-- Stage One (Ground Phase)
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1))
local warnDrainLifeNow	= mod:NewSpellAnnounce(28542, 2)
local warnDrainLifeSoon	= mod:NewSoonAnnounce(28542, 1)
local warnAirPhaseSoon	= mod:NewAnnounce("WarningAirPhaseSoon", 3, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendUnBurrow.blp")
local warnLanded		= mod:NewAnnounce("WarningLanded", 4, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendBurrow.blp")
local warnBlizzard		= mod:NewSpellAnnounce(28560, 4)

local specWarnBlizzard	= mod:NewSpecialWarningGTFO(28547, nil, nil, nil, 1, 8)

local timerDrainLife	= mod:NewCDTimer(24, 28542, nil, nil, nil, 3, nil, DBM_COMMON_L.CURSE_ICON) -- (25man Lordaeron 2022/09/02) - 24.0
local timerAirPhase		= mod:NewTimer(60, "TimerAir", "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendUnBurrow.blp", nil, nil, 6)
local timerBlizzard		= mod:NewNextTimer(6.5, 28560, nil, nil, nil, 3)
local timerTailSweep	= mod:NewNextTimer(10, 55696, nil, nil, nil, 2)

-- Stage Two (Air Phase)
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2))
local warnAirPhaseNow	= mod:NewAnnounce("WarningAirPhaseNow", 4, "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendUnBurrow.blp")
local warnIceBlock		= mod:NewTargetAnnounce(28522, 2)

local specWarnDeepBreath= mod:NewSpecialWarningSpell(28524, nil, nil, nil, 1, 2)
local yellIceBlock		= mod:NewYell(28522)

local timerLanding		= mod:NewTimer(20.5, "TimerLanding", "Interface\\AddOns\\DBM-Core\\textures\\CryptFiendBurrow.blp", nil, nil, 6)
local timerIceBlast		= mod:NewCastTimer(8, 28524, nil, nil, nil, 2, DBM_COMMON_L.DEADLY_ICON)

mod:AddRangeFrameOption("12")

--local UnitAffectingCombat = UnitAffectingCombat
--local noTargetTime = 0
local warned_lowhp = false
mod.vb.isFlying = false

--[[local function resetIsFlying(self)
	self.vb.isFlying = false
end]]

--[[local function Landing(self)
	self:SetStage(1)
	warnLanded:Show()
	warnDrainLifeSoon:Schedule(5)
	timerDrainLife:Start(10.5)
	warnAirPhaseSoon:Schedule(50)
	timerAirPhase:Cancel()  -- cancel any existing timer
	timerAirPhase:Start()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
		self:Schedule(59, DBM.RangeCheck.Show, DBM.RangeCheck, 12)
	end
end]]
function mod:OnCombatStart(delay)
--	noTargetTime = 0
	warned_lowhp = false
	self:SetStage(1)
	self.vb.isFlying = false
	warnDrainLifeSoon:Schedule(6.5-delay)
	timerDrainLife:Start(17-delay)
	timerBlizzard:Start(17-delay)
	timerTailSweep:Start(-delay)
	warnAirPhaseSoon:Schedule(35.74-delay)
	timerAirPhase:Start(45.74-delay)
	berserkTimer:Start(-delay)
	if self.Options.RangeFrame then
		self:Schedule(46-delay, DBM.RangeCheck.Show, DBM.RangeCheck, 12)
	end
--[[self:RegisterOnUpdateHandler(function(self, elapsed)
		if not self:IsInCombat() then return end
		local foundBoss, target
		for uId in DBM:GetGroupMembers() do
			local unitID = uId.."target"
			if self:GetUnitCreatureId(unitID) == 15989 and UnitAffectingCombat(unitID) then
				target = DBM:GetUnitFullName(unitID.."target")
				foundBoss = true
				break
			end
		end
		if foundBoss and not target then
			noTargetTime = noTargetTime + elapsed
		elseif foundBoss then
			noTargetTime = 0
		end
		if noTargetTime > 0.5 and not self.vb.isFlying then
			noTargetTime = 0
			self:SetStage(2)
			self.vb.isFlying = true
			self:Schedule(60, resetIsFlying, self)
			timerDrainLife:Cancel()
			timerAirPhase:Cancel()
			warnAirPhaseNow:Show()
			timerLanding:Start()
		end
	end, 0.2)]]
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 28522 then
		warnIceBlock:CombinedShow(0.5, args.destName)
		if args:IsPlayer() then
			yellIceBlock:Yell()
		end
	elseif args:IsSpellID(28547, 55699) and args:IsPlayer() and self:AntiSpam(1) then
		specWarnBlizzard:Show(args.spellName)
		specWarnBlizzard:Play("watchfeet")
	end
end

--[[
function mod:SPELL_CAST_START(args)
	--if args:IsSpellID(28524, 29318) then--NEEDS verification before deployed
		timerIceBlast:Start()
		timerLanding:Update(16.3, 28.5)--Probably not even needed, if base timer is more accurate
		self:Schedule(12.2, Landing, self)
		warnDeepBreath:Show()
		warnDeepBreath:Play("findshelter")
	end
end
--]]

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if args:IsSpellID(28542, 55665) then -- Life Drain
		warnDrainLifeNow:Show()
		warnDrainLifeSoon:Schedule(18.5)
		timerDrainLife:Start()
	elseif spellId == 28560 then
		DBM:AddMsg("Blizzard SPELL_CAST_SUCCESS unhidden from combat log. Notify Fivebuttons on Discord or GitHub")
		warnBlizzard:Show()
		if self:IsHeroic() then
			timerBlizzard:Start(6.5) -- 25-man
		else
			timerBlizzard:Start(8) -- 10-man
		end
	elseif spellId == 55696 then
		timerTailSweep:Start()
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.EmoteBreath or msg:find(L.EmoteBreath) then
		timerIceBlast:Start()
		timerLanding:Update(6, 20.1)
		specWarnDeepBreath:Show()
		specWarnDeepBreath:Play("findshelter")
	elseif msg == L.AirPhase or msg:find(L.AirPhase) then
		self:SetStage(2)
		self.vb.isFlying = true
		timerDrainLife:AddTime(35) --all abilities are delayed by 35 seconds on AC
		self:Unschedule(warnDrainLifeSoon.Show, warnDrainLifeSoon)
		warnDrainLifeSoon:Schedule(timerDrainLife:GetRemaining() - 5.5)-- Add 35 seconds to the timer
		timerAirPhase:Cancel()
		warnAirPhaseNow:Show()
		timerLanding:Start()
	elseif msg == L.LandingPhase or msg:find(L.LandingPhase) then
		self:SetStage(1)
		self.vb.isFlying = false
		warnLanded:Show()
		warnAirPhaseSoon:Schedule(50)
		timerAirPhase:Cancel()
		timerAirPhase:Start()
		if self.Options.RangeFrame then
			DBM.RangeCheck:Hide()
			self:Schedule(59, DBM.RangeCheck.Show, DBM.RangeCheck, 12)
		end
	end
end

function mod:UNIT_HEALTH(uId)
	local cid = self:GetUnitCreatureId(uId)
	if cid == 15989 and not warned_lowhp and UnitHealth(uId) / UnitHealthMax(uId) < 0.1 then
		warned_lowhp = true
		specWarnLowHP:Show()
		timerAirPhase:Cancel()
		self:Unschedule(warnAirPhaseSoon.Show, warnAirPhaseSoon)
	end
end

--[[function mod:OnSync(event)
	if event == "DeepBreath" then
		timerIceBlast:Start()
		timerLanding:Update(14)
		self:Schedule(14.5, Landing, self)
		specWarnDeepBreath:Show()
		specWarnDeepBreath:Play("findshelter")
	end
end]]
