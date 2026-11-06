local mod	= DBM:NewMod("PT", "DBM-Party-BC", 12)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261105120000")

mod:RegisterEvents(
	"UPDATE_WORLD_STATES",
	"UNIT_DIED",
	"CHAT_MSG_MONSTER_YELL"
)
mod.noStatistics = true

-- Portals
local warnWavePortalSoon	= mod:NewAnnounce("WarnWavePortalSoon", 2, 33404)
local warnWavePortal		= mod:NewAnnounce("WarnWavePortal", 3, 33404)
local warnBossPortal		= mod:NewAnnounce("WarnBossPortal", 4, 33341)

local timerNextPortal		= mod:NewTimer(120, "TimerNextPortal", 33404, nil, nil, 6)

mod:AddBoolOption("ShowAllPortalTimers", false, "timer")

local lastPortal = 0

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 17879 or cid == 17880 or cid == 21697 or cid == 21698 then
		timerNextPortal:Start(150, lastPortal + 1)--AC: 2.5min after-boss delay
		warnWavePortalSoon:Schedule(140)
	end
end

function mod:UPDATE_WORLD_STATES()
	local text = select(3, GetWorldStateUIInfo(2))
	if not text then return end
	local currentPortal = text:match("(%d+).+18")
	if not currentPortal then
		currentPortal = 0
	end
	currentPortal = tonumber(currentPortal)
	if currentPortal > lastPortal then
		warnWavePortalSoon:Cancel()
		timerNextPortal:Cancel()
		if currentPortal == 6 or currentPortal == 12 or currentPortal == 18 then
			warnBossPortal:Show()
		else
			warnWavePortal:Show(currentPortal)
			if self.Options.ShowAllPortalTimers then
				local nextPortal = currentPortal >= 13 and 120 or 90--AC: 90s, 120s from portal 13
				timerNextPortal:Start(nextPortal, currentPortal + 1)
				warnWavePortalSoon:Schedule(nextPortal - 10)
			end
		end
		lastPortal = currentPortal
	elseif currentPortal < lastPortal then
		lastPortal = 0
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.Shielddown or msg:find(L.Shielddown) then
		self:SendSync("Wipe")
	end
end

function mod:OnSync(msg)
	if msg == "Wipe" then
		warnWavePortalSoon:Cancel()
		timerNextPortal:Cancel()
	end
end
