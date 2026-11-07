local mod	= DBM:NewMod("BrannBronzebeard", "DBM-Party-WotLK", 7)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261107120000")
mod:SetCreatureID(28070)
mod:SetEncounterID(567)
mod:SetMinSyncRevision(20251123220131)

mod:RegisterCombat("yell", L.Pull)
mod:SetMinCombatTime(300)
mod:SetWipeTime(20)

mod:RegisterEventsInCombat(
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_DIED"
)

local warningPhase	= mod:NewAnnounce("WarningPhase", 2, "Interface\\Icons\\Spell_Nature_WispSplode")
local timerEvent	= mod:NewTimer(305, "timerEvent", "Interface\\Icons\\Spell_Holy_BorrowedTime", nil, nil, 6)

local killMsg = strtrim(L.Kill)

function mod:WatchdogWipe()
	DBM:EndCombat(self, true)
end

local function armWatchdog(self, t)
	self:Unschedule(self.WatchdogWipe, self)
	self:Schedule(t, self.WatchdogWipe, self)
end

function mod:OnCombatStart(delay)
	timerEvent:Start(-delay)
	armWatchdog(self, 40)
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg:find(L.Phase1, 1, true) then
		warningPhase:Show(1)
		armWatchdog(self, 90)
	elseif msg:find(L.Phase2, 1, true) then
		warningPhase:Show(2)
		armWatchdog(self, 115)
	elseif msg:find(L.Phase3, 1, true) then
		warningPhase:Show(3)
		armWatchdog(self, 115)
	elseif msg:find(killMsg, 1, true) then
		DBM:EndCombat(self)
	end
end

function mod:UNIT_DIED(args)
	if self:GetCIDFromGUID(args.destGUID) == 28070 then
		DBM:EndCombat(self, true)
	end
end
