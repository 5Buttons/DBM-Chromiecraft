local mod	= DBM:NewMod("Noth", "DBM-Naxx", 3)
local L		= mod:GetLocalizedStrings()

local GetSpellInfo = GetSpellInfo

mod:SetRevision("20251204000000")
mod:SetCreatureID(15954)
mod:SetEncounterID(1117)
mod:RegisterCombat("combat_yell", L.Pull)

mod:RegisterEvents(
	"SPELL_CAST_SUCCESS 29213 54835 29212 29208 29209 29210 29211",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UNIT_SPELLCAST_SUCCEEDED boss1"
)

local warnTeleportNow	= mod:NewAnnounce("WarningTeleportNow", 3, 46573, nil, nil, nil, 29216)
local warnTeleportSoon	= mod:NewAnnounce("WarningTeleportSoon", 1, 46573, nil, nil, nil, 29216)
local warnCurse			= mod:NewSpellAnnounce(29213, 2)
local warnBlinkSoon		= mod:NewSoonAnnounce(29208, 1)
local warnBlink			= mod:NewSpellAnnounce(29208, 3)

local specWarnAdds		= mod:NewSpecialWarningAdds(29247, "-Healer", nil, nil, 1, 2)

local timerTeleport		= mod:NewTimer(110, "TimerTeleport", 46573, nil, nil, 6, nil, nil, nil, nil, nil, nil, nil, 29216)
local timerTeleportBack	= mod:NewTimer(70, "TimerTeleportBack", 46573, nil, nil, 6, nil, nil, nil, nil, nil, nil, nil, 29231)
local timerCurseCD		= mod:NewCDTimer(25, 29213, nil, nil, nil, 5, nil, DBM_COMMON_L.CURSE_ICON)
local timerAddsCD		= mod:NewAddsTimer(30, 29247, nil, "-Healer")
local timerBlink		= mod:NewNextTimer(30, 29208)

mod:GroupSpells(29216, 29231) -- Teleport, Teleport Return

mod.vb.teleCount = 0
mod.vb.addsCount = 0
mod.vb.blinkCount = 0
mod.vb.isOnBalcony = false
local teleportBalconyName = GetSpellInfo(29216) -- Teleport
local teleportBackName = GetSpellInfo(29231) -- Teleport Return

function mod:OnCombatStart(delay)
	self.vb.teleCount = 0
	self.vb.addsCount = 0
	self.vb.blinkCount = 0
	self.vb.isOnBalcony = false
	-- Ground phase timers
	timerCurseCD:Start(15-delay)
	timerAddsCD:Start(10-delay) -- First summon announce at 10s
	timerBlink:Start(26-delay) -- 25-man only, but timer handles that
	warnBlinkSoon:Schedule(21-delay)
	timerTeleport:Start(110-delay)
	warnTeleportSoon:Schedule(100-delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(29213, 54835) then	-- Curse of the Plaguebringer
		warnCurse:Show()
		-- Only schedule next curse if on ground (phase mask check)
		if not self.vb.isOnBalcony then
			timerCurseCD:Start(25)
		end
	elseif args:IsSpellID(29208, 29209, 29210, 29211) and args:GetDestCreatureID() == 15954 then -- Blink
		self.vb.blinkCount = self.vb.blinkCount + 1
		warnBlink:Show()
		if not self.vb.isOnBalcony then
			timerBlink:Start(30)
			warnBlinkSoon:Schedule(25)
		end
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.Adds or msg:find(L.Adds) then
		self:SendSync("Adds")
	elseif msg == L.AddsTwo or msg:find(L.AddsTwo) then
		self:SendSync("AddsTwo")
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == teleportBalconyName then -- Teleport to Balcony
		self.vb.teleCount = self.vb.teleCount + 1
		self.vb.isOnBalcony = true
		DBM:AddSpecialEventToTranscriptorLog(format("Teleport %d", self.vb.teleCount))
		-- Stop ground phase timers
		timerCurseCD:Stop()
		timerAddsCD:Stop()
		timerBlink:Stop()
		warnBlinkSoon:Cancel()
		-- Balcony phase: 70 seconds, first adds at 4s
		timerTeleportBack:Start(70)
		warnTeleportSoon:Schedule(60)
		warnTeleportNow:Show()
		timerAddsCD:Start(4) -- First balcony wave
	elseif spellName == teleportBackName then -- Teleport Back to Ground
		self.vb.isOnBalcony = false
		DBM:AddSpecialEventToTranscriptorLog("Teleport Return")
		-- Stop balcony timers
		timerAddsCD:Stop()
		-- Ground phase: 110 seconds (until next teleport)
		timerTeleport:Start(110)
		warnTeleportSoon:Schedule(100)
		warnTeleportNow:Show()
		-- Restart ground phase timers
		timerCurseCD:Start(15)
		timerAddsCD:Start(10) -- First ground adds announce
		-- Blink only in 25-man, but schedule anyway (timer will handle difficulty)
		timerBlink:Start(26)
		warnBlinkSoon:Schedule(21)
		-- Apply berserk after 3rd balcony phase
		if self.vb.teleCount == 3 then
			DBM:AddSpecialEventToTranscriptorLog("Berserk Active (Post-3rd Balcony)")
		end
	end
end

function mod:OnSync(msg)
	if not self:IsInCombat() then return end
	if msg == "Adds" then -- Ground phase adds
		specWarnAdds:Show()
		specWarnAdds:Play("killmob")
		if not self.vb.isOnBalcony then
			-- Ground adds repeat every 30s
			timerAddsCD:Start(30)
		end
	elseif msg == "AddsTwo" then -- Balcony phase adds
		specWarnAdds:Show()
		specWarnAdds:Play("killmob")
		if self.vb.isOnBalcony then
			-- Balcony adds repeat every 30s (max 2 waves per balcony)
			-- Server schedules at 4s initial, then 30s repeat
			-- We're already in wave 1, so schedule wave 2
			timerAddsCD:Start(30)
		end
	end
end