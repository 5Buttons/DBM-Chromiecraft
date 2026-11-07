local mod	= DBM:NewMod("Noth", "DBM-Naxx", 3)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260214000001")
mod:SetCreatureID(15954)
mod:SetEncounterID(1117)

mod:RegisterCombat("combat_yell", L.Pull)

mod:RegisterEvents(
	"SPELL_CAST_SUCCESS 29213 54835",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"SPELL_AURA_APPLIED 29208"
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
local timerAddsCD		= mod:NewTimer(30, "TimerAdds", "Interface\\Icons\\achievement_character_undead_male", nil, nil, 1)
local timerBlink		= mod:NewNextTimer(30, 29208)

mod:GroupSpells(29216, 29231)

mod.vb.isOnBalcony = false

function mod:OnCombatStart(delay)
	self.vb.isOnBalcony = false
	timerAddsCD:Start(10 - delay)
	timerCurseCD:Start(15 - delay)
	timerTeleport:Start(110 - delay)
	warnTeleportSoon:Schedule(100 - delay)
	if self:IsDifficulty("normal25") then
		timerBlink:Start(26 - delay)
		warnBlinkSoon:Schedule(21 - delay)
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(29213, 54835) then
		warnCurse:Show()
		if not self.vb.isOnBalcony then
			timerCurseCD:Start()
		end
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.Adds or msg:find(L.Adds) then
		self:SendSync("Adds")
	elseif msg == L.AddsTwo or msg:find(L.AddsTwo) then
		self:SendSync("AddsTwo")
	elseif msg == L.Blink or msg:find(L.Blink) then
		self:SendSync("Blink")
	elseif msg == L.TeleportBalcony or msg:find(L.TeleportBalcony) then
		self:SendSync("TeleportBalcony")
	elseif msg == L.TeleportBack or msg:find(L.TeleportBack) then
		self:SendSync("TeleportBack")
	end
end

function mod:OnSync(msg)
	if not self:IsInCombat() then return end
	if msg == "Adds" or msg == "AddsTwo" then
		specWarnAdds:Show()
		specWarnAdds:Play("killmob")
		timerAddsCD:Stop()
		timerAddsCD:Start(30)
	elseif msg == "Blink" then
		warnBlink:Show()
		if not self.vb.isOnBalcony then
			timerBlink:Start()
			warnBlinkSoon:Schedule(25)
		end
	elseif msg == "TeleportBalcony" then
		self.vb.isOnBalcony = true
		warnTeleportNow:Show()
		timerTeleport:Stop()
		timerCurseCD:Stop()
		timerAddsCD:Stop()
		timerBlink:Stop()
		warnBlinkSoon:Cancel()
		timerTeleportBack:Start()
		warnTeleportSoon:Schedule(60)
	elseif msg == "TeleportBack" then
		self.vb.isOnBalcony = false
		warnTeleportNow:Show()
		timerTeleportBack:Stop()
		timerAddsCD:Stop()
		timerTeleport:Start()
		warnTeleportSoon:Schedule(100)
		timerCurseCD:Start(15)
		if self:IsDifficulty("normal25") then
			timerBlink:Start(26)
			warnBlinkSoon:Schedule(21)
		end
	end
end