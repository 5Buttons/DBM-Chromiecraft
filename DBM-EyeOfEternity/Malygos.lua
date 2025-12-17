local mod	= DBM:NewMod("Malygos", "DBM-EyeOfEternity")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20251221025043")
mod:SetCreatureID(28859)

mod:RegisterCombat("yell", L.YellPull)
--mod:RegisterCombat("combat")
mod:SetWipeTime(45)

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL"
)

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 60936 57407 56263 57429",
	"SPELL_CAST_START 56505",
	"SPELL_CAST_SUCCESS 56105 57430",
	"CHAT_MSG_RAID_BOSS_EMOTE"
--	"UNIT_SPELLCAST_SUCCEEDED boss1"
)
-- General
local enrageTimer				= mod:NewBerserkTimer(615)
local timerAchieve				= mod:NewAchievementTimer(360, 1875)

-- Stage One
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1))
local warnSummonPowerSpark		= mod:NewSpellAnnounce(56140, 2, 59381)
local warnVortex				= mod:NewSpellAnnounce(56105, 3)
local warnVortexSoon			= mod:NewSoonAnnounce(56105, 2)

local timerSummonPowerSpark		= mod:NewCDTimer("v20-30", 56140, nil, nil, nil, 1, 59381, DBM_COMMON_L.DAMAGE_ICON)
local timerVortex				= mod:NewCastTimer(10, 56105, nil, nil, nil, 5, nil, DBM_COMMON_L.HEALER_ICON)
local timerVortexCD				= mod:NewCDTimer(78, 56105, nil, nil, nil, 2)

-- Stage Two
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2))
local warnPhase2				= mod:NewPhaseAnnounce(2)
local warnBreathInc				= mod:NewSoonAnnounce(56505, 3)

local specWarnBreath			= mod:NewSpecialWarningSpell(56505, nil, nil, nil, 2, 2)

local timerBreath				= mod:NewBuffActiveTimer(8, 56505, nil, nil, nil, 5) --lasts 5 seconds plus 3 sec cast.
local timerBreathCD				= mod:NewCDTimer(65, 56505, nil, nil, nil, 2)
local timerIntermission			= mod:NewPhaseTimer(22)

-- Stage Three
mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(3))
local warnPhase3				= mod:NewPhaseAnnounce(3)
local warnSurge					= mod:NewTargetAnnounce(60936, 3)
local warnStaticField			= mod:NewTargetNoFilterAnnounce(57430, 3)

local specWarnSurge				= mod:NewSpecialWarningDefensive(60936, nil, nil, nil, 1, 2)
local specWarnP3SurgeOfPowerSoon= mod:NewSpecialWarningYou(60936, nil, nil, nil, 1, 2)
local specWarnStaticField		= mod:NewSpecialWarningYou(57430, nil, nil, nil, 1, 2)
local specWarnStaticFieldNear	= mod:NewSpecialWarningClose(57430, nil, nil, nil, 1, 2)
local yellStaticField			= mod:NewYellMe(57430)

local timerStaticFieldCD		= mod:NewCDTimer(12, 57430, nil, nil, nil, 3, nil, nil, true)
--local timerAttackable			= mod:NewTimer(24, "Malygos Wipes Debuffs") -- Not enough info nor locales on the code from previous contributor to know what this is intended for. Disabled for now

local tableBuild = false
local guids = {}

local function buildGuidTable()
	table.wipe(guids)
	for uId in DBM:GetGroupMembers() do
		local name, server = UnitName(uId)
		local fullName = name .. (server and server ~= "" and ("-" .. server) or "")
		guids[UnitGUID(uId.."pet") or "none"] = fullName
	end
	tableBuild = true
end

function mod:StaticFieldTarget()
	local targetname, uId = self:GetBossTarget(28859)
	if not targetname or not uId then return end
	local targetGuid = UnitGUID(uId)
	if not tableBuild then
		buildGuidTable()
	end
	local announcetarget = guids[targetGuid]
	if announcetarget == UnitName("player") then
		specWarnStaticField:Show()
		specWarnStaticField:Play("runaway")
		yellStaticField:Yell()
	elseif announcetarget and self:CheckNearby(13, announcetarget) then
		specWarnStaticFieldNear:Show(announcetarget)
		specWarnStaticFieldNear:Play("runaway")
	else
		warnStaticField:Show(announcetarget)
	end
end

function mod:OnCombatStart(delay)
    tableBuild = false
    self:SetStage(1)
    enrageTimer:Start(-delay)
    timerAchieve:Start(-delay)
    timerVortexCD:Start(35-delay)
    timerSummonPowerSpark:Start("v16-28")
    table.wipe(guids)
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(60936, 57407) then
		DBM:Debug("SURGE on: " .. (guids[args.destGUID] or "Unknown"), 2)
		local target = guids[args.destGUID]
		timerSurgeCD:Start()
		if target then
			warnSurge:CombinedShow(0.5, target)
			if target == UnitName("player") then
				specWarnSurge:Show()
				specWarnSurge:Play("defensive")
			end
		end
	elseif args:IsSpellID(57429) then
		if self:AntiSpam(3, "StaticField") then
			self:StaticFieldTarget(args.destGUID)
			timerStaticFieldCD:Start()
		end
	end
