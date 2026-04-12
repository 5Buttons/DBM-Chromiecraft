local mod	= DBM:NewMod("Sartharion", "DBM-ChamberOfAspects", 1)
local L		= mod:GetLocalizedStrings()

mod.statTypes = "normal,normal25"

mod:SetRevision("20260412220131")
mod:SetCreatureID(28860)
mod:SetEncounterID(742)

mod:RegisterCombat("yell", L.YellSarthPull)

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 56908 58956",
	"SPELL_CAST_SUCCESS 57579 59127",
	"SPELL_AURA_APPLIED 57491",
	"SPELL_DAMAGE 59128",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_MONSTER_EMOTE"
)

local warnShadowFissure			= mod:NewSpellAnnounce(59127, 4, nil, nil, nil, nil, nil, 2)
local warnBreathSoon			= mod:NewSoonAnnounce(58956, 2, nil, "Tank|Healer")
local warnTenebron				= mod:NewAnnounce("WarningTenebron", 2, 61248)
local warnShadron				= mod:NewAnnounce("WarningShadron", 2, 58105)
local warnVesperon				= mod:NewAnnounce("WarningVesperon", 2, 61251)
local warnTenebronWhelpsSoon	= mod:NewAnnounce("WarningWhelpsSoon", 1, 1022, false)
local warnShadronPortalSoon		= mod:NewAnnounce("WarningPortalSoon", 1, 11420, false)
local warnVesperonPortalSoon	= mod:NewAnnounce("WarningReflectSoon", 1, 57988, false)

local specWarnFireWall			= mod:NewSpecialWarning("WarningFireWall", nil, nil, nil, 2, 2)
local specWarnVesperonPortal	= mod:NewSpecialWarning("WarningVesperonPortal", false, nil, nil, 1, 7)
local specWarnTenebronPortal	= mod:NewSpecialWarning("WarningTenebronPortal", false, nil, nil, 1, 7)
local specWarnShadronPortal		= mod:NewSpecialWarning("WarningShadronPortal", false, nil, nil, 1, 7)

local timerShadowFissure		= mod:NewCastTimer(5, 59128, nil, nil, nil, 3, nil, DBM_COMMON_L.DEADLY_ICON)
local timerBreath 				= mod:NewCDTimer(10, 58956, nil, false, "Tank|Healer", 5)
local timerWall					= mod:NewNextTimer(25, 43113, nil, nil, nil, 2)

--Drake and Portals timings
local timerTenebron       = mod:NewTimer(28, "TimerTenebron", 61248, nil, nil, 1)
local timerShadron        = mod:NewTimer (68, "TimerShadron", 58105, nil, nil, 1)
local timerVesperon       = mod:NewTimer(122, "TimerVesperon", 61251, nil, nil, 1)
local timerTenebronWhelps = mod:NewTimer(49, "TimerTenebronWhelps", 1022)
local timerShadronPortal  = mod:NewTimer(23, "TimerShadronPortal", 11420)
local timerVesperonPortal = mod:NewTimer(36, "TimerVesperonPortal", 57988)

mod:AddBoolOption("AnnounceFails", true, "announce")

mod:GroupSpells(59127, 59128)--Shadow fissure with void blast

local lastvoids = {}
local lastfire = {}
local tsort, tinsert, twipe = table.sort, table.insert, table.wipe

local function isunitdebuffed(spellName)
	for uId in DBM:GetGroupMembers() do
		local debuff = DBM:UnitDebuff(uId, spellName)
		if debuff then
			return true
		end
	end
	return false
end

local function CheckDrakes(self, delay)
    if self.Options.HealthFrame then
        DBM.BossHealth:Show(L.name)
        DBM.BossHealth:AddBoss(28860, "Sartharion")
    end
    if isunitdebuffed(DBM:GetSpellInfo(61248)) then    -- Power of Tenebron
        timerTenebron:Start(-delay)
        warnTenebron:Schedule(25-delay)
--        timerTenebronWhelps:Start(-delay)
--        warnTenebronWhelpsSoon:Schedule(-delay)
        if self.Options.HealthFrame then
            DBM.BossHealth:AddBoss(30452, "Tenebron")
        end
    end
    if isunitdebuffed(DBM:GetSpellInfo(58105)) then    -- Power of Shadron
        timerShadron:Start(-delay)
        warnShadron:Schedule(62-delay)
--        timerShadronPortal:Start(-delay)
--        warnShadronPortalSoon:Schedule(-delay)
        if self.Options.HealthFrame then
            DBM.BossHealth:AddBoss(30451, "Shadron")
        end
    end
    if isunitdebuffed(DBM:GetSpellInfo(61251)) then    -- Power of Vesperon
        timerVesperon:Start(-delay)
        warnVesperon:Schedule(115-delay)
