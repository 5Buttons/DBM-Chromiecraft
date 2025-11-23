local mod	= DBM:NewMod("BrannBronzebeard", "DBM-Party-WotLK", 7)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20251123220131")
mod:SetCreatureID(28070)
mod:SetEncounterID(567)
mod:SetMinSyncRevision(20251123220131)

mod:RegisterCombat("yell", L.Pull)
mod:RegisterKill("yell", L.Kill)
mod:SetMinCombatTime(300) --first check for combat set to event duration
mod:SetWipeTime(20)

mod:RegisterEventsInCombat(
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_DIED"
)

local warningPhase	= mod:NewAnnounce("WarningPhase", 2, "Interface\\Icons\\Spell_Nature_WispSplode")

local timerEvent	= mod:NewTimer(302, "timerEvent", "Interface\\Icons\\Spell_Holy_BorrowedTime", nil, nil, 6)

function mod:OnCombatStart(delay)
	timerEvent:Start(-delay)
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if L.Phase1 == msg then
		warningPhase:Show(1)
	elseif msg == L.Phase2 then
		warningPhase:Show(2)
	elseif msg == L.Phase3 then
		warningPhase:Show(3)
	end
end

function mod:UNIT_DIED(args) --serves as a wipe detection function since SetMinCombatTime is set to 300s in order to keep the timer alive
	-- If Brann Bronzebeard (28070) dies, the event has failed.
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 28070 then
		DBM:EndCombat(self)
		self:SendSync("BrannDied") --add sync for ppl who release on a wipe before brann dies
	end
end

function mod:OnSync(msg)
	if msg == "BrannDied" then
		DBM:EndCombat(self)
	end
end