end

-- not really sure which one this spell is casted by. Use both i guess
function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if self:GetCIDFromGUID(args.sourceGUID) == 28859 then
		DBM:Debug("SCStart " .. spellId .. GetSpellLink(spellId) , 2)
	end
	if spellId == 56505 then--His deep breath
		specWarnBreath:Show()
		specWarnBreath:Play("findshield")
		timerBreath:Start()
		timerBreathCD:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if self:GetCIDFromGUID(args.sourceGUID) == 28859 then
		DBM:Debug("SCSuccess " .. spellId .. GetSpellLink(spellId) , 2)
	end
--	if spellId == 56105 then
--		timerVortexCD:Start()
---		warnVortexSoon:Schedule(54)
--		warnVortex:Show()
--		timerVortex:Start()
		-- Commenting this block out, since Sparks are fixed on a 30s interval... no need to correct anything on the fly
--		if timerSummonPowerSpark:GetTime() < 11 and timerSummonPowerSpark:IsStarted() then
--			timerSummonPowerSpark:Update(18, 30)
--		end
	if spellId == 57430 then
		self:ScheduleMethod(0.1, "StaticFieldTarget")
		--warnStaticField:Show()
		timerStaticFieldCD:Start()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
    --Secondary pull trigger
    if (msg == L.YellPull or msg:find(L.YellPull)) and not self:IsInCombat() then
        DBM:StartCombat(self, 0)
	elseif msg == L.YellVortex or msg:find(L.YellVortex) then
		timerVortex:Start()
		timerVortexCD:Start()
		warnVortexSoon:Schedule(70)
		warnVortex:Show()
        local elapsed, total = timerSummonPowerSpark:GetTime()
        if elapsed and total and total > 0 then
            local remaining = total - elapsed
            local newMax = remaining + 25
            local newMin = newMax - 10
            timerSummonPowerSpark:Stop()
            timerSummonPowerSpark:Start(("v%.1f-%.1f"):format(newMin, newMax))
        end
    elseif msg:sub(0, L.YellPhase2:len()) == L.YellPhase2 then
        self:SendSync("Phase2")
	elseif msg == L.YellBreath or msg:find(L.YellBreath) then
		self:SendSync("BreathSoon")
	elseif msg:sub(0, L.YellPhase3:len()) == L.YellPhase3 then
		self:SendSync("Phase3")
	elseif msg == L.EnoughScream then
		timerBreathCD:Stop()
--		timerAttackable:Start()
--		timerStaticFieldCD:Start(6)
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.EmoteSpark or msg:find(L.EmoteSpark) then
		warnSummonPowerSpark:Show()
		timerSummonPowerSpark:Start()
	end
	if msg == L.EmoteSurge or msg:find(L.EmoteSurge) then
		self:SendSync("MalygosSurge", UnitName("player"))
	end
end

--[[localization free triggers that's better but can only be used where boss1 UnitId available
function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
--	"<39.8> [UNIT_SPELLCAST_SUCCEEDED] Malygos:Possible Target<Omegal>:target:Summon Power Spark::0:56140", -- [998]
	if spellName == GetSpellInfo(56140) then
		warnSummonPowerSpark:Show()
		timerSummonPowerSpark:Start()
	end
end]]

function mod:OnSync(event, arg)
	if not self:IsInCombat() then return end
	if event == "Phase2" then
		self:SetStage(2)
		timerSummonPowerSpark:Cancel()
		timerVortexCD:Cancel()
		warnVortexSoon:Cancel()
		warnPhase2:Show()
		timerIntermission:Start()
		timerBreathCD:Start(65) -- REVIEW! no variance? (10man Lordaeron 2022/09/27 || 25man Lordaeron 2022/09/27) - Stage 2/68.0 || Stage 2/68.0
	elseif event == "BreathSoon" then
		warnBreathInc:Show()
	elseif event == "Phase3" then
		self:SetStage(3)
		warnPhase3:Show()
		self:Schedule(6, buildGuidTable)
		timerBreathCD:Cancel()
--		timerStaticFieldCD:Start(20.2) -- REVIEW! ~4s variance? (10man Lordaeron 2022/09/27 || 25man Lordaeron 2022/09/27) - Stage 3/24.5 || Stage 3/20.2
	elseif event == "MalygosSurge" then
		warnSurge:CombinedShow(0.2, arg)
		if arg == UnitName("player") then
			specWarnP3SurgeOfPowerSoon:Show()
			specWarnP3SurgeOfPowerSoon:Play("findshield")
		end
	end
end
