local mod	= DBM:NewMod("GeneralVezax", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260926220131")
mod:SetCreatureID(33271)
mod:SetEncounterID(755)
mod:SetUsedIcons(7, 8)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 62661 62662",
	"SPELL_CAST_SUCCESS 62660 63276",
	"SPELL_AURA_APPLIED 62662 63364",
	"SPELL_AURA_REMOVED 62662",
	"SPELL_INTERRUPT 62661",
	"UNIT_DIED",
	"CHAT_MSG_RAID_BOSS_EMOTE"
--	"UNIT_SPELLCAST_START boss1",
--	"UNIT_SPELLCAST_SUCCEEDED boss1"
)

local warnShadowCrash				= mod:NewTargetAnnounce(62660, 4)
local warnLeechLife					= mod:NewTargetNoFilterAnnounce(63276, 3)
local warnSaroniteVapor				= mod:NewCountAnnounce(63322, 2)

local specWarnShadowCrash			= mod:NewSpecialWarningDodge(62660, nil, nil, nil, 1, 2)
local yellShadowCrash				= mod:NewYell(62660)
local specWarnSurgeDarkness			= mod:NewSpecialWarningDefensive(62662, nil, nil, 2, 1, 2)
local specWarnMarkoftheFacelessYou	= mod:NewSpecialWarningMoveAway(63276, nil, nil, nil, 3, 2)
local yellMarkoftheFaceless			= mod:NewYell(63276)
local specWarnSearingFlames			= mod:NewSpecialWarningInterruptCount(62661, "HasInterrupt", nil, nil, 1, 2)

local timerEnrage					= mod:NewBerserkTimer(600)
 local timerSurgeofDarkness			= mod:NewBuffActiveTimer(10, 62662, nil, "Tank", nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerNextSurgeofDarkness		= mod:NewCDTimer(63, 62662, nil, "Tank", nil, 5, nil, DBM_COMMON_L.TANK_ICON) -- 63s on AC
local timerSaroniteVapors			= mod:NewNextCountTimer(30, 63322, nil, nil, nil, 5, nil, DBM_COMMON_L.HEALER_ICON)
local timerShadowCrashCD			= mod:NewCDTimer(10, 62660, nil, "Ranged", nil, 3) -- 13s on AC
local timerMarkoftheFaceless		= mod:NewTargetTimer(10, 63276, nil, false, 2, 3, nil, DBM_COMMON_L.IMPORTANT_ICON)
local timerMarkoftheFacelessCD		= mod:NewCDTimer(40, 63276, nil, nil, nil, 3, nil, DBM_COMMON_L.IMPORTANT_ICON) -- 40s on AC

mod:AddSetIconOption("SetIconOnShadowCrash", 62660, true, false, {8})
mod:AddSetIconOption("SetIconOnLifeLeach", 63276, true, false, {7})
mod:AddArrowOption("CrashArrow", 62660, true)

-- Hard Mode
mod:AddTimerLine(DBM_COMMON_L.HEROIC_ICON..DBM_CORE_L.HARD_MODE)
local specWarnAnimus			= mod:NewSpecialWarningSwitch(63145, nil, nil, nil, 1, 2)

local timerHardmode				= mod:NewTimer(188, "hardmodeSpawn", nil, nil, nil, 1)

mod.vb.interruptCount = 0
mod.vb.vaporsCount = 0
mod.vb.hardmodeLost = false

function mod:OnCombatStart(delay)
	self.vb.interruptCount = 0
	self.vb.vaporsCount = 0
	self.vb.hardmodeLost = false
	timerShadowCrashCD:Start(13-delay) --13s on AC
	timerMarkoftheFacelessCD:Start(20-delay) -- 20s on AC
	timerSaroniteVapors:Start(30-delay, 1)
	timerEnrage:Start(-delay)
	timerHardmode:Start(-delay)
	timerNextSurgeofDarkness:Start(-delay)
end

local function saroniteVaporsSpawned(self)
	self.vb.vaporsCount = self.vb.vaporsCount + 1
	warnSaroniteVapor:Show(self.vb.vaporsCount)
	if self.vb.vaporsCount < 6 or self.vb.hardmodeLost then
		timerSaroniteVapors:Start(30, self.vb.vaporsCount + 1)
	else -- AC delays events on hard mode after vapor 6
		timerShadowCrashCD:AddTime(12)
		timerMarkoftheFacelessCD:AddTime(12)
		timerNextSurgeofDarkness:AddTime(12)
	end
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 62661 then	-- Searing Flames
		self.vb.interruptCount = self.vb.interruptCount + 1
		if self.vb.interruptCount == 4 then
			self.vb.interruptCount = 1
		end
		local kickCount = self.vb.interruptCount
		specWarnSearingFlames:Show(args.sourceName, kickCount)
		specWarnSearingFlames:Play("kick"..kickCount.."r")
	elseif spellId == 62662 then
		if self:IsTanking("player", "boss1", nil, true) then--Player is current target
			specWarnSurgeDarkness:Show()
			specWarnSurgeDarkness:Play("defensive")
		end
		timerNextSurgeofDarkness:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 62660 then		-- Shadow Crash
--		self:BossTargetScanner(33271, "ShadowCrashTarget", 0.05, 20) -- this method is not needed, since CLEU has destName
		timerShadowCrashCD:Start()
		if self.Options.SetIconOnShadowCrash then
			self:SetIcon(args.destName, 8, 5)
		end
		if args:IsPlayer() then
			specWarnShadowCrash:Show()
			specWarnShadowCrash:Play("runaway")
			yellShadowCrash:Yell()
		else
			warnShadowCrash:Show(args.destName)
		end
		if self.Options.CrashArrow then
			local uId = DBM:GetRaidUnitId(args.destName)
			local x, y = GetPlayerMapPosition(uId)
			if x == 0 and y == 0 then
				SetMapToCurrentZone()
				x, y = GetPlayerMapPosition(uId)
			end
			DBM.Arrow:ShowRunAway(x, y, 13, 5) -- 15yd was too conservative. Try 13yd instead (from personal testing, the hitbox was around ~12.5yd)
		end
	elseif spellId == 63276 then	-- Mark of the Faceless
		if self.Options.SetIconOnLifeLeach then
			self:SetIcon(args.destName, 7, 10)
		end
		timerMarkoftheFaceless:Start(args.destName)
		timerMarkoftheFacelessCD:Start()
		if args:IsPlayer() then
			specWarnMarkoftheFacelessYou:Show()
			specWarnMarkoftheFacelessYou:Play("runout")
			yellMarkoftheFaceless:Yell()
		else
			warnLeechLife:Show(args.destName)
		end
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 62662 then	-- Surge of Darkness
		timerSurgeofDarkness:Start()
	elseif spellId == 63364 then	-- Saronite Barrier
		specWarnAnimus:Show()
		specWarnAnimus:Play("bigmob")
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 62662 then
		timerSurgeofDarkness:Stop()
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 33488 then--Saronite Vapor
		self.vb.hardmodeLost = true
		timerHardmode:Stop()
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(emote)
	if emote == L.EmoteSaroniteVapors or emote:find(L.EmoteSaroniteVapors) then
		self:SendSync("SaroniteVaporsSpawned")
	end
end

function mod:OnSync(msg)
	if msg == "SaroniteVaporsSpawned" and self:AntiSpam(3, 1) then
		saroniteVaporsSpawned(self)
	end
end