--        timerVesperonPortal:Start(-delay)
--        warnVesperonPortalSoon:Schedule(-delay)
        if self.Options.HealthFrame then
            DBM.BossHealth:AddBoss(30449, "Vesperon")
        end
    end
end

local sortedFails = {}
local function sortFails1(e1, e2)
	return (lastvoids[e1] or 0) > (lastvoids[e2] or 0)
end
local function sortFails2(e1, e2)
	return (lastfire[e1] or 0) > (lastfire[e2] or 0)
end

function mod:OnCombatStart(delay)
	--Cache spellnames so a solo player check doesn't fail in CheckDrakes in 8.0+
	self:Schedule(5, CheckDrakes, self, delay)
	timerWall:Start(20-delay)
	warnBreathSoon:Schedule(7-delay)
	timerBreath:Start(5-delay)

	twipe(lastvoids)
	twipe(lastfire)
end

function mod:OnCombatEnd()
	if not self.Options.AnnounceFails then return end
	if DBM:GetRaidRank() < 1 or not self.Options.Announce then return end

	local voids = ""
	for k, _ in pairs(lastvoids) do
		tinsert(sortedFails, k)
	end
	tsort(sortedFails, sortFails1)
	for _, v in ipairs(sortedFails) do
		voids = voids.." "..v.."("..(lastvoids[v] or "")..")"
	end
	SendChatMessage(L.VoidZones:format(voids), "RAID")
	twipe(sortedFails)
	local fire = ""
	for k, _ in pairs(lastfire) do
		tinsert(sortedFails, k)
	end
	tsort(sortedFails, sortFails2)
	for _, v in ipairs(sortedFails) do
		fire = fire.." "..v.."("..(lastfire[v] or "")..")"
	end
	SendChatMessage(L.FireWalls:format(fire), "RAID")
	twipe(sortedFails)
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(56908, 58956) then -- Flame breath
		warnBreathSoon:Schedule(15)
		timerBreath:Start()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(57579, 59127) then
		warnShadowFissure:Show()
		warnShadowFissure:Play("watchstep")
		timerShadowFissure:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if self.Options.AnnounceFails and self.Options.Announce and args.spellId == 57491 and DBM:GetRaidRank() >= 1 and DBM:GetRaidUnitId(args.destName) ~= "none" and args.destName then
		lastfire[args.destName] = (lastfire[args.destName] or 0) + 1
		SendChatMessage(L.FireWallOn:format(args.destName), "RAID")
	end
end

function mod:SPELL_DAMAGE(_, _, _, _, destName, _, spellId)
	if self.Options.AnnounceFails and self.Options.Announce and spellId == 59128 and DBM:GetRaidRank() >= 1 and DBM:GetRaidUnitId(destName) ~= "none" and destName then
		lastvoids[destName] = (lastvoids[destName] or 0) + 1
		SendChatMessage(L.VoidZoneOn:format(destName), "RAID")
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg, mob)
    if mob == L.NameTenebron and L.YellTenebronLand and msg:find(L.YellTenebronLand, 1, true) then
        timerTenebronWhelps:Start(49)       -- 22s Portal + 2s Eggs + 25s Hatch
        warnTenebronWhelpsSoon:Schedule(45)
    elseif mob == L.NameShadron and L.YellShadronLand and msg:find(L.YellShadronLand, 1, true) then
        timerShadronPortal:Start(23)
        warnShadronPortalSoon:Schedule(19)
    elseif mob == L.NameVesperon and L.YellVesperonLand and msg:find(L.YellVesperonLand, 1, true) then
        timerVesperonPortal:Start(36)
        warnVesperonPortalSoon:Schedule(32)
    end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg, mob)
    if msg == L.Wall or msg:find(L.Wall) then
        self:SendSync("FireWall")
    elseif msg == L.Portal or msg:find(L.Portal) then
        if mob == L.NameVesperon then
            self:SendSync("VesperonPortal")
        elseif mob == L.NameTenebron then
            self:SendSync("TenebronPortal")
        elseif mob == L.NameShadron then
            self:SendSync("ShadronPortal")
        end
    end
end

function mod:OnSync(event)
	if event == "FireWall" then
		timerWall:Start()
		specWarnFireWall:Show()
		specWarnFireWall:Play("watchwave")
	elseif event == "VesperonPortal" then
		specWarnVesperonPortal:Show()
		specWarnVesperonPortal:Play("newportal")
	elseif event == "TenebronPortal" then
		specWarnTenebronPortal:Show()
		specWarnTenebronPortal:Play("newportal")
	elseif event == "ShadronPortal" then
		specWarnShadronPortal:Show()
		specWarnShadronPortal:Play("newportal")
	end
end
