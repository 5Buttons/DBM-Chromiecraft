local mod	= DBM:NewMod("BrannBronzebeard", "DBM-Party-WotLK", 7)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20251124220131")
mod:SetCreatureID(28070)
mod:SetEncounterID(567)
mod:SetMinSyncRevision(20251123220131)

mod:RegisterCombat("yell", L.Pull)
mod:RegisterKill("yell", L.Kill)
mod:SetMinCombatTime(300) --first check for combat set to event duration
mod:SetWipeTime(20)

mod:RegisterEventsInCombat(
	"CHAT_MSG_MONSTER_YELL"
)

local warningPhase	= mod:NewAnnounce("WarningPhase", 2, "Interface\\Icons\\Spell_Nature_WispSplode")

local timerEvent	= mod:NewTimer(302, "timerEvent", "Interface\\Icons\\Spell_Holy_BorrowedTime", nil, nil, 6)

-- Watchdog function: Forces a wipe if a specific Phase Yell doesn't happen in time.
local function WatchdogWipe()
	mod:EndCombat(true)
end

function mod:OnCombatStart(delay)
	timerEvent:Start(-delay)
	self:Schedule(35, WatchdogWipe)
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	-- Phase 1: Kaddrak ("Security breach...")
	if msg == L.Phase1 then
		warningPhase:Show(1)
		self:Unschedule(WatchdogWipe)
		-- WATCHDOG 2: P1 lasts ~75s. Allow 90s for P2 to start.
		self:Schedule(90, WatchdogWipe)

	-- Phase 2: Marnak ("Threat index...")
	elseif msg == L.Phase2 then
		warningPhase:Show(2)
		self:Unschedule(WatchdogWipe)
		-- WATCHDOG 3: P2 lasts ~102s. Allow 115s for P3 to start.
		self:Schedule(115, WatchdogWipe)

	-- Phase 3: Abedneum ("Critical threat...")
	elseif msg == L.Phase3 then
		warningPhase:Show(3)
		self:Unschedule(WatchdogWipe)
		-- WATCHDOG 4: P3 lasts ~103s. Allow 115s for Kill yell.
		self:Schedule(115, WatchdogWipe)
	end
end